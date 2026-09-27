-- C4B queue/claim tests use synthetic data in an isolated PostgreSQL cluster.
CREATE EXTENSION dblink;

CREATE FUNCTION public.c4b_assert(p_condition BOOLEAN, p_label TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF p_condition IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'C4B assertion failed: %', p_label;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;

CREATE FUNCTION public.c4b_expect_error(
    p_sql TEXT,
    p_state TEXT,
    p_label TEXT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_state TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS DISTINCT FROM p_state THEN
        RAISE EXCEPTION 'C4B expected error failed: %, expected %, got %',
            p_label, p_state, v_state;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;

\set a 11111111-1111-4111-8111-111111111111
\set b 22222222-2222-4222-8222-222222222222
\set outsider 33333333-3333-4333-8333-333333333333
\set conversation aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
\set pre_message 44444444-4444-4444-8444-444444444444
\set good_message 55555555-5555-4555-8555-555555555555
\set policy_message 44444444-4444-4444-8444-444444444444
\set hidden_message 66666666-6666-4666-8666-666666666666
\set deleted_message 77777777-7777-4777-8777-777777777777
\set retry_message 88888888-8888-4888-8888-888888888888
\set rate_message 99999999-9999-4999-8999-999999999999
\set concurrent_message bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb
\set inactive_message cccccccc-cccc-4ccc-8ccc-cccccccccccc
\set auth_message dddddddd-dddd-4ddd-8ddd-dddddddddddd
\set correction eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee

SELECT public.c4b_assert(
    (SELECT count(*) = 4
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'chat_translations'
       AND column_name IN (
           'claim_token', 'lease_expires_at', 'last_attempt_at', 'updated_at'
       )),
    'C4B adds the four lease columns'
);
SELECT public.c4b_assert(
    to_regclass('private.chat_translation_provider_state') IS NOT NULL
    AND to_regclass('public.chat_translations_processing_lease') IS NOT NULL,
    'private circuit state and processing recovery index exist'
);
SELECT public.c4b_assert(
    (SELECT count(*) = 0 FROM public.chat_translations
     WHERE message_id = :'pre_message'),
    'pre-C4B raw messages are not backfilled'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'good_message', :'conversation', :'a', 'Xin chào C4B', 'vi',
    '55555555-5555-4555-9555-555555555555', NOW()
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT count(*) = 1
        AND bool_and(target_language_code = 'en')
        AND bool_and(translator_version = 'chat-translate-v2')
        AND bool_and(provider = 'vilao')
        AND bool_and(model = 'gemini-3.8-flash')
        AND bool_and(prompt_version = 'chat-translate-p2')
        AND bool_and(status = 'queued')
        AND bool_and(attempt_count = 0)
     FROM public.chat_translations WHERE message_id = :'good_message'),
    'raw insert enqueues one fixed-policy opposite-language job'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c4b_expect_error(
    format(
        'INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''duplicate wake-up'',''vi'',''55555555-5555-4555-9555-555555555555'',NOW())',
        :'conversation', :'a'
    ),
    '23505',
    'duplicate raw retry is rejected before another queue row'
);
SELECT public.c4b_expect_error(
    'SELECT * FROM public.claim_chat_translation(''chat-translate-v2'')',
    '42501',
    'authenticated client cannot claim jobs'
);
SELECT public.c4b_expect_error(
    format(
        'INSERT INTO public.chat_translations(message_id,target_language_code,translator_version) VALUES (%L,''en'',''client-forged'')',
        :'good_message'
    ),
    '42501',
    'authenticated client cannot enqueue translations'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT count(*) = 1 FROM public.chat_translations
     WHERE message_id = :'good_message'),
    'duplicate trigger path leaves one unique queue row'
);

SET ROLE service_role;
SELECT public.c4b_expect_error(
    'SELECT * FROM private.chat_translation_provider_state',
    '42501',
    'service role cannot read private circuit state directly'
);
SELECT public.c4b_expect_error(
    format(
        'UPDATE public.chat_translations SET attempt_count=1 WHERE message_id=%L',
        :'good_message'
    ),
    '42501',
    'service role direct mutation must use trusted RPCs'
);
SELECT public.c4b_expect_error(
    'SELECT * FROM public.claim_chat_translation(''unknown-version'')',
    '22023',
    'claim rejects an unknown translator version'
);
SELECT translation_id AS id, claim_token AS token, attempt_count AS attempt,
       lease_expires_at AS lease
FROM public.claim_chat_translation('chat-translate-v2') \gset good_first_
SELECT public.c4b_assert(
    :'good_first_attempt'::integer = 1
    AND :'good_first_lease'::timestamptz > clock_timestamp(),
    'first claim issues a live lease and increments attempt once'
);
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'active lease blocks a duplicate claim without another attempt'
);
RESET ROLE;

