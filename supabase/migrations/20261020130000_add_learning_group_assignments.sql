BEGIN;

CREATE TABLE private.learning_group_system_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.learning_groups(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    title TEXT NOT NULL CHECK (CHAR_LENGTH(BTRIM(title)) BETWEEN 1 AND 120),
    target_word_count INTEGER NOT NULL CHECK (target_word_count BETWEEN 1 AND 100),
    due_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
    request_id UUID NOT NULL,
    closed_request_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    UNIQUE (group_id, request_id),
    CHECK (due_at > created_at),
    CHECK ((status = 'closed') = (closed_at IS NOT NULL))
);

CREATE INDEX learning_group_system_tasks_list
ON private.learning_group_system_tasks(group_id, status, due_at, created_at DESC);

CREATE TABLE private.learning_group_vocabulary_shares (
    group_id UUID NOT NULL,
    student_user_id UUID NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, student_user_id),
    FOREIGN KEY (group_id, student_user_id)
        REFERENCES public.learning_group_members(group_id, user_id)
        ON DELETE CASCADE
);

CREATE TABLE private.learning_group_vocabulary_progress (
    group_id UUID NOT NULL,
    student_user_id UUID NOT NULL,
    word_key TEXT NOT NULL CHECK (CHAR_LENGTH(word_key) BETWEEN 1 AND 120),
    word TEXT NOT NULL CHECK (CHAR_LENGTH(BTRIM(word)) BETWEEN 1 AND 120),
    source_receipt_id TEXT NOT NULL
        REFERENCES public.lesson_completion_receipts(result_id) ON DELETE CASCADE,
    source_item_id TEXT NOT NULL CHECK (CHAR_LENGTH(BTRIM(source_item_id)) BETWEEN 1 AND 160),
    first_learned_at TIMESTAMPTZ NOT NULL,
    last_learned_at TIMESTAMPTZ NOT NULL,
    shared_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, student_user_id, word_key),
    FOREIGN KEY (group_id, student_user_id)
        REFERENCES private.learning_group_vocabulary_shares(group_id, student_user_id)
        ON DELETE CASCADE,
    CHECK (last_learned_at >= first_learned_at)
);

CREATE INDEX learning_group_vocabulary_progress_overview
ON private.learning_group_vocabulary_progress(
    group_id, student_user_id, first_learned_at DESC
);

ALTER TABLE private.learning_group_system_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.learning_group_vocabulary_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.learning_group_vocabulary_progress ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON private.learning_group_system_tasks,
    private.learning_group_vocabulary_shares,
    private.learning_group_vocabulary_progress
FROM PUBLIC, anon, authenticated;

ALTER TABLE private.learning_group_moderation_events
DROP CONSTRAINT learning_group_moderation_events_action_check;

ALTER TABLE private.learning_group_moderation_events
ADD CONSTRAINT learning_group_moderation_events_action_check CHECK (action IN (
    'group_created', 'group_updated', 'group_archived',
    'invite_rotated', 'invite_revoked', 'join_requested',
    'join_approved', 'join_rejected', 'member_left',
    'member_removed', 'member_muted', 'member_unmuted',
    'announcement_created', 'announcement_pinned',
    'announcement_unpinned', 'message_hidden', 'message_restored',
    'system_task_created', 'system_task_closed'
));

