-- 1. Them cot study_end_time
ALTER TABLE public.user_settings
  ADD COLUMN IF NOT EXISTS study_end_time TEXT DEFAULT '21:00';

ALTER TABLE public.user_settings
  ADD CONSTRAINT user_settings_study_end_time_format_check
  CHECK (study_end_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');

-- 2. Xoa function cu (7 tham so) truoc khi tao ban 8 tham so, tranh bi
-- PostgreSQL tao overload thay vi thay the signature cu.
DROP FUNCTION IF EXISTS public.complete_onboarding(
  text, text, integer, text, text, text, integer
);
DROP FUNCTION IF EXISTS private.complete_onboarding_for_current_user(
  text, text, integer, text, text, text, integer
);

-- 3. Tao lai ham private voi 8 tham so + validate end > start
CREATE FUNCTION private.complete_onboarding_for_current_user(
  p_display_name text,
  p_username text,
  p_age integer,
  p_phone text,
  p_account_role text,
  p_reminder_time text,
  p_study_end_time text,
  p_daily_target_words integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
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

    IF p_study_end_time IS NULL
       OR p_study_end_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RAISE EXCEPTION 'Invalid study end time'
            USING ERRCODE = '22023';
    END IF;

    IF p_study_end_time::TIME <= p_reminder_time::TIME THEN
        RAISE EXCEPTION 'Study end time must be after start time'
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
        study_end_time,
        daily_target_words
    )
    VALUES (
        v_user_id,
        p_reminder_time,
        p_study_end_time,
        p_daily_target_words
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        reminder_time = EXCLUDED.reminder_time,
        study_end_time = EXCLUDED.study_end_time,
        daily_target_words = EXCLUDED.daily_target_words;

    UPDATE public.users
    SET
        onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = v_user_id;

    RETURN TRUE;
END;
$function$;

-- 4. Wrapper public RPC (8 tham so), giu dung pattern SECURITY invoker
-- goi thang ham private nhu ban cu
CREATE FUNCTION public.complete_onboarding(
  p_display_name text,
  p_username text,
  p_age integer,
  p_phone text,
  p_account_role text,
  p_reminder_time text,
  p_study_end_time text,
  p_daily_target_words integer
)
RETURNS boolean
LANGUAGE sql
SET search_path TO ''
AS $function$
    SELECT private.complete_onboarding_for_current_user(
        $1, $2, $3, $4, $5, $6, $7, $8
    );
$function$;

REVOKE ALL ON FUNCTION public.complete_onboarding(
  text, text, integer, text, text, text, text, integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(
  text, text, integer, text, text, text, text, integer
) TO authenticated;;
