-- F1 friend management contract.
-- Adds exact contact discovery, atomic relationship RPCs and paginated reads.
-- Contact identifiers remain private and are never returned by Friends RPCs.

DO $$
BEGIN
    IF EXISTS (
        SELECT LOWER(BTRIM(email))
        FROM public.users
        GROUP BY LOWER(BTRIM(email))
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Normalized duplicate user emails block friend discovery migration'
            USING ERRCODE = '23505';
    END IF;
END;
$$;

ALTER TABLE public.friends
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;

UPDATE public.friends
SET updated_at = COALESCE(updated_at, created_at, NOW()),
    responded_at = CASE
        WHEN status IN ('accepted', 'rejected')
            THEN COALESCE(responded_at, created_at, NOW())
        ELSE NULL
    END;

ALTER TABLE public.friends
    ALTER COLUMN updated_at SET DEFAULT NOW(),
    ALTER COLUMN updated_at SET NOT NULL;

ALTER TABLE public.friends
    DROP CONSTRAINT IF EXISTS friends_response_timestamps_check;
ALTER TABLE public.friends
    ADD CONSTRAINT friends_response_timestamps_check
    CHECK (
        (status = 'pending' AND responded_at IS NULL)
        OR (status IN ('accepted', 'rejected') AND responded_at IS NOT NULL)
    ) NOT VALID;
ALTER TABLE public.friends VALIDATE CONSTRAINT friends_response_timestamps_check;

CREATE INDEX IF NOT EXISTS friends_owner_status_page_idx
    ON public.friends (user_id, status, updated_at DESC, friend_id);
CREATE INDEX IF NOT EXISTS friends_recipient_status_page_idx
    ON public.friends (friend_id, status, updated_at DESC, user_id);
CREATE INDEX IF NOT EXISTS users_friend_email_lookup_idx
    ON public.users ((LOWER(BTRIM(email))));

CREATE OR REPLACE FUNCTION private.set_friend_server_timestamps()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.created_at := COALESCE(NEW.created_at, NOW());
    ELSE
        NEW.created_at := OLD.created_at;
    END IF;

    NEW.updated_at := NOW();
    IF NEW.status = 'pending' THEN
        NEW.responded_at := NULL;
    ELSIF TG_OP = 'INSERT' OR NEW.status IS DISTINCT FROM OLD.status THEN
        NEW.responded_at := NOW();
    ELSE
        NEW.responded_at := OLD.responded_at;
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.set_friend_server_timestamps()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS set_friend_server_timestamps ON public.friends;
CREATE TRIGGER set_friend_server_timestamps
BEFORE INSERT OR UPDATE ON public.friends
FOR EACH ROW EXECUTE FUNCTION private.set_friend_server_timestamps();

CREATE TABLE IF NOT EXISTS private.friend_discovery_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    discoverable_by_email BOOLEAN NOT NULL DEFAULT FALSE,
    discoverable_by_phone BOOLEAN NOT NULL DEFAULT FALSE,
    phone_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.friend_discovery_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    method TEXT NOT NULL CHECK (method IN ('email', 'phone')),
    old_value BOOLEAN NOT NULL,
    new_value BOOLEAN NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('owner_update', 'contact_changed')),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (old_value IS DISTINCT FROM new_value)
);

