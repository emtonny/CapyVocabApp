-- Local-only pg_net/pg_cron/Vault doubles for the isolated C4G SQL suite.
CREATE SCHEMA vault;
CREATE SCHEMA net;
CREATE SCHEMA cron;

CREATE TABLE vault.decrypted_secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    decrypted_secret TEXT NOT NULL
);

CREATE TABLE net.http_request_log (
    id BIGSERIAL PRIMARY KEY,
    url TEXT NOT NULL,
    body JSONB NOT NULL,
    params JSONB NOT NULL,
    headers JSONB NOT NULL,
    timeout_milliseconds INTEGER NOT NULL
);

CREATE FUNCTION net.http_post(
    url TEXT,
    body JSONB DEFAULT '{}'::jsonb,
    params JSONB DEFAULT '{}'::jsonb,
    headers JSONB DEFAULT '{"Content-Type":"application/json"}'::jsonb,
    timeout_milliseconds INTEGER DEFAULT 2000
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO net.http_request_log(
        url, body, params, headers, timeout_milliseconds
    ) VALUES (
        url, body, params, headers, timeout_milliseconds
    ) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE TABLE cron.job (
    jobid BIGSERIAL PRIMARY KEY,
    jobname TEXT NOT NULL UNIQUE,
    schedule TEXT NOT NULL,
    command TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE FUNCTION cron.schedule(
    p_jobname TEXT,
    p_schedule TEXT,
    p_command TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE v_id BIGINT;
BEGIN
    INSERT INTO cron.job(jobname, schedule, command)
    VALUES (p_jobname, p_schedule, p_command)
    ON CONFLICT (jobname) DO UPDATE
    SET schedule = EXCLUDED.schedule,
        command = EXCLUDED.command,
        active = TRUE
    RETURNING jobid INTO v_id;
    RETURN v_id;
END;
$$;

CREATE FUNCTION cron.unschedule(p_jobid BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM cron.job WHERE jobid = p_jobid;
    RETURN FOUND;
END;
$$;

REVOKE ALL ON SCHEMA vault, net, cron FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA vault, net, cron
FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA vault, net, cron
FROM PUBLIC, anon, authenticated, service_role;
