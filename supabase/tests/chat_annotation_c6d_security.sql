\set ON_ERROR_STOP on
BEGIN;

CREATE OR REPLACE FUNCTION public.c6d_assert(ok BOOLEAN, label TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF NOT ok THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
    RAISE NOTICE 'PASS: %', label;
END;
$$;

CREATE OR REPLACE FUNCTION public.c6d_expect_error(statement TEXT, expected TEXT, label TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE statement;
        RAISE EXCEPTION 'Expected SQLSTATE %, but statement succeeded', expected;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> expected THEN RAISE; END IF;
    END;
    RAISE NOTICE 'PASS: %', label;
END;
$$;

\set a '11111111-1111-4111-8111-111111111111'
\set b '22222222-2222-4222-8222-222222222222'
\set outsider '33333333-3333-4333-8333-333333333333'
\set message '77777777-7777-4777-8777-777777777777'
\set correction '88888888-8888-4888-8888-888888888888'
\set pending_correction '99999999-9999-4999-8999-999999999999'
\set annotation 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'

INSERT INTO public.users(id) VALUES (:'a'), (:'b'), (:'outsider');
INSERT INTO public.user_language_profiles(
    user_id, native_language_code, learning_language_code, proficiency_level
) VALUES
    (:'a', 'vi', 'en', 'beginner'),
    (:'b', 'en', 'vi', 'beginner'),
    (:'outsider', 'vi', 'en', 'beginner');
INSERT INTO public.friends(user_id, friend_id, status)
VALUES (:'a', :'b', 'pending');

SET ROLE authenticated;
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
    :'message', :'conversation', :'a', 'Tối nay đi quẩy không? 🚀', 'vi',
    '66666666-6666-4666-8666-666666666666', NOW()
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    :'correction', :'message', :'b', 'en', 'Want to hit the club tonight?'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.resolve_chat_correction(:'correction', 'accepted');
INSERT INTO public.chat_slang_annotations(
    id, message_id, correction_id, created_by, span_text, span_start,
    span_end, tag_type, normalized_source
) VALUES (
    :'annotation', :'message', :'correction', :'a', 'quẩy', 11,
    15, 'slang', 'đi chơi hoặc đi bar'
);
SELECT public.c6d_assert(
    (SELECT span_text = 'quẩy' AND span_start = 11 AND span_end = 15
       AND substring('Tối nay đi quẩy không? 🚀' FROM span_start + 1
                     FOR span_end - span_start) = span_text
       AND annotator_role = 'source_speaker' AND status = 'active'
     FROM public.chat_slang_annotations WHERE id = :'annotation'),
    'multibyte Unicode span round-trips with zero-based code-point offsets'
);
SELECT public.c6d_assert(
    (SELECT count(*) = 1 FROM public.chat_slang_annotations),
    'source sender creates one tag only after accepting the correction'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
INSERT INTO public.chat_corrections(
    id, message_id, author_id, target_language_code, proposed_text
) VALUES (
    :'pending_correction', :'message', :'b', 'en', 'Are you partying tonight?'
);

SELECT public.c6d_assert(
    (SELECT count(*) = 1 FROM public.chat_slang_annotations),
    'other active member can read the operational tag'
);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',11,15,''slang'',''party'')',
    :'message', :'correction', :'b'), '42501',
    'correction author cannot tag the source speaker raw text'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',11,15,''slang'',''đi chơi'')',
    :'message', :'pending_correction', :'a'), '42501',
    'a pending correction is not eligible for tagging'
);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',10,14,''slang'',''đi chơi'')',
    :'message', :'correction', :'a'), '22023',
    'mismatched Unicode offsets fail before storage'
);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',11,99,''slang'',''đi chơi'')',
    :'message', :'correction', :'a'), '22023',
    'out-of-range Unicode offsets fail before storage'
);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',11,15,''unknown'',''đi chơi'')',
    :'message', :'correction', :'a'), '23514',
    'unknown tag types are rejected'
);
SELECT public.c6d_expect_error(format(
    'UPDATE public.chat_slang_annotations SET normalized_source=''rewritten'' WHERE id=%L',
    :'annotation'), '42501',
    'authenticated clients cannot rewrite a tag'
);

SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.c6d_assert(
    (SELECT count(*) = 0 FROM public.chat_slang_annotations),
    'outsider cannot read a guessed annotation'
);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',11,15,''slang'',''đi chơi'')',
    :'message', :'correction', :'outsider'), '42501',
    'outsider cannot insert a guessed annotation'
);

RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.c6d_expect_error(
    'SELECT * FROM public.chat_slang_annotations', '42501',
    'anonymous annotation reads are denied'
);

RESET ROLE;
SELECT public.c6d_assert(
    has_table_privilege('authenticated', 'public.chat_slang_annotations', 'SELECT')
    AND has_column_privilege('authenticated', 'public.chat_slang_annotations', 'id', 'INSERT')
    AND NOT has_table_privilege('authenticated', 'public.chat_slang_annotations', 'UPDATE')
    AND NOT has_table_privilege('authenticated', 'public.chat_slang_annotations', 'DELETE'),
    'authenticated grants are limited to select and constrained insert'
);
SELECT public.c6d_assert(
    (SELECT count(*) = 2 FROM pg_policies
     WHERE schemaname = 'public' AND tablename = 'chat_slang_annotations')
    AND (SELECT relrowsecurity FROM pg_class
         WHERE oid = 'public.chat_slang_annotations'::regclass),
    'annotation table has read and insert RLS policies'
);
SELECT public.c6d_assert(
    (SELECT count(*) = 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'chat_slang_annotations'),
    'annotation invalidations are published to Realtime'
);

SET ROLE service_role;
UPDATE public.chat_members SET left_at = NOW()
WHERE conversation_id = :'conversation' AND user_id = :'b';
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c6d_expect_error(format(
    'INSERT INTO public.chat_slang_annotations(id,message_id,correction_id,created_by,span_text,span_start,span_end,tag_type,normalized_source) VALUES (gen_random_uuid(),%L,%L,%L,''quẩy'',11,15,''slang'',''đi chơi'')',
    :'message', :'correction', :'a'), '42501',
    'inactive membership blocks new source annotations'
);

RESET ROLE;
SET ROLE service_role;
SELECT public.c6d_expect_error(format(
    'UPDATE public.chat_slang_annotations SET span_text=''rewrite'' WHERE id=%L',
    :'annotation'), '22023',
    'trusted callers cannot rewrite immutable tag content'
);

ROLLBACK;
