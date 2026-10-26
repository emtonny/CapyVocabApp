BEGIN;

\if :{?owner}
\else
\set owner 51111111-1111-4111-8111-111111111111
\set friend_a 52222222-2222-4222-8222-222222222222
\set friend_b 53333333-3333-4333-8333-333333333333
\set outsider 54444444-4444-4444-8444-444444444444
\set request 55000000-0000-4000-8000-000000000001
\endif

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    (:'owner', 'social-' || :'owner' || '@example.test', NOW()),
    (:'friend_a', 'social-' || :'friend_a' || '@example.test', NOW()),
    (:'friend_b', 'social-' || :'friend_b' || '@example.test', NOW()),
    (:'outsider', 'social-' || :'outsider' || '@example.test', NOW());
INSERT INTO public.users (
    id, email, display_name, username, account_role
) VALUES
    (:'owner', 'social-' || :'owner' || '@example.test', 'Owner',
     'social_' || REPLACE(LEFT(:'owner', 8), '-', ''), 'personal'),
    (:'friend_a', 'social-' || :'friend_a' || '@example.test', 'Friend A',
     'social_' || REPLACE(LEFT(:'friend_a', 8), '-', ''), 'personal'),
    (:'friend_b', 'social-' || :'friend_b' || '@example.test', 'Friend B',
     'social_' || REPLACE(LEFT(:'friend_b', 8), '-', ''), 'personal'),
    (:'outsider', 'social-' || :'outsider' || '@example.test', 'Outsider',
     'social_' || REPLACE(LEFT(:'outsider', 8), '-', ''), 'personal')
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    display_name = EXCLUDED.display_name,
    username = EXCLUDED.username,
    account_role = EXCLUDED.account_role;
INSERT INTO public.user_language_profiles (
    user_id, native_language_code, learning_language_code, proficiency_level
) VALUES
    (:'owner', 'vi', 'en', 'beginner'),
    (:'friend_a', 'en', 'vi', 'beginner'),
    (:'friend_b', 'en', 'vi', 'beginner'),
    (:'outsider', 'en', 'vi', 'beginner');
INSERT INTO public.friends(user_id, friend_id, status) VALUES
    (:'owner', :'friend_a', 'accepted'),
    (:'friend_a', :'owner', 'accepted'),
    (:'owner', :'friend_b', 'accepted'),
    (:'friend_b', :'owner', 'accepted');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config('request.jwt.claim.sub', :'owner', false);
SELECT public.create_social_chat_group(
    'Bạn học vui vẻ', ARRAY[:'friend_a'::UUID, :'friend_b'::UUID], :'request'
) AS social_conversation \gset

SELECT public.gt3_assert(
    (SELECT kind = 'social'
            AND social_owner_id = :'owner'
            AND social_title = 'Bạn học vui vẻ'
            AND learning_group_id IS NULL
            AND participant_low IS NULL
            AND participant_high IS NULL
     FROM public.chat_conversations WHERE id = :'social_conversation'),
    'personal user creates a correctly shaped social conversation'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 3 FROM public.chat_members
     WHERE conversation_id = :'social_conversation' AND left_at IS NULL),
    'social conversation contains owner and selected accepted friends'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.list_my_social_chat_groups()
     WHERE conversation_id = :'social_conversation'
       AND title = 'Bạn học vui vẻ' AND member_count = 3
       AND status = 'active'),
    'owner lists social metadata without learning group data'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 3
     FROM public.list_social_chat_group_members(
         ARRAY[:'social_conversation'::UUID]
     )),
    'active member lists the bounded public profile projection'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_social_chat_group_members(
         ARRAY[:'social_conversation'::UUID]
     )
     WHERE user_id = :'owner' AND is_owner),
    'member projection identifies exactly one social owner'
);
SELECT public.gt3_assert(
    public.create_social_chat_group(
        'Bạn học vui vẻ', ARRAY[:'friend_b'::UUID, :'friend_a'::UUID], :'request'
    ) = :'social_conversation'::UUID,
    'social creation retry is idempotent across member ordering'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.create_social_chat_group(%L,ARRAY[%L::UUID,%L::UUID],%L::UUID)',
        'Tên khác', :'friend_a', :'friend_b', :'request'
    ), '22023', 'same request with conflicting title is rejected'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.create_social_chat_group(%L,ARRAY[%L::UUID,%L::UUID],%L::UUID)',
        'Duplicate', :'friend_a', :'friend_a',
        '55000000-0000-4000-8000-000000000002'
    ), '22023', 'duplicate selected member is rejected'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.create_social_chat_group(%L,ARRAY[%L::UUID],%L::UUID)',
        'No friendship', :'outsider',
        '55000000-0000-4000-8000-000000000003'
    ), '42501', 'non-friend social member is rejected server-side'
);

