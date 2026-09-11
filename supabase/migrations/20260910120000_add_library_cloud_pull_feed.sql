-- M4.5: owner-scoped, cursor-based metadata pull for multi-device Library.
-- The feed stores identifiers only. Image bytes remain private Storage objects
-- and are downloaded exclusively by the existing explicit restore action.

alter table public.photo_notes
  add column if not exists emoji text;

create table if not exists public.library_change_events (
  sequence bigint generated always as identity primary key,
  user_id uuid not null,
  entity_type text not null check (entity_type in (
    'media_asset', 'scan_run', 'vocab_detection',
    'vocab_annotation', 'photo_note'
  )),
  entity_id uuid not null,
  media_asset_id uuid,
  photo_note_id uuid,
  operation text not null check (operation in ('upsert', 'delete')),
  changed_at timestamptz not null default now()
);

create index if not exists idx_library_change_events_owner_sequence
  on public.library_change_events (user_id, sequence);

alter table public.library_change_events enable row level security;
revoke all on public.library_change_events from public, anon, authenticated;
grant select on public.library_change_events to authenticated;

drop policy if exists "Users read their own library change feed"
  on public.library_change_events;
create policy "Users read their own library change feed"
  on public.library_change_events for select to authenticated
  using ((select auth.uid()) = user_id);

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

revoke all on function public.capture_library_change_event() from public;

drop trigger if exists trg_media_assets_library_change on public.media_assets;
create trigger trg_media_assets_library_change
after insert or update or delete on public.media_assets
for each row execute function public.capture_library_change_event();

drop trigger if exists trg_scan_runs_library_change on public.scan_runs;
create trigger trg_scan_runs_library_change
after insert or update or delete on public.scan_runs
for each row execute function public.capture_library_change_event();

drop trigger if exists trg_vocab_detections_library_change
  on public.vocab_detections;
create trigger trg_vocab_detections_library_change
after insert or update or delete on public.vocab_detections
for each row execute function public.capture_library_change_event();

drop trigger if exists trg_vocab_annotations_library_change
  on public.vocab_annotations;
create trigger trg_vocab_annotations_library_change
after insert or update or delete on public.vocab_annotations
for each row execute function public.capture_library_change_event();

drop trigger if exists trg_photo_notes_library_change on public.photo_notes;
create trigger trg_photo_notes_library_change
after insert or update or delete on public.photo_notes
for each row execute function public.capture_library_change_event();

-- Existing normalized notes need one initial event so a device starting at
-- cursor zero sees them. This contains identifiers only, never media or JSON.
insert into public.library_change_events (
  user_id, entity_type, entity_id, media_asset_id, photo_note_id, operation,
  changed_at
)
select user_id, 'photo_note', id, media_asset_id, id, 'upsert', updated_at
from public.photo_notes
where media_asset_id is not null;

create or replace function public.pull_library_delta(
  p_after_sequence bigint default 0,
  p_limit integer default 100
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  next_sequence bigint := p_after_sequence;
  media_ids uuid[] := array[]::uuid[];
  deletion_rows jsonb := '[]'::jsonb;
  more_rows boolean := false;
begin
  if owner_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_after_sequence < 0 or p_limit < 1 or p_limit > 500 then
    raise exception 'invalid Library pull cursor or limit'
      using errcode = '22023';
  end if;

  select
    coalesce(max(batch.sequence), p_after_sequence),
    coalesce(
      array_agg(distinct batch.media_asset_id)
        filter (where batch.media_asset_id is not null),
      array[]::uuid[]
    ),
    coalesce(
      jsonb_agg(jsonb_build_object(
        'sequence', batch.sequence,
        'user_id', batch.user_id,
        'photo_note_id', batch.photo_note_id,
        'changed_at', batch.changed_at
      ) order by batch.sequence) filter (
        where batch.entity_type = 'photo_note'
          and batch.operation = 'delete'
      ),
      '[]'::jsonb
    )
  into next_sequence, media_ids, deletion_rows
  from (
    select e.*
    from public.library_change_events e
    where e.user_id = owner_id and e.sequence > p_after_sequence
    order by e.sequence
    limit p_limit
  ) batch;

  select exists (
    select 1 from public.library_change_events e
    where e.user_id = owner_id and e.sequence > next_sequence
  ) into more_rows;

  return jsonb_build_object(
    'next_cursor', next_sequence,
    'has_more', more_rows,
    'deletions', deletion_rows,
    'media_assets', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.id)
      from public.media_assets m
      where m.user_id = owner_id and m.id = any(media_ids)
    ), '[]'::jsonb),
    'scan_runs', coalesce((
      select jsonb_agg(to_jsonb(s) order by s.started_at, s.id)
      from public.scan_runs s
      where s.user_id = owner_id and s.media_asset_id = any(media_ids)
    ), '[]'::jsonb),
    'vocab_detections', coalesce((
      select jsonb_agg(to_jsonb(d) order by d.display_order, d.id)
      from public.vocab_detections d
      join public.scan_runs s
        on s.id = d.scan_run_id and s.user_id = d.user_id
      where d.user_id = owner_id and s.media_asset_id = any(media_ids)
    ), '[]'::jsonb),
    'vocab_annotations', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.updated_at, a.id)
      from public.vocab_annotations a
      join public.vocab_detections d
        on d.id = a.detection_id and d.user_id = a.user_id
      join public.scan_runs s
        on s.id = d.scan_run_id and s.user_id = d.user_id
      where a.user_id = owner_id and s.media_asset_id = any(media_ids)
    ), '[]'::jsonb),
    'photo_notes', coalesce((
      select jsonb_agg(to_jsonb(p) order by p.updated_at, p.id)
      from public.photo_notes p
      where p.user_id = owner_id and p.media_asset_id = any(media_ids)
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.pull_library_delta(bigint, integer)
  from public, anon;
grant execute on function public.pull_library_delta(bigint, integer)
  to authenticated;
