-- C4B: additive Operational Chat translation queue and atomic service-only claim.
-- Provider calls remain outside PostgreSQL; raw-message insertion only enqueues.

ALTER TABLE public.chat_translations
    ADD COLUMN claim_token UUID,
    ADD COLUMN lease_expires_at TIMESTAMPTZ,
    ADD COLUMN last_attempt_at TIMESTAMPTZ,
    ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.chat_translations
    DROP CONSTRAINT IF EXISTS chat_translations_attempt_count_check,
    DROP CONSTRAINT IF EXISTS chat_translations_error_code_check,
    ADD CONSTRAINT chat_translations_attempt_count_check
        CHECK (attempt_count BETWEEN 0 AND 4),
    ADD CONSTRAINT chat_translations_error_code_check
        CHECK (error_code IS NULL OR error_code IN (
            'MESSAGE_INELIGIBLE',
            'UNSUPPORTED_LANGUAGE',
            'POLICY_MISMATCH',
            'PROVIDER_AUTH_DENIED',
            'PROVIDER_REQUEST_REJECTED',
            'PROVIDER_RATE_LIMITED',
            'PROVIDER_TIMEOUT',
            'PROVIDER_NETWORK',
            'PROVIDER_UNAVAILABLE',
            'MALFORMED_RESPONSE',
            'OUTPUT_INVALID',
            'RETRY_EXHAUSTED'
        )),
    ADD CONSTRAINT chat_translations_queue_state_check CHECK (
        (status = 'queued'
            AND attempt_count = 0
            AND claim_token IS NULL
            AND lease_expires_at IS NULL
            AND next_attempt_at IS NULL
            AND error_code IS NULL
            AND completed_at IS NULL)
        OR (status = 'processing'
            AND claim_token IS NOT NULL
            AND lease_expires_at IS NOT NULL
            AND last_attempt_at IS NOT NULL
            AND next_attempt_at IS NULL
            AND error_code IS NULL
            AND completed_at IS NULL)
        OR (status = 'succeeded'
            AND claim_token IS NULL
            AND lease_expires_at IS NULL
            AND next_attempt_at IS NULL
            AND error_code IS NULL)
        OR (status = 'failed'
            AND claim_token IS NULL
            AND lease_expires_at IS NULL
            AND completed_at IS NULL
            AND (attempt_count < 4 OR next_attempt_at IS NULL))
    ),
    ADD CONSTRAINT chat_translations_updated_at_check
        CHECK (updated_at >= created_at);

CREATE INDEX chat_translations_processing_lease
ON public.chat_translations(lease_expires_at, id)
WHERE status = 'processing';

