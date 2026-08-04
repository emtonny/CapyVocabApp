-- =============================================================================
-- CAPY VOCAB APP - SUPABASE SCHEMA (SYNCED FROM LIVE PROJECT)
-- Project ref: vmxonxqxrlkssdzsucrg
-- Snapshot date: 2026-07-30
--
-- Purpose:
--   - Recreate the current public schema on a fresh Supabase project.
--   - Keep RLS fixes currently deployed to production.
--   - Include Auth -> public.users profile trigger and Storage configuration.
--
-- IMPORTANT:
--   - Run on a fresh project or as a reviewed migration.
--   - This file does not insert application seed data.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT DEFAULT '',
    study_points INT DEFAULT 0 CHECK (study_points >= 0),
    streak_days INT DEFAULT 0 CHECK (streak_days >= 0),
    total_coins INT DEFAULT 100 CHECK (total_coins >= 0),
    user_level INT DEFAULT 1 CHECK (user_level >= 1),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    username TEXT UNIQUE,
    age INT CHECK (age IS NULL OR age BETWEEN 1 AND 120),
    phone TEXT,
    account_role TEXT CHECK (
        account_role IS NULL OR account_role IN ('personal', 'parent')
    ),
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT users_phone_format_check CHECK (
        phone IS NULL OR phone ~ '^0[0-9]{9}$'
    )
);

CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    theme_mode TEXT DEFAULT 'light' CHECK (theme_mode IN ('light', 'dark')),
    daily_target_words INT DEFAULT 10 CHECK (daily_target_words > 0),
    reminder_time TEXT DEFAULT '20:00',
    sound_effects_enabled BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.lessons (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    order_index INT NOT NULL,
    min_points_required INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.vocabularies (
    id TEXT PRIMARY KEY,
    lesson_id TEXT NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    word TEXT NOT NULL,
    phonetic TEXT,
    meaning TEXT NOT NULL,
    example_sentence TEXT,
    audio_url TEXT
);

CREATE TABLE IF NOT EXISTS public.user_vocab_progress (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vocab_id TEXT NOT NULL REFERENCES public.vocabularies(id) ON DELETE CASCADE,
    mastery_level INT DEFAULT 0 CHECK (mastery_level BETWEEN 0 AND 5),
    review_count INT DEFAULT 0,
    last_reviewed_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (user_id, vocab_id)
);

CREATE TABLE IF NOT EXISTS public.photo_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    image_path TEXT NOT NULL,
    template_id TEXT DEFAULT 'standard',
    note_title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.photo_note_vocabularies (
    photo_note_id UUID NOT NULL REFERENCES public.photo_notes(id) ON DELETE CASCADE,
    vocab_id TEXT NOT NULL REFERENCES public.vocabularies(id) ON DELETE CASCADE,
    PRIMARY KEY (photo_note_id, vocab_id)
);

CREATE TABLE IF NOT EXISTS public.solo_arena_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    guest_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    bet_amount INT NOT NULL CHECK (bet_amount >= 0),
    winner_id UUID REFERENCES public.users(id),
    host_score INT DEFAULT 0,
    guest_score INT DEFAULT 0,
    status TEXT DEFAULT 'waiting' CHECK (
        status IN ('waiting', 'in_progress', 'completed', 'cancelled')
    ),
    matched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    finished_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.pet_items (
    id TEXT PRIMARY KEY,
    item_name TEXT NOT NULL,
    price INT NOT NULL CHECK (price >= 0),
    rarity TEXT DEFAULT 'common',
    category TEXT NOT NULL,
    icon_url TEXT
);

CREATE TABLE IF NOT EXISTS public.user_pet_inventory (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES public.pet_items(id) ON DELETE CASCADE,
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    is_equipped BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, item_id)
);

CREATE TABLE IF NOT EXISTS public.friends (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (
        status IN ('pending', 'accepted', 'rejected')
    ),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id)
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_ai_response BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.shop_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES public.pet_items(id) ON DELETE CASCADE,
    amount INT NOT NULL CHECK (amount >= 0),
    payment_method TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    plan_type TEXT NOT NULL,
    status TEXT DEFAULT 'active' CHECK (
        status IN ('active', 'expired', 'cancelled')
    ),
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns introduced after the original schema exist on older databases.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS age INT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS account_role TEXT;
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- =============================================================================
-- CONSTRAINTS / INDEXES
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS users_username_key
    ON public.users (username);
CREATE UNIQUE INDEX IF NOT EXISTS users_phone_key
    ON public.users (phone);
