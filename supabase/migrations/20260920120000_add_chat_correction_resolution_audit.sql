BEGIN;

ALTER TABLE public.chat_corrections
ADD COLUMN updated_at TIMESTAMPTZ;

UPDATE public.chat_corrections
SET updated_at = COALESCE(accepted_at, rejected_at, created_at);

ALTER TABLE public.chat_corrections
ALTER COLUMN updated_at SET DEFAULT NOW(),
ALTER COLUMN updated_at SET NOT NULL;

CREATE UNIQUE INDEX chat_corrections_one_proposed_per_author
ON public.chat_corrections(message_id, author_id)
WHERE status = 'proposed';

CREATE TABLE public.chat_correction_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    correction_id UUID NOT NULL
        REFERENCES public.chat_corrections(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('proposed', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (correction_id, action)
);

CREATE INDEX chat_correction_events_order
ON public.chat_correction_events(correction_id, created_at, id);

-- Existing corrections gain the same audit history as rows created after C6C.
INSERT INTO public.chat_correction_events(
    correction_id, actor_id, action, created_at
)
SELECT id, author_id, 'proposed', created_at
FROM public.chat_corrections;

INSERT INTO public.chat_correction_events(
    correction_id, actor_id, action, created_at
)
SELECT
    id,
    CASE status WHEN 'accepted' THEN accepted_by ELSE rejected_by END,
    status,
    CASE status WHEN 'accepted' THEN accepted_at ELSE rejected_at END
FROM public.chat_corrections
WHERE status IN ('accepted', 'rejected');

CREATE FUNCTION private.stamp_chat_correction_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.updated_at := NEW.created_at;
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        NEW.updated_at := NOW();
    ELSIF NEW.updated_at IS DISTINCT FROM OLD.updated_at THEN
        RAISE EXCEPTION 'Correction update timestamp is server-owned'
            USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.stamp_chat_correction_updated_at()
FROM PUBLIC, anon, authenticated, service_role;
-- The name deliberately sorts after validate_chat_correction so the existing
-- C2/C4 immutable-content guard evaluates caller input before this server stamp.
CREATE TRIGGER zz_stamp_chat_correction_updated_at
BEFORE INSERT OR UPDATE ON public.chat_corrections
FOR EACH ROW EXECUTE FUNCTION private.stamp_chat_correction_updated_at();

CREATE FUNCTION private.guard_chat_correction_event_mutation()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_owner NAME;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Correction audit events are immutable'
            USING ERRCODE = '22023';
    END IF;
    IF TG_OP = 'DELETE' THEN
        -- Retention/account deletion may cascade from the parent correction.
        -- A direct event delete still sees its parent and remains forbidden.
        IF EXISTS (
            SELECT 1 FROM public.chat_corrections c
            WHERE c.id = OLD.correction_id
        ) THEN
            RAISE EXCEPTION 'Correction audit events are immutable'
                USING ERRCODE = '22023';
        END IF;
        RETURN OLD;
    END IF;
    SELECT pg_get_userbyid(c.relowner) INTO v_owner
    FROM pg_catalog.pg_class c
    WHERE c.oid = 'public.chat_correction_events'::regclass;
    IF current_user IS DISTINCT FROM v_owner THEN
        RAISE EXCEPTION 'Correction audit events are trigger-owned'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_correction_event_mutation()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER guard_chat_correction_event_mutation
BEFORE INSERT OR UPDATE OR DELETE ON public.chat_correction_events
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_correction_event_mutation();

CREATE FUNCTION private.audit_chat_correction()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.chat_correction_events(
            correction_id, actor_id, action, created_at
        ) VALUES (NEW.id, NEW.author_id, 'proposed', NEW.created_at);
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO public.chat_correction_events(
            correction_id, actor_id, action, created_at
        ) VALUES (
            NEW.id,
            CASE NEW.status
                WHEN 'accepted' THEN NEW.accepted_by
                ELSE NEW.rejected_by
            END,
            NEW.status,
            CASE NEW.status
                WHEN 'accepted' THEN NEW.accepted_at
                ELSE NEW.rejected_at
            END
        );
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.audit_chat_correction()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER audit_chat_correction
AFTER INSERT OR UPDATE ON public.chat_corrections
FOR EACH ROW EXECUTE FUNCTION private.audit_chat_correction();

CREATE FUNCTION private.can_read_chat_correction_event(p_correction UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.chat_corrections c
        WHERE c.id = p_correction
          AND private.can_read_chat_message(c.message_id)
    );
$$;
REVOKE ALL ON FUNCTION private.can_read_chat_correction_event(UUID)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_read_chat_correction_event(UUID)
TO authenticated;

ALTER TABLE public.chat_correction_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chat_correction_events
FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.chat_correction_events TO authenticated, service_role;
CREATE POLICY chat_correction_event_member_read
ON public.chat_correction_events FOR SELECT TO authenticated
USING (private.can_read_chat_correction_event(correction_id));

CREATE FUNCTION public.resolve_chat_correction(
    p_correction_id UUID,
    p_decision TEXT
)
RETURNS public.chat_corrections
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
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
    FROM public.chat_corrections c
    WHERE c.id = p_correction_id
    FOR UPDATE;

    SELECT m.sender_id, m.conversation_id
    INTO v_sender, v_conversation
    FROM public.chat_operational_messages m
    WHERE m.id = v_correction.message_id;

    IF v_correction.id IS NULL
       OR v_sender IS DISTINCT FROM v_actor
       OR NOT private.can_read_chat_message(v_correction.message_id)
       OR (SELECT count(*) FROM public.chat_members m
           WHERE m.conversation_id = v_conversation AND m.left_at IS NULL) <> 2 THEN
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
REVOKE ALL ON FUNCTION public.resolve_chat_correction(UUID, TEXT)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.resolve_chat_correction(UUID, TEXT)
TO authenticated;

COMMENT ON TABLE public.chat_correction_events IS
'Append-only Operational Chat correction audit. Never a Training source.';
COMMENT ON FUNCTION public.resolve_chat_correction(UUID, TEXT) IS
'C6C sender-only, row-locked and idempotent correction decision API.';

COMMIT;
