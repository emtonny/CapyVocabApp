BEGIN;
\set a 11111111-1111-4111-8111-111111111111
\set b 22222222-2222-4222-8222-222222222222
\set c 33333333-3333-4333-8333-333333333333
\set d 44444444-4444-4444-8444-444444444444
\set e 55555555-5555-4555-8555-555555555555

SELECT public.f1_assert(
    (SELECT COUNT(*) = 2
     FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'friends'
       AND column_name IN ('updated_at', 'responded_at')),
    'friend timestamps exist'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 3
     FROM pg_class AS c
     JOIN pg_namespace AS n ON n.oid = c.relnamespace
     WHERE n.nspname = 'private'
       AND c.relname IN (
           'friend_discovery_settings',
           'friend_discovery_events',
           'friend_search_rate_limits'
       )
       AND c.relrowsecurity),
    'all private discovery tables enable RLS'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 2
     FROM public.friends
     WHERE status = 'accepted'
       AND updated_at IS NOT NULL
       AND responded_at IS NOT NULL),
    'accepted friendship timestamps backfilled'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.friends
     WHERE status = 'pending'
       AND updated_at IS NOT NULL
       AND responded_at IS NULL),
    'pending friendship timestamp backfilled without response time'
);

SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.f1_expect_error(
    'SELECT * FROM public.search_friend(''username'', ''bob'')',
    '42501',
    'anonymous search denied'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.get_my_friend_discovery_settings()',
    '42501',
    'anonymous discovery settings denied'
);
SELECT public.f1_expect_error(
    'SELECT public.check_phone_available(''0912345678'')',
    '42501',
    'anonymous phone precheck denied'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    (SELECT NOT discoverable_by_email
         AND NOT discoverable_by_phone
         AND email_confirmed
         AND NOT phone_verified
     FROM public.get_my_friend_discovery_settings()),
    'discovery defaults fail closed'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1 FROM public.search_friend('username', ' BoB ')),
    'exact username search normalizes case and spaces'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0 FROM public.search_friend('username', 'alice')),
    'search excludes caller account'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.search_friend(''username'', ''x'')',
    '22023',
    'invalid username rejected'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.search_friend(''email'', ''invalid'')',
    '22023',
    'invalid email rejected'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.search_friend(''phone'', ''phone123'')',
    '22023',
    'invalid phone rejected'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.search_friend(''unknown'', ''bob'')',
    '22023',
    'unknown search method rejected'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0 FROM public.get_public_profiles(NULL::UUID[])),
    'NULL public profile IDs return no rows'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1 FROM public.get_public_profiles(ARRAY[:'b'::UUID])),
    'known public profile ID remains readable'
);
SELECT public.f1_assert(
    public.check_phone_available('0912345678')
    AND public.check_phone_available('0999999999'),
    'phone precheck does not reveal whether a valid number exists'
);
SELECT public.f1_assert(
    NOT public.check_phone_available('not-a-phone'),
    'phone precheck still rejects invalid syntax'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0 FROM public.search_friend('email', 'bob@example.test')),
    'email opt-out is not discoverable'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0 FROM public.search_friend('phone', '0912345678')),
    'phone opt-out is not discoverable'
);
SELECT public.f1_expect_error(
    'SELECT * FROM private.friend_discovery_settings',
    '42501',
    'authenticated client cannot read private discovery settings'
);

SELECT set_config('request.jwt.claim.sub', :'d', false);
SELECT public.f1_expect_error(
    'SELECT * FROM public.update_my_friend_discovery_settings(TRUE, FALSE)',
    '22023',
    'unconfirmed email cannot enable discovery'
);
SELECT public.f1_expect_error(
    'SELECT public.sync_my_verified_friend_phone()',
    '22023',
    'unconfirmed phone cannot be synchronized'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.f1_assert(
    public.sync_my_verified_friend_phone(),
    'confirmed auth phone synchronizes without client assertion'
);
SELECT public.f1_assert(
    (SELECT discoverable_by_email
         AND discoverable_by_phone
         AND email_confirmed
         AND phone_verified
     FROM public.update_my_friend_discovery_settings(TRUE, TRUE)),
    'owner enables verified email and phone discovery'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.search_friend('email', ' BOB@EXAMPLE.TEST ')
     WHERE id = :'b' AND relationship_state = 'none'),
    'verified opted-in email returns public profile only'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.search_friend('phone', '0912345678')
     WHERE id = :'b'),
    'verified opted-in local phone finds account'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.search_friend('phone', '+84 912-345-678')
     WHERE id = :'b'),
    'Vietnam international phone normalizes to stored format'
);
SELECT public.f1_expect_error(
    format('SELECT public.send_friend_request(%L)', :'a'),
    '22023',
    'self friend request denied'
);
SELECT public.f1_expect_error(
    'SELECT public.send_friend_request(''99999999-9999-4999-8999-999999999999'')',
    'P0002',
    'unknown friend target denied'
);
SELECT public.f1_assert(
    public.send_friend_request(:'b') = 'outgoing_pending',
    'friend request creates outgoing pending state'
);
SELECT public.f1_assert(
    public.send_friend_request(:'b') = 'outgoing_pending'
    AND (SELECT COUNT(*) = 1
         FROM public.friends
         WHERE user_id = :'a' AND friend_id = :'b'),
    'friend request retry is idempotent'
);
SELECT public.f1_assert(
    (SELECT relationship_state = 'outgoing_pending'
     FROM public.search_friend('username', 'bob')),
    'search reports outgoing pending relationship'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_friend_requests('outgoing')
     WHERE peer_id = :'b'),
    'outgoing request list includes target'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_friend_requests('incoming')
     WHERE peer_id = :'a'),
    'recipient sees incoming request'
);

