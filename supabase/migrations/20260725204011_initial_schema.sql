-- Baseline recovered from the repository's original supabase_schema.sql
-- (commit f40a1fa, before the first incremental migration).
-- Schema only: no production rows or user data are copied.

create extension if not exists "uuid-ossp";

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  display_name text not null,
  avatar_url text default '',
  study_points int default 0 check (study_points >= 0),
  streak_days int default 0 check (streak_days >= 0),
  total_coins int default 100 check (total_coins >= 0),
  user_level int default 1 check (user_level >= 1),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references public.users(id) on delete cascade,
  theme_mode text default 'light' check (theme_mode in ('light', 'dark')),
  daily_target_words int default 10 check (daily_target_words > 0),
  reminder_time text default '20:00',
  sound_effects_enabled boolean default true
);

create table if not exists public.lessons (
  id text primary key,
  title text not null,
  category text not null,
  order_index int not null,
  min_points_required int default 0
);

create table if not exists public.vocabularies (
  id text primary key,
  lesson_id text not null references public.lessons(id) on delete cascade,
  word text not null,
  phonetic text,
  meaning text not null,
  example_sentence text,
  audio_url text
);

create table if not exists public.user_vocab_progress (
  user_id uuid not null references public.users(id) on delete cascade,
  vocab_id text not null references public.vocabularies(id) on delete cascade,
  mastery_level int default 0 check (mastery_level between 0 and 5),
  review_count int default 0,
  last_reviewed_at timestamptz,
  next_review_at timestamptz not null,
  primary key (user_id, vocab_id)
);

create table if not exists public.photo_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  image_path text not null,
  template_id text default 'standard',
  note_title text not null,
  created_at timestamptz default now()
);

create table if not exists public.photo_note_vocabularies (
  photo_note_id uuid not null references public.photo_notes(id) on delete cascade,
  vocab_id text not null references public.vocabularies(id) on delete cascade,
  primary key (photo_note_id, vocab_id)
);

create table if not exists public.solo_arena_matches (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid not null references public.users(id) on delete cascade,
  guest_user_id uuid references public.users(id) on delete cascade,
  bet_amount int not null check (bet_amount >= 0),
  winner_id uuid references public.users(id),
  host_score int default 0,
  guest_score int default 0,
  status text default 'waiting'
    check (status in ('waiting', 'in_progress', 'completed', 'cancelled')),
  matched_at timestamptz default now(),
  created_at timestamptz default now(),
  finished_at timestamptz
);

create table if not exists public.pet_items (
  id text primary key,
  item_name text not null,
  price int not null check (price >= 0),
  rarity text default 'common',
  category text not null,
  icon_url text
);

create table if not exists public.user_pet_inventory (
  user_id uuid not null references public.users(id) on delete cascade,
  item_id text not null references public.pet_items(id) on delete cascade,
  purchased_at timestamptz default now(),
  is_equipped boolean default false,
  primary key (user_id, item_id)
);

create table if not exists public.friends (
  user_id uuid not null references public.users(id) on delete cascade,
  friend_id uuid not null references public.users(id) on delete cascade,
  status text default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz default now(),
  primary key (user_id, friend_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  message text not null,
  is_ai_response boolean default false,
  timestamp timestamptz default now()
);

create table if not exists public.shop_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  item_id text not null references public.pet_items(id) on delete cascade,
  amount int not null check (amount >= 0),
  payment_method text not null,
  transaction_id text not null,
  created_at timestamptz default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  plan_type text not null,
  status text default 'active'
    check (status in ('active', 'expired', 'cancelled')),
  start_date timestamptz default now(),
  end_date timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text default 'info',
  is_read boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_users_leaderboard
  on public.users (study_points desc, streak_days desc);
create index if not exists idx_vocab_srs_due
  on public.user_vocab_progress (user_id, next_review_at asc);
create index if not exists idx_photo_notes_user
  on public.photo_notes (user_id, created_at desc);
create index if not exists idx_chat_messages_user
  on public.chat_messages (user_id, timestamp asc);

alter table public.users enable row level security;
alter table public.user_settings enable row level security;
alter table public.lessons enable row level security;
alter table public.vocabularies enable row level security;
alter table public.user_vocab_progress enable row level security;
alter table public.photo_notes enable row level security;
alter table public.photo_note_vocabularies enable row level security;
alter table public.solo_arena_matches enable row level security;
alter table public.pet_items enable row level security;
alter table public.user_pet_inventory enable row level security;
alter table public.friends enable row level security;
alter table public.chat_messages enable row level security;
alter table public.shop_purchases enable row level security;
alter table public.subscriptions enable row level security;
alter table public.notifications enable row level security;

create policy "Public profiles are viewable by authenticated users"
  on public.users for select
  using (auth.role() = 'authenticated');

create policy "Users can insert their own profile"
  on public.users for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.users for update
  using (auth.uid() = id);

create policy "Users manage their own settings"
  on public.user_settings for all
  using (auth.uid() = user_id);

create policy "Lessons are viewable by all"
  on public.lessons for select using (true);
create policy "Vocabularies are viewable by all"
  on public.vocabularies for select using (true);
create policy "Pet items are viewable by all"
  on public.pet_items for select using (true);

create policy "Users manage their own SRS progress"
  on public.user_vocab_progress for all
  using (auth.uid() = user_id);

create policy "Users manage their own photo notes"
  on public.photo_notes for all
  using (auth.uid() = user_id);

create policy "Users manage photo note vocabs"
  on public.photo_note_vocabularies for all
  using (
    exists (
      select 1
      from public.photo_notes
      where id = photo_note_id and user_id = auth.uid()
    )
  );

create policy "Match players can view match"
  on public.solo_arena_matches for select
  using (
    auth.uid() = host_user_id
    or auth.uid() = guest_user_id
    or status = 'waiting'
  );

create policy "Authenticated users can create match"
  on public.solo_arena_matches for insert
  with check (auth.uid() = host_user_id);

create policy "Players can update their match"
  on public.solo_arena_matches for update
  using (auth.uid() = host_user_id or auth.uid() = guest_user_id);

create policy "Users manage their pet inventory"
  on public.user_pet_inventory for all
  using (auth.uid() = user_id);

create policy "Users view their purchases"
  on public.shop_purchases for all
  using (auth.uid() = user_id);

create policy "Users view their friend connections"
  on public.friends for select
  using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "Users manage friend requests"
  on public.friends for all
  using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "Users manage their chat messages"
  on public.chat_messages for all
  using (auth.uid() = user_id);

create policy "Users view their subscriptions"
  on public.subscriptions for select
  using (auth.uid() = user_id);

create policy "Users manage their notifications"
  on public.notifications for all
  using (auth.uid() = user_id);

alter publication supabase_realtime add table public.solo_arena_matches;
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.notifications;

insert into storage.buckets (id, name, public)
values ('photo_notes', 'photo_notes', true)
on conflict (id) do nothing;

create policy "Public Access Photo Notes"
  on storage.objects for select
  using (bucket_id = 'photo_notes');

create policy "User Upload Photo Notes"
  on storage.objects for insert
  with check (
    bucket_id = 'photo_notes'
    and auth.role() = 'authenticated'
  );
