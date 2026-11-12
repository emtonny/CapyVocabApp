-- H5: server-authoritative Yuzu, weekly-Yuzu and streak settlement.
-- Late completion window is the already-frozen mission next_day_ends_at (24h).
-- Late completion never restores streak. A rewarded replay uses floor(first/3).

ALTER TABLE public.lesson_completion_receipts
    DROP CONSTRAINT IF EXISTS lesson_completion_receipts_user_id_mission_date_key;

ALTER TABLE public.lesson_completion_receipts
    ADD COLUMN completion_ordinal INTEGER,
    ADD COLUMN reward_timing TEXT CHECK (
        reward_timing IN ('on_time', 'late', 'expired')
    ),
    ADD COLUMN weekly_yuzu INTEGER CHECK (
        weekly_yuzu IS NULL OR weekly_yuzu >= 0
    );

UPDATE public.lesson_completion_receipts
SET completion_ordinal = 1
WHERE completion_ordinal IS NULL;

ALTER TABLE public.lesson_completion_receipts
    ALTER COLUMN completion_ordinal SET NOT NULL,
    ADD CONSTRAINT lesson_completion_receipts_ordinal_check CHECK (
        completion_ordinal BETWEEN 1 AND 3
    ),
    ADD CONSTRAINT lesson_completion_receipts_owner_day_ordinal_key
        UNIQUE (user_id, mission_date, completion_ordinal);

CREATE TABLE public.yuzu_reward_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id TEXT NOT NULL UNIQUE
        REFERENCES public.lesson_completion_receipts(result_id)
        ON DELETE CASCADE,
    user_id UUID NOT NULL
        REFERENCES public.users(id) ON DELETE CASCADE,
    mission_date DATE NOT NULL,
    completion_ordinal INTEGER NOT NULL CHECK (
        completion_ordinal BETWEEN 1 AND 3
    ),
    reward_timing TEXT NOT NULL CHECK (
        reward_timing IN ('on_time', 'late', 'expired')
    ),
    wallet_yuzu INTEGER NOT NULL CHECK (wallet_yuzu >= 0),
    weekly_yuzu INTEGER NOT NULL CHECK (weekly_yuzu >= 0),
    week_start DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT statement_timestamp(),
    UNIQUE (user_id, mission_date, completion_ordinal),
    CHECK (completion_ordinal = 1 OR weekly_yuzu = 0)
);

COMMENT ON TABLE public.yuzu_reward_ledger IS
    'Immutable H5 settlement ledger. Wallet and weekly amounts are distinct.';

CREATE INDEX idx_yuzu_reward_ledger_week_rank
ON public.yuzu_reward_ledger(week_start, weekly_yuzu DESC, user_id);

CREATE TABLE public.lesson_streak_days (
    user_id UUID NOT NULL
        REFERENCES public.users(id) ON DELETE CASCADE,
    mission_date DATE NOT NULL,
    receipt_id TEXT NOT NULL UNIQUE
        REFERENCES public.lesson_completion_receipts(result_id)
        ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT statement_timestamp(),
    PRIMARY KEY (user_id, mission_date)
);

CREATE OR REPLACE FUNCTION private.reject_reward_ledger_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
    RAISE EXCEPTION 'reward ledger rows are immutable'
        USING ERRCODE = '55000';
END;
$function$;

REVOKE ALL ON FUNCTION private.reject_reward_ledger_mutation()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_yuzu_reward_ledger_immutable
BEFORE UPDATE ON public.yuzu_reward_ledger
FOR EACH ROW EXECUTE FUNCTION private.reject_reward_ledger_mutation();

CREATE TRIGGER trg_lesson_streak_days_immutable
BEFORE UPDATE ON public.lesson_streak_days
FOR EACH ROW EXECUTE FUNCTION private.reject_reward_ledger_mutation();

ALTER TABLE public.yuzu_reward_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_streak_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read their own Yuzu reward ledger"
ON public.yuzu_reward_ledger
FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users read their own lesson streak days"
ON public.lesson_streak_days
FOR SELECT TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.yuzu_reward_ledger, public.lesson_streak_days
FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.yuzu_reward_ledger, public.lesson_streak_days
TO authenticated;

