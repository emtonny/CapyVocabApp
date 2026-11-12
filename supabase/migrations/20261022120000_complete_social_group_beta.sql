BEGIN;

ALTER TABLE public.chat_conversations
    ADD COLUMN social_status TEXT;

UPDATE public.chat_conversations
SET social_status = 'active'
WHERE kind = 'social';

ALTER TABLE public.chat_conversations
    ADD CONSTRAINT chat_conversations_social_status_check CHECK (
        social_status IS NULL OR social_status IN ('active', 'closed')
    ),
    DROP CONSTRAINT chat_conversations_shape_check,
    ADD CONSTRAINT chat_conversations_shape_check CHECK (
        (kind = 'direct'
         AND learning_group_id IS NULL
         AND social_owner_id IS NULL
         AND social_title IS NULL
         AND social_creation_request_id IS NULL
         AND social_status IS NULL
         AND participant_low IS NOT NULL
         AND participant_high IS NOT NULL
         AND participant_low < participant_high)
        OR
        (kind = 'group'
         AND learning_group_id IS NOT NULL
         AND social_owner_id IS NULL
         AND social_title IS NULL
         AND social_creation_request_id IS NULL
         AND social_status IS NULL
         AND participant_low IS NULL
         AND participant_high IS NULL)
        OR
        (kind = 'social'
         AND learning_group_id IS NULL
         AND social_owner_id IS NOT NULL
         AND social_title IS NOT NULL
         AND social_creation_request_id IS NOT NULL
         AND social_status IN ('active', 'closed')
         AND participant_low IS NULL
         AND participant_high IS NULL)
    );

CREATE TABLE private.social_chat_group_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL
        REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    actor_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('rename', 'close', 'leave')),
    previous_value TEXT,
    next_value TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX social_chat_group_audit_conversation_created
ON private.social_chat_group_audit(conversation_id, created_at DESC, id DESC);