SELECT set_config('request.jwt.claim.sub', :'c', false);
SELECT public.f1_expect_error(
    format('SELECT public.respond_friend_request(%L, ''accept'')', :'a'),
    'P0002',
    'outsider cannot respond to another pair request'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_expect_error(
    format('SELECT public.respond_friend_request(%L, ''accept'')', :'a'),
    '22023',
    'request sender cannot accept own request'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.f1_assert(
    public.respond_friend_request(:'a', 'accept') = 'accepted',
    'recipient accepts request through atomic RPC'
);
SELECT public.f1_assert(
    public.respond_friend_request(:'a', 'accept') = 'accepted',
    'accept retry is idempotent'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 2
     FROM public.friends
     WHERE user_id IN (:'a'::UUID, :'b'::UUID)
       AND friend_id IN (:'a'::UUID, :'b'::UUID)
       AND status = 'accepted'
       AND responded_at IS NOT NULL),
    'accept commits exactly two responded rows'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_accepted_friends()
     WHERE peer_id = :'a'),
    'recipient accepted list contains requester'
);
SELECT public.open_direct_chat(:'a') AS conversation_id \gset
SELECT public.f1_assert(
    public.open_direct_chat(:'a') = :'conversation_id'::UUID,
    'accepted friendship still opens idempotent direct Chat'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    public.send_friend_request(:'b') = 'already_accepted',
    'send against accepted pair is idempotent'
);
SELECT public.f1_assert(
    public.open_direct_chat(:'b') = :'conversation_id'::UUID,
    'reverse friend opens canonical Chat conversation'
);
SELECT peer_id AS first_peer_id,
       relationship_updated_at AS first_updated_at
FROM public.list_accepted_friends(NULL::TIMESTAMPTZ, NULL::UUID, 1)
\gset
SELECT public.f1_assert(
    :'first_peer_id'::UUID = :'b'::UUID,
    'accepted keyset page orders newest relationship first'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_accepted_friends(
         :'first_updated_at'::TIMESTAMPTZ,
         :'first_peer_id'::UUID,
         1
     )
     WHERE peer_id = :'e'),
    'accepted keyset cursor returns next friend without duplicate'
);

SELECT public.f1_assert(
    public.send_friend_request(:'c') = 'outgoing_pending',
    'second pair request created for reject path'
);
SELECT set_config('request.jwt.claim.sub', :'c', false);
SELECT public.f1_assert(
    public.respond_friend_request(:'a', 'reject') = 'rejected',
    'recipient rejects pending request'
);
SELECT public.f1_assert(
    public.respond_friend_request(:'a', 'reject') = 'rejected',
    'reject retry is idempotent'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.friends
     WHERE user_id = :'a'
       AND friend_id = :'c'
       AND status = 'rejected'
       AND responded_at IS NOT NULL)
    AND NOT EXISTS (
        SELECT 1 FROM public.friends
        WHERE user_id = :'c' AND friend_id = :'a'
    ),
    'reject keeps one audit row and creates no mirror'
);
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    public.send_friend_request(:'c') = 'rejected',
    'rejected relationship is not silently reopened'
);
SELECT public.f1_expect_error(
    format(
        'UPDATE public.friends SET status=''accepted'' WHERE user_id=%L AND friend_id=%L',
        :'a', :'d'
    ),
    '42501',
    'sender still cannot forge direct acceptance'
);

