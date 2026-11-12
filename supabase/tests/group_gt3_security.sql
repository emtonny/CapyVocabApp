BEGIN;
\set teacher 11111111-1111-4111-8111-111111111111
\set student 22222222-2222-4222-8222-222222222222
\set outsider 33333333-3333-4333-8333-333333333333
\set direct_peer 44444444-4444-4444-8444-444444444444

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    (:'teacher', 'teacher@example.test', NOW()),
    (:'student', 'student@example.test', NOW()),
    (:'outsider', 'outsider@example.test', NOW()),
    (:'direct_peer', 'peer@example.test', NOW());
INSERT INTO public.users (
    id, email, display_name, username, account_role
) VALUES
    (:'teacher', 'teacher@example.test', 'Teacher', 'gt3_teacher', 'teacher'),
    (:'student', 'student@example.test', 'Student', 'gt3_student', 'personal'),
    (:'outsider', 'outsider@example.test', 'Outsider', 'gt3_outsider', 'personal'),
    (:'direct_peer', 'peer@example.test', 'Peer', 'gt3_peer', 'personal');
INSERT INTO public.user_language_profiles (
    user_id, native_language_code, learning_language_code, proficiency_level
) VALUES
    (:'teacher', 'vi', 'en', 'beginner'),
    (:'student', 'en', 'vi', 'beginner'),
    (:'outsider', 'en', 'vi', 'beginner'),
    (:'direct_peer', 'en', 'vi', 'beginner');

SET ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT public.set_teacher_verification(:'teacher', 'verified', 'gt3_test');
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.create_learning_group(
    'GT3 private class', 'Group chat security test',
    '70000000-0000-4000-8000-000000000001'
) AS group_id \gset

SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1
     FROM public.chat_conversations
     WHERE kind = 'group' AND learning_group_id = :'group_id'
       AND participant_low IS NULL AND participant_high IS NULL),
    'group creation creates exactly one shaped group conversation'
);
SELECT id AS group_conversation
FROM public.chat_conversations
WHERE learning_group_id = :'group_id' \gset
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_members
     WHERE conversation_id = :'group_conversation'
       AND user_id = :'teacher' AND left_at IS NULL),
    'owner membership is synchronized into group chat members'
);

RESET ROLE;
INSERT INTO public.learning_group_members(
    group_id, user_id, role, status, joined_at
) VALUES (:'group_id', :'student', 'student', 'active', NOW());
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_members
     WHERE conversation_id = :'group_conversation'
       AND user_id = :'student' AND left_at IS NULL),
    'active student membership is synchronized into chat members'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_conversations
     WHERE id = :'group_conversation'),
    'active student reads the group conversation without friendship'
);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    '80000000-0000-4000-8000-000000000001', :'group_conversation',
    :'student', 'hello group', 'en',
    '81000000-0000-4000-8000-000000000001', NOW()
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_operational_messages
     WHERE conversation_id = :'group_conversation'),
    'active unmuted student sends a raw group message'
);

RESET ROLE;
SET ROLE service_role;
SELECT raw_text AS claimed_raw, translation_id AS claimed_translation
FROM public.claim_chat_translation('chat-translate-v3') \gset
RESET ROLE;
SELECT public.gt3_assert(
    :'claimed_raw' = 'hello group'
    AND CHAR_LENGTH(:'claimed_translation') = 36,
    'translation worker claims a group message with more than two members'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_corrections(id,message_id,author_id,target_language_code,proposed_text) VALUES (%L,%L,%L,''vi'',''blocked group correction'')',
        '82000000-0000-4000-8000-000000000001',
        '80000000-0000-4000-8000-000000000001', :'teacher'
    ),
    '42501',
    'group chat rejects the direct-only correction contract'
);

RESET ROLE;
SET ROLE service_role;
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_corrections(id,message_id,author_id,target_language_code,proposed_text) VALUES (%L,%L,%L,''vi'',''service bypass attempt'')',
        '82000000-0000-4000-8000-000000000002',
        '80000000-0000-4000-8000-000000000001', :'teacher'
    ),
    '42501',
    'group correction trigger also blocks trusted-role bypass'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_translations
     WHERE message_id = '80000000-0000-4000-8000-000000000001'
       AND status = 'processing'),
    'group member reads shared translation through existing RLS'
);

SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.chat_conversations
     WHERE id = :'group_conversation')
    AND (SELECT COUNT(*) = 0 FROM public.chat_operational_messages
         WHERE conversation_id = :'group_conversation'),
    'outsider reads neither group conversation nor message'
);

SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.set_learning_group_member_mute(
    :'group_id', :'student', TRUE,
    '70000000-0000-4000-8000-000000000002', 'class_rule'
);
SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_operational_messages(id,conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,%L,''muted send'',''en'',%L,NOW())',
        '80000000-0000-4000-8000-000000000002', :'group_conversation',
        :'student', '81000000-0000-4000-8000-000000000002'
    ),
    '42501',
    'muted student cannot send group messages'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_operational_messages
     WHERE id = '80000000-0000-4000-8000-000000000001'),
    'muted student retains read access to group history'
);

SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.moderate_learning_group_message(
    :'group_id', '80000000-0000-4000-8000-000000000001', 'hidden',
    '70000000-0000-4000-8000-000000000003', 'class_rule'
);
SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.chat_operational_messages
     WHERE id = '80000000-0000-4000-8000-000000000001'),
    'owner moderation hides a group message from active students'
);
SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.moderate_learning_group_message(%L,%L,''visible'',%L,NULL)',
        :'group_id', '80000000-0000-4000-8000-000000000001',
        '70000000-0000-4000-8000-000000000004'
    ),
    '42501',
    'outsider cannot moderate group messages'
);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.moderate_learning_group_message(
    :'group_id', '80000000-0000-4000-8000-000000000001', 'visible',
    '70000000-0000-4000-8000-000000000005', NULL
);
RESET ROLE;
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 2 FROM private.learning_group_moderation_events
     WHERE group_id = :'group_id'
       AND action IN ('message_hidden', 'message_restored')),
    'group message visibility changes append immutable moderation audit'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.archive_learning_group(
    :'group_id', '70000000-0000-4000-8000-000000000006'
);
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_operational_messages(id,conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,%L,''archived send'',''vi'',%L,NOW())',
        '80000000-0000-4000-8000-000000000003', :'group_conversation',
        :'teacher', '81000000-0000-4000-8000-000000000003'
    ),
    '42501',
    'archived group chat is read-only'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_conversations
     WHERE id = :'group_conversation')
    AND (SELECT COUNT(*) = 1 FROM public.chat_operational_messages
         WHERE id = '80000000-0000-4000-8000-000000000001'),
    'archived active members retain group chat history'
);

RESET ROLE;
INSERT INTO public.friends(user_id, friend_id, status) VALUES
    (:'teacher', :'direct_peer', 'accepted'),
    (:'direct_peer', :'teacher', 'accepted');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.open_direct_chat(:'direct_peer') AS direct_conversation \gset
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    '80000000-0000-4000-8000-000000000010', :'direct_conversation',
    :'teacher', 'direct regression', 'vi',
    '81000000-0000-4000-8000-000000000010', NOW()
);
SELECT set_config('request.jwt.claim.sub', :'direct_peer', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    '82000000-0000-4000-8000-000000000010',
    '80000000-0000-4000-8000-000000000010', :'direct_peer', 'en',
    'direct correction still works'
);
SELECT public.gt3_assert(
    (SELECT kind = 'direct' AND learning_group_id IS NULL
     FROM public.chat_conversations WHERE id = :'direct_conversation')
    AND (SELECT COUNT(*) = 1 FROM public.chat_corrections
         WHERE id = '82000000-0000-4000-8000-000000000010'),
    'direct open send and correction behavior remains available'
);

RESET ROLE;
UPDATE public.learning_group_members
SET status = 'removed', ended_at = NOW(), updated_at = NOW()
WHERE group_id = :'group_id' AND user_id = :'student';
SELECT public.gt3_assert(
    (SELECT left_at IS NOT NULL FROM public.chat_members
     WHERE conversation_id = :'group_conversation' AND user_id = :'student'),
    'removed membership closes the mirrored chat member in the same transaction'
);
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.chat_conversations
     WHERE id = :'group_conversation')
    AND (SELECT COUNT(*) = 0 FROM public.chat_operational_messages
         WHERE conversation_id = :'group_conversation'),
    'removed student immediately loses group chat read access'
);

ROLLBACK;
