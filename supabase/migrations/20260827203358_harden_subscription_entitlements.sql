BEGIN;

-- A subscription is the current entitlement record for one user. Abort instead
-- of silently deleting or merging billing data if legacy duplicates exist.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.subscriptions
        GROUP BY user_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Cannot enforce subscriptions_user_id_key: duplicate user_id rows exist';
    END IF;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.subscriptions'::regclass
          AND conname = 'subscriptions_user_id_key'
          AND contype = 'u'
    ) THEN
        ALTER TABLE public.subscriptions
            ADD CONSTRAINT subscriptions_user_id_key UNIQUE (user_id);
    END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS subscriptions_user_status_end_date_idx
ON public.subscriptions (user_id, status, end_date DESC);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view their subscriptions"
ON public.subscriptions;

CREATE POLICY "Users view their subscriptions"
ON public.subscriptions
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON TABLE public.subscriptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.subscriptions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.subscriptions
TO service_role;

COMMIT;
