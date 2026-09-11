# Capy Vocab — Project Status & AI Handoff

> Last audited: 2026-09-11
> Source of truth for current implementation status, integration boundaries, and next work.
> Do not copy secrets, production URLs, access tokens, or service-role keys into this file.

```yaml
project:
  name: Capy Vocab
  type: Flutter client application
  version: 0.1.0
  current_milestone: "Phase 2 — First usable learning loop"
  phase_1_code_status: "implemented"
  phase_1_acceptance_status: "Production M3A/M4.5 cloud contract verified; broader release acceptance pending"
  product_status: "offline Library, consent-gated cloud sync/pull/manual media restore, authentication, onboarding, and photo scan implemented"
  release_ready: false
backend:
  provider: Supabase
  production_connection: "reachable from the configured Flutter environment"
  library_cloud_contract: "M3A + M4.5 applied and owner-isolation verified on Production"
frontend:
  working_user_flow: "offline-tolerant startup -> email/password auth -> five-step onboarding -> guarded /home -> bottom tab routing & photo scan"
  first_blocking_placeholder: "/home"
tests:
  automated: "351 default tests plus 1 opt-in live sync test"
  last_result: "Gate 3 Production sync/pull/purge and two-user RLS/Storage runtime passed on 2026-09-11"
```

## 1. Executive summary

The project has completed the code portion of the **technical foundation
phase** and has started the **first usable learning loop**. It is not yet an
MVP.

### Update log — 2026-09-11 (Production Library Gate 3)

1. After explicit owner approval, M3A and M4.5 were applied to Production by
   explicit project ref without relinking the repository.
2. Production migration history is 21/21 and post-apply dry-run is up to date.
   The `photo_notes` bucket is private and normalized Library/change-feed
   tables exist.
3. Full runtime fixture verification passed private upload, normalized JSON,
   metadata pull to a second SQLite database, permanent purge and cleanup.
4. Two-user RLS/Storage verification passed owner access and denied cross-user
   row insert/read plus Storage upload/read; owner signed URL returned 200.
5. Final audit contains 0 fixture rows, objects or Auth users. Default runtime
   sync remains compile-time OFF; no Production app build/release was made.

The application can currently:

1. Load its environment configuration.
2. Initialize the Supabase Flutter client with a publishable key.
3. Open local UI without requiring a successful remote health request.
4. Keep Library sync failures out of the app bootstrap path.
5. Sign up and sign in with email/password.
6. Present distinct authentication errors.
7. Persist/read the Supabase session.
8. Guard application routes and react to auth session changes.
9. Read `public.users.onboarding_completed` and route authenticated users to
   onboarding or home.
10. Collect and validate the five-step onboarding profile.
11. Persist profile and learning settings atomically before marking onboarding
    complete.

After authentication, incomplete profiles enter onboarding and completed
profiles open `/home`. Learning,
scanning, games, arena, shop, friends, chat, notifications, and settings are
in progress.

### Update log — 2026-09-02 (Library offline storage)

1. M1 added a pure-Dart Library domain contract for offline Photo Notes,
   scan evidence, annotation, albums, learning/SRS, sync outbox, consent audit,
   and on-device-training lineage.
2. D1 is approved. M2A uses `sqflite` on native, FFI for tests and SQLite
   WASM/IndexedDB on Web; the Web build contains its worker and WASM assets.
3. Version-1 `scan_results` migration was tested to preserve every legacy row
   and queue account-aware import without inventing an owner for old data.
4. SQLite integration tests cover tenant foreign keys, transaction rollback,
   immutable evidence, append-only learning events, consent constraints, ML
   provenance, and single-active-model enforcement.
5. M2B implements SQLite codecs and all six Library/Album/Learning/Sync/
   Training/Consent repository contracts, including consent-gated atomic
   outbox and training lineage invalidation.
6. Native `scan_results` now opens the shared version-2 database and queues
   every new legacy row transactionally; importer completion remains explicitly
   owner-gated.
7. Verification on 2026-09-02: `flutter analyze` reported no issues,
   `flutter build web` passed, and the complete Flutter suite passed 250/250.
8. D2–D10 remain pending. Chrome IndexedDB runtime verification is blocked by
   the local Chrome test runner; physical-device benchmark, media commit
   recovery, automatic legacy conversion and Library UI wiring remain open.

### Update log — 2026-09-03 (M2C native scan persistence)

1. Native AI Scan now maps each successful Gemini response into the normalized
   M2B MediaAsset, ScanRun, VocabDetection and PhotoNote aggregate.
2. The raw Edge Function response is retained before client ranking so schema
   metadata and detection hierarchy remain immutable scan evidence for future
   evaluation and on-device ML lineage.
3. The compatibility `scan_results` row, normalized aggregate and imported
   legacy queue link commit in one owner-scoped SQLite transaction; a failure
   rolls all of them back.
4. New local accounts default all cloud/personalization/federated consent flags
   to false, while existing consent state is preserved.
5. AI predictions are not promoted to user annotations or training examples.
6. Verification on 2026-09-03: `flutter analyze --no-pub` found no issues, the
   complete Flutter suite passed 252/252, and `flutter build web --no-pub`
   succeeded.
7. This milestone does not upload image or JSON data to Supabase. Sync worker,
   two-phase media recovery, Library UI, old ownerless-row import and the
   on-device trainer remain separate follow-up milestones.

