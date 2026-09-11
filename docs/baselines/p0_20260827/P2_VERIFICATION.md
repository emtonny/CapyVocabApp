# P2 Model Router Verification

Date: 2026-08-28 (Asia/Bangkok)

## Scope

P2 adds server-owned model routing after the P1 authentication and entitlement
checks. The Flutter client still sends only the image payload and cannot select
the tier, model, fallback, or user identity.

## Implemented policy

| Tier | Primary | Fallback |
| --- | --- | --- |
| Free | `GEMINI_FREE_MODEL` or `gemini-3.5-flash-lite` | None |
| Pro | `GEMINI_PRO_MODEL` or `gemini-3.7-flash` | `GEMINI_PRO_FALLBACK_MODEL` or `gemini-3.6-flash` |

The router is owned by
`supabase/functions/gemini-vision-scan/model_policy.ts`.

- Free never enters the Pro model pool.
- HTTP 429 never retries or falls back to another model.
- Pro falls back only after HTTP 500, 502, 503, 504, or an eligible network
  failure/timeout.
- HTTP 503 and eligible network failures/timeouts receive one same-model retry
  with bounded jitter before the Pro fallback is considered.
- The model health store remains telemetry only and cannot reorder the policy.
- Prompt, response schema, and result-size behavior remain shared between Free
  and Pro.
- Successful responses include `service_tier` and `model_used`.

Supabase project secrets were not changed by this phase. The defaults above
keep the function operable, while the three secret names allow model changes
without an app update. Supabase documents that Edge Function secrets are read
through `Deno.env.get()` and become available without redeploying the function.

## Local verification

Commands were run from the Edge Function directory when Deno needed the local
`deno.json` import mapping.

- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 185 tests.
- `deno test --allow-env`: passed, 55 tests.
- `deno check index.ts`: passed.
- `deno fmt --check` for the seven P1/P2 files: passed.
- `git diff --check`: passed (Git emitted line-ending warnings only).
- `deno lint`: four existing `no-unused-vars` findings remain in `index.ts`:
  `BoundingBox`, `rankWordsByBoxArea`, `buildScanPrompt`, and
  `deduplicateWords`. P0 recorded seven Deno lint findings, and P2 introduced
  no new lint category or finding.

Routing coverage includes Free primary-only behavior, Pro primary/fallback,
server environment overrides, 429 handling, eligible 5xx handling, network
failure, timeout, retry jitter, health telemetry isolation, and unchanged
generation schema/config behavior.

## Canary deployment

Project: `vmxonxqxrlkssdzsucrg`

- Function: `gemini-vision-scan-canary`
- Version: 13
- Status: `ACTIVE`
- Bundle SHA-256:
  `4ad18ef7aedd9944d5196946d695aec20b7db8c6463f9c8c6b0995e5668d041b`
- Gateway `verify_jwt`: false because the function performs custom JWT
  verification before entitlement resolution and before reading the image.

Remote bundle inspection confirmed the model policy file, entitlement-before-
payload ordering, policy-before-Gemini ordering, removal of the legacy shared
model chain, and the `service_tier`/`model_used` response fields.

Smoke checks did not call Gemini and therefore consumed no Gemini request:

- Missing JWT: HTTP 401 `authentication_required`.
- Invalid JWT: HTTP 401 `authentication_required`.
- Edge logs recorded both HTTP 401 requests against canary version 13.

## Production state and rollout blocker

Production was not changed by this P2 execution.

The P1 database migration `20260827134123_harden_subscription_entitlements`
is still present remotely. A read-only check found both expected subscription
indexes and the authenticated owner-read policy.

The current production function changed after the P1 baseline and is now:

- Function: `gemini-vision-scan`
- Version: 34
- Status: `ACTIVE`
- Bundle SHA-256:
  `19059f670e1420bb39d779039372e01906f7abdce2abdb8aa47e5a303bb73f7d`

Read-only inspection shows production version 34 does not contain the P1
entitlement boundary or the P2 tier router. It uses one shared model chain,
including Free and Pro models, for every request. Consequently, the intended
Free/Pro business separation is active on canary only, not production.

Production promotion remains blocked until both of these are available:

1. Explicit approval to replace the current production bundle.
2. At least one valid authenticated canary scan that proves the live
   Auth -> subscription -> tier -> Gemini path. Ideally test one Free user and
   one active Pro user, and verify `service_tier` and `model_used` in each
   response.

No commit, push, production deployment, secret update, or Gemini request was
performed as part of this P2 completion pass.
