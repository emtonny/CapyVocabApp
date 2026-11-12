\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'

CREATE OR REPLACE FUNCTION public.h5_sync(
    p_session TEXT,
    p_day DATE,
    p_total INTEGER,
    p_completed_at TIMESTAMPTZ
)
RETURNS public.lesson_completion_receipts
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    v_items JSONB;
    v_verdicts JSONB;
BEGIN
    SELECT jsonb_agg(jsonb_build_object('id', 'item-' || value))
    INTO v_items
    FROM generate_series(1, p_total) AS value;
    SELECT jsonb_agg(jsonb_build_object(
        'item_id', 'item-' || value,
        'is_correct', true
    ))
    INTO v_verdicts
    FROM generate_series(1, p_total) AS value;
    RETURN public.sync_lesson_completion(
        p_session || ':completion',
        p_session,
        p_day,
        p_total,
        p_total,
        repeat('a', 64),
        'h5-rules-v1',
        'nfc-casefold-v1',
        jsonb_build_object(
            'items', v_items,
            'attempts', jsonb_build_array(
                jsonb_build_object('verdicts', v_verdicts)
            )
        ),
        p_completed_at
    );
END;
$$;

SELECT public.h2a_assert(
    (SELECT reward_status = 'rejected'
            AND completion_ordinal = 1
            AND reward_yuzu IS NULL
            AND weekly_yuzu = 0
     FROM public.lesson_completion_receipts
     WHERE result_id = 'session-a:completion')
    AND EXISTS (
        SELECT 1 FROM public.yuzu_reward_ledger
        WHERE receipt_id = 'session-a:completion'
          AND wallet_yuzu = 0
          AND weekly_yuzu = 0
    ),
    'pending H4 receipts are backfilled once under H5 rules'
);

SELECT public.h2a_assert(
    has_table_privilege('authenticated', 'public.yuzu_reward_ledger', 'SELECT')
    AND NOT has_table_privilege(
        'authenticated', 'public.yuzu_reward_ledger', 'INSERT')
    AND NOT has_table_privilege(
        'authenticated', 'public.yuzu_reward_ledger', 'UPDATE')
    AND NOT has_table_privilege(
        'authenticated', 'public.yuzu_reward_ledger', 'DELETE'),
    'authenticated clients can read but cannot mutate the Yuzu ledger'
);

SELECT public.h2a_assert(
    private.daily_lesson_reward_yuzu(10, 10, 'on_time') = 100
    AND private.daily_lesson_reward_yuzu(14, 10, 'on_time') = 100
    AND private.daily_lesson_reward_yuzu(15, 10, 'on_time') = 130
    AND private.daily_lesson_reward_yuzu(19, 10, 'on_time') = 130
    AND private.daily_lesson_reward_yuzu(20, 10, 'on_time') = 150
    AND private.daily_lesson_reward_yuzu(10, 10, 'late') = 67
    AND private.daily_lesson_reward_yuzu(15, 10, 'late') = 87
    AND private.daily_lesson_reward_yuzu(20, 10, 'late') = 100
    AND private.daily_lesson_reward_yuzu(9, 10, 'on_time') = 0
    AND private.daily_lesson_reward_yuzu(20, 10, 'expired') = 0,
    'reward thresholds cover 99 100 149 150 199 and 200 percent'
);

INSERT INTO public.daily_missions (
    user_id, mission_date, time_zone, target_words,
    starts_at, ends_at, next_day_ends_at
) VALUES
    (:'a', '2026-10-10', 'Asia/Bangkok', 2,
     '2026-10-09T17:00:00Z', '2026-10-10T17:00:00Z', '2026-10-11T17:00:00Z'),
    (:'a', '2026-10-11', 'Asia/Bangkok', 2,
     '2026-10-10T17:00:00Z', '2026-10-11T17:00:00Z', '2026-10-12T17:00:00Z'),
    (:'a', '2026-10-12', 'Asia/Bangkok', 2,
     '2026-10-11T17:00:00Z', '2026-10-12T17:00:00Z', '2026-10-13T17:00:00Z'),
    (:'a', '2026-10-13', 'Asia/Bangkok', 2,
     '2026-10-12T17:00:00Z', '2026-10-13T17:00:00Z', '2026-10-14T17:00:00Z'),
    (:'a', '2026-10-14', 'Asia/Bangkok', 2,
     '2026-10-13T17:00:00Z', '2026-10-14T17:00:00Z', '2026-10-15T17:00:00Z');

SELECT set_config('request.jwt.claim.sub', :'a', false);
SET ROLE authenticated;

