-- Minimal existing contracts in an isolated native PostgreSQL test cluster.
-- No production snapshot, real user records or API credentials are used.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE SCHEMA private;
GRANT USAGE ON SCHEMA public, auth, private TO authenticated, service_role;
GRANT USAGE ON SCHEMA public, auth TO anon;
CREATE FUNCTION auth.uid() RETURNS UUID LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
CREATE TABLE public.users (id UUID PRIMARY KEY);
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
    created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY (user_id, friend_id)
);
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view their friend connections" ON public.friends FOR SELECT
USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "Users manage friend requests" ON public.friends FOR ALL
USING (auth.uid() = user_id OR auth.uid() = friend_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.friends TO authenticated, service_role;
CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL, is_ai_response BOOLEAN DEFAULT FALSE, timestamp TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage their chat messages" ON public.chat_messages FOR ALL USING (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_messages TO authenticated;
CREATE PUBLICATION supabase_realtime;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

CREATE FUNCTION public.c2_assert(p_condition BOOLEAN, p_label TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF p_condition IS DISTINCT FROM TRUE THEN RAISE EXCEPTION 'C2 assertion failed: %', p_label; END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;
CREATE FUNCTION public.c2_expect_error(p_sql TEXT, p_state TEXT, p_label TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_state TEXT;
BEGIN
    BEGIN EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM p_state THEN
        RAISE EXCEPTION 'C2 expected error failed: %, expected %, got %', p_label, p_state, v_state;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;
