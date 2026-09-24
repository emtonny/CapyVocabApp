BEGIN;

-- Account contacts use E.164 everywhere. Existing profile rows were previously
-- constrained to Vietnamese local numbers, so that conversion is unambiguous.
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_phone_format_check;
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_phone_check;
ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_phone_e164_check;

UPDATE public.users
SET phone = '+84' || SUBSTRING(phone FROM 2)
WHERE phone ~ '^0[0-9]{9}$';

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.users
        WHERE phone IS NOT NULL
          AND phone !~ '^\+[1-9][0-9]{6,14}$'
    ) THEN
        RAISE EXCEPTION
            'Cannot enable E.164 contacts: unresolved legacy phone rows exist';
    END IF;
END;
$$;

ALTER TABLE public.users
    ADD CONSTRAINT users_phone_e164_check
    CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{6,14}$');

CREATE OR REPLACE FUNCTION private.normalize_account_phone(p_value TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
    v_value TEXT := REGEXP_REPLACE(BTRIM(COALESCE(p_value, '')), '[[:space:]().-]', '', 'g');
BEGIN
    IF v_value ~ '^[1-9][0-9]{6,14}$' THEN
        v_value := '+' || v_value;
    END IF;
    IF v_value !~ '^\+[1-9][0-9]{6,14}$' THEN
        RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '22023';
    END IF;
    RETURN v_value;
END;
$$;

REVOKE ALL ON FUNCTION private.normalize_account_phone(TEXT)
FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.account_contact_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    show_email_to_friends BOOLEAN NOT NULL DEFAULT FALSE,
    show_phone_to_friends BOOLEAN NOT NULL DEFAULT FALSE,
    phone_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.account_contact_history (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    contact_type TEXT NOT NULL CHECK (contact_type IN ('email', 'phone')),
    contact_value TEXT NOT NULL,
    verified_at TIMESTAMPTZ NOT NULL,
    replaced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, contact_type, contact_value)
);

CREATE INDEX IF NOT EXISTS account_contact_history_value_idx
ON private.account_contact_history (contact_type, contact_value);

CREATE TABLE IF NOT EXISTS private.subscription_contact_snapshots (
    subscription_id UUID PRIMARY KEY
        REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    verified_email TEXT NOT NULL
        CHECK (verified_email = LOWER(BTRIM(verified_email))),
    verified_phone TEXT NOT NULL
        CHECK (verified_phone ~ '^\+[1-9][0-9]{6,14}$'),
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS private.promotion_redemptions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_key TEXT NOT NULL
        CHECK (BTRIM(promotion_key) <> '' AND promotion_key = BTRIM(promotion_key)),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    verified_email TEXT NOT NULL
        CHECK (verified_email = LOWER(BTRIM(verified_email))),
    verified_phone TEXT NOT NULL
        CHECK (verified_phone ~ '^\+[1-9][0-9]{6,14}$'),
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    manual_review_required BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (promotion_key, user_id),
    UNIQUE (promotion_key, verified_email),
    UNIQUE (promotion_key, verified_phone)
);

ALTER TABLE private.account_contact_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.account_contact_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.subscription_contact_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.promotion_redemptions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.account_contact_settings,
    private.account_contact_history,
    private.subscription_contact_snapshots,
    private.promotion_redemptions
FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    private.account_contact_settings,
    private.account_contact_history,
    private.subscription_contact_snapshots,
    private.promotion_redemptions
TO service_role;

REVOKE ALL ON SEQUENCE private.account_contact_history_id_seq,
    private.promotion_redemptions_id_seq
FROM PUBLIC, anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE private.account_contact_history_id_seq,
    private.promotion_redemptions_id_seq
TO service_role;

-- Seed only contacts whose public value still matches confirmed Auth data.
-- Ambiguous or unverified legacy rows remain hidden and require re-verification.
INSERT INTO private.account_contact_settings (user_id, phone_verified_at)
SELECT u.id,
       CASE
           WHEN au.phone_confirmed_at IS NOT NULL
                AND au.phone IS NOT NULL
                AND private.normalize_account_phone(au.phone) = u.phone
           THEN au.phone_confirmed_at
       END
