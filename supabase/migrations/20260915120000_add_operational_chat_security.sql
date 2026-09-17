-- C2 operational chat only. Legacy chat_messages and Training remain unchanged.
-- No guessed recipients/backfill, client edit/delete, retention worker or Gemini calls.

CREATE FUNCTION private.guard_chat_friend_acceptance()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_user UUID := (SELECT auth.uid()); v_reciprocal BOOLEAN;
BEGIN
    -- Trusted DB maintenance/service roles retain their existing authority.
    IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
    IF v_user IS NULL OR NEW.user_id = NEW.friend_id OR NEW.status IS NULL THEN
        RAISE EXCEPTION 'Invalid friendship actor' USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'UPDATE' AND
       (NEW.user_id <> OLD.user_id OR NEW.friend_id <> OLD.friend_id) THEN
        RAISE EXCEPTION 'Friendship identity is immutable' USING ERRCODE = '42501';
    END IF;
    SELECT EXISTS (SELECT 1 FROM public.friends f
        WHERE f.user_id = NEW.friend_id AND f.friend_id = NEW.user_id
          AND f.status = 'accepted') INTO v_reciprocal;
    IF TG_OP = 'INSERT' THEN
        IF NEW.user_id <> v_user OR
           NOT (NEW.status = 'pending' OR (NEW.status = 'accepted' AND v_reciprocal)) THEN
            RAISE EXCEPTION 'Friend request must be sent as pending' USING ERRCODE = '42501';
        END IF;
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        IF NOT ((v_user = OLD.friend_id AND OLD.status = 'pending'
                 AND NEW.status IN ('accepted', 'rejected')) OR
                (v_user = OLD.user_id AND NEW.status = 'accepted' AND v_reciprocal)) THEN
            RAISE EXCEPTION 'Only the recipient may accept a pending request' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_friend_acceptance() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_chat_friend_acceptance BEFORE INSERT OR UPDATE ON public.friends
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_friend_acceptance();

CREATE TABLE public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind TEXT NOT NULL DEFAULT 'direct' CHECK (kind = 'direct'),
    participant_low UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    participant_high UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_message_at TIMESTAMPTZ,
    CHECK (participant_low < participant_high),
    UNIQUE (participant_low, participant_high)
);
CREATE TABLE public.chat_members (
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    PRIMARY KEY (conversation_id, user_id),
    CHECK (left_at IS NULL OR left_at >= joined_at)
);
CREATE TABLE public.chat_operational_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    raw_text TEXT NOT NULL CHECK (char_length(raw_text) BETWEEN 1 AND 4000 AND raw_text ~ '[^[:space:]]'),
    source_language_code TEXT NOT NULL CHECK (source_language_code IN ('vi', 'en')),
    client_generated_id UUID NOT NULL,
    client_created_at TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    moderation_state TEXT NOT NULL DEFAULT 'visible' CHECK (moderation_state IN ('visible', 'held', 'removed')),
    FOREIGN KEY (conversation_id, sender_id) REFERENCES public.chat_members(conversation_id, user_id) ON DELETE CASCADE,
    UNIQUE (sender_id, client_generated_id)
);
CREATE TABLE public.chat_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.chat_operational_messages(id) ON DELETE CASCADE,
    target_language_code TEXT NOT NULL CHECK (target_language_code IN ('vi', 'en')),
    translator_version TEXT NOT NULL CHECK (char_length(translator_version) BETWEEN 1 AND 80),
    translated_text TEXT,
    provider TEXT NOT NULL DEFAULT 'gemini' CHECK (provider = 'gemini'),
    model TEXT,
    prompt_version TEXT,
    status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'succeeded', 'failed')),
    attempt_count INT NOT NULL DEFAULT 0 CHECK (attempt_count BETWEEN 0 AND 10),
    next_attempt_at TIMESTAMPTZ,
    error_code TEXT CHECK (error_code IS NULL OR error_code ~ '^[A-Z0-9_]{1,64}$'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE (message_id, target_language_code, translator_version),
    CHECK ((status = 'succeeded' AND translated_text IS NOT NULL
            AND char_length(translated_text) BETWEEN 1 AND 16000 AND translated_text ~ '[^[:space:]]'
            AND model IS NOT NULL AND prompt_version IS NOT NULL AND completed_at IS NOT NULL)
           OR (status <> 'succeeded' AND translated_text IS NULL))
);
CREATE TABLE public.chat_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.chat_operational_messages(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_language_code TEXT NOT NULL CHECK (target_language_code IN ('vi', 'en')),
    proposed_text TEXT NOT NULL CHECK (char_length(proposed_text) BETWEEN 1 AND 4000 AND proposed_text ~ '[^[:space:]]'),
    status TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed', 'accepted', 'rejected')),
    accepted_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    accepted_at TIMESTAMPTZ,
    rejected_by UUID REFERENCES public.users(id) ON DELETE CASCADE,
    rejected_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK ((status = 'proposed' AND accepted_by IS NULL AND accepted_at IS NULL AND rejected_by IS NULL AND rejected_at IS NULL)
        OR (status = 'accepted' AND accepted_by IS NOT NULL AND accepted_at IS NOT NULL AND rejected_by IS NULL AND rejected_at IS NULL)
        OR (status = 'rejected' AND rejected_by IS NOT NULL AND rejected_at IS NOT NULL AND accepted_by IS NULL AND accepted_at IS NULL))
);