CREATE OR REPLACE FUNCTION private.daily_lesson_reward_yuzu(
    p_total_items INTEGER,
    p_target_words INTEGER,
    p_timing TEXT
)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
STRICT
SECURITY INVOKER
SET search_path = ''
AS $function$
    SELECT CASE
        WHEN p_total_items < p_target_words OR p_timing = 'expired' THEN 0
        WHEN p_total_items >= p_target_words * 2 THEN
            CASE WHEN p_timing = 'late' THEN 100 ELSE 150 END
        WHEN p_total_items * 2 >= p_target_words * 3 THEN
            CASE WHEN p_timing = 'late' THEN 87 ELSE 130 END
        ELSE
            CASE WHEN p_timing = 'late' THEN 67 ELSE 100 END
    END;
$function$;

REVOKE ALL ON FUNCTION private.daily_lesson_reward_yuzu(
    INTEGER, INTEGER, TEXT
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.recompute_lesson_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_day DATE;
    v_streak INTEGER := 0;
BEGIN
    SELECT max(day.mission_date)
    INTO v_day
    FROM public.lesson_streak_days AS day
    WHERE day.user_id = p_user_id;

    WHILE v_day IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.lesson_streak_days AS day
        WHERE day.user_id = p_user_id
          AND day.mission_date = v_day
    ) LOOP
        v_streak := v_streak + 1;
        v_day := v_day - 1;
    END LOOP;

    UPDATE public.users
    SET streak_days = v_streak,
        updated_at = statement_timestamp()
    WHERE id = p_user_id;

    RETURN v_streak;
END;
$function$;

REVOKE ALL ON FUNCTION private.recompute_lesson_streak(UUID)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.refresh_lesson_streak_on_new_mission()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_latest DATE;
BEGIN
    SELECT max(day.mission_date)
    INTO v_latest
    FROM public.lesson_streak_days AS day
    WHERE day.user_id = NEW.user_id;

    IF v_latest IS NULL OR NEW.mission_date > v_latest + 1 THEN
        UPDATE public.users
        SET streak_days = 0,
            updated_at = statement_timestamp()
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.refresh_lesson_streak_on_new_mission()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_refresh_lesson_streak_on_new_mission
AFTER INSERT ON public.daily_missions
FOR EACH ROW EXECUTE FUNCTION private.refresh_lesson_streak_on_new_mission();

CREATE OR REPLACE FUNCTION private.settle_lesson_completion(
    p_result_id TEXT
)
RETURNS public.lesson_completion_receipts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_receipt public.lesson_completion_receipts%ROWTYPE;
    v_mission public.daily_missions%ROWTYPE;
    v_timing TEXT;
    v_wallet_yuzu INTEGER := 0;
    v_weekly_yuzu INTEGER := 0;
    v_first_yuzu INTEGER := 0;
    v_week_start DATE;
