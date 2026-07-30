-- =============================================================================
-- CAPY VOCAB APP - MIGRATION: ALIGN LIVE DATABASE WITH FINAL SECURE SCHEMA
-- Apply once to project: vmxonxqxrlkssdzsucrg
-- Date: 2026-07-30
--
-- Review Flutter impact before applying:
-- - photo_notes bucket becomes private
-- - direct writes to economy/shop/inventory/subscriptions/arena results blocked
-- - users table SELECT becomes own-row only; use get_public_profiles() for public data
-- =============================================================================

BEGIN;

-- Remove duplicate phone-format constraint seen on Production.
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_phone_check;


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

COMMIT;