FROM public.users AS u
JOIN auth.users AS au ON au.id = u.id
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO private.account_contact_history (
    user_id, contact_type, contact_value, verified_at
)
SELECT u.id, 'email', LOWER(BTRIM(u.email)), au.email_confirmed_at
FROM public.users AS u
JOIN auth.users AS au ON au.id = u.id
WHERE au.email_confirmed_at IS NOT NULL
  AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(u.email))
ON CONFLICT (user_id, contact_type, contact_value) DO NOTHING;

INSERT INTO private.account_contact_history (
    user_id, contact_type, contact_value, verified_at
)
SELECT u.id, 'phone', u.phone, au.phone_confirmed_at
FROM public.users AS u
JOIN auth.users AS au ON au.id = u.id
WHERE u.phone IS NOT NULL
  AND au.phone_confirmed_at IS NOT NULL
  AND au.phone IS NOT NULL
  AND private.normalize_account_phone(au.phone) = u.phone
ON CONFLICT (user_id, contact_type, contact_value) DO NOTHING;

INSERT INTO private.subscription_contact_snapshots (
    subscription_id, user_id, verified_email, verified_phone, captured_at
)
SELECT s.id, s.user_id, LOWER(BTRIM(u.email)), u.phone,
       COALESCE(s.start_date, s.created_at, NOW())
FROM public.subscriptions AS s
JOIN public.users AS u ON u.id = s.user_id
JOIN auth.users AS au ON au.id = s.user_id
WHERE u.phone IS NOT NULL
  AND au.email_confirmed_at IS NOT NULL
  AND au.phone_confirmed_at IS NOT NULL
  AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(u.email))
  AND au.phone IS NOT NULL
  AND private.normalize_account_phone(au.phone) = u.phone
ON CONFLICT (subscription_id) DO NOTHING;

