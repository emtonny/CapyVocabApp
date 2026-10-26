-- Total ranks the current wallet; periods rank confirmed earnings, including
-- replay rewards, by settlement time in the requesting account's timezone.
CREATE OR REPLACE FUNCTION public.list_period_yuzu_leaderboard(
    p_period TEXT, p_day DATE DEFAULT NULL
)
RETURNS TABLE (
    user_id UUID, display_name TEXT, avatar_url TEXT,
    period_yuzu BIGINT, rank_position BIGINT, period_start DATE
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
    v_from TIMESTAMPTZ;
    v_until TIMESTAMPTZ;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
    END IF;
    -- Support the existing settings schema without a timezone column.
    SELECT to_jsonb(settings) ->> 'time_zone' INTO v_time_zone
    FROM public.user_settings AS settings WHERE settings.user_id = v_user;
    v_time_zone := COALESCE(NULLIF(v_time_zone, ''), 'Asia/Ho_Chi_Minh');
    v_day := COALESCE(p_day, (statement_timestamp() AT TIME ZONE v_time_zone)::DATE);
    CASE p_period
        WHEN 'total' THEN v_start := NULL; v_end := NULL;
        WHEN 'day' THEN v_start := v_day; v_end := v_day + 1;
        WHEN 'week' THEN
            v_start := v_day - (EXTRACT(ISODOW FROM v_day)::INTEGER - 1);
            v_end := v_start + 7;
        WHEN 'month' THEN
            v_start := date_trunc('month', v_day::TIMESTAMP)::DATE;
            v_end := (v_start + INTERVAL '1 month')::DATE;
        ELSE
            RAISE EXCEPTION 'Period must be total, day, week or month'
                USING ERRCODE = '22023';
    END CASE;
    v_from := v_start::TIMESTAMP AT TIME ZONE v_time_zone;
    v_until := v_end::TIMESTAMP AT TIME ZONE v_time_zone;
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
        WHERE outgoing.user_id = v_user AND outgoing.status = 'accepted'
    ), scores AS (
        SELECT candidate.candidate_id,
            CASE WHEN p_period = 'total' THEN profile.total_coins::BIGINT
                 ELSE COALESCE(sum(ledger.wallet_yuzu), 0)::BIGINT END AS score
        FROM candidates AS candidate
        JOIN public.users AS profile ON profile.id = candidate.candidate_id
        LEFT JOIN public.yuzu_reward_ledger AS ledger
          ON p_period <> 'total' AND ledger.user_id = candidate.candidate_id
         AND ledger.created_at >= v_from AND ledger.created_at < v_until
        GROUP BY candidate.candidate_id, profile.total_coins
    ), ranked AS (
        SELECT scores.candidate_id, scores.score,
            rank() OVER (ORDER BY scores.score DESC) AS resolved_rank
        FROM scores
    )
    SELECT ranked.candidate_id, profile.display_name, profile.avatar_url,
        ranked.score, ranked.resolved_rank, v_start
    FROM ranked JOIN public.users AS profile ON profile.id = ranked.candidate_id
    ORDER BY ranked.resolved_rank, ranked.candidate_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.list_period_yuzu_leaderboard(TEXT, DATE)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_period_yuzu_leaderboard(TEXT, DATE)
TO authenticated;
;
