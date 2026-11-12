BEGIN;

CREATE FUNCTION public.get_learning_group_invite_status(p_group_id UUID)
RETURNS TABLE (
    has_active_invite BOOLEAN,
    expires_at TIMESTAMPTZ,
    use_count INTEGER,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL
       OR p_group_id IS NULL
       OR NOT private.is_verified_teacher(v_user)
       OR NOT private.is_learning_group_owner_member(p_group_id, v_user) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        COALESCE(i.expires_at > NOW(), FALSE),
        i.expires_at,
        i.use_count,
        i.last_used_at,
        i.created_at
    FROM (SELECT TRUE) AS seed
    LEFT JOIN LATERAL (
        SELECT invite.expires_at, invite.use_count,
               invite.last_used_at, invite.created_at
        FROM public.learning_group_invites AS invite
        WHERE invite.group_id = p_group_id
          AND invite.revoked_at IS NULL
        ORDER BY invite.created_at DESC, invite.id DESC
        LIMIT 1
    ) AS i ON TRUE;
END;
$$;

CREATE FUNCTION public.list_learning_group_moderation_events(
    p_group_id UUID,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    event_id BIGINT,
    actor_user_id UUID,
    actor_display_name TEXT,
    target_user_id UUID,
    target_display_name TEXT,
    target_message_id UUID,
    action TEXT,
    reason_code TEXT,
    occurred_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 200 THEN
        RAISE EXCEPTION 'invalid_moderation_event_limit' USING ERRCODE = '22023';
    END IF;
    IF v_user IS NULL
       OR p_group_id IS NULL
       OR NOT private.is_verified_teacher(v_user)
       OR NOT private.is_learning_group_owner_member(p_group_id, v_user) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT event.id, event.actor_user_id, actor.display_name,
           event.target_user_id, target.display_name,
           event.target_message_id, event.action, event.reason_code,
           event.occurred_at
    FROM private.learning_group_moderation_events AS event
    JOIN public.users AS actor ON actor.id = event.actor_user_id
    LEFT JOIN public.users AS target ON target.id = event.target_user_id
    WHERE event.group_id = p_group_id
    ORDER BY event.occurred_at DESC, event.id DESC
    LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.get_learning_group_invite_status(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_learning_group_moderation_events(UUID, INTEGER)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_learning_group_invite_status(UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_learning_group_moderation_events(UUID, INTEGER)
TO authenticated;

COMMENT ON FUNCTION public.get_learning_group_invite_status(UUID) IS
'GT4 owner-only invite metadata projection; never returns token or token hash.';
COMMENT ON FUNCTION public.list_learning_group_moderation_events(UUID, INTEGER) IS
'GT4 owner-only bounded projection of private learning-group moderation events.';

COMMIT;
