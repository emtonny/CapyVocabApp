-- Restrict direct access to private profile rows and expose only approved
-- public profile fields through a SECURITY DEFINER RPC.

DROP POLICY IF EXISTS "Public profiles are viewable by authenticated users"
ON public.users;

DROP POLICY IF EXISTS "Users view own profile"
ON public.users;

CREATE POLICY "Users view own profile"
ON public.users
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = id);

CREATE OR REPLACE FUNCTION public.get_public_profiles(profile_ids UUID[] DEFAULT NULL)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    username TEXT,
    avatar_url TEXT,
    study_points INT,
    streak_days INT,
    user_level INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        u.id,
        u.display_name,
        u.username,
        u.avatar_url,
        u.study_points,
        u.streak_days,
        u.user_level
    FROM public.users AS u
    WHERE profile_ids IS NULL
       OR u.id = ANY(profile_ids);
$$;

REVOKE ALL ON FUNCTION public.get_public_profiles(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_profiles(UUID[]) TO authenticated;

COMMENT ON FUNCTION public.get_public_profiles(UUID[]) IS
'Approved public profile projection for friends and leaderboards. Does not expose email, phone, age, account_role, onboarding state, coins, or timestamps.';;
