-- Minimal pre-GT1 schema for isolated native PostgreSQL verification.
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
    email_confirmed_at TIMESTAMPTZ
);

CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    username TEXT UNIQUE,
    age INT CHECK (age IS NULL OR age BETWEEN 1 AND 120),
    account_role TEXT CHECK (
        account_role IS NULL OR account_role IN ('personal', 'parent')
    ),
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_owner_read ON public.users FOR SELECT TO authenticated
USING (auth.uid() = id);
CREATE POLICY users_owner_update ON public.users FOR UPDATE TO authenticated
USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE (display_name, username, age, account_role, updated_at)
ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO service_role;

CREATE TABLE public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    interface_locale TEXT NOT NULL,
    learning_locale TEXT NOT NULL,
    reminder_time TEXT NOT NULL,
    study_end_time TEXT NOT NULL,
    daily_target_words INT NOT NULL
);

CREATE TABLE public.user_language_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    native_language_code TEXT NOT NULL,
    learning_language_code TEXT NOT NULL,
    proficiency_level TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE FUNCTION public.sync_my_verified_email()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$ SELECT TRUE; $$;

CREATE FUNCTION private.complete_verified_onboarding(
    p_display_name TEXT,
    p_username TEXT,
    p_age INT,
    p_phone TEXT,
    p_account_role TEXT,
    p_interface_locale TEXT,
    p_learning_locale TEXT,
    p_reminder_time TEXT,
    p_study_end_time TEXT,
    p_daily_target_words INT,
    p_native_language_code TEXT,
    p_learning_language_code TEXT,
    p_proficiency_level TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$ SELECT FALSE; $$;

CREATE FUNCTION public.complete_onboarding(
    p_display_name TEXT,
    p_username TEXT,
    p_age INT,
    p_phone TEXT,
    p_account_role TEXT,
    p_interface_locale TEXT,
    p_learning_locale TEXT,
    p_reminder_time TEXT,
    p_study_end_time TEXT,
    p_daily_target_words INT,
    p_native_language_code TEXT,
    p_learning_language_code TEXT,
    p_proficiency_level TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT private.complete_verified_onboarding(
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
    );
$$;

REVOKE ALL ON FUNCTION public.complete_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) TO authenticated;

CREATE FUNCTION public.gt1_assert(p_condition BOOLEAN, p_label TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_condition IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'GT1 assertion failed: %', p_label;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;

CREATE FUNCTION public.gt1_expect_error(
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
        RAISE EXCEPTION 'GT1 expected error failed: %, expected %, got %',
            p_label, p_state, v_state;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;