UPDATE public.chat_translations
SET lease_expires_at = clock_timestamp() - INTERVAL '1 second'
WHERE id = :'good_first_id';
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token, attempt_count AS attempt
FROM public.claim_chat_translation('chat-translate-v2') \gset good_second_
SELECT public.c4b_assert(
    :'good_second_id'::uuid = :'good_first_id'::uuid
    AND :'good_second_token'::uuid <> :'good_first_token'::uuid
    AND :'good_second_attempt'::integer = 2,
    'expired lease is reclaimed with a new token'
);
SELECT public.c4b_expect_error(
    format(
        'SELECT public.complete_chat_translation(%L,%L,''stale output'')',
        :'good_first_id', :'good_first_token'
    ),
    '55000',
    'stale token cannot complete a reclaimed job'
);
SELECT public.c4b_expect_error(
    format(
        'SELECT public.fail_chat_translation(%L,%L,''PROVIDER_TIMEOUT'')',
        :'good_first_id', :'good_first_token'
    ),
    '55000',
    'stale token cannot fail a reclaimed job'
);
SELECT public.c4b_expect_error(
    format(
        'SELECT public.complete_chat_translation(%L,%L,''   '')',
        :'good_second_id', :'good_second_token'
    ),
    '22023',
    'blank translated output is rejected'
);
SELECT public.c4b_expect_error(
    format(
        'SELECT public.fail_chat_translation(%L,%L,''UNMAPPED_PROVIDER_ERROR'')',
        :'good_second_id', :'good_second_token'
    ),
    '22023',
    'unmapped provider failure code is rejected without changing the claim'
);
SELECT public.c4b_assert(
    public.complete_chat_translation(
        :'good_second_id', :'good_second_token', 'Hello C4B'
    ),
    'current token completes a valid translation'
);
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'successful translation is never claimed again'
);
RESET ROLE;
SELECT public.c4b_expect_error(
    format(
        'UPDATE public.chat_translations SET translated_text=''rewritten'' WHERE id=%L',
        :'good_second_id'
    ),
    '22023',
    'successful output stays immutable for the table owner'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.c4b_assert(
    (SELECT count(*) = 1 FROM public.chat_translations
     WHERE id = :'good_second_id' AND translated_text = 'Hello C4B'),
    'active peer reads the shared successful row'
);
SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.c4b_assert(
    (SELECT count(*) = 0 FROM public.chat_translations),
    'outsider cannot read translation jobs or output'
);
RESET ROLE;

INSERT INTO public.chat_translations(
    message_id, target_language_code, translator_version,
    provider, model, prompt_version
) VALUES (
    :'policy_message', 'en', 'chat-translate-v2',
    'gemini', 'wrong-model', 'chat-translate-p2'
);
SET ROLE service_role;
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'policy mismatch returns no provider-eligible claim'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT status = 'failed' AND error_code = 'POLICY_MISMATCH'
     FROM public.chat_translations WHERE message_id = :'policy_message'),
    'policy mismatch terminates without consuming an attempt'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'hidden_message', :'conversation', :'a', 'hidden fixture', 'vi',
    gen_random_uuid(), NOW()
), (
    :'deleted_message', :'conversation', :'a', 'deleted fixture', 'vi',
    gen_random_uuid(), NOW()
);
RESET ROLE;
UPDATE public.chat_operational_messages
SET moderation_state = 'held' WHERE id = :'hidden_message';
UPDATE public.chat_operational_messages
SET deleted_at = clock_timestamp() WHERE id = :'deleted_message';
SET ROLE service_role;
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'held message is terminal and never returned to a worker'
);
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'deleted message is terminal and never returned to a worker'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT count(*) = 2 FROM public.chat_translations
     WHERE message_id IN (:'hidden_message', :'deleted_message')
       AND status = 'failed'
       AND error_code = 'MESSAGE_INELIGIBLE'
       AND attempt_count = 0),
    'held and deleted jobs fail without provider attempts'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'retry_message', :'conversation', :'a', 'retry fixture', 'vi',
    gen_random_uuid(), NOW()
);
RESET ROLE;
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token
FROM public.claim_chat_translation('chat-translate-v2') \gset retry_one_
SELECT public.fail_chat_translation(
    :'retry_one_id', :'retry_one_token', 'PROVIDER_TIMEOUT'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT error_code = 'PROVIDER_TIMEOUT'
        AND next_attempt_at BETWEEN clock_timestamp() + INTERVAL '3 seconds'
                                AND clock_timestamp() + INTERVAL '7 seconds'
     FROM public.chat_translations WHERE id = :'retry_one_id'),
    'attempt one schedules the exact five-second retry tier'
);
UPDATE public.chat_translations SET next_attempt_at = clock_timestamp() - INTERVAL '1 second'
WHERE id = :'retry_one_id';
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token
FROM public.claim_chat_translation('chat-translate-v2') \gset retry_two_
SELECT public.fail_chat_translation(
    :'retry_two_id', :'retry_two_token', 'PROVIDER_NETWORK'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT attempt_count = 2
        AND next_attempt_at BETWEEN clock_timestamp() + INTERVAL '28 seconds'
                                AND clock_timestamp() + INTERVAL '32 seconds'
     FROM public.chat_translations WHERE id = :'retry_two_id'),
    'attempt two schedules the exact thirty-second retry tier'
);
UPDATE public.chat_translations SET next_attempt_at = clock_timestamp() - INTERVAL '1 second'
WHERE id = :'retry_two_id';
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token
FROM public.claim_chat_translation('chat-translate-v2') \gset retry_three_
SELECT public.fail_chat_translation(
    :'retry_three_id', :'retry_three_token', 'MALFORMED_RESPONSE'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT consecutive_failure_count = 3
        AND open_until BETWEEN clock_timestamp() + INTERVAL '28 seconds'
                           AND clock_timestamp() + INTERVAL '32 seconds'
     FROM private.chat_translation_provider_state
     WHERE translator_version = 'chat-translate-v2'),
    'third transient failure opens the circuit for thirty seconds'
);
UPDATE public.chat_translations SET next_attempt_at = clock_timestamp() - INTERVAL '1 second'
WHERE id = :'retry_three_id';
SET ROLE service_role;
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'open circuit returns no claim'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT attempt_count = 3 FROM public.chat_translations
     WHERE id = :'retry_three_id'),
    'circuit-open wake-up consumes no attempt'
);
UPDATE private.chat_translation_provider_state
SET open_until = clock_timestamp() - INTERVAL '1 second'
WHERE translator_version = 'chat-translate-v2';
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token
FROM public.claim_chat_translation('chat-translate-v2') \gset retry_four_
SELECT public.fail_chat_translation(
    :'retry_four_id', :'retry_four_token', 'PROVIDER_UNAVAILABLE'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT status = 'failed'
        AND attempt_count = 4
        AND error_code = 'RETRY_EXHAUSTED'
        AND next_attempt_at IS NULL
     FROM public.chat_translations WHERE id = :'retry_four_id'),
    'fourth transient failure terminates at the provider-attempt cap'
);

