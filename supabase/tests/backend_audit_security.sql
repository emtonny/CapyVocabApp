begin;
\set a 11111111-1111-4111-8111-111111111111
\set b 22222222-2222-4222-8222-222222222222
\set c 33333333-3333-4333-8333-333333333333
insert into auth.users(id) values (:'a'), (:'b'), (:'c');
insert into public.users(id,email,display_name,username) values
  (:'a','a@audit.invalid','Audit A','audit_a'),
  (:'b','b@audit.invalid','Audit B','audit_b'),
  (:'c','c@audit.invalid','Audit C','audit_c');
insert into public.user_language_profiles(user_id,native_language_code,learning_language_code)
values (:'a','vi','en'),(:'b','en','vi');

create function public.audit_insert_image(labels jsonb, mime text default 'image/jpeg', bytes integer default 10)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare message_id uuid := gen_random_uuid();
begin
  insert into public.chat_operational_messages(
    id, conversation_id, sender_id, raw_text, source_language_code,
    client_generated_id, client_created_at, attachment_kind,
    attachment_source_photo_note_id, attachment_object_path,
    attachment_mime_type, attachment_byte_size, attachment_labels
  ) values (
    message_id, current_setting('audit.conversation')::uuid, auth.uid(),
    'Đã chia sẻ 1 ảnh từ Album', 'vi', gen_random_uuid(), now(), 'album_image',
    '44444444-4444-4444-8444-444444444444',
    auth.uid()::text || '/' || message_id::text || '/image.jpg', mime, bytes, labels
  );
  return message_id;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', :'a', true);
select public.f1_assert(not has_table_privilege(current_user,'public.friends','INSERT'), 'direct friend insert revoked');
select public.f1_assert(not has_table_privilege(current_user,'public.friends','UPDATE'), 'direct friend update revoked');
select public.f1_assert(not has_table_privilege(current_user,'public.friends','DELETE'), 'direct friend delete revoked');
select public.f1_assert(not has_column_privilege(current_user,'public.friends','status','UPDATE'), 'column friend update revoked');
select public.f1_expect_error(format('insert into public.friends(user_id,friend_id,status) values (%L,%L,''accepted'')', :'a', :'b'), '42501', 'forged accepted friendship denied');
select public.f1_assert(public.send_friend_request(:'b') = 'outgoing_pending', 'send RPC still works');
select set_config('request.jwt.claim.sub', :'b', true);
select public.f1_assert(public.respond_friend_request(:'a','accept') = 'accepted', 'accept RPC still works');
select set_config('request.jwt.claim.sub', :'a', true);
select set_config('audit.conversation', public.open_direct_chat(:'b')::text, true);
select public.f1_expect_error(format('delete from public.friends where user_id=%L', :'a'), '42501', 'one-sided direct delete denied');
select public.f1_assert(not has_function_privilege('anon','public.capture_library_change_event()','execute'), 'anon trigger execute revoked');
select public.f1_assert(has_function_privilege(current_user,'private.valid_chat_album_image_labels(jsonb)','execute'), 'authenticated validator execute preserved');

select public.f1_assert(not private.valid_chat_album_image_labels(null), 'SQL NULL labels rejected');
select public.f1_assert(not private.valid_chat_album_image_labels('[{}]'), 'missing required keys rejected');
select public.f1_assert(not private.valid_chat_album_image_labels('[{"number":1,"word":"cat"}]'), 'missing geometry rejected');
select public.f1_expect_error($q$select public.audit_insert_image('[{}]')$q$, '23514', 'malformed image INSERT rejected');
select public.f1_expect_error($q$select public.audit_insert_image('[]',null,10)$q$, '23514', 'NULL MIME INSERT rejected');
select public.f1_expect_error($q$select public.audit_insert_image('[]','image/jpeg',null)$q$, '23514', 'NULL size INSERT rejected');
select public.f1_expect_error($q$select public.audit_insert_image('[]','image/jpeg',8388609)$q$, '23514', 'oversize image INSERT rejected');
select public.audit_insert_image('[{"number":1,"word":"cat","phonetic":"","meaning":"mèo","part_of_speech":"noun","x":0,"y":0,"width":0.5,"height":0.5}]') as image_id \gset
select public.f1_assert((select count(*)=1 from public.chat_operational_messages where id=:'image_id'), 'valid image INSERT works');
insert into public.chat_operational_messages(conversation_id,sender_id,raw_text,source_language_code,client_generated_id,client_created_at)
values(current_setting('audit.conversation')::uuid,:'a','Synthetic text','vi',gen_random_uuid(),now());
select public.f1_assert((select count(*)=2 from public.chat_operational_messages), 'text INSERT still works');
select public.f1_assert((select count(*)=1 from public.invalidate_my_chat_album_images('44444444-4444-4444-8444-444444444444')), 'first invalidation returns cleanup path');
select public.f1_assert((select count(*)=1 from public.invalidate_my_chat_album_images('44444444-4444-4444-8444-444444444444')), 'retry returns already invalidated cleanup path');
select set_config('request.jwt.claim.sub', :'c', true);
select public.f1_assert((select count(*)=0 from public.chat_operational_messages), 'outsider cannot read messages');
select public.f1_assert((select count(*)=0 from public.invalidate_my_chat_album_images('44444444-4444-4444-8444-444444444444')), 'outsider cannot get cleanup paths');
rollback;