CREATE TABLE private.chat_translation_provider_state (
    translator_version TEXT PRIMARY KEY
        CHECK (char_length(translator_version) BETWEEN 1 AND 80),
    consecutive_failure_count INTEGER NOT NULL DEFAULT 0
        CHECK (consecutive_failure_count >= 0),
    open_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

REVOKE ALL ON private.chat_translation_provider_state
FROM PUBLIC, anon, authenticated, service_role;

-- Keep the C2 derived-record rules and additionally freeze the policy snapshot.
CREATE OR REPLACE FUNCTION private.validate_chat_derived_record()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_sender UUID; v_source TEXT;
BEGIN
    SELECT sender_id, source_language_code INTO v_sender, v_source
    FROM public.chat_operational_messages WHERE id = NEW.message_id;
    IF v_sender IS NULL OR NEW.target_language_code = v_source THEN
        RAISE EXCEPTION 'Derived record needs a different target language'
            USING ERRCODE = '22023';
    END IF;
    IF TG_OP = 'UPDATE' AND (
        NEW.id <> OLD.id
        OR NEW.message_id <> OLD.message_id
        OR NEW.target_language_code <> OLD.target_language_code
    ) THEN
        RAISE EXCEPTION 'Derived record identity is immutable'
            USING ERRCODE = '22023';
    END IF;
    IF TG_TABLE_NAME = 'chat_translations' THEN
        IF TG_OP = 'UPDATE' THEN
            IF ROW(NEW.translator_version, NEW.provider, NEW.model, NEW.prompt_version)
                IS DISTINCT FROM
               ROW(OLD.translator_version, OLD.provider, OLD.model, OLD.prompt_version) THEN
                RAISE EXCEPTION 'Translation policy snapshot is immutable'
                    USING ERRCODE = '22023';
            END IF;
            IF OLD.status = 'succeeded' AND NEW IS DISTINCT FROM OLD THEN
                RAISE EXCEPTION 'Successful translation is immutable'
                    USING ERRCODE = '22023';
            END IF;
        END IF;
    ELSE
        IF NEW.author_id = v_sender OR NOT EXISTS (
            SELECT 1
            FROM public.chat_members m
            JOIN public.chat_operational_messages msg
              ON msg.conversation_id = m.conversation_id
            WHERE msg.id = NEW.message_id
              AND m.user_id = NEW.author_id
              AND m.left_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Correction must come from the other member'
                USING ERRCODE = '22023';
        END IF;
        IF TG_OP = 'UPDATE' THEN
            IF NEW.author_id <> OLD.author_id
               OR NEW.proposed_text <> OLD.proposed_text
               OR NEW.created_at <> OLD.created_at
               OR (OLD.status <> 'proposed' AND NEW IS DISTINCT FROM OLD) THEN
                RAISE EXCEPTION 'Correction content/decision is immutable'
                    USING ERRCODE = '22023';
            END IF;
        END IF;
        IF (NEW.accepted_by IS NOT NULL AND NEW.accepted_by <> v_sender)
           OR (NEW.rejected_by IS NOT NULL AND NEW.rejected_by <> v_sender) THEN
            RAISE EXCEPTION 'Only the source sender decides a correction'
                USING ERRCODE = '22023';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE FUNCTION private.guard_chat_translation_mutation()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_owner NAME;
BEGIN
    SELECT pg_get_userbyid(c.relowner) INTO v_owner
    FROM pg_catalog.pg_class c
    WHERE c.oid = 'public.chat_translations'::regclass;
    IF current_user IS DISTINCT FROM v_owner THEN
        RAISE EXCEPTION 'Chat translation mutations require a trusted RPC'
            USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_chat_translation_mutation()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER guard_chat_translation_mutation
BEFORE INSERT OR UPDATE OR DELETE ON public.chat_translations
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_translation_mutation();

CREATE FUNCTION private.enqueue_chat_translation_v1()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    INSERT INTO public.chat_translations (
        message_id,
        target_language_code,
        translator_version,
        provider,
        model,
        prompt_version,
        status
    ) VALUES (
        NEW.id,
        CASE NEW.source_language_code WHEN 'vi' THEN 'en' ELSE 'vi' END,
        'chat-translate-v1',
        'gemini',
        'gemini-3.5-flash-lite',
        'chat-translate-p1',
        'queued'
    )
    ON CONFLICT (message_id, target_language_code, translator_version)
    DO NOTHING;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enqueue_chat_translation_v1()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER enqueue_chat_translation_v1
AFTER INSERT ON public.chat_operational_messages
FOR EACH ROW EXECUTE FUNCTION private.enqueue_chat_translation_v1();

CREATE FUNCTION public.claim_chat_translation(p_translator_version TEXT)
RETURNS TABLE (
    translation_id UUID,
    claim_token UUID,
    raw_text TEXT,
    source_language_code TEXT,
    target_language_code TEXT,
    provider TEXT,
    model TEXT,
    prompt_version TEXT,
    translator_version TEXT,
    attempt_count INTEGER,
    lease_expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_job public.chat_translations%ROWTYPE;
    v_source_language TEXT;
    v_token UUID;
BEGIN
    IF p_translator_version IS DISTINCT FROM 'chat-translate-v1' THEN
        RAISE EXCEPTION 'Unsupported chat translator version'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1 FROM private.chat_translation_provider_state s
        WHERE s.translator_version = p_translator_version
          AND s.open_until > v_now
    ) THEN
        RETURN;
    END IF;

    SELECT t.* INTO v_job
    FROM public.chat_translations t
    WHERE t.translator_version = p_translator_version
      AND (
          t.status = 'queued'
          OR (t.status = 'failed'
              AND t.next_attempt_at IS NOT NULL
              AND t.next_attempt_at <= v_now)
          OR (t.status = 'processing'
              AND t.lease_expires_at <= v_now)
      )
    ORDER BY COALESCE(t.next_attempt_at, t.lease_expires_at, t.created_at),
             t.created_at, t.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_job.attempt_count >= 4 THEN
        UPDATE public.chat_translations t
        SET status = 'failed',
            error_code = 'RETRY_EXHAUSTED',
            next_attempt_at = NULL,
            claim_token = NULL,
            lease_expires_at = NULL,
            updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    SELECT m.source_language_code INTO v_source_language
    FROM public.chat_operational_messages m
    WHERE m.id = v_job.message_id;

    IF v_source_language IS NULL
       OR (v_source_language = 'vi' AND v_job.target_language_code <> 'en')
       OR (v_source_language = 'en' AND v_job.target_language_code <> 'vi')
       OR v_source_language NOT IN ('vi', 'en') THEN
        UPDATE public.chat_translations t
        SET status = 'failed', error_code = 'UNSUPPORTED_LANGUAGE',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    IF v_job.provider IS DISTINCT FROM 'gemini'
       OR v_job.model IS DISTINCT FROM 'gemini-3.5-flash-lite'
       OR v_job.prompt_version IS DISTINCT FROM 'chat-translate-p1' THEN
        UPDATE public.chat_translations t
        SET status = 'failed', error_code = 'POLICY_MISMATCH',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.chat_operational_messages m
        WHERE m.id = v_job.message_id
          AND m.deleted_at IS NULL
          AND m.moderation_state = 'visible'
          AND (
              SELECT count(*)
              FROM public.chat_members cm
              WHERE cm.conversation_id = m.conversation_id
                AND cm.left_at IS NULL
          ) = 2
    ) THEN
        UPDATE public.chat_translations t
        SET status = 'failed', error_code = 'MESSAGE_INELIGIBLE',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    v_token := gen_random_uuid();
    UPDATE public.chat_translations t
    SET status = 'processing',
        attempt_count = t.attempt_count + 1,
        claim_token = v_token,
        lease_expires_at = v_now + INTERVAL '60 seconds',
        last_attempt_at = v_now,
        next_attempt_at = NULL,
        error_code = NULL,
        updated_at = v_now
    WHERE t.id = v_job.id;

    RETURN QUERY
    SELECT t.id, t.claim_token, m.raw_text, m.source_language_code,
           t.target_language_code, t.provider, t.model, t.prompt_version,
           t.translator_version, t.attempt_count, t.lease_expires_at
    FROM public.chat_translations t
    JOIN public.chat_operational_messages m ON m.id = t.message_id
    WHERE t.id = v_job.id;
END;
$$;

CREATE FUNCTION public.complete_chat_translation(
    p_translation_id UUID,
    p_claim_token UUID,
    p_translated_text TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_job public.chat_translations%ROWTYPE;
BEGIN
    IF p_translated_text IS NULL
       OR char_length(p_translated_text) NOT BETWEEN 1 AND 16000
       OR p_translated_text !~ '[^[:space:]]' THEN
        RAISE EXCEPTION 'Invalid translated output' USING ERRCODE = '22023';
    END IF;

    SELECT t.* INTO v_job
    FROM public.chat_translations t
    WHERE t.id = p_translation_id
    FOR UPDATE;
    IF NOT FOUND
       OR v_job.status <> 'processing'
       OR v_job.claim_token IS DISTINCT FROM p_claim_token
       OR v_job.lease_expires_at <= v_now THEN
        RAISE EXCEPTION 'Translation claim is stale or invalid'
            USING ERRCODE = '55000';
    END IF;

    UPDATE public.chat_translations t
    SET status = 'succeeded',
        translated_text = p_translated_text,
        completed_at = v_now,
        claim_token = NULL,
        lease_expires_at = NULL,
        next_attempt_at = NULL,
        error_code = NULL,
        updated_at = v_now
    WHERE t.id = p_translation_id;

    INSERT INTO private.chat_translation_provider_state (
        translator_version, consecutive_failure_count, open_until, updated_at
    ) VALUES (v_job.translator_version, 0, NULL, v_now)
    ON CONFLICT (translator_version) DO UPDATE
    SET consecutive_failure_count = 0,
        open_until = NULL,
        updated_at = EXCLUDED.updated_at;
    RETURN TRUE;
END;
$$;

CREATE FUNCTION public.fail_chat_translation(
    p_translation_id UUID,
    p_claim_token UUID,
    p_error_code TEXT,
    p_provider_retry_after_seconds INTEGER DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_job public.chat_translations%ROWTYPE;
    v_retryable BOOLEAN;
    v_base_delay_seconds INTEGER;
    v_provider_delay_seconds INTEGER;
    v_retry_delay_seconds INTEGER;
    v_stored_error TEXT;
BEGIN
    IF p_error_code NOT IN (
        'PROVIDER_AUTH_DENIED',
        'PROVIDER_REQUEST_REJECTED',
        'PROVIDER_RATE_LIMITED',
        'PROVIDER_TIMEOUT',
        'PROVIDER_NETWORK',
        'PROVIDER_UNAVAILABLE',
        'MALFORMED_RESPONSE',
        'OUTPUT_INVALID'
    ) THEN
        RAISE EXCEPTION 'Unsupported provider failure code'
            USING ERRCODE = '22023';
    END IF;

    SELECT t.* INTO v_job
    FROM public.chat_translations t
    WHERE t.id = p_translation_id
    FOR UPDATE;
    IF NOT FOUND
       OR v_job.status <> 'processing'
       OR v_job.claim_token IS DISTINCT FROM p_claim_token
       OR v_job.lease_expires_at <= v_now THEN
        RAISE EXCEPTION 'Translation claim is stale or invalid'
            USING ERRCODE = '55000';
    END IF;

    v_retryable := p_error_code IN (
        'PROVIDER_RATE_LIMITED',
        'PROVIDER_TIMEOUT',
        'PROVIDER_NETWORK',
        'PROVIDER_UNAVAILABLE',
        'MALFORMED_RESPONSE'
    );
    v_provider_delay_seconds := CASE
        WHEN p_provider_retry_after_seconds IS NULL
             OR p_provider_retry_after_seconds < 0 THEN NULL
        ELSE LEAST(p_provider_retry_after_seconds, 300)
    END;
    v_base_delay_seconds := CASE v_job.attempt_count
        WHEN 1 THEN 5
        WHEN 2 THEN 30
        WHEN 3 THEN 120
        ELSE NULL
    END;
    v_retry_delay_seconds := CASE
        WHEN v_retryable AND v_job.attempt_count < 4 THEN
            GREATEST(v_base_delay_seconds, COALESCE(v_provider_delay_seconds, 0))
        ELSE NULL
    END;
    v_stored_error := CASE
        WHEN v_retryable AND v_job.attempt_count >= 4 THEN 'RETRY_EXHAUSTED'
        ELSE p_error_code
    END;

    UPDATE public.chat_translations t
    SET status = 'failed',
        error_code = v_stored_error,
        next_attempt_at = CASE
            WHEN v_retry_delay_seconds IS NULL THEN NULL
            ELSE v_now + make_interval(secs => v_retry_delay_seconds)
        END,
        claim_token = NULL,
        lease_expires_at = NULL,
        updated_at = v_now
    WHERE t.id = p_translation_id;

    IF p_error_code = 'PROVIDER_RATE_LIMITED' THEN
        INSERT INTO private.chat_translation_provider_state (
            translator_version, consecutive_failure_count, open_until, updated_at
        ) VALUES (
            v_job.translator_version,
            0,
            v_now + make_interval(secs => COALESCE(v_provider_delay_seconds, 60)),
            v_now
        )
        ON CONFLICT (translator_version) DO UPDATE
        SET open_until = EXCLUDED.open_until,
            updated_at = EXCLUDED.updated_at;
    ELSIF p_error_code = 'PROVIDER_AUTH_DENIED' THEN
        INSERT INTO private.chat_translation_provider_state (
            translator_version, consecutive_failure_count, open_until, updated_at
        ) VALUES (v_job.translator_version, 0, v_now + INTERVAL '5 minutes', v_now)
        ON CONFLICT (translator_version) DO UPDATE
        SET open_until = EXCLUDED.open_until,
            updated_at = EXCLUDED.updated_at;
    ELSIF p_error_code IN (
        'PROVIDER_TIMEOUT', 'PROVIDER_NETWORK',
        'PROVIDER_UNAVAILABLE', 'MALFORMED_RESPONSE'
    ) THEN
        INSERT INTO private.chat_translation_provider_state (
            translator_version, consecutive_failure_count, open_until, updated_at
        ) VALUES (v_job.translator_version, 1, NULL, v_now)
        ON CONFLICT (translator_version) DO UPDATE
        SET consecutive_failure_count =
                chat_translation_provider_state.consecutive_failure_count + 1,
            open_until = CASE
                WHEN chat_translation_provider_state.consecutive_failure_count + 1 >= 3
                    THEN v_now + INTERVAL '30 seconds'
                ELSE NULL
            END,
            updated_at = EXCLUDED.updated_at;
    END IF;
    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_chat_translation(TEXT)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.complete_chat_translation(UUID, UUID, TEXT)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.fail_chat_translation(UUID, UUID, TEXT, INTEGER)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_chat_translation(TEXT) TO service_role;

GRANT EXECUTE ON FUNCTION public.complete_chat_translation(UUID, UUID, TEXT)
TO service_role;

GRANT EXECUTE ON FUNCTION public.fail_chat_translation(UUID, UUID, TEXT, INTEGER)
TO service_role;

COMMENT ON TABLE private.chat_translation_provider_state IS
'C4B private circuit state only; never stores chat content or user identity.';

COMMENT ON FUNCTION public.claim_chat_translation(TEXT) IS
'C4B atomic single-flight claim. Service role only; returns raw text to the winning worker.';

COMMENT ON FUNCTION public.complete_chat_translation(UUID, UUID, TEXT) IS
'C4B token-bound immutable success transition. Service role only.';

COMMENT ON FUNCTION public.fail_chat_translation(UUID, UUID, TEXT, INTEGER) IS
'C4B token-bound bounded retry/circuit transition. Service role only.';
