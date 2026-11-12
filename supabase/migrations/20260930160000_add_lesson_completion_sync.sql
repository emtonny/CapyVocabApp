-- H4: idempotent, owner-scoped lesson completion receipts.
--
-- This migration deliberately does not award Yuzu, update streaks, or write
-- leaderboard data. H5 owns those server-authoritative mutations.

CREATE TABLE public.lesson_completion_receipts (
    result_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id UUID NOT NULL
        REFERENCES public.users(id) ON DELETE CASCADE,
    mission_date DATE NOT NULL,
    total_items INTEGER NOT NULL CHECK (total_items > 0),
    completed_items INTEGER NOT NULL CHECK (
        completed_items = total_items
    ),
    source_revision_hash TEXT NOT NULL CHECK (
        length(source_revision_hash) BETWEEN 16 AND 128
    ),
    rule_version TEXT NOT NULL CHECK (
        length(rule_version) BETWEEN 1 AND 64
    ),
    normalizer_version TEXT NOT NULL CHECK (
        length(normalizer_version) BETWEEN 1 AND 64
    ),
    evidence JSONB NOT NULL CHECK (jsonb_typeof(evidence) = 'object'),
    completed_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT statement_timestamp(),
    reward_status TEXT NOT NULL DEFAULT 'pending' CHECK (
        reward_status IN ('pending', 'awarded', 'rejected')
    ),
    reward_yuzu INTEGER CHECK (reward_yuzu IS NULL OR reward_yuzu >= 0),
    rewarded_at TIMESTAMPTZ,
    UNIQUE (user_id, session_id),
    UNIQUE (user_id, mission_date),
    FOREIGN KEY (user_id, mission_date)
        REFERENCES public.daily_missions(user_id, mission_date),
    CHECK (
        (reward_status = 'pending'
            AND reward_yuzu IS NULL
            AND rewarded_at IS NULL)
        OR
        (reward_status = 'awarded'
            AND reward_yuzu IS NOT NULL
            AND rewarded_at IS NOT NULL)
        OR
        (reward_status = 'rejected'
            AND reward_yuzu IS NULL
            AND rewarded_at IS NULL)
    )
);

COMMENT ON TABLE public.lesson_completion_receipts IS
    'H4 immutable daily lesson completion receipts. H5 owns reward settlement.';

CREATE INDEX idx_lesson_completion_receipts_owner_accepted
ON public.lesson_completion_receipts(user_id, accepted_at DESC);

CREATE OR REPLACE FUNCTION private.reject_lesson_receipt_payload_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    RAISE EXCEPTION 'lesson completion receipt payload is immutable'
        USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION private.reject_lesson_receipt_payload_update()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_lesson_completion_receipt_payload_immutable
BEFORE UPDATE OF
    result_id,
    session_id,
    user_id,
    mission_date,
    total_items,
    completed_items,
    source_revision_hash,
    rule_version,
    normalizer_version,
    evidence,
    completed_at,
    accepted_at
ON public.lesson_completion_receipts
FOR EACH ROW EXECUTE FUNCTION private.reject_lesson_receipt_payload_update();

ALTER TABLE public.lesson_completion_receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read their own lesson completion receipts"
ON public.lesson_completion_receipts
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.lesson_completion_receipts
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.lesson_completion_receipts TO authenticated;

