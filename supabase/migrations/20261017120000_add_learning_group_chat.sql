BEGIN;

ALTER TABLE public.chat_conversations
    DROP CONSTRAINT chat_conversations_kind_check,
    DROP CONSTRAINT chat_conversations_check;

ALTER TABLE public.chat_conversations
    ALTER COLUMN participant_low DROP NOT NULL,
    ALTER COLUMN participant_high DROP NOT NULL,
    ADD COLUMN learning_group_id UUID
        REFERENCES public.learning_groups(id) ON DELETE CASCADE,
    ADD CONSTRAINT chat_conversations_kind_check
        CHECK (kind IN ('direct', 'group')),
    ADD CONSTRAINT chat_conversations_shape_check CHECK (
        (kind = 'direct'
         AND learning_group_id IS NULL
         AND participant_low IS NOT NULL
         AND participant_high IS NOT NULL
         AND participant_low < participant_high)
        OR
        (kind = 'group'
         AND learning_group_id IS NOT NULL
         AND participant_low IS NULL
         AND participant_high IS NULL)
    ),
    ADD CONSTRAINT chat_conversations_learning_group_key
        UNIQUE (learning_group_id);

CREATE OR REPLACE FUNCTION private.guard_chat_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    v_kind TEXT;
    v_group_id UUID;
    v_participant_low UUID;
    v_participant_high UUID;
    v_membership_status TEXT;
BEGIN
    SELECT c.kind, c.learning_group_id, c.participant_low, c.participant_high
    INTO v_kind, v_group_id, v_participant_low, v_participant_high
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

INSERT INTO public.chat_conversations(kind, learning_group_id, created_at)
SELECT 'group', g.id, g.created_at
FROM public.learning_groups AS g
ON CONFLICT (learning_group_id) DO NOTHING;

INSERT INTO public.chat_members(conversation_id, user_id, joined_at)
SELECT c.id, m.user_id, COALESCE(m.joined_at, m.requested_at)
FROM public.learning_group_members AS m
JOIN public.chat_conversations AS c ON c.learning_group_id = m.group_id
WHERE m.status = 'active'
ON CONFLICT (conversation_id, user_id) DO UPDATE
SET joined_at = LEAST(public.chat_members.joined_at, EXCLUDED.joined_at),
    left_at = NULL;

CREATE FUNCTION private.create_learning_group_chat()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.chat_conversations(kind, learning_group_id, created_at)
    VALUES ('group', NEW.id, NEW.created_at)
    ON CONFLICT (learning_group_id) DO NOTHING;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.create_learning_group_chat()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER create_learning_group_chat
AFTER INSERT ON public.learning_groups
FOR EACH ROW EXECUTE FUNCTION private.create_learning_group_chat();

CREATE FUNCTION private.sync_learning_group_chat_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_conversation UUID;
BEGIN
    SELECT c.id INTO v_conversation
    FROM public.chat_conversations AS c
    WHERE c.kind = 'group' AND c.learning_group_id = NEW.group_id;
    IF v_conversation IS NULL THEN
        RAISE EXCEPTION 'Learning group chat is unavailable'
            USING ERRCODE = '55000';
    END IF;

    IF NEW.status = 'active' THEN
        INSERT INTO public.chat_members(
            conversation_id, user_id, joined_at, left_at
        ) VALUES (
            v_conversation, NEW.user_id,
            COALESCE(NEW.joined_at, NEW.requested_at), NULL
        )
        ON CONFLICT (conversation_id, user_id) DO UPDATE
        SET joined_at = LEAST(
                public.chat_members.joined_at,
                EXCLUDED.joined_at
            ),
            left_at = NULL;
    ELSIF TG_OP = 'UPDATE' AND OLD.status = 'active' THEN
        UPDATE public.chat_members
        SET left_at = COALESCE(NEW.ended_at, NOW())
        WHERE conversation_id = v_conversation
          AND user_id = NEW.user_id
          AND left_at IS NULL;
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.sync_learning_group_chat_member()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER sync_learning_group_chat_member
AFTER INSERT OR UPDATE OF status, joined_at, ended_at
ON public.learning_group_members
FOR EACH ROW EXECUTE FUNCTION private.sync_learning_group_chat_member();

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

