\set v3_message '15151515-1515-4515-8515-151515151515'

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
    :'v3_message', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    'Gemini v3 synthetic translation', 'vi', gen_random_uuid(), NOW()
);
RESET ROLE;

SELECT public.c4b_assert(
    (SELECT COUNT(*) = 1
        AND bool_and(translator_version = 'chat-translate-v3')
        AND bool_and(provider = 'gemini')
        AND bool_and(model = 'gemini-3-flash-preview')
        AND bool_and(prompt_version = 'chat-translate-p3')
        AND bool_and(status = 'queued')
     FROM public.chat_translations WHERE message_id = :'v3_message'),
    'v3 enqueue stores the native Gemini policy snapshot'
);
SELECT public.c4b_assert(
    (SELECT COUNT(*) = 0 FROM public.chat_translations
     WHERE message_id = :'v3_message'
       AND translator_version = 'chat-translate-v2'),
    'v3 enqueue does not create a new Vilao job'
);

SET ROLE service_role;
SELECT public.c4b_expect_error(
    'SELECT * FROM public.claim_chat_translation(''chat-translate-v2'')',
    '22023',
    'v3 claim rejects the retired translator version'
);
SELECT raw_text AS v3_raw, provider AS v3_provider, model AS v3_model,
       prompt_version AS v3_prompt, translator_version AS v3_version,
       translation_id AS v3_translation, claim_token AS v3_token
FROM public.claim_chat_translation('chat-translate-v3') \gset
SELECT public.complete_chat_translation(
    :'v3_translation', :'v3_token', 'Gemini v3 translated text'
);
RESET ROLE;

SELECT public.c4b_assert(
    :'v3_raw' = 'Gemini v3 synthetic translation'
    AND :'v3_provider' = 'gemini'
    AND :'v3_model' = 'gemini-3-flash-preview'
    AND :'v3_prompt' = 'chat-translate-p3'
    AND :'v3_version' = 'chat-translate-v3',
    'v3 claim returns the locked native Gemini contract'
);
SELECT public.c4b_assert(
    (SELECT status = 'succeeded'
        AND translated_text = 'Gemini v3 translated text'
        AND attempt_count = 1
        AND error_code IS NULL
     FROM public.chat_translations WHERE id = :'v3_translation'),
    'v3 completion preserves the existing single-flight state machine'
);
SELECT public.c4b_assert(
    EXISTS (
        SELECT 1 FROM public.chat_translations
        WHERE translator_version = 'chat-translate-v2'
    ),
    'immutable v2 history remains readable after v3 activation'
);
