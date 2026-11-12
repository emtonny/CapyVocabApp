-- Isolated fixture: bootstrap + minimal reward ledger + latest period migration.
ALTER TABLE public.user_settings ADD COLUMN time_zone TEXT;
UPDATE public.user_settings SET time_zone = 'Asia/Ho_Chi_Minh';
UPDATE public.users SET total_coins = CASE
    WHEN display_name = 'A' THEN 500 ELSE 700 END;
INSERT INTO public.yuzu_reward_ledger
    (user_id, mission_date, wallet_yuzu, weekly_yuzu, created_at) VALUES
('10000000-0000-4000-8000-000000000001','2026-09-30',100,100,'2026-10-10T00:10:00+07'),
('10000000-0000-4000-8000-000000000001','2026-10-10',33,0,'2026-10-10T00:11:00+07'),
('10000000-0000-4000-8000-000000000001','2026-10-09',20,20,'2026-10-09T23:59:59+07'),
('10000000-0000-4000-8000-000000000001','2026-10-11',50,50,'2026-10-11T00:00:00+07'),
('10000000-0000-4000-8000-000000000001','2026-09-30',7,7,'2026-09-30T23:59:59+07'),
('10000000-0000-4000-8000-000000000002','2026-10-10',40,40,'2026-10-10T01:00:00+07');
SELECT public.h2a_assert(
 has_function_privilege('authenticated','public.list_period_yuzu_leaderboard(text,date)','EXECUTE')
 AND NOT has_function_privilege('anon','public.list_period_yuzu_leaderboard(text,date)','EXECUTE'),
 'only authenticated clients can call the leaderboard');
SELECT set_config('request.jwt.claim.sub', '', false);
SELECT public.h2a_expect_error($sql$SELECT public.list_period_yuzu_leaderboard('total')$sql$,
 '42501','missing authentication is rejected');
SELECT set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
SELECT public.h2a_expect_error($sql$SELECT public.list_period_yuzu_leaderboard('year')$sql$,
 '22023','unsupported periods are rejected');
INSERT INTO public.friends(user_id,friend_id,status) VALUES
 ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','accepted');
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT count(*)=1 FROM public.list_period_yuzu_leaderboard('total')),
 'one-sided friendship does not disclose wallet balances');
SELECT public.h2a_assert((SELECT period_yuzu=500 AND period_start IS NULL
 FROM public.list_period_yuzu_leaderboard('total')), 'total uses the current wallet');
SELECT public.h2a_assert((SELECT period_yuzu=133 AND period_start='2026-10-10'
 FROM public.list_period_yuzu_leaderboard('day','2026-10-10')),
 'day includes replay and late mission earnings, excluding both time boundaries');
SELECT public.h2a_assert((SELECT period_yuzu=203 AND period_start='2026-10-05'
 FROM public.list_period_yuzu_leaderboard('week','2026-10-10')), 'week begins Monday');
SELECT public.h2a_assert((SELECT period_yuzu=203 AND period_start='2026-10-01'
 FROM public.list_period_yuzu_leaderboard('month','2026-10-31')), 'month excludes September earnings');
SELECT public.h2a_assert((SELECT period_yuzu=0 FROM public.list_period_yuzu_leaderboard('month','2026-11-01')),
 'empty earning periods return zero');
RESET ROLE;
INSERT INTO public.friends(user_id,friend_id,status) VALUES
 ('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','accepted');
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT count(*)=2 FROM public.list_period_yuzu_leaderboard('total'))
 AND (SELECT rank_position=1 AND period_yuzu=700 FROM public.list_period_yuzu_leaderboard('total')
 WHERE user_id='10000000-0000-4000-8000-000000000002'), 'mutual friends rank by wallet');
SELECT public.h2a_assert((SELECT rank_position=1 AND period_yuzu=133
 FROM public.list_period_yuzu_leaderboard('day','2026-10-10')
 WHERE user_id='10000000-0000-4000-8000-000000000001'), 'earned ranking can differ from wallet ranking');
RESET ROLE;
UPDATE public.user_settings SET time_zone='America/Los_Angeles';
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT period_yuzu=50 FROM public.list_period_yuzu_leaderboard('day','2026-10-10')
 WHERE user_id='10000000-0000-4000-8000-000000000001'), 'earning windows use account timezone');
RESET ROLE;
ALTER TABLE public.user_settings DROP COLUMN time_zone;
SET ROLE authenticated;
SELECT public.h2a_assert((SELECT period_yuzu=133 FROM public.list_period_yuzu_leaderboard('day','2026-10-10')
 WHERE user_id='10000000-0000-4000-8000-000000000001'), 'legacy settings default to Vietnam timezone');
RESET ROLE;
