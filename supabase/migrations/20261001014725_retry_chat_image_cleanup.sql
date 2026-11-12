-- Return already-revoked paths too: a prior call or the Library trigger may
-- have revoked access before Storage deletion completed.
create or replace function public.invalidate_my_chat_album_images(
  p_source_photo_note_id uuid
)
returns table (object_path text)
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  update public.chat_operational_messages m
    set attachment_available = false
    where m.sender_id = (select auth.uid())
      and m.attachment_kind = 'album_image'
      and m.attachment_source_photo_note_id = p_source_photo_note_id
      and m.attachment_available;
  return query
    select distinct m.attachment_object_path
    from public.chat_operational_messages m
    where m.sender_id = (select auth.uid())
      and m.attachment_kind = 'album_image'
      and m.attachment_source_photo_note_id = p_source_photo_note_id
      and not m.attachment_available;
end;
$$;
revoke all on function public.invalidate_my_chat_album_images(uuid)
  from public, anon;
grant execute on function public.invalidate_my_chat_album_images(uuid)
  to authenticated;