### Update log — 2026-09-03 (M3A private cloud contract)

1. D2 and D3 were approved: active notes keep local display/model-input media,
   original media is opt-in/quota-bound, and cloud backup defaults OFF.
2. An additive Supabase migration now defines normalized media/scan/detection/
   annotation tables and extends legacy `photo_notes` without deleting rows.
3. The `photo_notes` bucket contract is private and owner-prefixed for read,
   insert, update and delete; public URLs are no longer the client contract.
4. Flutter Storage uses deterministic `{userId}/{mediaAssetId}/{variant}` keys,
   returns object paths and creates short-lived signed URLs for reads.
5. M3A source is implemented but not applied to Production. Runtime upload and
   outbox processing remain M3B.
6. Verification: `flutter analyze --no-pub` found no issues, the full Flutter
   suite passed 259/259, and `flutter build web --no-pub` succeeded.
7. The original 15-table schema was recovered as the first migration. Baseline
   plus all 19 incremental migrations applied successfully on Free Staging;
   local/remote history matches 20/20 and the remote is up to date.
8. Two-user Staging verification passed for normalized row isolation, private
   Storage ownership, owner upload and signed URL creation. Test users, rows and
   objects were removed. Production remains unchanged.
9. Post-Staging regression: `flutter analyze --no-pub` found no issues and the
   full Flutter suite passed 260/260.

### Update log — 2026-09-04 (M3B local sync worker)

1. Added a bounded, dependency-aware outbox worker with consent and owner-auth
   gates, retry/backoff, stale-running recovery and auth unblock on sign-in.
2. Added a native Supabase gateway for the five normalized M3A entities.
3. Media sync now uses deterministic two-phase upload: Storage object upsert,
   database metadata upsert, then local remote-path/status commit.
4. Photo Note operations now wait for media, scan and all detection/annotation
   evidence; purge completes its tombstone only after remote delete succeeds.
5. Targeted M3B/SQLite/Storage tests passed 20/20 and targeted analyzer found
   no issues; full analyzer was clean and the Flutter suite passed 267/267.
   Runtime scheduling and Staging worker E2E remain follow-ups; Production was
   not changed.

### Update log — 2026-09-04 (M3C runtime sync and offline startup)

1. Removed the remote health preflight from app bootstrap so a network outage
   no longer blocks local SQLite/media access or the rest of the UI.
2. Added a runtime coordinator driven by auth, cloud consent, outbox changes,
   SQLite `next_attempt_at` and app resume; logout and consent OFF cancel wake
   timers.
3. Added the native app-documents media resolver and a fail-closed Web factory.
4. Sync runtime is protected by `LIBRARY_SYNC_ENABLED` and defaults to `false`;
   this prevents an app still configured for Production from using the M3A
   contract before Production migration/backfill approval.
5. Targeted tests passed 23/23, full analyzer reported no issues, full Flutter
   regression passed 273/273, and Web build with the flag enabled succeeded.
6. Concurrent auth transitions are generation-guarded so an older owner
   subscription cannot survive a rapid logout/account switch.
7. Staging worker E2E, consent UI and Production rollout remain pending. No
   remote environment was changed in this increment.

### Update log — 2026-09-04 (real Staging worker E2E)

1. Added an opt-in test that runs the real SQLite store, outbox worker and
   Supabase gateway against the verified linked Staging project.
2. The worker completed 5/5 dependency operations, uploaded and downloaded two
   real private JPEG variants, and round-tripped media, raw scan JSON,
   detection, annotation and Photo Note rows through the owner session.
3. Media and raw-JSON SHA-256 values matched the real fixture bytes/content.
   Storage objects, all test rows and the temporary Auth user were removed;
   deterministic cleanup paths are registered before upload.
4. The runner refuses the wrong linked project, unhealthy status, more than two
   active projects or migration drift, and never prints or stores API keys.
5. Four live runs passed. Full analyzer was clean; the default suite passed
   273 tests and skipped the single opt-in live test as designed. Production
   remained unlinked and unchanged.

### Update log — 2026-09-04 (cloud-backup consent UI)

1. Settings now exposes an account-scoped cloud-backup switch backed by
   SQLite. Opt-in requires an explicit dialog; logout/loading/error states fail
   closed and an SQLite read error offers retry.
2. Each actual change appends a consent audit event with old/new values,
   `privacy-v1`, source action, UTC timestamp and applied enforcement state.
   First use bootstraps a fail-closed local account without overwriting a
   concurrently created account.
   Consent and scan request IDs share a core secure UUID v4 utility rather than
   coupling Settings to the Gemini service.
3. Consent copy states that only new scans are queued, local copies stay
   offline-readable, old cloud data is not auto-purged, and cloud backup does
   not grant on-device/federated training consent.
4. Supabase URL/anon key can be supplied by dart-define for a Staging build
   without editing `.env`; the smoke runner validates linked Staging and uses a
   temporary define file that is always deleted.
5. Consent/Settings tests passed 13/13, full analyzer was clean, and the full
   suite passed 279 tests with one live test skipped. Live Staging worker E2E
   passed again with cleanup.
6. This blocker was resolved on 2026-09-05: the Android v2 host now uses
   `com.capyvocab.app`; a sync-enabled Staging APK built, installed and passed
   startup/background/resume smoke on CPH2375. Authenticated consent-to-upload
   on the device remains pending. Production remained unlinked and unchanged.

