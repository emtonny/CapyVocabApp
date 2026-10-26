CREATE TABLE public.lesson_completion_receipts (
    result_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    mission_date DATE NOT NULL,
    total_items INTEGER NOT NULL CHECK (total_items > 0),
    completed_items INTEGER NOT NULL CHECK (completed_items = total_items),
    source_revision_hash TEXT NOT NULL,
    rule_version TEXT NOT NULL,
    normalizer_version TEXT NOT NULL,
    evidence JSONB NOT NULL CHECK (jsonb_typeof(evidence) = 'object'),
    completed_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT statement_timestamp(),
    reward_status TEXT NOT NULL DEFAULT 'pending',
    reward_yuzu INTEGER,
    rewarded_at TIMESTAMPTZ,
    UNIQUE (user_id, session_id)
);

ALTER TABLE public.lesson_completion_receipts ENABLE ROW LEVEL SECURITY;
CREATE POLICY lesson_receipt_owner_read
ON public.lesson_completion_receipts FOR SELECT TO authenticated
USING (auth.uid() = user_id);
GRANT SELECT ON public.lesson_completion_receipts TO authenticated;
