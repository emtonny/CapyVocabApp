BEGIN;

ALTER TABLE public.chat_conversations
    DROP CONSTRAINT chat_conversations_kind_check,
    DROP CONSTRAINT chat_conversations_shape_check;

ALTER TABLE public.chat_conversations
    ADD COLUMN social_owner_id UUID
        REFERENCES public.users(id) ON DELETE CASCADE,
    ADD COLUMN social_title TEXT,
    ADD COLUMN social_creation_request_id UUID,
    ADD CONSTRAINT chat_conversations_kind_check
        CHECK (kind IN ('direct', 'group', 'social')),
    ADD CONSTRAINT chat_conversations_social_title_check CHECK (
        social_title IS NULL
        OR (
            CHAR_LENGTH(BTRIM(social_title)) BETWEEN 1 AND 80
            AND social_title = BTRIM(social_title)
        )
    ),
    ADD CONSTRAINT chat_conversations_shape_check CHECK (
        (kind = 'direct'
         AND learning_group_id IS NULL
         AND social_owner_id IS NULL
         AND social_title IS NULL
         AND social_creation_request_id IS NULL
         AND participant_low IS NOT NULL
         AND participant_high IS NOT NULL
         AND participant_low < participant_high)
        OR
        (kind = 'group'
         AND learning_group_id IS NOT NULL
         AND social_owner_id IS NULL
         AND social_title IS NULL
         AND social_creation_request_id IS NULL
         AND participant_low IS NULL
         AND participant_high IS NULL)
        OR
        (kind = 'social'
         AND learning_group_id IS NULL
         AND social_owner_id IS NOT NULL
         AND social_title IS NOT NULL
         AND social_creation_request_id IS NOT NULL
         AND participant_low IS NULL
         AND participant_high IS NULL)
    );

CREATE UNIQUE INDEX chat_conversations_social_request_key
ON public.chat_conversations(social_owner_id, social_creation_request_id)
WHERE kind = 'social';

CREATE OR REPLACE FUNCTION private.guard_chat_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    v_kind TEXT;
    v_group_id UUID;
    v_social_owner UUID;
    v_participant_low UUID;
    v_participant_high UUID;
    v_membership_status TEXT;
