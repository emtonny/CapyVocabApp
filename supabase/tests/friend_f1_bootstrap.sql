-- Minimal pre-F1 schema for isolated native PostgreSQL verification.
-- Synthetic identities only; no remote project or credentials are used.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;

CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA public, auth, private TO authenticated, service_role;
GRANT USAGE ON SCHEMA public, auth TO anon;

CREATE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID;
$$;

CREATE TABLE auth.users (
    id UUID PRIMARY KEY,
    email TEXT,
    email_confirmed_at TIMESTAMPTZ,
    phone TEXT,
    phone_confirmed_at TIMESTAMPTZ
);

CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    username TEXT UNIQUE,
    phone TEXT UNIQUE CHECK (phone IS NULL OR phone ~ '^0[0-9]{9}$'),
    avatar_url TEXT DEFAULT '',
    study_points INTEGER DEFAULT 0,
    streak_days INTEGER DEFAULT 0,
    user_level INTEGER DEFAULT 1
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_owner_read ON public.users FOR SELECT TO authenticated
USING (auth.uid() = id);
CREATE POLICY users_owner_update ON public.users FOR UPDATE TO authenticated
USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
GRANT SELECT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO service_role;

CREATE TABLE public.user_language_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    native_language_code TEXT NOT NULL CHECK (native_language_code IN ('vi', 'en')),
    learning_language_code TEXT NOT NULL CHECK (learning_language_code IN ('vi', 'en')),
    proficiency_level TEXT NOT NULL DEFAULT 'beginner',
    CHECK (native_language_code <> learning_language_code)
);

CREATE TABLE public.friends (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id)
);

ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
CREATE POLICY friends_participant_read ON public.friends FOR SELECT TO authenticated
USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY friends_participant_manage ON public.friends FOR ALL TO authenticated
USING (auth.uid() = user_id OR auth.uid() = friend_id)
WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.friends TO authenticated, service_role;

CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_ai_response BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY chat_messages_owner_manage ON public.chat_messages FOR ALL TO authenticated
USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_messages TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profiles(profile_ids UUID[] DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INTEGER,
    streak_days INTEGER,
    user_level INTEGER
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
    FROM public.users AS u
    WHERE profile_ids IS NULL OR u.id = ANY(profile_ids);
$$;
REVOKE ALL ON FUNCTION public.get_public_profiles(UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(UUID[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.check_phone_available(p_phone TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT NOT EXISTS (SELECT 1 FROM public.users WHERE phone = p_phone);
$$;
REVOKE ALL ON FUNCTION public.check_phone_available(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_phone_available(TEXT) TO authenticated;

CREATE PUBLICATION supabase_realtime;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

CREATE FUNCTION public.f1_assert(p_condition BOOLEAN, p_label TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_condition IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'F1 assertion failed: %', p_label;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;

CREATE FUNCTION public.f1_expect_error(
    p_sql TEXT,
    p_state TEXT,
    p_label TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_state TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS DISTINCT FROM p_state THEN
        RAISE EXCEPTION 'F1 expected error failed: %, expected %, got %',
            p_label, p_state, v_state;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;
