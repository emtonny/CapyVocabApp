-- C4G wake-up tests continue in the same isolated cluster as the C4B suite.
SELECT public.c4b_assert(
    (SELECT count(*) = 1
     FROM cron.job
     WHERE jobname = 'chat-translation-worker-recovery'
       AND schedule = '* * * * *'
       AND command = 'SELECT private.request_chat_translation_worker();'
       AND active),
    'one fixed once-per-minute translation recovery job exists'
);

SELECT public.c4b_assert(
    NOT has_function_privilege(
        'anon', 'private.request_chat_translation_worker()', 'EXECUTE'
    )
    AND NOT has_function_privilege(
        'authenticated', 'private.request_chat_translation_worker()', 'EXECUTE'
    )
    AND NOT has_function_privilege(
        'service_role', 'private.request_chat_translation_worker()', 'EXECUTE'
    )
    AND NOT has_function_privilege(
        'authenticated', 'private.wake_chat_translation_worker_v2()', 'EXECUTE'
    ),
    'clients and service role cannot invoke private wake-up functions'
);

SELECT public.c4b_assert(
    (SELECT count(*) = 0 FROM net.http_request_log),
    'missing Vault configuration produces no network request'
);

INSERT INTO vault.decrypted_secrets(name, decrypted_secret) VALUES
    (
        'chat_translation_worker_url',
        'https://nxteaznowkfennxpqjmt.supabase.co/functions/v1/chat-translation-worker'
    ),
    (
        'chat_translation_trigger_secret',
        'local_C4G_trigger_secret_0123456789'
    );

UPDATE public.chat_members
SET left_at = NULL
WHERE conversation_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  AND user_id = '22222222-2222-4222-8222-222222222222';

SET ROLE authenticated;
SELECT set_config(
    'request.jwt.claim.sub',
    '11111111-1111-4111-8111-111111111111',
    false
);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    '12121212-1212-4212-8212-121212121212',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    'C4G wake-up raw content must not enter the request',
    'vi',
    '13131313-1313-4313-8313-131313131313',
    NOW()
);
RESET ROLE;

SELECT public.c4b_assert(
    (SELECT count(*) = 1
     FROM public.chat_translations
     WHERE message_id = '12121212-1212-4212-8212-121212121212'
       AND status = 'queued'
       AND attempt_count = 0),
    'raw insert still creates one untouched queue row before provider work'
);

SELECT public.c4b_assert(
    (SELECT count(*) = 1
        AND bool_and(
            url = 'https://nxteaznowkfennxpqjmt.supabase.co/functions/v1/chat-translation-worker'
            AND body = '{"source":"database"}'::jsonb
            AND params = '{}'::jsonb
            AND headers->>'Content-Type' = 'application/json'
            AND headers->>'X-Chat-Translation-Trigger' =
                'local_C4G_trigger_secret_0123456789'
            AND timeout_milliseconds = 5000
            AND body::text NOT LIKE '%wake-up raw content%'
        )
     FROM net.http_request_log),
    'enqueue emits one metadata-only authenticated pg_net request'
);

SELECT private.request_chat_translation_worker();
SELECT public.c4b_assert(
    (SELECT count(*) = 2 FROM net.http_request_log),
    'scheduled recovery uses the same idempotent worker wake-up'
);

UPDATE vault.decrypted_secrets
SET decrypted_secret = 'too-short'
WHERE name = 'chat_translation_trigger_secret';
SELECT private.request_chat_translation_worker();
SELECT public.c4b_assert(
    (SELECT count(*) = 2 FROM net.http_request_log),
    'malformed Vault trigger secret fails closed without a request'
);

SET ROLE authenticated;
SELECT set_config(
    'request.jwt.claim.sub',
    '11111111-1111-4111-8111-111111111111',
    false
);
SELECT public.c4b_expect_error(
    'INSERT INTO public.chat_operational_messages(id,conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (gen_random_uuid(),''aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'',''11111111-1111-4111-8111-111111111111'',''duplicate wake-up'',''vi'',''13131313-1313-4313-8313-131313131313'',NOW())',
    '23505',
    'duplicate raw retry cannot enqueue or wake the worker twice'
);
RESET ROLE;

SELECT public.c4b_assert(
    (SELECT count(*) = 1
     FROM public.chat_translations
     WHERE message_id = '12121212-1212-4212-8212-121212121212')
    AND (SELECT count(*) = 2 FROM net.http_request_log),
    'duplicate raw retry preserves one queue row and request count'
);
