\set a '10000000-0000-4000-8000-000000000001'
\set b '10000000-0000-4000-8000-000000000002'
\set c '10000000-0000-4000-8000-000000000003'
\set subscription '20000000-0000-4000-8000-000000000001'
\set email_only_subscription '20000000-0000-4000-8000-000000000002'

SELECT public.f1_assert(
    (SELECT phone = '+84987654321' FROM public.users WHERE id = :'a'),
    'legacy Vietnamese phone is migrated to E.164'
);
SELECT public.f1_assert(
    NOT has_table_privilege('authenticated',
        'private.account_contact_settings', 'SELECT'),
    'authenticated cannot read private contact settings directly'
);
SELECT public.f1_assert(
    NOT has_table_privilege('authenticated',
        'private.account_contact_history', 'SELECT'),
    'authenticated cannot read private contact history directly'
);
SELECT public.f1_assert(
    NOT has_function_privilege('authenticated',
        'private.complete_verified_onboarding(text,text,integer,text,text,text,text,text,text,integer,text,text,text)',
        'EXECUTE'),
    'authenticated cannot execute private onboarding helper directly'
);
SELECT public.f1_assert(
    has_sequence_privilege('service_role',
        'private.promotion_redemptions_id_seq', 'USAGE'),
    'service role can allocate promotion ledger identities'
);
SELECT public.f1_assert(
    (SELECT verified_email = 'b@example.com'
            AND verified_phone = '+84912345678'
     FROM private.subscription_contact_snapshots
     WHERE subscription_id = :'subscription'),
    'migration backfills verified contacts for an existing subscription'
);

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);

SELECT public.f1_assert(
    public.check_phone_available('+1 (415) 555-2671'),
    'international E.164 phone syntax is accepted'
);
SELECT public.f1_assert(
    NOT public.check_phone_available('0987654321'),
    'local phone without country code is rejected'
);
SELECT public.f1_assert(
    (SELECT username = 'bravo'
     FROM public.search_friend('username', 'BRAVO')),
    'friend search still finds exact username'
);
SELECT public.f1_expect_error(
    $$SELECT * FROM public.search_friend('email', 'b@example.com')$$,
    '22023',
    'friend search rejects email method'
);
SELECT public.f1_expect_error(
    $$SELECT * FROM public.search_friend('phone', '+84912345678')$$,
    '22023',
    'friend search rejects phone method'
);
SELECT public.f1_expect_error(
    format($sql$SELECT * FROM public.get_accepted_friend_contact(%L::uuid)$sql$,
           :'b'),
    '42501',
    'contact view requires an accepted friendship'
);

RESET ROLE;
INSERT INTO public.friends (user_id, friend_id, status) VALUES
    (:'a', :'b', 'accepted'),
    (:'b', :'a', 'accepted');

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    (SELECT email IS NULL AND phone IS NULL
     FROM public.get_accepted_friend_contact(:'b')),
    'accepted friend contacts are hidden by default'
);

SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.f1_assert(
    (SELECT show_email_to_friends AND show_phone_to_friends
     FROM public.update_my_account_contact_visibility(TRUE, TRUE)),
    'verified owner can enable both contact switches'
);

SELECT set_config('request.jwt.claim.sub', :'a', false);
SELECT public.f1_assert(
    (SELECT email = 'b@example.com' AND phone = '+84912345678'
     FROM public.get_accepted_friend_contact(:'b')),
    'accepted friend sees only explicitly shared verified contacts'
);

SELECT set_config('request.jwt.claim.sub', :'c', false);
SELECT public.f1_expect_error(
    $$SELECT * FROM public.update_my_account_contact_visibility(TRUE, FALSE)$$,
    '22023',
    'unverified email cannot be made visible'
);
SELECT public.f1_expect_error(
    $$SELECT public.complete_onboarding(
        'C', 'charlie', 20, '+14155552671', 'personal', '20:00', 10
    )$$,
    '22023',
    'onboarding rejects unverified contacts'
);

RESET ROLE;
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE id = :'c';

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'c', false);
SELECT public.f1_assert(
    public.complete_onboarding(
        'C Verified', 'charlie', 20, '+14155552671', 'personal', '20:00', 10
    ),
    'compatibility onboarding overload accepts a verified email without SMS'
);
SELECT public.f1_assert(
    (SELECT onboarding_completed AND phone IS NULL
     FROM public.users WHERE id = :'c'),
    'email-only onboarding ignores the dormant phone parameter'
);

RESET ROLE;
INSERT INTO public.subscriptions (
    id, user_id, plan_type, start_date, end_date
) VALUES (
    :'email_only_subscription', :'c', 'pro', '2026-09-25', '2026-10-25'
);
SELECT public.f1_assert(
    (SELECT verified_email = 'c@example.com' AND verified_phone IS NULL
     FROM private.subscription_contact_snapshots
     WHERE subscription_id = :'email_only_subscription'),
    'email-only account can start a subscription without a phone snapshot'
);

UPDATE auth.users
SET email = 'b-new@example.com', email_confirmed_at = NOW(),
    phone = '33142278186', phone_confirmed_at = NOW()
WHERE id = :'b';
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'b', false);
SELECT public.sync_my_verified_email();
SELECT public.sync_my_verified_phone();
RESET ROLE;

SELECT public.f1_assert(
    (SELECT NOT show_email_to_friends AND NOT show_phone_to_friends
     FROM private.account_contact_settings WHERE user_id = :'b'),
    'changing contacts resets both visibility switches'
);
UPDATE public.subscriptions
SET end_date = '2026-09-20'
WHERE id = :'subscription';
SELECT public.f1_assert(
    (SELECT verified_email = 'b@example.com'
            AND verified_phone = '+84912345678'
     FROM private.subscription_contact_snapshots
     WHERE subscription_id = :'subscription'),
    'shortening an existing package does not replace original contacts'
);
UPDATE public.subscriptions
SET end_date = '2026-11-01'
WHERE id = :'subscription';
SELECT public.f1_assert(
    (SELECT verified_email = 'b-new@example.com'
            AND verified_phone = '+33142278186'
     FROM private.subscription_contact_snapshots
     WHERE subscription_id = :'subscription'),
    'renewal extension captures the newly verified contacts'
);

INSERT INTO private.promotion_redemptions (
    promotion_key, user_id, verified_email, verified_phone
) VALUES ('welcome', :'a', 'a@example.com', '+84987654321');
SELECT public.f1_expect_error(
    format($sql$INSERT INTO private.promotion_redemptions
        (promotion_key, user_id, verified_email, verified_phone)
        VALUES ('welcome', %L::uuid, 'a@example.com', '+14155552671')$sql$,
        :'c'),
    '23505',
    'promotion cannot be reclaimed through the same verified email'
);
