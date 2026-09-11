-- M3A: normalized cloud contract and private owner-scoped Photo Note media.
-- Its table/column changes are additive for existing Photo Notes. It does not
-- migrate legacy image_path values or enable a client sync worker.
-- Preflight required: moving the existing bucket to private invalidates legacy
-- public URLs until the client reads signed URLs/backfilled object paths.

create table if not exists public.media_assets (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  content_hash_sha256 text not null check (
    content_hash_sha256 ~ '^[0-9a-f]{64}$'
  ),
  original_object_path text,
  display_object_path text not null,
  model_input_object_path text,
  mime_type text not null,
  width integer not null check (width > 0),
  height integer not null check (height > 0),
  orientation integer not null default 0 check (orientation >= 0),
  byte_size_original bigint check (byte_size_original >= 0),
  byte_size_display bigint not null check (byte_size_display >= 0),
  preprocessing_version text not null,
  capture_source text not null check (
    capture_source in ('camera', 'gallery', 'imported', 'migration')
  ),
  captured_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  sync_version bigint not null default 1 check (sync_version > 0),
  unique (id, user_id),
  check (
    split_part(display_object_path, '/', 1) = user_id::text
    and split_part(display_object_path, '/', 2) = id::text
    and split_part(display_object_path, '/', 3)
      ~ '^display\.(jpg|jpeg|png|webp|heic)$'
    and array_length(string_to_array(display_object_path, '/'), 1) = 3
  ),
  check (
    original_object_path is null or (
      split_part(original_object_path, '/', 1) = user_id::text
      and split_part(original_object_path, '/', 2) = id::text
      and split_part(original_object_path, '/', 3)
        ~ '^original\.(jpg|jpeg|png|webp|heic)$'
      and array_length(string_to_array(original_object_path, '/'), 1) = 3
    )
  ),
  check (
    model_input_object_path is null or (
      split_part(model_input_object_path, '/', 1) = user_id::text
      and split_part(model_input_object_path, '/', 2) = id::text
      and split_part(model_input_object_path, '/', 3)
        ~ '^model_input\.(jpg|jpeg|png|webp|heic)$'
      and array_length(string_to_array(model_input_object_path, '/'), 1) = 3
    )
  )
);

create table if not exists public.scan_runs (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  media_asset_id uuid not null,
  request_id text not null,
  provider text not null,
  model_name text not null,
  model_version text,
  service_tier text,
  prompt_version text not null,
  response_schema_version text not null,
  preprocessing_version text not null,
  raw_response_json jsonb,
  response_hash_sha256 text check (
    response_hash_sha256 is null
    or response_hash_sha256 ~ '^[0-9a-f]{64}$'
  ),
  status text not null check (
    status in ('pending', 'succeeded', 'failed', 'quarantined')
  ),
  error_code text,
  started_at timestamptz not null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sync_version bigint not null default 1 check (sync_version > 0),
  unique (id, user_id),
  unique (user_id, request_id),
  check (completed_at is null or completed_at >= started_at),
  check (
    status <> 'succeeded'
    or (raw_response_json is not null and response_hash_sha256 is not null)
  ),
  foreign key (media_asset_id, user_id)
    references public.media_assets(id, user_id) on delete cascade
);

create table if not exists public.vocab_detections (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  scan_run_id uuid not null,
  word_raw text not null check (length(btrim(word_raw)) > 0),
  word_normalized text not null check (length(btrim(word_normalized)) > 0),
  phonetic text,
  meaning_vi text,
  part_of_speech text,
  example_en text,
  example_vi text,
  bbox_x double precision,
  bbox_y double precision,
  bbox_width double precision,
  bbox_height double precision,
  confidence double precision check (
    confidence is null or confidence between 0.0 and 1.0
  ),
  display_order integer not null check (display_order >= 0),
  created_at timestamptz not null,
  unique (id, user_id),
  check (
    (
      bbox_x is null and bbox_y is null
      and bbox_width is null and bbox_height is null
    ) or (
      bbox_x between 0.0 and 1.0
      and bbox_y between 0.0 and 1.0
      and bbox_width > 0.0 and bbox_height > 0.0
      and bbox_x + bbox_width <= 1.0
      and bbox_y + bbox_height <= 1.0
    )
  ),
  foreign key (scan_run_id, user_id)
    references public.scan_runs(id, user_id) on delete cascade
);