BEGIN
    SELECT c.kind, c.learning_group_id, c.social_owner_id,
           c.participant_low, c.participant_high
    INTO v_kind, v_group_id, v_social_owner,
         v_participant_low, v_participant_high
    FROM public.chat_conversations AS c
    WHERE c.id = NEW.conversation_id;

    IF v_kind = 'direct' THEN
        IF NEW.user_id NOT IN (v_participant_low, v_participant_high) THEN
            RAISE EXCEPTION 'Direct chat only permits its two participants'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_kind = 'group' THEN
        SELECT m.status INTO v_membership_status
        FROM public.learning_group_members AS m
        WHERE m.group_id = v_group_id AND m.user_id = NEW.user_id;
        IF v_membership_status IS NULL
           OR ((NEW.left_at IS NULL) <> (v_membership_status = 'active')) THEN
            RAISE EXCEPTION 'Group chat membership must match learning group membership'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_kind = 'social' THEN
        IF v_social_owner IS NULL
           OR NOT EXISTS (
               SELECT 1 FROM public.users AS u WHERE u.id = NEW.user_id
           ) THEN
            RAISE EXCEPTION 'Invalid social group member'
                USING ERRCODE = '22023';
        END IF;
        IF TG_OP = 'INSERT'
           AND NEW.left_at IS NULL
           AND (
               SELECT COUNT(*) FROM public.chat_members AS m
               WHERE m.conversation_id = NEW.conversation_id
                 AND m.left_at IS NULL
           ) >= 20 THEN
            RAISE EXCEPTION 'Social group member limit reached'
                USING ERRCODE = '22023';
        END IF;
    ELSE
        RAISE EXCEPTION 'Unknown chat conversation' USING ERRCODE = '22023';
    END IF;

    IF TG_OP = 'UPDATE'
       AND (NEW.conversation_id <> OLD.conversation_id
            OR NEW.user_id <> OLD.user_id) THEN
        RAISE EXCEPTION 'Membership identity is immutable'
            USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.is_active_chat_member(p_conversation UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT COALESCE((
        SELECT CASE c.kind
            WHEN 'direct' THEN EXISTS (
                SELECT 1 FROM public.chat_members AS m
                WHERE m.conversation_id = c.id
                  AND m.user_id = (SELECT auth.uid())
                  AND m.left_at IS NULL
            )
            WHEN 'group' THEN EXISTS (
                SELECT 1 FROM public.learning_group_members AS m
                WHERE m.group_id = c.learning_group_id
                  AND m.user_id = (SELECT auth.uid())
                  AND m.status = 'active'
            )
            WHEN 'social' THEN EXISTS (
                SELECT 1 FROM public.chat_members AS m
                WHERE m.conversation_id = c.id
                  AND m.user_id = (SELECT auth.uid())
                  AND m.left_at IS NULL
            )
            ELSE FALSE
        END
        FROM public.chat_conversations AS c
        WHERE c.id = p_conversation
    ), FALSE);
$$;

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
                private.is_active_chat_member(c.id)
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

CREATE FUNCTION public.create_social_chat_group(
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
        kind, social_owner_id, social_title, social_creation_request_id
    ) VALUES (
        'social', v_user, v_title, p_request_id
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

CREATE FUNCTION public.list_my_social_chat_groups()
RETURNS TABLE (
    conversation_id UUID,
    title TEXT,
    owner_user_id UUID,
    member_count INTEGER
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
           COUNT(active_member.user_id)::INTEGER
    FROM public.chat_conversations AS c
    JOIN public.chat_members AS owner_membership
      ON owner_membership.conversation_id = c.id
     AND owner_membership.user_id = v_user
     AND owner_membership.left_at IS NULL
    JOIN public.chat_members AS active_member
      ON active_member.conversation_id = c.id
     AND active_member.left_at IS NULL
    WHERE c.kind = 'social'
    GROUP BY c.id, c.social_title, c.social_owner_id
    ORDER BY c.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_chat_translation(
    p_translator_version TEXT
)
RETURNS TABLE (
    translation_id UUID,
    claim_token UUID,
    raw_text TEXT,
    source_language_code TEXT,
    target_language_code TEXT,
    provider TEXT,
    model TEXT,
    prompt_version TEXT,
    translator_version TEXT,
    attempt_count INTEGER,
    lease_expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_job public.chat_translations%ROWTYPE;
    v_source_language TEXT;
    v_token UUID;
BEGIN
    IF p_translator_version IS DISTINCT FROM 'chat-translate-v3' THEN
        RAISE EXCEPTION 'Unsupported chat translator version'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1 FROM private.chat_translation_provider_state AS s
        WHERE s.translator_version = p_translator_version
          AND s.open_until > v_now
    ) THEN
        RETURN;
    END IF;

    SELECT t.* INTO v_job
    FROM public.chat_translations AS t
    WHERE t.translator_version = p_translator_version
      AND (
          t.status = 'queued'
          OR (t.status = 'failed'
              AND t.next_attempt_at IS NOT NULL
              AND t.next_attempt_at <= v_now)
          OR (t.status = 'processing' AND t.lease_expires_at <= v_now)
      )
    ORDER BY COALESCE(t.next_attempt_at, t.lease_expires_at, t.created_at),
             t.created_at, t.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_job.attempt_count >= 4 THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'RETRY_EXHAUSTED',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    SELECT m.source_language_code INTO v_source_language
    FROM public.chat_operational_messages AS m
    WHERE m.id = v_job.message_id;

    IF v_source_language IS NULL
       OR (v_source_language = 'vi' AND v_job.target_language_code <> 'en')
       OR (v_source_language = 'en' AND v_job.target_language_code <> 'vi')
       OR v_source_language NOT IN ('vi', 'en') THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'UNSUPPORTED_LANGUAGE',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    IF v_job.provider IS DISTINCT FROM 'gemini'
       OR v_job.model IS DISTINCT FROM 'gemini-3-flash-preview'
       OR v_job.prompt_version IS DISTINCT FROM 'chat-translate-p3' THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'POLICY_MISMATCH',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.chat_operational_messages AS m
        JOIN public.chat_conversations AS c ON c.id = m.conversation_id
        WHERE m.id = v_job.message_id
          AND m.deleted_at IS NULL
          AND m.moderation_state = 'visible'
          AND (
              (c.kind = 'direct' AND (
                  SELECT COUNT(*) FROM public.chat_members AS cm
                  WHERE cm.conversation_id = c.id AND cm.left_at IS NULL
              ) = 2)
              OR c.kind IN ('group', 'social')
          )
    ) THEN
        UPDATE public.chat_translations AS t
        SET status = 'failed', error_code = 'MESSAGE_INELIGIBLE',
            next_attempt_at = NULL, claim_token = NULL,
            lease_expires_at = NULL, updated_at = v_now
        WHERE t.id = v_job.id;
        RETURN;
    END IF;

    v_token := gen_random_uuid();
    UPDATE public.chat_translations AS t
    SET status = 'processing', attempt_count = t.attempt_count + 1,
        claim_token = v_token,
        lease_expires_at = v_now + INTERVAL '60 seconds',
        last_attempt_at = v_now, next_attempt_at = NULL,
        error_code = NULL, updated_at = v_now
    WHERE t.id = v_job.id;

    RETURN QUERY
    SELECT t.id, t.claim_token, m.raw_text, m.source_language_code,
           t.target_language_code, t.provider, t.model, t.prompt_version,
           t.translator_version, t.attempt_count, t.lease_expires_at
    FROM public.chat_translations AS t
    JOIN public.chat_operational_messages AS m ON m.id = t.message_id
    WHERE t.id = v_job.id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_social_chat_group(TEXT, UUID[], UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_my_social_chat_groups()
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_social_chat_group(TEXT, UUID[], UUID),
    public.list_my_social_chat_groups()
TO authenticated;

COMMENT ON COLUMN public.chat_conversations.social_owner_id IS
'Creator of a fixed-membership social chat group; never grants learning-group privileges.';
COMMENT ON FUNCTION public.create_social_chat_group(TEXT, UUID[], UUID) IS
'Creates an idempotent fixed-membership social chat for mutually accepted friends; no learning progress access.';

COMMIT;
