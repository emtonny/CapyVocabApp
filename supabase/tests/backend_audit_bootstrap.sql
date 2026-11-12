-- Synthetic local contracts only. Run in a disposable PostgreSQL cluster.
\ir friend_f1_bootstrap.sql

create schema storage;
grant usage on schema storage to authenticated, service_role;
create table storage.buckets (
  id text primary key, name text not null, public boolean not null default false,
  file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id), name text not null
);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to authenticated;
create function storage.foldername(name text) returns text[]
language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1)-1];
$$;
create table public.photo_notes (
  id uuid primary key, user_id uuid not null references public.users(id),
  image_path text, note_title text not null default '',
  template_id text not null default 'standard',
  created_at timestamptz not null default now()
);
alter table public.photo_notes enable row level security;
grant select, insert, update, delete on public.photo_notes to authenticated;

\ir ../migrations/20260903120000_add_library_cloud_storage_contract.sql
\ir ../migrations/20260910120000_add_library_cloud_pull_feed.sql
\ir ../migrations/20260915120000_add_operational_chat_security.sql
\ir ../migrations/20260918120000_add_chat_translation_queue_claim.sql
\ir ../migrations/20260921120000_add_vilao_chat_translation_v2.sql
\ir ../migrations/20260922120000_add_friend_management_contract.sql
\ir ../migrations/20260923120000_accept_supabase_auth_phone_format.sql
\ir ../migrations/20260929132557_add_chat_album_image_shares.sql
\ir ../migrations/20260929143000_add_chat_album_image_labels.sql
\ir ../migrations/20260930130000_restore_chat_label_validator_execute.sql

-- Simulate independently granted column privileges found in upgraded projects.
grant insert (status), update (status) on public.friends to authenticated;
\ir ../migrations/20261001014150_harden_friend_client_writes.sql
\ir ../migrations/20261001014152_validate_chat_image_payloads.sql
\ir ../migrations/20261001014515_order_library_change_feed.sql
\ir ../migrations/20261001014725_retry_chat_image_cleanup.sql
