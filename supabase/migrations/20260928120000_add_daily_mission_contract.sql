-- H2A: account day boundary and immutable daily-mission snapshots.
-- Mission creation remains application work for H2B.

CREATE OR REPLACE FUNCTION private.is_supported_iana_time_zone(p_name TEXT)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY INVOKER
SET search_path = ''
AS $function$
    SELECT
        p_name IS NOT NULL
        AND position('/' IN p_name) > 1
        AND EXISTS (
            SELECT 1
            FROM pg_catalog.pg_timezone_names AS zone
            WHERE zone.name = p_name
        );
$function$;
REVOKE ALL ON FUNCTION private.is_supported_iana_time_zone(TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_supported_iana_time_zone(TEXT)
TO authenticated, service_role;
ALTER TABLE public.user_settings
    ADD COLUMN IF NOT EXISTS time_zone TEXT;
ALTER TABLE public.user_settings
    DROP CONSTRAINT IF EXISTS user_settings_time_zone_iana_check;
ALTER TABLE public.user_settings
    ADD CONSTRAINT user_settings_time_zone_iana_check
    CHECK (
        time_zone IS NULL
        OR private.is_supported_iana_time_zone(time_zone)
    );
COMMENT ON COLUMN public.user_settings.time_zone IS
    'IANA region identifier. NULL only for accounts not upgraded by H2B yet.';
CREATE TABLE public.daily_missions (
    user_id UUID NOT NULL
        REFERENCES public.users(id) ON DELETE CASCADE,
    mission_date DATE NOT NULL,
    time_zone TEXT NOT NULL,
    target_words INTEGER NOT NULL CHECK (target_words > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, mission_date),
    CONSTRAINT daily_missions_time_zone_iana_check
        CHECK (private.is_supported_iana_time_zone(time_zone))
);
COMMENT ON TABLE public.daily_missions IS
    'One immutable day/time-zone/target snapshot per account. Creation is added in H2B.';
CREATE OR REPLACE FUNCTION private.reject_daily_mission_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    RAISE EXCEPTION 'daily mission snapshots are immutable'
        USING ERRCODE = '55000';
END;
$function$;
REVOKE ALL ON FUNCTION private.reject_daily_mission_update()
FROM PUBLIC, anon, authenticated;
CREATE TRIGGER trg_daily_missions_immutable
BEFORE UPDATE ON public.daily_missions
FOR EACH ROW EXECUTE FUNCTION private.reject_daily_mission_update();
ALTER TABLE public.daily_missions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read their own daily missions"
ON public.daily_missions
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);
REVOKE ALL ON public.daily_missions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.daily_missions TO authenticated;