### Update log — 2026-09-05 (Android Staging device smoke)

1. Scaffolded the Flutter Android v2 host with the owner-approved namespace and
   application ID `com.capyvocab.app`, plus Android Internet permission.
2. Extended the fail-closed Staging runner with Android build/device targets.
   It injects sync configuration through a temporary file, removes that file,
   and suppresses Gradle command echo while credentials are present.
3. A debug Staging APK built and installed on CPH2375 (Android 13). Supabase
   initialized, and HOME/resume kept the same process without a fatal log.
4. The first native launch exposed an auth redirect bug because `file:///` has
   no HTTP origin. Native auth now omits the email redirect while Web keeps its
   HTTP(S) origin; hot restart, six auth tests, analyzer and the 281-test full
   suite passed (one opt-in Staging test skipped).
5. The device remained unauthenticated, so consent interaction and an outbox
   upload originating from the device are still pending. Production was not
   linked or changed.

### Update log — 2026-08-08

The following work was completed or added to the repository today:

1. **Photo Scan Bottom Sheet & Control Layout**
   - Translucent sheet backdrop (`barrierColor: 0x66000000`) over live `HomeScreen`.
   - Single-row horizontal note template cards with green selection border (`#7CB342`).
   - Removed vertical scrollbar and expanded sheet container height to fit control layout perfectly.
   - Simplified image preview widget by removing text, leaving clean zoom icon.

2. **Notebook Capybara Vocab Canvas Overlay**
   - Redesigned `VocabCanvasOverlay` and `VocabOverlayPainter` using a warm notebook aesthetic.
   - Hand-drawn wobbly brown sketch outlines (`#B07748`) around detected objects.
   - Curved hand-drawn arrows with 3-stroke arrowheads pointing from note cards to object centers.
   - Rounded note cards (`#FDF6EC`) containing 2-digit index badge (`01`, `02`), English word, IPA, Vietnamese meaning, drop shadow, and orange doodle accents (`✦ ♡ ✶ ☁ ★`).

3. **Bottom Navigation Tab Routing**
   - Wired `BottomNavBar` tabs to GoRouter locations: `/home`, `/storage`, `/pet-shop`, `/friends`.
   - Created styled coming-soon screens for `StorageAlbumScreen`, `PetShopScreen`, and `FriendsLeaderboardScreen`.
   - Updated navigation tests to verify all 4 tabs switch locations properly.

4. **Global Instant Page Transitions (No Animations)**
   - Wrapped all `GoRoute`s in `AppRouter` with `NoTransitionPage`.
   - Configured `_NoTransitionsBuilder` in `AppTheme` for both light and dark themes to disable transitions globally.
   - Made `/scan` bottom sheet open instantly without slide transition.

5. **Automated Verification**
   - `flutter analyze`: 0 issues found.
   - `flutter test`: 56/56 passing tests.

### Update log — 2026-07-30

The following work was completed or added to the repository today:

1. **Three-state routing**
   - No authenticated session routes to `/auth`.
   - An authenticated user with `onboarding_completed = false` routes to
     `/onboarding`.
   - An authenticated user with `onboarding_completed = true` routes to
     `/home`.
   - The completion flag is read from `public.users`, not Auth session
     metadata.
2. **Registration profile name**
   - Added the `Họ tên` field to registration.
   - Trimmed and passed `displayName` through the provider and repository to
     Supabase Auth metadata.
3. **Five-step onboarding**
   - Preserved the required order: name/username, age/phone, role, study time,
     daily word target.
   - Added per-step validation, username availability check, retained form
     state, back/next navigation, loading protection, clear save errors, and
     retry behavior.
   - Implemented role selection with two cards and study time with Flutter's
     time picker.
4. **Atomic onboarding persistence**
   - Added `public.complete_onboarding(...)` to update `users` and
     `user_settings` together.
   - `onboarding_completed` is set only after both profile and settings writes
     succeed.
   - Added migration
     `supabase/migrations/20260730_complete_onboarding_rpc.sql`; the RPC was
     applied and transaction rollback behavior was verified on Production.
5. **Database security artifacts**
   - Added the secure schema snapshot and
     `20260730_align_secure_schema.sql`.
   - The alignment migration is a reviewed target artifact; this status file
     does not claim that the complete RLS alignment migration has been applied
     to Production.
6. **Automated coverage**
   - Added Auth tests for the registration name field and trimmed repository
     input.
   - Added Onboarding provider tests for ordered validation, retained state,
     duplicate-submit protection, and retry after failure.
   - Added a widget test covering the five onboarding screens in order.
7. **Project handoff and assets**
   - Added repository operating instructions, local agent skills, Supabase
     schema/migration structure, Flutter web bootstrap files, and the eight
     supplied design reference images.

Explicitly deferred: Google/Facebook OAuth UI, pixel-perfect implementation of
the eight designs, real study reminder scheduling, and the `/home` learning
experience.

## 2. Status legend

| Status | Meaning |
| --- | --- |
| ✅ Working | Implemented and covered by at least static analysis/smoke verification |
| 🟡 Partial | Some real service or data-access code exists; end-to-end flow is missing |
| ⬜ Scaffold | File/route exists but UI, state, entity, or business logic is a placeholder |
| ⏸ Deferred | Intentionally excluded from the current phase |
| ⚠️ Blocked | Must be resolved before a production release |

