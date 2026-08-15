BEGIN;

CREATE TABLE public.gemini_model_health (
    model_name TEXT PRIMARY KEY,
    is_healthy BOOLEAN NOT NULL DEFAULT TRUE,
    consecutive_failures INT NOT NULL DEFAULT 0,
    last_success_at TIMESTAMPTZ,
    CONSTRAINT gemini_model_health_consecutive_failures_nonnegative
        CHECK (consecutive_failures >= 0)
);

ALTER TABLE public.gemini_model_health ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.gemini_model_health FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.gemini_model_health TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.gemini_model_health TO service_role;

CREATE POLICY "Authenticated users can read Gemini model health"
ON public.gemini_model_health
FOR SELECT
TO authenticated
USING (TRUE);

-- service_role bypasses RLS, but these policies document and preserve the
-- intended write boundary if that role's bypass behavior changes.
CREATE POLICY "Service role can insert Gemini model health"
ON public.gemini_model_health
FOR INSERT
TO service_role
WITH CHECK (TRUE);

CREATE POLICY "Service role can update Gemini model health"
ON public.gemini_model_health
FOR UPDATE
TO service_role
USING (TRUE)
WITH CHECK (TRUE);

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
    IF p_model_name IS NULL OR btrim(p_model_name) = '' THEN
        RAISE EXCEPTION 'p_model_name must not be empty'
            USING ERRCODE = '22023';
    END IF;

    IF p_outcome = 'success' THEN
        INSERT INTO public.gemini_model_health (
            model_name,
            is_healthy,
            consecutive_failures,
            last_success_at
        )
        VALUES (p_model_name, TRUE, 0, now())
        ON CONFLICT (model_name) DO UPDATE
        SET is_healthy = TRUE,
            consecutive_failures = 0,
            last_success_at = EXCLUDED.last_success_at;
    ELSIF p_outcome = 'system_failure' THEN
        INSERT INTO public.gemini_model_health AS health (
            model_name,
            is_healthy,
            consecutive_failures
        )
        VALUES (p_model_name, TRUE, 1)
        ON CONFLICT (model_name) DO UPDATE
        SET consecutive_failures =
                health.consecutive_failures + 1,
            is_healthy =
                health.is_healthy
                AND health.consecutive_failures + 1 < 3;
    ELSE
        RAISE EXCEPTION 'Unsupported Gemini health outcome: %', p_outcome
            USING ERRCODE = '22023';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.record_gemini_model_health(TEXT, TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_gemini_model_health(TEXT, TEXT)
TO service_role;

COMMIT;