UPDATE private.chat_translation_provider_state
SET consecutive_failure_count = 0, open_until = NULL, updated_at = clock_timestamp()
WHERE translator_version = 'chat-translate-v2';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'rate_message', :'conversation', :'a', 'quota fixture', 'vi',
    gen_random_uuid(), NOW()
);
RESET ROLE;
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token
FROM public.claim_chat_translation('chat-translate-v2') \gset rate_
SELECT public.fail_chat_translation(
    :'rate_id', :'rate_token', 'PROVIDER_RATE_LIMITED', 400
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT error_code = 'PROVIDER_RATE_LIMITED'
        AND next_attempt_at BETWEEN clock_timestamp() + INTERVAL '298 seconds'
                                AND clock_timestamp() + INTERVAL '302 seconds'
     FROM public.chat_translations WHERE id = :'rate_id')
    AND
    (SELECT open_until BETWEEN clock_timestamp() + INTERVAL '298 seconds'
                           AND clock_timestamp() + INTERVAL '302 seconds'
     FROM private.chat_translation_provider_state
     WHERE translator_version = 'chat-translate-v2'),
    'provider Retry-After and circuit duration are capped at five minutes'
);

UPDATE private.chat_translation_provider_state
SET consecutive_failure_count = 0, open_until = NULL, updated_at = clock_timestamp()
WHERE translator_version = 'chat-translate-v2';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'auth_message', :'conversation', :'a', 'auth failure fixture', 'vi',
    gen_random_uuid(), NOW()
);
RESET ROLE;
SET ROLE service_role;
SELECT translation_id AS id, claim_token AS token
FROM public.claim_chat_translation('chat-translate-v2') \gset auth_
SELECT public.fail_chat_translation(
    :'auth_id', :'auth_token', 'PROVIDER_AUTH_DENIED'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT status = 'failed'
        AND error_code = 'PROVIDER_AUTH_DENIED'
        AND next_attempt_at IS NULL
     FROM public.chat_translations WHERE id = :'auth_id')
    AND
    (SELECT open_until BETWEEN clock_timestamp() + INTERVAL '298 seconds'
                           AND clock_timestamp() + INTERVAL '302 seconds'
     FROM private.chat_translation_provider_state
     WHERE translator_version = 'chat-translate-v2'),
    'provider authentication denial is terminal and opens a five-minute circuit'
);

