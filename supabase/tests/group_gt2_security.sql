BEGIN;
\set teacher_a 11111111-1111-4111-8111-111111111111
\set teacher_b 22222222-2222-4222-8222-222222222222
\set teacher_pending 33333333-3333-4333-8333-333333333333
\set student_a 44444444-4444-4444-8444-444444444444
\set student_b 55555555-5555-4555-8555-555555555555
\set outsider 66666666-6666-4666-8666-666666666666

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    (:'teacher_a', 'teacher-a@example.test', NOW()),
    (:'teacher_b', 'teacher-b@example.test', NOW()),
    (:'teacher_pending', 'teacher-pending@example.test', NOW()),
    (:'student_a', 'student-a@example.test', NOW()),
    (:'student_b', 'student-b@example.test', NOW()),
    (:'outsider', 'outsider@example.test', NOW());
INSERT INTO public.users (
    id, email, display_name, username, avatar_url, account_role
) VALUES
    (:'teacher_a', 'teacher-a@example.test', 'Teacher A', 'teacher_a', '', 'teacher'),
    (:'teacher_b', 'teacher-b@example.test', 'Teacher B', 'teacher_b', '', 'teacher'),
    (:'teacher_pending', 'teacher-pending@example.test', 'Teacher Pending', 'teacher_pending', '', 'teacher'),
    (:'student_a', 'student-a@example.test', 'Student A', 'student_a', '', 'personal'),
    (:'student_b', 'student-b@example.test', 'Student B', 'student_b', '', 'personal'),
    (:'outsider', 'outsider@example.test', 'Outsider', 'outsider', '', 'personal');

SELECT public.gt2_assert(
    (SELECT BOOL_AND(relrowsecurity)
     FROM pg_class
     WHERE oid IN (
        'public.learning_groups'::regclass,
        'public.learning_group_members'::regclass,
        'public.learning_group_invites'::regclass,
        'public.learning_group_announcements'::regclass
     )),
    'all public GT2 tables enforce RLS'
);
SELECT public.gt2_assert(
    NOT has_table_privilege('authenticated', 'public.learning_group_invites', 'SELECT'),
    'authenticated users cannot read invite hashes'
);
SELECT public.gt2_assert(
    NOT has_table_privilege(
        'authenticated', 'private.learning_group_moderation_events', 'SELECT'
    ),
    'authenticated users cannot read private moderation audit'
);
SELECT public.gt2_assert(
    NOT has_table_privilege('authenticated', 'public.learning_groups', 'INSERT')
    AND NOT has_table_privilege('authenticated', 'public.learning_group_members', 'UPDATE')
    AND NOT has_table_privilege('authenticated', 'public.learning_group_announcements', 'DELETE'),
    'authenticated users have no direct group mutation privileges'
);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 3
     FROM pg_catalog.pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename IN (
          'learning_groups',
          'learning_group_members',
          'learning_group_announcements'
       )),
    'GT2 realtime publication contains the three invalidation tables'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.gt2_expect_error(
    'SELECT * FROM public.get_my_learning_group_capabilities()',
    '42501',
    'group capabilities require authentication'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_pending', false);
SELECT public.gt2_expect_error(
    $$SELECT public.create_learning_group(
        'Pending class', '', '70000000-0000-4000-8000-000000000001'
    )$$,
    '42501',
    'self-selected pending teacher cannot create a group'
);

RESET ROLE;
SET ROLE service_role;
SELECT set_config('request.jwt.claim.role', '', false);
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT public.set_teacher_verification(:'teacher_a', 'verified', 'gt2_test');
SELECT public.set_teacher_verification(:'teacher_b', 'verified', 'gt2_test');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.gt2_assert(
    (SELECT can_manage_groups FROM public.get_my_learning_group_capabilities()),
    'verified teacher receives group management capability'
);
SELECT set_config('request.jwt.claim.sub', :'student_a', false);
SELECT public.gt2_assert(
    NOT (SELECT can_manage_groups FROM public.get_my_learning_group_capabilities()),
    'personal account receives no group management capability'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.create_learning_group(
    'Lop Anh van A', 'Nhom hoc rieng',
    '70000000-0000-4000-8000-000000000002'
) AS group_a \gset
SELECT public.gt2_assert(
    :'group_a'::UUID = public.create_learning_group(
        'Ignored retry title', 'Ignored retry description',
        '70000000-0000-4000-8000-000000000002'
    )
    AND CHAR_LENGTH(:'group_a') = 36,
    'group creation is nonempty and idempotent by request id'
);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1
     FROM public.learning_group_members
     WHERE group_id = :'group_a' AND role = 'owner_teacher'
       AND status = 'active'),
    'group creation installs exactly one active owner membership'
);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1 FROM public.list_my_learning_groups()
     WHERE group_id = :'group_a' AND member_role = 'owner_teacher'),
    'owner list returns the created group'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_b', false);
