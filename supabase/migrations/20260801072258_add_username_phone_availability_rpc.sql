-- Chỉ trả về boolean, KHÔNG lộ dữ liệu người dùng khác — an toàn dù RLS
-- chặn đọc trực tiếp bảng users của người khác.
CREATE OR REPLACE FUNCTION public.check_username_available(p_username TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.users WHERE username = lower(p_username)
  );
$$;

CREATE OR REPLACE FUNCTION public.check_phone_available(p_phone TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.users WHERE phone = p_phone
  );
$$;

REVOKE ALL ON FUNCTION public.check_username_available(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.check_phone_available(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_username_available(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_phone_available(TEXT) TO authenticated;;
