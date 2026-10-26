-- Synthetic fixtures for the GT2 approval-cap concurrency test.
\set teacher 77777777-7777-4777-8777-777777777777
\set group_id 88888888-8888-4888-8888-888888888888

INSERT INTO auth.users (id, email, email_confirmed_at)
VALUES (:'teacher', 'concurrency-teacher@example.test', NOW());

INSERT INTO public.users (
    id, email, display_name, username, avatar_url, account_role
) VALUES (
    :'teacher', 'concurrency-teacher@example.test',
    'Concurrency Teacher', 'concurrency_teacher', '', 'teacher'
);

INSERT INTO auth.users (id, email, email_confirmed_at)
SELECT
    ('90000000-0000-4000-8000-' || LPAD(n::TEXT, 12, '0'))::UUID,
    FORMAT('concurrency-student-%s@example.test', n),
    NOW()
FROM GENERATE_SERIES(1, 51) AS n;

INSERT INTO public.users (
    id, email, display_name, username, avatar_url, account_role
)
SELECT
    ('90000000-0000-4000-8000-' || LPAD(n::TEXT, 12, '0'))::UUID,
    FORMAT('concurrency-student-%s@example.test', n),
    FORMAT('Concurrency Student %s', n),
    FORMAT('concurrency_student_%s', n),
    '',
    'personal'
FROM GENERATE_SERIES(1, 51) AS n;

SET ROLE service_role;
SELECT set_config('request.jwt.claim.role', '', false);
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT public.set_teacher_verification(:'teacher', 'verified', 'gt2_concurrency');
RESET ROLE;

INSERT INTO public.learning_groups (
    id, owner_teacher_id, title, description, creation_request_id
) VALUES (
    :'group_id', :'teacher', 'Concurrency class', '',
    '91000000-0000-4000-8000-000000000001'
);

INSERT INTO public.learning_group_members (
    group_id, user_id, role, status, joined_at
) VALUES (
    :'group_id', :'teacher', 'owner_teacher', 'active', NOW()
);

INSERT INTO public.learning_group_members (
    group_id, user_id, role, status, joined_at
)
SELECT
    :'group_id',
    ('90000000-0000-4000-8000-' || LPAD(n::TEXT, 12, '0'))::UUID,
    'student',
    'active',
    NOW()
FROM GENERATE_SERIES(1, 49) AS n;

INSERT INTO public.learning_group_members (
    group_id, user_id, role, status
)
SELECT
    :'group_id',
    ('90000000-0000-4000-8000-' || LPAD(n::TEXT, 12, '0'))::UUID,
    'student',
    'pending'
FROM GENERATE_SERIES(50, 51) AS n;
