-- C1: owner-scoped language profile used by bilingual chat rendering.
-- Existing users are deliberately not backfilled: guessing a language pair
-- could expose the wrong translation or mix account preferences.
CREATE TABLE public.user_language_profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    native_language_code TEXT NOT NULL
        CHECK (native_language_code IN ('vi', 'en')),
    learning_language_code TEXT NOT NULL
        CHECK (learning_language_code IN ('vi', 'en')),
    proficiency_level TEXT NOT NULL DEFAULT 'beginner'
        CHECK (proficiency_level IN ('beginner', 'intermediate', 'advanced')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (native_language_code <> learning_language_code),
    CHECK (updated_at >= created_at)
);

CREATE FUNCTION private.touch_user_language_profile_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.touch_user_language_profile_updated_at()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER touch_user_language_profile_updated_at
BEFORE UPDATE ON public.user_language_profiles
FOR EACH ROW
EXECUTE FUNCTION private.touch_user_language_profile_updated_at();

ALTER TABLE public.user_language_profiles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.user_language_profiles FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE
ON public.user_language_profiles TO authenticated;

CREATE POLICY "Users manage their own language profile"
ON public.user_language_profiles
FOR ALL
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

-- Keep the existing 8-argument RPC for released clients. The new named
-- parameters select this overload and atomically complete onboarding plus the
-- language profile.
CREATE FUNCTION private.complete_onboarding_for_current_user(
    p_display_name TEXT,
    p_username TEXT,
    p_age INT,
    p_phone TEXT,
    p_account_role TEXT,
    p_reminder_time TEXT,
    p_study_end_time TEXT,
    p_daily_target_words INT,
    p_native_language_code TEXT,
    p_learning_language_code TEXT,
    p_proficiency_level TEXT
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
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
    END IF;
    IF BTRIM(COALESCE(p_display_name, '')) = '' THEN
        RAISE EXCEPTION 'Display name is required' USING ERRCODE = '22023';
    END IF;
    IF BTRIM(COALESCE(p_username, '')) !~ '^[a-zA-Z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'Invalid username' USING ERRCODE = '22023';
    END IF;
    IF p_age IS NULL OR p_age < 1 OR p_age > 120 THEN
        RAISE EXCEPTION 'Age must be between 1 and 120'
            USING ERRCODE = '22023';
    END IF;
    IF p_phone IS NULL OR p_phone !~ '^0[0-9]{9}$' THEN
        RAISE EXCEPTION 'Invalid phone number' USING ERRCODE = '22023';
    END IF;
    IF p_account_role IS NULL
       OR p_account_role NOT IN ('personal', 'parent') THEN
        RAISE EXCEPTION 'Invalid account role' USING ERRCODE = '22023';
    END IF;
    IF p_reminder_time IS NULL
       OR p_reminder_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RAISE EXCEPTION 'Invalid reminder time' USING ERRCODE = '22023';
    END IF;
    IF p_study_end_time IS NULL
       OR p_study_end_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RAISE EXCEPTION 'Invalid study end time' USING ERRCODE = '22023';
    END IF;
    IF p_study_end_time::TIME = p_reminder_time::TIME THEN
        RAISE EXCEPTION 'Study end time must differ from start time'
            USING ERRCODE = '22023';
    END IF;
    IF p_daily_target_words IS NULL OR p_daily_target_words <= 0 THEN
        RAISE EXCEPTION 'Daily target must be greater than zero'
            USING ERRCODE = '22023';
    END IF;
    IF COALESCE(p_native_language_code, '') NOT IN ('vi', 'en')
       OR COALESCE(p_learning_language_code, '') NOT IN ('vi', 'en')
       OR p_native_language_code = p_learning_language_code THEN
        RAISE EXCEPTION 'Invalid language pair' USING ERRCODE = '22023';
    END IF;
    IF COALESCE(p_proficiency_level, '')
       NOT IN ('beginner', 'intermediate', 'advanced') THEN
        RAISE EXCEPTION 'Invalid proficiency level' USING ERRCODE = '22023';
    END IF;

    UPDATE public.users
    SET display_name = BTRIM(p_display_name),
        username = LOWER(BTRIM(p_username)),
        age = p_age,
        phone = p_phone,
        account_role = p_account_role,
        updated_at = NOW()
    WHERE id = v_user_id;

    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;
    IF v_updated_rows <> 1 THEN
        RAISE EXCEPTION 'User profile not found' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.user_settings (
        user_id, reminder_time, study_end_time, daily_target_words
    ) VALUES (
        v_user_id, p_reminder_time, p_study_end_time, p_daily_target_words
    )
    ON CONFLICT (user_id) DO UPDATE
    SET reminder_time = EXCLUDED.reminder_time,
        study_end_time = EXCLUDED.study_end_time,
        daily_target_words = EXCLUDED.daily_target_words;

    INSERT INTO public.user_language_profiles (
        user_id, native_language_code, learning_language_code,
        proficiency_level
    ) VALUES (
        v_user_id, p_native_language_code, p_learning_language_code,
        p_proficiency_level
    )
    ON CONFLICT (user_id) DO UPDATE
    SET native_language_code = EXCLUDED.native_language_code,
        learning_language_code = EXCLUDED.learning_language_code,
        proficiency_level = EXCLUDED.proficiency_level,
        updated_at = NOW();

    UPDATE public.users
    SET onboarding_completed = TRUE, updated_at = NOW()
    WHERE id = v_user_id;

    RETURN TRUE;
END;
$function$;

REVOKE ALL ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) TO authenticated;

CREATE FUNCTION public.complete_onboarding(
    p_display_name TEXT,
    p_username TEXT,
    p_age INT,
    p_phone TEXT,
    p_account_role TEXT,
    p_reminder_time TEXT,
    p_study_end_time TEXT,
    p_daily_target_words INT,
    p_native_language_code TEXT,
    p_learning_language_code TEXT,
    p_proficiency_level TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
    SELECT private.complete_onboarding_for_current_user(
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
    );
$function$;

REVOKE ALL ON FUNCTION public.complete_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) TO authenticated;