CREATE INDEX IF NOT EXISTS idx_users_leaderboard
    ON public.users (study_points DESC, streak_days DESC);
CREATE INDEX IF NOT EXISTS idx_vocab_srs_due
    ON public.user_vocab_progress (user_id, next_review_at ASC);
CREATE INDEX IF NOT EXISTS idx_photo_notes_user
    ON public.photo_notes (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user
    ON public.chat_messages (user_id, timestamp ASC);

-- Add newer checks only when they do not already exist.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'users_age_check'
          AND conrelid = 'public.users'::regclass
    ) THEN
        ALTER TABLE public.users
            ADD CONSTRAINT users_age_check
            CHECK (age IS NULL OR age BETWEEN 1 AND 120);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'users_phone_format_check'
          AND conrelid = 'public.users'::regclass
    ) THEN
        ALTER TABLE public.users
            ADD CONSTRAINT users_phone_format_check
            CHECK (phone IS NULL OR phone ~ '^0[0-9]{9}$');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'users_account_role_check'
          AND conrelid = 'public.users'::regclass
    ) THEN
        ALTER TABLE public.users
            ADD CONSTRAINT users_account_role_check
            CHECK (account_role IS NULL OR account_role IN ('personal', 'parent'));
    END IF;
END
$$;

-- =============================================================================
-- AUTH PROFILE SYNC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, display_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NEW.raw_user_meta_data ->> 'display_name',
            SPLIT_PART(NEW.email, '@', 1)
        )
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- ROW LEVEL SECURITY + COLUMN PRIVILEGES (HARDENED TARGET)
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocabularies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_vocab_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_note_vocabularies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solo_arena_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_pet_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Remove old/broad policies so this file is rerunnable.
DROP POLICY IF EXISTS "Public profiles are viewable by authenticated users" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users view own profile" ON public.users;
DROP POLICY IF EXISTS "Users update own profile" ON public.users;

DROP POLICY IF EXISTS "Users manage their own settings" ON public.user_settings;
DROP POLICY IF EXISTS "Lessons are viewable by all" ON public.lessons;
DROP POLICY IF EXISTS "Vocabularies are viewable by all" ON public.vocabularies;
DROP POLICY IF EXISTS "Pet items are viewable by all" ON public.pet_items;
DROP POLICY IF EXISTS "Users manage their own SRS progress" ON public.user_vocab_progress;
DROP POLICY IF EXISTS "Users manage their own photo notes" ON public.photo_notes;
DROP POLICY IF EXISTS "Users manage photo note vocabs" ON public.photo_note_vocabularies;

DROP POLICY IF EXISTS "Match players can view match" ON public.solo_arena_matches;
DROP POLICY IF EXISTS "Authenticated users can create match" ON public.solo_arena_matches;
DROP POLICY IF EXISTS "Players can update their match" ON public.solo_arena_matches;

DROP POLICY IF EXISTS "Users manage their pet inventory" ON public.user_pet_inventory;
DROP POLICY IF EXISTS "Users view their purchases" ON public.shop_purchases;

DROP POLICY IF EXISTS "Users view their friend connections" ON public.friends;
DROP POLICY IF EXISTS "Users manage friend requests" ON public.friends;
DROP POLICY IF EXISTS "Users create friend requests" ON public.friends;
DROP POLICY IF EXISTS "Users update received friend requests" ON public.friends;
DROP POLICY IF EXISTS "Users delete friend connections" ON public.friends;

DROP POLICY IF EXISTS "Users manage their chat messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Users read own chat messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Users create own chat messages" ON public.chat_messages;
DROP POLICY IF EXISTS "Users delete own chat messages" ON public.chat_messages;

DROP POLICY IF EXISTS "Users view their subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users manage their notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users update own notification state" ON public.notifications;
DROP POLICY IF EXISTS "Users delete own notifications" ON public.notifications;

-- ---------------------------------------------------------------------------
-- users: private profile row; client may edit profile columns only.
-- Sensitive/economic columns are protected with column privileges below.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users view own profile"
ON public.users FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users update own profile"
ON public.users FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = id)
WITH CHECK ((SELECT auth.uid()) = id);

-- Profiles are created by handle_new_user(); direct client INSERT is unnecessary.
REVOKE INSERT, DELETE ON public.users FROM authenticated;
REVOKE UPDATE ON public.users FROM authenticated;
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE (
    display_name,
    avatar_url,
    username,
    age,
    phone,
    account_role,
    onboarding_completed,
    updated_at
) ON public.users TO authenticated;

