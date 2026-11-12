-- Day/month ranking uses the same confirmed first-completion ledger score.

CREATE OR REPLACE FUNCTION public.list_period_yuzu_leaderboard(
    p_period TEXT, p_day DATE DEFAULT NULL
)
RETURNS TABLE (
    user_id UUID,
    display_name TEXT,
    avatar_url TEXT,
    period_yuzu BIGINT,
    rank_position BIGINT,
    period_start DATE
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_time_zone TEXT;
    v_day DATE;
    v_start DATE;
    v_end DATE;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;

    SELECT settings.time_zone
    INTO v_time_zone
    FROM public.user_settings AS settings
    WHERE settings.user_id = v_user;
    IF v_time_zone IS NULL THEN
        RAISE EXCEPTION 'Account timezone is required' USING ERRCODE = 'P0002';
    END IF;

    v_day := COALESCE(p_day, (statement_timestamp() AT TIME ZONE v_time_zone)::DATE);
    CASE p_period
        WHEN 'day' THEN
            v_start := v_day;
            v_end := v_day + 1;
        WHEN 'month' THEN
            v_start := date_trunc('month', v_day::TIMESTAMP)::DATE;
            v_end := (v_start + INTERVAL '1 month')::DATE;
        ELSE
            RAISE EXCEPTION 'Period must be day or month' USING ERRCODE = '22023';
    END CASE;

    RETURN QUERY
    WITH candidates AS (
        SELECT v_user AS candidate_id
        UNION
        SELECT outgoing.friend_id
        FROM public.friends AS outgoing
        JOIN public.friends AS incoming
          ON incoming.user_id = outgoing.friend_id
         AND incoming.friend_id = outgoing.user_id
         AND incoming.status = 'accepted'
        WHERE outgoing.user_id = v_user
          AND outgoing.status = 'accepted'
    ), scores AS (
        SELECT
            candidate.candidate_id,
            COALESCE(sum(ledger.weekly_yuzu), 0)::BIGINT AS score
        FROM candidates AS candidate
        LEFT JOIN public.yuzu_reward_ledger AS ledger
          ON ledger.user_id = candidate.candidate_id
         AND ledger.mission_date >= v_start
         AND ledger.mission_date < v_end
        GROUP BY candidate.candidate_id
    ), ranked AS (
        SELECT
            score.candidate_id,
            score.score,
            rank() OVER (
                ORDER BY score.score DESC
            ) AS resolved_rank
        FROM scores AS score
    )
    SELECT
        ranked.candidate_id,
        profile.display_name,
        profile.avatar_url,
        ranked.score,
        ranked.resolved_rank,
        v_start
    FROM ranked
    JOIN public.users AS profile ON profile.id = ranked.candidate_id
    ORDER BY ranked.resolved_rank, ranked.candidate_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_period_yuzu_leaderboard(TEXT, DATE)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_period_yuzu_leaderboard(TEXT, DATE)
TO authenticated;
