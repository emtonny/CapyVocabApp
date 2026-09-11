BEGIN;

-- Supabase default privileges may grant service_role more access than this
-- ledger needs. Keep deletion owned by database maintenance jobs only.
REVOKE ALL ON TABLE public.ai_scan_requests FROM service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.ai_scan_requests TO service_role;

COMMIT;