CREATE OR REPLACE FUNCTION private.record_account_contact_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.email IS DISTINCT FROM OLD.email THEN
        UPDATE private.account_contact_history
        SET replaced_at = COALESCE(replaced_at, NOW())
        WHERE user_id = NEW.id
          AND contact_type = 'email'
          AND replaced_at IS NULL;
        INSERT INTO private.account_contact_history (
            user_id, contact_type, contact_value, verified_at
        )
        SELECT NEW.id, 'email', LOWER(BTRIM(NEW.email)), au.email_confirmed_at
        FROM auth.users AS au
        WHERE au.id = NEW.id
          AND au.email_confirmed_at IS NOT NULL
          AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(NEW.email))
        ON CONFLICT (user_id, contact_type, contact_value) DO UPDATE
        SET verified_at = EXCLUDED.verified_at, replaced_at = NULL;
        INSERT INTO private.account_contact_settings (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO UPDATE
        SET show_email_to_friends = FALSE, updated_at = NOW();
    END IF;

    IF NEW.phone IS DISTINCT FROM OLD.phone THEN
        UPDATE private.account_contact_history
        SET replaced_at = COALESCE(replaced_at, NOW())
        WHERE user_id = NEW.id
          AND contact_type = 'phone'
          AND replaced_at IS NULL;
        IF NEW.phone IS NOT NULL AND EXISTS (
            SELECT 1
            FROM auth.users AS au
            WHERE au.id = NEW.id
              AND au.phone_confirmed_at IS NOT NULL
              AND au.phone IS NOT NULL
              AND private.normalize_account_phone(au.phone) = NEW.phone
        ) THEN
            INSERT INTO private.account_contact_history (
                user_id, contact_type, contact_value, verified_at
            )
            SELECT NEW.id, 'phone', NEW.phone, au.phone_confirmed_at
            FROM auth.users AS au
            WHERE au.id = NEW.id
            ON CONFLICT (user_id, contact_type, contact_value) DO UPDATE
            SET verified_at = EXCLUDED.verified_at, replaced_at = NULL;
        END IF;
        INSERT INTO private.account_contact_settings (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO UPDATE
        SET show_phone_to_friends = FALSE,
            phone_verified_at = NULL,
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.record_account_contact_change()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS record_account_contact_change ON public.users;
CREATE TRIGGER record_account_contact_change
AFTER UPDATE OF email, phone ON public.users
FOR EACH ROW
WHEN (OLD.email IS DISTINCT FROM NEW.email OR OLD.phone IS DISTINCT FROM NEW.phone)
EXECUTE FUNCTION private.record_account_contact_change();

CREATE OR REPLACE FUNCTION public.sync_my_verified_email()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_email TEXT;
    v_confirmed_at TIMESTAMPTZ;
BEGIN
    SELECT LOWER(BTRIM(email)), email_confirmed_at
    INTO v_email, v_confirmed_at
    FROM auth.users
    WHERE id = v_user;
    IF v_user IS NULL OR v_email IS NULL OR v_confirmed_at IS NULL THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;

    UPDATE public.users
    SET email = v_email, updated_at = NOW()
    WHERE id = v_user;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO private.account_contact_history (
        user_id, contact_type, contact_value, verified_at
    ) VALUES (v_user, 'email', v_email, v_confirmed_at)
    ON CONFLICT (user_id, contact_type, contact_value) DO UPDATE
    SET verified_at = EXCLUDED.verified_at, replaced_at = NULL;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_my_verified_phone()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_phone TEXT;
    v_auth_phone TEXT;
    v_confirmed_at TIMESTAMPTZ;
BEGIN
    SELECT phone, phone_confirmed_at
    INTO v_auth_phone, v_confirmed_at
    FROM auth.users
    WHERE id = v_user;
    IF v_user IS NULL OR v_auth_phone IS NULL OR v_confirmed_at IS NULL THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;
    v_phone := private.normalize_account_phone(v_auth_phone);

    UPDATE public.users
    SET phone = v_phone, updated_at = NOW()
    WHERE id = v_user;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO private.account_contact_settings (
        user_id, phone_verified_at, updated_at
    ) VALUES (v_user, v_confirmed_at, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET phone_verified_at = EXCLUDED.phone_verified_at,
        show_phone_to_friends = FALSE,
        updated_at = NOW();
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_account_contact_settings()
RETURNS TABLE (
    email TEXT,
    phone TEXT,
    email_confirmed BOOLEAN,
    phone_confirmed BOOLEAN,
    show_email_to_friends BOOLEAN,
    show_phone_to_friends BOOLEAN
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
    SELECT
        u.email,
        u.phone,
        au.email_confirmed_at IS NOT NULL
            AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(u.email)),
        CASE
            WHEN au.phone_confirmed_at IS NOT NULL AND au.phone IS NOT NULL
            THEN private.normalize_account_phone(au.phone) = u.phone
            ELSE FALSE
        END,
        COALESCE(s.show_email_to_friends, FALSE),
        COALESCE(s.show_phone_to_friends, FALSE)
    FROM public.users AS u
    JOIN auth.users AS au ON au.id = u.id
    LEFT JOIN private.account_contact_settings AS s ON s.user_id = u.id
    WHERE u.id = v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_my_account_contact_visibility(
    p_show_email BOOLEAN,
    p_show_phone BOOLEAN
)
RETURNS TABLE (
    email TEXT,
    phone TEXT,
    email_confirmed BOOLEAN,
    phone_confirmed BOOLEAN,
    show_email_to_friends BOOLEAN,
    show_phone_to_friends BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_email_confirmed BOOLEAN;
    v_phone_confirmed BOOLEAN;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF p_show_email IS NULL OR p_show_phone IS NULL THEN
        RAISE EXCEPTION 'invalid_visibility' USING ERRCODE = '22023';
    END IF;
    SELECT s.email_confirmed, s.phone_confirmed
    INTO v_email_confirmed, v_phone_confirmed
    FROM public.get_my_account_contact_settings() AS s;
    IF p_show_email AND NOT COALESCE(v_email_confirmed, FALSE) THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;
    IF p_show_phone AND NOT COALESCE(v_phone_confirmed, FALSE) THEN
        RAISE EXCEPTION 'contact_not_verified' USING ERRCODE = '22023';
    END IF;

    INSERT INTO private.account_contact_settings (
        user_id, show_email_to_friends, show_phone_to_friends, updated_at
    ) VALUES (v_user, p_show_email, p_show_phone, NOW())
    ON CONFLICT (user_id) DO UPDATE
    SET show_email_to_friends = EXCLUDED.show_email_to_friends,
        show_phone_to_friends = EXCLUDED.show_phone_to_friends,
        updated_at = NOW();
    RETURN QUERY SELECT * FROM public.get_my_account_contact_settings();
END;
$$;

CREATE OR REPLACE FUNCTION public.get_accepted_friend_contact(p_friend_id UUID)
RETURNS TABLE (email TEXT, phone TEXT)
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
    IF p_friend_id IS NULL OR p_friend_id = v_user THEN
        RAISE EXCEPTION 'invalid_friend' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM public.friends AS outgoing
        JOIN public.friends AS incoming
          ON incoming.user_id = outgoing.friend_id
         AND incoming.friend_id = outgoing.user_id
         AND incoming.status = 'accepted'
        WHERE outgoing.user_id = v_user
          AND outgoing.friend_id = p_friend_id
          AND outgoing.status = 'accepted'
    ) THEN
        RAISE EXCEPTION 'friendship_required' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        CASE WHEN COALESCE(s.show_email_to_friends, FALSE)
                  AND au.email_confirmed_at IS NOT NULL
                  AND LOWER(BTRIM(au.email)) = LOWER(BTRIM(u.email))
             THEN u.email END,
        CASE WHEN COALESCE(s.show_phone_to_friends, FALSE)
                  AND CASE
                      WHEN au.phone_confirmed_at IS NOT NULL
                           AND au.phone IS NOT NULL
                      THEN private.normalize_account_phone(au.phone) = u.phone
                      ELSE FALSE
                  END
             THEN u.phone END
    FROM public.users AS u
    JOIN auth.users AS au ON au.id = u.id
    LEFT JOIN private.account_contact_settings AS s ON s.user_id = u.id
    WHERE u.id = p_friend_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.capture_subscription_contacts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_email TEXT;
    v_phone TEXT;
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.start_date IS NOT DISTINCT FROM OLD.start_date
       AND NEW.end_date <= OLD.end_date THEN
        RETURN NEW;
    END IF;

    SELECT LOWER(BTRIM(au.email)),
           CASE WHEN au.phone IS NOT NULL
                THEN private.normalize_account_phone(au.phone) END
    INTO v_email, v_phone
    FROM auth.users AS au
    WHERE au.id = NEW.user_id
      AND au.email_confirmed_at IS NOT NULL
      AND au.phone_confirmed_at IS NOT NULL;
    IF v_email IS NULL OR v_phone IS NULL THEN
        RAISE EXCEPTION 'verified_contacts_required' USING ERRCODE = '22023';
    END IF;
    INSERT INTO private.subscription_contact_snapshots (
        subscription_id, user_id, verified_email, verified_phone, captured_at
    ) VALUES (NEW.id, NEW.user_id, v_email, v_phone, NOW())
    ON CONFLICT (subscription_id) DO UPDATE
    SET verified_email = EXCLUDED.verified_email,
        verified_phone = EXCLUDED.verified_phone,
        captured_at = NOW();
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.capture_subscription_contacts()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS capture_subscription_contacts ON public.subscriptions;
CREATE TRIGGER capture_subscription_contacts
AFTER INSERT OR UPDATE OF start_date, end_date ON public.subscriptions
FOR EACH ROW EXECUTE FUNCTION private.capture_subscription_contacts();

-- Only exact username discovery remains public. The signature is preserved for
-- installed clients, but email/phone methods now fail closed.
CREATE OR REPLACE FUNCTION public.search_friend(p_method TEXT, p_query TEXT)
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
    v_query TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF LOWER(BTRIM(COALESCE(p_method, ''))) <> 'username' THEN
        RAISE EXCEPTION 'invalid_search_method' USING ERRCODE = '22023';
    END IF;
    v_query := private.normalize_friend_username(p_query);
    PERFORM private.consume_friend_search_budget(v_user);

    RETURN QUERY
    SELECT
        u.id, u.display_name, u.username, u.avatar_url,
        u.study_points, u.streak_days, u.user_level,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS outgoing
                JOIN public.friends AS incoming
                  ON incoming.user_id = outgoing.friend_id
                 AND incoming.friend_id = outgoing.user_id
                 AND incoming.status = 'accepted'
                WHERE outgoing.user_id = v_user
                  AND outgoing.friend_id = u.id
                  AND outgoing.status = 'accepted'
            ) THEN 'accepted'
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS f
                WHERE f.user_id = v_user AND f.friend_id = u.id
                  AND f.status = 'pending'
            ) THEN 'outgoing_pending'
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS f
                WHERE f.user_id = u.id AND f.friend_id = v_user
                  AND f.status = 'pending'
            ) THEN 'incoming_pending'
            WHEN EXISTS (
                SELECT 1 FROM public.friends AS f
                WHERE ((f.user_id = v_user AND f.friend_id = u.id)
                    OR (f.user_id = u.id AND f.friend_id = v_user))
                  AND f.status = 'rejected'
            ) THEN 'rejected'
            ELSE 'none'
        END
    FROM public.users AS u
    WHERE u.id <> v_user
      AND LOWER(BTRIM(u.username)) = v_query
    ORDER BY u.id
    LIMIT 1;
