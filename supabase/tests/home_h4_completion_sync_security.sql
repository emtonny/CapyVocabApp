\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'

SELECT public.h2a_assert(
    has_table_privilege(
        'authenticated', 'public.lesson_completion_receipts', 'SELECT')
    AND NOT has_table_privilege(
        'authenticated', 'public.lesson_completion_receipts', 'INSERT')
    AND NOT has_table_privilege(
        'authenticated', 'public.lesson_completion_receipts', 'UPDATE')
    AND NOT has_table_privilege(
        'authenticated', 'public.lesson_completion_receipts', 'DELETE'),
    'authenticated clients can read but cannot directly mutate receipts'
);

SELECT public.h2a_assert(
    has_function_privilege(
        'authenticated',
        'public.sync_lesson_completion(text,text,date,integer,integer,text,text,text,jsonb,timestamptz)',
        'EXECUTE')
    AND NOT has_function_privilege(
        'anon',
        'public.sync_lesson_completion(text,text,date,integer,integer,text,text,text,jsonb,timestamptz)',
        'EXECUTE'),
    'only authenticated clients can call lesson completion sync'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SET ROLE authenticated;

SELECT public.h2a_assert(
    (public.sync_lesson_completion(
        'session-a:completion',
        'session-a',
        '2026-09-28',
        2,
        2,
        '0123456789abcdef0123456789abcdef',
        'h3-rules-v1',
        'nfc-casefold-v1',
        '{
          "items": [
            {"id": "item-1", "source_revision": "r1"},
            {"id": "item-2", "source_revision": "r2"}
          ],
          "attempts": [
            {"id": "attempt-1", "verdicts": [
              {"item_id": "item-1", "is_correct": true},
              {"item_id": "item-2", "is_correct": true}
            ]}
          ]
        }'::JSONB,
        '2026-09-28T10:00:00Z'
    )).reward_status = 'pending',
    'first full completion creates a reward-pending receipt'
);

SELECT public.h2a_assert(
    (public.sync_lesson_completion(
        'session-a:completion',
        'session-a',
        '2026-09-28',
        2,
        2,
        '0123456789abcdef0123456789abcdef',
        'h3-rules-v1',
        'nfc-casefold-v1',
        '{
          "items": [
            {"id": "item-1", "source_revision": "r1"},
            {"id": "item-2", "source_revision": "r2"}
          ],
          "attempts": [
            {"id": "attempt-1", "verdicts": [
              {"item_id": "item-1", "is_correct": true},
              {"item_id": "item-2", "is_correct": true}
            ]}
          ]
        }'::JSONB,
        '2026-09-28T10:00:00Z'
    )).result_id = 'session-a:completion'
    AND (SELECT count(*) FROM public.lesson_completion_receipts) = 1,
    'identical retry returns the original receipt without duplication'
);

RESET ROLE;

SELECT public.h2a_expect_error(
    $sql$
      SELECT public.sync_lesson_completion(
        'session-a:completion', 'session-a', '2026-09-28', 2, 2,
        'fedcba9876543210fedcba9876543210',
        'h3-rules-v1', 'nfc-casefold-v1',
        '{"items":[{"id":"item-1"},{"id":"item-2"}],
          "attempts":[{"verdicts":[
            {"item_id":"item-1","is_correct":true},
            {"item_id":"item-2","is_correct":true}
          ]}]}'::jsonb,
        '2026-09-28T10:00:00Z'
      )
    $sql$,
    '23505',
    'same identity with a changed payload is rejected'
);

SELECT public.h2a_expect_error(
    $sql$
      SELECT public.sync_lesson_completion(
        'partial:completion', 'partial', '2026-09-28', 2, 1,
        '0123456789abcdef0123456789abcdef',
        'h3-rules-v1', 'nfc-casefold-v1',
        '{"items":[{"id":"item-1"},{"id":"item-2"}],
          "attempts":[{"verdicts":[
            {"item_id":"item-1","is_correct":true}
          ]}]}'::jsonb,
        '2026-09-28T10:00:00Z'
      )
    $sql$,
    '22023',
    'partial completion cannot be synchronized'
);

SELECT public.h2a_expect_error(
    $sql$
      SELECT public.sync_lesson_completion(
        'unproved:completion', 'unproved', '2026-09-28', 2, 2,
        '0123456789abcdef0123456789abcdef',
        'h3-rules-v1', 'nfc-casefold-v1',
        '{"items":[{"id":"item-1"},{"id":"item-2"}],
          "attempts":[{"verdicts":[
            {"item_id":"item-1","is_correct":true},
            {"item_id":"item-2","is_correct":false}
          ]}]}'::jsonb,
        '2026-09-28T10:00:00Z'
      )
    $sql$,
    '22023',
    'evidence missing full mastery is rejected'
);

SELECT public.h2a_expect_error(
    $sql$
      SELECT public.sync_lesson_completion(
        'missing-day:completion', 'missing-day', '2026-12-31', 1, 1,
        '0123456789abcdef0123456789abcdef',
        'h3-rules-v1', 'nfc-casefold-v1',
        '{"items":[{"id":"item-1"}],
          "attempts":[{"verdicts":[
            {"item_id":"item-1","is_correct":true}
          ]}]}'::jsonb,
        '2026-12-31T10:00:00Z'
      )
    $sql$,
    'P0002',
    'receipt requires the authenticated owner daily mission'
);

SET ROLE authenticated;
SELECT public.h2a_assert(
    (SELECT count(*) = 1 FROM public.lesson_completion_receipts),
    'owner RLS returns its own receipt'
);
RESET ROLE;

SELECT set_config('request.jwt.claim.sub', :'b', false);
SET ROLE authenticated;
SELECT public.h2a_assert(
    NOT EXISTS (SELECT 1 FROM public.lesson_completion_receipts),
    'another account cannot read the owner receipt'
);
RESET ROLE;

SELECT public.h2a_assert(
    NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'lesson_completion_receipts'
          AND column_name IN ('total_coins', 'weekly_yuzu', 'streak_days')
    ),
    'receipt sync introduces no spendable coin column'
);

SELECT public.h2a_assert(
    (SELECT reward_status = 'pending'
        AND reward_yuzu IS NULL
        AND rewarded_at IS NULL
     FROM public.lesson_completion_receipts
     WHERE result_id = 'session-a:completion'),
    'H4 does not settle rewards or leaderboard value'
);
