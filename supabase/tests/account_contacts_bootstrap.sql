-- Extra pre-migration objects for isolated account-contact verification.
ALTER TABLE public.users
    ADD COLUMN age INTEGER,
    ADD COLUMN account_role TEXT,
    ADD COLUMN onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.user_language_profiles
    ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE public.user_settings (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    interface_locale TEXT NOT NULL DEFAULT 'vi-VN',
    learning_locale TEXT NOT NULL DEFAULT 'en-US',
    reminder_time TEXT NOT NULL DEFAULT '20:00',
    study_end_time TEXT NOT NULL DEFAULT '21:00',
    daily_target_words INTEGER NOT NULL DEFAULT 10
);

CREATE TABLE public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
    plan_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, INT
) RETURNS BOOLEAN LANGUAGE sql AS $$ SELECT TRUE $$;
CREATE FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT
) RETURNS BOOLEAN LANGUAGE sql AS $$ SELECT TRUE $$;
CREATE FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT
) RETURNS BOOLEAN LANGUAGE sql AS $$ SELECT TRUE $$;
CREATE FUNCTION private.complete_onboarding_for_current_user(
    TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT
) RETURNS BOOLEAN LANGUAGE sql AS $$ SELECT TRUE $$;

INSERT INTO auth.users (
    id, email, email_confirmed_at, phone, phone_confirmed_at
) VALUES
    ('10000000-0000-4000-8000-000000000001', 'a@example.com', NOW(),
     '84987654321', NOW()),
    ('10000000-0000-4000-8000-000000000002', 'b@example.com', NOW(),
     '84912345678', NOW()),
    ('10000000-0000-4000-8000-000000000003', 'c@example.com', NULL,
     NULL, NULL);

INSERT INTO public.users (id, email, display_name, username, phone) VALUES
    ('10000000-0000-4000-8000-000000000001', 'a@example.com', 'A', 'alpha',
     '0987654321'),
    ('10000000-0000-4000-8000-000000000002', 'b@example.com', 'B', 'bravo',
     '0912345678'),
    ('10000000-0000-4000-8000-000000000003', 'c@example.com', 'C', 'charlie',
     NULL);

INSERT INTO public.subscriptions (
    id, user_id, plan_type, start_date, end_date
) VALUES (
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002',
    'pro', '2026-09-01', '2026-10-01'
);