## 3. Milestone status

### Phase 1 — Technical foundation

| Capability | Status | Evidence / notes |
| --- | --- | --- |
| Supabase initialization | ✅ Working | Uses `publishableKey` in `lib/core/services/supabase_service.dart` |
| Production Data API reachability | ✅ Working | Audit received HTTP 200 from all 15 table endpoints |
| Offline-tolerant startup | ✅ Working | `lib/main.dart` initializes the client without a remote preflight; network failure does not block local UI |
| Cloud degraded retry | 🟡 Partial | Library outbox retries by SQLite schedule/app resume when enabled; no global connectivity indicator yet |
| Email/password repository | ✅ Working | Sign-up, sign-in, sign-out implemented |
| Riverpod auth state | ✅ Working | `AsyncValue<Session?>` |
| Auth error mapping | ✅ Working | Invalid credentials, existing email, unconfirmed email |
| Auth form | ✅ Working | Validation, loading state, inline error messages |
| Route guard | ✅ Working | Three-state redirect using session plus `public.users.onboarding_completed` |
| Automatic `public.users` profile trigger | ✅ User-reported | Created manually in Supabase Dashboard; not independently audited |
| Production auth acceptance test | ⚠️ Pending | Must be run with the owner's pre-created auto-confirmed account |
| Production RLS/security audit | ⚠️ Pending | REST access does not prove every policy is safe |

Phase 1 is **code-complete but not accepted for release** until the two
pending production checks above pass.

### Current Phase 2 milestone

**Phase 2 — First usable learning loop**

Onboarding is complete. Continue this vertical slice before expanding into
games or social features:

```text
authenticated user
  -> determine onboarding status [implemented]
  -> onboarding form [implemented]
  -> create/update profile and settings [implemented]
  -> home lesson map
  -> open lesson
  -> complete one vocabulary activity
  -> persist progress
  -> return to updated home state
```

This is the shortest path from “authentication works” to “the product is
actually useful.”

## 4. Feature matrix

| Area | Status | Real implementation | Missing end-to-end work |
| --- | --- | --- | --- |
| Bootstrap / health | ✅ Working | Supabase config initialization without remote startup gate; configuration-error UI on init failure | Add a non-blocking cloud status indicator if product UX requires it |
| Email/password Auth | ✅ Working | Repository, Riverpod notifier, form, validation, name metadata, errors, Web email-confirmation redirect via the current origin, focused tests | Dashboard redirect allowlist and manual email-confirmation acceptance |
| Session routing | ✅ Working | Guarded routes, auth stream listener, profile completion lookup | Intended-route restoration; explicit expired-session UX |
| Google OAuth | ⏸ Deferred | Repository method exists | Provider config, UI, deep links/callbacks |
| Password recovery | ⏸ Deferred | Send-reset repository method exists | Callback/deep link and update-password UI |
| Onboarding | ✅ Working | Five-step provider/UI, validation, username check, time picker, atomic RPC persistence, retry/loading behavior, tests | Production manual journey test; pixel-perfect design and real reminder scheduling are deferred |
| Home / lesson map | 🟡 Partial | User and vocabulary Supabase access classes | Providers, UI, lesson flow, progress wiring |
| AI photo scan | 🟡 Partial | Gemini Edge flow, app-local JPEG, normalized SQLite aggregate, Staging-verified two-phase worker and default-off runtime coordinator | Consent UI, device lifecycle smoke, Library UI/album flow, Web durable media, on-device trainer |
| Photo mini-games | ⬜ Scaffold | Routes/files and dependencies | Game state, questions, scoring, UI, persistence |
| Solo Arena | 🟡 Partial | Supabase/Realtime data source | Entities, matchmaking state, battle UI, result flow |
| Pet shop | 🟡 Partial | Supabase shop data source; payment gateway shell | Entities, provider, UI, atomic purchase logic, real payment SDK |
| Friends / leaderboard | 🟡 Partial | Supabase friends data source | Entities, provider, UI, request lifecycle validation |
| Chatbot | 🟡 Partial | Supabase chat data source | Entity, provider, AI orchestration, inbox/detail UI |
| Notifications | 🟡 Partial | Supabase notification data source | Provider, item UI, center screen, unread badge |
| Settings / subscription | 🟡 Partial | Subscription data source; payment shell | Provider, settings UI, theme wiring, purchase verification |
| Shared navigation | ⬜ Scaffold | File exists | Bottom navigation and feature entry points |
| Shared UI/services | ⬜ Scaffold | Design tokens and package dependencies | Most reusable widgets, audio, TTS, confetti, local storage |

The previous audit count of 131 TODO/scaffold markers is no longer current
because onboarding placeholders were replaced on 2026-07-30. Recount before
using TODO totals for planning. Most presentation layers beyond Auth and
Onboarding remain placeholders.

## 5. Current runtime route map

| Flutter route | Authentication | Current screen status |
| --- | --- | --- |
| `/auth` | Public; authenticated users redirect according to profile completion | ✅ Functional |
| `/onboarding` | Required; incomplete profiles remain here | ✅ Functional |
| `/home` | Required | ⬜ Placeholder |
| `/storage` | Required | ⬜ Placeholder |
| `/solo-arena` | Required | ⬜ Placeholder |
| `/pet-shop` | Required | ⬜ Placeholder |
| `/friends` | Required | ⬜ Placeholder |
| `/settings` | Required | ⬜ Placeholder |

