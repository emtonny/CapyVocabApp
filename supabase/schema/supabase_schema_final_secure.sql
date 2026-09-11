-- Schema Snapshot: supabase_schema_final_secure.sql
-- Viết toàn bộ schema SQL định năng tại đây
-- =============================================================================
-- CAPY VOCAB - SUPABASE POSTGRESQL DATABASE SCHEMA & ROW LEVEL SECURITY (RLS)
-- Reference snapshot for 20 product/Library tables. The ordered migration
-- chain is canonical for deployment and also creates operational tables such
-- as public.gemini_model_health.
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
    media_asset_id UUID,
    primary_scan_run_id UUID,
    template_id TEXT DEFAULT 'standard',
    note_title TEXT NOT NULL,
    emoji TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    sync_version BIGINT NOT NULL DEFAULT 1 CHECK (sync_version > 0)
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
    user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    plan_type TEXT NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
    start_date TIMESTAMPTZ DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS subscriptions_user_status_end_date_idx
ON public.subscriptions (user_id, status, end_date DESC);

-- -----------------------------------------------------------------------------
-- 15. TABLE: ai_scan_requests (Idempotency + AI cost telemetry)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_scan_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_request_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    service_tier TEXT NOT NULL CHECK (service_tier IN ('free', 'pro')),
    status TEXT NOT NULL DEFAULT 'processing'
        CHECK (status IN ('processing', 'succeeded', 'failed')),
    model_used TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    input_token_count BIGINT NOT NULL DEFAULT 0 CHECK (input_token_count >= 0),
    output_token_count BIGINT NOT NULL DEFAULT 0 CHECK (output_token_count >= 0),
    total_token_count BIGINT NOT NULL DEFAULT 0 CHECK (total_token_count >= 0),
    latency_ms BIGINT CHECK (latency_ms >= 0),
    word_count INTEGER CHECK (word_count >= 0),
    error_code TEXT,
    result_json JSONB,
    result_expires_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ai_scan_requests_user_client_request_key
        UNIQUE (user_id, client_request_id),
    CONSTRAINT ai_scan_requests_result_has_no_image
        CHECK (result_json IS NULL OR NOT (result_json ? 'image_base64'))
);

CREATE INDEX IF NOT EXISTS ai_scan_requests_result_expiry_idx
ON public.ai_scan_requests (result_expires_at)
WHERE result_json IS NOT NULL;

