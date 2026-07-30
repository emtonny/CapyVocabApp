# Capy Vocab — Project Status & AI Handoff

> Last audited: 2026-07-29  
> Source of truth for current implementation status, integration boundaries, and next work.  
> Do not copy secrets, production URLs, access tokens, or service-role keys into this file.

```yaml
project:
  name: Capy Vocab
  type: Flutter client application
  version: 0.1.0
  current_milestone: "Phase 1 — Technical foundation"
  phase_1_code_status: "implemented"
  phase_1_acceptance_status: "pending production manual test and security audit"
  product_status: "authentication shell; core learning features are not implemented"
  release_ready: false
backend:
  provider: Supabase
  production_connection: "reachable from the configured Flutter environment"
  public_tables_detected: 15
frontend:
  working_user_flow: "startup -> health check -> email/password auth -> guarded /home"
  first_blocking_placeholder: "/home"
tests:
  automated: "one Flutter startup smoke test"
  last_result: "passing"
```

## 1. Executive summary

The project is at the end of the **technical foundation phase**, not at the
end of the MVP.

The application can currently:

1. Load its environment configuration.
2. Initialize the Supabase Flutter client with a publishable key.
3. Test access to the production Data API before opening the main app.
4. Show a retry screen when the health check fails.
5. Sign up and sign in with email/password.
6. Present distinct authentication errors.
7. Persist/read the Supabase session.
8. Guard application routes and react to auth session changes.

After authentication, the router opens `/home`, but `HomeScreen` is still a
placeholder. Onboarding, learning, scanning, games, arena, shop, friends,
chat, notifications, and settings are not yet complete user flows.

**Practical description:** the app has a working front door and backend
adapters, but most rooms behind that front door have not been built.

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
| Startup health gate | ✅ Working | `lib/main.dart` blocks the normal app when `testConnection()` returns false |
| Retry UI | ✅ Working | Retry calls `SupabaseService.testConnection()` |
| Email/password repository | ✅ Working | Sign-up, sign-in, sign-out implemented |
| Riverpod auth state | ✅ Working | `AsyncValue<Session?>` |
| Auth error mapping | ✅ Working | Invalid credentials, existing email, unconfirmed email |
| Auth form | ✅ Working | Validation, loading state, inline error messages |
| Route guard | ✅ Working | Session-based redirect with `onAuthStateChange` refresh |
| Automatic `public.users` profile trigger | ✅ User-reported | Created manually in Supabase Dashboard; not independently audited |
| Production auth acceptance test | ⚠️ Pending | Must be run with the owner's pre-created auto-confirmed account |
| Production RLS/security audit | ⚠️ Pending | REST access does not prove every policy is safe |

Phase 1 is **code-complete but not accepted for release** until the two
pending production checks above pass.

### Recommended next milestone

**Phase 2 — First usable learning loop**

Build this vertical slice before expanding into games or social features:

```text
authenticated user
  -> determine onboarding status
  -> onboarding form
  -> create/update profile and settings
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
| Bootstrap / health | ✅ Working | Supabase init, connection test, retry screen | Reinitialize client if initialization itself fails |
| Email/password Auth | ✅ Working | Repository, Riverpod notifier, form, validation, errors | Production manual acceptance; focused auth tests |
| Session routing | ✅ Working | Guarded routes and auth stream listener | Intended-route restoration; explicit expired-session UX |
| Google OAuth | ⏸ Deferred | Repository method exists | Provider config, UI, deep links/callbacks |
| Password recovery | ⏸ Deferred | Send-reset repository method exists | Callback/deep link and update-password UI |
| Onboarding | ⬜ Scaffold | Route and placeholder files | Entity, provider, five steps, persistence, completion flag |
| Home / lesson map | 🟡 Partial | User and vocabulary Supabase access classes | Providers, UI, lesson flow, progress wiring |
| AI photo scan | 🟡 Partial | Gemini HTTP service, image compression, storage wrapper | Secure backend proxy, entities, provider, scan UI, album flow |
| Photo mini-games | ⬜ Scaffold | Routes/files and dependencies | Game state, questions, scoring, UI, persistence |
| Solo Arena | 🟡 Partial | Supabase/Realtime data source | Entities, matchmaking state, battle UI, result flow |
| Pet shop | 🟡 Partial | Supabase shop data source; payment gateway shell | Entities, provider, UI, atomic purchase logic, real payment SDK |
| Friends / leaderboard | 🟡 Partial | Supabase friends data source | Entities, provider, UI, request lifecycle validation |
| Chatbot | 🟡 Partial | Supabase chat data source | Entity, provider, AI orchestration, inbox/detail UI |
| Notifications | 🟡 Partial | Supabase notification data source | Provider, item UI, center screen, unread badge |
| Settings / subscription | 🟡 Partial | Subscription data source; payment shell | Provider, settings UI, theme wiring, purchase verification |
| Shared navigation | ⬜ Scaffold | File exists | Bottom navigation and feature entry points |
| Shared UI/services | ⬜ Scaffold | Design tokens and package dependencies | Most reusable widgets, audio, TTS, confetti, local storage |

Audit signal: there are currently **131 TODO/scaffold marker lines** under
`lib/`. Except for Auth, every presentation provider remains a roughly
20-line placeholder.

## 5. Current runtime route map

| Flutter route | Authentication | Current screen status |
| --- | --- | --- |
| `/auth` | Public; redirects to `/home` when a session exists | ✅ Functional |
| `/onboarding` | Required | ⬜ Placeholder |
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

### 7.4 Callback and deep-link pages

These are not configured yet:

- Email confirmation callback
- Password recovery callback
- Google OAuth callback
- Mobile universal/app links
- Canonical production web domain

Before OAuth or password recovery work begins, decide the canonical URLs and
add them to Supabase Auth redirect allowlists.

### 7.5 AI and payment boundaries

The Flutter project currently reads `GEMINI_API_KEY` from its bundled `.env`.
That is not safe for production. Move Gemini calls to a server or Supabase
Edge Function before publishing the app or connecting a public website.

Payment operations also need a trusted backend/webhook that verifies provider
receipts before updating coins, purchases, or subscriptions.

## 8. Priority backlog

### P0 — Urgent, before broader feature development or release

1. Run the production email/password acceptance checklist.
2. Audit and harden Production RLS, Storage policies, triggers, and grants.
3. Remove Gemini secrets from the Flutter bundle; create a trusted AI proxy.
4. Decide whether a new user goes to onboarding or directly to `/home`.
5. Add an onboarding-completion source of truth and implement the first usable
   learning vertical slice.

### P1 — Medium

1. Implement onboarding and home providers/screens.
2. Wire lesson and vocabulary progress to the existing Supabase data layer.
3. Add automated tests for auth errors, loading, route guards, and session
   changes.
4. Implement password recovery and email confirmation callback handling.
5. Define web domains, deep links, privacy/terms/support URLs.
6. Make `supabase/schema/supabase_schema_final_secure.sql` idempotent and place schema changes in `supabase/migrations/`.
7. Make the health retry path handle a failed Supabase initialization.

### P2 — Lower priority

1. Enable and implement Google OAuth.
2. Implement social, arena, shop, chatbot, and notification presentation
   layers after the core learning loop works.
3. Integrate payment providers and receipt verification.
4. Implement shared UI polish, audio, TTS, confetti, assets, and localization.
5. Remove the two remaining analyzer info notices.
6. Replace stale Firebase/Firestore descriptions in the legacy README.

## 9. Verification snapshot

Last local verification:

```text
flutter test
  -> all tests passed (1 startup smoke test)

flutter analyze
  -> no errors
  -> 2 info-level notices in gemini_vision_service.dart
```

Manual production verification is still required. Automated tests do not call
Production Auth or create test accounts.

## 10. Rules for another AI or developer

1. Read this file before assuming a feature is implemented.
2. A Supabase data source does not mean its UI or business flow is complete.
3. Preserve the Phase 1 Auth and health-gate behavior.
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
- Database design snapshot: `supabase/schema/supabase_schema_final_secure.sql`
- Database migrations: `supabase/migrations/`
- Dependencies: `pubspec.yaml`

## 12. External references

- [Supabase Flutter reference](https://supabase.com/docs/reference/dart/introduction)
- [Supabase Flutter initialization](https://supabase.com/docs/reference/dart/initializing)
- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Supabase user sessions](https://supabase.com/docs/guides/auth/sessions)