Mini-games, notifications, and chat screens exist in source but do not yet
have top-level router entries.

## 6. Backend map

The repository schema defines these 15 public tables:

| Domain | Tables |
| --- | --- |
| User | `users`, `user_settings` |
| Learning | `lessons`, `vocabularies`, `user_vocab_progress` |
| AI notes | `photo_notes`, `photo_note_vocabularies` |
| Arena | `solo_arena_matches` |
| Shop | `pet_items`, `user_pet_inventory`, `shop_purchases` |
| Social | `friends`, `chat_messages`, `notifications` |
| Billing | `subscriptions` |

Realtime publication is intended for:

- `solo_arena_matches`
- `chat_messages`
- `notifications`

Storage currently uses the `photo_notes` bucket.

Important: table existence and HTTP 200 responses confirm Data API exposure,
not the correctness of every RLS policy, trigger, index, or publication.

## 7. Web integration map

This section is the contract for future websites that need to connect to the
same product.

### 7.1 Public marketing website

A landing page can be built independently. It should link to:

- App download/install destinations — **TBD**
- Privacy policy — **TBD**
- Terms of service — **TBD**
- Support/contact page — **TBD**
- Web app login — **TBD**

No production secrets are required for a static marketing site.

### 7.2 Authenticated web app

A web app may use the same Supabase project and the same user identities.
Use the official Supabase web client with:

- Supabase project URL
- Supabase publishable key

Never expose:

- Supabase secret key
- `service_role`
- Direct database password/connection string
- Gemini server key
- Payment provider secrets

Mobile and web sessions belong to the same user account but are stored per
client/device. Do not assume a Flutter session automatically logs a browser
in.

The web app must enforce authorization through the same RLS model. Hiding a
button or route in the browser is not authorization.

### 7.3 Admin website

An admin dashboard must use a trusted server/API layer for privileged
operations. A service-role or secret key must never be shipped to browser
JavaScript.

Before an admin site is started, define:

- Admin roles in trusted `app_metadata` or a private authorization table
- Server-side authorization checks
- Audit logging requirements
- Which tables/actions admins may access

Do not use user-editable `user_metadata` to grant administrative privileges.

### 7.4 Web auth callbacks

The Flutter Web email-confirmation callback is wired on the application side:

- Email sign-up sends `Uri.base.origin` as `emailRedirectTo`, so local and
  deployed Web domains are detected at runtime.
- `supabase_flutter` keeps its default `detectSessionInUri = true` behavior and
  restores the session from the confirmation URL.
- The router listens to `onAuthStateChange`; a newly confirmed account with
  incomplete onboarding is redirected to `/onboarding`.

Each demo or production origin must still be added to the Supabase Auth
redirect allowlist, and the real email round trip requires manual acceptance.
Password recovery and Google OAuth callbacks use the native URL scheme
`capyvocab://` on Android/iOS. The following URLs must also be allowlisted in
Supabase Auth before completing a real mobile email/OAuth round trip:

- `capyvocab://login-callback/`
- `capyvocab://reset-password/`

### 7.5 AI and payment boundaries

The Flutter bundle contains only the public Supabase URL and publishable key in
`assets/config/client.config`. `GEMINI_API_KEY` is read only by the Supabase Edge
Function and must remain configured as a server-side secret.

Payment operations also need a trusted backend/webhook that verifies provider
receipts before updating coins, purchases, or subscriptions.

## 8. Priority backlog

### P0 — Urgent, before broader feature development or release

1. Run the production email/password acceptance checklist.
2. Audit and harden Production RLS, Storage policies, triggers, and grants.
3. Build the home lesson map and complete the remaining first usable learning
   vertical slice.

### P1 — Medium

1. Implement home providers/screens.
2. Wire lesson and vocabulary progress to the existing Supabase data layer.
3. Extend automated tests to auth errors, route guards, session changes, and
   Production-safe integration coverage.
4. Implement password recovery; manually accept the Web email-confirmation
   callback against each allowlisted deployment origin.
5. Define the canonical production Web domain and privacy/terms/support URLs.
6. Make `supabase/schema/supabase_schema_final_secure.sql` idempotent and place schema changes in `supabase/migrations/`.
7. Make the health retry path handle a failed Supabase initialization.

### P2 — Lower priority

1. Enable and implement Google OAuth.
2. Implement social, arena, shop, chatbot, and notification presentation
   layers after the core learning loop works.
3. Integrate payment providers and receipt verification.
4. Implement shared UI polish, audio, TTS, confetti, assets, and localization.
5. Replace stale Firebase/Firestore descriptions in the legacy README.

## 9. Verification snapshot

Last local verification:

```text
flutter analyze --no-pub
  -> No issues found

flutter test --no-pub <M3C targeted files>
  -> 23/23 passed

flutter test --no-pub --reporter compact
  -> 273 passed, 1 opt-in live Staging test skipped by default
  -> one earlier parallel run reported one unidentified failure; two complete
     reruns passed, so test-suite flakiness remains under observation

flutter build web --no-pub --dart-define=LIBRARY_SYNC_ENABLED=true
  -> succeeded
  -> existing flutter_tts Wasm dry-run and CupertinoIcons warnings only

git diff --check
  -> passed
  -> line-ending warnings only (LF will be converted to CRLF)

tool/run_staging_library_sync_e2e.ps1
  -> passed twice with real private files and authenticated owner
  -> all temporary Storage objects, rows and Auth user cleaned up
  -> Production not linked or changed
```

