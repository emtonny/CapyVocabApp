-- C4G prerequisite for asynchronous post-commit Edge Function wake-ups.
-- Supabase treats CREATE EXTENSION as enabling the managed extension.
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
