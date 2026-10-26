BEGIN;

-- Supabase default privileges may grant service_role table DML. Keep the
-- verification RPC as the only mutation path so transition checks and audit
-- cannot be bypassed.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE public.teacher_profiles
FROM service_role;
GRANT SELECT ON TABLE public.teacher_profiles TO service_role;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
ON TABLE private.teacher_verification_events
FROM service_role;
GRANT SELECT ON TABLE private.teacher_verification_events TO service_role;
REVOKE ALL ON SEQUENCE private.teacher_verification_events_id_seq
FROM service_role;

CREATE OR REPLACE FUNCTION public.set_teacher_verification(
    p_teacher_user_id UUID,
    p_status TEXT,
    p_reason_code TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_old_status TEXT;
    v_request_role TEXT := COALESCE(
        NULLIF(current_setting('request.jwt.claim.role', true), ''),
        (
            NULLIF(current_setting('request.jwt.claims', true), '')::JSONB
            ->> 'role'
        ),
        NULLIF(current_setting('role', true), 'none'),
        current_user
    );
BEGIN
    IF v_request_role <> 'service_role' THEN
        RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
    END IF;

    IF p_status IS NULL
       OR p_status NOT IN ('pending', 'verified', 'suspended', 'rejected')
       OR (
           p_reason_code IS NOT NULL
           AND p_reason_code !~ '^[a-z0-9_]{1,64}$'
       ) THEN
        RAISE EXCEPTION 'invalid_teacher_verification'
            USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.users
        WHERE id = p_teacher_user_id
          AND account_role = 'teacher'
    ) THEN
        RAISE EXCEPTION 'teacher_profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    SELECT verification_status
    INTO v_old_status
    FROM public.teacher_profiles
    WHERE user_id = p_teacher_user_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'teacher_profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    IF v_old_status <> p_status AND NOT (
        (v_old_status = 'pending' AND p_status IN ('verified', 'rejected'))
        OR (v_old_status = 'verified' AND p_status = 'suspended')
        OR (v_old_status = 'suspended' AND p_status IN ('verified', 'rejected'))
        OR (v_old_status = 'rejected' AND p_status = 'pending')
    ) THEN
        RAISE EXCEPTION 'invalid_teacher_verification_transition'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.teacher_profiles
    SET verification_status = p_status,
        reviewed_at = CASE
            WHEN p_status = 'pending' THEN NULL
            ELSE NOW()
        END,
        reviewed_by = CASE
            WHEN p_status = 'pending' THEN NULL
            ELSE (SELECT auth.uid())
        END,
        decision_reason_code = p_reason_code,
        updated_at = NOW()
    WHERE user_id = p_teacher_user_id;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.set_teacher_verification(UUID, TEXT, TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_teacher_verification(UUID, TEXT, TEXT)
TO service_role;

COMMIT;
