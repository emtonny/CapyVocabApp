-- Merge the locale-preference and operational-chat language-profile onboarding
-- contracts without changing either compatibility overload.
CREATE OR REPLACE FUNCTION public.complete_onboarding(
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
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $function$
DECLARE
    v_preferences_saved BOOLEAN;
    v_profile_saved BOOLEAN;
BEGIN
    v_preferences_saved := private.complete_onboarding_for_current_user(
        p_display_name,
        p_username,
        p_age,
        p_phone,
        p_account_role,
        p_interface_locale,
        p_learning_locale,
        p_reminder_time,
        p_study_end_time,
        p_daily_target_words
    );

    v_profile_saved := private.complete_onboarding_for_current_user(
        p_display_name,
        p_username,
        p_age,
        p_phone,
        p_account_role,
        p_reminder_time,
        p_study_end_time,
        p_daily_target_words,
        p_native_language_code,
        p_learning_language_code,
        p_proficiency_level
    );

    RETURN v_preferences_saved AND v_profile_saved;
END;
$function$;

REVOKE ALL ON FUNCTION public.complete_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) TO authenticated;