create table if not exists public.vocab_annotations (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  detection_id uuid not null,
  source text not null check (
    source in ('user_confirmed', 'user_corrected', 'imported')
  ),
  quality_status text not null check (
    quality_status in ('accepted', 'corrected', 'rejected')
  ),
  corrected_word text,
  corrected_phonetic text,
  corrected_meaning_vi text,
  corrected_bbox_x double precision,
  corrected_bbox_y double precision,
  corrected_bbox_width double precision,
  corrected_bbox_height double precision,
  revision integer not null check (revision > 0),
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  unique (id, user_id),
  unique (detection_id, revision),
  check (updated_at >= created_at),
  check (
    (
      corrected_bbox_x is null and corrected_bbox_y is null
      and corrected_bbox_width is null and corrected_bbox_height is null
    ) or (
      corrected_bbox_x between 0.0 and 1.0
      and corrected_bbox_y between 0.0 and 1.0
      and corrected_bbox_width > 0.0 and corrected_bbox_height > 0.0
      and corrected_bbox_x + corrected_bbox_width <= 1.0
      and corrected_bbox_y + corrected_bbox_height <= 1.0
    )
  ),
  check (
    source <> 'user_corrected'
    or corrected_word is not null
    or corrected_phonetic is not null
    or corrected_meaning_vi is not null
    or corrected_bbox_x is not null
  ),
  foreign key (detection_id, user_id)
    references public.vocab_detections(id, user_id) on delete cascade
);

alter table public.photo_notes
  add column if not exists media_asset_id uuid,
  add column if not exists primary_scan_run_id uuid,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists sync_version bigint not null default 1;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'photo_notes_media_asset_owner_fkey'
      and conrelid = 'public.photo_notes'::regclass
  ) then
    alter table public.photo_notes
      add constraint photo_notes_media_asset_owner_fkey
      foreign key (media_asset_id, user_id)
      references public.media_assets(id, user_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'photo_notes_primary_scan_owner_fkey'
      and conrelid = 'public.photo_notes'::regclass
  ) then
    alter table public.photo_notes
      add constraint photo_notes_primary_scan_owner_fkey
      foreign key (primary_scan_run_id, user_id)
      references public.scan_runs(id, user_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'photo_notes_sync_version_positive'
      and conrelid = 'public.photo_notes'::regclass
  ) then
    alter table public.photo_notes
      add constraint photo_notes_sync_version_positive
      check (sync_version > 0);
  end if;
end
$$;

create index if not exists idx_media_assets_user_created
  on public.media_assets (user_id, deleted_at, created_at desc);
create index if not exists idx_scan_runs_user_media
  on public.scan_runs (user_id, media_asset_id, started_at desc);
create index if not exists idx_vocab_detections_user_scan
  on public.vocab_detections (user_id, scan_run_id, display_order);
create index if not exists idx_vocab_annotations_user_detection
  on public.vocab_annotations (user_id, detection_id, revision desc);
create index if not exists idx_photo_notes_user_updated
  on public.photo_notes (user_id, deleted_at, updated_at desc);

alter table public.media_assets enable row level security;
alter table public.scan_runs enable row level security;
alter table public.vocab_detections enable row level security;
alter table public.vocab_annotations enable row level security;
alter table public.photo_notes enable row level security;

revoke all on public.media_assets from public, anon;
revoke all on public.scan_runs from public, anon;
revoke all on public.vocab_detections from public, anon;
revoke all on public.vocab_annotations from public, anon;

grant select, insert, update, delete on public.media_assets to authenticated;
grant select, insert, update, delete on public.scan_runs to authenticated;
grant select, insert, update, delete on public.vocab_detections to authenticated;
grant select, insert, update, delete on public.vocab_annotations to authenticated;

drop policy if exists "Users manage their own media assets"
  on public.media_assets;
create policy "Users manage their own media assets"
  on public.media_assets for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage their own scan runs"
  on public.scan_runs;
create policy "Users manage their own scan runs"
  on public.scan_runs for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage their own vocab detections"
  on public.vocab_detections;
create policy "Users manage their own vocab detections"
  on public.vocab_detections for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage their own vocab annotations"
  on public.vocab_annotations;
create policy "Users manage their own vocab annotations"
  on public.vocab_annotations for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users manage their own photo notes"
  on public.photo_notes;
create policy "Users manage their own photo notes"
  on public.photo_notes for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public)
values ('photo_notes', 'photo_notes', false)
on conflict (id) do update set public = false;

drop policy if exists "Public Access Photo Notes" on storage.objects;
drop policy if exists "User Upload Photo Notes" on storage.objects;
drop policy if exists "Users read their own photo note media" on storage.objects;
drop policy if exists "Users upload their own photo note media" on storage.objects;
drop policy if exists "Users update their own photo note media" on storage.objects;
drop policy if exists "Users delete their own photo note media" on storage.objects;

create policy "Users read their own photo note media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'photo_notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users upload their own photo note media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'photo_notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users update their own photo note media"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'photo_notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'photo_notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "Users delete their own photo note media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'photo_notes'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