CREATE INDEX chat_members_active_owner ON public.chat_members(user_id, conversation_id) WHERE left_at IS NULL;
CREATE INDEX chat_messages_conversation_order ON public.chat_operational_messages(conversation_id, sent_at, id);
CREATE INDEX chat_translations_retry ON public.chat_translations(status, next_attempt_at) WHERE status IN ('queued', 'failed');
CREATE INDEX chat_corrections_message_order ON public.chat_corrections(message_id, created_at, id);

CREATE FUNCTION private.guard_chat_member()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.chat_conversations c WHERE c.id = NEW.conversation_id
        AND NEW.user_id IN (c.participant_low, c.participant_high)) THEN
        RAISE EXCEPTION 'Direct chat only permits its two participants' USING ERRCODE = '22023';
    END IF;
    IF TG_OP = 'UPDATE' AND (NEW.conversation_id <> OLD.conversation_id OR NEW.user_id <> OLD.user_id) THEN
        RAISE EXCEPTION 'Membership identity is immutable' USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_member() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_chat_member BEFORE INSERT OR UPDATE ON public.chat_members
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_member();

CREATE FUNCTION private.guard_chat_raw_message()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN NEW.sent_at := NOW();
    ELSIF ROW(NEW.id, NEW.conversation_id, NEW.sender_id, NEW.raw_text, NEW.source_language_code,
              NEW.client_generated_id, NEW.client_created_at, NEW.sent_at)
          IS DISTINCT FROM
          ROW(OLD.id, OLD.conversation_id, OLD.sender_id, OLD.raw_text, OLD.source_language_code,
              OLD.client_generated_id, OLD.client_created_at, OLD.sent_at) THEN
        RAISE EXCEPTION 'Raw message identity/content is immutable' USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_chat_raw_message() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER guard_chat_raw_message BEFORE INSERT OR UPDATE ON public.chat_operational_messages
FOR EACH ROW EXECUTE FUNCTION private.guard_chat_raw_message();