CREATE FUNCTION private.project_learning_group_vocabulary_receipt(
    p_group_id UUID,
    p_user_id UUID,
    p_receipt_id TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_count INTEGER := 0;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM private.learning_group_vocabulary_shares AS share
        JOIN public.learning_group_members AS member
          ON member.group_id = share.group_id
         AND member.user_id = share.student_user_id
        JOIN public.learning_groups AS group_row ON group_row.id = share.group_id
        WHERE share.group_id = p_group_id
          AND share.student_user_id = p_user_id
          AND share.enabled
          AND member.role = 'student'
          AND member.status = 'active'
          AND group_row.status = 'active'
    ) THEN
        RETURN 0;
    END IF;

    INSERT INTO private.learning_group_vocabulary_progress (
        group_id, student_user_id, word_key, word,
        source_receipt_id, source_item_id,
        first_learned_at, last_learned_at
    )
    SELECT p_group_id, receipt.user_id, LOWER(BTRIM(item ->> 'word')),
           BTRIM(item ->> 'word'), receipt.result_id, item ->> 'id',
           receipt.completed_at, receipt.completed_at
    FROM public.lesson_completion_receipts AS receipt
    CROSS JOIN LATERAL jsonb_array_elements(receipt.evidence -> 'items') AS item
    WHERE receipt.result_id = p_receipt_id
      AND receipt.user_id = p_user_id
      AND receipt.accepted_at IS NOT NULL
      AND receipt.completed_items = receipt.total_items
      AND jsonb_typeof(receipt.evidence -> 'items') = 'array'
      AND jsonb_typeof(item) = 'object'
      AND NULLIF(BTRIM(item ->> 'id'), '') IS NOT NULL
      AND CHAR_LENGTH(BTRIM(item ->> 'id')) <= 160
      AND NULLIF(BTRIM(item ->> 'word'), '') IS NOT NULL
      AND CHAR_LENGTH(BTRIM(item ->> 'word')) <= 120
      AND EXISTS (
          SELECT 1
          FROM jsonb_array_elements(receipt.evidence -> 'attempts') AS attempt
          CROSS JOIN LATERAL jsonb_array_elements(
              CASE WHEN jsonb_typeof(attempt -> 'verdicts') = 'array'
                  THEN attempt -> 'verdicts' ELSE '[]'::JSONB END
          ) AS verdict
          WHERE verdict ->> 'item_id' = item ->> 'id'
            AND verdict ->> 'is_correct' = 'true'
      )
    ON CONFLICT (group_id, student_user_id, word_key) DO UPDATE
    SET word = EXCLUDED.word,
        source_receipt_id = EXCLUDED.source_receipt_id,
        source_item_id = EXCLUDED.source_item_id,
        first_learned_at = LEAST(
            private.learning_group_vocabulary_progress.first_learned_at,
            EXCLUDED.first_learned_at
        ),
        last_learned_at = GREATEST(
            private.learning_group_vocabulary_progress.last_learned_at,
            EXCLUDED.last_learned_at
        ),
        shared_at = NOW();

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION private.project_learning_group_vocabulary_receipt(
    UUID, UUID, TEXT
) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION private.project_new_lesson_receipt_to_learning_groups()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE share_row RECORD;
BEGIN
    FOR share_row IN
        SELECT share.group_id
        FROM private.learning_group_vocabulary_shares AS share
        WHERE share.student_user_id = NEW.user_id
          AND share.enabled
    LOOP
        PERFORM private.project_learning_group_vocabulary_receipt(
            share_row.group_id, NEW.user_id, NEW.result_id
        );
    END LOOP;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.project_new_lesson_receipt_to_learning_groups()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER project_lesson_receipt_to_learning_groups
AFTER INSERT ON public.lesson_completion_receipts
FOR EACH ROW EXECUTE FUNCTION private.project_new_lesson_receipt_to_learning_groups();

CREATE FUNCTION private.revoke_learning_group_vocabulary_on_membership_end()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'DELETE' AND OLD.role = 'student' AND OLD.status = 'active' THEN
        DELETE FROM private.learning_group_vocabulary_shares
        WHERE group_id = OLD.group_id AND student_user_id = OLD.user_id;
        RETURN OLD;
    END IF;
    IF OLD.role = 'student' AND OLD.status = 'active' AND NEW.status <> 'active' THEN
        DELETE FROM private.learning_group_vocabulary_shares
        WHERE group_id = OLD.group_id AND student_user_id = OLD.user_id;
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.revoke_learning_group_vocabulary_on_membership_end()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER revoke_learning_group_vocabulary_on_membership_end
AFTER UPDATE OF status OR DELETE ON public.learning_group_members
FOR EACH ROW EXECUTE FUNCTION private.revoke_learning_group_vocabulary_on_membership_end();

