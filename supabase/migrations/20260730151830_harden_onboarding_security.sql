CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles are viewable by authenticated users"
ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users view own profile" ON public.users;
DROP POLICY IF EXISTS "Users update own profile" ON public.users;

CREATE POLICY "Users view own profile"
ON public.users
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users update own profile"
ON public.users
FOR UPDATE
TO authenticated
USING ((SELECT auth.uid()) = id)
WITH CHECK ((SELECT auth.uid()) = id);

REVOKE INSERT, DELETE, UPDATE ON public.users FROM authenticated;
GRANT SELECT ON public.users TO authenticated;
GRANT UPDATE (
    display_name,
    avatar_url,
    username,
    age,
    phone,
    account_role,
    updated_at
) ON public.users TO authenticated;

DROP POLICY IF EXISTS "Users manage their own settings"
ON public.user_settings;

CREATE POLICY "Users manage their own settings"
ON public.user_settings
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.user_settings FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE
ON public.user_settings TO authenticated;

CREATE OR REPLACE FUNCTION private.is_username_available(
    p_username TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id UUID := (SELECT auth.uid());
    v_username TEXT := LOWER(BTRIM(COALESCE(p_username, '')));
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required'
            USING ERRCODE = '28000';
    END IF;

    IF v_username !~ '^[a-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Invalid username'
            USING ERRCODE = '22023';
    END IF;

    RETURN NOT EXISTS (
        SELECT 1
        FROM public.users AS u
        WHERE LOWER(u.username) = v_username
          AND u.id <> v_user_id
    );
END;
$function$;

REVOKE ALL ON FUNCTION private.is_username_available(TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_username_available(TEXT)
TO authenticated;

CREATE OR REPLACE FUNCTION public.is_username_available(
    p_username TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
    SELECT private.is_username_available($1);
$function$;

REVOKE ALL ON FUNCTION public.is_username_available(TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_username_available(TEXT)
TO authenticated;

CREATE OR REPLACE FUNCTION private.get_public_profiles(
    p_profile_ids UUID[] DEFAULT NULL
)
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
SET search_path = ''
AS $function$
    SELECT
        u.id,
        u.display_name,
        u.username,
        u.avatar_url,
        u.study_points,
        u.streak_days,
        u.user_level
    FROM public.users AS u
    WHERE (SELECT auth.uid()) IS NOT NULL
      AND (p_profile_ids IS NULL OR u.id = ANY(p_profile_ids));
$function$;

REVOKE ALL ON FUNCTION private.get_public_profiles(UUID[])
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_public_profiles(UUID[])
TO authenticated;

CREATE OR REPLACE FUNCTION public.get_public_profiles(
    profile_ids UUID[] DEFAULT NULL
)
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
SECURITY INVOKER
SET search_path = ''
AS $function$
    SELECT *
    FROM private.get_public_profiles($1);
$function$;

REVOKE ALL ON FUNCTION public.get_public_profiles(UUID[])
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(UUID[])
TO authenticated;

CREATE OR REPLACE FUNCTION private.complete_onboarding_for_current_user(
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
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;

REVOKE ALL ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT,
    TEXT,
    INT,
    TEXT,
    TEXT,
    TEXT,
    INT
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT,
    TEXT,
    INT,
    TEXT,
    TEXT,
    TEXT,
    INT
) TO authenticated;

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
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
    SELECT private.complete_onboarding_for_current_user(
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7
    );
$function$;

REVOKE ALL ON FUNCTION public.complete_onboarding(
    TEXT,
    TEXT,
    INT,
    TEXT,
    TEXT,
    TEXT,
    INT
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.complete_onboarding(
    TEXT,
    TEXT,
    INT,
    TEXT,
    TEXT,
    TEXT,
    INT
) TO authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;

REVOKE ALL ON FUNCTION public.handle_new_user()
FROM PUBLIC, anon, authenticated;

ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_phone_check;;
