-- CHỈ dùng cho mục đích test/demo — reset onboarding_completed về false
-- cho CHÍNH tài khoản đang gọi (không thể reset tài khoản người khác,
-- vì SECURITY DEFINER vẫn giới hạn qua auth.uid() của người gọi).
CREATE OR REPLACE FUNCTION public.reset_my_onboarding()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.users
  SET onboarding_completed = false
  WHERE id = (SELECT auth.uid());
$$;

REVOKE ALL ON FUNCTION public.reset_my_onboarding() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reset_my_onboarding() TO authenticated;;
