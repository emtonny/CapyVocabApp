-- Move new Chat display translations to native Google Gemini while preserving
-- immutable v1/v2 rows for history and rollback inspection.

BEGIN;

DROP TRIGGER IF EXISTS enqueue_chat_translation_v2
ON public.chat_operational_messages;
DROP TRIGGER IF EXISTS wake_chat_translation_worker_v2
ON public.chat_translations;

CREATE FUNCTION private.enqueue_chat_translation_v3()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
        'chat-translate-v3',
        'gemini',
        'gemini-3-flash-preview',
        'chat-translate-p3',
        'queued'
    )
    ON CONFLICT (message_id, target_language_code, translator_version)
    DO NOTHING;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enqueue_chat_translation_v3()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER enqueue_chat_translation_v3
AFTER INSERT ON public.chat_operational_messages
FOR EACH ROW EXECUTE FUNCTION private.enqueue_chat_translation_v3();

CREATE OR REPLACE FUNCTION public.claim_chat_translation(
    p_translator_version TEXT
)
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_job public.chat_translations%ROWTYPE;
    v_source_language TEXT;
    v_token UUID;
BEGIN
    IF p_translator_version IS DISTINCT FROM 'chat-translate-v3' THEN
        RAISE EXCEPTION 'Unsupported chat translator version'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1 FROM private.chat_translation_provider_state AS s
        WHERE s.translator_version = p_translator_version
          AND s.open_until > v_now
    ) THEN
        RETURN;
    END IF;

    SELECT t.* INTO v_job
    FROM public.chat_translations AS t
    WHERE t.translator_version = p_translator_version
      AND (
          t.status = 'queued'
          OR (t.status = 'failed'
              AND t.next_attempt_at IS NOT NULL
              AND t.next_attempt_at <= v_now)
          OR (t.status = 'processing' AND t.lease_expires_at <= v_now)
      )
    ORDER BY COALESCE(t.next_attempt_at, t.lease_expires_at, t.created_at),
             t.created_at, t.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_job.attempt_count >= 4 THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'RETRY_EXHAUSTED',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    SELECT m.source_language_code INTO v_source_language
    FROM public.chat_operational_messages AS m
    WHERE m.id = v_job.message_id;

    IF v_source_language IS NULL
       OR (v_source_language = 'vi' AND v_job.target_language_code <> 'en')
       OR (v_source_language = 'en' AND v_job.target_language_code <> 'vi')
       OR v_source_language NOT IN ('vi', 'en') THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'UNSUPPORTED_LANGUAGE',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    IF v_job.provider IS DISTINCT FROM 'gemini'
       OR v_job.model IS DISTINCT FROM 'gemini-3-flash-preview'
       OR v_job.prompt_version IS DISTINCT FROM 'chat-translate-p3' THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'POLICY_MISMATCH',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.chat_operational_messages AS m
        JOIN public.chat_conversations AS c ON c.id = m.conversation_id
        WHERE m.id = v_job.message_id
          AND m.deleted_at IS NULL
          AND m.moderation_state = 'visible'
          AND (
              (c.kind = 'direct' AND (
                  SELECT COUNT(*) FROM public.chat_members AS cm
                  WHERE cm.conversation_id = c.id AND cm.left_at IS NULL
              ) = 2)
              OR c.kind = 'group'
          )
    ) THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'MESSAGE_INELIGIBLE',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    v_token := gen_random_uuid();
    UPDATE public.chat_translations AS t
    SET status = 'processing', attempt_count = t.attempt_count + 1,
        claim_token = v_token,
        lease_expires_at = v_now + INTERVAL '60 seconds',
        last_attempt_at = v_now, next_attempt_at = NULL,
        error_code = NULL, updated_at = v_now
    WHERE t.id = v_job.id;

    RETURN QUERY
    SELECT t.id, t.claim_token, m.raw_text, m.source_language_code,
           t.target_language_code, t.provider, t.model, t.prompt_version,
           t.translator_version, t.attempt_count, t.lease_expires_at
    FROM public.chat_translations AS t
    JOIN public.chat_operational_messages AS m ON m.id = t.message_id
    WHERE t.id = v_job.id;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_chat_translation(TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_chat_translation(TEXT) TO service_role;

CREATE FUNCTION private.wake_chat_translation_worker_v3()
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

REVOKE ALL ON FUNCTION private.wake_chat_translation_worker_v3()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER wake_chat_translation_worker_v3
AFTER INSERT ON public.chat_translations
FOR EACH ROW
WHEN (
    NEW.status = 'queued'
    AND NEW.translator_version = 'chat-translate-v3'
)
EXECUTE FUNCTION private.wake_chat_translation_worker_v3();

COMMENT ON FUNCTION private.enqueue_chat_translation_v3() IS
'Enqueues immutable native Gemini/gemini-3-flash-preview display translations for new raw Chat messages.';
COMMENT ON FUNCTION private.wake_chat_translation_worker_v3() IS
'Fail-open wake-up for v3 Chat translation jobs.';
COMMENT ON FUNCTION public.claim_chat_translation(TEXT) IS
'Atomic single-flight claim for chat-translate-v3. Service role only.';

COMMIT;
