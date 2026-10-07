\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'

SELECT public.h2a_assert(
    (SELECT starts_at = '2026-09-27T17:00:00Z'
            AND ends_at = '2026-09-28T17:00:00Z'
            AND next_day_ends_at = '2026-09-29T17:00:00Z'
     FROM public.daily_missions
     WHERE user_id = :'a' AND mission_date = '2026-09-28'),
    'H2A rows receive exact IANA boundaries during migration'
);

SELECT public.h2a_assert(
    (private.ensure_daily_mission_for_current_user(
        'Asia/Bangkok', '2026-10-01T16:59:59Z'
     )).mission_date = '2026-10-01',
    'server clock resolves the account local date before midnight'
);
SELECT public.h2a_assert(
    (private.ensure_daily_mission_for_current_user(
        'America/New_York', '2026-10-01T17:00:00Z'
     )).mission_date = '2026-10-02',
    'repeated device calls return the same account-zone mission'
);
SELECT public.h2a_assert(
    private.ensure_daily_mission_for_current_user(
        'Asia/Bangkok', '2026-10-01T17:00:00Z'
    ) IS NOT DISTINCT FROM
    private.ensure_daily_mission_for_current_user(
        'America/Los_Angeles', '2026-10-01T17:00:00Z'
    ),
    'two devices receive the same immutable mission snapshot'
);
SELECT public.h2a_assert(
    (SELECT time_zone = 'Asia/Ho_Chi_Minh'
     FROM public.user_settings WHERE user_id = :'a'),
    'detected timezone cannot overwrite an existing account setting'
);

UPDATE public.user_settings
SET daily_target_words = 30, time_zone = 'America/New_York'
WHERE user_id = :'a';
SELECT public.h2a_assert(
    (private.ensure_daily_mission_for_current_user(
        'America/New_York', '2026-10-01T17:30:00Z'
     )).target_words = 10
    AND (private.ensure_daily_mission_for_current_user(
        'America/New_York', '2026-10-01T17:30:00Z'
     )).time_zone = 'Asia/Ho_Chi_Minh',
    'same-day target and timezone changes do not mutate the existing mission'
);
SELECT public.h2a_assert(
    (private.ensure_daily_mission_for_current_user(
        'America/New_York', '2026-10-03T17:30:00Z'
     )).target_words = 30
    AND (private.ensure_daily_mission_for_current_user(
        'America/New_York', '2026-10-03T17:30:00Z'
     )).time_zone = 'America/New_York',
    'target and timezone changes apply to the next account day'
);
SELECT public.h2a_assert(
    (private.ensure_daily_mission_for_current_user(
        'America/New_York', '2026-11-01T16:00:00Z'
     )).ends_at
      - (private.ensure_daily_mission_for_current_user(
          'America/New_York', '2026-11-01T16:00:00Z'
        )).starts_at = INTERVAL '25 hours',
    'IANA boundaries preserve the DST fall-back day'
);

SELECT public.h2a_assert(
    has_function_privilege(
        'authenticated', 'public.ensure_daily_mission(text)', 'EXECUTE')
    AND NOT has_function_privilege(
        'anon', 'public.ensure_daily_mission(text)', 'EXECUTE')
    AND NOT has_function_privilege(
        'authenticated',
        'private.ensure_daily_mission_for_current_user(text,timestamptz)',
        'EXECUTE'),
    'only authenticated clients can call the public ensure wrapper'
);

UPDATE public.user_settings SET time_zone = NULL WHERE user_id = :'b';
SELECT set_config('request.jwt.claim.sub', :'b', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (public.ensure_daily_mission('Asia/Bangkok')).user_id = :'b'::UUID,
    'public RPC creates and returns only the authenticated owner mission'
);
RESET ROLE;
SELECT public.h2a_assert(
    (SELECT time_zone = 'Asia/Bangkok'
     FROM public.user_settings WHERE user_id = :'b'),
    'first ensure stores the detected IANA timezone on the account'
);

SELECT public.h2a_assert(
    (SELECT count(*) = 1
     FROM pg_catalog.pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'users'),
    'Home profile changes are published to Realtime'
);
