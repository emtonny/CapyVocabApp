BEGIN;

CREATE TABLE public.chat_slang_annotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL
        REFERENCES public.chat_operational_messages(id) ON DELETE CASCADE,
    correction_id UUID NOT NULL
        REFERENCES public.chat_corrections(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    span_text TEXT NOT NULL
        CHECK (char_length(span_text) BETWEEN 1 AND 4000
               AND span_text ~ '[^[:space:]]'),
    -- Zero-based, half-open Unicode code-point offsets into raw_text.
    span_start INTEGER NOT NULL CHECK (span_start >= 0),
    span_end INTEGER NOT NULL CHECK (span_end > span_start),
    tag_type TEXT NOT NULL CHECK (tag_type IN (
        'slang',
        'abbreviation',
        'informal_address',
        'idiom',
        'typo_or_phonetic_spelling',
        'other'
    )),
    normalized_source TEXT NOT NULL
        CHECK (char_length(normalized_source) BETWEEN 1 AND 4000
               AND normalized_source ~ '[^[:space:]]'),
    annotator_role TEXT NOT NULL DEFAULT 'source_speaker'
        CHECK (annotator_role = 'source_speaker'),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status = 'active'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (correction_id, created_by, span_start, span_end, tag_type,
            normalized_source)
);

CREATE INDEX chat_slang_annotations_message_order
ON public.chat_slang_annotations(message_id, created_at, id);

CREATE FUNCTION private.can_create_chat_slang_annotation(
    p_message UUID,
    p_correction UUID
)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.chat_operational_messages m
        JOIN public.chat_corrections c
          ON c.id = p_correction AND c.message_id = m.id
        WHERE m.id = p_message
          AND m.sender_id = (SELECT auth.uid())
          AND m.deleted_at IS NULL
          AND m.moderation_state = 'visible'
          AND c.status = 'accepted'
          AND c.accepted_by = (SELECT auth.uid())
          AND private.is_active_chat_member(m.conversation_id)
          AND (SELECT count(*) FROM public.chat_members cm
               WHERE cm.conversation_id = m.conversation_id
                 AND cm.left_at IS NULL) = 2
    );
$$;
REVOKE ALL ON FUNCTION private.can_create_chat_slang_annotation(UUID, UUID)
FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_create_chat_slang_annotation(UUID, UUID)
TO authenticated;

CREATE FUNCTION private.guard_chat_slang_annotation()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE
    v_raw TEXT;
    v_sender UUID;
    v_correction_message UUID;
    v_correction_status TEXT;
    v_accepted_by UUID;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Chat span annotations are immutable'
            USING ERRCODE = '22023';
    END IF;

    SELECT m.raw_text, m.sender_id
    INTO v_raw, v_sender
    FROM public.chat_operational_messages m
    WHERE m.id = NEW.message_id;

    SELECT c.message_id, c.status, c.accepted_by
    INTO v_correction_message, v_correction_status, v_accepted_by
    FROM public.chat_corrections c
    WHERE c.id = NEW.correction_id;

    IF NEW.created_by IS DISTINCT FROM (SELECT auth.uid())
       OR v_raw IS NULL
       OR v_correction_message IS DISTINCT FROM NEW.message_id
       OR v_correction_status IS DISTINCT FROM 'accepted'
       OR v_sender IS DISTINCT FROM NEW.created_by
       OR v_accepted_by IS DISTINCT FROM NEW.created_by THEN
        RAISE EXCEPTION 'Annotation requires an accepted correction and source sender'
            USING ERRCODE = '42501';
    END IF;

    IF NEW.span_end > char_length(v_raw)
       OR substring(v_raw FROM NEW.span_start + 1
                    FOR NEW.span_end - NEW.span_start) IS DISTINCT FROM NEW.span_text THEN
        RAISE EXCEPTION 'Annotation Unicode span does not match raw text'
            USING ERRCODE = '22023';
    END IF;

    NEW.annotator_role := 'source_speaker';
    NEW.status := 'active';
    NEW.created_at := NOW();
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_slang_annotation()
FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER guard_chat_slang_annotation
BEFORE INSERT OR UPDATE ON public.chat_slang_annotations
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_slang_annotation();

ALTER TABLE public.chat_slang_annotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chat_slang_annotations
FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.chat_slang_annotations TO authenticated, service_role;
GRANT INSERT (
    id, message_id, correction_id, created_by, span_text, span_start,
    span_end, tag_type, normalized_source
) ON public.chat_slang_annotations TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.chat_slang_annotations TO service_role;

CREATE POLICY chat_slang_annotation_member_read
ON public.chat_slang_annotations FOR SELECT TO authenticated
USING (private.can_read_chat_message(message_id));

CREATE POLICY chat_slang_annotation_source_insert
ON public.chat_slang_annotations FOR INSERT TO authenticated
WITH CHECK (
    created_by = (SELECT auth.uid())
    AND private.can_create_chat_slang_annotation(message_id, correction_id)
);

ALTER PUBLICATION supabase_realtime
ADD TABLE public.chat_slang_annotations;

COMMENT ON TABLE public.chat_slang_annotations IS
'C6D source-speaker Unicode span tags for accepted Operational Chat corrections. Never a Training source.';
COMMENT ON COLUMN public.chat_slang_annotations.span_start IS
'Zero-based inclusive Unicode code-point offset into chat_operational_messages.raw_text.';
COMMENT ON COLUMN public.chat_slang_annotations.span_end IS
'Zero-based exclusive Unicode code-point offset into chat_operational_messages.raw_text.';

COMMIT;