CREATE OR REPLACE FUNCTION public.reserve_ai_scan_request(
    p_user_id UUID,
    p_client_request_id UUID,
    p_service_tier TEXT
)
RETURNS TABLE (
    decision TEXT,
    attempt_count INTEGER,
    result_json JSONB,
    model_used TEXT,
    service_tier TEXT,
    input_token_count BIGINT,
    output_token_count BIGINT,
    total_token_count BIGINT
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    request_row public.ai_scan_requests%ROWTYPE;
BEGIN
    IF p_service_tier NOT IN ('free', 'pro') THEN
        RAISE EXCEPTION 'Unsupported service tier: %', p_service_tier
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.ai_scan_requests (
        client_request_id, user_id, service_tier, status
    ) VALUES (
        p_client_request_id, p_user_id, p_service_tier, 'processing'
    )
    ON CONFLICT (user_id, client_request_id) DO NOTHING
    RETURNING * INTO request_row;

    IF FOUND THEN
        RETURN QUERY SELECT
            'reserved'::TEXT, request_row.attempt_count,
            request_row.result_json, request_row.model_used,
            request_row.service_tier, request_row.input_token_count,
            request_row.output_token_count, request_row.total_token_count;
        RETURN;
    END IF;

    SELECT * INTO request_row
    FROM public.ai_scan_requests AS request
    WHERE request.user_id = p_user_id
      AND request.client_request_id = p_client_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'AI scan reservation disappeared';
    END IF;

    IF request_row.status = 'succeeded' THEN
        RETURN QUERY SELECT
            CASE WHEN request_row.result_json IS NOT NULL
                       AND request_row.result_expires_at > NOW()
                THEN 'replay'::TEXT ELSE 'expired'::TEXT END,
            request_row.attempt_count, request_row.result_json,
            request_row.model_used, request_row.service_tier,
            request_row.input_token_count, request_row.output_token_count,
            request_row.total_token_count;
        RETURN;
    END IF;

    IF request_row.status = 'processing' THEN
        RETURN QUERY SELECT
            'in_progress'::TEXT, request_row.attempt_count, NULL::JSONB,
            request_row.model_used, request_row.service_tier,
            request_row.input_token_count, request_row.output_token_count,
            request_row.total_token_count;
        RETURN;
    END IF;

    UPDATE public.ai_scan_requests AS request
    SET status = 'processing', service_tier = p_service_tier,
        model_used = NULL, latency_ms = NULL, word_count = NULL,
        error_code = NULL, result_json = NULL, result_expires_at = NULL,
        started_at = NOW(), completed_at = NULL, updated_at = NOW()
    WHERE request.id = request_row.id
    RETURNING * INTO request_row;

    RETURN QUERY SELECT
        'reserved'::TEXT, request_row.attempt_count, request_row.result_json,
        request_row.model_used, request_row.service_tier,
        request_row.input_token_count, request_row.output_token_count,
        request_row.total_token_count;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_ai_scan_request(UUID, UUID, TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_ai_scan_request(UUID, UUID, TEXT)
TO service_role;

CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
DECLARE
    existing_job_id BIGINT;
BEGIN
    SELECT jobid INTO existing_job_id
    FROM cron.job
    WHERE jobname = 'purge-ai-scan-result-json-hourly'
    LIMIT 1;
    IF existing_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(existing_job_id);
    END IF;
    PERFORM cron.schedule(
        'purge-ai-scan-result-json-hourly',
        '17 * * * *',
        $command$
            UPDATE public.ai_scan_requests
            SET result_json = NULL, updated_at = NOW()
            WHERE result_json IS NOT NULL
              AND result_expires_at <= NOW();
        $command$
    );
END;
$$;

-- -----------------------------------------------------------------------------
-- 16. TABLE: notifications (Bảng bổ sung - Thông báo)
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
-- M3A NORMALIZED LIBRARY CLOUD CONTRACT
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.media_assets (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content_hash_sha256 TEXT NOT NULL CHECK (content_hash_sha256 ~ '^[0-9a-f]{64}$'),
    original_object_path TEXT,
    display_object_path TEXT NOT NULL,
    model_input_object_path TEXT,
    mime_type TEXT NOT NULL,
    width INTEGER NOT NULL CHECK (width > 0),
    height INTEGER NOT NULL CHECK (height > 0),
    orientation INTEGER NOT NULL DEFAULT 0 CHECK (orientation >= 0),
    byte_size_original BIGINT CHECK (byte_size_original >= 0),
    byte_size_display BIGINT NOT NULL CHECK (byte_size_display >= 0),
    preprocessing_version TEXT NOT NULL,
    capture_source TEXT NOT NULL CHECK (
        capture_source IN ('camera', 'gallery', 'imported', 'migration')
    ),
    captured_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    sync_version BIGINT NOT NULL DEFAULT 1 CHECK (sync_version > 0),
    UNIQUE (id, user_id),
    CHECK (
        split_part(display_object_path, '/', 1) = user_id::text
        AND split_part(display_object_path, '/', 2) = id::text
        AND split_part(display_object_path, '/', 3)
            ~ '^display\.(jpg|jpeg|png|webp|heic)$'
        AND array_length(string_to_array(display_object_path, '/'), 1) = 3
    ),
    CHECK (
        original_object_path IS NULL OR (
            split_part(original_object_path, '/', 1) = user_id::text
            AND split_part(original_object_path, '/', 2) = id::text
            AND split_part(original_object_path, '/', 3)
                ~ '^original\.(jpg|jpeg|png|webp|heic)$'
            AND array_length(string_to_array(original_object_path, '/'), 1) = 3
        )
    ),
    CHECK (
        model_input_object_path IS NULL OR (
            split_part(model_input_object_path, '/', 1) = user_id::text
            AND split_part(model_input_object_path, '/', 2) = id::text
            AND split_part(model_input_object_path, '/', 3)
                ~ '^model_input\.(jpg|jpeg|png|webp|heic)$'
            AND array_length(string_to_array(model_input_object_path, '/'), 1) = 3
        )
    )
);

CREATE TABLE IF NOT EXISTS public.scan_runs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    media_asset_id UUID NOT NULL,
    request_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    model_name TEXT NOT NULL,
    model_version TEXT,
    service_tier TEXT,
    prompt_version TEXT NOT NULL,
    response_schema_version TEXT NOT NULL,
    preprocessing_version TEXT NOT NULL,
    raw_response_json JSONB,
    response_hash_sha256 TEXT CHECK (
        response_hash_sha256 IS NULL OR response_hash_sha256 ~ '^[0-9a-f]{64}$'
    ),
    status TEXT NOT NULL CHECK (
        status IN ('pending', 'succeeded', 'failed', 'quarantined')
    ),
    error_code TEXT,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_version BIGINT NOT NULL DEFAULT 1 CHECK (sync_version > 0),
    UNIQUE (id, user_id),
    UNIQUE (user_id, request_id),
    CHECK (completed_at IS NULL OR completed_at >= started_at),
    CHECK (
        status <> 'succeeded'
        OR (raw_response_json IS NOT NULL AND response_hash_sha256 IS NOT NULL)
    ),
    FOREIGN KEY (media_asset_id, user_id)
        REFERENCES public.media_assets(id, user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.vocab_detections (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    scan_run_id UUID NOT NULL,
    word_raw TEXT NOT NULL CHECK (length(btrim(word_raw)) > 0),
    word_normalized TEXT NOT NULL CHECK (length(btrim(word_normalized)) > 0),
    phonetic TEXT,
    meaning_vi TEXT,
    part_of_speech TEXT,
    example_en TEXT,
    example_vi TEXT,
    bbox_x DOUBLE PRECISION,
    bbox_y DOUBLE PRECISION,
    bbox_width DOUBLE PRECISION,
    bbox_height DOUBLE PRECISION,
    confidence DOUBLE PRECISION CHECK (
        confidence IS NULL OR confidence BETWEEN 0.0 AND 1.0
    ),
    display_order INTEGER NOT NULL CHECK (display_order >= 0),
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE (id, user_id),
    CHECK (
        (
            bbox_x IS NULL AND bbox_y IS NULL
            AND bbox_width IS NULL AND bbox_height IS NULL
        ) OR (
            bbox_x BETWEEN 0.0 AND 1.0
            AND bbox_y BETWEEN 0.0 AND 1.0
            AND bbox_width > 0.0 AND bbox_height > 0.0
            AND bbox_x + bbox_width <= 1.0
            AND bbox_y + bbox_height <= 1.0
        )
    ),
    FOREIGN KEY (scan_run_id, user_id)
        REFERENCES public.scan_runs(id, user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.vocab_annotations (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    detection_id UUID NOT NULL,
    source TEXT NOT NULL CHECK (
        source IN ('user_confirmed', 'user_corrected', 'imported')
    ),
    quality_status TEXT NOT NULL CHECK (
        quality_status IN ('accepted', 'corrected', 'rejected')
    ),
    corrected_word TEXT,
    corrected_phonetic TEXT,
    corrected_meaning_vi TEXT,
    corrected_bbox_x DOUBLE PRECISION,
    corrected_bbox_y DOUBLE PRECISION,
    corrected_bbox_width DOUBLE PRECISION,
    corrected_bbox_height DOUBLE PRECISION,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    UNIQUE (id, user_id),
    UNIQUE (detection_id, revision),
    CHECK (updated_at >= created_at),
    CHECK (
        (
            corrected_bbox_x IS NULL AND corrected_bbox_y IS NULL
            AND corrected_bbox_width IS NULL AND corrected_bbox_height IS NULL
        ) OR (
            corrected_bbox_x BETWEEN 0.0 AND 1.0
            AND corrected_bbox_y BETWEEN 0.0 AND 1.0
            AND corrected_bbox_width > 0.0 AND corrected_bbox_height > 0.0
            AND corrected_bbox_x + corrected_bbox_width <= 1.0
            AND corrected_bbox_y + corrected_bbox_height <= 1.0
        )
    ),
    CHECK (
        source <> 'user_corrected'
        OR corrected_word IS NOT NULL
        OR corrected_phonetic IS NOT NULL
        OR corrected_meaning_vi IS NOT NULL
        OR corrected_bbox_x IS NOT NULL
    ),
    FOREIGN KEY (detection_id, user_id)
        REFERENCES public.vocab_detections(id, user_id) ON DELETE CASCADE
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'photo_notes_media_asset_owner_fkey'
          AND conrelid = 'public.photo_notes'::regclass
    ) THEN
        ALTER TABLE public.photo_notes
            ADD CONSTRAINT photo_notes_media_asset_owner_fkey
            FOREIGN KEY (media_asset_id, user_id)
            REFERENCES public.media_assets(id, user_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'photo_notes_primary_scan_owner_fkey'
          AND conrelid = 'public.photo_notes'::regclass
    ) THEN
        ALTER TABLE public.photo_notes
            ADD CONSTRAINT photo_notes_primary_scan_owner_fkey
            FOREIGN KEY (primary_scan_run_id, user_id)
            REFERENCES public.scan_runs(id, user_id);
    END IF;
END
$$;

-- =============================================================================
-- INDEXES FOR QUERY OPTIMIZATION
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_users_leaderboard ON public.users (study_points DESC, streak_days DESC);
CREATE INDEX IF NOT EXISTS idx_vocab_srs_due ON public.user_vocab_progress (user_id, next_review_at ASC);
CREATE INDEX IF NOT EXISTS idx_photo_notes_user ON public.photo_notes (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user ON public.chat_messages (user_id, timestamp ASC);
CREATE INDEX IF NOT EXISTS idx_media_assets_user_created ON public.media_assets (user_id, deleted_at, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scan_runs_user_media ON public.scan_runs (user_id, media_asset_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_vocab_detections_user_scan ON public.vocab_detections (user_id, scan_run_id, display_order);
CREATE INDEX IF NOT EXISTS idx_vocab_annotations_user_detection ON public.vocab_annotations (user_id, detection_id, revision DESC);
CREATE INDEX IF NOT EXISTS idx_photo_notes_user_updated ON public.photo_notes (user_id, deleted_at, updated_at DESC);

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
ALTER TABLE public.ai_scan_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scan_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocab_detections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vocab_annotations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.subscriptions
TO service_role;

REVOKE ALL ON TABLE public.ai_scan_requests
FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.ai_scan_requests
TO service_role;

REVOKE ALL ON TABLE public.media_assets FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.scan_runs FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.vocab_detections FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.vocab_annotations FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.media_assets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.scan_runs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vocab_detections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vocab_annotations TO authenticated;

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
ON public.photo_notes FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users manage their own media assets"
ON public.media_assets FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users manage their own scan runs"
ON public.scan_runs FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users manage their own vocab detections"
ON public.vocab_detections FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users manage their own vocab annotations"
ON public.vocab_annotations FOR ALL TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

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
ON public.subscriptions
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);

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
VALUES ('photo_notes', 'photo_notes', false)
ON CONFLICT (id) DO UPDATE SET public = false;

CREATE POLICY "Users read their own photo note media"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users upload their own photo note media"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users update their own photo note media"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
)
WITH CHECK (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

CREATE POLICY "Users delete their own photo note media"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'photo_notes'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
);

-- =============================================================================
-- M4.5 OWNER-SCOPED LIBRARY CHANGE FEED
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.library_change_events (
    sequence BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN (
        'media_asset', 'scan_run', 'vocab_detection',
        'vocab_annotation', 'photo_note'
    )),
    entity_id UUID NOT NULL,
    media_asset_id UUID,
    photo_note_id UUID,
    operation TEXT NOT NULL CHECK (operation IN ('upsert', 'delete')),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_library_change_events_owner_sequence
ON public.library_change_events (user_id, sequence);

ALTER TABLE public.library_change_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.library_change_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.library_change_events TO authenticated;

CREATE POLICY "Users read their own library change feed"
ON public.library_change_events FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE OR REPLACE FUNCTION public.capture_library_change_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    source_row RECORD;
    owner_id UUID;
    source_id UUID;
    root_media_id UUID;
    root_note_id UUID;
    entity_kind TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        source_row := OLD;
    ELSE
        source_row := NEW;
    END IF;
    owner_id := source_row.user_id;
    source_id := source_row.id;
    IF TG_TABLE_NAME = 'media_assets' THEN
        entity_kind := 'media_asset';
        root_media_id := source_row.id;
    ELSIF TG_TABLE_NAME = 'scan_runs' THEN
        entity_kind := 'scan_run';
        root_media_id := source_row.media_asset_id;
    ELSIF TG_TABLE_NAME = 'vocab_detections' THEN
        entity_kind := 'vocab_detection';
        SELECT s.media_asset_id INTO root_media_id
        FROM public.scan_runs s
        WHERE s.id = source_row.scan_run_id AND s.user_id = owner_id;
    ELSIF TG_TABLE_NAME = 'vocab_annotations' THEN
        entity_kind := 'vocab_annotation';
        SELECT s.media_asset_id INTO root_media_id
        FROM public.vocab_detections d
        JOIN public.scan_runs s ON s.id = d.scan_run_id
        WHERE d.id = source_row.detection_id AND s.user_id = owner_id;
    ELSE
        entity_kind := 'photo_note';
        root_media_id := source_row.media_asset_id;
        root_note_id := source_row.id;
    END IF;
    INSERT INTO public.library_change_events (
        user_id, entity_type, entity_id, media_asset_id, photo_note_id,
        operation
    ) VALUES (
        owner_id, entity_kind, source_id, root_media_id, root_note_id,
        CASE WHEN TG_OP = 'DELETE' THEN 'delete' ELSE 'upsert' END
    );
    RETURN source_row;
END;
$$;

REVOKE ALL ON FUNCTION public.capture_library_change_event() FROM PUBLIC;

CREATE TRIGGER trg_media_assets_library_change
AFTER INSERT OR UPDATE OR DELETE ON public.media_assets
FOR EACH ROW EXECUTE FUNCTION public.capture_library_change_event();
CREATE TRIGGER trg_scan_runs_library_change
AFTER INSERT OR UPDATE OR DELETE ON public.scan_runs
FOR EACH ROW EXECUTE FUNCTION public.capture_library_change_event();
CREATE TRIGGER trg_vocab_detections_library_change
AFTER INSERT OR UPDATE OR DELETE ON public.vocab_detections
FOR EACH ROW EXECUTE FUNCTION public.capture_library_change_event();
CREATE TRIGGER trg_vocab_annotations_library_change
AFTER INSERT OR UPDATE OR DELETE ON public.vocab_annotations
FOR EACH ROW EXECUTE FUNCTION public.capture_library_change_event();
CREATE TRIGGER trg_photo_notes_library_change
AFTER INSERT OR UPDATE OR DELETE ON public.photo_notes
FOR EACH ROW EXECUTE FUNCTION public.capture_library_change_event();

CREATE OR REPLACE FUNCTION public.pull_library_delta(
    p_after_sequence BIGINT DEFAULT 0,
    p_limit INTEGER DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    owner_id UUID := auth.uid();
    next_sequence BIGINT := p_after_sequence;
    media_ids UUID[] := ARRAY[]::UUID[];
    deletion_rows JSONB := '[]'::JSONB;
    more_rows BOOLEAN := FALSE;
BEGIN
    IF owner_id IS NULL THEN
        RAISE EXCEPTION 'authentication required' USING ERRCODE = '42501';
    END IF;
    IF p_after_sequence < 0 OR p_limit < 1 OR p_limit > 500 THEN
        RAISE EXCEPTION 'invalid Library pull cursor or limit'
            USING ERRCODE = '22023';
    END IF;
    SELECT
        COALESCE(MAX(batch.sequence), p_after_sequence),
        COALESCE(
            ARRAY_AGG(DISTINCT batch.media_asset_id)
                FILTER (WHERE batch.media_asset_id IS NOT NULL),
            ARRAY[]::UUID[]
        ),
        COALESCE(
            JSONB_AGG(JSONB_BUILD_OBJECT(
                'sequence', batch.sequence,
                'user_id', batch.user_id,
                'photo_note_id', batch.photo_note_id,
                'changed_at', batch.changed_at
            ) ORDER BY batch.sequence) FILTER (
                WHERE batch.entity_type = 'photo_note'
                  AND batch.operation = 'delete'
            ),
            '[]'::JSONB
        )
    INTO next_sequence, media_ids, deletion_rows
    FROM (
        SELECT e.* FROM public.library_change_events e
        WHERE e.user_id = owner_id AND e.sequence > p_after_sequence
        ORDER BY e.sequence LIMIT p_limit
    ) batch;
    SELECT EXISTS (
        SELECT 1 FROM public.library_change_events e
        WHERE e.user_id = owner_id AND e.sequence > next_sequence
    ) INTO more_rows;
    RETURN JSONB_BUILD_OBJECT(
        'next_cursor', next_sequence,
        'has_more', more_rows,
        'deletions', deletion_rows,
        'media_assets', COALESCE((
            SELECT JSONB_AGG(TO_JSONB(m) ORDER BY m.id)
            FROM public.media_assets m
            WHERE m.user_id = owner_id AND m.id = ANY(media_ids)
        ), '[]'::JSONB),
        'scan_runs', COALESCE((
            SELECT JSONB_AGG(TO_JSONB(s) ORDER BY s.started_at, s.id)
            FROM public.scan_runs s
            WHERE s.user_id = owner_id AND s.media_asset_id = ANY(media_ids)
        ), '[]'::JSONB),
        'vocab_detections', COALESCE((
            SELECT JSONB_AGG(TO_JSONB(d) ORDER BY d.display_order, d.id)
            FROM public.vocab_detections d
            JOIN public.scan_runs s
              ON s.id = d.scan_run_id AND s.user_id = d.user_id
            WHERE d.user_id = owner_id AND s.media_asset_id = ANY(media_ids)
        ), '[]'::JSONB),
        'vocab_annotations', COALESCE((
            SELECT JSONB_AGG(TO_JSONB(a) ORDER BY a.updated_at, a.id)
            FROM public.vocab_annotations a
            JOIN public.vocab_detections d
              ON d.id = a.detection_id AND d.user_id = a.user_id
            JOIN public.scan_runs s
              ON s.id = d.scan_run_id AND s.user_id = d.user_id
            WHERE a.user_id = owner_id AND s.media_asset_id = ANY(media_ids)
        ), '[]'::JSONB),
        'photo_notes', COALESCE((
            SELECT JSONB_AGG(TO_JSONB(p) ORDER BY p.updated_at, p.id)
            FROM public.photo_notes p
            WHERE p.user_id = owner_id AND p.media_asset_id = ANY(media_ids)
        ), '[]'::JSONB)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.pull_library_delta(BIGINT, INTEGER)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pull_library_delta(BIGINT, INTEGER)
TO authenticated;
