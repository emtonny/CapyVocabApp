-- Keep the sender's vocabulary-label snapshot with an Album-image message so
-- every active conversation member sees the same labels without Library access.

alter table public.chat_operational_messages
  add column attachment_labels jsonb not null default '[]'::jsonb;
create or replace function private.valid_chat_album_image_labels(labels jsonb)
returns boolean
language plpgsql immutable
set search_path = '' as $$
declare
  item jsonb;
  label_number integer;
  label_x numeric;
  label_y numeric;
  label_width numeric;
  label_height numeric;
begin
  if jsonb_typeof(labels) <> 'array'
    or jsonb_array_length(labels) > 15
    or octet_length(labels::text) > 32768
  then
    return false;
  end if;

  for item in select value from jsonb_array_elements(labels) loop
    if jsonb_typeof(item) <> 'object'
      or jsonb_typeof(item->'number') <> 'number'
      or jsonb_typeof(item->'word') <> 'string'
      or jsonb_typeof(item->'phonetic') <> 'string'
      or jsonb_typeof(item->'meaning') <> 'string'
      or jsonb_typeof(item->'part_of_speech') <> 'string'
      or jsonb_typeof(item->'x') <> 'number'
      or jsonb_typeof(item->'y') <> 'number'
      or jsonb_typeof(item->'width') <> 'number'
      or jsonb_typeof(item->'height') <> 'number'
    then
      return false;
    end if;

    label_number := (item->>'number')::integer;
    label_x := (item->>'x')::numeric;
    label_y := (item->>'y')::numeric;
    label_width := (item->>'width')::numeric;
    label_height := (item->>'height')::numeric;
    if label_number not between 1 and 15
      or char_length(btrim(item->>'word')) not between 1 and 160
      or char_length(btrim(item->>'phonetic')) > 160
      or char_length(btrim(item->>'meaning')) > 320
      or char_length(btrim(item->>'part_of_speech')) > 80
      or label_x < 0 or label_y < 0
      or label_width <= 0 or label_height <= 0
      or label_x + label_width > 1
      or label_y + label_height > 1
    then
      return false;
    end if;
  end loop;
  return true;
exception when others then
  return false;
end;
$$;
revoke all on function private.valid_chat_album_image_labels(jsonb)
  from public, anon, authenticated;
alter table public.chat_operational_messages
  drop constraint chat_operational_messages_attachment_shape_check,
  add constraint chat_operational_messages_attachment_shape_check check (
    (attachment_kind = 'none'
      and attachment_source_photo_note_id is null
      and attachment_object_path is null
      and attachment_mime_type is null
      and attachment_byte_size is null
      and attachment_labels = '[]'::jsonb)
    or
    (attachment_kind = 'album_image'
      and attachment_source_photo_note_id is not null
      and attachment_object_path is not null
      and attachment_mime_type in
        ('image/jpeg', 'image/png', 'image/webp', 'image/heic')
      and attachment_byte_size between 1 and 8388608
      and private.valid_chat_album_image_labels(attachment_labels))
  );
grant insert (attachment_labels)
  on public.chat_operational_messages to authenticated;
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
      new.attachment_mime_type, new.attachment_byte_size,
      new.attachment_labels)
    is distinct from row(
      old.id, old.conversation_id, old.sender_id, old.raw_text,
      old.source_language_code, old.client_generated_id,
      old.client_created_at, old.sent_at, old.attachment_kind,
      old.attachment_source_photo_note_id, old.attachment_object_path,
      old.attachment_mime_type, old.attachment_byte_size,
      old.attachment_labels)
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
comment on column public.chat_operational_messages.attachment_labels is
  'Immutable vocabulary-label snapshot for an Album image; max 15 labels.';
