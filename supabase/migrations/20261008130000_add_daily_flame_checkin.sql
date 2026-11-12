-- Manual daily flame and on-time lesson completions share one streak calendar.
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE public.manual_streak_days (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    mission_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY (user_id, mission_date)
);
ALTER TABLE public.manual_streak_days ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read their own manual streak days"
ON public.manual_streak_days FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);
REVOKE ALL ON public.manual_streak_days FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.manual_streak_days TO authenticated;

-- The legacy app database has no lesson calendar yet. Do not require the
-- unrelated lesson/reward migrations just to enable daily flame check-ins.
DO $block$
BEGIN
    IF to_regclass('public.lesson_streak_days') IS NULL THEN
        EXECUTE 'CREATE VIEW private.streak_activity_days AS
                 SELECT user_id, mission_date FROM public.manual_streak_days';
    ELSE
        EXECUTE 'CREATE VIEW private.streak_activity_days AS
                 SELECT user_id, mission_date FROM public.lesson_streak_days
                 UNION SELECT user_id, mission_date FROM public.manual_streak_days';
    END IF;
END;
$block$;
REVOKE ALL ON private.streak_activity_days FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.recompute_lesson_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_day DATE;
    v_streak INTEGER := 0;
BEGIN
    PERFORM 1 FROM public.users AS profile WHERE profile.id = p_user_id FOR UPDATE;
    SELECT max(day.mission_date)
    INTO v_day
    FROM private.streak_activity_days AS day
    WHERE day.user_id = p_user_id;

    WHILE v_day IS NOT NULL AND EXISTS (
        SELECT 1
        FROM private.streak_activity_days AS day
        WHERE day.user_id = p_user_id
          AND day.mission_date = v_day
    ) LOOP
        v_streak := v_streak + 1;
        v_day := v_day - 1;
    END LOOP;

    UPDATE public.users
    SET streak_days = v_streak,
        updated_at = statement_timestamp()
    WHERE id = p_user_id;

    RETURN v_streak;
END;
$function$;

REVOKE ALL ON FUNCTION private.recompute_lesson_streak(UUID)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.refresh_lesson_streak_on_new_mission()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_latest DATE;
BEGIN
    PERFORM 1 FROM public.users AS profile WHERE profile.id = NEW.user_id FOR UPDATE;
    SELECT max(day.mission_date)
    INTO v_latest
    FROM private.streak_activity_days AS day
    WHERE day.user_id = NEW.user_id;

    IF v_latest IS NULL OR NEW.mission_date > v_latest + 1 THEN
        UPDATE public.users
        SET streak_days = 0,
            updated_at = statement_timestamp()
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.refresh_lesson_streak_on_new_mission()
FROM PUBLIC, anon, authenticated;


CREATE FUNCTION public.light_streak_flame()
RETURNS TABLE (user_id UUID, streak_days INTEGER, incremented BOOLEAN, updated_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_time_zone TEXT;
    v_day DATE;
    v_had_today BOOLEAN;
    v_streak INTEGER;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    -- Serializes duplicate taps/devices with reward settlement's user update.
    PERFORM 1 FROM public.users AS profile WHERE profile.id = v_user FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile required' USING ERRCODE = 'P0002';
    END IF;
    SELECT NULLIF(to_jsonb(settings)->>'time_zone', '') INTO v_time_zone
    FROM public.user_settings AS settings WHERE settings.user_id = v_user;
    -- Legacy accounts have no timezone column/settings yet.
    v_time_zone := COALESCE(v_time_zone, 'Asia/Ho_Chi_Minh');
    v_day := (statement_timestamp() AT TIME ZONE v_time_zone)::DATE;
    SELECT EXISTS (
        SELECT 1 FROM private.streak_activity_days AS day
        WHERE day.user_id = v_user AND day.mission_date = v_day
    ) INTO v_had_today;
    INSERT INTO public.manual_streak_days (user_id, mission_date)
    VALUES (v_user, v_day) ON CONFLICT DO NOTHING;
    v_streak := private.recompute_lesson_streak(v_user);
    RETURN QUERY SELECT v_user, v_streak, NOT v_had_today, profile.updated_at
    FROM public.users AS profile WHERE profile.id = v_user;
END;
$function$;
REVOKE ALL ON FUNCTION public.light_streak_flame() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.light_streak_flame() TO authenticated;
