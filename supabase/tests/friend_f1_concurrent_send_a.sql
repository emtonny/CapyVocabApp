\set ON_ERROR_STOP on
SET ROLE authenticated;
SELECT set_config(
    'request.jwt.claim.sub',
    '66666666-6666-4666-8666-666666666666',
    false
);
SELECT pg_sleep(1);
SELECT public.send_friend_request(
    '77777777-7777-4777-8777-777777777777'::UUID
);
