# P1 Entitlement Verification

## Local implementation

- Central capability policy: `supabase/functions/_shared/entitlements.ts`.
- JWT verification through Supabase Auth: `supabase/functions/_shared/auth.ts`.
- Edge resolves the authenticated user before subscription lookup and resolves
  subscription before parsing the image or calling Gemini.
- Flutter subscription writes were removed; the remaining read filters active,
  unexpired subscriptions.
- Client `user_id`, `is_pro`, `plan`, `tier`, and `model` fields are ignored.
- No entitlement is stored in `user_metadata`.

## Database production state

- Migration applied: `20260827134123_harden_subscription_entitlements`.
- Rows at migration time: 0; duplicate users: 0.
- Unique constraint: `subscriptions_user_id_key (user_id)`.
- Query index: `subscriptions_user_status_end_date_idx
  (user_id, status, end_date DESC)`.
- `anon`: no table privileges.
- `authenticated`: SELECT only, with owner-only RLS.
- `service_role`: SELECT/INSERT/UPDATE/DELETE.

## Edge rollout state

- Canary: version 12, active, SHA-256
  `72d4957b0055f07b9c8b33d314b7d4e1d34a8a5a49d119b6895fbf9cff533523`.
- Canary missing-JWT smoke: 401 `authentication_required`.
- Canary invalid-JWT smoke: 401 `authentication_required`.
- Production remains version 33, active, SHA-256
  `fe067d4571ee6f197f20d8c3736e87425081c6ffc88d6f31805b2748380bf3dc`.
- Production promotion was not performed because a valid authenticated canary
  scan has not yet been smoke-tested. Explicit approval is required to accept
  that rollout risk.

## Verification results

- `flutter analyze`: passed.
- `flutter test`: 185 passed.
- `deno test --allow-env`: 45 passed.
- `deno check index.ts`: passed.
- P1 Deno format check: passed.
- P1-only Deno lint: passed.
- Whole-function Deno lint: 6 pre-existing findings remain, improved from the
  7-findings P0 baseline.
- Supabase advisors reported no new subscription RLS/security issue. Existing
  unrelated project warnings remain documented in the task report.

## Rollback reference

The complete pre-P1 local worktree is preserved by the two patch files and hash
manifest in this directory. Production Edge is still on the recorded P0 version
33. Reverting the database migration requires a reviewed follow-up migration;
do not manually grant client write privileges as an emergency shortcut.
