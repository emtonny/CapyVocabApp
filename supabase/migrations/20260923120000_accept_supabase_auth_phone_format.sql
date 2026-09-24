-- Supabase Auth stores verified E.164 phone numbers without the leading '+' on
-- this project. Keep local, +84, and 84 forms equivalent while still requiring
-- auth.users.phone_confirmed_at and an exact normalized profile match.

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