CREATE OR REPLACE FUNCTION public.sync_lesson_completion(
    p_result_id TEXT,
    p_session_id TEXT,
    p_mission_date DATE,
    p_total_items INTEGER,
    p_completed_items INTEGER,
    p_source_revision_hash TEXT,
    p_rule_version TEXT,
    p_normalizer_version TEXT,
    p_evidence JSONB,
    p_completed_at TIMESTAMPTZ
)
RETURNS public.lesson_completion_receipts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user_id UUID := (SELECT auth.uid());
    v_existing public.lesson_completion_receipts%ROWTYPE;
    v_receipt public.lesson_completion_receipts%ROWTYPE;
    v_snapshot JSONB;
    v_attempts JSONB;
    v_distinct_item_count INTEGER;
    v_correct_item_count INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    IF p_result_id IS NULL OR btrim(p_result_id) = ''
        OR length(p_result_id) > 160
        OR p_session_id IS NULL OR btrim(p_session_id) = ''
        OR length(p_session_id) > 128 THEN
        RAISE EXCEPTION 'Invalid lesson completion identity'
            USING ERRCODE = '22023';
    END IF;
    IF p_result_id IS DISTINCT FROM p_session_id || ':completion' THEN
        RAISE EXCEPTION 'Result identity does not match the session'
            USING ERRCODE = '22023';
    END IF;
    IF p_total_items IS NULL OR p_total_items <= 0
        OR p_completed_items IS DISTINCT FROM p_total_items THEN
        RAISE EXCEPTION 'Only 100 percent completion can be synchronized'
            USING ERRCODE = '22023';
    END IF;
    IF p_source_revision_hash IS NULL
        OR length(p_source_revision_hash) NOT BETWEEN 16 AND 128
        OR p_rule_version IS NULL
        OR length(p_rule_version) NOT BETWEEN 1 AND 64
        OR p_normalizer_version IS NULL
        OR length(p_normalizer_version) NOT BETWEEN 1 AND 64
        OR p_completed_at IS NULL THEN
        RAISE EXCEPTION 'Invalid lesson completion metadata'
            USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM public.daily_missions AS mission
        WHERE mission.user_id = v_user_id
          AND mission.mission_date = p_mission_date
    ) THEN
        RAISE EXCEPTION 'Daily mission not found' USING ERRCODE = 'P0002';
    END IF;
    IF p_evidence IS NULL OR jsonb_typeof(p_evidence) != 'object' THEN
        RAISE EXCEPTION 'Completion evidence must be an object'
            USING ERRCODE = '22023';
    END IF;

    v_snapshot := p_evidence -> 'items';
    v_attempts := p_evidence -> 'attempts';
    IF jsonb_typeof(v_snapshot) != 'array'
        OR jsonb_array_length(v_snapshot) != p_total_items
        OR jsonb_typeof(v_attempts) != 'array'
        OR jsonb_array_length(v_attempts) = 0 THEN
        RAISE EXCEPTION 'Completion evidence has an invalid shape'
            USING ERRCODE = '22023';
    END IF;

    SELECT count(DISTINCT item ->> 'id')
    INTO v_distinct_item_count
    FROM jsonb_array_elements(v_snapshot) AS item
    WHERE jsonb_typeof(item) = 'object'
      AND nullif(btrim(item ->> 'id'), '') IS NOT NULL;

    SELECT count(DISTINCT verdict ->> 'item_id')
    INTO v_correct_item_count
    FROM jsonb_array_elements(v_attempts) AS attempt
    CROSS JOIN LATERAL jsonb_array_elements(
        CASE
            WHEN jsonb_typeof(attempt -> 'verdicts') = 'array'
                THEN attempt -> 'verdicts'
            ELSE '[]'::JSONB
        END
    ) AS verdict
    WHERE verdict ->> 'is_correct' = 'true'
      AND EXISTS (
          SELECT 1
          FROM jsonb_array_elements(v_snapshot) AS item
          WHERE item ->> 'id' = verdict ->> 'item_id'
      );

    IF v_distinct_item_count != p_total_items
        OR v_correct_item_count != p_total_items THEN
        RAISE EXCEPTION 'Completion evidence does not prove full mastery'
            USING ERRCODE = '22023';
    END IF;

    SELECT receipt.*
    INTO v_existing
    FROM public.lesson_completion_receipts AS receipt
    WHERE receipt.result_id = p_result_id
       OR (receipt.user_id = v_user_id
           AND receipt.session_id = p_session_id)
       OR (receipt.user_id = v_user_id
           AND receipt.mission_date = p_mission_date)
    LIMIT 1;

    IF NOT FOUND THEN
        INSERT INTO public.lesson_completion_receipts (
            result_id,
            session_id,
            user_id,
            mission_date,
            total_items,
            completed_items,
            source_revision_hash,
            rule_version,
            normalizer_version,
            evidence,
            completed_at
        )
        VALUES (
            p_result_id,
            p_session_id,
            v_user_id,
            p_mission_date,
            p_total_items,
            p_completed_items,
            p_source_revision_hash,
            p_rule_version,
            p_normalizer_version,
            p_evidence,
            p_completed_at
        )
        ON CONFLICT DO NOTHING
        RETURNING * INTO v_receipt;

        IF FOUND THEN
            RETURN v_receipt;
        END IF;

        -- Another request can insert the same logical receipt after the first
        -- lookup. The unique indexes serialize that race; load the winner and
        -- run the same payload comparison instead of leaking a unique error.
        SELECT receipt.*
        INTO v_existing
        FROM public.lesson_completion_receipts AS receipt
        WHERE receipt.result_id = p_result_id
           OR (receipt.user_id = v_user_id
               AND receipt.session_id = p_session_id)
           OR (receipt.user_id = v_user_id
               AND receipt.mission_date = p_mission_date)
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Lesson completion insert conflict could not be resolved'
                USING ERRCODE = '40001';
        END IF;
    END IF;

    IF v_existing.user_id IS DISTINCT FROM v_user_id
        OR v_existing.result_id IS DISTINCT FROM p_result_id
        OR v_existing.session_id IS DISTINCT FROM p_session_id
        OR v_existing.mission_date IS DISTINCT FROM p_mission_date
        OR v_existing.total_items IS DISTINCT FROM p_total_items
        OR v_existing.completed_items IS DISTINCT FROM p_completed_items
        OR v_existing.source_revision_hash IS DISTINCT FROM p_source_revision_hash
        OR v_existing.rule_version IS DISTINCT FROM p_rule_version
        OR v_existing.normalizer_version IS DISTINCT FROM p_normalizer_version
        OR v_existing.evidence IS DISTINCT FROM p_evidence
        OR v_existing.completed_at IS DISTINCT FROM p_completed_at THEN
        RAISE EXCEPTION 'Lesson completion idempotency conflict'
            USING ERRCODE = '23505';
    END IF;

    RETURN v_existing;
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_lesson_completion(
    TEXT, TEXT, DATE, INTEGER, INTEGER, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_lesson_completion(
    TEXT, TEXT, DATE, INTEGER, INTEGER, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ
) TO authenticated;
