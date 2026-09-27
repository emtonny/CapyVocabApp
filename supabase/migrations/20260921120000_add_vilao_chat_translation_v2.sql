-- C7: move new Chat display translations to the Vilao gateway without
-- rewriting immutable v1 rows. Existing v1 translations remain readable.

ALTER TABLE public.chat_translations
    DROP CONSTRAINT IF EXISTS chat_translations_provider_check,
    ADD CONSTRAINT chat_translations_provider_check
        CHECK (provider IN ('gemini', 'vilao'));

DROP TRIGGER IF EXISTS enqueue_chat_translation_v1
ON public.chat_operational_messages;
DROP TRIGGER IF EXISTS wake_chat_translation_worker_v1
ON public.chat_translations;
CREATE FUNCTION private.enqueue_chat_translation_v2()
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
        'chat-translate-v2',
        'vilao',
        'gemini-3.8-flash',
        'chat-translate-p2',
        'queued'
    )
    ON CONFLICT (message_id, target_language_code, translator_version)
    DO NOTHING;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.enqueue_chat_translation_v2()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER enqueue_chat_translation_v2
AFTER INSERT ON public.chat_operational_messages
FOR EACH ROW EXECUTE FUNCTION private.enqueue_chat_translation_v2();
CREATE OR REPLACE FUNCTION public.claim_chat_translation(p_translator_version TEXT)
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
    IF p_translator_version IS DISTINCT FROM 'chat-translate-v2' THEN
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

    IF v_job.provider IS DISTINCT FROM 'vilao'
       OR v_job.model IS DISTINCT FROM 'gemini-3.8-flash'
       OR v_job.prompt_version IS DISTINCT FROM 'chat-translate-p2' THEN
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

REVOKE ALL ON FUNCTION public.claim_chat_translation(TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_chat_translation(TEXT) TO service_role;

CREATE OR REPLACE FUNCTION private.wake_chat_translation_worker_v2()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM private.request_chat_translation_worker();
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.wake_chat_translation_worker_v2()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER wake_chat_translation_worker_v2
AFTER INSERT ON public.chat_translations
FOR EACH ROW
WHEN (
    NEW.status = 'queued'
    AND NEW.translator_version = 'chat-translate-v2'
)
EXECUTE FUNCTION private.wake_chat_translation_worker_v2();

COMMENT ON FUNCTION private.enqueue_chat_translation_v2() IS
'C7 enqueues immutable Vilao/gemini-3.8-flash display translations for new raw Chat messages.';
COMMENT ON FUNCTION private.wake_chat_translation_worker_v2() IS
'C7 fail-open wake-up for v2 Chat translation jobs.';
COMMENT ON FUNCTION public.claim_chat_translation(TEXT) IS
'C7 atomic single-flight claim for chat-translate-v2. Service role only.';
COMMENT ON TABLE public.chat_translations IS
'Operational display translations only, service-written. Not a Training source.';