END;
$$;

-- One verified implementation owns every onboarding overload so older clients
-- cannot bypass the contact gate.
CREATE OR REPLACE FUNCTION private.complete_verified_onboarding(
    p_display_name TEXT,
    p_username TEXT,
    p_age INT,
    p_phone TEXT,
    p_account_role TEXT,
    p_interface_locale TEXT,
    p_learning_locale TEXT,
    p_reminder_time TEXT,
    p_study_end_time TEXT,
    p_daily_target_words INT,
    p_native_language_code TEXT,
    p_learning_language_code TEXT,
    p_proficiency_level TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user UUID := (SELECT auth.uid());
    v_phone TEXT := private.normalize_account_phone(p_phone);
    v_auth_phone TEXT;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
    END IF;
    IF BTRIM(COALESCE(p_display_name, '')) = ''
       OR BTRIM(COALESCE(p_username, '')) !~ '^[a-zA-Z0-9_]{3,20}$'
       OR p_age IS NULL OR p_age NOT BETWEEN 1 AND 120
       OR p_account_role NOT IN ('personal', 'parent')
       OR p_interface_locale !~ '^[a-z]{2,3}-[A-Z]{2}$'
       OR p_learning_locale !~ '^[a-z]{2,3}-[A-Z]{2}$'
       OR p_reminder_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       OR p_study_end_time !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
       OR p_reminder_time::TIME = p_study_end_time::TIME
       OR p_daily_target_words IS NULL OR p_daily_target_words <= 0
       OR p_native_language_code NOT IN ('vi', 'en')
       OR p_learning_language_code NOT IN ('vi', 'en')
       OR p_native_language_code = p_learning_language_code
       OR p_proficiency_level NOT IN ('beginner', 'intermediate', 'advanced') THEN
        RAISE EXCEPTION 'invalid_onboarding_data' USING ERRCODE = '22023';
    END IF;

    SELECT CASE WHEN phone IS NOT NULL
                THEN private.normalize_account_phone(phone) END
    INTO v_auth_phone
    FROM auth.users
    WHERE id = v_user
      AND email_confirmed_at IS NOT NULL
      AND phone_confirmed_at IS NOT NULL;
    IF v_auth_phone IS NULL OR v_auth_phone <> v_phone THEN
        RAISE EXCEPTION 'verified_contacts_required' USING ERRCODE = '22023';
    END IF;

    PERFORM public.sync_my_verified_email();
    PERFORM public.sync_my_verified_phone();

    UPDATE public.users
    SET display_name = BTRIM(p_display_name),
        username = LOWER(BTRIM(p_username)),
        age = p_age,
        phone = v_phone,
        account_role = p_account_role,
        onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = v_user;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.user_settings (
        user_id, interface_locale, learning_locale, reminder_time,
        study_end_time, daily_target_words
    ) VALUES (
        v_user, p_interface_locale, p_learning_locale, p_reminder_time,
        p_study_end_time, p_daily_target_words
    ) ON CONFLICT (user_id) DO UPDATE
    SET interface_locale = EXCLUDED.interface_locale,
        learning_locale = EXCLUDED.learning_locale,
        reminder_time = EXCLUDED.reminder_time,
        study_end_time = EXCLUDED.study_end_time,
        daily_target_words = EXCLUDED.daily_target_words;

    INSERT INTO public.user_language_profiles (
        user_id, native_language_code, learning_language_code, proficiency_level
    ) VALUES (
        v_user, p_native_language_code, p_learning_language_code,
        p_proficiency_level
    ) ON CONFLICT (user_id) DO UPDATE
    SET native_language_code = EXCLUDED.native_language_code,
        learning_language_code = EXCLUDED.learning_language_code,
        proficiency_level = EXCLUDED.proficiency_level,
        updated_at = NOW();
    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION private.complete_verified_onboarding(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
    p_display_name TEXT, p_username TEXT, p_age INT, p_phone TEXT,
    p_account_role TEXT, p_interface_locale TEXT, p_learning_locale TEXT,
    p_reminder_time TEXT, p_study_end_time TEXT, p_daily_target_words INT,
    p_native_language_code TEXT, p_learning_language_code TEXT,
    p_proficiency_level TEXT
) RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.complete_verified_onboarding(
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13
    );
$$;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
    p_display_name TEXT, p_username TEXT, p_age INT, p_phone TEXT,
    p_account_role TEXT, p_interface_locale TEXT, p_learning_locale TEXT,
    p_reminder_time TEXT, p_study_end_time TEXT, p_daily_target_words INT
) RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.complete_verified_onboarding(
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'vi','en','beginner'
    );
