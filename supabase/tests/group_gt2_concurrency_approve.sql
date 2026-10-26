BEGIN;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config(
    'request.jwt.claim.sub',
    '77777777-7777-4777-8777-777777777777',
    false
);
\if :prelock
SELECT pg_advisory_xact_lock(
    hashtextextended('88888888-8888-4888-8888-888888888888', 0)
);
SELECT pg_sleep(2);
\endif
SELECT public.respond_learning_group_join(
    '88888888-8888-4888-8888-888888888888',
    :'student_id',
    'approve',
    :'request_id',
    NULL
);
COMMIT;