SELECT set_config('request.jwt.claim.sub', :'friend_a', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_conversations
     WHERE id = :'social_conversation'),
    'selected friend reads the social conversation'
);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    '56000000-0000-4000-8000-000000000001', :'social_conversation',
    :'friend_a', 'hello social group', 'en',
    '57000000-0000-4000-8000-000000000001', NOW()
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1 FROM public.chat_operational_messages
     WHERE id = '56000000-0000-4000-8000-000000000001'),
    'selected friend sends a raw social group message'
);
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_corrections(id,message_id,author_id,target_language_code,proposed_text) VALUES (%L,%L,%L,%L,%L)',
        '58000000-0000-4000-8000-000000000001',
        '56000000-0000-4000-8000-000000000001',
        :'friend_a', 'vi', 'direct only'
    ), '42501', 'social group cannot create correction or training evidence'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.rename_social_chat_group(%L,%L)',
        :'social_conversation', 'Không được đổi'
    ), '42501', 'non-owner cannot rename social group'
);

SELECT set_config('request.jwt.claim.sub', :'friend_b', false);
SELECT public.gt3_assert(
    public.leave_social_chat_group(:'social_conversation') =
        :'social_conversation'::UUID,
    'non-owner leaves social group'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.list_my_social_chat_groups()),
    'leave removes the group from member inventory immediately'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.chat_conversations
     WHERE id = :'social_conversation'),
    'departed member loses conversation visibility'
);
SELECT public.gt3_assert(
    public.leave_social_chat_group(:'social_conversation') =
        :'social_conversation'::UUID,
    'leave retry is idempotent after visibility is revoked'
);

SELECT set_config('request.jwt.claim.sub', :'owner', false);
SELECT public.rename_social_chat_group(
    :'social_conversation', 'Nhóm beta'
);
SELECT public.gt3_assert(
    (SELECT social_title = 'Nhóm beta'
         FROM public.chat_conversations
         WHERE id = :'social_conversation'),
    'owner renames active social group'
);
SELECT public.close_social_chat_group(
    :'social_conversation'
);
SELECT public.gt3_assert(
    (SELECT social_status = 'closed'
         FROM public.chat_conversations
         WHERE id = :'social_conversation'),
    'owner closes social group without deleting history'
);
SELECT public.gt3_assert(
    public.close_social_chat_group(:'social_conversation') =
        :'social_conversation'::UUID,
    'close retry is idempotent'
);
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_operational_messages(id,conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,%L,%L,%L,%L,NOW())',
        '56000000-0000-4000-8000-000000000003', :'social_conversation',
        :'owner', 'closed', 'vi',
        '57000000-0000-4000-8000-000000000003'
    ), '42501', 'closed social group rejects new messages'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.leave_social_chat_group(%L)', :'social_conversation'
    ), '42501', 'social owner must close instead of leaving'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 2
     FROM public.list_social_chat_group_members(
         ARRAY[:'social_conversation'::UUID]
     )),
    'member projection excludes departed members'
);

SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.chat_conversations
     WHERE id = :'social_conversation'),
    'outsider cannot read social conversation'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 0 FROM public.list_my_social_chat_groups()),
    'outsider social inventory is empty'
);
SELECT public.gt3_expect_error(
    format(
        'INSERT INTO public.chat_operational_messages(id,conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,%L,%L,%L,%L,NOW())',
        '56000000-0000-4000-8000-000000000002', :'social_conversation',
        :'outsider', 'forbidden', 'en',
        '57000000-0000-4000-8000-000000000002'
    ), '42501', 'outsider cannot send into social conversation'
);

RESET ROLE;
SELECT EXISTS(
    SELECT 1 FROM pg_roles WHERE rolname = 'postgres'
) AS has_postgres_role \gset
\if :has_postgres_role
SET ROLE postgres;
\endif
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 3 FROM private.social_chat_group_audit
     WHERE conversation_id = :'social_conversation'
       AND action IN ('rename', 'close', 'leave')),
    'social lifecycle writes one audit event per state change'
);
SET ROLE service_role;
SELECT set_config('request.jwt.claim.role', 'service_role', false);
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT translation_id AS claimed_translation
FROM public.claim_chat_translation('chat-translate-v3') \gset
SELECT public.gt3_assert(
    :'claimed_translation'::UUID IS NOT NULL,
    'social raw message remains eligible for display translation'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config('request.jwt.claim.sub', :'owner', false);
SELECT public.open_direct_chat(:'friend_a') AS direct_conversation \gset
SELECT public.gt3_assert(
    (SELECT kind = 'direct' AND social_owner_id IS NULL
            AND social_title IS NULL AND social_creation_request_id IS NULL
     FROM public.chat_conversations WHERE id = :'direct_conversation'),
    'direct chat remains compatible after social group migration'
);

ROLLBACK;
