-- Run after home_h5_leaderboard_security.sql with its synthetic fixtures.
BEGIN;
\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'

SELECT public.h2a_assert(
    has_function_privilege('authenticated',
        'public.list_period_yuzu_leaderboard(text,date)', 'EXECUTE')
    AND NOT has_function_privilege('anon',
        'public.list_period_yuzu_leaderboard(text,date)', 'EXECUTE'),
    'period leaderboard is authenticated-only'
);
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.h2a_expect_error(
    $sql$SELECT public.list_period_yuzu_leaderboard('year', '2026-10-10')$sql$,
    '22023', 'unsupported leaderboard periods are rejected'
);
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT period_yuzu = 100 AND period_start = '2026-10-10'
     FROM public.list_period_yuzu_leaderboard('day', '2026-10-10')
     WHERE user_id = :'a'),
    'today uses the mission date and excludes rewarded replays'
);
SELECT public.h2a_assert(
    (SELECT count(*) = 2
     FROM public.list_period_yuzu_leaderboard('day', '2026-10-10')),
    'mutually accepted friends participate in daily ranking'
);
SELECT public.h2a_assert(
    (SELECT bool_and(period_yuzu = 0)
     FROM public.list_period_yuzu_leaderboard('day', '2026-11-01')),
    'day boundaries exclude other mission dates'
);
SELECT public.h2a_assert(
    (SELECT bool_and(period_yuzu = 0 AND period_start = '2026-11-01')
     FROM public.list_period_yuzu_leaderboard('month', '2026-11-30')),
    'month boundaries exclude the previous month'
);
RESET ROLE;
SELECT public.h2a_assert(
    (SELECT period_yuzu FROM public.list_period_yuzu_leaderboard('month', '2026-10-31')
     WHERE user_id = :'a') =
    (SELECT sum(weekly_yuzu) FROM public.yuzu_reward_ledger
     WHERE user_id = :'a' AND mission_date >= '2026-10-01' AND mission_date < '2026-11-01'),
    'month includes confirmed first-completion scores across weeks'
);
DELETE FROM public.friends WHERE user_id = :'b' AND friend_id = :'a';
SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 1 FROM public.list_period_yuzu_leaderboard('month', '2026-10-10')),
    'one-sided friendship cannot expose period scores'
);
RESET ROLE;
ROLLBACK;
