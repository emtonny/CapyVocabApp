BEGIN;

\set a 11111111-1111-4111-8111-111111111111
\set b 22222222-2222-4222-8222-222222222222
\set outsider 33333333-3333-4333-8333-333333333333
\set message 44444444-4444-4444-8444-444444444444
\set correction 55555555-5555-4555-8555-555555555555
\set correction2 55555555-5555-4555-8555-555555555556
\set correction3 55555555-5555-4555-8555-555555555557

INSERT INTO public.users VALUES (:'a'), (:'b'), (:'outsider');
INSERT INTO public.user_language_profiles(
    user_id, native_language_code, learning_language_code
) VALUES (:'a', 'vi', 'en'), (:'b', 'en', 'vi');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.friends(user_id, friend_id, status)
VALUES (:'a', :'b', 'pending');
SELECT set_config('request.jwt.claim.sub', :'b', false);
UPDATE public.friends SET status = 'accepted'
WHERE user_id = :'a' AND friend_id = :'b';
INSERT INTO public.friends(user_id, friend_id, status)
VALUES (:'b', :'a', 'accepted');
SELECT public.open_direct_chat(:'a') AS conversation \gset

SELECT set_config('request.jwt.claim.sub', :'a', false);
INSERT INTO public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at
) VALUES (
    :'message', :'conversation', :'a', 'Tối nay đi quẩy không?', 'vi',
    '66666666-6666-4666-8666-666666666666', NOW()
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    :'correction', :'message', :'b', 'en', 'Want to hit the club tonight?'
);
SELECT public.c2_assert(
    (SELECT status = 'proposed' AND updated_at = created_at
     FROM public.chat_corrections WHERE id = :'correction'),
    'proposal receives a server-owned stable update timestamp'
);
SELECT public.c2_assert(
    (SELECT count(*) = 1 FROM public.chat_correction_events
     WHERE correction_id = :'correction' AND action = 'proposed'
       AND actor_id = :'b'),
    'proposal appends one author audit event'
);
SELECT public.c2_expect_error(format(
    'INSERT INTO public.chat_corrections(id,message_id,author_id,target_language_code,proposed_text) VALUES (%L,%L,%L,''en'',''duplicate open proposal'')',
    :'correction2', :'message', :'b'), '23505',
    'one author cannot create two simultaneous proposals for one message'
);
SELECT public.c2_expect_error(format(
    'SELECT public.resolve_chat_correction(%L,''accepted'')', :'correction'),
    '42501', 'correction author cannot decide their own proposal'
);
SELECT public.c2_expect_error(format(
    'UPDATE public.chat_corrections SET status=''accepted'',accepted_by=%L,accepted_at=NOW() WHERE id=%L',
    :'a', :'correction'), '42501',
    'authenticated client cannot bypass the decision RPC'
);

SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.c2_assert(
    (SELECT count(*) = 0 FROM public.chat_corrections)
    AND (SELECT count(*) = 0 FROM public.chat_correction_events),
    'outsider reads no correction or audit event'
);
SELECT public.c2_expect_error(format(
    'SELECT public.resolve_chat_correction(%L,''accepted'')', :'correction'),
    '42501', 'outsider cannot decide a guessed correction'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT (public.resolve_chat_correction(:'correction', 'accepted')).status
AS accepted_status \gset
SELECT public.c2_assert(:'accepted_status' = 'accepted',
    'raw sender accepts through the dedicated RPC');
SELECT accepted_at AS accepted_before
FROM public.chat_corrections WHERE id = :'correction' \gset
SELECT public.c2_assert(
    (SELECT status = 'accepted' AND accepted_by = :'a'
      AND accepted_at IS NOT NULL AND updated_at >= created_at
     FROM public.chat_corrections WHERE id = :'correction'),
    'accepted decision stores only the source sender and server time'
);
SELECT public.c2_assert(
    (SELECT count(*) = 2 FROM public.chat_correction_events
     WHERE correction_id = :'correction')
    AND (SELECT count(*) = 1 FROM public.chat_correction_events
         WHERE correction_id = :'correction' AND action = 'accepted'
           AND actor_id = :'a'),
    'acceptance appends exactly one decision audit event'
);
SELECT public.resolve_chat_correction(:'correction', 'accepted');
SELECT public.c2_assert(
    (SELECT accepted_at = :'accepted_before'::timestamptz
     FROM public.chat_corrections WHERE id = :'correction')
    AND (SELECT count(*) = 2 FROM public.chat_correction_events
         WHERE correction_id = :'correction'),
    'same decision retry is idempotent without another event'
);
SELECT public.c2_expect_error(format(
    'SELECT public.resolve_chat_correction(%L,''rejected'')', :'correction'),
    '22023', 'opposite final decision cannot replace acceptance'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    :'correction2', :'message', :'b', 'en', 'A newer independent proposal'
);
SELECT public.c2_assert(
    (SELECT count(*) = 2 FROM public.chat_corrections
     WHERE message_id = :'message' AND author_id = :'b'),
    'append-only history permits a new proposal after the prior final decision'
);

RESET ROLE;
SET ROLE service_role;
SELECT public.c2_expect_error(
    'UPDATE public.chat_correction_events SET action=''rejected''',
    '42501', 'service role cannot rewrite audit events'
);
SELECT public.c2_expect_error(format(
    'UPDATE public.chat_corrections SET proposed_text=''rewritten'' WHERE id=%L',
    :'correction'), '22023',
    'trusted callers still cannot rewrite finalized correction content'
);

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.resolve_chat_correction(:'correction2', 'rejected');
SELECT public.c2_assert(
    (SELECT status = 'rejected' AND rejected_by = :'a'
     FROM public.chat_corrections WHERE id = :'correction2')
    AND (SELECT count(*) = 1 FROM public.chat_correction_events
         WHERE correction_id = :'correction2' AND action = 'rejected'),
    'rejection uses the same actor-bound audited transition'
);
SELECT public.c2_expect_error(
    'SELECT public.resolve_chat_correction(NULL,''accepted'')',
    '22023', 'invalid decision input fails before mutation'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    :'correction3', :'message', :'b', 'en',
    'Pending proposal before membership becomes inactive'
);

RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.c2_expect_error(format(
    'SELECT public.resolve_chat_correction(%L,''accepted'')', :'correction'),
    '42501', 'anonymous actor cannot execute correction decision RPC'
);
SELECT public.c2_expect_error(
    'SELECT * FROM public.chat_correction_events',
    '42501', 'anonymous audit reads are denied'
);

RESET ROLE;
SET ROLE service_role;
UPDATE public.chat_members SET left_at = NOW()
WHERE conversation_id = :'conversation' AND user_id = :'b';
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_expect_error(format(
    'SELECT public.resolve_chat_correction(%L,''accepted'')', :'correction3'),
    '42501', 'inactive-member correction decision fails closed'
);

RESET ROLE;
SELECT public.c2_assert(
    has_function_privilege('authenticated',
      'public.resolve_chat_correction(uuid,text)', 'EXECUTE')
    AND NOT has_function_privilege('anon',
      'public.resolve_chat_correction(uuid,text)', 'EXECUTE')
    AND NOT has_table_privilege('authenticated',
      'public.chat_correction_events', 'INSERT'),
    'only authenticated RPC execution and member audit reads are granted'
);
SELECT public.c2_assert(
    (SELECT count(*) = 1 FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'chat_correction_events'
       AND policyname = 'chat_correction_event_member_read')
    AND (SELECT relrowsecurity FROM pg_class
         WHERE oid = 'public.chat_correction_events'::regclass),
    'audit table has one read-only member RLS policy'
);

SET ROLE service_role;
SELECT public.c2_expect_error(format(
    'DELETE FROM public.chat_correction_events WHERE correction_id=%L',
    :'correction3'), '42501',
    'trusted caller cannot directly delete an audit event'
);
DELETE FROM public.chat_corrections WHERE id = :'correction3';
SELECT public.c2_assert(
    NOT EXISTS (SELECT 1 FROM public.chat_correction_events
                WHERE correction_id = :'correction3'),
    'retention cascade can remove an event with its parent correction'
);

ROLLBACK;