Manual verification of the real email-confirmation round trip and the complete
registration-to-home journey is still required. Automated Flutter tests do not
create Production Auth accounts.

## 10. Rules for another AI or developer

1. Read this file before assuming a feature is implemented.
2. A Supabase data source does not mean its UI or business flow is complete.
3. Preserve Phase 1 Auth behavior and the M3C offline-startup contract; do not
   reintroduce a blocking remote health preflight.
4. Never print or commit `.env`, tokens, database URLs, or secret keys.
5. Do not add a service-role key to Flutter or browser code.
6. Treat `supabase/schema/supabase_schema_final_secure.sql` as the database design snapshot, and place all new DB changes into `supabase/migrations/`.
7. Run `flutter analyze` and `flutter test` after changes.
8. Update this document whenever a milestone or feature status materially
   changes.

## 11. Source entry points

- App bootstrap: `lib/main.dart`
- Supabase wrapper: `lib/core/services/supabase_service.dart`
- Router and auth guard: `lib/core/routes/app_router.dart`
- Auth repository: `lib/features/auth/data/repositories/auth_repository_impl.dart`
- Auth state: `lib/features/auth/presentation/providers/auth_provider.dart`
- Auth UI: `lib/features/auth/presentation/screens/auth_screen.dart`
- Onboarding repository: `lib/features/onboarding/data/repositories/onboarding_repository.dart`
- Onboarding state: `lib/features/onboarding/presentation/providers/onboarding_provider.dart`
- Onboarding wizard: `lib/features/onboarding/presentation/screens/onboarding_wizard_screen.dart`
- Database design snapshot: `supabase/schema/supabase_schema_final_secure.sql`
- Database migrations: `supabase/migrations/`
- Dependencies: `pubspec.yaml`

## 12. External references

