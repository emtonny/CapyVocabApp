\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'

SELECT public.h2a_assert(
    (SELECT time_zone IS NULL AND daily_target_words = 10
     FROM public.user_settings WHERE user_id = :'a'),
    'existing settings survive with an explicit upgrade-pending timezone'
);
SELECT public.h2a_expect_error(
    format(
        $sql$UPDATE public.user_settings SET time_zone = 'UTC+7'
             WHERE user_id = %L::uuid$sql$,
        :'a'
    ),
    '23514',
    'fixed UTC offsets are rejected'
);
SELECT public.h2a_expect_error(
    format(
        $sql$UPDATE public.user_settings SET time_zone = 'Mars/Olympus'
             WHERE user_id = %L::uuid$sql$,
        :'a'
    ),
    '23514',
    'unknown region identifiers are rejected'
);
UPDATE public.user_settings SET time_zone = 'Asia/Bangkok' WHERE user_id = :'a';
SELECT public.h2a_assert(
    (SELECT time_zone = 'Asia/Bangkok'
     FROM public.user_settings WHERE user_id = :'a'),
    'known IANA region identifiers are stored'
);

INSERT INTO public.daily_missions (
    user_id, mission_date, time_zone, target_words, created_at
) VALUES
    (:'a', '2026-09-28', 'Asia/Bangkok', 10, '2026-09-27T17:00:00Z'),
    (:'b', '2026-09-28', 'America/New_York', 20, '2026-09-28T04:00:00Z');

SELECT public.h2a_expect_error(
    format(
        $sql$INSERT INTO public.daily_missions
             (user_id, mission_date, time_zone, target_words)
             VALUES (%L::uuid, '2026-09-28', 'Asia/Bangkok', 99)$sql$,
        :'a'
    ),
    '23505',
    'one account has only one mission per local date'
);
SELECT public.h2a_expect_error(
    format(
        $sql$UPDATE public.daily_missions SET target_words = 99
             WHERE user_id = %L::uuid AND mission_date = '2026-09-28'$sql$,
        :'a'
    ),
    '55000',
    'daily mission snapshots cannot be changed'
);
SELECT public.h2a_expect_error(
    format(
        $sql$INSERT INTO public.daily_missions
             (user_id, mission_date, time_zone, target_words)
             VALUES (%L::uuid, '2026-09-29', 'UTC+7', 10)$sql$,
        :'a'
    ),
    '23514',
    'mission snapshots reject non-IANA timezone values'
);

SELECT public.h2a_assert(
    has_table_privilege('authenticated', 'public.daily_missions', 'SELECT')
    AND NOT has_table_privilege(
        'authenticated', 'public.daily_missions', 'INSERT')
    AND NOT has_table_privilege(
        'authenticated', 'public.daily_missions', 'UPDATE')
    AND NOT has_table_privilege(
        'authenticated', 'public.daily_missions', 'DELETE'),
    'authenticated clients can read but cannot mutate mission snapshots'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
UPDATE public.user_settings
SET time_zone = 'Asia/Ho_Chi_Minh'
WHERE user_id = :'a';
SELECT public.h2a_assert(
    (SELECT time_zone = 'Asia/Ho_Chi_Minh'
     FROM public.user_settings WHERE user_id = :'a'),
    'authenticated owner can change the account timezone setting'
);
SELECT public.h2a_assert(
    (SELECT count(*) = 1 FROM public.daily_missions),
    'RLS returns only the signed-in owner mission'
);
SELECT public.h2a_assert(
    NOT EXISTS (
        SELECT 1 FROM public.daily_missions WHERE user_id = :'b'
    ),
    'RLS hides another owner mission'
);
RESET ROLE;
