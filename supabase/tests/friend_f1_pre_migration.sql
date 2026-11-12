-- Synthetic rows inserted before F1 to verify additive backfill behavior.
\set a 11111111-1111-4111-8111-111111111111
\set b 22222222-2222-4222-8222-222222222222
\set c 33333333-3333-4333-8333-333333333333
\set d 44444444-4444-4444-8444-444444444444
\set e 55555555-5555-4555-8555-555555555555
\set f 66666666-6666-4666-8666-666666666666
\set g 77777777-7777-4777-8777-777777777777

INSERT INTO auth.users (
    id, email, email_confirmed_at, phone, phone_confirmed_at
) VALUES
    (:'a', 'alice@example.test', NOW(), '+84901234567', NOW()),
    -- Hosted Supabase Auth currently stores verified E.164 values without '+'.
    (:'b', 'bob@example.test', NOW(), '84912345678', NOW()),
    (:'c', 'carol@example.test', NOW(), '+84923456789', NOW()),
    (:'d', 'dave@example.test', NULL, '+84934567890', NULL),
    (:'e', 'erin@example.test', NOW(), '+84945678901', NOW()),
    (:'f', 'finn@example.test', NOW(), '+84956789012', NOW()),
    (:'g', 'gail@example.test', NOW(), '+84967890123', NOW());

INSERT INTO public.users (
    id, email, display_name, username, phone, avatar_url,
    study_points, streak_days, user_level
) VALUES
    (:'a', 'alice@example.test', 'Alice', 'alice', '0901234567', 'alice.png', 10, 1, 2),
    (:'b', 'bob@example.test', 'Bob', 'bob', '0912345678', 'bob.png', 20, 2, 3),
    (:'c', 'carol@example.test', 'Carol', 'carol', '0923456789', 'carol.png', 30, 3, 4),
    (:'d', 'dave@example.test', 'Dave', 'dave', '0934567890', 'dave.png', 40, 4, 5),
    (:'e', 'erin@example.test', 'Erin', 'erin', '0945678901', 'erin.png', 50, 5, 6),
    (:'f', 'finn@example.test', 'Finn', 'finn', '0956789012', 'finn.png', 60, 6, 7),
    (:'g', 'gail@example.test', 'Gail', 'gail', '0967890123', 'gail.png', 70, 7, 8);

INSERT INTO public.user_language_profiles (
    user_id, native_language_code, learning_language_code
) VALUES
    (:'a', 'vi', 'en'),
    (:'b', 'en', 'vi'),
    (:'e', 'en', 'vi');

INSERT INTO public.friends (user_id, friend_id, status, created_at) VALUES
    (:'a', :'e', 'accepted', NOW() - INTERVAL '2 days'),
    (:'e', :'a', 'accepted', NOW() - INTERVAL '2 days'),
    (:'a', :'d', 'pending', NOW() - INTERVAL '1 day');
