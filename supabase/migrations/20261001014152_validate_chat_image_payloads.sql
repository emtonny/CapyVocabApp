-- Reject missing keys and SQL NULLs without removing required validator grants.
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
  if jsonb_typeof(labels) is distinct from 'array'
    or jsonb_array_length(labels) > 15
    or octet_length(labels::text) > 32768
  then
    return false;
  end if;

  for item in select value from jsonb_array_elements(labels) loop
    if jsonb_typeof(item) is distinct from 'object'
      or jsonb_typeof(item->'number') is distinct from 'number'
      or jsonb_typeof(item->'word') is distinct from 'string'
      or jsonb_typeof(item->'phonetic') is distinct from 'string'
      or jsonb_typeof(item->'meaning') is distinct from 'string'
      or jsonb_typeof(item->'part_of_speech') is distinct from 'string'
      or jsonb_typeof(item->'x') is distinct from 'number'
      or jsonb_typeof(item->'y') is distinct from 'number'
      or jsonb_typeof(item->'width') is distinct from 'number'
      or jsonb_typeof(item->'height') is distinct from 'number'
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
  from public, anon;

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
      and attachment_mime_type is not null
      and attachment_byte_size is not null
      and attachment_mime_type in
        ('image/jpeg', 'image/png', 'image/webp', 'image/heic')
      and attachment_byte_size between 1 and 8388608
      and private.valid_chat_album_image_labels(attachment_labels))
  );


grant execute on function private.valid_chat_album_image_labels(jsonb)
  to authenticated, service_role;
