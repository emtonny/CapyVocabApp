BEGIN;

ALTER TABLE public.gemini_model_health
    ADD COLUMN circuit_state TEXT NOT NULL DEFAULT 'healthy',
    ADD COLUMN opened_at TIMESTAMPTZ,
    ADD COLUMN cooldown_until TIMESTAMPTZ,
    ADD COLUMN half_open_probe_token UUID,
    ADD COLUMN half_open_lease_until TIMESTAMPTZ,
    ADD COLUMN last_system_failure_at TIMESTAMPTZ,
    ADD COLUMN system_failure_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN quota_rpm_error_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN quota_tpm_error_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN quota_rpd_error_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN quota_unknown_error_count BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN last_quota_error_at TIMESTAMPTZ,
    ADD COLUMN last_quota_kind TEXT,
    ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.gemini_model_health
SET circuit_state = CASE
        WHEN NOT is_healthy THEN 'open'
        WHEN consecutive_failures > 0 THEN 'degraded'
        ELSE 'healthy'
    END,
    opened_at = CASE WHEN NOT is_healthy THEN now() ELSE NULL END,
    cooldown_until = CASE WHEN NOT is_healthy THEN now() ELSE NULL END,
    system_failure_count = consecutive_failures,
    updated_at = now();

ALTER TABLE public.gemini_model_health
    ADD CONSTRAINT gemini_model_health_circuit_state_valid
        CHECK (circuit_state IN ('healthy', 'degraded', 'open', 'half_open')),
    ADD CONSTRAINT gemini_model_health_legacy_health_consistent
        CHECK (is_healthy = (circuit_state IN ('healthy', 'degraded'))),
    ADD CONSTRAINT gemini_model_health_half_open_lease_consistent
        CHECK (
            (
                circuit_state = 'half_open'
                AND half_open_probe_token IS NOT NULL
                AND half_open_lease_until IS NOT NULL
            )
            OR (
                circuit_state <> 'half_open'
                AND half_open_probe_token IS NULL
                AND half_open_lease_until IS NULL
            )
        ),
    ADD CONSTRAINT gemini_model_health_open_cooldown_present
        CHECK (circuit_state <> 'open' OR cooldown_until IS NOT NULL),
    ADD CONSTRAINT gemini_model_health_counters_nonnegative
        CHECK (
            system_failure_count >= 0
            AND quota_rpm_error_count >= 0
            AND quota_tpm_error_count >= 0
            AND quota_rpd_error_count >= 0
            AND quota_unknown_error_count >= 0
        ),
    ADD CONSTRAINT gemini_model_health_quota_kind_valid
        CHECK (
            last_quota_kind IS NULL
            OR last_quota_kind IN ('rpm', 'tpm', 'rpd', 'unknown')
        );

DROP POLICY IF EXISTS "Authenticated users can read Gemini model health"
ON public.gemini_model_health;
REVOKE ALL ON TABLE public.gemini_model_health
FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.gemini_model_health
TO service_role;