REVOKE ALL ON TABLE private.social_chat_group_audit FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.can_insert_chat_message(
    p_conversation UUID,
    p_source TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT COALESCE((
        SELECT CASE c.kind
            WHEN 'direct' THEN
                private.is_active_chat_member(c.id)
                AND (SELECT COUNT(*) FROM public.chat_members AS cm
                     WHERE cm.conversation_id = c.id
                       AND cm.left_at IS NULL) = 2
            WHEN 'group' THEN EXISTS (
                SELECT 1
                FROM public.learning_groups AS g
                JOIN public.learning_group_members AS m
                  ON m.group_id = g.id
                WHERE g.id = c.learning_group_id
                  AND g.status = 'active'
                  AND m.user_id = (SELECT auth.uid())
                  AND m.status = 'active'
                  AND NOT m.is_muted
            )
            WHEN 'social' THEN
                c.social_status = 'active'
                AND private.is_active_chat_member(c.id)
                AND (SELECT COUNT(*) FROM public.chat_members AS cm
                     WHERE cm.conversation_id = c.id
                       AND cm.left_at IS NULL) BETWEEN 2 AND 20
            ELSE FALSE
        END
        FROM public.chat_conversations AS c
        WHERE c.id = p_conversation
    ), FALSE)
    AND EXISTS (
        SELECT 1 FROM public.user_language_profiles AS p
        WHERE p.user_id = (SELECT auth.uid())
          AND p.native_language_code = p_source
    );
$$;

CREATE OR REPLACE FUNCTION public.create_social_chat_group(
    p_title TEXT,
    p_member_ids UUID[],
    p_request_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_members UUID[];
    v_expected UUID[];
    v_conversation UUID;
    v_stored_title TEXT;
    v_stored_members UUID[];
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL
       OR CHAR_LENGTH(v_title) NOT BETWEEN 1 AND 80
       OR p_member_ids IS NULL
       OR CARDINALITY(p_member_ids) NOT BETWEEN 1 AND 19
       OR ARRAY_POSITION(p_member_ids, NULL) IS NOT NULL
       OR v_user = ANY(p_member_ids) THEN
        RAISE EXCEPTION 'invalid_social_group' USING ERRCODE = '22023';
    END IF;

    SELECT ARRAY_AGG(member_id ORDER BY member_id)
    INTO v_members
    FROM (SELECT DISTINCT UNNEST(p_member_ids) AS member_id) AS selected;
    IF CARDINALITY(v_members) <> CARDINALITY(p_member_ids) THEN
        RAISE EXCEPTION 'invalid_social_group' USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM UNNEST(v_members) AS selected(member_id)
        WHERE NOT EXISTS (
            SELECT 1 FROM public.friends AS f
            WHERE f.user_id = v_user
              AND f.friend_id = selected.member_id
              AND f.status = 'accepted'
        ) OR NOT EXISTS (
            SELECT 1 FROM public.friends AS f
            WHERE f.user_id = selected.member_id
              AND f.friend_id = v_user
              AND f.status = 'accepted'
        )
    ) THEN
        RAISE EXCEPTION 'mutually_accepted_friends_required'
            USING ERRCODE = '42501';
    END IF;

    SELECT ARRAY_AGG(member_id ORDER BY member_id)
    INTO v_expected
    FROM (
        SELECT v_user AS member_id
        UNION ALL
        SELECT UNNEST(v_members)
    ) AS expected;
    IF (
        SELECT COUNT(*) FROM public.user_language_profiles AS p
        WHERE p.user_id = ANY(v_expected)
    ) <> CARDINALITY(v_expected) THEN
        RAISE EXCEPTION 'all_language_profiles_required'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.chat_conversations(
        kind, social_owner_id, social_title, social_creation_request_id,
        social_status
    ) VALUES (
        'social', v_user, v_title, p_request_id, 'active'
    )
    ON CONFLICT (social_owner_id, social_creation_request_id)
        WHERE kind = 'social'
    DO NOTHING;

    SELECT c.id, c.social_title
    INTO v_conversation, v_stored_title
    FROM public.chat_conversations AS c
    WHERE c.kind = 'social'
      AND c.social_owner_id = v_user
      AND c.social_creation_request_id = p_request_id
    FOR UPDATE;
    IF v_conversation IS NULL OR v_stored_title IS DISTINCT FROM v_title THEN
        RAISE EXCEPTION 'social_group_request_conflict'
            USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.chat_members(conversation_id, user_id)
    SELECT v_conversation, member_id FROM UNNEST(v_expected) AS member_id
    ON CONFLICT (conversation_id, user_id) DO NOTHING;

    SELECT ARRAY_AGG(m.user_id ORDER BY m.user_id)
    INTO v_stored_members
    FROM public.chat_members AS m
    WHERE m.conversation_id = v_conversation
      AND m.left_at IS NULL;
    IF v_stored_members IS DISTINCT FROM v_expected THEN
        RAISE EXCEPTION 'social_group_request_conflict'
            USING ERRCODE = '22023';
    END IF;
    RETURN v_conversation;
END;
$$;

DROP FUNCTION public.list_my_social_chat_groups();
CREATE FUNCTION public.list_my_social_chat_groups()
RETURNS TABLE (
    conversation_id UUID,
    title TEXT,
    owner_user_id UUID,
    member_count INTEGER,
    status TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT c.id, c.social_title, c.social_owner_id,
           COUNT(active_member.user_id)::INTEGER, c.social_status
    FROM public.chat_conversations AS c
    JOIN public.chat_members AS owner_membership
      ON owner_membership.conversation_id = c.id
     AND owner_membership.user_id = v_user
     AND owner_membership.left_at IS NULL
    JOIN public.chat_members AS active_member
      ON active_member.conversation_id = c.id
     AND active_member.left_at IS NULL
    WHERE c.kind = 'social'
    GROUP BY c.id, c.social_title, c.social_owner_id, c.social_status
    ORDER BY c.id;
END;
$$;

CREATE FUNCTION public.list_social_chat_group_members(
    p_conversation_ids UUID[]
)
RETURNS TABLE (
    conversation_id UUID,
    user_id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    is_owner BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_ids UUID[];
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_conversation_ids IS NULL
       OR CARDINALITY(p_conversation_ids) NOT BETWEEN 1 AND 50
       OR ARRAY_POSITION(p_conversation_ids, NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'invalid_social_group_inventory'
            USING ERRCODE = '22023';
    END IF;
    SELECT ARRAY_AGG(id ORDER BY id)
    INTO v_ids
    FROM (SELECT DISTINCT UNNEST(p_conversation_ids) AS id) AS requested;
    IF CARDINALITY(v_ids) <> CARDINALITY(p_conversation_ids) THEN
        RAISE EXCEPTION 'invalid_social_group_inventory'
            USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT c.id, member.user_id, u.display_name, u.username, u.avatar_url,
           member.user_id = c.social_owner_id
    FROM public.chat_conversations AS c
    JOIN public.chat_members AS requester
      ON requester.conversation_id = c.id
     AND requester.user_id = v_user
     AND requester.left_at IS NULL
    JOIN public.chat_members AS member
      ON member.conversation_id = c.id
     AND member.left_at IS NULL
    JOIN public.users AS u ON u.id = member.user_id
    WHERE c.kind = 'social' AND c.id = ANY(v_ids)
    ORDER BY c.id, (member.user_id = c.social_owner_id) DESC,
             LOWER(COALESCE(NULLIF(BTRIM(u.display_name), ''), u.username)),
             member.user_id;
END;
$$;

CREATE FUNCTION public.rename_social_chat_group(
    p_conversation_id UUID,
    p_title TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_owner UUID;
    v_status TEXT;
    v_previous TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_conversation_id IS NULL OR CHAR_LENGTH(v_title) NOT BETWEEN 1 AND 80 THEN
        RAISE EXCEPTION 'invalid_social_group' USING ERRCODE = '22023';
    END IF;
    SELECT c.social_owner_id, c.social_status, c.social_title
    INTO v_owner, v_status, v_previous
    FROM public.chat_conversations AS c
    WHERE c.id = p_conversation_id AND c.kind = 'social'
    FOR UPDATE;
    IF v_owner IS DISTINCT FROM v_user THEN
        RAISE EXCEPTION 'social_group_owner_required' USING ERRCODE = '42501';
    END IF;
    IF v_status IS DISTINCT FROM 'active' THEN
        RAISE EXCEPTION 'social_group_closed' USING ERRCODE = '42501';
    END IF;
    IF v_previous IS DISTINCT FROM v_title THEN
        UPDATE public.chat_conversations
        SET social_title = v_title
        WHERE id = p_conversation_id;
        INSERT INTO private.social_chat_group_audit(
            conversation_id, actor_user_id, action, previous_value, next_value
        ) VALUES (
            p_conversation_id, v_user, 'rename', v_previous, v_title
        );
    END IF;
    RETURN p_conversation_id;
END;
$$;

CREATE FUNCTION public.close_social_chat_group(p_conversation_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_owner UUID;
    v_status TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    SELECT c.social_owner_id, c.social_status
    INTO v_owner, v_status
    FROM public.chat_conversations AS c
    WHERE c.id = p_conversation_id AND c.kind = 'social'
    FOR UPDATE;
    IF v_owner IS DISTINCT FROM v_user THEN
        RAISE EXCEPTION 'social_group_owner_required' USING ERRCODE = '42501';
    END IF;
    IF v_status = 'active' THEN
        UPDATE public.chat_conversations
        SET social_status = 'closed'
        WHERE id = p_conversation_id;
        INSERT INTO private.social_chat_group_audit(
            conversation_id, actor_user_id, action, previous_value, next_value
        ) VALUES (
            p_conversation_id, v_user, 'close', 'active', 'closed'
        );
    END IF;
    RETURN p_conversation_id;
END;
$$;

CREATE FUNCTION public.leave_social_chat_group(p_conversation_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_owner UUID;
    v_left_at TIMESTAMPTZ;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    SELECT c.social_owner_id
    INTO v_owner
    FROM public.chat_conversations AS c
    WHERE c.id = p_conversation_id AND c.kind = 'social';
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'social_group_membership_required' USING ERRCODE = '42501';
    END IF;
    IF v_owner = v_user THEN
        RAISE EXCEPTION 'social_group_owner_must_close' USING ERRCODE = '42501';
    END IF;
    SELECT m.left_at
    INTO v_left_at
    FROM public.chat_members AS m
    WHERE m.conversation_id = p_conversation_id AND m.user_id = v_user
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'social_group_membership_required' USING ERRCODE = '42501';
    END IF;
    IF v_left_at IS NULL THEN
        UPDATE public.chat_members
        SET left_at = clock_timestamp()
        WHERE conversation_id = p_conversation_id AND user_id = v_user;
        INSERT INTO private.social_chat_group_audit(
            conversation_id, actor_user_id, action, previous_value, next_value
        ) VALUES (
            p_conversation_id, v_user, 'leave', 'active', 'left'
        );
    END IF;
    RETURN p_conversation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_social_chat_group(TEXT, UUID[], UUID),
    public.list_my_social_chat_groups(),
    public.list_social_chat_group_members(UUID[]),
    public.rename_social_chat_group(UUID, TEXT),
    public.close_social_chat_group(UUID),
    public.leave_social_chat_group(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_social_chat_group(TEXT, UUID[], UUID),
    public.list_my_social_chat_groups(),
    public.list_social_chat_group_members(UUID[]),
    public.rename_social_chat_group(UUID, TEXT),
    public.close_social_chat_group(UUID),
    public.leave_social_chat_group(UUID)
TO authenticated;

COMMENT ON COLUMN public.chat_conversations.social_status IS
'Lifecycle for social chat groups. Closed groups retain readable history and reject new messages.';
COMMENT ON FUNCTION public.list_social_chat_group_members(UUID[]) IS
'Returns the approved public profile projection only for active co-members of requested social groups.';
COMMENT ON FUNCTION public.leave_social_chat_group(UUID) IS
'Lets a non-owner leave a social group idempotently and immediately lose RLS visibility.';

COMMIT;
