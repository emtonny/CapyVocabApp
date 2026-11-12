BEGIN;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE public.learning_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_teacher_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL CHECK (CHAR_LENGTH(BTRIM(title)) BETWEEN 1 AND 80),
    description TEXT NOT NULL DEFAULT '' CHECK (CHAR_LENGTH(description) <= 500),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    creation_request_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ,
    UNIQUE (owner_teacher_id, creation_request_id),
    CHECK ((status = 'archived') = (archived_at IS NOT NULL))
);

CREATE TABLE public.learning_group_members (
    group_id UUID NOT NULL REFERENCES public.learning_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('owner_teacher', 'student')),
    status TEXT NOT NULL CHECK (
        status IN ('pending', 'active', 'rejected', 'left', 'removed')
    ),
    is_muted BOOLEAN NOT NULL DEFAULT FALSE,
    last_request_id UUID,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    joined_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id),
    CHECK (
        role <> 'owner_teacher'
        OR (status = 'active' AND NOT is_muted AND joined_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX learning_group_single_owner
ON public.learning_group_members (group_id)
WHERE role = 'owner_teacher';

CREATE INDEX learning_group_members_user_list
ON public.learning_group_members (user_id, status, updated_at DESC);

CREATE INDEX learning_group_members_group_queue
ON public.learning_group_members (group_id, status, updated_at DESC);

CREATE TABLE public.learning_group_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.learning_groups(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    request_id UUID NOT NULL,
    use_count INT NOT NULL DEFAULT 0 CHECK (use_count >= 0),
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (group_id, request_id),
    CHECK (expires_at > created_at)
);

CREATE UNIQUE INDEX learning_group_one_live_invite
ON public.learning_group_invites (group_id)
WHERE revoked_at IS NULL;

CREATE TABLE public.learning_group_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.learning_groups(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    body TEXT NOT NULL CHECK (CHAR_LENGTH(BTRIM(body)) BETWEEN 1 AND 2000),
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    request_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (group_id, request_id)
);

CREATE INDEX learning_group_announcements_list
ON public.learning_group_announcements (
    group_id, is_pinned DESC, created_at DESC, id DESC
);

CREATE TABLE private.learning_group_moderation_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES public.learning_groups(id) ON DELETE CASCADE,
    actor_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
    target_user_id UUID REFERENCES public.users(id) ON DELETE RESTRICT,
    action TEXT NOT NULL CHECK (action IN (
        'group_created', 'group_updated', 'group_archived',
        'invite_rotated', 'invite_revoked', 'join_requested',
        'join_approved', 'join_rejected', 'member_left',
        'member_removed', 'member_muted', 'member_unmuted',
        'announcement_created', 'announcement_pinned',
        'announcement_unpinned'
    )),
    reason_code TEXT CHECK (
        reason_code IS NULL OR reason_code ~ '^[a-z0-9_]{1,64}$'
    ),
    request_id UUID,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX learning_group_event_request_once
ON private.learning_group_moderation_events (actor_user_id, request_id)
WHERE request_id IS NOT NULL;

CREATE INDEX learning_group_events_group_time
ON private.learning_group_moderation_events (group_id, occurred_at DESC, id DESC);

CREATE TABLE private.learning_group_join_rate_limits (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    window_started_at TIMESTAMPTZ NOT NULL,
    attempt_count INT NOT NULL CHECK (attempt_count >= 1)
);

ALTER TABLE public.learning_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_group_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.learning_group_moderation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.learning_group_join_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION private.is_learning_group_active_member(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.learning_group_members AS m
        WHERE m.group_id = p_group_id
          AND m.user_id = p_user_id
          AND m.status = 'active'
    );
$$;

CREATE OR REPLACE FUNCTION private.is_learning_group_visible_to_user(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.learning_group_members AS m
        WHERE m.group_id = p_group_id
          AND m.user_id = p_user_id
          AND m.status IN ('pending', 'active')
    );
$$;

CREATE OR REPLACE FUNCTION private.is_learning_group_owner_member(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.learning_group_members AS m
        WHERE m.group_id = p_group_id
          AND m.user_id = p_user_id
          AND m.role = 'owner_teacher'
          AND m.status = 'active'
    );
$$;

REVOKE ALL ON FUNCTION private.is_learning_group_active_member(UUID, UUID)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_learning_group_visible_to_user(UUID, UUID)
FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_learning_group_owner_member(UUID, UUID)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.current_user_can_see_learning_group(
    p_group_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT private.is_learning_group_visible_to_user(
        p_group_id, (SELECT auth.uid())
    );
$$;

CREATE OR REPLACE FUNCTION private.current_user_is_active_learning_group_member(
    p_group_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT private.is_learning_group_active_member(
        p_group_id, (SELECT auth.uid())
    );
$$;

CREATE OR REPLACE FUNCTION private.current_user_can_read_learning_group_member(
    p_group_id UUID,
    p_row_user_id UUID,
    p_row_status TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT (
        p_row_status = 'active'
        AND private.is_learning_group_active_member(
            p_group_id, (SELECT auth.uid())
        )
    )
    OR private.is_learning_group_owner_member(
        p_group_id, (SELECT auth.uid())
    )
    OR (
        p_row_user_id = (SELECT auth.uid())
        AND p_row_status = 'pending'
    );
$$;

REVOKE ALL ON FUNCTION private.current_user_can_see_learning_group(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.current_user_is_active_learning_group_member(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.current_user_can_read_learning_group_member(UUID, UUID, TEXT)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.current_user_can_see_learning_group(UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_user_is_active_learning_group_member(UUID)
TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_user_can_read_learning_group_member(UUID, UUID, TEXT)
TO authenticated;

CREATE POLICY learning_groups_member_read
ON public.learning_groups FOR SELECT TO authenticated
USING (private.current_user_can_see_learning_group(id));

CREATE POLICY learning_group_members_member_read
ON public.learning_group_members FOR SELECT TO authenticated
USING (
    private.current_user_can_read_learning_group_member(
        group_id, user_id, status
    )
);

CREATE POLICY learning_group_announcements_member_read
ON public.learning_group_announcements FOR SELECT TO authenticated
USING (private.current_user_is_active_learning_group_member(group_id));

GRANT SELECT ON public.learning_groups TO authenticated;
GRANT SELECT ON public.learning_group_members TO authenticated;
GRANT SELECT ON public.learning_group_announcements TO authenticated;
REVOKE ALL ON public.learning_group_invites FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.learning_group_moderation_events
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON private.learning_group_join_rate_limits
FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_my_learning_group_capabilities()
RETURNS TABLE (
    account_role TEXT,
    teacher_verification_status TEXT,
    can_manage_groups BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT u.account_role,
           tp.verification_status,
           private.is_verified_teacher(v_user)
    FROM public.users AS u
    LEFT JOIN public.teacher_profiles AS tp ON tp.user_id = u.id
    WHERE u.id = v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_my_learning_groups()
RETURNS TABLE (
    group_id UUID,
    title TEXT,
    description TEXT,
    group_status TEXT,
    member_role TEXT,
    membership_status TEXT,
    is_muted BOOLEAN,
    active_student_count INT,
    pending_student_count INT,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT g.id, g.title, g.description, g.status, mine.role, mine.status,
           mine.is_muted,
           COUNT(*) FILTER (
               WHERE members.role = 'student' AND members.status = 'active'
           )::INT,
           COUNT(*) FILTER (
               WHERE members.role = 'student' AND members.status = 'pending'
           )::INT,
           g.updated_at
    FROM public.learning_group_members AS mine
    JOIN public.learning_groups AS g ON g.id = mine.group_id
    LEFT JOIN public.learning_group_members AS members ON members.group_id = g.id
    WHERE mine.user_id = v_user
      AND mine.status IN ('pending', 'active')
    GROUP BY g.id, mine.role, mine.status, mine.is_muted
    ORDER BY g.updated_at DESC, g.id DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_learning_group(
    p_title TEXT,
    p_description TEXT,
    p_request_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_group UUID;
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_description TEXT := BTRIM(COALESCE(p_description, ''));
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT private.is_verified_teacher(v_user) THEN
        RAISE EXCEPTION 'verified_teacher_required' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL OR CHAR_LENGTH(v_title) NOT BETWEEN 1 AND 80
       OR CHAR_LENGTH(v_description) > 500 THEN
        RAISE EXCEPTION 'invalid_group' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.learning_groups (
        owner_teacher_id, title, description, creation_request_id
    ) VALUES (v_user, v_title, v_description, p_request_id)
    ON CONFLICT (owner_teacher_id, creation_request_id) DO UPDATE SET
        title = public.learning_groups.title
    RETURNING id INTO v_group;
    INSERT INTO public.learning_group_members (
        group_id, user_id, role, status, joined_at, last_request_id
    ) VALUES (v_group, v_user, 'owner_teacher', 'active', NOW(), p_request_id)
    ON CONFLICT (group_id, user_id) DO NOTHING;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (v_group, v_user, 'group_created', p_request_id)
    ON CONFLICT (actor_user_id, request_id) WHERE request_id IS NOT NULL
    DO NOTHING;
    RETURN v_group;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_learning_group(
    p_group_id UUID,
    p_title TEXT,
    p_description TEXT,
    p_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_title TEXT := BTRIM(COALESCE(p_title, ''));
    v_description TEXT := BTRIM(COALESCE(p_description, ''));
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL OR CHAR_LENGTH(v_title) NOT BETWEEN 1 AND 80
       OR CHAR_LENGTH(v_description) > 500 THEN
        RAISE EXCEPTION 'invalid_group' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (
        SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id
    ) THEN RETURN TRUE; END IF;
    UPDATE public.learning_groups
    SET title = v_title, description = v_description, updated_at = NOW()
    WHERE id = p_group_id;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (p_group_id, v_user, 'group_updated', p_request_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_learning_group(
    p_group_id UUID,
    p_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_request_id' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (
        SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id
    ) THEN RETURN TRUE; END IF;
    UPDATE public.learning_groups
    SET status = 'archived', archived_at = COALESCE(archived_at, NOW()),
        updated_at = NOW()
    WHERE id = p_group_id;
    UPDATE public.learning_group_invites
    SET revoked_at = COALESCE(revoked_at, NOW())
    WHERE group_id = p_group_id AND revoked_at IS NULL;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (p_group_id, v_user, 'group_archived', p_request_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.rotate_learning_group_invite(
    p_group_id UUID,
    p_expires_at TIMESTAMPTZ,
    p_request_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_token TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL OR p_expires_at IS NULL
       OR p_expires_at <= NOW() OR p_expires_at > NOW() + INTERVAL '90 days' THEN
        RAISE EXCEPTION 'invalid_invite_expiry' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (
        SELECT 1 FROM public.learning_group_invites
        WHERE group_id = p_group_id AND request_id = p_request_id
    ) THEN
        RAISE EXCEPTION 'invite_secret_not_replayable' USING ERRCODE = '55000';
    END IF;
    UPDATE public.learning_group_invites SET revoked_at = NOW()
    WHERE group_id = p_group_id AND revoked_at IS NULL;
    v_token := LOWER(REPLACE(gen_random_uuid()::TEXT, '-', ''))
        || LOWER(REPLACE(gen_random_uuid()::TEXT, '-', ''));
    INSERT INTO public.learning_group_invites (
        group_id, token_hash, expires_at, created_by, request_id
    ) VALUES (
        p_group_id,
        ENCODE(extensions.digest(v_token, 'sha256'), 'hex'),
        p_expires_at, v_user, p_request_id
    );
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (p_group_id, v_user, 'invite_rotated', p_request_id);
    RETURN v_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_learning_group_invite(
    p_group_id UUID,
    p_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_request_id' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (
        SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id
    ) THEN RETURN TRUE; END IF;
    UPDATE public.learning_group_invites SET revoked_at = NOW()
    WHERE group_id = p_group_id AND revoked_at IS NULL;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (p_group_id, v_user, 'invite_revoked', p_request_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_learning_group_join(
    p_invite_token TEXT,
    p_request_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_group UUID;
    v_token_hash TEXT;
    v_existing public.learning_group_members%ROWTYPE;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_request_id' USING ERRCODE = '22023';
    END IF;
    INSERT INTO private.learning_group_join_rate_limits (
        user_id, window_started_at, attempt_count
    ) VALUES (v_user, NOW(), 1)
    ON CONFLICT (user_id) DO UPDATE SET
        window_started_at = CASE
            WHEN private.learning_group_join_rate_limits.window_started_at
                <= NOW() - INTERVAL '10 minutes' THEN NOW()
            ELSE private.learning_group_join_rate_limits.window_started_at
        END,
        attempt_count = CASE
            WHEN private.learning_group_join_rate_limits.window_started_at
                <= NOW() - INTERVAL '10 minutes' THEN 1
            ELSE private.learning_group_join_rate_limits.attempt_count + 1
        END;
    IF (SELECT attempt_count FROM private.learning_group_join_rate_limits
        WHERE user_id = v_user) > 10 THEN
        RETURN NULL;
    END IF;
    IF p_invite_token IS NULL OR p_invite_token !~ '^[0-9a-fA-F]{64}$' THEN
        RETURN NULL;
    END IF;
    v_token_hash := ENCODE(
        extensions.digest(LOWER(p_invite_token), 'sha256'), 'hex'
    );
    SELECT i.group_id INTO v_group
    FROM public.learning_group_invites AS i
    JOIN public.learning_groups AS g ON g.id = i.group_id
    WHERE i.token_hash = v_token_hash
      AND i.revoked_at IS NULL
      AND i.expires_at > NOW()
      AND g.status = 'active'
    FOR UPDATE OF i;
    IF v_group IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT * INTO v_existing
    FROM public.learning_group_members
    WHERE group_id = v_group AND user_id = v_user
    FOR UPDATE;
    IF FOUND AND v_existing.role = 'owner_teacher' THEN
        RAISE EXCEPTION 'already_group_owner' USING ERRCODE = '55000';
    END IF;
    IF FOUND AND v_existing.status = 'active' THEN
        RAISE EXCEPTION 'already_group_member' USING ERRCODE = '55000';
    END IF;
    IF FOUND AND v_existing.status = 'pending' THEN
        RETURN v_group;
    END IF;
    INSERT INTO public.learning_group_members (
        group_id, user_id, role, status, is_muted, last_request_id,
        requested_at, joined_at, ended_at, updated_at
    ) VALUES (
        v_group, v_user, 'student', 'pending', FALSE, p_request_id,
        NOW(), NULL, NULL, NOW()
    ) ON CONFLICT (group_id, user_id) DO UPDATE SET
        role = 'student', status = 'pending', is_muted = FALSE,
        last_request_id = EXCLUDED.last_request_id,
        requested_at = NOW(), joined_at = NULL, ended_at = NULL,
        updated_at = NOW();
    UPDATE public.learning_group_invites
    SET use_count = use_count + 1, last_used_at = NOW()
    WHERE token_hash = v_token_hash;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, target_user_id, action, request_id
    ) VALUES (v_group, v_user, v_user, 'join_requested', p_request_id)
    ON CONFLICT (actor_user_id, request_id) WHERE request_id IS NOT NULL
    DO NOTHING;
    RETURN v_group;
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_learning_group_join(
    p_group_id UUID,
    p_student_user_id UUID,
    p_decision TEXT,
    p_request_id UUID,
    p_reason_code TEXT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_action TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL OR p_decision NOT IN ('approve', 'reject')
       OR (p_reason_code IS NOT NULL AND p_reason_code !~ '^[a-z0-9_]{1,64}$') THEN
        RAISE EXCEPTION 'invalid_join_decision' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (
        SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id
    ) THEN
        RETURN CASE WHEN p_decision = 'approve' THEN 'active' ELSE 'rejected' END;
    END IF;
    PERFORM 1 FROM public.learning_group_members
    WHERE group_id = p_group_id AND user_id = p_student_user_id
      AND role = 'student' AND status = 'pending'
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'pending_member_not_found' USING ERRCODE = 'P0002';
    END IF;
    IF p_decision = 'approve' AND (
        SELECT COUNT(*) FROM public.learning_group_members
        WHERE group_id = p_group_id AND role = 'student' AND status = 'active'
    ) >= 50 THEN
        RAISE EXCEPTION 'group_student_limit_reached' USING ERRCODE = '55000';
    END IF;
    UPDATE public.learning_group_members
    SET status = CASE WHEN p_decision = 'approve' THEN 'active' ELSE 'rejected' END,
        joined_at = CASE WHEN p_decision = 'approve' THEN NOW() ELSE NULL END,
        ended_at = CASE WHEN p_decision = 'reject' THEN NOW() ELSE NULL END,
        updated_at = NOW(), last_request_id = p_request_id
    WHERE group_id = p_group_id AND user_id = p_student_user_id;
    v_action := CASE WHEN p_decision = 'approve'
        THEN 'join_approved' ELSE 'join_rejected' END;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, target_user_id, action, reason_code, request_id
    ) VALUES (
        p_group_id, v_user, p_student_user_id, v_action, p_reason_code, p_request_id
    );
    RETURN CASE WHEN p_decision = 'approve' THEN 'active' ELSE 'rejected' END;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_learning_group_member_mute(
    p_group_id UUID,
    p_student_user_id UUID,
    p_is_muted BOOLEAN,
    p_request_id UUID,
    p_reason_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_is_muted IS NULL OR p_request_id IS NULL
       OR (p_reason_code IS NOT NULL AND p_reason_code !~ '^[a-z0-9_]{1,64}$') THEN
        RAISE EXCEPTION 'invalid_member_action' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id) THEN
        RETURN TRUE;
    END IF;
    UPDATE public.learning_group_members
    SET is_muted = p_is_muted, updated_at = NOW(), last_request_id = p_request_id
    WHERE group_id = p_group_id AND user_id = p_student_user_id
      AND role = 'student' AND status = 'active';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'active_member_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, target_user_id, action, reason_code, request_id
    ) VALUES (
        p_group_id, v_user, p_student_user_id,
        CASE WHEN p_is_muted THEN 'member_muted' ELSE 'member_unmuted' END,
        p_reason_code, p_request_id
    );
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_learning_group_member(
    p_group_id UUID,
    p_student_user_id UUID,
    p_request_id UUID,
    p_reason_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL OR (p_reason_code IS NOT NULL
       AND p_reason_code !~ '^[a-z0-9_]{1,64}$') THEN
        RAISE EXCEPTION 'invalid_member_action' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id) THEN
        RETURN TRUE;
    END IF;
    UPDATE public.learning_group_members
    SET status = 'removed', is_muted = FALSE, ended_at = NOW(),
        updated_at = NOW(), last_request_id = p_request_id
    WHERE group_id = p_group_id AND user_id = p_student_user_id
      AND role = 'student' AND status = 'active';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'active_member_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, target_user_id, action, reason_code, request_id
    ) VALUES (
        p_group_id, v_user, p_student_user_id, 'member_removed',
        p_reason_code, p_request_id
    );
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_learning_group(
    p_group_id UUID,
    p_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_request_id' USING ERRCODE = '22023';
    END IF;
    PERFORM pg_advisory_xact_lock(hashtextextended(p_group_id::TEXT, 0));
    IF EXISTS (SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id) THEN
        RETURN TRUE;
    END IF;
    UPDATE public.learning_group_members
    SET status = 'left', is_muted = FALSE, ended_at = NOW(),
        updated_at = NOW(), last_request_id = p_request_id
    WHERE group_id = p_group_id AND user_id = v_user
      AND role = 'student' AND status = 'active';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'active_member_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, target_user_id, action, request_id
    ) VALUES (p_group_id, v_user, v_user, 'member_left', p_request_id);
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_learning_group_members(p_group_id UUID)
RETURNS TABLE (
    user_id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    member_role TEXT,
    membership_status TEXT,
    is_muted BOOLEAN,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL OR NOT private.is_learning_group_active_member(
        p_group_id, v_user
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT u.id, u.display_name, COALESCE(u.username, ''),
           NULLIF(COALESCE(u.avatar_url, ''), ''), m.role, m.status,
           m.is_muted, m.updated_at
    FROM public.learning_group_members AS m
    JOIN public.users AS u ON u.id = m.user_id
    WHERE m.group_id = p_group_id
      AND (
          m.status = 'active'
          OR (
              EXISTS (
                  SELECT 1 FROM public.learning_groups AS g
                  WHERE g.id = p_group_id AND g.owner_teacher_id = v_user
              )
              AND m.status = 'pending'
          )
      )
    ORDER BY CASE WHEN m.role = 'owner_teacher' THEN 0 ELSE 1 END,
             m.updated_at DESC, m.user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_learning_group_announcement(
    p_group_id UUID,
    p_body TEXT,
    p_request_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_id UUID;
    v_body TEXT := BTRIM(COALESCE(p_body, ''));
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_request_id IS NULL OR CHAR_LENGTH(v_body) NOT BETWEEN 1 AND 2000 THEN
        RAISE EXCEPTION 'invalid_announcement' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    INSERT INTO public.learning_group_announcements (
        group_id, author_user_id, body, request_id
    ) VALUES (p_group_id, v_user, v_body, p_request_id)
    ON CONFLICT (group_id, request_id) DO UPDATE SET
        body = public.learning_group_announcements.body
    RETURNING id INTO v_id;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (p_group_id, v_user, 'announcement_created', p_request_id)
    ON CONFLICT (actor_user_id, request_id) WHERE request_id IS NOT NULL
    DO NOTHING;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_learning_group_announcement_pinned(
    p_group_id UUID,
    p_announcement_id UUID,
    p_is_pinned BOOLEAN,
    p_request_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_is_pinned IS NULL OR p_request_id IS NULL THEN
        RAISE EXCEPTION 'invalid_announcement_action' USING ERRCODE = '22023';
    END IF;
    IF NOT private.is_verified_teacher(v_user) OR NOT EXISTS (
        SELECT 1 FROM public.learning_groups
        WHERE id = p_group_id AND owner_teacher_id = v_user AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM private.learning_group_moderation_events
        WHERE actor_user_id = v_user AND request_id = p_request_id) THEN
        RETURN TRUE;
    END IF;
    UPDATE public.learning_group_announcements
    SET is_pinned = p_is_pinned, updated_at = NOW()
    WHERE id = p_announcement_id AND group_id = p_group_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'announcement_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO private.learning_group_moderation_events (
        group_id, actor_user_id, action, request_id
    ) VALUES (
        p_group_id, v_user,
        CASE WHEN p_is_pinned THEN 'announcement_pinned'
             ELSE 'announcement_unpinned' END,
        p_request_id
    );
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_learning_group_announcements(
    p_group_id UUID
)
RETURNS TABLE (
    announcement_id UUID,
    author_user_id UUID,
    author_display_name TEXT,
    body TEXT,
    is_pinned BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_user UUID := (SELECT auth.uid());
BEGIN
    IF v_user IS NULL OR NOT private.is_learning_group_active_member(
        p_group_id, v_user
    ) THEN
        RAISE EXCEPTION 'group_not_found_or_denied' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY
    SELECT a.id, a.author_user_id, u.display_name, a.body, a.is_pinned,
           a.created_at, a.updated_at
    FROM public.learning_group_announcements AS a
    JOIN public.users AS u ON u.id = a.author_user_id
    WHERE a.group_id = p_group_id
    ORDER BY a.is_pinned DESC, a.created_at DESC, a.id DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_learning_group_capabilities()
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_my_learning_groups()
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_learning_group(TEXT, TEXT, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_learning_group(UUID, TEXT, TEXT, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.archive_learning_group(UUID, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rotate_learning_group_invite(UUID, TIMESTAMPTZ, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.revoke_learning_group_invite(UUID, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.request_learning_group_join(TEXT, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_learning_group_join(UUID, UUID, TEXT, UUID, TEXT)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_learning_group_member_mute(UUID, UUID, BOOLEAN, UUID, TEXT)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.remove_learning_group_member(UUID, UUID, UUID, TEXT)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.leave_learning_group(UUID, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_learning_group_members(UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_learning_group_announcement(UUID, TEXT, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_learning_group_announcement_pinned(UUID, UUID, BOOLEAN, UUID)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_learning_group_announcements(UUID)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_my_learning_group_capabilities() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_learning_groups() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_learning_group(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_learning_group(UUID, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_learning_group(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_learning_group_invite(UUID, TIMESTAMPTZ, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_learning_group_invite(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_learning_group_join(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_learning_group_join(UUID, UUID, TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_learning_group_member_mute(UUID, UUID, BOOLEAN, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_learning_group_member(UUID, UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_learning_group(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_learning_group_members(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_learning_group_announcement(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_learning_group_announcement_pinned(UUID, UUID, BOOLEAN, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_learning_group_announcements(UUID) TO authenticated;

DO $$
DECLARE v_table TEXT;
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        FOREACH v_table IN ARRAY ARRAY[
            'learning_groups',
            'learning_group_members',
            'learning_group_announcements'
        ] LOOP
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_publication_tables
                WHERE pubname = 'supabase_realtime'
                  AND schemaname = 'public'
                  AND tablename = v_table
            ) THEN
                EXECUTE FORMAT(
                    'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
                    v_table
                );
            END IF;
        END LOOP;
    END IF;
END;
$$;

COMMIT;