CREATE INDEX IF NOT EXISTS friend_discovery_events_owner_time_idx
    ON private.friend_discovery_events (user_id, occurred_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS private.friend_search_rate_limits (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    window_started_at TIMESTAMPTZ NOT NULL,
    attempt_count INTEGER NOT NULL CHECK (attempt_count >= 1)
);

ALTER TABLE private.friend_discovery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.friend_discovery_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.friend_search_rate_limits ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.friend_discovery_settings,
    private.friend_discovery_events,
    private.friend_search_rate_limits
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.normalize_friend_username(p_value TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
DECLARE
    v_value TEXT := LOWER(BTRIM(p_value));
BEGIN
    IF v_value !~ '^[a-z0-9_]{3,20}$' THEN
        RAISE EXCEPTION 'invalid_username' USING ERRCODE = '22023';
    END IF;
    RETURN v_value;
END;
$$;

CREATE OR REPLACE FUNCTION private.normalize_friend_email(p_value TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
DECLARE
    v_value TEXT := LOWER(BTRIM(p_value));
BEGIN
    IF CHAR_LENGTH(v_value) > 320
       OR v_value !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
        RAISE EXCEPTION 'invalid_email' USING ERRCODE = '22023';
    END IF;
    RETURN v_value;
END;
$$;

CREATE OR REPLACE FUNCTION private.normalize_friend_phone(p_value TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
DECLARE
    v_value TEXT;
BEGIN
    IF BTRIM(p_value) !~ '^[+0-9[:space:]().-]+$' THEN
        RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '22023';
    END IF;

    v_value := REGEXP_REPLACE(BTRIM(p_value), '[[:space:]().-]', '', 'g');
    IF v_value ~ '^\+84[0-9]{9}$' THEN
        v_value := '0' || SUBSTRING(v_value FROM 4);
    END IF;
    IF v_value !~ '^0[0-9]{9}$' THEN
        RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '22023';
    END IF;
    RETURN v_value;
END;
$$;

REVOKE ALL ON FUNCTION private.normalize_friend_username(TEXT),
    private.normalize_friend_email(TEXT),
    private.normalize_friend_phone(TEXT)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.consume_friend_search_budget(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_attempts INTEGER;
BEGIN
    INSERT INTO private.friend_search_rate_limits (
        user_id,
        window_started_at,
        attempt_count
    ) VALUES (
        p_user,
        clock_timestamp(),
        1
    )
    ON CONFLICT (user_id) DO UPDATE
    SET window_started_at = CASE
            WHEN private.friend_search_rate_limits.window_started_at
                    <= clock_timestamp() - INTERVAL '1 minute'
                THEN clock_timestamp()
            ELSE private.friend_search_rate_limits.window_started_at
        END,
        attempt_count = CASE
            WHEN private.friend_search_rate_limits.window_started_at
                    <= clock_timestamp() - INTERVAL '1 minute'
                THEN 1
            ELSE private.friend_search_rate_limits.attempt_count + 1
        END
    RETURNING attempt_count INTO v_attempts;

    IF v_attempts > 30 THEN
        RAISE EXCEPTION 'rate_limited' USING ERRCODE = 'P0001';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.consume_friend_search_budget(UUID)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.reset_friend_contact_discovery()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_email_was_enabled BOOLEAN := FALSE;
    v_phone_was_enabled BOOLEAN := FALSE;
BEGIN
    SELECT s.discoverable_by_email, s.discoverable_by_phone
    INTO v_email_was_enabled, v_phone_was_enabled
    FROM private.friend_discovery_settings AS s
    WHERE s.user_id = NEW.id;

    IF NEW.email IS DISTINCT FROM OLD.email THEN
        UPDATE private.friend_discovery_settings
        SET discoverable_by_email = FALSE,
            updated_at = NOW()
        WHERE user_id = NEW.id;
        IF COALESCE(v_email_was_enabled, FALSE) THEN
            INSERT INTO private.friend_discovery_events (
                user_id, method, old_value, new_value, reason
            ) VALUES (NEW.id, 'email', TRUE, FALSE, 'contact_changed');
        END IF;
    END IF;

    IF NEW.phone IS DISTINCT FROM OLD.phone THEN
        UPDATE private.friend_discovery_settings
        SET discoverable_by_phone = FALSE,
            phone_verified_at = NULL,
            updated_at = NOW()
        WHERE user_id = NEW.id;
        IF COALESCE(v_phone_was_enabled, FALSE) THEN
            INSERT INTO private.friend_discovery_events (
                user_id, method, old_value, new_value, reason
            ) VALUES (NEW.id, 'phone', TRUE, FALSE, 'contact_changed');
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.reset_friend_contact_discovery()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS reset_friend_contact_discovery ON public.users;
CREATE TRIGGER reset_friend_contact_discovery
AFTER UPDATE OF email, phone ON public.users
FOR EACH ROW
WHEN (OLD.email IS DISTINCT FROM NEW.email OR OLD.phone IS DISTINCT FROM NEW.phone)
EXECUTE FUNCTION private.reset_friend_contact_discovery();

CREATE OR REPLACE FUNCTION public.get_my_friend_discovery_settings()
RETURNS TABLE (
    discoverable_by_email BOOLEAN,
    discoverable_by_phone BOOLEAN,
    email_confirmed BOOLEAN,
    phone_verified BOOLEAN
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
    IF NOT EXISTS (SELECT 1 FROM public.users AS u WHERE u.id = v_user) THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        COALESCE(s.discoverable_by_email, FALSE),
        COALESCE(s.discoverable_by_phone, FALSE),
        (
            au.email_confirmed_at IS NOT NULL
            AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(u.email))
        ),
        (
            s.phone_verified_at IS NOT NULL
            AND au.phone_confirmed_at IS NOT NULL
            AND u.phone ~ '^0[0-9]{9}$'
            AND au.phone IN (
                u.phone,
                '+84' || SUBSTRING(u.phone FROM 2),
                '84' || SUBSTRING(u.phone FROM 2)
            )
        )
    FROM public.users AS u
    JOIN auth.users AS au ON au.id = u.id
    LEFT JOIN private.friend_discovery_settings AS s ON s.user_id = u.id
    WHERE u.id = v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_my_verified_friend_phone()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_confirmed_at TIMESTAMPTZ;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;

    SELECT au.phone_confirmed_at
    INTO v_confirmed_at
    FROM public.users AS u
    JOIN auth.users AS au ON au.id = u.id
    WHERE u.id = v_user
      AND u.phone ~ '^0[0-9]{9}$'
      AND au.phone_confirmed_at IS NOT NULL
      AND au.phone IN (
          u.phone,
          '+84' || SUBSTRING(u.phone FROM 2),
          '84' || SUBSTRING(u.phone FROM 2)
      );

    IF v_confirmed_at IS NULL THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;

    INSERT INTO private.friend_discovery_settings (
        user_id,
        phone_verified_at,
        updated_at
    ) VALUES (
        v_user,
        v_confirmed_at,
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET phone_verified_at = EXCLUDED.phone_verified_at,
        updated_at = NOW();
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_my_friend_discovery_settings(
    p_discoverable_by_email BOOLEAN,
    p_discoverable_by_phone BOOLEAN
)
RETURNS TABLE (
    discoverable_by_email BOOLEAN,
    discoverable_by_phone BOOLEAN,
    email_confirmed BOOLEAN,
    phone_verified BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_email_confirmed BOOLEAN;
    v_phone_verified BOOLEAN;
    v_old_email BOOLEAN := FALSE;
    v_old_phone BOOLEAN := FALSE;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_discoverable_by_email IS NULL OR p_discoverable_by_phone IS NULL THEN
        RAISE EXCEPTION 'invalid_discovery_settings' USING ERRCODE = '22023';
    END IF;

    SELECT
        au.email_confirmed_at IS NOT NULL
            AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(u.email)),
        s.phone_verified_at IS NOT NULL
            AND au.phone_confirmed_at IS NOT NULL
            AND u.phone ~ '^0[0-9]{9}$'
            AND au.phone IN (
                u.phone,
                '+84' || SUBSTRING(u.phone FROM 2),
                '84' || SUBSTRING(u.phone FROM 2)
            ),
        COALESCE(s.discoverable_by_email, FALSE),
        COALESCE(s.discoverable_by_phone, FALSE)
    INTO v_email_confirmed, v_phone_verified, v_old_email, v_old_phone
    FROM public.users AS u
    JOIN auth.users AS au ON au.id = u.id
    LEFT JOIN private.friend_discovery_settings AS s ON s.user_id = u.id
    WHERE u.id = v_user;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = '42501';
    END IF;
    IF p_discoverable_by_email AND NOT v_email_confirmed THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;
    IF p_discoverable_by_phone AND NOT v_phone_verified THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;

    INSERT INTO private.friend_discovery_settings (
        user_id,
        discoverable_by_email,
        discoverable_by_phone,
        updated_at
    ) VALUES (
        v_user,
        p_discoverable_by_email,
        p_discoverable_by_phone,
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE
    SET discoverable_by_email = EXCLUDED.discoverable_by_email,
        discoverable_by_phone = EXCLUDED.discoverable_by_phone,
        updated_at = NOW();

    IF v_old_email IS DISTINCT FROM p_discoverable_by_email THEN
        INSERT INTO private.friend_discovery_events (
            user_id, method, old_value, new_value, reason
        ) VALUES (
            v_user, 'email', v_old_email, p_discoverable_by_email, 'owner_update'
        );
    END IF;
    IF v_old_phone IS DISTINCT FROM p_discoverable_by_phone THEN
        INSERT INTO private.friend_discovery_events (
            user_id, method, old_value, new_value, reason
        ) VALUES (
            v_user, 'phone', v_old_phone, p_discoverable_by_phone, 'owner_update'
        );
    END IF;

    RETURN QUERY SELECT * FROM public.get_my_friend_discovery_settings();
END;
$$;

CREATE OR REPLACE FUNCTION public.search_friend(
    p_method TEXT,
    p_query TEXT
)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INTEGER,
    streak_days INTEGER,
    user_level INTEGER,
    relationship_state TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_method TEXT := LOWER(BTRIM(COALESCE(p_method, '')));
    v_query TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.users AS u WHERE u.id = v_user) THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = '42501';
    END IF;
    IF v_method = 'username' THEN
        v_query := private.normalize_friend_username(p_query);
    ELSIF v_method = 'email' THEN
        v_query := private.normalize_friend_email(p_query);
    ELSIF v_method = 'phone' THEN
        v_query := private.normalize_friend_phone(p_query);
    ELSE
        RAISE EXCEPTION 'invalid_search_method' USING ERRCODE = '22023';
    END IF;

    PERFORM private.consume_friend_search_budget(v_user);

    RETURN QUERY
    WITH target AS (
        SELECT u.*
        FROM public.users AS u
        JOIN auth.users AS au ON au.id = u.id
        LEFT JOIN private.friend_discovery_settings AS s ON s.user_id = u.id
        WHERE u.id <> v_user
          AND (
              (v_method = 'username' AND LOWER(BTRIM(u.username)) = v_query)
              OR (
                  v_method = 'email'
                  AND COALESCE(s.discoverable_by_email, FALSE)
                  AND au.email_confirmed_at IS NOT NULL
                  AND LOWER(BTRIM(au.email)) = v_query
                  AND LOWER(BTRIM(u.email)) = v_query
              )
              OR (
                  v_method = 'phone'
                  AND COALESCE(s.discoverable_by_phone, FALSE)
                  AND s.phone_verified_at IS NOT NULL
                  AND au.phone_confirmed_at IS NOT NULL
                  AND u.phone = v_query
                  AND au.phone IN (
                      v_query,
                      '+84' || SUBSTRING(v_query FROM 2),
                      '84' || SUBSTRING(v_query FROM 2)
                  )
              )
          )
        ORDER BY u.id
        LIMIT 1
    )
    SELECT
        t.id,
        t.display_name,
        t.username,
        t.avatar_url,
        t.study_points,
        t.streak_days,
        t.user_level,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS outgoing
                JOIN public.friends AS incoming
                  ON incoming.user_id = outgoing.friend_id
                 AND incoming.friend_id = outgoing.user_id
                 AND incoming.status = 'accepted'
                WHERE outgoing.user_id = v_user
                  AND outgoing.friend_id = t.id
                  AND outgoing.status = 'accepted'
            ) THEN 'accepted'
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS f
                WHERE f.user_id = v_user
                  AND f.friend_id = t.id
                  AND f.status = 'pending'
            ) THEN 'outgoing_pending'
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS f
                WHERE f.user_id = t.id
                  AND f.friend_id = v_user
                  AND f.status = 'pending'
            ) THEN 'incoming_pending'
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS f
                WHERE ((f.user_id = v_user AND f.friend_id = t.id)
                    OR (f.user_id = t.id AND f.friend_id = v_user))
                  AND f.status = 'rejected'
            ) THEN 'rejected'
            ELSE 'none'
        END
    FROM target AS t;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_friend_request(p_target_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_outgoing TEXT;
    v_incoming TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_target_user_id IS NULL OR p_target_user_id = v_user THEN
        RAISE EXCEPTION 'self_request' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_target_user_id) THEN
        RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0002';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            LEAST(v_user, p_target_user_id)::TEXT || ':' ||
            GREATEST(v_user, p_target_user_id)::TEXT,
            0
        )
    );

    SELECT f.status INTO v_outgoing
    FROM public.friends AS f
    WHERE f.user_id = v_user AND f.friend_id = p_target_user_id
    FOR UPDATE;
    SELECT f.status INTO v_incoming
    FROM public.friends AS f
    WHERE f.user_id = p_target_user_id AND f.friend_id = v_user
    FOR UPDATE;

    IF v_outgoing = 'accepted' AND v_incoming = 'accepted' THEN
        RETURN 'already_accepted';
    END IF;
    IF v_outgoing = 'accepted' OR v_incoming = 'accepted' THEN
        RAISE EXCEPTION 'friendship_inconsistent' USING ERRCODE = '55000';
    END IF;
    IF v_outgoing = 'pending' THEN
        RETURN 'outgoing_pending';
    END IF;
    IF v_incoming = 'pending' THEN
        RETURN 'incoming_pending';
    END IF;
    IF v_outgoing = 'rejected' OR v_incoming = 'rejected' THEN
        RETURN 'rejected';
    END IF;

    INSERT INTO public.friends (user_id, friend_id, status)
    VALUES (v_user, p_target_user_id, 'pending');
    RETURN 'outgoing_pending';