$$;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
    p_display_name TEXT, p_username TEXT, p_age INT, p_phone TEXT,
    p_account_role TEXT, p_reminder_time TEXT, p_study_end_time TEXT,
    p_daily_target_words INT, p_native_language_code TEXT,
    p_learning_language_code TEXT, p_proficiency_level TEXT
) RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.complete_verified_onboarding(
        $1,$2,$3,$4,$5,'vi-VN','en-US',$6,$7,$8,$9,$10,$11
    );
$$;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
    p_display_name TEXT, p_username TEXT, p_age INT, p_phone TEXT,
    p_account_role TEXT, p_reminder_time TEXT, p_study_end_time TEXT,
    p_daily_target_words INT
) RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.complete_verified_onboarding(
        $1,$2,$3,$4,$5,'vi-VN','en-US',$6,$7,$8,'vi','en','beginner'
    );
$$;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
    p_display_name TEXT, p_username TEXT, p_age INT, p_phone TEXT,
    p_account_role TEXT, p_reminder_time TEXT, p_daily_target_words INT
) RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.complete_verified_onboarding(
        $1,$2,$3,$4,$5,'vi-VN','en-US',$6,
        CASE WHEN $6 ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
             THEN SUBSTRING(($6::TIME + INTERVAL '1 hour')::TEXT FROM 1 FOR 5)
             ELSE $6 END,
        $7,'vi','en','beginner'
    );
