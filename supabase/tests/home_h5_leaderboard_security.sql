\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'

SELECT public.h2a_assert(
    has_function_privilege(
        'authenticated', 'public.list_weekly_yuzu_leaderboard(date)', 'EXECUTE'
    ) AND NOT has_function_privilege(
        'anon', 'public.list_weekly_yuzu_leaderboard(date)', 'EXECUTE'
    ),
    'only authenticated clients can list weekly Yuzu leaderboard'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.h2a_expect_error(
    $sql$SELECT public.list_weekly_yuzu_leaderboard('2026-10-06')$sql$,
    '22023',
    'leaderboard rejects a non-Monday week boundary'
);

SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 1
     FROM public.list_weekly_yuzu_leaderboard('2026-10-05'))
    AND (SELECT weekly_yuzu = 230 AND rank_position = 1
         FROM public.list_weekly_yuzu_leaderboard('2026-10-05')),
    'leaderboard initially exposes only the signed-in account'
);
RESET ROLE;

INSERT INTO public.daily_missions (
    user_id, mission_date, time_zone, target_words,
    starts_at, ends_at, next_day_ends_at
) VALUES (
    :'b', '2026-10-10', 'Asia/Bangkok', 2,
    '2026-10-09T17:00:00Z', '2026-10-10T17:00:00Z', '2026-10-11T17:00:00Z'
);
SELECT set_config('request.jwt.claim.sub', :'b', false);
SET ROLE authenticated;
SELECT public.h5_sync(
    'h5-b-day-10', '2026-10-10', 2, '2026-10-10T10:00:00Z'
);
RESET ROLE;

INSERT INTO public.friends (user_id, friend_id, status)
VALUES (:'a', :'b', 'accepted');
SELECT set_config('request.jwt.claim.sub', :'a', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 1
     FROM public.list_weekly_yuzu_leaderboard('2026-10-05')),
    'one-sided accepted edge does not expose another score'
);
RESET ROLE;

INSERT INTO public.friends (user_id, friend_id, status)
VALUES (:'b', :'a', 'accepted');
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 2
     FROM public.list_weekly_yuzu_leaderboard('2026-10-05'))
    AND (SELECT weekly_yuzu = 230 AND rank_position = 1
         FROM public.list_weekly_yuzu_leaderboard('2026-10-05')
         WHERE user_id = :'a')
    AND (SELECT weekly_yuzu = 100 AND rank_position = 2
         FROM public.list_weekly_yuzu_leaderboard('2026-10-05')
         WHERE user_id = :'b'),
    'mutual friends see deterministic ledger-backed ranks'
);

SELECT public.h2a_assert(
    (SELECT weekly_yuzu = 230
     FROM public.list_weekly_yuzu_leaderboard('2026-10-05')
     WHERE user_id = :'a'),
    'rewarded replay remains excluded from weekly Yuzu'
);
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', :'b', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 2
     FROM public.list_weekly_yuzu_leaderboard('2026-10-05'))
    AND (SELECT weekly_yuzu = 230 AND rank_position = 1
         FROM public.list_weekly_yuzu_leaderboard('2026-10-05')
         WHERE user_id = :'a'),
    'both accepted peers receive the same weekly ordering'
);
RESET ROLE;
