BEGIN;
\set teacher 11111111-1111-4111-8111-111111111111
\set student 22222222-2222-4222-8222-222222222222
\set outsider 33333333-3333-4333-8333-333333333333

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    (:'teacher', 'gt4.teacher@example.test', NOW()),
    (:'student', 'gt4.student@example.test', NOW()),
    (:'outsider', 'gt4.outsider@example.test', NOW());
INSERT INTO public.users (
    id, email, display_name, username, account_role
) VALUES
    (:'teacher', 'gt4.teacher@example.test', 'GT4 Teacher', 'gt4_teacher', 'teacher'),
    (:'student', 'gt4.student@example.test', 'GT4 Student', 'gt4_student', 'personal'),
    (:'outsider', 'gt4.outsider@example.test', 'GT4 Outsider', 'gt4_outsider', 'personal');

SET ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT public.set_teacher_verification(:'teacher', 'verified', 'gt4_test');
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.create_learning_group(
    'GT4 private class', 'Management projection test',
    '70000000-0000-4000-8000-000000000021'
) AS group_id \gset
SELECT public.rotate_learning_group_invite(
    :'group_id', NOW() + INTERVAL '7 days',
    '70000000-0000-4000-8000-000000000022'
) AS invite_token \gset

SELECT public.gt3_assert(
    (SELECT has_active_invite AND expires_at > NOW() AND use_count = 0
     FROM public.get_learning_group_invite_status(:'group_id')),
    'owner reads active invite metadata without token projection'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 2
     FROM public.list_learning_group_moderation_events(:'group_id', 100)
     WHERE action IN ('group_created', 'invite_rotated')),
    'owner reads bounded class moderation history'
);
SELECT public.gt3_assert(
    (SELECT BOOL_AND(actor_display_name = 'GT4 Teacher')
     FROM public.list_learning_group_moderation_events(:'group_id', 100)),
    'audit projection resolves safe actor display names'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_moderation_events(%L, 0)',
        :'group_id'
    ),
    '22023',
    'audit projection rejects an unbounded zero limit'
);

RESET ROLE;
INSERT INTO public.learning_group_members(
    group_id, user_id, role, status, joined_at
) VALUES (:'group_id', :'student', 'student', 'active', NOW());

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.get_learning_group_invite_status(%L)',
        :'group_id'
    ),
    '42501',
    'active student cannot read invite metadata'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_moderation_events(%L, 100)',
        :'group_id'
    ),
    '42501',
    'active student cannot read private moderation history'
);
SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_moderation_events(%L, 100)',
        :'group_id'
    ),
    '42501',
    'outsider cannot read private moderation history'
);

SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.archive_learning_group(
    :'group_id', '70000000-0000-4000-8000-000000000023'
);
SELECT public.gt3_assert(
    (SELECT NOT has_active_invite AND expires_at IS NULL
     FROM public.get_learning_group_invite_status(:'group_id')),
    'archive revokes invite while owner retains metadata access'
);
SELECT public.gt3_assert(
    (SELECT action = 'group_archived'
     FROM public.list_learning_group_moderation_events(:'group_id', 1)),
    'archived owner retains latest moderation history'
);

RESET ROLE;
SET ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT set_config('request.jwt.claim.role', 'service_role', false);
SELECT public.set_teacher_verification(:'teacher', 'suspended', 'gt4_test');
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_moderation_events(%L, 100)',
        :'group_id'
    ),
    '42501',
    'suspended teacher loses moderation history access'
);

ROLLBACK;