$$;

REVOKE ALL ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, INT
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.sync_my_verified_email(),
    public.sync_my_verified_phone(),
    public.get_my_account_contact_settings(),
    public.update_my_account_contact_visibility(BOOLEAN, BOOLEAN),
    public.get_accepted_friend_contact(UUID)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_my_verified_email(),
    public.sync_my_verified_phone(),
    public.get_my_account_contact_settings(),
    public.update_my_account_contact_visibility(BOOLEAN, BOOLEAN),
    public.get_accepted_friend_contact(UUID)
TO authenticated;

REVOKE ALL ON FUNCTION public.search_friend(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_friend(TEXT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,INT,TEXT,TEXT,TEXT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,INT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,INT,TEXT,TEXT,TEXT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,INT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,INT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,INT,TEXT,TEXT,TEXT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,INT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,INT,TEXT,TEXT,TEXT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,TEXT,INT
), public.complete_onboarding(
    TEXT,TEXT,INT,TEXT,TEXT,TEXT,INT
) TO authenticated;

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
    PERFORM private.normalize_account_phone(p_phone);
    RETURN TRUE;
EXCEPTION WHEN SQLSTATE '22023' THEN RETURN FALSE;
END;
$$;

COMMENT ON TABLE private.account_contact_settings IS
'Owner contact visibility. Flags default off and never enable friend search.';
COMMENT ON TABLE private.account_contact_history IS
'Private verified-contact history for abuse and promotion review.';
COMMENT ON TABLE private.subscription_contact_snapshots IS
'Verified contacts captured only when a subscription starts or renews.';
COMMENT ON FUNCTION public.get_accepted_friend_contact(UUID) IS
'Returns explicitly shared contacts only for a mutually accepted friendship.';

COMMIT;
