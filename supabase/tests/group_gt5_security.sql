BEGIN;
\set teacher 11111111-1111-4111-8111-111111111111
\set student 22222222-2222-4222-8222-222222222222
\set outsider 33333333-3333-4333-8333-333333333333

INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    (:'teacher', 'gt5.teacher@example.test', NOW()),
    (:'student', 'gt5.student@example.test', NOW()),
    (:'outsider', 'gt5.outsider@example.test', NOW());
INSERT INTO public.users (
    id, email, display_name, username, account_role
) VALUES
    (:'teacher', 'gt5.teacher@example.test', 'GT5 Teacher', 'gt5_teacher', 'teacher'),
    (:'student', 'gt5.student@example.test', 'GT5 Student', 'gt5_student', 'personal'),
    (:'outsider', 'gt5.outsider@example.test', 'GT5 Outsider', 'gt5_outsider', 'personal');

SET ROLE service_role;
SELECT set_config('request.jwt.claims', '{"role":"service_role"}', false);
SELECT public.set_teacher_verification(:'teacher', 'verified', 'gt5_test');
RESET ROLE;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claims', '{"role":"authenticated"}', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.create_learning_group(
    'GT5 private class', 'Text-only learning projection test',
    '71000000-0000-4000-8000-000000000001'
) AS group_id \gset

RESET ROLE;
INSERT INTO public.learning_group_members(
    group_id, user_id, role, status, joined_at
) VALUES (:'group_id', :'student', 'student', 'active', NOW());

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT NOW() + INTERVAL '7 days' AS task_due_at \gset
SELECT public.create_learning_group_system_task(
    :'group_id', 'Học 2 từ mới', 2, :'task_due_at'::TIMESTAMPTZ,
    '71000000-0000-4000-8000-000000000002'
) AS task_id \gset

SELECT public.gt3_assert(
    public.create_learning_group_system_task(
        :'group_id', 'Học 2 từ mới', 2, :'task_due_at'::TIMESTAMPTZ,
        '71000000-0000-4000-8000-000000000002'
    ) = :'task_id'::UUID,
    'system task creation replays idempotently with the same request id'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 1
     FROM public.list_learning_group_moderation_events(:'group_id', 100)
     WHERE action = 'system_task_created'),
    'system task creation writes exactly one owner audit event'
);

SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_assert(
    (SELECT progress_status = 'sharing_off' AND NOT sharing_enabled
     FROM public.list_learning_group_system_tasks(:'group_id')
     WHERE task_id = :'task_id'),
    'student task starts fail-closed while vocabulary sharing is off'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT public.create_learning_group_system_task(%L, %L, 2, NOW() + INTERVAL ''1 day'', %L)',
        :'group_id', 'student forbidden', '71000000-0000-4000-8000-000000000004'
    ),
    '42501',
    'student cannot create a system task'
);
SELECT public.gt3_assert(
    public.set_learning_group_vocabulary_sharing(:'group_id', TRUE),
    'active student explicitly enables vocabulary sharing'
);
SELECT public.gt3_assert(
    public.get_my_learning_group_vocabulary_sharing(:'group_id'),
    'student reads own group-scoped vocabulary sharing state'
);

RESET ROLE;
INSERT INTO public.lesson_completion_receipts (
    result_id, session_id, user_id, mission_date,
    total_items, completed_items, source_revision_hash,
    rule_version, normalizer_version, evidence, completed_at
) VALUES (
    'gt5-session:completion', 'gt5-session', :'student', CURRENT_DATE,
    2, 2, repeat('a', 64), 'rule-v1', 'normalizer-v1',
    jsonb_build_object(
        'items', jsonb_build_array(
            jsonb_build_object('id', 'item-apple', 'word', 'apple'),
            jsonb_build_object('id', 'item-book', 'word', 'book')
        ),
        'attempts', jsonb_build_array(
            jsonb_build_object(
                'id', 'attempt-1',
                'verdicts', jsonb_build_array(
                    jsonb_build_object('item_id', 'item-apple', 'is_correct', true),
                    jsonb_build_object('item_id', 'item-book', 'is_correct', true)
                )
            )
        )
    ),
    NOW() + INTERVAL '1 second'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt3_assert(
    (SELECT sharing_enabled AND total_learned_word_count = 2
        AND completed_task_count >= 1 AND average_mastery_percent = 100
     FROM public.list_learning_group_learning_overview(:'group_id')
     WHERE student_user_id = :'student'),
    'owner overview shows consented aggregate and completed task progress'
);
SELECT public.gt3_assert(
    (SELECT COUNT(*) = 2
        AND BOOL_AND(NOT (to_jsonb(vocabulary) ?| ARRAY[
            'source_receipt_id', 'source_item_id', 'photo_note_id',
            'media_asset_id', 'image_path', 'raw_response'
        ]))
     FROM public.list_learning_group_student_vocabulary(
        :'group_id', :'student', 200
     ) AS vocabulary),
    'teacher vocabulary projection exposes words without source or image identifiers'
);
SELECT public.gt3_assert(
    (SELECT completed_student_count = 1 AND assigned_student_count = 1
     FROM public.list_learning_group_system_tasks(:'group_id')
     WHERE task_id = :'task_id'),
    'owner task summary derives completion from accepted lesson evidence'
);

SELECT set_config('request.jwt.claim.sub', :'student', false);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_learning_overview(%L)',
        :'group_id'
    ),
    '42501',
    'student cannot read class learning overview'
);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_student_vocabulary(%L, %L, 200)',
        :'group_id', :'student'
    ),
    '42501',
    'student cannot invoke teacher vocabulary projection'
);

SELECT public.gt3_assert(
    NOT public.set_learning_group_vocabulary_sharing(:'group_id', FALSE),
    'student can revoke vocabulary sharing'
);
SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt3_assert(
    (SELECT NOT sharing_enabled AND total_learned_word_count = 0
     FROM public.list_learning_group_learning_overview(:'group_id')
     WHERE student_user_id = :'student'),
    'revoking sharing purges teacher-visible vocabulary projection'
);

SELECT set_config('request.jwt.claim.sub', :'outsider', false);
SELECT public.gt3_expect_error(
    format(
        'SELECT * FROM public.list_learning_group_system_tasks(%L)',
        :'group_id'
    ),
    '42501',
    'outsider cannot read group tasks'
);

SELECT set_config('request.jwt.claim.sub', :'teacher', false);
SELECT public.gt3_assert(
    public.close_learning_group_system_task(
        :'group_id', :'task_id', '71000000-0000-4000-8000-000000000005'
    ),
    'verified owner closes a system task'
);
SELECT public.gt3_assert(
    (SELECT action = 'system_task_closed'
     FROM public.list_learning_group_moderation_events(:'group_id', 1)),
    'system task closure is recorded in owner audit'
);
SELECT public.gt3_assert(
    NOT has_table_privilege('authenticated',
        'private.learning_group_vocabulary_progress', 'SELECT'),
    'authenticated clients have no direct vocabulary projection table access'
);

ROLLBACK;
