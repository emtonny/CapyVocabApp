-- C4G: wake the Chat translation worker after a queue row commits and recover
-- missed wake-ups once per minute. Provider calls remain outside PostgreSQL.
--
-- Required hosted extensions: pg_net, pg_cron and Supabase Vault. The rollout
-- preflight must verify these before applying this migration.

CREATE FUNCTION private.request_chat_translation_worker()
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_worker_url TEXT;
    v_trigger_secret TEXT;
BEGIN
    SELECT s.decrypted_secret
    INTO v_worker_url
    FROM vault.decrypted_secrets s
    WHERE s.name = 'chat_translation_worker_url'
    LIMIT 1;

    SELECT s.decrypted_secret
    INTO v_trigger_secret
    FROM vault.decrypted_secrets s
    WHERE s.name = 'chat_translation_trigger_secret'
    LIMIT 1;

    -- Missing or malformed rollout configuration must never block raw chat.
    IF v_worker_url IS NULL
       OR v_worker_url !~ '^https://[a-z0-9-]+[.]supabase[.]co/functions/v1/chat-translation-worker$'
       OR v_trigger_secret IS NULL
       OR char_length(v_trigger_secret) NOT BETWEEN 32 AND 256
       OR v_trigger_secret !~ '^[A-Za-z0-9_-]+$' THEN
        RETURN NULL;
    END IF;

    RETURN net.http_post(
        url := v_worker_url,
        body := '{"source":"database"}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'X-Chat-Translation-Trigger', v_trigger_secret
        ),
        timeout_milliseconds := 5000
    );
EXCEPTION WHEN OTHERS THEN
    -- pg_net/Vault failures are repaired by the scheduled recovery wake-up.
    -- Do not expose provider or infrastructure failures to the raw-message path.
    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION private.request_chat_translation_worker()
FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION private.wake_chat_translation_worker_v1()
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

REVOKE ALL ON FUNCTION private.wake_chat_translation_worker_v1()
FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER wake_chat_translation_worker_v1
AFTER INSERT ON public.chat_translations
FOR EACH ROW
WHEN (
    NEW.status = 'queued'
    AND NEW.translator_version = 'chat-translate-v1'
)
EXECUTE FUNCTION private.wake_chat_translation_worker_v1();

DO $$
DECLARE
    v_existing_job_id BIGINT;
BEGIN
    SELECT j.jobid
    INTO v_existing_job_id
    FROM cron.job j
    WHERE j.jobname = 'chat-translation-worker-recovery'
    LIMIT 1;

    IF v_existing_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_existing_job_id);
    END IF;

    PERFORM cron.schedule(
        'chat-translation-worker-recovery',
        '* * * * *',
        'SELECT private.request_chat_translation_worker();'
    );
END;
$$;

COMMENT ON FUNCTION private.request_chat_translation_worker() IS
'C4G async worker wake-up. Reads only rollout URL/trigger secret from Vault and never chat content.';

COMMENT ON FUNCTION private.wake_chat_translation_worker_v1() IS
'C4G fail-open queue trigger; raw chat remains independent from Edge/network availability.';
