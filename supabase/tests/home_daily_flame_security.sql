BEGIN;
\set c '10000000-0000-4000-8000-000000000003'
\set d '10000000-0000-4000-8000-000000000004'
INSERT INTO auth.users(id) VALUES (:'c'), (:'d');
INSERT INTO public.users(id, email, display_name)
VALUES (:'c', 'flame-c@example.invalid', 'Flame C'),
       (:'d', 'flame-d@example.invalid', 'Flame D');
INSERT INTO public.user_settings(user_id, time_zone)
VALUES (:'c', 'Pacific/Kiritimati'), (:'d', 'UTC');
INSERT INTO public.manual_streak_days(user_id, mission_date)
SELECT :'c'::UUID, (statement_timestamp() AT TIME ZONE 'Pacific/Kiritimati')::DATE - n
FROM unnest(ARRAY[1,2,4]) AS n;
INSERT INTO public.manual_streak_days(user_id, mission_date)
VALUES (:'d', (statement_timestamp() AT TIME ZONE 'UTC')::DATE - 2);

SELECT public.h2a_assert(
    has_function_privilege('authenticated', 'public.light_streak_flame()', 'EXECUTE')
    AND NOT has_function_privilege('anon', 'public.light_streak_flame()', 'EXECUTE')
    AND NOT has_table_privilege('authenticated', 'public.manual_streak_days', 'INSERT'),
    'flame dates are writable only through the authenticated server action'
);
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.h2a_expect_error($sql$SELECT public.light_streak_flame()$sql$,
    '42501', 'flame requires an authenticated account');

SELECT set_config('request.jwt.claim.sub', :'c', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT streak_days = 3 AND incremented FROM public.light_streak_flame()),
    'today extends two consecutive days and stops at the older gap'
);
SELECT public.h2a_assert(
    (SELECT streak_days = 3 AND NOT incremented FROM public.light_streak_flame()),
    'duplicate taps do not add another streak day'
);
SELECT public.h2a_assert(
    EXISTS (SELECT 1 FROM public.manual_streak_days
      WHERE mission_date = (statement_timestamp() AT TIME ZONE 'Pacific/Kiritimati')::DATE),
    'flame uses the account timezone rather than UTC or the client date'
);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', :'d', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT streak_days = 1 AND incremented FROM public.light_streak_flame()),
    'a missed day restarts the continuous streak at one'
);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', :'c', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 4 AND bool_and(user_id = :'c'::UUID)
     FROM public.manual_streak_days),
    'flame history remains isolated by account'
);
RESET ROLE;
SELECT public.h2a_assert(
    (SELECT bool_and(total_coins = 100) FROM public.users WHERE id IN (:'c', :'d'))
    AND NOT EXISTS (SELECT 1 FROM public.yuzu_reward_ledger WHERE user_id IN (:'c', :'d')),
    'flame adds no wallet coins or leaderboard score'
);
ROLLBACK;