- [Supabase Flutter reference](https://supabase.com/docs/reference/dart/introduction)
- [Supabase Flutter initialization](https://supabase.com/docs/reference/dart/initializing)
- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Supabase user sessions](https://supabase.com/docs/guides/auth/sessions)

## 13. Nhật ký thay đổi ngày 30/07/2026 (Change Log)

- **Router ba trạng thái:** Điều hướng 3 trạng thái (`/auth`, `/onboarding`, `/home`) dựa trên Auth session và `public.users.onboarding_completed`.
- **Form đăng ký có họ tên:** Thêm trường `Họ tên` (`displayName`) trong form đăng ký auth và truyền vào metadata Supabase Auth.
- **Onboarding 5 bước & RPC atomic:** Hoàn thiện luồng Onboarding 5 bước (tên/username, tuổi/SĐT, vai trò, thời gian học, mục tiêu từ vựng hàng ngày) và lưu dữ liệu atomic qua RPC `public.complete_onboarding(...)`.
- **Supabase Migration / Schema mới:** Thêm các migration `20260730_complete_onboarding_rpc.sql`, `20260730_align_secure_schema.sql` cùng bản cập nhật snapshot schema an toàn.
- **Tiến độ chuyển sang Phase 2:** Chuyển trọng tâm sang Phase 2 — Vòng lặp học tập đầu tiên (First usable learning loop).
- **Cập nhật trạng thái Onboarding:** Onboarding chính thức chuyển từ `⬜ Scaffold` sang `✅ Working`.
- **Kết quả Kiểm thử & Phân tích:** Đạt `8/8` tests (`flutter test`) và `dart analyze` sạch (exit code 0, không có lỗi hay cảnh báo).
- **Backlog mới:** Ưu tiên xây dựng `HomeScreen` và luồng học bài (`Home/lesson learning loop`).
- **Các hạng mục tiếp tục hoãn (Deferred):** Google/Facebook OAuth UI, thiết kế Pixel-perfect theo 8 bản mẫu UI, và thông báo đẩy (notification) thật.

## 14. Nhật ký thay đổi ngày 04/08/2026 (Change Log)

### A. Tùy chỉnh khung giờ học (Onboarding Step 4)
- **Thêm tùy chọn Tùy chỉnh:** Thêm ô thẻ thứ 5 `⏱️ Tùy chỉnh khung giờ` (`_CustomTimeSlotCard`) bên dưới 4 khung giờ cố định.
- **Bánh xe cuộn kiểu Cupertino (Scroll Wheel Picker):** Mở Bottom Sheet tích hợp `CupertinoDatePicker` cho phép người dùng cuộn chọn **Giờ bắt đầu** và **Giờ kết thúc** linh hoạt.
- **Tương thích Backend 100%:** Trích xuất giờ bắt đầu dạng chuỗi `HH:mm` đồng bộ vào `reminderTime` đẩy lên Supabase RPC `complete_onboarding(...)` mà không làm thay đổi hay ảnh hưởng logic Backend (0% impact).

### B. Đồng bộ Nút Đăng nhập Mạng xã hội & Sửa Logo Google (Auth Screen)
- **Vẽ lại Logo Google G 4 màu chuẩn:** Thay thế chữ `G` văn bản cũ bằng Logo Google 4 màu (Đỏ, Vàng, Xanh lá, Xanh dương) chuẩn tỷ lệ gốc bằng `CustomPainter` (`_GoogleGLogoPainter`), khắc phục lỗi nét vẽ méo cũ.
- **Căn lề thẳng hàng tuyệt đối (Stack Layout):** Căn lề icon cố định `Positioned(left: 20)` trên cả 2 nút Google và Facebook, giúp 2 icon luôn nằm trên cùng một hàng dọc thẳng đứng.
- **Đồng bộ Typography:** Đồng bộ phông chữ Fredoka `fontSize: 15`, `fontWeight: w700`, `height: 1.2` giúp chữ căn giữa chính xác theo chiều dọc với icon.

### C. Thêm mới Video Header Widgets & Media Assets
- **Video Header Animation:** Tạo widget `capy_video_header.dart` và `capy_onboarding_header.dart` hiển thị video hoạt hình chú chuột lang Capybara sống động tại màn Auth và Onboarding.
- **Assets:** Thêm video assets `assets/CapyLogin.mp4` & `assets/CapyOnboarding.mp4`.

### D. Kiểm thử & Đánh giá (Testing)
- **Widget Test:** Thêm test case kiểm tra sự xuất hiện và tương tác ô Tùy chỉnh khung giờ tại `onboarding_wizard_screen_test.dart`.
- **Kết quả Kiểm thử:** Chạy `flutter test` đạt **`22/22` tests passed!**

---

### E. Danh sách các File đã Thay đổi & Thêm mới (Files Summary)

#### 1. Các File đã thay đổi (Modified - `M`):
- `lib/features/auth/presentation/widgets/social_auth_button.dart` *(Vẽ logo Google 4 màu, căn lề Stack 20px)*
- `lib/features/auth/presentation/screens/auth_screen.dart` *(Cập nhật giao diện Đăng nhập)*
- `lib/features/onboarding/presentation/widgets/step4_study_time.dart` *(Thêm ô Tùy chỉnh & Cupertino Scroll Wheel Picker)*
- `lib/features/onboarding/presentation/screens/onboarding_wizard_screen.dart` *(Cập nhật luồng Onboarding)*
- `lib/features/onboarding/presentation/widgets/step1_name_username.dart`
- `lib/features/onboarding/presentation/widgets/step2_age_phone.dart`
- `lib/features/onboarding/presentation/widgets/step3_role_selector.dart`
- `lib/features/onboarding/presentation/widgets/step5_daily_target.dart`
- `test/features/auth/auth_screen_test.dart`
- `test/features/onboarding/onboarding_wizard_screen_test.dart` *(Bổ sung test case Step 4)*
- `pubspec.yaml`, `pubspec.lock`, `.env.example`, `.flutter-plugins-dependencies`, `AGENTS.md`

#### 2. Các File mới được tạo / thêm mới (Untracked - `U`):
- `lib/features/auth/presentation/widgets/capy_video_header.dart`
- `lib/features/onboarding/presentation/widgets/capy_onboarding_header.dart`
- `assets/CapyLogin.mp4`
- `assets/CapyOnboarding.mp4`
- `implementation_plan.md`
- `android/`, `ios/`, `macos/` *(Thư mục cấu hình build platform)*

## 15. Nhật ký thay đổi ngày 06/08/2026 (Change Log)

### A. Responsive Layout & Giao diện đa nền tảng
- **Hệ thống Responsive Layout:** Tạo widget `responsive_layout.dart` (`ResponsiveLayout`) tự động thích ứng giao diện giữa các kích thước màn hình Mobile, Tablet và Desktop.
- **Tối ưu hóa Onboarding & Auth Screen:** Cập nhật `auth_screen.dart`, `capy_video_header.dart`, `onboarding_wizard_screen.dart`, `step4_study_time.dart` cho trải nghiệm mượt mà trên đa màn hình.

### B. Bổ sung Assets & Cấu hình Môi trường
- **Assets hình nền mới:** Thêm `assets/capy_background.png` và `assets/capy_background_mobile.png`.
- **Cấu hình môi trường `.env`:** Tạo file `.env` từ `.env.example` phục vụ việc nạp asset bundle và cấu hình kết nối Supabase/Gemini.

### C. Quản lý Mã nguồn (Git Workflow)
- **Commit & Push an toàn:** Commit và đẩy code thành công vào nhánh `nam-30-7` trên các remote (`vocab1` và `origin`), giữ nguyên an toàn cho nhánh `main`.

---

### D. Danh sách các File đã Thay đổi & Thêm mới (Files Summary)

#### 1. Các File đã thay đổi (Modified - `M`):
- `lib/features/auth/presentation/screens/auth_screen.dart` *(Cập nhật giao diện Đăng nhập)*
- `lib/features/auth/presentation/widgets/capy_video_header.dart` *(Tối ưu hiển thị video header)*
- `lib/features/onboarding/presentation/screens/onboarding_wizard_screen.dart` *(Cập nhật giao diện wizard onboarding)*
- `lib/features/onboarding/presentation/widgets/step4_study_time.dart` *(Tối ưu ô tùy chỉnh thời gian học)*
- `assets/CapyLogin.mp4`, `assets/CapyOnboarding.mp4` *(Cập nhật video asset)*
- `pubspec.yaml` *(Cập nhật asset declaration)*

#### 2. Các File mới được tạo / thêm mới (New Files):
- `lib/core/widgets/responsive_layout.dart` *(Widget hỗ trợ giao diện responsive)*
- `assets/capy_background.png`, `assets/capy_background_mobile.png` *(Hình nền mới)*
- `.claude/skills/flutter-build-responsive-layout/SKILL.md` *(Skill hướng dẫn xây dựng responsive layout)*
- `skills-lock.json`
- `.env` *(File cấu hình biến môi trường cục bộ)*

## 16. Tình trạng dự án ngày 10/08/2026 (Current Project Status)

### A. Trạng thái mã nguồn và đồng bộ GitHub

- Đã fetch và đồng bộ phần thiết kế mới nhất từ `origin/main` thông qua PR #5.
- Commit đang được kiểm chứng: `abe5d04` (`Merge pull request #5 from emtonny/nam-30-7`).
- Nhánh local `main` đã khớp hoàn toàn với `origin/main` (`0` commit ahead, `0` commit behind).
- Working tree hiện ở nhánh `AI-scan`; nội dung tracked đã khớp với `origin/main` và đang ahead `origin/AI-scan` 6 commit. Chưa push thay đổi này lên `origin/AI-scan`.
### B. Các luồng và giao diện hiện đã có

1. **Khởi động, Auth và Onboarding**
   - Giữ nguyên luồng `startup -> health check -> auth -> onboarding 5 bước -> home`.
   - Router tiếp tục bảo vệ luồng theo session và trạng thái `onboarding_completed`.
   - Giao diện Auth và Onboarding đã có video header, hình nền và bố cục responsive cho mobile/tablet/desktop.

2. **Home và điều hướng chính**
   - `HomeScreen` đã được thay thế từ placeholder bằng giao diện dashboard phong cách sổ tay Capybara.
   - Bottom navigation đã điều hướng thật giữa 4 route: `/home`, `/storage`, `/pet-shop`, `/friends`.
   - Nút Camera trung tâm mở luồng `/scan`; trạng thái tab active được xác định từ route hiện tại.
   - Toàn bộ route dùng chuyển trang tức thời; `/scan` mở dạng overlay có nền tối mà không chạy hiệu ứng slide.

3. **AI Scan và Vocabulary Overlay**
   - Photo Scan Bottom Sheet hỗ trợ chọn ảnh/camera, xử lý ảnh và đi qua pipeline scan hiện có.
   - Kết quả scan được hiển thị bằng notebook-style vocabulary canvas overlay với bounding box, mũi tên, số thứ tự, từ tiếng Anh, IPA và nghĩa tiếng Việt.
   - Luồng lỗi camera, lỗi nén ảnh, lỗi API và dữ liệu bounding box tiếp tục có test tự động bảo vệ.

4. **Các màn bổ trợ**
   - `StorageAlbumScreen`, `PetShopScreen` và `FriendsLeaderboardScreen` đã có giao diện đồng bộ và route truy cập.
   - Các màn này hiện chủ yếu là presentation/coming-soon; nghiệp vụ dữ liệu thật, giao dịch cửa hàng, social/leaderboard realtime và vòng lặp học hoàn chỉnh vẫn chưa được triển khai đầy đủ.

### C. Assets và responsive layout

- Asset bundle hiện dùng khai báo `assets/` trong `pubspec.yaml`.
- Đã có video `CapyLogin.mp4`, `CapyOnboarding.mp4` và hai ảnh nền `capy_background.png`, `capy_background_mobile.png`.
- `ResponsiveLayout` đã được thêm để phân nhánh bố cục mobile/tablet/desktop dựa trên không gian hiển thị.
- Các màn Auth, Onboarding và video header đã được tối ưu lại để sử dụng bộ asset và bố cục responsive mới.

### D. Kết quả kiểm chứng ngày 10/08/2026

```text
flutter pub get
  -> thành công
  -> SDK local resolve meta/test_api thấp hơn lockfile trên GitHub;
     lockfile được giữ nguyên theo commit abe5d04 để bảo toàn trạng thái đồng bộ

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub \
  test/shared/navigation/bottom_nav_bar_test.dart \
  test/features/ai_scan/photo_scan_bottom_sheet_test.dart
  -> 7/7 tests passed

flutter test --no-pub
  -> 56/56 tests passed

flutter build web --no-pub
  -> build thành công tại build/web

git diff --check
  -> passed

HEAD...origin/main
  -> 0 ahead / 0 behind
```

### E. Cảnh báo và phần việc còn lại

- Web build thành công nhưng còn cảnh báo không chặn về font `CupertinoIcons`; cần kiểm tra lại dependency/asset font nếu UI sử dụng icon Cupertino trên Web.
- `flutter_tts 4.2.5` còn cảnh báo tương thích WebAssembly từ mã dependency; build Web JavaScript thông thường vẫn thành công.
- Cần kiểm thử thủ công trên thiết bị thật và nhiều kích thước màn hình để xác nhận video, camera, touch target, overflow và breakpoint responsive.
- Cần kiểm thử Production cho email confirmation, Auth callback, Supabase RLS/RPC và hành trình đăng ký đến Home.
- Vòng lặp học chính, dữ liệu Home thật, Storage, Shop, Friends/Leaderboard, Arena, chatbot, notification và thanh toán vẫn là các hạng mục chưa hoàn thiện đầy đủ.
- Chưa thực hiện commit hoặc push cho lần cập nhật tài liệu ngày 10/08/2026.

