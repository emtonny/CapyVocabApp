-- One private Album image per operational Chat message. The image copy is
-- readable only by active conversation members and becomes permanently
-- unavailable when its source Photo Note is deleted.

alter table public.chat_operational_messages
  add column attachment_kind text not null default 'none',
  add column attachment_source_photo_note_id uuid,
  add column attachment_object_path text,
  add column attachment_mime_type text,
  add column attachment_byte_size integer,
  add column attachment_available boolean not null default true,
  add constraint chat_operational_messages_attachment_kind_check
    check (attachment_kind in ('none', 'album_image')),
  add constraint chat_operational_messages_attachment_shape_check check (
    (attachment_kind = 'none'
      and attachment_source_photo_note_id is null
      and attachment_object_path is null
      and attachment_mime_type is null
      and attachment_byte_size is null)
    or
    (attachment_kind = 'album_image'
      and attachment_source_photo_note_id is not null
      and attachment_object_path is not null
      and attachment_mime_type in
        ('image/jpeg', 'image/png', 'image/webp', 'image/heic')
      and attachment_byte_size between 1 and 8388608)
  );
create index chat_album_image_source
  on public.chat_operational_messages(sender_id, attachment_source_photo_note_id)
  where attachment_kind = 'album_image' and attachment_available;
grant insert (
  attachment_kind,
  attachment_source_photo_note_id,
  attachment_object_path,
  attachment_mime_type,
  attachment_byte_size
) on public.chat_operational_messages to authenticated;
create or replace function private.guard_chat_raw_message()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.sent_at := now();
    if new.attachment_kind = 'album_image' and (
      new.raw_text <> 'Đã chia sẻ 1 ảnh từ Album'
      or split_part(new.attachment_object_path, '/', 1) <> new.sender_id::text
      or split_part(new.attachment_object_path, '/', 2) <> new.id::text
      or split_part(new.attachment_object_path, '/', 3)
        !~ '^image[.](jpg|jpeg|png|webp|heic)$'
      or array_length(string_to_array(new.attachment_object_path, '/'), 1) <> 3
    ) then
      raise exception 'Invalid Album image attachment'
        using errcode = '22023';
    end if;
  elsif row(
      new.id, new.conversation_id, new.sender_id, new.raw_text,
      new.source_language_code, new.client_generated_id,
      new.client_created_at, new.sent_at, new.attachment_kind,
      new.attachment_source_photo_note_id, new.attachment_object_path,
      new.attachment_mime_type, new.attachment_byte_size)
    is distinct from row(
      old.id, old.conversation_id, old.sender_id, old.raw_text,
      old.source_language_code, old.client_generated_id,
      old.client_created_at, old.sent_at, old.attachment_kind,
      old.attachment_source_photo_note_id, old.attachment_object_path,
      old.attachment_mime_type, old.attachment_byte_size)
    or (old.attachment_available = false and new.attachment_available = true)
  then
    raise exception 'Raw message identity/content is immutable'
      using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_chat_raw_message()
  from public, anon, authenticated;
create or replace function private.enqueue_chat_translation_v2()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.attachment_kind = 'none' then
    insert into public.chat_translations (
      message_id, target_language_code, translator_version,
      provider, model, prompt_version, status
    ) values (
      new.id,
      case new.source_language_code when 'vi' then 'en' else 'vi' end,
      'chat-translate-v2', 'vilao', 'gemini-3.8-flash',
      'chat-translate-p2', 'queued'
    )
    on conflict (message_id, target_language_code, translator_version)
    do nothing;
  end if;
  return new;
end;
$$;
revoke all on function private.enqueue_chat_translation_v2()
  from public, anon, authenticated, service_role;
create or replace function public.invalidate_my_chat_album_images(
  p_source_photo_note_id uuid
)
returns table (object_path text)
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  return query
  update public.chat_operational_messages m
    set attachment_available = false
    where m.sender_id = (select auth.uid())
      and m.attachment_kind = 'album_image'
      and m.attachment_source_photo_note_id = p_source_photo_note_id
      and m.attachment_available
    returning m.attachment_object_path;
end;
$$;
revoke all on function public.invalidate_my_chat_album_images(uuid)
  from public, anon, authenticated;
grant execute on function public.invalidate_my_chat_album_images(uuid)
  to authenticated;
create or replace function private.invalidate_chat_album_images_from_photo_note()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := case when tg_op = 'DELETE' then old.id else new.id end;
  v_user_id uuid := case
    when tg_op = 'DELETE' then old.user_id else new.user_id
  end;
begin
  if tg_op = 'DELETE'
    or (old.deleted_at is null and new.deleted_at is not null)
  then
    update public.chat_operational_messages m
    set attachment_available = false
    where m.sender_id = v_user_id
      and m.attachment_source_photo_note_id = v_id
      and m.attachment_kind = 'album_image'
      and m.attachment_available;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
revoke all on function private.invalidate_chat_album_images_from_photo_note()
  from public, anon, authenticated;
create trigger invalidate_chat_album_images_after_photo_note_delete
after update of deleted_at or delete on public.photo_notes
for each row execute function
  private.invalidate_chat_album_images_from_photo_note();
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'chat_album_images', 'chat_album_images', false, 8388608,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "Chat senders upload Album images" on storage.objects;
drop policy if exists "Chat members read Album images" on storage.objects;
drop policy if exists "Chat senders update Album images" on storage.objects;
drop policy if exists "Chat senders delete Album images" on storage.objects;
create policy "Chat senders upload Album images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'chat_album_images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and array_length(storage.foldername(name), 1) = 2
);
create policy "Chat members read Album images"
on storage.objects for select to authenticated
using (
  bucket_id = 'chat_album_images' and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.chat_operational_messages m
      where m.attachment_kind = 'album_image'
        and m.attachment_available
        and m.attachment_object_path = storage.objects.name
        and private.is_active_chat_member(m.conversation_id)
    )
  )
);
create policy "Chat senders update Album images"
on storage.objects for update to authenticated
using (
  bucket_id = 'chat_album_images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'chat_album_images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "Chat senders delete Album images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'chat_album_images'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
comment on function public.invalidate_my_chat_album_images(uuid) is
  'Permanently hides Album-image Chat copies after their source Photo Note is deleted; returns owner paths for best-effort Storage cleanup.';