END;
$$;

CREATE OR REPLACE FUNCTION public.respond_friend_request(
    p_requester_id UUID,
    p_decision TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_decision TEXT := LOWER(BTRIM(COALESCE(p_decision, '')));
    v_status TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_requester_id IS NULL OR p_requester_id = v_user THEN
        RAISE EXCEPTION 'invalid_requester' USING ERRCODE = '22023';
    END IF;
    IF v_decision NOT IN ('accept', 'reject') THEN
        RAISE EXCEPTION 'invalid_decision' USING ERRCODE = '22023';
    END IF;

    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            LEAST(v_user, p_requester_id)::TEXT || ':' ||
            GREATEST(v_user, p_requester_id)::TEXT,
            0
        )
    );

    SELECT f.status INTO v_status
    FROM public.friends AS f
    WHERE f.user_id = p_requester_id AND f.friend_id = v_user
    FOR UPDATE;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'stale_request' USING ERRCODE = 'P0002';
    END IF;
    IF v_status = 'accepted' AND v_decision = 'accept' THEN
        INSERT INTO public.friends (user_id, friend_id, status)
        VALUES (v_user, p_requester_id, 'accepted')
        ON CONFLICT (user_id, friend_id) DO UPDATE
        SET status = 'accepted';
        RETURN 'accepted';
    END IF;
    IF v_status = 'rejected' AND v_decision = 'reject' THEN
        RETURN 'rejected';
    END IF;
    IF v_status <> 'pending' THEN
        RAISE EXCEPTION 'request_already_resolved' USING ERRCODE = '55000';
    END IF;

    IF v_decision = 'accept' THEN
        UPDATE public.friends
        SET status = 'accepted'
        WHERE user_id = p_requester_id AND friend_id = v_user;
        INSERT INTO public.friends (user_id, friend_id, status)
        VALUES (v_user, p_requester_id, 'accepted')
        ON CONFLICT (user_id, friend_id) DO UPDATE
        SET status = 'accepted';
        RETURN 'accepted';
    END IF;

    UPDATE public.friends
    SET status = 'rejected'
    WHERE user_id = p_requester_id AND friend_id = v_user;
    RETURN 'rejected';
