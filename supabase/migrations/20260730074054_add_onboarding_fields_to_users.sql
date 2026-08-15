ALTER TABLE public.users
  ADD COLUMN username TEXT UNIQUE,
  ADD COLUMN age INT CHECK (age IS NULL OR (age >= 1 AND age <= 120)),
  ADD COLUMN phone TEXT CHECK (phone IS NULL OR phone ~ '^0[0-9]{9}$'),
  ADD COLUMN account_role TEXT CHECK (account_role IS NULL OR account_role IN ('personal', 'parent')),
  ADD COLUMN onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;;