-- Bind authorization to auth.uid(), never to a caller-provided owner identity.
-- Definer avoids recursive chat_members RLS; no helper returns another user's rows.
CREATE FUNCTION private.is_active_chat_member(p_conversation UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (SELECT 1 FROM public.chat_members m
        WHERE m.conversation_id = p_conversation AND m.user_id = (SELECT auth.uid()) AND m.left_at IS NULL);
$$;
CREATE FUNCTION private.can_read_chat_message(p_message UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (SELECT 1 FROM public.chat_operational_messages m
        WHERE m.id = p_message AND m.deleted_at IS NULL AND m.moderation_state = 'visible'
          AND private.is_active_chat_member(m.conversation_id));
$$;
CREATE FUNCTION private.can_insert_chat_message(p_conversation UUID, p_source TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.is_active_chat_member(p_conversation)
        AND (SELECT count(*) FROM public.chat_members WHERE conversation_id = p_conversation AND left_at IS NULL) = 2
        AND EXISTS (SELECT 1 FROM public.user_language_profiles p
            WHERE p.user_id = (SELECT auth.uid()) AND p.native_language_code = p_source);
$$;
CREATE FUNCTION private.can_propose_chat_correction(p_message UUID, p_target TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT private.can_read_chat_message(p_message) AND EXISTS (
        SELECT 1 FROM public.chat_operational_messages m JOIN public.user_language_profiles p
          ON p.user_id = (SELECT auth.uid())
        WHERE m.id = p_message AND m.sender_id <> (SELECT auth.uid())
          AND m.source_language_code <> p_target AND p.native_language_code = p_target);
$$;
REVOKE ALL ON FUNCTION private.is_active_chat_member(UUID), private.can_read_chat_message(UUID),
    private.can_insert_chat_message(UUID, TEXT), private.can_propose_chat_correction(UUID, TEXT)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.is_active_chat_member(UUID), private.can_read_chat_message(UUID),
    private.can_insert_chat_message(UUID, TEXT), private.can_propose_chat_correction(UUID, TEXT)
TO authenticated;

CREATE FUNCTION private.open_direct_chat(p_peer UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user UUID := (SELECT auth.uid()); v_low UUID; v_high UUID; v_id UUID;
BEGIN
    IF v_user IS NULL OR p_peer IS NULL OR p_peer = v_user THEN
        RAISE EXCEPTION 'Invalid chat actor' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.friends WHERE user_id = v_user AND friend_id = p_peer AND status = 'accepted')
       OR NOT EXISTS (SELECT 1 FROM public.friends WHERE user_id = p_peer AND friend_id = v_user AND status = 'accepted') THEN
        RAISE EXCEPTION 'Mutually accepted friendship required' USING ERRCODE = '42501';
    END IF;
    IF (SELECT count(*) FROM public.user_language_profiles WHERE user_id IN (v_user, p_peer)) <> 2 THEN
        RAISE EXCEPTION 'Both language profiles are required' USING ERRCODE = '22023';
    END IF;
    v_low := LEAST(v_user, p_peer); v_high := GREATEST(v_user, p_peer);
    INSERT INTO public.chat_conversations(participant_low, participant_high) VALUES (v_low, v_high)
    ON CONFLICT (participant_low, participant_high) DO NOTHING;
    SELECT id INTO v_id FROM public.chat_conversations WHERE participant_low = v_low AND participant_high = v_high;
    INSERT INTO public.chat_members(conversation_id, user_id) VALUES (v_id, v_user), (v_id, p_peer)
    ON CONFLICT (conversation_id, user_id) DO NOTHING;
    IF (SELECT count(*) FROM public.chat_members WHERE conversation_id = v_id AND left_at IS NULL) <> 2 THEN
        RAISE EXCEPTION 'Conversation membership is inactive' USING ERRCODE = '42501';
    END IF;
    RETURN v_id;
END;
$$;
CREATE FUNCTION public.open_direct_chat(p_peer_id UUID)
RETURNS UUID LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
    SELECT private.open_direct_chat($1);
$$;
REVOKE ALL ON FUNCTION private.open_direct_chat(UUID), public.open_direct_chat(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.open_direct_chat(UUID), public.open_direct_chat(UUID) TO authenticated;

CREATE FUNCTION private.validate_chat_derived_record()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE v_sender UUID; v_source TEXT;
BEGIN
    SELECT sender_id, source_language_code INTO v_sender, v_source FROM public.chat_operational_messages WHERE id = NEW.message_id;
    IF v_sender IS NULL OR NEW.target_language_code = v_source THEN
        RAISE EXCEPTION 'Derived record needs a different target language' USING ERRCODE = '22023';
    END IF;
    IF TG_OP = 'UPDATE' AND (NEW.id <> OLD.id OR NEW.message_id <> OLD.message_id OR NEW.target_language_code <> OLD.target_language_code) THEN
        RAISE EXCEPTION 'Derived record identity is immutable' USING ERRCODE = '22023';
    END IF;
    IF TG_TABLE_NAME = 'chat_translations' THEN
        IF TG_OP = 'UPDATE' THEN
            IF NEW.translator_version <> OLD.translator_version OR (OLD.status = 'succeeded' AND NEW IS DISTINCT FROM OLD) THEN
                RAISE EXCEPTION 'Successful translation is immutable' USING ERRCODE = '22023';
            END IF;
        END IF;
    ELSE
        IF NEW.author_id = v_sender OR
           NOT EXISTS (SELECT 1 FROM public.chat_members m JOIN public.chat_operational_messages msg ON msg.conversation_id = m.conversation_id
                       WHERE msg.id = NEW.message_id AND m.user_id = NEW.author_id AND m.left_at IS NULL) THEN
            RAISE EXCEPTION 'Correction must come from the other member' USING ERRCODE = '22023';
        END IF;
        IF TG_OP = 'UPDATE' THEN
            IF NEW.author_id <> OLD.author_id OR NEW.proposed_text <> OLD.proposed_text OR NEW.created_at <> OLD.created_at
               OR (OLD.status <> 'proposed' AND NEW IS DISTINCT FROM OLD) THEN
                RAISE EXCEPTION 'Correction content/decision is immutable' USING ERRCODE = '22023';
            END IF;
        END IF;
        IF (NEW.accepted_by IS NOT NULL AND NEW.accepted_by <> v_sender) OR
           (NEW.rejected_by IS NOT NULL AND NEW.rejected_by <> v_sender) THEN
            RAISE EXCEPTION 'Only the source sender decides a correction' USING ERRCODE = '22023';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.validate_chat_derived_record() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER validate_chat_translation BEFORE INSERT OR UPDATE ON public.chat_translations
FOR EACH ROW EXECUTE FUNCTION private.validate_chat_derived_record();
CREATE TRIGGER validate_chat_correction BEFORE INSERT OR UPDATE ON public.chat_corrections
FOR EACH ROW EXECUTE FUNCTION private.validate_chat_derived_record();

CREATE FUNCTION private.touch_chat_conversation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    UPDATE public.chat_conversations SET last_message_at = GREATEST(last_message_at, NEW.sent_at) WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.touch_chat_conversation() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER touch_chat_conversation AFTER INSERT ON public.chat_operational_messages
FOR EACH ROW EXECUTE FUNCTION private.touch_chat_conversation();

ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_operational_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_corrections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.chat_conversations, public.chat_members, public.chat_operational_messages,
    public.chat_translations, public.chat_corrections FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_conversations, public.chat_members, public.chat_operational_messages,
    public.chat_translations, public.chat_corrections TO authenticated;
GRANT INSERT (id, conversation_id, sender_id, raw_text, source_language_code, client_generated_id, client_created_at)
ON public.chat_operational_messages TO authenticated;
GRANT INSERT (id, message_id, author_id, target_language_code, proposed_text) ON public.chat_corrections TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chat_conversations, public.chat_members, public.chat_operational_messages,
    public.chat_translations, public.chat_corrections TO service_role;

CREATE POLICY chat_conversation_member_read ON public.chat_conversations FOR SELECT TO authenticated
USING (private.is_active_chat_member(id));
CREATE POLICY chat_members_member_read ON public.chat_members FOR SELECT TO authenticated
USING (private.is_active_chat_member(conversation_id));
CREATE POLICY chat_message_member_read ON public.chat_operational_messages FOR SELECT TO authenticated
USING (deleted_at IS NULL AND moderation_state = 'visible' AND private.is_active_chat_member(conversation_id));
CREATE POLICY chat_message_sender_insert ON public.chat_operational_messages FOR INSERT TO authenticated
WITH CHECK (sender_id = (SELECT auth.uid()) AND private.can_insert_chat_message(conversation_id, source_language_code));
CREATE POLICY chat_translation_member_read ON public.chat_translations FOR SELECT TO authenticated
USING (private.can_read_chat_message(message_id));
CREATE POLICY chat_correction_member_read ON public.chat_corrections FOR SELECT TO authenticated
USING (private.can_read_chat_message(message_id));
CREATE POLICY chat_correction_other_member_insert ON public.chat_corrections FOR INSERT TO authenticated
WITH CHECK (author_id = (SELECT auth.uid()) AND private.can_propose_chat_correction(message_id, target_language_code));

-- Default replica identity avoids including raw text in DELETE old-record payloads.
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations, public.chat_members,
    public.chat_operational_messages, public.chat_translations, public.chat_corrections;
COMMENT ON TABLE public.chat_operational_messages IS 'Operational human chat only. Never directly export or connect to a trainer. Legacy chat_messages is unchanged.';
COMMENT ON TABLE public.chat_translations IS 'Operational Gemini output only, service-written. Not a Training source.';