CREATE OR REPLACE FUNCTION private.can_propose_chat_correction(
    p_message UUID,
    p_target TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT private.can_read_chat_message(p_message)
       AND EXISTS (
            SELECT 1
            FROM public.chat_operational_messages AS m
            JOIN public.chat_conversations AS conv
              ON conv.id = m.conversation_id AND conv.kind = 'direct'
            JOIN public.user_language_profiles AS p
              ON p.user_id = (SELECT auth.uid())
            WHERE m.id = p_message
              AND m.sender_id <> (SELECT auth.uid())
              AND m.source_language_code <> p_target
              AND p.native_language_code = p_target
       );
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
    IF p_translator_version IS DISTINCT FROM 'chat-translate-v2' THEN
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

    IF v_job.provider IS DISTINCT FROM 'vilao'
       OR v_job.model IS DISTINCT FROM 'gemini-3.8-flash'
       OR v_job.prompt_version IS DISTINCT FROM 'chat-translate-p2' THEN
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
              OR c.kind = 'group'
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

CREATE OR REPLACE FUNCTION private.can_create_chat_slang_annotation(
    p_message UUID,
    p_correction UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.chat_operational_messages AS m
        JOIN public.chat_conversations AS conv
          ON conv.id = m.conversation_id AND conv.kind = 'direct'
        JOIN public.chat_corrections AS c
          ON c.id = p_correction AND c.message_id = m.id
        WHERE m.id = p_message
          AND m.sender_id = (SELECT auth.uid())
          AND m.deleted_at IS NULL
          AND m.moderation_state = 'visible'
          AND c.status = 'accepted'
          AND c.accepted_by = (SELECT auth.uid())
          AND private.is_active_chat_member(m.conversation_id)
          AND (SELECT COUNT(*) FROM public.chat_members AS cm
               WHERE cm.conversation_id = m.conversation_id
                 AND cm.left_at IS NULL) = 2
    );
$$;

CREATE FUNCTION private.guard_direct_chat_learning_feature()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.chat_operational_messages AS m
        JOIN public.chat_conversations AS c ON c.id = m.conversation_id
        WHERE m.id = NEW.message_id AND c.kind = 'direct'
    ) THEN
        RAISE EXCEPTION 'Learning interaction is direct-chat only'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_direct_chat_learning_feature()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER aa_guard_direct_chat_correction
BEFORE INSERT OR UPDATE ON public.chat_corrections
FOR EACH ROW EXECUTE FUNCTION private.guard_direct_chat_learning_feature();
CREATE TRIGGER aa_guard_direct_chat_annotation
BEFORE INSERT OR UPDATE ON public.chat_slang_annotations
FOR EACH ROW EXECUTE FUNCTION private.guard_direct_chat_learning_feature();

CREATE OR REPLACE FUNCTION public.resolve_chat_correction(
    p_correction_id UUID,
    p_decision TEXT
)
RETURNS public.chat_corrections
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor UUID := (SELECT auth.uid());
    v_correction public.chat_corrections%ROWTYPE;
    v_sender UUID;
    v_conversation UUID;
BEGIN
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authenticated correction actor required'
            USING ERRCODE = '42501';
    END IF;
    IF p_correction_id IS NULL OR p_decision NOT IN ('accepted', 'rejected') THEN
        RAISE EXCEPTION 'Invalid correction decision'
            USING ERRCODE = '22023';
    END IF;

    SELECT c.* INTO v_correction
    FROM public.chat_corrections AS c
    WHERE c.id = p_correction_id
    FOR UPDATE;

    SELECT m.sender_id, m.conversation_id
    INTO v_sender, v_conversation
    FROM public.chat_operational_messages AS m
    JOIN public.chat_conversations AS conv
      ON conv.id = m.conversation_id AND conv.kind = 'direct'
    WHERE m.id = v_correction.message_id;

    IF v_correction.id IS NULL
       OR v_sender IS DISTINCT FROM v_actor
       OR NOT private.can_read_chat_message(v_correction.message_id)
       OR (SELECT COUNT(*) FROM public.chat_members AS m
           WHERE m.conversation_id = v_conversation
             AND m.left_at IS NULL) <> 2 THEN
        RAISE EXCEPTION 'Correction decision denied'
            USING ERRCODE = '42501';
    END IF;

    IF v_correction.status = p_decision THEN
        RETURN v_correction;
    END IF;
    IF v_correction.status <> 'proposed' THEN
        RAISE EXCEPTION 'Correction already has a different final decision'
            USING ERRCODE = '22023';
    END IF;

    IF p_decision = 'accepted' THEN
        UPDATE public.chat_corrections
        SET status = 'accepted', accepted_by = v_actor, accepted_at = NOW()
        WHERE id = p_correction_id
        RETURNING * INTO v_correction;
    ELSE
        UPDATE public.chat_corrections
        SET status = 'rejected', rejected_by = v_actor, rejected_at = NOW()
        WHERE id = p_correction_id
        RETURNING * INTO v_correction;
    END IF;
    RETURN v_correction;
