ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS age INT CHECK (age IS NULL OR (age BETWEEN 1 AND 120)),
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS account_role TEXT CHECK (account_role IS NULL OR account_role IN ('personal', 'parent')),
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- Ràng buộc định dạng số điện thoại Việt Nam: 10 số, bắt đầu bằng 0
ALTER TABLE public.users
  ADD CONSTRAINT users_phone_format_check
  CHECK (phone IS NULL OR phone ~ '^0[0-9]{9}$');;