-- Safe public profile projection for leaderboard/friends.
CREATE OR REPLACE FUNCTION public.get_public_profiles(profile_ids UUID[] DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INT,
    streak_days INT,
    user_level INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        u.id,
        u.display_name,
        u.username,
        u.avatar_url,
        u.study_points,
        u.streak_days,
        u.user_level
    FROM public.users u
    WHERE profile_ids IS NULL OR u.id = ANY(profile_ids);
$$;

REVOKE ALL ON FUNCTION public.get_public_profiles(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(UUID[]) TO authenticated;

-- ---------------------------------------------------------------------------
-- User-owned regular data.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users manage their own settings"
ON public.user_settings FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- Complete onboarding in one transaction. SECURITY INVOKER keeps RLS and
-- column privileges active, while auth.uid() fixes ownership to the caller.
CREATE OR REPLACE FUNCTION public.complete_onboarding(
    p_display_name TEXT,
    p_username TEXT,
    p_age INT,
    p_phone TEXT,
    p_account_role TEXT,
    p_reminder_time TEXT,
    p_daily_target_words INT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID := (SELECT auth.uid());
    v_updated_rows INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '28000';
    END IF;

    IF BTRIM(COALESCE(p_display_name, '')) = '' THEN
        RAISE EXCEPTION 'Display name is required'
            USING ERRCODE = '22023';
    END IF;

    IF BTRIM(COALESCE(p_username, '')) !~ '^[a-zA-Z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Invalid username'
            USING ERRCODE = '22023';
    END IF;

    IF p_age IS NULL OR p_age < 1 OR p_age > 120 THEN
        RAISE EXCEPTION 'Age must be between 1 and 120'
            USING ERRCODE = '22023';
    END IF;

    IF p_phone IS NULL OR p_phone !~ '^0[0-9]{9}$' THEN
        RAISE EXCEPTION 'Invalid phone number'
            USING ERRCODE = '22023';
    END IF;

    IF p_account_role IS NULL
       OR p_account_role NOT IN ('personal', 'parent') THEN
        RAISE EXCEPTION 'Invalid account role'
            USING ERRCODE = '22023';
    END IF;

    IF p_reminder_time IS NULL
       OR p_reminder_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RAISE EXCEPTION 'Invalid reminder time'
            USING ERRCODE = '22023';
    END IF;

    IF p_daily_target_words IS NULL OR p_daily_target_words <= 0 THEN
        RAISE EXCEPTION 'Daily target must be greater than zero'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.users
    SET
        display_name = BTRIM(p_display_name),
        username = LOWER(BTRIM(p_username)),
        age = p_age,
        phone = p_phone,
        account_role = p_account_role,
        updated_at = NOW()
    WHERE id = v_user_id;

    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
    IF v_updated_rows <> 1 THEN
        RAISE EXCEPTION 'User profile not found'
            USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.user_settings (
        user_id,
        reminder_time,
        daily_target_words
    )
    VALUES (
        v_user_id,
        p_reminder_time,
        p_daily_target_words
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        reminder_time = EXCLUDED.reminder_time,
        daily_target_words = EXCLUDED.daily_target_words;

    UPDATE public.users
    SET
        onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = v_user_id;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_onboarding(
    TEXT,
    TEXT,
    INT,
    TEXT,
    TEXT,
    TEXT,
    INT
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.complete_onboarding(
    TEXT,
    TEXT,
    INT,
    TEXT,
    TEXT,
    TEXT,
    INT
) TO authenticated;

CREATE POLICY "Lessons are viewable by all"
ON public.lessons FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "Vocabularies are viewable by all"
ON public.vocabularies FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "Pet items are viewable by all"
ON public.pet_items FOR SELECT TO anon, authenticated
USING (true);

CREATE POLICY "Users manage their own SRS progress"
ON public.user_vocab_progress FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users manage their own photo notes"
ON public.photo_notes FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users manage photo note vocabs"
ON public.photo_note_vocabularies FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.photo_notes pn
        WHERE pn.id = photo_note_id
          AND pn.user_id = (SELECT auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.photo_notes pn
        WHERE pn.id = photo_note_id
          AND pn.user_id = (SELECT auth.uid())
    )
);

-- ---------------------------------------------------------------------------
-- Arena: clients can read and create waiting rooms, but cannot directly
-- modify score, winner, bet, guest or status. Use trusted RPC/Edge Function.
-- ---------------------------------------------------------------------------
CREATE POLICY "Match players can view match"
ON public.solo_arena_matches FOR SELECT TO authenticated
USING (
    (SELECT auth.uid()) = host_user_id
    OR (SELECT auth.uid()) = guest_user_id
    OR status = 'waiting'
);

CREATE POLICY "Authenticated users can create match"
ON public.solo_arena_matches FOR INSERT TO authenticated
WITH CHECK (
    (SELECT auth.uid()) = host_user_id
    AND guest_user_id IS NULL
    AND winner_id IS NULL
    AND host_score = 0
    AND guest_score = 0
    AND status = 'waiting'
);

REVOKE UPDATE, DELETE ON public.solo_arena_matches FROM authenticated;

-- ---------------------------------------------------------------------------
-- Shop/inventory: users may read only. All writes must be trusted server-side.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users view their inventory"
ON public.user_pet_inventory FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users view their purchases"
ON public.shop_purchases FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE INSERT, UPDATE, DELETE ON public.user_pet_inventory FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.shop_purchases FROM authenticated;

-- ---------------------------------------------------------------------------
-- Friends: requester creates; recipient may change status only.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users view their friend connections"
ON public.friends FOR SELECT TO authenticated
USING (
    (SELECT auth.uid()) = user_id
    OR (SELECT auth.uid()) = friend_id
);

CREATE POLICY "Users create friend requests"
ON public.friends FOR INSERT TO authenticated
WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND user_id <> friend_id
    AND status = 'pending'
);

CREATE POLICY "Users update received friend requests"
ON public.friends FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = friend_id)
WITH CHECK (
    (SELECT auth.uid()) = friend_id
    AND user_id <> friend_id
    AND status IN ('accepted', 'rejected')
);

CREATE POLICY "Users delete friend connections"
ON public.friends FOR DELETE TO authenticated
USING (
    (SELECT auth.uid()) = user_id
    OR (SELECT auth.uid()) = friend_id
);

REVOKE UPDATE ON public.friends FROM authenticated;
GRANT UPDATE (status) ON public.friends TO authenticated;

-- ---------------------------------------------------------------------------
-- Chat: user can create normal messages only; AI responses require backend.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users read own chat messages"
ON public.chat_messages FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users create own chat messages"
ON public.chat_messages FOR INSERT TO authenticated
WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND is_ai_response = FALSE
);

CREATE POLICY "Users delete own chat messages"
ON public.chat_messages FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE UPDATE ON public.chat_messages FROM authenticated;

-- ---------------------------------------------------------------------------
-- Subscriptions: read only from client.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users view their subscriptions"
ON public.subscriptions FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE INSERT, UPDATE, DELETE ON public.subscriptions FROM authenticated;

-- ---------------------------------------------------------------------------
-- Notifications: backend creates; client reads, marks read, or deletes.
-- ---------------------------------------------------------------------------
CREATE POLICY "Users read own notifications"
ON public.notifications FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users update own notification state"
ON public.notifications FOR UPDATE TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users delete own notifications"
ON public.notifications FOR DELETE TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE INSERT ON public.notifications FROM authenticated;
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT UPDATE (is_read) ON public.notifications TO authenticated;

-- =============================================================================
-- REALTIME
-- =============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'solo_arena_matches'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.solo_arena_matches;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
END
$$;

-- =============================================================================
-- STORAGE
-- =============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('photo_notes', 'photo_notes', FALSE)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public;

DROP POLICY IF EXISTS "Public Access Photo Notes" ON storage.objects;
DROP POLICY IF EXISTS "User Upload Photo Notes" ON storage.objects;
DROP POLICY IF EXISTS "Users read own photo notes" ON storage.objects;
DROP POLICY IF EXISTS "Users update own photo notes" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own photo notes" ON storage.objects;

CREATE POLICY "Users read own photo notes"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY "User Upload Photo Notes"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY "Users update own photo notes"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
)
WITH CHECK (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

CREATE POLICY "Users delete own photo notes"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::TEXT
);

-- =============================================================================
-- NOTES FOR FLUTTER
-- =============================================================================
-- 1) Upload path must be: <auth.uid()>/<filename>
-- 2) Bucket is private. Read images with createSignedUrl(), not getPublicUrl().
-- 3) Do not update users.study_points/total_coins/streak_days/user_level directly.
-- 4) Purchases, inventory grants, subscriptions, AI replies, notifications and
--    arena results must be written through service-role backend/RPC/Edge Function.