BEGIN
    SELECT receipt.*
    INTO STRICT v_receipt
    FROM public.lesson_completion_receipts AS receipt
    WHERE receipt.result_id = p_result_id
    FOR UPDATE;

    IF v_receipt.reward_status <> 'pending' THEN
        RETURN v_receipt;
    END IF;

    SELECT mission.*
    INTO STRICT v_mission
    FROM public.daily_missions AS mission
    WHERE mission.user_id = v_receipt.user_id
      AND mission.mission_date = v_receipt.mission_date;

    v_timing := CASE
        WHEN v_receipt.completed_at >= v_mission.starts_at
         AND v_receipt.completed_at <= v_mission.ends_at THEN 'on_time'
        WHEN v_receipt.completed_at > v_mission.ends_at
         AND v_receipt.completed_at <= v_mission.next_day_ends_at THEN 'late'
        ELSE 'expired'
    END;

    IF v_receipt.completion_ordinal = 1 THEN
        v_wallet_yuzu := private.daily_lesson_reward_yuzu(
            v_receipt.total_items,
            v_mission.target_words,
            v_timing
        );
        v_weekly_yuzu := v_wallet_yuzu;
    ELSIF v_receipt.completion_ordinal = 2 AND v_timing <> 'expired' THEN
        SELECT ledger.wallet_yuzu
        INTO v_first_yuzu
        FROM public.yuzu_reward_ledger AS ledger
        WHERE ledger.user_id = v_receipt.user_id
          AND ledger.mission_date = v_receipt.mission_date
          AND ledger.completion_ordinal = 1;
        v_wallet_yuzu := COALESCE(v_first_yuzu, 0) / 3;
    END IF;

    v_week_start := v_receipt.mission_date
        - (EXTRACT(ISODOW FROM v_receipt.mission_date)::INTEGER - 1);

    INSERT INTO public.yuzu_reward_ledger (
        receipt_id,
        user_id,
        mission_date,
        completion_ordinal,
        reward_timing,
        wallet_yuzu,
        weekly_yuzu,
        week_start
    ) VALUES (
        v_receipt.result_id,
        v_receipt.user_id,
        v_receipt.mission_date,
        v_receipt.completion_ordinal,
        v_timing,
        v_wallet_yuzu,
        v_weekly_yuzu,
        v_week_start
    ) ON CONFLICT (receipt_id) DO NOTHING;

    IF v_wallet_yuzu > 0 THEN
        UPDATE public.users
        SET total_coins = total_coins + v_wallet_yuzu,
            updated_at = statement_timestamp()
        WHERE id = v_receipt.user_id;
    END IF;

    IF v_receipt.completion_ordinal = 1
       AND v_timing = 'on_time'
       AND v_wallet_yuzu > 0 THEN
        INSERT INTO public.lesson_streak_days (
            user_id, mission_date, receipt_id
        ) VALUES (
            v_receipt.user_id, v_receipt.mission_date, v_receipt.result_id
        ) ON CONFLICT (user_id, mission_date) DO NOTHING;
        PERFORM private.recompute_lesson_streak(v_receipt.user_id);
    END IF;

    UPDATE public.lesson_completion_receipts
    SET reward_status = CASE
            WHEN v_wallet_yuzu > 0 THEN 'awarded'
            ELSE 'rejected'
        END,
        reward_yuzu = CASE
            WHEN v_wallet_yuzu > 0 THEN v_wallet_yuzu
            ELSE NULL
        END,
        rewarded_at = CASE
            WHEN v_wallet_yuzu > 0 THEN statement_timestamp()
            ELSE NULL
        END,
        reward_timing = v_timing,
        weekly_yuzu = v_weekly_yuzu
    WHERE result_id = v_receipt.result_id
    RETURNING * INTO v_receipt;

    RETURN v_receipt;
END;
$function$;

REVOKE ALL ON FUNCTION private.settle_lesson_completion(TEXT)
FROM PUBLIC, anon, authenticated;

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
    v_mission public.daily_missions%ROWTYPE;
    v_snapshot JSONB;
    v_attempts JSONB;
    v_distinct_item_count INTEGER;
    v_correct_item_count INTEGER;
    v_completion_ordinal INTEGER;
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

    SELECT mission.*
    INTO v_mission
    FROM public.daily_missions AS mission
    WHERE mission.user_id = v_user_id
      AND mission.mission_date = p_mission_date
    FOR UPDATE;
    IF NOT FOUND THEN
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
    LIMIT 1;

    IF FOUND THEN
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
    END IF;

    SELECT COALESCE(max(receipt.completion_ordinal), 0) + 1
    INTO v_completion_ordinal
    FROM public.lesson_completion_receipts AS receipt
    WHERE receipt.user_id = v_user_id
      AND receipt.mission_date = p_mission_date;

    IF v_completion_ordinal > 3 THEN
        RAISE EXCEPTION 'Lesson completion reward limit reached'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.lesson_completion_receipts (
        result_id, session_id, user_id, mission_date,
        total_items, completed_items, source_revision_hash,
        rule_version, normalizer_version, evidence, completed_at,
        completion_ordinal
    ) VALUES (
        p_result_id, p_session_id, v_user_id, p_mission_date,
        p_total_items, p_completed_items, p_source_revision_hash,
        p_rule_version, p_normalizer_version, p_evidence, p_completed_at,
        v_completion_ordinal
    )
    RETURNING * INTO v_receipt;

    RETURN private.settle_lesson_completion(v_receipt.result_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.sync_lesson_completion(
    TEXT, TEXT, DATE, INTEGER, INTEGER, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_lesson_completion(
    TEXT, TEXT, DATE, INTEGER, INTEGER, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ
) TO authenticated;

-- Settle receipts accepted during H4 before H5 was deployed.
SELECT private.settle_lesson_completion(receipt.result_id)
FROM public.lesson_completion_receipts AS receipt
WHERE receipt.reward_status = 'pending'
ORDER BY receipt.user_id, receipt.mission_date, receipt.completion_ordinal;
