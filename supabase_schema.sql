-- =============================================================================
-- CAPY VOCAB - SUPABASE POSTGRESQL DATABASE SCHEMA & ROW LEVEL SECURITY (RLS)
-- Includes 12 base entities from database_design.html + 3 additional tables:
-- shop_purchases, subscriptions, notifications (Total: 15 tables)
-- =============================================================================

-- Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. TABLE: users
-- -----------------------------------------------------------------------------
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
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2. TABLE: user_settings (1-1 with users)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    theme_mode TEXT DEFAULT 'light' CHECK (theme_mode IN ('light', 'dark')),
    daily_target_words INT DEFAULT 10 CHECK (daily_target_words > 0),
    reminder_time TEXT DEFAULT '20:00',
    sound_effects_enabled BOOLEAN DEFAULT TRUE
);

-- -----------------------------------------------------------------------------
-- 3. TABLE: lessons
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.lessons (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    order_index INT NOT NULL,
    min_points_required INT DEFAULT 0
);

-- -----------------------------------------------------------------------------
-- 4. TABLE: vocabularies
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vocabularies (
    id TEXT PRIMARY KEY,
    lesson_id TEXT NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
    word TEXT NOT NULL,
    phonetic TEXT,
    meaning TEXT NOT NULL,
    example_sentence TEXT,
    audio_url TEXT
);

-- -----------------------------------------------------------------------------
-- 5. TABLE: user_vocab_progress (SRS)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_vocab_progress (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    vocab_id TEXT NOT NULL REFERENCES public.vocabularies(id) ON DELETE CASCADE,
    mastery_level INT DEFAULT 0 CHECK (mastery_level BETWEEN 0 AND 5),
    review_count INT DEFAULT 0,
    last_reviewed_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (user_id, vocab_id)
);

-- -----------------------------------------------------------------------------
-- 6. TABLE: photo_notes (AI Vision Scan Album)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.photo_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    image_path TEXT NOT NULL,
    template_id TEXT DEFAULT 'standard',
    note_title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 7. TABLE: photo_note_vocabularies (N-N photo_notes <-> vocabularies)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.photo_note_vocabularies (
    photo_note_id UUID NOT NULL REFERENCES public.photo_notes(id) ON DELETE CASCADE,
    vocab_id TEXT NOT NULL REFERENCES public.vocabularies(id) ON DELETE CASCADE,
    PRIMARY KEY (photo_note_id, vocab_id)
);

-- -----------------------------------------------------------------------------
-- 8. TABLE: solo_arena_matches (1v1 Realtime Arena)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.solo_arena_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    guest_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    bet_amount INT NOT NULL CHECK (bet_amount >= 0),
    winner_id UUID REFERENCES public.users(id),
    host_score INT DEFAULT 0,
    guest_score INT DEFAULT 0,
    status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting', 'in_progress', 'completed', 'cancelled')),
    matched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    finished_at TIMESTAMPTZ
);

-- -----------------------------------------------------------------------------
-- 9. TABLE: pet_items (Capybara Pet Shop Catalogue)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pet_items (
    id TEXT PRIMARY KEY,
    item_name TEXT NOT NULL,
    price INT NOT NULL CHECK (price >= 0),
    rarity TEXT DEFAULT 'common',
    category TEXT NOT NULL,
    icon_url TEXT
);

-- -----------------------------------------------------------------------------
-- 10. TABLE: user_pet_inventory
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_pet_inventory (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES public.pet_items(id) ON DELETE CASCADE,
    purchased_at TIMESTAMPTZ DEFAULT NOW(),
    is_equipped BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, item_id)
);

-- -----------------------------------------------------------------------------
-- 11. TABLE: friends
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.friends (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id)
);

