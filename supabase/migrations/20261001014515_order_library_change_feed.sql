-- Preserve per-owner commit ordering for the cursor feed.
create or replace function public.capture_library_change_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_row record;
  owner_id uuid;
  source_id uuid;
  root_media_id uuid;
  root_note_id uuid;
  entity_kind text;
begin
  if tg_op = 'DELETE' then
    source_row := old;
  else
    source_row := new;
  end if;
  owner_id := source_row.user_id;
  source_id := source_row.id;

  -- Allocate feed sequence only while holding the owner lock until commit.
  -- Concurrent writers may deadlock on other rows; normal transaction retry
  -- is safe, whereas advancing past an uncommitted sequence loses data.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('library-feed:' || owner_id::text, 0)
  );

  if tg_table_name = 'media_assets' then
    entity_kind := 'media_asset';
    root_media_id := source_row.id;
  elsif tg_table_name = 'scan_runs' then
    entity_kind := 'scan_run';
    root_media_id := source_row.media_asset_id;
  elsif tg_table_name = 'vocab_detections' then
    entity_kind := 'vocab_detection';
    select s.media_asset_id into root_media_id
    from public.scan_runs s
    where s.id = source_row.scan_run_id and s.user_id = owner_id;
  elsif tg_table_name = 'vocab_annotations' then
    entity_kind := 'vocab_annotation';
    select s.media_asset_id into root_media_id
    from public.vocab_detections d
    join public.scan_runs s on s.id = d.scan_run_id
    where d.id = source_row.detection_id and s.user_id = owner_id;
  elsif tg_table_name = 'photo_notes' then
    entity_kind := 'photo_note';
    root_media_id := source_row.media_asset_id;
    root_note_id := source_row.id;
  else
    raise exception 'unsupported Library change source: %', tg_table_name;
  end if;

  insert into public.library_change_events (
    user_id, entity_type, entity_id, media_asset_id, photo_note_id,
    operation
  ) values (
    owner_id, entity_kind, source_id, root_media_id, root_note_id,
    case when tg_op = 'DELETE' then 'delete' else 'upsert' end
  );
  return source_row;
end;
$$;

revoke all on function public.capture_library_change_event() from public, anon, authenticated;
