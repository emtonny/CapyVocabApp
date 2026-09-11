# P3 RPD Optimization Verification

Date: 2026-08-28 (Asia/Bangkok)

## Scope

P3 adds one stable client request ID per scan action, server-side idempotency,
an AI scan ledger, bounded upstream retry, and Gemini-free liveness checks.
The image hash cache remains intentionally deferred until production telemetry
shows that users repeatedly scan the same compressed image.

P3 does not change the shared prompt or response schema introduced before this
phase. Existing Flutter image compression remains in the scan pipeline; it
reduces payload/TPM cost but does not reduce Gemini RPD by itself.

## Request and idempotency flow

Flutter now generates a UUID v4 once per scan action and sends:

```json
{
  "request_id": "uuid",
  "image_base64": "..."
}
```

- A manual retry of the same failed local image retains the same request ID.
- A different image/action receives a new request ID.
- The Edge Function accepts legacy callers without `request_id` by generating
  a server UUID, but those old clients cannot deduplicate separate HTTP retries.
- The client cannot provide `user_id`, `service_tier`, or `model`.

The Edge Function resolves JWT and entitlements before reserving a request.
The reservation RPC uses a short transaction and a unique constraint on
`(user_id, client_request_id)`:

1. A new request returns `reserved`.
2. A successful unexpired duplicate returns `replay` and the stored JSON.
3. A duplicate still in progress returns HTTP 409 and never calls Gemini.
4. A failed request may reserve the same ID again while preserving cumulative
   attempt/token counters.
5. Gemini is always called after the reservation transaction has ended.
6. Completion is written with one short conditional update on a row whose
   status is still `processing`.

Successful result JSON expires after 24 hours. The hourly `pg_cron` job clears
only expired `result_json`; ledger metadata remains available for telemetry.
No image bytes/base64 are stored, and a database check constraint rejects a
top-level `image_base64` result field.

## Retry policy

The Gemini client has a hard ceiling of two total upstream calls for one
reserved execution.

- HTTP 429 without a valid short `Retry-After` is treated as quota/RPD and is
  not retried.
- HTTP 429 is retried once on the same model only when `Retry-After` is valid
  and no longer than five seconds. It never triggers a model fallback.
- Free retries the same Free model at most once after HTTP 503, eligible
  network failure, or timeout.
- Pro uses its configured fallback as the one additional call after eligible
  HTTP 500/502/503/504, network failure, or timeout.
- JSON parse/schema/hierarchy errors are returned without another Gemini call.
- Other upstream HTTP failures are not automatically retried.

This P3 ceiling supersedes the earlier P2 report's larger same-model-retry plus
fallback sequence.

## Database migrations and remote verification

Project: `vmxonxqxrlkssdzsucrg`

Local migration files:

- `20260828173421_add_ai_scan_request_ledger.sql`
- `20260828174457_restrict_ai_scan_ledger_service_role.sql`

Remote migration records:

- `20260828104338_add_ai_scan_request_ledger`
- `20260828104528_restrict_ai_scan_ledger_service_role`

The second migration corrects Supabase default table privileges discovered
during verification. The final remote permissions are:

- `service_role`: `SELECT`, `INSERT`, `UPDATE` only.
- `anon` and `authenticated`: no table privileges and no RPC execute privilege.
- RLS: enabled with no client policy, because the ledger is server-only.
- Reservation RPC: `SECURITY INVOKER` with an empty `search_path`.

Remote catalog checks confirmed the unique constraint, result-expiry partial
index, active hourly cron job at minute 17, installed `pg_cron`, RLS, and the
expected grants. A database-only transaction test with rollback verified:

```text
reserved -> in_progress -> replay -> failed request reserved again
```

The test used an existing auth user only as a foreign-key target, returned no
user data, created no persistent ledger row, and did not call Gemini.

## Local verification

- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 186 tests.
- `deno test --allow-env`: passed, 62 tests.
- `deno check index.ts`: passed.
- `deno fmt --check`: passed for 11 Edge Function files.
- P3/new-module `deno lint`: passed for 10 files.
- `git diff --check`: passed; Git emitted line-ending warnings only.
- Full `deno lint`: the same four baseline `no-unused-vars` findings remain in
  `index.ts`: `BoundingBox`, `rankWordsByBoxArea`, `buildScanPrompt`, and
  `deduplicateWords`. P3 introduced no new lint finding.

Tests cover request ID validation and legacy compatibility, retry ID reuse,
new-action ID rotation, ledger reservation/replay/completion metrics, no image
field in ledger writes, ledger fail-closed behavior, Free/Pro retry/fallback,
429 with and without `Retry-After`, network failure, timeout, and the global
two-call ceiling.

## Advisors

The Supabase Security Advisor reports one P3 informational item:
`ai_scan_requests` has RLS with no policy. This is intentional because only the
server service role may access the ledger. No P3 security warning was reported.

The Performance Advisor reports the new expiry index as unused. The table has
no production data yet; the hourly expiry job is its intended consumer. Other
advisor warnings concern pre-existing tables/functions and were not modified
by P3.

## Canary deployment

- Function: `gemini-vision-scan-canary`
- Version: 14
- Status: `ACTIVE`
- Bundle SHA-256:
  `1a4145f557c325e70df941623ea4026ac181ae5d3dcdffc6012baf4a624a4b4d`
- Gateway `verify_jwt`: false because the function performs custom JWT
  verification before entitlement lookup, payload processing, ledger reserve,
  and Gemini.

Remote bundle inspection confirmed `scan_ledger.ts`, request parsing, the
two-call retry ceiling, P1 entitlements, and P2 model policy are included.

Gemini-free smoke checks:

- `OPTIONS`: HTTP 200 with body `ok`.
- Missing JWT: HTTP 401 `authentication_required`.
- Edge logs recorded both requests against canary version 14.
- Ledger row count remained zero after the checks.

## Production state

Production was not changed by P3:

- Function: `gemini-vision-scan`
- Version: 34
- Status: `ACTIVE`
- Bundle SHA-256:
  `19059f670e1420bb39d779039372e01906f7abdce2abdb8aa47e5a303bb73f7d`

Production version 34 still does not contain the P1/P2/P3 server boundary. A
separate explicit promotion and authenticated canary validation are required
before replacing it.

## Production telemetry query

After authenticated canary traffic exists, measure the RPD objective over a
stable window with:

```sql
SELECT
    service_tier,
    COUNT(*) AS unique_scan_requests,
    SUM(attempt_count) AS gemini_calls,
    ROUND(
        SUM(attempt_count)::NUMERIC / NULLIF(COUNT(*), 0),
        3
    ) AS calls_per_scan,
    SUM(GREATEST(attempt_count - 1, 0)) AS retry_calls
FROM public.ai_scan_requests
WHERE status IN ('succeeded', 'failed')
  AND created_at >= NOW() - INTERVAL '24 hours'
GROUP BY service_tier;
```

The normal path is one upstream call and automated tests prove the hard maximum
is two. The target `calls_per_scan <= 1.05` cannot be claimed until real traffic
exists. Duplicate requests in `replay` or `in_progress` do not increment
`attempt_count`, so they do not consume another Gemini call.

Repository search found no synthetic Gemini caller. Current synthetic health
usage is therefore 0 RPD/model/day; the health store records outcomes from real
scans only.

## Residual risks and rollout blockers

1. A valid authenticated Free and Pro canary scan has not been run in this
   pass, to avoid consuming Gemini RPD without owner-provided test sessions.
2. If Gemini succeeds but the final ledger update is unavailable, the client
   still receives the result while that request ID can remain `processing`.
   This fails safely for RPD (duplicates remain blocked) but requires an
   operational repair/new scan action. No automatic stale reclaim was added,
   because it could create a duplicate Gemini call without a lease/fencing
   design.
3. The image-hash cache was not added because no telemetry currently proves it
   would save meaningful requests.
4. `calls_per_scan <= 1.05` and `duplicate_calls = 0` must still be monitored
   under concurrent authenticated load before production promotion.

No commit, push, production Edge deployment, model secret update, or Gemini
request was performed in this P3 pass.
