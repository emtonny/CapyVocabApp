# GitHub AI-scan sync — 2026-09-12

Status: **local integration verified; deployment and live scan pending**.

## Source and recovery

- Fast-forwarded `AI-scan`: `cbd7318` → `b742ea4` (two incoming commits).
- HEAD matches `origin/AI-scan`; Vilao integration remains uncommitted locally.
- Original local edits and untracked documentation are retained in stash
  `1af17176dbcdb752876bc6e2aeab69db0743d2db`, named
  `pre-sync-AI-scan-preserve-Vilao-20260912`. Keep it until the result is accepted.
- Preserved the user's documentation reorganization. Resolved conflicts in
  `PROJECT_STATUS.md`, `pubspec.lock`, and `gemini_client.ts`.
- Imported Library, offline persistence, auth/onboarding, settings, tests and
  migrations from GitHub. Resolved dependencies for Flutter 3.44.4/Dart 3.12.2.
- No commit, push, remote migration, deploy, secret change or data mutation.

## Vilao contract

Flutter → authenticated Supabase Edge Function → Vilao → normalized scan JSON
→ native SQLite/Library. Authentication, capabilities, request ledger and model
circuit breaker from the incoming branch remain active.

| Server setting | Behavior |
| --- | --- |
| `GEMINI_API_KEY` | Existing Vilao consumer key; server only |
| `GEMINI_BASE_URL` | Default `https://api.vilao.ai/v1`; highest URL priority |
| `GEMINI_MODEL` | Default `gemini-3.8-flash`; used for both Free and Pro on Vilao |
| `GEMINI_API_BASE_URL` | Explicit native Gemini/P6 override, only when `GEMINI_BASE_URL` is absent; leave unset for default Vilao |
| `GEMINI_FREE_MODEL` / `GEMINI_PRO_MODEL` / `GEMINI_PRO_FALLBACK_MODEL` | Only used in explicitly configured native Gemini mode |

Vilao calls `/chat/completions` with Bearer authentication and JPEG data URLs.
The API key is never sent to Google by fallback. Retries stay on the configured
Vilao model and retain the incoming two-attempt cap. Capability tier remains
server-derived even though both tiers use the same Vilao model.

The prompt requests schema v2 explicitly because OpenAI transport does not use
Google's `generationConfig.responseSchema`. The parser supports OpenAI and
native Gemini envelopes, fenced JSON, legacy field aliases and ledger token
accounting. Invalid hierarchy still fails validation.

Client assets contain public Supabase configuration only. Existing server
secrets were not read or changed. Secret presence alone does not prove the
stored key is a valid Vilao key; live verification remains pending.

## Verification

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed using existing dependency constraints |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub --reporter expanded` | 390 passed; 1 opt-in live Staging test skipped |
| Settings targeted tests | 11 passed after fixing Material background; 4 failed before fix |
| Deno suite (command below) | 82 passed, including 10 new gateway/handler tests |
| Deno check/lint/format on integration files | Passed |
| `flutter build web --no-pub` | Passed (JavaScript build) |
| `flutter build apk --debug --no-pub` | Passed |
| Client-project migration history | 21/21 local/remote match, read-only |
| Git | No merge conflicts; ahead 0 / behind 0 against origin/AI-scan |

```powershell
deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan
deno check --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto supabase/functions/gemini-vision-scan/index.ts
```

The explicit Deno config is necessary to resolve the incoming `edge-runtime`
import when running checks from the repository root. The integration test
invokes the actual request handler with mocked network and synthetic keys;
it verifies Free/Pro routing, response normalization, ledger token counts,
replay without another Vilao call, and rejection of missing authentication.

Build warnings remain: `flutter_tts` is incompatible with the WebAssembly
dry-run, CupertinoIcons font is not bundled, Android dependencies still apply
Kotlin Gradle Plugin, and Android SDK XML tool versions differ. These did not
prevent the JavaScript Web build or debug APK. iOS was not built on Windows.

## Runtime boundary

The app configuration and CLI currently target the same project. Read-only
inspection found main `gemini-vision-scan` v41 and canary v19 ACTIVE, plus the
`GEMINI_API_KEY` secret. Those deployments were not replaced in this task;
their ACTIVE status does not validate the newly merged code or provider.

Before claiming live acceptance, deploy the reviewed main Edge Function to the
intended project and perform an authenticated photo scan with the existing
Vilao secret, checking response, ledger and saved Library note. Database history
already matches, so this sync has not applied any migration. Cloud backup stays
behind `LIBRARY_SYNC_ENABLED=false` by default and user consent.

Web scan durability remains an upstream gap: the repository has a WASM SQLite
adapter, but the Web scan flow still uses memory. No device data was installed,
deleted, uploaded or modified during verification.
