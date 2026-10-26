-- GT2-only additions layered over group_gt1_bootstrap.sql and GT1 migrations.
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';
CREATE PUBLICATION supabase_realtime;

CREATE FUNCTION public.gt2_assert(p_condition BOOLEAN, p_label TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_condition IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'GT2 assertion failed: %', p_label;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;

CREATE FUNCTION public.gt2_expect_error(
    p_sql TEXT,
    p_state TEXT,
    p_label TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE v_state TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    END;
    IF v_state IS DISTINCT FROM p_state THEN
        RAISE EXCEPTION 'GT2 expected error failed: %, expected %, got %',
            p_label, p_state, v_state;
    END IF;
    RAISE NOTICE 'PASS: %', p_label;
END;
$$;