CREATE FUNCTION public.set_learning_group_vocabulary_sharing(
    p_group_id UUID,
    p_enabled BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_member public.learning_group_members%ROWTYPE;
    v_receipt RECORD;
BEGIN
    IF v_user IS NULL OR p_group_id IS NULL OR p_enabled IS NULL THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;

    SELECT member.* INTO v_member
    FROM public.learning_group_members AS member
    WHERE member.group_id = p_group_id AND member.user_id = v_user;

    IF NOT FOUND OR v_member.role <> 'student' THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;

    IF p_enabled THEN
        IF v_member.status <> 'active' OR NOT EXISTS (
            SELECT 1 FROM public.learning_groups AS group_row
            WHERE group_row.id = p_group_id AND group_row.status = 'active'
        ) THEN
            RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
        END IF;
        INSERT INTO private.learning_group_vocabulary_shares (
            group_id, student_user_id, enabled, updated_at
        ) VALUES (p_group_id, v_user, TRUE, NOW())
        ON CONFLICT (group_id, student_user_id) DO UPDATE
        SET enabled = TRUE, updated_at = NOW();

        FOR v_receipt IN
            SELECT receipt.result_id
            FROM public.lesson_completion_receipts AS receipt
            WHERE receipt.user_id = v_user AND receipt.accepted_at IS NOT NULL
        LOOP
            PERFORM private.project_learning_group_vocabulary_receipt(
                p_group_id, v_user, v_receipt.result_id
            );
        END LOOP;
    ELSE
        INSERT INTO private.learning_group_vocabulary_shares (
            group_id, student_user_id, enabled, updated_at
        ) VALUES (p_group_id, v_user, FALSE, NOW())
        ON CONFLICT (group_id, student_user_id) DO UPDATE
        SET enabled = FALSE, updated_at = NOW();
        DELETE FROM private.learning_group_vocabulary_progress
        WHERE group_id = p_group_id AND student_user_id = v_user;
    END IF;
    RETURN p_enabled;
END;
$$;

CREATE FUNCTION public.create_learning_group_system_task(
    p_group_id UUID,
    p_title TEXT,
    p_target_word_count INTEGER,
    p_due_at TIMESTAMPTZ,
    p_request_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_task private.learning_group_system_tasks%ROWTYPE;
BEGIN
    IF v_user IS NULL OR p_group_id IS NULL OR p_request_id IS NULL
       OR p_title IS NULL OR CHAR_LENGTH(BTRIM(p_title)) NOT BETWEEN 1 AND 120
       OR p_target_word_count IS NULL OR p_target_word_count NOT BETWEEN 1 AND 100
       OR p_due_at IS NULL OR p_due_at <= NOW() THEN
        RAISE EXCEPTION 'invalid_system_task' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user)
       OR NOT private.is_learning_group_owner_member(p_group_id, v_user)
       OR NOT EXISTS (
           SELECT 1 FROM public.learning_groups AS group_row
           WHERE group_row.id = p_group_id AND group_row.status = 'active'
       ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;

    INSERT INTO private.learning_group_system_tasks (
        group_id, created_by, title, target_word_count, due_at, request_id
    ) VALUES (
        p_group_id, v_user, BTRIM(p_title), p_target_word_count, p_due_at,
        p_request_id
    )
    ON CONFLICT (group_id, request_id) DO NOTHING
    RETURNING * INTO v_task;

    IF NOT FOUND THEN
        SELECT task.* INTO v_task
        FROM private.learning_group_system_tasks AS task
        WHERE task.group_id = p_group_id AND task.request_id = p_request_id;
        IF NOT FOUND
           OR v_task.created_by IS DISTINCT FROM v_user
           OR v_task.title IS DISTINCT FROM BTRIM(p_title)
           OR v_task.target_word_count IS DISTINCT FROM p_target_word_count
           OR v_task.due_at IS DISTINCT FROM p_due_at THEN
            RAISE EXCEPTION 'system_task_request_conflict' USING ERRCODE = '23505';
        END IF;
        RETURN v_task.id;
    END IF;

    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, reason_code, request_id
    ) VALUES (p_group_id, v_user, 'system_task_created', 'teacher_created', p_request_id);
    RETURN v_task.id;
END;
$$;

CREATE FUNCTION public.get_my_learning_group_vocabulary_sharing(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.learning_group_members AS member
        WHERE member.group_id = p_group_id
          AND member.user_id = v_user
          AND member.role = 'student'
          AND member.status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    RETURN COALESCE((
        SELECT share.enabled
        FROM private.learning_group_vocabulary_shares AS share
        WHERE share.group_id = p_group_id AND share.student_user_id = v_user
    ), FALSE);
END;
$$;

CREATE FUNCTION public.close_learning_group_system_task(
    p_group_id UUID,
    p_task_id UUID,
    p_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_task private.learning_group_system_tasks%ROWTYPE;
BEGIN
    IF v_user IS NULL OR p_group_id IS NULL OR p_task_id IS NULL OR p_request_id IS NULL
       OR NOT private.is_verified_teacher(v_user)
       OR NOT private.is_learning_group_owner_member(p_group_id, v_user) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    SELECT task.* INTO v_task
    FROM private.learning_group_system_tasks AS task
    WHERE task.id = p_task_id AND task.group_id = p_group_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'system_task_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF v_task.status = 'closed' THEN
        IF v_task.closed_request_id IS DISTINCT FROM p_request_id THEN
            RAISE EXCEPTION 'system_task_already_closed' USING ERRCODE = '23505';
        END IF;
        RETURN TRUE;
    END IF;
    UPDATE private.learning_group_system_tasks
    SET status = 'closed', closed_at = NOW(), updated_at = NOW(),
        closed_request_id = p_request_id
    WHERE id = p_task_id;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, reason_code, request_id
    ) VALUES (p_group_id, v_user, 'system_task_closed', 'teacher_closed', p_request_id);
    RETURN TRUE;
END;
$$;

CREATE FUNCTION public.list_learning_group_system_tasks(p_group_id UUID)
RETURNS TABLE (
    task_id UUID,
    title TEXT,
    target_word_count INTEGER,
    due_at TIMESTAMPTZ,
    task_status TEXT,
    created_at TIMESTAMPTZ,
    learned_word_count INTEGER,
    mastery_percent INTEGER,
    progress_status TEXT,
    sharing_enabled BOOLEAN,
    assigned_student_count INTEGER,
    completed_student_count INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL OR NOT private.is_learning_group_active_member(p_group_id, v_user) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT task.id, task.title, task.target_word_count, task.due_at, task.status,
           task.created_at,
           CASE WHEN mine.role = 'student' THEN LEAST(my_progress.words, task.target_word_count) ELSE 0 END,
           CASE WHEN mine.role = 'student' THEN LEAST(100, FLOOR(100.0 * my_progress.words / task.target_word_count)::INT) ELSE 0 END,
           CASE
               WHEN mine.role <> 'student' THEN 'owner_view'
               WHEN NOT COALESCE(share.enabled, FALSE) THEN 'sharing_off'
               WHEN my_progress.words >= task.target_word_count THEN 'completed'
               WHEN task.status = 'closed' OR task.due_at < NOW() THEN 'overdue'
               WHEN my_progress.words > 0 THEN 'in_progress'
               ELSE 'not_started'
           END,
           CASE WHEN mine.role = 'student' THEN COALESCE(share.enabled, FALSE) ELSE FALSE END,
           totals.assigned_count,
           totals.completed_count
    FROM private.learning_group_system_tasks AS task
    JOIN public.learning_group_members AS mine
      ON mine.group_id = task.group_id AND mine.user_id = v_user AND mine.status = 'active'
    LEFT JOIN private.learning_group_vocabulary_shares AS share
      ON share.group_id = task.group_id AND share.student_user_id = v_user
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::INT AS words
        FROM private.learning_group_vocabulary_progress AS progress
        WHERE progress.group_id = task.group_id
          AND progress.student_user_id = v_user
          AND progress.first_learned_at >= task.created_at
          AND progress.first_learned_at <= task.due_at
    ) AS my_progress ON TRUE
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::INT AS assigned_count,
               COUNT(*) FILTER (WHERE member_progress.words >= task.target_word_count)::INT AS completed_count
        FROM public.learning_group_members AS student
        LEFT JOIN LATERAL (
            SELECT COUNT(*)::INT AS words
            FROM private.learning_group_vocabulary_progress AS progress
            WHERE progress.group_id = task.group_id
              AND progress.student_user_id = student.user_id
              AND progress.first_learned_at >= task.created_at
              AND progress.first_learned_at <= task.due_at
        ) AS member_progress ON TRUE
        WHERE student.group_id = task.group_id
          AND student.role = 'student' AND student.status = 'active'
    ) AS totals ON TRUE
    WHERE task.group_id = p_group_id
    ORDER BY CASE WHEN task.status = 'active' THEN 0 ELSE 1 END,
             task.due_at, task.created_at DESC, task.id;
END;
$$;

CREATE FUNCTION public.list_learning_group_learning_overview(p_group_id UUID)
RETURNS TABLE (
    student_user_id UUID,
    display_name TEXT,
    sharing_enabled BOOLEAN,
    total_learned_word_count INTEGER,
    active_task_count INTEGER,
    completed_task_count INTEGER,
    average_mastery_percent INTEGER,
    last_learned_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL OR NOT private.is_verified_teacher(v_user)
       OR NOT private.is_learning_group_owner_member(p_group_id, v_user) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT student.user_id, profile.display_name, COALESCE(share.enabled, FALSE),
           COALESCE(vocab.total_words, 0), COALESCE(task_stats.active_tasks, 0),
           COALESCE(task_stats.completed_tasks, 0),
           COALESCE(task_stats.average_mastery, 0), vocab.last_learned
    FROM public.learning_group_members AS student
    JOIN public.users AS profile ON profile.id = student.user_id
    LEFT JOIN private.learning_group_vocabulary_shares AS share
      ON share.group_id = student.group_id AND share.student_user_id = student.user_id
    LEFT JOIN LATERAL (
        SELECT COUNT(*)::INT AS total_words, MAX(progress.last_learned_at) AS last_learned
        FROM private.learning_group_vocabulary_progress AS progress
        WHERE progress.group_id = student.group_id
          AND progress.student_user_id = student.user_id
          AND COALESCE(share.enabled, FALSE)
    ) AS vocab ON TRUE
    LEFT JOIN LATERAL (
        SELECT COUNT(*) FILTER (WHERE task.status = 'active')::INT AS active_tasks,
               COUNT(*) FILTER (
                   WHERE task.status = 'active' AND counts.words >= task.target_word_count
               )::INT AS completed_tasks,
               COALESCE(AVG(
                   CASE WHEN task.status = 'active' THEN
                       LEAST(100, FLOOR(100.0 * counts.words / task.target_word_count)::INT)
                   END
               ), 0)::INT AS average_mastery
        FROM private.learning_group_system_tasks AS task
        LEFT JOIN LATERAL (
            SELECT COUNT(*)::INT AS words
            FROM private.learning_group_vocabulary_progress AS progress
            WHERE progress.group_id = task.group_id
              AND progress.student_user_id = student.user_id
              AND progress.first_learned_at >= task.created_at
              AND progress.first_learned_at <= task.due_at
        ) AS counts ON TRUE
        WHERE task.group_id = student.group_id
    ) AS task_stats ON TRUE
    WHERE student.group_id = p_group_id
      AND student.role = 'student' AND student.status = 'active'
    ORDER BY profile.display_name, student.user_id;
END;
$$;

CREATE FUNCTION public.list_learning_group_student_vocabulary(
    p_group_id UUID,
    p_student_user_id UUID,
    p_limit INTEGER DEFAULT 200
)
RETURNS TABLE (
    word TEXT,
    first_learned_at TIMESTAMPTZ,
    last_learned_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN
        RAISE EXCEPTION 'invalid_vocabulary_limit' USING ERRCODE = '22023';
    END IF;
    IF v_user IS NULL OR NOT private.is_verified_teacher(v_user)
       OR NOT private.is_learning_group_owner_member(p_group_id, v_user)
       OR NOT EXISTS (
           SELECT 1
           FROM public.learning_group_members AS member
           JOIN private.learning_group_vocabulary_shares AS share
             ON share.group_id = member.group_id
            AND share.student_user_id = member.user_id
            AND share.enabled
           WHERE member.group_id = p_group_id
             AND member.user_id = p_student_user_id
             AND member.role = 'student' AND member.status = 'active'
       ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT progress.word, progress.first_learned_at, progress.last_learned_at
    FROM private.learning_group_vocabulary_progress AS progress
    WHERE progress.group_id = p_group_id
      AND progress.student_user_id = p_student_user_id
    ORDER BY progress.last_learned_at DESC, progress.word_key
    LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.set_learning_group_vocabulary_sharing(UUID, BOOLEAN)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_learning_group_vocabulary_sharing(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_learning_group_system_task(
    UUID, TEXT, INTEGER, TIMESTAMPTZ, UUID
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.close_learning_group_system_task(UUID, UUID, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_learning_group_system_tasks(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_learning_group_learning_overview(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_learning_group_student_vocabulary(UUID, UUID, INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_learning_group_vocabulary_sharing(UUID, BOOLEAN)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_learning_group_vocabulary_sharing(UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_learning_group_system_task(
    UUID, TEXT, INTEGER, TIMESTAMPTZ, UUID
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_learning_group_system_task(UUID, UUID, UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_learning_group_system_tasks(UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_learning_group_learning_overview(UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_learning_group_student_vocabulary(UUID, UUID, INTEGER)
TO authenticated;

COMMENT ON TABLE private.learning_group_vocabulary_progress IS
'GT5 opt-in text-only vocabulary projection. Never stores photo, media, scan, box or raw Vision data.';
COMMENT ON FUNCTION public.list_learning_group_student_vocabulary(UUID, UUID, INTEGER) IS
'GT5 owner-only bounded word projection; never returns source receipt/item/photo/media identifiers.';

COMMIT;
