BEGIN;

CREATE TABLE public.ai_scan_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_request_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    service_tier TEXT NOT NULL
        CHECK (service_tier IN ('free', 'pro')),
    status TEXT NOT NULL DEFAULT 'processing'
        CHECK (status IN ('processing', 'succeeded', 'failed')),
    model_used TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0
        CHECK (attempt_count >= 0),
    input_token_count BIGINT NOT NULL DEFAULT 0
        CHECK (input_token_count >= 0),
    output_token_count BIGINT NOT NULL DEFAULT 0
        CHECK (output_token_count >= 0),
    total_token_count BIGINT NOT NULL DEFAULT 0
        CHECK (total_token_count >= 0),
    latency_ms BIGINT CHECK (latency_ms >= 0),
    word_count INTEGER CHECK (word_count >= 0),
    error_code TEXT,
    result_json JSONB,
    result_expires_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ai_scan_requests_user_client_request_key
        UNIQUE (user_id, client_request_id),
    CONSTRAINT ai_scan_requests_result_has_no_image
        CHECK (result_json IS NULL OR NOT (result_json ? 'image_base64'))
);

CREATE INDEX ai_scan_requests_result_expiry_idx
ON public.ai_scan_requests (result_expires_at)
WHERE result_json IS NOT NULL;

ALTER TABLE public.ai_scan_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.ai_scan_requests
FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.ai_scan_requests
TO service_role;

CREATE OR REPLACE FUNCTION public.reserve_ai_scan_request(
    p_user_id UUID,
    p_client_request_id UUID,
    p_service_tier TEXT
)
RETURNS TABLE (
    decision TEXT,
    attempt_count INTEGER,
    result_json JSONB,
    model_used TEXT,
    service_tier TEXT,
    input_token_count BIGINT,
    output_token_count BIGINT,
    total_token_count BIGINT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    request_row public.ai_scan_requests%ROWTYPE;
BEGIN
    IF p_service_tier NOT IN ('free', 'pro') THEN
        RAISE EXCEPTION 'Unsupported service tier: %', p_service_tier
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.ai_scan_requests (
        client_request_id,
        user_id,
        service_tier,
        status
    ) VALUES (
        p_client_request_id,
        p_user_id,
        p_service_tier,
        'processing'
    )
    ON CONFLICT (user_id, client_request_id) DO NOTHING
    RETURNING * INTO request_row;

    IF FOUND THEN
        RETURN QUERY SELECT
            'reserved'::TEXT,
            request_row.attempt_count,
            request_row.result_json,
            request_row.model_used,
            request_row.service_tier,
            request_row.input_token_count,
            request_row.output_token_count,
            request_row.total_token_count;
        RETURN;
    END IF;

    SELECT * INTO request_row
    FROM public.ai_scan_requests AS request
    WHERE request.user_id = p_user_id
      AND request.client_request_id = p_client_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'AI scan reservation disappeared';
    END IF;

    IF request_row.status = 'succeeded' THEN
        RETURN QUERY SELECT
            CASE
                WHEN request_row.result_json IS NOT NULL
                 AND request_row.result_expires_at > NOW()
                    THEN 'replay'::TEXT
                ELSE 'expired'::TEXT
            END,
            request_row.attempt_count,
            request_row.result_json,
            request_row.model_used,
            request_row.service_tier,
            request_row.input_token_count,
            request_row.output_token_count,
            request_row.total_token_count;
        RETURN;
    END IF;

    IF request_row.status = 'processing' THEN
        RETURN QUERY SELECT
            'in_progress'::TEXT,
            request_row.attempt_count,
            NULL::JSONB,
            request_row.model_used,
            request_row.service_tier,
            request_row.input_token_count,
            request_row.output_token_count,
            request_row.total_token_count;
        RETURN;
    END IF;

    UPDATE public.ai_scan_requests AS request
    SET status = 'processing',
        service_tier = p_service_tier,
        model_used = NULL,
        latency_ms = NULL,
        word_count = NULL,
        error_code = NULL,
        result_json = NULL,
        result_expires_at = NULL,
        started_at = NOW(),
        completed_at = NULL,
        updated_at = NOW()
    WHERE request.id = request_row.id
    RETURNING * INTO request_row;

    RETURN QUERY SELECT
        'reserved'::TEXT,
        request_row.attempt_count,
        request_row.result_json,
        request_row.model_used,
        request_row.service_tier,
        request_row.input_token_count,
        request_row.output_token_count,
        request_row.total_token_count;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_ai_scan_request(UUID, UUID, TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_ai_scan_request(UUID, UUID, TEXT)
TO service_role;

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
DECLARE
    existing_job_id BIGINT;
BEGIN
    SELECT jobid INTO existing_job_id
    FROM cron.job
    WHERE jobname = 'purge-ai-scan-result-json-hourly'
    LIMIT 1;

    IF existing_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(existing_job_id);
    END IF;

    PERFORM cron.schedule(
        'purge-ai-scan-result-json-hourly',
        '17 * * * *',
        $command$
            UPDATE public.ai_scan_requests
            SET result_json = NULL,
                updated_at = NOW()
            WHERE result_json IS NOT NULL
              AND result_expires_at <= NOW();
        $command$
    );
END;
$$;

COMMIT;