END;
$$;

ALTER TABLE private.learning_group_moderation_events
    DROP CONSTRAINT learning_group_moderation_events_action_check,
    ADD CONSTRAINT learning_group_moderation_events_action_check CHECK (
        action IN (
            'group_created', 'group_updated', 'group_archived',
            'invite_rotated', 'invite_revoked', 'join_requested',
            'join_approved', 'join_rejected', 'member_left',
            'member_removed', 'member_muted', 'member_unmuted',
            'announcement_created', 'announcement_pinned',
            'announcement_unpinned', 'message_hidden', 'message_restored'
        )
    );

ALTER TABLE private.learning_group_moderation_events
    ADD COLUMN target_message_id UUID
        REFERENCES public.chat_operational_messages(id) ON DELETE CASCADE,
    ADD CONSTRAINT learning_group_moderation_target_message_check CHECK (
        (action IN ('message_hidden', 'message_restored'))
        = (target_message_id IS NOT NULL)
    );

CREATE FUNCTION public.moderate_learning_group_message(
    p_group_id UUID,
    p_message_id UUID,
    p_visibility TEXT,
    p_request_id UUID,
    p_reason_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor UUID := (SELECT auth.uid());
    v_state TEXT;
BEGIN
    IF v_actor IS NULL
       OR p_group_id IS NULL
       OR p_message_id IS NULL
       OR p_request_id IS NULL
       OR p_visibility NOT IN ('hidden', 'visible')
       OR (p_reason_code IS NOT NULL
           AND p_reason_code !~ '^[a-z0-9_]{1,64}$') THEN
        RAISE EXCEPTION 'Invalid group message moderation request'
            USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_learning_group_owner_member(p_group_id, v_actor)
       OR NOT private.is_verified_teacher(v_actor) THEN
        RAISE EXCEPTION 'Group owner permission required'
            USING ERRCODE = '42501';
    END IF;
    IF EXISTS (
        SELECT 1 FROM private.learning_group_moderation_events AS e
        WHERE e.actor_user_id = v_actor AND e.request_id = p_request_id
    ) THEN
        IF EXISTS (
            SELECT 1 FROM private.learning_group_moderation_events AS e
            WHERE e.actor_user_id = v_actor
              AND e.request_id = p_request_id
              AND e.group_id = p_group_id
              AND e.target_message_id = p_message_id
              AND e.action = CASE p_visibility
                    WHEN 'hidden' THEN 'message_hidden'
                    ELSE 'message_restored'
                  END
        ) THEN
            RETURN TRUE;
        END IF;
        RAISE EXCEPTION 'Moderation request identity conflict'
            USING ERRCODE = '22023';
    END IF;

    SELECT m.moderation_state INTO v_state
    FROM public.chat_operational_messages AS m
    JOIN public.chat_conversations AS c ON c.id = m.conversation_id
    WHERE m.id = p_message_id
      AND c.kind = 'group'
      AND c.learning_group_id = p_group_id
    FOR UPDATE;
    IF v_state IS NULL THEN
        RAISE EXCEPTION 'Group message not found' USING ERRCODE = '42501';
    END IF;

    UPDATE public.chat_operational_messages
    SET moderation_state = CASE p_visibility
            WHEN 'hidden' THEN 'removed' ELSE 'visible' END,
        deleted_at = CASE p_visibility
            WHEN 'hidden' THEN NOW() ELSE NULL END
    WHERE id = p_message_id;

    INSERT INTO private.learning_group_moderation_events(
        group_id, actor_user_id, target_message_id, action,
        reason_code, request_id
    ) VALUES (
        p_group_id, v_actor, p_message_id,
        CASE p_visibility
            WHEN 'hidden' THEN 'message_hidden'
            ELSE 'message_restored'
        END,
        p_reason_code, p_request_id
    );
    RETURN TRUE;
END;
$$;
REVOKE ALL ON FUNCTION public.moderate_learning_group_message(
    UUID, UUID, TEXT, UUID, TEXT
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_learning_group_message(
    UUID, UUID, TEXT, UUID, TEXT
) TO authenticated;

COMMENT ON COLUMN public.chat_conversations.learning_group_id IS
'GT3 one-to-one link for private learning-group chat; NULL for direct chat.';
COMMENT ON FUNCTION public.moderate_learning_group_message(
    UUID, UUID, TEXT, UUID, TEXT
) IS 'Owner-only audited visibility change for GT3 group messages.';

COMMIT;
