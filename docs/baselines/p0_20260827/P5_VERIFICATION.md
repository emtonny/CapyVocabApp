# P5 Circuit Breaker Verification

Date: 2026-08-29 (Asia/Bangkok)

## Scope

P5 adds a database-coordinated circuit breaker for the three configured Gemini
model pools and records quota errors separately as RPM, TPM, RPD, or unknown.

This phase does not add a queue, Redis, a VPS, a quota rate limiter, a new
dependency, a second Gemini key, or any hard-coded Free Tier quota. Gemini
Tier 1, billing/prepay, budget alerts, and collection of real Tier 1 quotas
remain an owner checkpoint because the project has not been upgraded yet.

## Circuit architecture

Each configured model name owns one row in `public.gemini_model_health`.
The state machine is:

```text
healthy -> degraded -> open -> half_open -> healthy/open
```

The Edge Function calls the short transaction RPC
`acquire_gemini_model_attempt` before calling a model. The RPC locks only that
model row. Consequently:

- Flash-Lite failures cannot open either Pro model.
- Pro primary failures cannot open Flash-Lite or the Pro fallback.
- An open Pro primary is skipped in favor of the configured Pro fallback.
- An open Free model returns the existing `503 upstream_unavailable` contract
  without entering a Pro pool.
- After cooldown, one caller atomically changes `open` to `half_open` and
  receives a fenced probe token.
- Other callers are rejected until the half-open lease expires or the probe
  records its result.
- A stale probe token cannot close or reopen a newer half-open lease.

The Gemini HTTP request remains outside every database transaction. This keeps
row locks short and avoids holding a Postgres lock during a network call.

Circuit configuration is read from Edge Function environment/secrets:

```text
GEMINI_CIRCUIT_FAILURE_THRESHOLD
GEMINI_CIRCUIT_COOLDOWN_SECONDS
GEMINI_CIRCUIT_HALF_OPEN_LEASE_SECONDS
```

Missing values use conservative defaults `3`, `60`, and `45`. Present values
are range-validated and invalid configuration fails at initialization. These
are health-control values, not Google quota limits.

If the circuit store itself is temporarily unavailable, the breaker logs the
failure and preserves the configured model policy. This deliberate fail-open
choice prevents a health-telemetry outage from becoming an AI outage. Auth,
entitlement, and scan-ledger database failures still fail closed as established
in P1/P3.

## Retry and RPD behavior

The P3 ceiling of two Gemini calls per reserved execution remains in place.

- Free may retry its same Flash-Lite model once for an eligible `503`, network
  failure, or timeout, but never enters a Pro pool.
- Pro uses its configured fallback as the only additional model call after an
  eligible primary failure.
- Pro fallback does not gain an extra retry when the primary circuit is open.
- HTTP 429 never causes model fallback.
- HTTP 429 is retried on the same model only for the existing valid, short
  `Retry-After` path.
- Circuit rejection consumes zero Gemini RPD because no upstream call occurs.

No queue was added. It remains gated on load-test evidence that burst RPM is
the actual bottleneck.

## Quota telemetry

HTTP 429 is not counted as a model system failure and cannot increment the
consecutive-failure counter or open a healthy circuit.

The response body is inspected only for explicit quota dimension identifiers.
The following counters are stored separately per model:

```text
quota_rpm_error_count
quota_tpm_error_count
quota_rpd_error_count
quota_unknown_error_count
```

Unrecognized 429 responses stay `unknown`; the code does not guess RPM/RPD from
the status code or `Retry-After` alone. The scan ledger records final failures
as `quota_rpm_exceeded`, `quota_tpm_exceeded`, `quota_rpd_exceeded`, or the
backward-compatible generic `quota_exceeded`. Client responses retain
`error: quota_exceeded`, so older Flutter versions remain compatible.

Edge logs include service tier, model, quota kind, attempt count, and latency.
The existing scan ledger already owns tier/model/attempt/token/latency fields.

Google's current rate-limit documentation confirms that RPM, TPM, and RPD are
separate dimensions, limits apply per project rather than per API key, and
active limits must be read from AI Studio:
https://ai.google.dev/gemini-api/docs/rate-limits

## Database migration and security

Project: `vmxonxqxrlkssdzsucrg`

Local migration:

```text
20260829152311_add_gemini_model_circuit_breaker.sql
```

Remote migration record:

```text
20260829082840_add_gemini_model_circuit_breaker
```

The migration is additive and retains the two-argument
`record_gemini_model_health` RPC as a compatibility wrapper for the currently
deployed production function.

