-- H2B: server-authoritative day boundaries and idempotent mission creation.

ALTER TABLE public.daily_missions
    ADD COLUMN starts_at TIMESTAMPTZ,
    ADD COLUMN ends_at TIMESTAMPTZ,
    ADD COLUMN next_day_ends_at TIMESTAMPTZ;
ALTER TABLE public.daily_missions
    DISABLE TRIGGER trg_daily_missions_immutable;
UPDATE public.daily_missions
SET
    starts_at = mission_date::TIMESTAMP AT TIME ZONE time_zone,
    ends_at = (mission_date + 1)::TIMESTAMP AT TIME ZONE time_zone,
    next_day_ends_at = (mission_date + 2)::TIMESTAMP AT TIME ZONE time_zone;
ALTER TABLE public.daily_missions
    ENABLE TRIGGER trg_daily_missions_immutable;
ALTER TABLE public.daily_missions
    ALTER COLUMN starts_at SET NOT NULL,
    ALTER COLUMN ends_at SET NOT NULL,
    ALTER COLUMN next_day_ends_at SET NOT NULL,
    ADD CONSTRAINT daily_missions_boundary_order_check CHECK (
        starts_at < ends_at AND ends_at < next_day_ends_at
    );
CREATE OR REPLACE FUNCTION private.ensure_daily_mission_for_current_user(
    p_detected_time_zone TEXT,
    p_now TIMESTAMPTZ
)
RETURNS public.daily_missions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id UUID := (SELECT auth.uid());
    v_time_zone TEXT;
    v_target_words INTEGER;
    v_mission_date DATE;
    v_mission public.daily_missions%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF p_now IS NULL THEN
        RAISE EXCEPTION 'Current time is required' USING ERRCODE = '22023';
    END IF;

    SELECT settings.time_zone, settings.daily_target_words
    INTO v_time_zone, v_target_words
    FROM public.user_settings AS settings
    WHERE settings.user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User settings not found' USING ERRCODE = 'P0002';
    END IF;
    IF v_target_words IS NULL OR v_target_words <= 0 THEN
        RAISE EXCEPTION 'Daily target must be greater than zero'
            USING ERRCODE = '22023';
    END IF;

    IF v_time_zone IS NULL THEN
        IF NOT private.is_supported_iana_time_zone(p_detected_time_zone) THEN
            RAISE EXCEPTION 'A valid detected IANA time zone is required'
                USING ERRCODE = '22023';
        END IF;
        v_time_zone := p_detected_time_zone;
        UPDATE public.user_settings
        SET time_zone = v_time_zone
        WHERE user_id = v_user_id;
    END IF;

    v_mission_date := (p_now AT TIME ZONE v_time_zone)::DATE;

    INSERT INTO public.daily_missions (
        user_id,
        mission_date,
        time_zone,
        target_words,
        starts_at,
        ends_at,
        next_day_ends_at
    )
    VALUES (
        v_user_id,
        v_mission_date,
        v_time_zone,
        v_target_words,
        v_mission_date::TIMESTAMP AT TIME ZONE v_time_zone,
        (v_mission_date + 1)::TIMESTAMP AT TIME ZONE v_time_zone,
        (v_mission_date + 2)::TIMESTAMP AT TIME ZONE v_time_zone
    )
    ON CONFLICT (user_id, mission_date) DO NOTHING;

    SELECT mission.*
    INTO STRICT v_mission
    FROM public.daily_missions AS mission
    WHERE mission.user_id = v_user_id
      AND mission.mission_date = v_mission_date;

    RETURN v_mission;
END;
$function$;
REVOKE ALL ON FUNCTION private.ensure_daily_mission_for_current_user(
    TEXT, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION public.ensure_daily_mission(
    p_detected_time_zone TEXT DEFAULT NULL
)
RETURNS public.daily_missions
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
    SELECT private.ensure_daily_mission_for_current_user(
        p_detected_time_zone,
        statement_timestamp()
    );
$function$;
REVOKE ALL ON FUNCTION public.ensure_daily_mission(TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_daily_mission(TEXT)
TO authenticated;
