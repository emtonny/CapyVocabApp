BEGIN;
\set a 11111111-1111-4111-8111-111111111111
\set b 22222222-2222-4222-8222-222222222222
\set outsider 33333333-3333-4333-8333-333333333333
\set message 44444444-4444-4444-8444-444444444444
\set correction 55555555-5555-4555-8555-555555555555
INSERT INTO public.users VALUES (:'a'), (:'b'), (:'outsider');
INSERT INTO public.user_language_profiles(user_id, native_language_code, learning_language_code)
VALUES (:'a', 'vi', 'en'), (:'b', 'en', 'vi');
INSERT INTO public.chat_messages(user_id, message) VALUES (:'a', 'Synthetic legacy fixture');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_expect_error(format('SELECT public.open_direct_chat(%L)', :'b'), '42501', 'stranger cannot open conversation');
INSERT INTO public.friends(user_id, friend_id, status) VALUES (:'a', :'b', 'pending');
SELECT public.c2_expect_error(format('SELECT public.open_direct_chat(%L)', :'b'), '42501', 'pending friend cannot open conversation');
SELECT public.c2_expect_error(format('UPDATE public.friends SET status=''accepted'' WHERE user_id=%L AND friend_id=%L', :'a', :'b'), '42501', 'sender cannot forge acceptance');
SELECT public.c2_expect_error(format('INSERT INTO public.friends(user_id,friend_id,status) VALUES (%L,%L,''accepted'')', :'a', :'outsider'), '42501', 'sender cannot insert forged accepted friend');

SELECT set_config('request.jwt.claim.sub', :'b', false);
UPDATE public.friends SET status='accepted' WHERE user_id=:'a' AND friend_id=:'b';
INSERT INTO public.friends(user_id,friend_id,status) VALUES (:'b', :'a', 'accepted');
INSERT INTO public.friends(user_id,friend_id,status) VALUES (:'b', :'a', 'accepted')
ON CONFLICT (user_id,friend_id) DO UPDATE SET status=EXCLUDED.status,created_at=EXCLUDED.created_at;
SELECT public.c2_assert((SELECT count(*)=2 FROM public.friends WHERE status='accepted'), 'existing recipient accept and mirrored insert remain valid');
SELECT public.open_direct_chat(:'a') AS conversation \gset
SELECT public.c2_assert(public.open_direct_chat(:'a')=:'conversation'::uuid, 'conversation retry is idempotent');
SELECT public.c2_assert((SELECT count(*)=2 FROM public.chat_members WHERE conversation_id=:'conversation'), 'direct chat has exactly two members');
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_assert(public.open_direct_chat(:'b')=:'conversation'::uuid, 'reverse actor uses same conversation');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_members(conversation_id,user_id) VALUES (%L,%L)', :'conversation', :'outsider'), '42501', 'client cannot add a member');

INSERT INTO public.chat_operational_messages(id,conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at)
VALUES (:'message', :'conversation', :'a', 'Tối nay đi quẩy k bro?', 'vi', '66666666-6666-4666-8666-666666666666', '2000-01-01');
SELECT public.c2_assert((SELECT raw_text='Tối nay đi quẩy k bro?' AND sent_at >= NOW() FROM public.chat_operational_messages WHERE id=:'message'), 'raw Unicode preserved and sent_at server-owned');
SELECT public.c2_assert((SELECT last_message_at IS NOT NULL FROM public.chat_conversations WHERE id=:'conversation'), 'message atomically updates conversation summary');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''duplicate'',''vi'',''66666666-6666-4666-8666-666666666666'',NOW())', :'conversation', :'a'), '23505', 'message client ID deduplicates retries');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''forged'',''en'',gen_random_uuid(),NOW())', :'conversation', :'b'), '42501', 'sender spoofing rejected');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''wrong source'',''en'',gen_random_uuid(),NOW())', :'conversation', :'a'), '42501', 'source language must match owner profile');
SELECT public.c2_expect_error('UPDATE public.chat_operational_messages SET raw_text=''tampered''', '42501', 'client cannot edit raw text');
SELECT public.c2_expect_error('DELETE FROM public.chat_operational_messages', '42501', 'client delete withheld pending policy');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at,sent_at) VALUES (%L,%L,''forged time'',''vi'',gen_random_uuid(),NOW(),''2000-01-01'')', :'conversation', :'a'), '42501', 'client cannot supply server sent_at');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''   '',''vi'',gen_random_uuid(),NOW())', :'conversation', :'a'), '23514', 'blank messages rejected by DB');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,chr(9)||chr(10),''vi'',gen_random_uuid(),NOW())', :'conversation', :'a'), '23514', 'tab newline-only messages rejected by DB');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,repeat(''x'',4001),''vi'',gen_random_uuid(),NOW())', :'conversation', :'a'), '23514', 'oversized messages rejected by DB');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_translations(message_id,target_language_code,translator_version) VALUES (%L,''en'',''v1'')', :'message'), '42501', 'client cannot create translation job');

SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.c2_assert((SELECT count(*)=1 FROM public.chat_operational_messages), 'peer receives raw message without translation');
INSERT INTO public.chat_corrections(id,message_id,author_id,target_language_code,proposed_text)
VALUES (:'correction', :'message', :'b', 'en', 'Synthetic independent human correction');
SELECT public.c2_expect_error('UPDATE public.chat_corrections SET status=''accepted'', accepted_at=NOW()', '42501', 'client cannot forge correction decision');
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_expect_error(format('INSERT INTO public.chat_corrections(message_id,author_id,target_language_code,proposed_text) VALUES (%L,%L,''en'',''self correction'')', :'message', :'a'), '22023', 'raw sender cannot impersonate human target author');