Remote catalog checks confirmed:

- All circuit columns and consistency constraints exist.
- `acquire_gemini_model_attempt`, `record_gemini_model_outcome`, and the legacy
  wrapper are `SECURITY INVOKER` with an empty `search_path`.
- `anon` and `authenticated` have no table access and cannot execute the RPCs.
- Only `service_role` can select/insert/update health rows and execute the RPCs.
- RLS remains enabled as defense in depth.

This follows Supabase's current guidance to prefer security-invoker functions,
pin `search_path`, and revoke default function execution:
https://supabase.com/docs/guides/database/functions

## Database tests

Before migration application, the complete migration ran successfully in a
transaction that ended with rollback.

A second rollback-only test asserted:

```text
healthy -> degraded -> open -> half_open -> healthy
```

It also verified quota isolation, probe fencing, model-row isolation, and that
a second half-open acquire is rejected.

After application, two concurrent database sessions targeted the same expired
open test row. Exactly one received `allowed=true` with a probe token; the
other received `allowed=false` in `half_open`. The test row was then deleted.

Current migrated production data reflects the pre-existing telemetry:

- `gemini-3.5-flash-lite`: `healthy`.
- `gemini-3.6-flash`: `healthy`.
- `gemini-3.7-flash`: `open` with four pre-existing consecutive system
  failures.

Once P5 source is deployed and cooldown has elapsed, the next Pro request will
be the single half-open probe for 3.7. Until then, the old deployed source does
not enforce this circuit state.

## Local verification

- Test-first red state confirmed the circuit/quota API was absent.
- Focused P5 Deno tests: passed, 24 tests.
- Full Edge Function Deno tests: passed, 67 tests.
- `deno check index.ts`: passed.
- P5 changed-file `deno fmt --check`: passed for 5 files.
- P5 module/test `deno lint`: passed for 4 files.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 196 tests.
- `git diff --check`: passed; Git emitted line-ending warnings only.

The full Edge directory formatter still reports eight pre-existing/unrelated
format findings. Full Deno lint retains the same four baseline `no-unused-vars`
findings in `index.ts`: `BoundingBox`, `rankWordsByBoxArea`,
`buildScanPrompt`, and `deduplicateWords`. P5 introduced no new lint finding.

## Advisors

Supabase Security and Performance Advisors reported no P5 object warning.

Existing unrelated findings remain, including:

- `ai_scan_requests` has RLS with no policy, intentionally server-only.
- Three older onboarding/availability `SECURITY DEFINER` functions are callable
  by authenticated users.
- Leaked-password protection is disabled.
- Older tables have unindexed foreign keys and RLS init-plan warnings.

Relevant remediation references:

- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan

## Deployment state

The database migration is applied, but P5 Edge source is not deployed.

The deployment tool rejected source upload because explicit owner permission
for private-source egress to the canary had not been given. No alternate deploy
path was attempted.

- Production `gemini-vision-scan`: version 34, unchanged, SHA
  `19059f670e1420bb39d779039372e01906f7abdce2abdb8aa47e5a303bb73f7d`.
- Canary `gemini-vision-scan-canary`: version 14, unchanged, SHA
  `1a4145f557c325e70df941623ea4026ac181ae5d3dcdffc6012baf4a624a4b4d`.

Canary deployment requires the owner to explicitly authorize uploading the
repository Edge Function source to the existing Supabase canary function.
Production promotion remains a separate later decision.

## Deferred owner checkpoint: Gemini Tier 1

No billing or Gemini account change was made. When funds are available, the
owner still needs to:

1. Link billing and upgrade the production Gemini project to Tier 1.
2. Configure prepay/payment and budget alerts.
3. Record actual AI Studio limits for Flash-Lite, Flash 3.7, and Flash 3.6:
   RPM, TPM, RPD, and any spend-based limit.
4. Provide those observed limits before a production rate limiter or load-test
   target is configured.

No current Free Tier quota is embedded in source.

## Remaining validation

1. Explicitly authorize and deploy P5 source to canary.
2. Run Gemini-free canary smoke checks (`OPTIONS` and missing JWT).
3. When desired, run one authenticated Free scan and one authenticated Pro scan
   with owner-provided sessions. These calls consume Gemini quota.
4. After Tier 1, load test with the observed quota values and decide whether a
   queue/rate limiter is necessary.

No commit, push, production Edge deployment, Gemini secret change, billing
change, Tier upgrade, or Gemini request was performed in this P5 pass.
