-- Synthetic row created before C4B. The migration must not backfill it.
INSERT INTO public.users(id) VALUES
    ('11111111-1111-4111-8111-111111111111'),
    ('22222222-2222-4222-8222-222222222222'),
    ('33333333-3333-4333-8333-333333333333');
INSERT INTO public.user_language_profiles(
    user_id, native_language_code, learning_language_code
) VALUES
    ('11111111-1111-4111-8111-111111111111', 'vi', 'en'),
    ('22222222-2222-4222-8222-222222222222', 'en', 'vi');
INSERT INTO public.chat_conversations(id, participant_low, participant_high)
VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    '22222222-2222-4222-8222-222222222222'
);
INSERT INTO public.chat_members(conversation_id, user_id) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111'),
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '22222222-2222-4222-8222-222222222222');
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    '44444444-4444-4444-8444-444444444444',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '11111111-1111-4111-8111-111111111111',
    'Synthetic pre-C4B raw message',
    'vi',
    '44444444-4444-4444-9444-444444444444',
    '2000-01-01'
);
