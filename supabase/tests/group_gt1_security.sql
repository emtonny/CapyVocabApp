BEGIN;
\set teacher 11111111-1111-4111-8111-111111111111
\set personal 22222222-2222-4222-8222-222222222222
\set parent 33333333-3333-4333-8333-333333333333

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    (:'teacher', 'teacher@example.test', NOW()),
    (:'personal', 'personal@example.test', NOW()),
    (:'parent', 'parent@example.test', NOW());
INSERT INTO public.users (id, email, display_name) VALUES
    (:'teacher', 'teacher@example.test', 'Teacher'),
    (:'personal', 'personal@example.test', 'Personal'),
    (:'parent', 'parent@example.test', 'Parent');

SELECT public.gt1_assert(
    (SELECT convalidated
     FROM pg_constraint
     WHERE conrelid = 'public.users'::regclass
       AND conname = 'users_account_role_check'),
    'teacher account role constraint is validated'
);
SELECT public.gt1_assert(
    (SELECT relrowsecurity
     FROM pg_class
     WHERE oid = 'public.teacher_profiles'::regclass),
    'teacher profiles enforce RLS'
);
SELECT public.gt1_assert(
    (SELECT relrowsecurity
     FROM pg_class
     WHERE oid = 'private.teacher_verification_events'::regclass),
    'teacher verification audit enforces RLS'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt1_assert(
    public.complete_onboarding(
        'Teacher One', 'teacher_one', 30, '', 'teacher',
        'vi-VN', 'en-US', '20:00', '21:00', 10,
        'vi', 'en', 'beginner'
    ),
    'verified-email account completes onboarding as teacher'
);
SELECT public.gt1_assert(
    (SELECT account_role = 'teacher'
     FROM public.users WHERE id = :'teacher'),
    'onboarding persists teacher intent role'
);
SELECT public.gt1_assert(
    (SELECT verification_status = 'pending'
     FROM public.teacher_profiles WHERE user_id = :'teacher'),
    'teacher role creates pending verification profile'
);
SELECT public.gt1_assert(
    NOT public.is_current_user_verified_teacher(),
    'self-selected teacher role grants no teacher authorization'
);
SELECT public.gt1_expect_error(
    format(
        'SELECT public.set_teacher_verification(%L, ''verified'', NULL)',
        :'teacher'
    ),
    '42501',
    'authenticated user cannot call verification mutation'
);
SELECT public.gt1_expect_error(
    format(
        'UPDATE public.teacher_profiles SET verification_status = ''verified'' WHERE user_id = %L',
        :'teacher'
    ),
    '42501',
    'authenticated user cannot update verification directly'
);

SELECT set_config('request.jwt.claim.sub', :'personal', false);
SELECT public.gt1_assert(
    public.complete_onboarding(
        'Personal One', 'personal_one', 20, '', 'personal',
        'vi-VN', 'en-US', '20:00', '21:00', 10,
        'vi', 'en', 'beginner'
    ),
    'personal onboarding remains backward compatible'
);
SELECT public.gt1_assert(
    (SELECT COUNT(*) = 0 FROM public.teacher_profiles),
    'other users cannot read teacher verification profiles'
);
SELECT public.gt1_expect_error(
    $$INSERT INTO public.teacher_profiles (user_id) VALUES ('22222222-2222-4222-8222-222222222222')$$,
    '42501',
    'authenticated user cannot insert verification profile'
);
SELECT public.gt1_expect_error(
    $$SELECT * FROM private.teacher_verification_events$$,
    '42501',
    'authenticated user cannot read verification audit'
);
SELECT public.gt1_expect_error(
    $$SELECT public.complete_onboarding(
        'Bad Role', 'bad_role', 20, '', 'admin',
        'vi-VN', 'en-US', '20:00', '21:00', 10,
        'vi', 'en', 'beginner'
    )$$,
    '22023',
    'unknown onboarding role remains rejected'
);
SELECT public.gt1_expect_error(
    $$SELECT public.complete_onboarding(
        'Null Role', 'null_role', 20, '', NULL,
        'vi-VN', 'en-US', '20:00', '21:00', 10,
        'vi', 'en', 'beginner'
    )$$,
    '22023',
    'null onboarding role remains rejected'
);

SELECT set_config('request.jwt.claim.sub', :'parent', false);
SELECT public.gt1_assert(
    public.complete_onboarding(
        'Parent One', 'parent_one', 35, '', 'parent',
        'vi-VN', 'en-US', '20:00', '21:00', 10,
        'vi', 'en', 'beginner'
    ),
    'parent onboarding remains backward compatible'
);

RESET ROLE;
SET ROLE service_role;
SELECT set_config('request.jwt.claim.role', '', false);
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.gt1_assert(
    public.set_teacher_verification(:'teacher', 'verified', 'manual_review'),
    'service role verifies pending teacher through guarded RPC'
);
SELECT public.gt1_expect_error(
    format(
        'SELECT public.set_teacher_verification(%L, NULL, NULL)',
        :'teacher'
    ),
    '22023',
    'null verification status is rejected explicitly'
);
SELECT public.gt1_assert(
    (SELECT COUNT(*) = 2
     FROM private.teacher_verification_events
     WHERE teacher_user_id = :'teacher'
       AND new_status IN ('pending', 'verified')),
    'pending creation and verification are audited'
);
SELECT public.gt1_expect_error(
    format(
        'SELECT public.set_teacher_verification(%L, ''rejected'', ''invalid_transition'')',
        :'teacher'
    ),
    '22023',
    'invalid verification transition fails closed'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt1_assert(
    public.is_current_user_verified_teacher(),
    'verified teacher receives teacher authorization'
);
SELECT public.gt1_assert(
    (SELECT verification_status = 'verified'
     FROM public.teacher_profiles WHERE user_id = :'teacher'),
    'teacher reads own verified status'
);
UPDATE public.users SET account_role = 'personal' WHERE id = :'teacher';
SELECT public.gt1_assert(
    NOT public.is_current_user_verified_teacher(),
    'verified profile without teacher intent grants no authorization'
);
UPDATE public.users SET account_role = 'teacher' WHERE id = :'teacher';
SELECT public.gt1_assert(
    public.is_current_user_verified_teacher(),
    'teacher authorization requires role and verified profile together'
);

RESET ROLE;
SET ROLE service_role;
SELECT set_config('request.jwt.claim.role', 'service_role', false);
SELECT public.gt1_assert(
    public.set_teacher_verification(:'teacher', 'suspended', 'policy_review'),
    'service role suspends verified teacher'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt1_assert(
    NOT public.is_current_user_verified_teacher(),
    'suspension revokes teacher authorization immediately'
);

RESET ROLE;
SELECT public.gt1_assert(
    (SELECT COUNT(*) = 3
     FROM private.teacher_verification_events
     WHERE teacher_user_id = :'teacher'),
    'audit contains exactly one event per status transition'
);
SELECT public.gt1_assert(
    NOT has_table_privilege(
        'authenticated',
        'private.teacher_verification_events',
        'SELECT'
    ),
    'authenticated role has no audit table privilege'
);
SELECT public.gt1_assert(
    NOT has_function_privilege(
        'authenticated',
        'public.set_teacher_verification(uuid,text,text)',
        'EXECUTE'
    ),
    'verification mutation is service-only'
);
SELECT public.gt1_assert(
    NOT has_table_privilege(
        'service_role',
        'public.teacher_profiles',
        'UPDATE'
    ),
    'service role must use guarded verification RPC for mutation'
);
SELECT public.gt1_assert(
    NOT has_table_privilege(
        'service_role',
        'private.teacher_verification_events',
        'INSERT'
    )
    AND NOT has_table_privilege(
        'service_role',
        'private.teacher_verification_events',
        'UPDATE'
    )
    AND NOT has_table_privilege(
        'service_role',
        'private.teacher_verification_events',
        'DELETE'
    ),
    'service role cannot mutate verification audit directly'
);
SELECT public.gt1_assert(
    (SELECT COUNT(*) = 1
     FROM pg_indexes
     WHERE schemaname = 'public'
       AND tablename = 'teacher_profiles'
       AND indexname = 'teacher_profiles_verification_status_idx'),
    'verification queue index exists for future admin workflow'
);

ROLLBACK;