END;
$$;

CREATE OR REPLACE FUNCTION public.list_friend_requests(
    p_direction TEXT,
    p_cursor_updated_at TIMESTAMPTZ DEFAULT NULL,
    p_cursor_peer_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    peer_id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INTEGER,
    streak_days INTEGER,
    user_level INTEGER,
    direction TEXT,
    request_updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_direction TEXT := LOWER(BTRIM(COALESCE(p_direction, '')));
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF v_direction NOT IN ('incoming', 'outgoing') THEN
        RAISE EXCEPTION 'invalid_direction' USING ERRCODE = '22023';
    END IF;
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION 'invalid_limit' USING ERRCODE = '22023';
    END IF;
    IF (p_cursor_updated_at IS NULL) IS DISTINCT FROM (p_cursor_peer_id IS NULL) THEN
        RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    WITH requests AS (
        SELECT
            f.*,
            CASE WHEN v_direction = 'incoming' THEN f.user_id ELSE f.friend_id END AS resolved_peer_id
        FROM public.friends AS f
        WHERE f.status = 'pending'
          AND (
              (v_direction = 'incoming' AND f.friend_id = v_user)
              OR (v_direction = 'outgoing' AND f.user_id = v_user)
          )
    )
    SELECT
        r.resolved_peer_id,
        u.display_name,
        u.username,
        u.avatar_url,
        u.study_points,
        u.streak_days,
        u.user_level,
        v_direction,
        r.updated_at
    FROM requests AS r
    JOIN public.users AS u ON u.id = r.resolved_peer_id
    WHERE p_cursor_updated_at IS NULL
       OR (r.updated_at, r.resolved_peer_id) <
          (p_cursor_updated_at, p_cursor_peer_id)
    ORDER BY r.updated_at DESC, r.resolved_peer_id DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_accepted_friends(
    p_cursor_updated_at TIMESTAMPTZ DEFAULT NULL,
    p_cursor_peer_id UUID DEFAULT NULL,
    p_limit INTEGER DEFAULT 30
)
RETURNS TABLE (
    peer_id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INTEGER,
    streak_days INTEGER,
    user_level INTEGER,
    relationship_updated_at TIMESTAMPTZ
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
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION 'invalid_limit' USING ERRCODE = '22023';
    END IF;
    IF (p_cursor_updated_at IS NULL) IS DISTINCT FROM (p_cursor_peer_id IS NULL) THEN
        RAISE EXCEPTION 'invalid_cursor' USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    WITH accepted AS (
        SELECT
            outgoing.friend_id AS resolved_peer_id,
            GREATEST(outgoing.updated_at, incoming.updated_at) AS resolved_updated_at
        FROM public.friends AS outgoing
        JOIN public.friends AS incoming
          ON incoming.user_id = outgoing.friend_id
         AND incoming.friend_id = outgoing.user_id
         AND incoming.status = 'accepted'
        WHERE outgoing.user_id = v_user
          AND outgoing.status = 'accepted'
    )
    SELECT
        a.resolved_peer_id,
        u.display_name,
        u.username,
        u.avatar_url,
        u.study_points,
        u.streak_days,
        u.user_level,
        a.resolved_updated_at
    FROM accepted AS a
    JOIN public.users AS u ON u.id = a.resolved_peer_id
    WHERE p_cursor_updated_at IS NULL
       OR (a.resolved_updated_at, a.resolved_peer_id) <
          (p_cursor_updated_at, p_cursor_peer_id)
    ORDER BY a.resolved_updated_at DESC, a.resolved_peer_id DESC
    LIMIT p_limit;
END;
$$;

-- Availability pre-checks cannot reveal whether another account owns a phone.
-- The final onboarding write remains authoritative through users_phone_key.
CREATE OR REPLACE FUNCTION public.check_phone_available(p_phone TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF (SELECT auth.uid()) IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    PERFORM private.normalize_friend_phone(p_phone);
    RETURN TRUE;
EXCEPTION
    WHEN SQLSTATE '22023' THEN RETURN FALSE;
END;
$$;

-- NULL must never mean "return every profile".
CREATE OR REPLACE FUNCTION public.get_public_profiles(profile_ids UUID[] DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INTEGER,
    streak_days INTEGER,
    user_level INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        u.id,
        u.display_name,
        u.username,
        u.avatar_url,
        u.study_points,
        u.streak_days,
        u.user_level
    FROM public.users AS u
    WHERE profile_ids IS NOT NULL
      AND CARDINALITY(profile_ids) > 0
      AND u.id = ANY(profile_ids);
$$;

REVOKE ALL ON FUNCTION public.get_my_friend_discovery_settings(),
    public.sync_my_verified_friend_phone(),
    public.update_my_friend_discovery_settings(BOOLEAN, BOOLEAN),
    public.search_friend(TEXT, TEXT),
    public.send_friend_request(UUID),
    public.respond_friend_request(UUID, TEXT),
    public.list_friend_requests(TEXT, TIMESTAMPTZ, UUID, INTEGER),
    public.list_accepted_friends(TIMESTAMPTZ, UUID, INTEGER),
    public.check_phone_available(TEXT),
    public.get_public_profiles(UUID[])
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_my_friend_discovery_settings(),
    public.sync_my_verified_friend_phone(),
    public.update_my_friend_discovery_settings(BOOLEAN, BOOLEAN),
    public.search_friend(TEXT, TEXT),
    public.send_friend_request(UUID),
    public.respond_friend_request(UUID, TEXT),
    public.list_friend_requests(TEXT, TIMESTAMPTZ, UUID, INTEGER),
    public.list_accepted_friends(TIMESTAMPTZ, UUID, INTEGER),
    public.check_phone_available(TEXT),
    public.get_public_profiles(UUID[])
TO authenticated;

COMMENT ON TABLE private.friend_discovery_settings IS
'Owner-controlled email/phone discovery flags. No raw contact identifiers are stored here.';
COMMENT ON TABLE private.friend_discovery_events IS
'Append-only discovery setting audit without raw email or phone values.';
COMMENT ON FUNCTION public.search_friend(TEXT, TEXT) IS
'Exact username/email/Vietnam phone lookup returning only the approved public profile projection.';
COMMENT ON FUNCTION public.check_phone_available(TEXT) IS
'Privacy-preserving deprecated pre-check: validates syntax only; final onboarding uniqueness is authoritative.';
COMMENT ON FUNCTION public.get_public_profiles(UUID[]) IS
'Approved public profile projection for known IDs. NULL/empty input returns no rows and contact fields are never exposed.';

-- Friend request/list providers invalidate their caches from Postgres Changes.
-- Keep this idempotent because local bootstrap databases do not always install
-- the Supabase Realtime publication.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication
        WHERE pubname = 'supabase_realtime'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'friends'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.friends;
    END IF;
END;
$$;