CREATE OR REPLACE FUNCTION public.acquire_gemini_model_attempt(
    p_model_name TEXT,
    p_half_open_lease_seconds INTEGER
)
RETURNS TABLE (
    allowed BOOLEAN,
    circuit_state TEXT,
    probe_token UUID,
    retry_after_seconds INTEGER
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_health public.gemini_model_health%ROWTYPE;
    v_now TIMESTAMPTZ := clock_timestamp();
    v_probe_token UUID;
    v_retry_after_seconds INTEGER;
BEGIN
    IF p_model_name IS NULL OR btrim(p_model_name) = '' THEN
        RAISE EXCEPTION 'p_model_name must not be empty'
            USING ERRCODE = '22023';
    END IF;
    IF p_half_open_lease_seconds IS NULL
       OR p_half_open_lease_seconds < 1
       OR p_half_open_lease_seconds > 3600 THEN
        RAISE EXCEPTION 'p_half_open_lease_seconds must be between 1 and 3600'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.gemini_model_health (model_name)
    VALUES (btrim(p_model_name))
    ON CONFLICT (model_name) DO NOTHING;

    SELECT health.*
    INTO v_health
    FROM public.gemini_model_health AS health
    WHERE health.model_name = btrim(p_model_name)
    FOR UPDATE;

    IF v_health.circuit_state IN ('healthy', 'degraded') THEN
        RETURN QUERY
        SELECT TRUE, v_health.circuit_state, NULL::UUID, NULL::INTEGER;
        RETURN;
    END IF;

    IF v_health.circuit_state = 'open'
       AND v_health.cooldown_until > v_now THEN
        v_retry_after_seconds := GREATEST(
            1,
            CEIL(EXTRACT(EPOCH FROM (v_health.cooldown_until - v_now)))::INTEGER
        );
        RETURN QUERY
        SELECT FALSE, 'open'::TEXT, NULL::UUID, v_retry_after_seconds;
        RETURN;
    END IF;

    IF v_health.circuit_state = 'half_open'
       AND v_health.half_open_lease_until > v_now THEN
        v_retry_after_seconds := GREATEST(
            1,
            CEIL(
                EXTRACT(EPOCH FROM (v_health.half_open_lease_until - v_now))
            )::INTEGER
        );
        RETURN QUERY
        SELECT
            FALSE,
            'half_open'::TEXT,
            NULL::UUID,
            v_retry_after_seconds;
        RETURN;
    END IF;

    v_probe_token := gen_random_uuid();
    UPDATE public.gemini_model_health AS health
    SET circuit_state = 'half_open',
        is_healthy = FALSE,
        half_open_probe_token = v_probe_token,
        half_open_lease_until = v_now
            + make_interval(secs => p_half_open_lease_seconds),
        updated_at = v_now
    WHERE health.model_name = btrim(p_model_name);

    RETURN QUERY
    SELECT TRUE, 'half_open'::TEXT, v_probe_token, NULL::INTEGER;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_gemini_model_outcome(
    p_model_name TEXT,
    p_outcome TEXT,
    p_failure_threshold INTEGER,
    p_cooldown_seconds INTEGER,
    p_probe_token UUID,
    p_quota_kind TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_health public.gemini_model_health%ROWTYPE;
    v_now TIMESTAMPTZ := clock_timestamp();
    v_next_failures INTEGER;
BEGIN
    IF p_model_name IS NULL OR btrim(p_model_name) = '' THEN
        RAISE EXCEPTION 'p_model_name must not be empty'
            USING ERRCODE = '22023';
    END IF;
    IF p_outcome IS NULL
       OR p_outcome NOT IN ('success', 'system_failure', 'quota_error') THEN
        RAISE EXCEPTION 'Unsupported Gemini model outcome: %', p_outcome
            USING ERRCODE = '22023';
    END IF;
    IF p_failure_threshold IS NULL
       OR p_failure_threshold < 1
       OR p_failure_threshold > 100 THEN
        RAISE EXCEPTION 'p_failure_threshold must be between 1 and 100'
            USING ERRCODE = '22023';
    END IF;
    IF p_cooldown_seconds IS NULL
       OR p_cooldown_seconds < 1
       OR p_cooldown_seconds > 86400 THEN
        RAISE EXCEPTION 'p_cooldown_seconds must be between 1 and 86400'
            USING ERRCODE = '22023';
    END IF;
    IF p_outcome = 'quota_error'
       AND (
           p_quota_kind IS NULL
           OR p_quota_kind NOT IN ('rpm', 'tpm', 'rpd', 'unknown')
       ) THEN
        RAISE EXCEPTION 'Unsupported Gemini quota kind: %', p_quota_kind
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.gemini_model_health (model_name)
    VALUES (btrim(p_model_name))
    ON CONFLICT (model_name) DO NOTHING;

    SELECT health.*
    INTO v_health
    FROM public.gemini_model_health AS health
    WHERE health.model_name = btrim(p_model_name)
    FOR UPDATE;

    IF p_outcome = 'quota_error' THEN
        UPDATE public.gemini_model_health AS health
        SET quota_rpm_error_count = health.quota_rpm_error_count
                + CASE WHEN p_quota_kind = 'rpm' THEN 1 ELSE 0 END,
            quota_tpm_error_count = health.quota_tpm_error_count
                + CASE WHEN p_quota_kind = 'tpm' THEN 1 ELSE 0 END,
            quota_rpd_error_count = health.quota_rpd_error_count
                + CASE WHEN p_quota_kind = 'rpd' THEN 1 ELSE 0 END,
            quota_unknown_error_count = health.quota_unknown_error_count
                + CASE WHEN p_quota_kind = 'unknown' THEN 1 ELSE 0 END,
            last_quota_error_at = v_now,
            last_quota_kind = p_quota_kind,
            updated_at = v_now
        WHERE health.model_name = btrim(p_model_name);
        RETURN;
    END IF;

    IF p_outcome = 'success' THEN
        IF v_health.circuit_state = 'open' THEN
            RETURN;
        END IF;
        IF v_health.circuit_state = 'half_open'
           AND (
               p_probe_token IS NULL
               OR p_probe_token IS DISTINCT FROM v_health.half_open_probe_token
           ) THEN
            RETURN;
        END IF;

        UPDATE public.gemini_model_health AS health
        SET circuit_state = 'healthy',
            is_healthy = TRUE,
            consecutive_failures = 0,
            last_success_at = v_now,
            opened_at = NULL,
            cooldown_until = NULL,
            half_open_probe_token = NULL,
            half_open_lease_until = NULL,
            updated_at = v_now
        WHERE health.model_name = btrim(p_model_name);
        RETURN;
    END IF;

    UPDATE public.gemini_model_health AS health
    SET system_failure_count = health.system_failure_count + 1,
        last_system_failure_at = v_now,
        updated_at = v_now
    WHERE health.model_name = btrim(p_model_name);

    IF v_health.circuit_state = 'open' THEN
        RETURN;
    END IF;
    IF v_health.circuit_state = 'half_open' THEN
        IF p_probe_token IS NULL
           OR p_probe_token IS DISTINCT FROM v_health.half_open_probe_token THEN
            RETURN;
        END IF;

        UPDATE public.gemini_model_health AS health
        SET circuit_state = 'open',
            is_healthy = FALSE,
            consecutive_failures = GREATEST(
                health.consecutive_failures + 1,
                p_failure_threshold
            ),
            opened_at = v_now,
            cooldown_until = v_now
                + make_interval(secs => p_cooldown_seconds),
            half_open_probe_token = NULL,
            half_open_lease_until = NULL,
            updated_at = v_now
        WHERE health.model_name = btrim(p_model_name);
        RETURN;
    END IF;

    v_next_failures := v_health.consecutive_failures + 1;
    UPDATE public.gemini_model_health AS health
    SET consecutive_failures = v_next_failures,
        circuit_state = CASE
            WHEN v_next_failures >= p_failure_threshold THEN 'open'
            ELSE 'degraded'
        END,
        is_healthy = v_next_failures < p_failure_threshold,
        opened_at = CASE
            WHEN v_next_failures >= p_failure_threshold THEN v_now
            ELSE NULL
        END,
        cooldown_until = CASE
            WHEN v_next_failures >= p_failure_threshold
                THEN v_now + make_interval(secs => p_cooldown_seconds)
            ELSE NULL
        END,
        half_open_probe_token = NULL,
        half_open_lease_until = NULL,
        updated_at = v_now
    WHERE health.model_name = btrim(p_model_name);
END;
$$;

-- Compatibility wrapper for the currently deployed production function.
CREATE OR REPLACE FUNCTION public.record_gemini_model_health(
    p_model_name TEXT,
    p_outcome TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    PERFORM public.record_gemini_model_outcome(
        p_model_name,
        p_outcome,
        3,
        60,
        NULL,
        NULL
    );
END;
$$;

REVOKE ALL ON FUNCTION public.acquire_gemini_model_attempt(TEXT, INTEGER)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_gemini_model_outcome(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    UUID,
    TEXT
)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_gemini_model_health(TEXT, TEXT)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.acquire_gemini_model_attempt(TEXT, INTEGER)
TO service_role;
GRANT EXECUTE ON FUNCTION public.record_gemini_model_outcome(
    TEXT,
    TEXT,
    INTEGER,
    INTEGER,
    UUID,
    TEXT
)
TO service_role;
GRANT EXECUTE ON FUNCTION public.record_gemini_model_health(TEXT, TEXT)
TO service_role;

COMMIT;