-- Force the reciprocal insert to fail and prove the original pending row rolls back.
SELECT set_config('request.jwt.claim.sub', :'c', false);
SELECT public.f1_assert(
    public.send_friend_request(:'d') = 'outgoing_pending',
    'atomic rollback fixture starts pending'
);
RESET ROLE;
CREATE FUNCTION public.f1_fail_synthetic_mirror()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.user_id = '44444444-4444-4444-8444-444444444444'::UUID
       AND NEW.friend_id = '33333333-3333-4333-8333-333333333333'::UUID
       AND NEW.status = 'accepted' THEN
        RAISE EXCEPTION 'synthetic_mirror_failure' USING ERRCODE = '55000';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER f1_fail_synthetic_mirror
BEFORE INSERT ON public.friends
FOR EACH ROW EXECUTE FUNCTION public.f1_fail_synthetic_mirror();
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'d', false);
SELECT public.f1_expect_error(
    format('SELECT public.respond_friend_request(%L, ''accept'')', :'c'),
    '55000',
    'reciprocal failure aborts accept RPC'
);
SELECT public.f1_assert(
    (SELECT status = 'pending' AND responded_at IS NULL
     FROM public.friends
     WHERE user_id = :'c' AND friend_id = :'d'),
    'failed reciprocal insert rolls original request back to pending'
);
RESET ROLE;
DROP TRIGGER f1_fail_synthetic_mirror ON public.friends;
DROP FUNCTION public.f1_fail_synthetic_mirror();

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
UPDATE public.users SET phone = '0912345670' WHERE id = :'b';
SELECT public.f1_assert(
    (SELECT discoverable_by_email
         AND NOT discoverable_by_phone
         AND email_confirmed
         AND NOT phone_verified
     FROM public.get_my_friend_discovery_settings()),
    'changing phone clears verification and phone discovery'
);
UPDATE public.users SET email = 'bob.changed@example.test' WHERE id = :'b';
SELECT public.f1_assert(
    (SELECT NOT discoverable_by_email AND NOT discoverable_by_phone
     FROM public.get_my_friend_discovery_settings()),
    'changing email clears email discovery'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0
     FROM public.search_friend('phone', '0912345678')),
    'old phone is not discoverable after contact change'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0
     FROM public.search_friend('email', 'bob@example.test')),
    'old email is not discoverable after contact change'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.list_friend_requests(''sideways'')',
    '22023',
    'invalid request direction rejected'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.list_accepted_friends(NULL, NULL, 101)',
    '22023',
    'oversized friend page rejected'
);
SELECT public.f1_expect_error(
    'SELECT * FROM public.list_accepted_friends(NOW(), NULL::UUID, 30)',
    '22023',
    'partial keyset cursor rejected'
);

RESET ROLE;
SELECT public.f1_assert(
    (SELECT COUNT(*) = 4
     FROM private.friend_discovery_events
     WHERE user_id = :'b'
       AND old_value IS DISTINCT FROM new_value),
    'discovery opt-in and automatic contact resets are audited without identifiers'
);
SELECT public.f1_assert(
    NOT has_table_privilege(
        'authenticated',
        'private.friend_discovery_settings',
        'SELECT'
    )
    AND NOT has_table_privilege(
        'authenticated',
        'private.friend_discovery_events',
        'SELECT'
    ),
    'private discovery tables grant no authenticated reads'
);
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0
     FROM information_schema.parameters AS p
     JOIN information_schema.routines AS r
       ON r.specific_catalog = p.specific_catalog
      AND r.specific_schema = p.specific_schema
      AND r.specific_name = p.specific_name
     WHERE r.routine_schema = 'public'
       AND r.routine_name = 'search_friend'
       AND p.parameter_mode IN ('OUT', 'INOUT')
       AND p.parameter_name IN ('email', 'phone')),
    'search RPC has no contact identifier output'
);

TRUNCATE private.friend_search_rate_limits;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
DO $$
DECLARE
    v_index INTEGER;
BEGIN
    FOR v_index IN 1..30 LOOP
        PERFORM * FROM public.search_friend('username', 'nobody');
    END LOOP;
END;
$$;
SELECT public.f1_expect_error(
    'SELECT * FROM public.search_friend(''username'', ''nobody'')',
    'P0001',
    'server rate limit rejects the thirty-first search in a minute'
);

RESET ROLE;
SELECT public.f1_assert(
    (SELECT COUNT(*) = 0
     FROM public.friends
     WHERE user_id = :'a' AND friend_id = :'b' AND status = 'pending'),
    'accepted pair leaves no pending row'
);

ROLLBACK;