-- -----------------------------------------------------------------------------
-- 12. TABLE: chat_messages (AI Chatbot)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_ai_response BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 13. TABLE: shop_purchases (Bảng bổ sung - Lịch sử mua sắm)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shop_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    item_id TEXT NOT NULL REFERENCES public.pet_items(id) ON DELETE CASCADE,
    amount INT NOT NULL CHECK (amount >= 0),
    payment_method TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 14. TABLE: subscriptions (Bảng bổ sung - Gói Pro)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    plan_type TEXT NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 15. TABLE: notifications (Bảng bổ sung - Thông báo)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- INDEXES FOR QUERY OPTIMIZATION
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_users_leaderboard ON public.users (study_points DESC, streak_days DESC);
CREATE INDEX IF NOT EXISTS idx_vocab_srs_due ON public.user_vocab_progress (user_id, next_review_at ASC);
CREATE INDEX IF NOT EXISTS idx_photo_notes_user ON public.photo_notes (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON public.chat_messages (user_id, timestamp ASC);

-- =============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS on all tables
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

-- 1. users: All authenticated users can read (for profiles & leaderboards), owner can update
CREATE POLICY "Public profiles are viewable by authenticated users" 
ON public.users FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert their own profile" 
ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
ON public.users FOR UPDATE USING (auth.uid() = id);

-- 2. user_settings: Owner access only
CREATE POLICY "Users manage their own settings" 
ON public.user_settings FOR ALL USING (auth.uid() = user_id);

-- 3. lessons & 4. vocabularies & 9. pet_items: Read-only for authenticated users
CREATE POLICY "Lessons are viewable by all" ON public.lessons FOR SELECT USING (true);
CREATE POLICY "Vocabularies are viewable by all" ON public.vocabularies FOR SELECT USING (true);
CREATE POLICY "Pet items are viewable by all" ON public.pet_items FOR SELECT USING (true);

-- 5. user_vocab_progress: Owner access only
CREATE POLICY "Users manage their own SRS progress" 
ON public.user_vocab_progress FOR ALL USING (auth.uid() = user_id);

-- 6. photo_notes & 7. photo_note_vocabularies: Owner access only
CREATE POLICY "Users manage their own photo notes" 
ON public.photo_notes FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users manage photo note vocabs" 
ON public.photo_note_vocabularies FOR ALL USING (
    EXISTS (SELECT 1 FROM public.photo_notes WHERE id = photo_note_id AND user_id = auth.uid())
);

-- 8. solo_arena_matches: Players in match can read/update
CREATE POLICY "Match players can view match" 
ON public.solo_arena_matches FOR SELECT USING (
    auth.uid() = host_user_id OR auth.uid() = guest_user_id OR status = 'waiting'
);

CREATE POLICY "Authenticated users can create match" 
ON public.solo_arena_matches FOR INSERT WITH CHECK (auth.uid() = host_user_id);

CREATE POLICY "Players can update their match" 
ON public.solo_arena_matches FOR UPDATE USING (
    auth.uid() = host_user_id OR auth.uid() = guest_user_id
);

-- 10. user_pet_inventory & 13. shop_purchases: Owner access only
CREATE POLICY "Users manage their pet inventory" 
ON public.user_pet_inventory FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users view their purchases" 
ON public.shop_purchases FOR ALL USING (auth.uid() = user_id);

-- 11. friends: Either party in friend relationship can read/manage
CREATE POLICY "Users view their friend connections" 
ON public.friends FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users manage friend requests" 
ON public.friends FOR ALL USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- 12. chat_messages: Owner access only
CREATE POLICY "Users manage their chat messages" 
ON public.chat_messages FOR ALL USING (auth.uid() = user_id);

-- 14. subscriptions & 15. notifications: Owner access only
CREATE POLICY "Users view their subscriptions" 
ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users manage their notifications" 
ON public.notifications FOR ALL USING (auth.uid() = user_id);

-- =============================================================================
-- SUPABASE REALTIME PUBLICATION ENABLEMENT
-- =============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.solo_arena_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- =============================================================================
-- SUPABASE STORAGE BUCKET CONFIGURATION
-- =============================================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('photo_notes', 'photo_notes', true) 
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Access Photo Notes" 
ON storage.objects FOR SELECT USING (bucket_id = 'photo_notes');

CREATE POLICY "User Upload Photo Notes" 
ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'photo_notes' AND auth.role() = 'authenticated');