SELECT public.create_learning_group(
    'Lop Anh van B', '', '70000000-0000-4000-8000-000000000003'
) AS group_b \gset
SELECT public.gt2_expect_error(
    format(
        'SELECT public.update_learning_group(%L, ''Hijack'', '''', %L)',
        :'group_a', '70000000-0000-4000-8000-000000000004'
    ),
    '42501',
    'teacher B cannot manage teacher A group'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.update_learning_group(
    :'group_a', 'Lop A da sua', 'Mo ta moi',
    '70000000-0000-4000-8000-000000000005'
);
SELECT public.gt2_assert(
    (SELECT title = 'Lop A da sua'
     FROM public.learning_groups WHERE id = :'group_a'),
    'owner updates an active group through audited RPC'
);
SELECT public.rotate_learning_group_invite(
    :'group_a', NOW() + INTERVAL '7 days',
    '70000000-0000-4000-8000-000000000006'
) AS token_a \gset
SELECT public.gt2_assert(
    CHAR_LENGTH(:'token_a') = 64 AND :'token_a' ~ '^[0-9a-f]{64}$',
    'invite rotation returns one 256-bit hex secret'
);

RESET ROLE;
SELECT public.gt2_assert(
    (SELECT token_hash <> :'token_a'
        AND token_hash = ENCODE(extensions.digest(:'token_a', 'sha256'), 'hex')
     FROM public.learning_group_invites
     WHERE group_id = :'group_a' AND revoked_at IS NULL),
    'invite table stores only the SHA-256 token hash'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.gt2_expect_error(
    format(
        'SELECT public.rotate_learning_group_invite(%L, NOW() + INTERVAL ''7 days'', %L)',
        :'group_a', '70000000-0000-4000-8000-000000000006'
    ),
    '55000',
    'invite secret is never replayed for a repeated request id'
);

SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt2_assert(
    public.request_learning_group_join(
        repeat('z', 64), '70000000-0000-4000-8000-000000000007'
    ) IS NULL,
    'malformed invite fails without revealing a group'
);

RESET ROLE;
UPDATE public.learning_group_invites
SET created_at = NOW() - INTERVAL '2 days',
    expires_at = NOW() - INTERVAL '1 day'
WHERE group_id = :'group_a' AND revoked_at IS NULL;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt2_assert(
    public.request_learning_group_join(
        :'token_a', '70000000-0000-4000-8000-000000000008'
    ) IS NULL,
    'expired invite has the same non-disclosing result'
);

RESET ROLE;
UPDATE public.learning_group_invites
SET expires_at = NOW() + INTERVAL '7 days', revoked_at = NOW()
WHERE group_id = :'group_a';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt2_assert(
    public.request_learning_group_join(
        :'token_a', '70000000-0000-4000-8000-000000000009'
    ) IS NULL,
    'revoked invite has the same non-disclosing result'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.rotate_learning_group_invite(
    :'group_a', NOW() + INTERVAL '7 days',
    '70000000-0000-4000-8000-000000000010'
) AS token_live \gset
SELECT set_config('request.jwt.claim.sub', :'student_a', false);
SELECT public.request_learning_group_join(
    :'token_live', '70000000-0000-4000-8000-000000000011'
);
SELECT public.gt2_assert(
    (SELECT status = 'pending'
     FROM public.learning_group_members
     WHERE group_id = :'group_a' AND user_id = :'student_a'),
    'valid invite creates a pending membership only'
);
SELECT public.gt2_assert(
    public.request_learning_group_join(
        :'token_live', '70000000-0000-4000-8000-000000000011'
    ) = :'group_a'::UUID
    AND (SELECT COUNT(*) = 1 FROM public.learning_group_members
         WHERE group_id = :'group_a' AND user_id = :'student_a'),
    'join retry does not duplicate membership'
);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1 FROM public.learning_groups WHERE id = :'group_a'),
    'pending student can see only the requested group shell'
);
SELECT public.gt2_expect_error(
    'SELECT * FROM public.learning_group_invites',
    '42501',
    'student cannot query invite metadata or hashes'
);
SELECT public.gt2_expect_error(
    format('UPDATE public.learning_groups SET title = ''Bad'' WHERE id = %L', :'group_a'),
    '42501',
    'student cannot update a group directly'
);
SELECT public.gt2_expect_error(
    format(
        'UPDATE public.learning_group_members SET status = ''active'' WHERE group_id = %L',
        :'group_a'
    ),
    '42501',
    'student cannot approve a membership directly'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_b', false);
SELECT public.gt2_expect_error(
    format(
        'SELECT public.respond_learning_group_join(%L, %L, ''approve'', %L, NULL)',
        :'group_a', :'student_a', '70000000-0000-4000-8000-000000000012'
    ),
    '42501',
    'teacher B cannot approve teacher A applicants'
);
SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.gt2_assert(
    public.respond_learning_group_join(
        :'group_a', :'student_a', 'approve',
        '70000000-0000-4000-8000-000000000013', NULL
    ) = 'active',
    'owner atomically approves a pending student'
);
SELECT public.gt2_assert(
    (SELECT ARRAY_AGG(column_name ORDER BY ordinal_position)::TEXT
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'list_learning_group_members') IS NULL
    AND (SELECT COUNT(*) = 2 FROM public.list_learning_group_members(:'group_a')),
    'member projection returns only group-visible profiles'
);

SELECT set_config('request.jwt.claim.sub', :'student_b', false);
SELECT public.request_learning_group_join(
    :'token_live', '70000000-0000-4000-8000-000000000014'
);
SELECT set_config('request.jwt.claim.sub', :'student_a', false);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 0 FROM public.learning_group_members
     WHERE group_id = :'group_a' AND status = 'pending'),
    'active student cannot see pending applicants'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.create_learning_group_announcement(
    :'group_a', 'Chao mung vao lop',
    '70000000-0000-4000-8000-000000000015'
) AS announcement_a \gset
SELECT public.gt2_assert(
    :'announcement_a'::UUID = public.create_learning_group_announcement(
        :'group_a', 'Ignored duplicate body',
        '70000000-0000-4000-8000-000000000015'
    )
    AND (SELECT COUNT(*) = 1 FROM public.learning_group_announcements
         WHERE group_id = :'group_a'),
    'announcement creation is idempotent'
);
SELECT set_config('request.jwt.claim.sub', :'student_a', false);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_learning_group_announcements(:'group_a')),
    'active student reads group announcements'
);

SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.set_learning_group_member_mute(
    :'group_a', :'student_a', TRUE,
    '70000000-0000-4000-8000-000000000016', 'class_rule'
);
SELECT public.set_learning_group_member_mute(
    :'group_a', :'student_a', FALSE,
    '70000000-0000-4000-8000-000000000017', NULL
);
SELECT public.gt2_assert(
    NOT (SELECT is_muted FROM public.learning_group_members
         WHERE group_id = :'group_a' AND user_id = :'student_a'),
    'owner mute and unmute actions are audited and effective'
);
SELECT public.gt2_assert(
    public.remove_learning_group_member(
        :'group_a', :'student_a',
        '70000000-0000-4000-8000-000000000018', 'class_rule'
    ),
    'owner removes an active student through RPC'
);
SELECT set_config('request.jwt.claim.sub', :'student_a', false);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 0 FROM public.learning_groups WHERE id = :'group_a')
    AND (SELECT COUNT(*) = 0 FROM public.list_my_learning_groups()),
    'removed student immediately loses group visibility'
);
SELECT public.gt2_assert(
    public.request_learning_group_join(
        :'token_live', '70000000-0000-4000-8000-000000000019'
    ) = :'group_a'::UUID,
    'removed student can re-request only through invite RPC'
);

RESET ROLE;
INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT ('50000000-0000-4000-8000-' || LPAD(gs::TEXT, 12, '0'))::UUID,
       'cap-' || gs || '@example.test', NOW()
FROM generate_series(1, 50) AS gs;
INSERT INTO public.users (id, email, display_name, username, account_role)
SELECT id, email, 'Cap Student', 'cap_' || ROW_NUMBER() OVER (ORDER BY id), 'personal'
FROM auth.users WHERE email LIKE 'cap-%@example.test';
INSERT INTO public.learning_group_members (
    group_id, user_id, role, status, joined_at
)
SELECT :'group_a', id, 'student', 'active', NOW()
FROM auth.users WHERE email LIKE 'cap-%@example.test';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher_a', false);
SELECT public.gt2_expect_error(
    format(
        'SELECT public.respond_learning_group_join(%L, %L, ''approve'', %L, NULL)',
        :'group_a', :'student_b', '70000000-0000-4000-8000-000000000020'
    ),
    '55000',
    'approval lock enforces the 50 active student cap'
);
SELECT public.archive_learning_group(
    :'group_a', '70000000-0000-4000-8000-000000000021'
);
RESET ROLE;
SELECT public.gt2_assert(
    (SELECT status = 'archived' FROM public.learning_groups
     WHERE id = :'group_a')
    AND NOT EXISTS (
        SELECT 1 FROM public.learning_group_invites
        WHERE group_id = :'group_a' AND revoked_at IS NULL
    ),
    'archive preserves group and revokes every live invite'
);

SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1 FROM private.learning_group_moderation_events
     WHERE actor_user_id = :'teacher_a'
       AND request_id = '70000000-0000-4000-8000-000000000015'),
    'idempotent announcement retry creates one audit event'
);
SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1 FROM pg_proc
     WHERE oid = 'public.respond_learning_group_join(uuid,uuid,text,uuid,text)'::regprocedure
       AND prosrc LIKE '%pg_advisory_xact_lock%'),
    'approval contract holds a transaction-scoped per-group lock'
);

ROLLBACK;