SELECT public.h2a_assert(
    (public.h5_sync(
        'h5-day-10', '2026-10-10', 2, '2026-10-10T10:00:00Z'
    )).reward_yuzu = 100,
    'first on-time 100 percent completion awards 100 Yuzu'
);
SELECT public.h2a_assert(
    (public.h5_sync(
        'h5-day-11', '2026-10-11', 3, '2026-10-11T10:00:00Z'
    )).reward_yuzu = 130,
    'first on-time 150 percent completion awards 130 Yuzu'
);
SELECT public.h2a_assert(
    (public.h5_sync(
        'h5-day-12', '2026-10-12', 4, '2026-10-12T18:00:00Z'
    )).reward_yuzu = 100,
    'late 200 percent completion awards reduced 100 Yuzu'
);
SELECT public.h2a_assert(
    (public.h5_sync(
        'h5-day-13', '2026-10-13', 2, '2026-10-13T18:00:00Z'
    )).reward_yuzu = 67,
    'late 100 percent completion awards reduced 67 Yuzu'
);
SELECT public.h2a_assert(
    (public.h5_sync(
        'h5-day-14', '2026-10-14', 3, '2026-10-14T18:00:00Z'
    )).reward_yuzu = 87,
    'late 150 percent completion awards reduced 87 Yuzu'
);

SELECT public.h5_sync(
    'h5-day-10-replay', '2026-10-10', 2, '2026-10-10T12:00:00Z'
);
SELECT public.h2a_assert(
    (SELECT reward_yuzu = 33
            AND weekly_yuzu = 0
            AND completion_ordinal = 2
     FROM public.lesson_completion_receipts
     WHERE result_id = 'h5-day-10-replay:completion')
    AND (SELECT wallet_yuzu = 33 AND weekly_yuzu = 0
         FROM public.yuzu_reward_ledger
         WHERE receipt_id = 'h5-day-10-replay:completion'),
    'first replay awards floor one third to wallet only'
);

SELECT public.h5_sync(
    'h5-day-10-review', '2026-10-10', 2, '2026-10-10T13:00:00Z'
);
SELECT public.h2a_assert(
    (SELECT reward_status = 'rejected' AND completion_ordinal = 3
     FROM public.lesson_completion_receipts
     WHERE result_id = 'h5-day-10-review:completion')
    AND (SELECT wallet_yuzu = 0 AND weekly_yuzu = 0
         FROM public.yuzu_reward_ledger
         WHERE receipt_id = 'h5-day-10-review:completion'),
    'third completion creates no wallet or weekly reward'
);

SELECT public.h2a_assert(
    (public.h5_sync(
        'h5-day-10-replay', '2026-10-10', 2, '2026-10-10T12:00:00Z'
    )).reward_yuzu = 33
    AND (SELECT count(*) = 1 FROM public.yuzu_reward_ledger
         WHERE receipt_id = 'h5-day-10-replay:completion'),
    'identical rewarded replay retry cannot double award'
);

SELECT public.h5_sync(
    'h5-day-11-expired-replay', '2026-10-11', 3, '2026-10-13T10:00:00Z'
);
SELECT public.h2a_assert(
    (SELECT reward_status = 'rejected'
            AND reward_timing = 'expired'
            AND reward_yuzu IS NULL
            AND weekly_yuzu = 0
            AND completion_ordinal = 2
     FROM public.lesson_completion_receipts
     WHERE result_id = 'h5-day-11-expired-replay:completion')
    AND (SELECT wallet_yuzu = 0 AND weekly_yuzu = 0
         FROM public.yuzu_reward_ledger
         WHERE receipt_id = 'h5-day-11-expired-replay:completion'),
    'rewarded replay after the 24 hour window creates no reward'
);

RESET ROLE;

SELECT public.h2a_assert(
    (SELECT total_coins = 617 AND streak_days = 2
     FROM public.users WHERE id = :'a')
    AND (SELECT sum(wallet_yuzu) = 517
         FROM public.yuzu_reward_ledger WHERE user_id = :'a')
    AND (SELECT sum(weekly_yuzu) = 484
         FROM public.yuzu_reward_ledger WHERE user_id = :'a'),
    'wallet weekly ledger and streak settle to independent exact totals'
);

SELECT public.h2a_expect_error(
    $sql$
      SELECT public.h5_sync(
        'h5-day-10-fourth', '2026-10-10', 2, '2026-10-10T14:00:00Z'
      )
    $sql$,
    '22023',
    'fourth completion is refused instead of creating ledger noise'
);

SELECT public.h2a_expect_error(
    $sql$
      UPDATE public.yuzu_reward_ledger SET wallet_yuzu = 999
      WHERE receipt_id = 'h5-day-10:completion'
    $sql$,
    '55000',
    'settled Yuzu ledger entries are immutable'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    NOT EXISTS (SELECT 1 FROM public.yuzu_reward_ledger)
    AND NOT EXISTS (SELECT 1 FROM public.lesson_streak_days),
    'another account cannot read Yuzu or streak ledger rows'
);
RESET ROLE;