UPDATE private.chat_translation_provider_state
SET consecutive_failure_count = 0, open_until = NULL, updated_at = clock_timestamp()
WHERE translator_version = 'chat-translate-v2';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'concurrent_message', :'conversation', :'a', 'concurrency fixture', 'vi',
    gen_random_uuid(), NOW()
);
RESET ROLE;

SELECT dblink_connect('c4b_worker_1', :'test_connstr');
SELECT dblink_connect('c4b_worker_2', :'test_connstr');
SELECT dblink_exec('c4b_worker_1', 'BEGIN');
SELECT dblink_exec('c4b_worker_1', 'SET ROLE service_role');
SELECT dblink_exec('c4b_worker_2', 'BEGIN');
SELECT dblink_exec('c4b_worker_2', 'SET ROLE service_role');
CREATE TEMP TABLE c4b_first_worker_claim(translation_id TEXT);
INSERT INTO c4b_first_worker_claim
SELECT translation_id
FROM dblink(
    'c4b_worker_1',
    'SELECT translation_id::text FROM public.claim_chat_translation(''chat-translate-v2'')'
) AS claimed(translation_id TEXT);
SELECT public.c4b_assert(
    (SELECT count(*) = 1 FROM c4b_first_worker_claim),
    'first concurrent worker claims the only due job'
);
SELECT public.c4b_assert(
    (SELECT claimed_count = 0
     FROM dblink(
         'c4b_worker_2',
         'SELECT count(*)::integer AS claimed_count FROM public.claim_chat_translation(''chat-translate-v2'')'
     ) AS second_worker(claimed_count INTEGER)),
    'second concurrent worker skips the locked job'
);
SELECT dblink_exec('c4b_worker_1', 'COMMIT');
SELECT dblink_exec('c4b_worker_2', 'COMMIT');
SELECT dblink_disconnect('c4b_worker_1');
SELECT dblink_disconnect('c4b_worker_2');
SELECT public.c4b_assert(
    (SELECT status = 'processing' AND attempt_count = 1
     FROM public.chat_translations WHERE message_id = :'concurrent_message'),
    'concurrent claim produces one processing row and one attempt'
);
SELECT id AS id, claim_token AS token
FROM public.chat_translations WHERE message_id = :'concurrent_message' \gset concurrent_
SET ROLE service_role;
SELECT public.complete_chat_translation(
    :'concurrent_id', :'concurrent_token', 'Concurrent success'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT consecutive_failure_count = 0 AND open_until IS NULL
     FROM private.chat_translation_provider_state
     WHERE translator_version = 'chat-translate-v2'),
    'validated success resets provider circuit state'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    :'correction', :'good_message', :'b', 'en',
    'Independent human correction remains separate'
);
SELECT public.c4b_expect_error(
    format(
        'UPDATE public.chat_corrections SET status=''accepted'',accepted_by=%L,accepted_at=NOW() WHERE id=%L',
        :'a', :'correction'
    ),
    '42501',
    'client still cannot forge correction acceptance'
);
RESET ROLE;
SET ROLE service_role;
UPDATE public.chat_corrections
SET status = 'accepted', accepted_by = :'a', accepted_at = clock_timestamp()
WHERE id = :'correction';
SELECT public.c4b_expect_error(
    format(
        'UPDATE public.chat_corrections SET proposed_text=''rewritten'' WHERE id=%L',
        :'correction'
    ),
    '22023',
    'C4B keeps accepted human correction content immutable'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT status = 'accepted'
        AND proposed_text = 'Independent human correction remains separate'
     FROM public.chat_corrections WHERE id = :'correction'),
    'C2 correction state machine remains intact after C4B'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'inactive_message', :'conversation', :'a', 'inactive member fixture', 'vi',
    gen_random_uuid(), NOW()
);
RESET ROLE;
UPDATE public.chat_members SET left_at = clock_timestamp()
WHERE conversation_id = :'conversation' AND user_id = :'b';
SET ROLE service_role;
SELECT public.c4b_assert(
    (SELECT count(*) = 0
     FROM public.claim_chat_translation('chat-translate-v2')),
    'inactive conversation returns no provider-eligible claim'
);
RESET ROLE;
SELECT public.c4b_assert(
    (SELECT status = 'failed'
        AND error_code = 'MESSAGE_INELIGIBLE'
        AND attempt_count = 0
     FROM public.chat_translations WHERE message_id = :'inactive_message'),
    'inactive conversation terminates without a provider attempt'
);
SELECT public.c4b_assert(
    (SELECT raw_text = 'inactive member fixture'
     FROM public.chat_operational_messages WHERE id = :'inactive_message'),
    'queue failure never mutates authoritative raw text'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.c4b_assert(
    (SELECT count(*) = 0 FROM public.chat_translations),
    'inactive member loses translation visibility'
);
RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.c4b_expect_error(
    'SELECT * FROM public.claim_chat_translation(''chat-translate-v2'')',
    '42501',
    'anonymous caller cannot invoke claim RPC'
);
RESET ROLE;

SELECT public.c4b_assert(
    has_function_privilege(
        'service_role', 'public.claim_chat_translation(text)', 'EXECUTE'
    )
    AND has_function_privilege(
        'service_role',
        'public.complete_chat_translation(uuid,uuid,text)',
        'EXECUTE'
    )
    AND has_function_privilege(
        'service_role',
        'public.fail_chat_translation(uuid,uuid,text,integer)',
        'EXECUTE'
    )
    AND NOT has_function_privilege(
        'authenticated', 'public.claim_chat_translation(text)', 'EXECUTE'
    ),
    'only service role receives translation state-transition RPC authority'
);
