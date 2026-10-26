-- GT3-only dependencies layered over group_gt1_bootstrap.sql and GT1.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';

CREATE TABLE public.friends (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, friend_id)
);
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
CREATE POLICY friends_read ON public.friends FOR SELECT TO authenticated
USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY friends_write ON public.friends FOR ALL TO authenticated
USING (auth.uid() = user_id OR auth.uid() = friend_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.friends
TO authenticated, service_role;

CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_ai_response BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY legacy_chat_owner ON public.chat_messages FOR ALL TO authenticated
USING (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_messages TO authenticated;

CREATE PUBLICATION supabase_realtime;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

CREATE FUNCTION public.gt3_assert(p_condition BOOLEAN, p_label TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_condition IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'GT3 assertion failed: %', p_label;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;

CREATE FUNCTION public.gt3_expect_error(
    p_sql TEXT,
    p_state TEXT,
    p_label TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE v_state TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS DISTINCT FROM p_state THEN
        RAISE EXCEPTION 'GT3 expected error failed: %, expected %, got %',
            p_label, p_state, v_state;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;
