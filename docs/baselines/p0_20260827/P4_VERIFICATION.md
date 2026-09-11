# P4 Flutter Entitlement Provider Verification

Date: 2026-08-28 (Asia/Bangkok)

## Scope

P4 adds one Flutter entitlement source for UI decisions, restores those UI
entitlements from Supabase Auth/subscription state, and parses the P2 scan
metadata without breaking legacy scan responses.

This provider is not an authorization boundary. All high-value endpoints still
authenticate the JWT and resolve capabilities server-side before invoking
Gemini or another protected service.

## Central provider

The provider is implemented in:

```text
lib/core/entitlements/entitlement_provider.dart
```

UI usage:

```dart
final entitlements = ref.watch(entitlementProvider);

if (entitlements.can(AppCapability.aiScanAdvanced)) {
  // Show a Pro-only UI entry or Pro badge.
}
```

After a verified payment/webhook has updated `subscriptions`, the payment UI
can explicitly reload the server-owned state:

```dart
await ref.read(entitlementProvider.notifier).refresh();
```

The current capability map is intentionally identical to P1:

| Tier | Capabilities |
| --- | --- |
| Free | `aiScanBasic` |
| Pro | `aiScanBasic`, `aiScanAdvanced` |

Future capability names are present in the enum but are not granted to either
tier until their server policy and product behavior are implemented.

## Subscription and auth lifecycle

- No authenticated user: Free, without a subscription query.
- Only `capy_pro_monthly` with a future `end_date` becomes Pro.
- Missing, unsupported, malformed, expired, or failed subscription lookup:
  Free/fail-closed.
- Supabase `onAuthStateChange` reloads entitlement after restored/new-device
  login and clears Pro state immediately after sign-out.
- A version guard prevents a slow subscription response for an old session
  from restoring Pro after sign-out or account switching.
- The auth stream subscription is cancelled when Riverpod disposes the
  notifier.

The central query selects only `plan_type,end_date` from the current user's
active subscription. The pre-existing settings datasource delegates to this
same helper, so there is one query definition rather than two.

Supabase's current Dart reference documents `onAuthStateChange`, including
error handling and cancelling its subscription:
https://supabase.com/docs/reference/dart/auth-onauthstatechange

The repository currently locks `supabase_flutter` 2.17.1. The current
Supabase changelog contains no relevant Flutter/Auth breaking change for this
implementation. It also documents automatic transient GET/HEAD retries in the
client libraries, so P4 does not add another client retry loop:
https://supabase.com/changelog/45071-automatic-postgrest-retries-for-transient-errors

## UI integration

`SettingsScreen` now reads the centralized provider and displays its `PRO`
badge only when:

```dart
entitlements.can(AppCapability.aiScanAdvanced)
```

The existing paywall and payment service remain scaffolds. P4 exposes the
capability and refresh API they need, but does not fabricate a payment flow or
write a subscription from Flutter.

## Scan response compatibility

`GeminiVisionResult` now exposes nullable:

- `scanId` from `scan_id`
- `serviceTier` from `service_tier`
- `modelUsed` from `model_used`

The legacy contract remains valid:

```json
{
  "words": []
}
```

The P2/P3 contract is also parsed and round-tripped:

```json
{
  "scan_id": "...",
  "service_tier": "pro",
  "model_used": "gemini-3.7-flash",
  "words": []
}
```

Metadata is optional and does not change word parsing, ranking, bounding boxes,
error mapping, or older callers that only read `words`.

## Security and remote verification

Project: `vmxonxqxrlkssdzsucrg`

A read-only catalog check confirmed:

- `authenticated` can `SELECT` subscriptions.
- `authenticated` cannot `INSERT` or `UPDATE` subscriptions.
- The owner-read RLS policy is present and restricts rows using `auth.uid()` and
  `user_id`.

The provider never reads tier from `user_metadata` and never writes a plan.
Changing the APK/provider state can only spoof local presentation; the P1 Edge
authorization boundary still determines the actual tier and model.

## Verification

- Test-first red state confirmed the missing provider and missing scan metadata
  fields before implementation.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 196 tests.
- P4 focused Flutter suite: passed, 36 tests.
- `deno test --allow-env`: passed, 62 tests.
- `deno check index.ts`: passed.
- `git diff HEAD --check`: passed; Git emitted line-ending warnings only.

P4 tests cover Free default, active Pro, unsupported/expired plans, manual
refresh after payment, auth restore on another device, sign-out downgrade,
database-error fail-closed behavior, stale async response rejection, legacy
scan response parsing, new metadata parsing, unchanged HTTP 401/429/503 error
mapping, and capability-driven Pro badge rendering.

## Deployment state

P4 changed no database schema and no Edge Function source, so no migration or
Edge deployment was performed.

- Production `gemini-vision-scan`: version 34, SHA `19059f670e1420bb...`
- Canary `gemini-vision-scan-canary`: version 14, SHA `1a4145f557c325e...`

The production rollout blocker recorded in P3 remains: production version 34
does not contain the P1-P3 server boundary. Flutter P4 must not be released
against that production function as proof of Pro security.

## Remaining integration

When the real payment/webhook flow is implemented, its successful server
confirmation must call `entitlementProvider.notifier.refresh()`. No mock
payment result should create a local Pro subscription or directly mutate the
provider to Pro.

No commit, push, production deployment, canary deployment, migration, secret
change, subscription write, or Gemini request was performed in P4.