RESET ROLE;
SET ROLE service_role;
SELECT public.c2_expect_error(format('INSERT INTO public.chat_members(conversation_id,user_id) VALUES (%L,%L)', :'conversation', :'outsider'), '22023', 'even service cannot add a third direct-chat participant');
SELECT public.c2_expect_error('UPDATE public.chat_operational_messages SET raw_text=''tampered''', '22023', 'even service preserves immutable raw content');
INSERT INTO public.chat_translations(message_id,target_language_code,translator_version) VALUES (:'message', 'en', 'v1');
UPDATE public.chat_translations SET status='succeeded', translated_text='Synthetic translation, no Gemini request', model='synthetic', prompt_version='test', completed_at=NOW();
SELECT public.c2_expect_error('UPDATE public.chat_translations SET translated_text=''rewritten''', '22023', 'successful provider output cannot be rewritten');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_translations(message_id,target_language_code,translator_version) VALUES (%L,''en'',''v1'')', :'message'), '23505', 'translation key is unique for both clients');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_translations(message_id,target_language_code,translator_version) VALUES (%L,''vi'',''v2'')', :'message'), '22023', 'translation target differs from source');
SELECT public.c2_expect_error(format('UPDATE public.chat_corrections SET status=''accepted'',accepted_by=%L,accepted_at=NOW()', :'b'), '22023', 'correction author cannot be recorded as source acceptor');
UPDATE public.chat_corrections SET status='accepted',accepted_by=:'a',accepted_at=NOW() WHERE id=:'correction';
SELECT public.c2_expect_error('UPDATE public.chat_corrections SET proposed_text=''rewritten''', '22023', 'human correction remains append-only');

RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.c2_assert((SELECT count(*)=1 FROM public.chat_translations WHERE status='succeeded'), 'peer reads shared translation');
SELECT public.c2_expect_error('UPDATE public.chat_translations SET attempt_count=2', '42501', 'client cannot mutate provider job metadata');
SELECT public.c2_assert((SELECT count(*)=1 FROM public.chat_corrections WHERE status='accepted'), 'peer reads correction separately');
SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.c2_assert((SELECT count(*)=0 FROM public.chat_conversations) AND (SELECT count(*)=0 FROM public.chat_members)
 AND (SELECT count(*)=0 FROM public.chat_operational_messages) AND (SELECT count(*)=0 FROM public.chat_translations)
 AND (SELECT count(*)=0 FROM public.chat_corrections), 'outsider reads no operational rows');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''outsider'',''vi'',gen_random_uuid(),NOW())', :'conversation', :'outsider'), '42501', 'outsider cannot send to guessed conversation');

RESET ROLE;
DELETE FROM public.user_language_profiles WHERE user_id=:'b';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_expect_error(format('SELECT public.open_direct_chat(%L)', :'b'), '22023', 'missing language profile fails closed');
RESET ROLE;
INSERT INTO public.user_language_profiles(user_id,native_language_code,learning_language_code) VALUES (:'b','en','vi');
SET ROLE service_role;
UPDATE public.chat_operational_messages SET moderation_state='held' WHERE id=:'message';
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_assert((SELECT count(*)=0 FROM public.chat_operational_messages) AND (SELECT count(*)=0 FROM public.chat_translations)
 AND (SELECT count(*)=0 FROM public.chat_corrections), 'held raw message also hides derived records');
RESET ROLE;
SET ROLE service_role;
UPDATE public.chat_operational_messages SET moderation_state='visible' WHERE id=:'message';
UPDATE public.chat_members SET left_at=NOW() WHERE conversation_id=:'conversation' AND user_id=:'b';
RESET ROLE;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.c2_assert((SELECT count(*)=0 FROM public.chat_conversations) AND (SELECT count(*)=0 FROM public.chat_operational_messages), 'inactive member loses read access');
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.c2_expect_error(format('SELECT public.open_direct_chat(%L)', :'b'), '42501', 'RPC cannot silently reactivate left member');
SELECT public.c2_expect_error(format('INSERT INTO public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at) VALUES (%L,%L,''inactive peer'',''vi'',gen_random_uuid(),NOW())', :'conversation', :'a'), '42501', 'sending requires two active members');

RESET ROLE;
SET ROLE anon;
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.c2_expect_error('SELECT * FROM public.chat_operational_messages', '42501', 'anon table reads denied');
SELECT public.c2_expect_error(format('SELECT public.open_direct_chat(%L)', :'a'), '42501', 'anon RPC denied');
RESET ROLE;
SELECT public.c2_assert((SELECT count(*)=5 FROM pg_class WHERE relname IN ('chat_conversations','chat_members','chat_operational_messages','chat_translations','chat_corrections') AND relrowsecurity), 'all five operational tables enable RLS');
SELECT public.c2_assert((SELECT count(*)=5 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('chat_conversations','chat_members','chat_operational_messages','chat_translations','chat_corrections')), 'Realtime publishes only RLS-protected operational tables');
SELECT public.c2_assert((SELECT count(*)=1 FROM public.chat_messages) AND has_table_privilege('authenticated','public.chat_messages','INSERT'), 'legacy data and released-client write contract unchanged');
SELECT public.c2_assert((SELECT count(*)=1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='chat_messages'), 'legacy Realtime subscription contract unchanged');
ROLLBACK;
