# Capy Vocab — Project Status & AI Handoff

> Last audited: 2026-08-08
> Source of truth for current implementation status, integration boundaries, and next work.
> Do not copy secrets, production URLs, access tokens, or service-role keys into this file.

```yaml
project:
  name: Capy Vocab
  type: Flutter client application
  version: 0.1.0
  current_milestone: "Phase 2 — First usable learning loop"
  phase_1_code_status: "implemented"
  phase_1_acceptance_status: "pending production manual test and security audit"
  product_status: "authentication, onboarding, photo scan bottom sheet, and tab navigation routing implemented"
  release_ready: false
backend:
  provider: Supabase
  production_connection: "reachable from the configured Flutter environment"
  public_tables_detected: 15
frontend:
  working_user_flow: "startup -> health check -> email/password auth -> five-step onboarding -> guarded /home -> bottom tab routing & photo scan"
  first_blocking_placeholder: "/home"
tests:
  automated: "56 Flutter unit & widget tests"
  last_result: "56/56 passing on 2026-08-08"
```

## 1. Executive summary

The project has completed the code portion of the **technical foundation
phase** and has started the **first usable learning loop**. It is not yet an
MVP.

The application can currently:

1. Load its environment configuration.
2. Initialize the Supabase Flutter client with a publishable key.
3. Test access to the production Data API before opening the main app.
4. Show a retry screen when the health check fails.
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
| Startup health gate | ✅ Working | `lib/main.dart` blocks the normal app when `testConnection()` returns false |
| Retry UI | ✅ Working | Retry calls `SupabaseService.testConnection()` |
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
| Bootstrap / health | ✅ Working | Supabase init, connection test, retry screen | Reinitialize client if initialization itself fails |
| Email/password Auth | ✅ Working | Repository, Riverpod notifier, form, validation, name metadata, errors, Web email-confirmation redirect via the current origin, focused tests | Dashboard redirect allowlist and manual email-confirmation acceptance |
| Session routing | ✅ Working | Guarded routes, auth stream listener, profile completion lookup | Intended-route restoration; explicit expired-session UX |
| Google OAuth | ⏸ Deferred | Repository method exists | Provider config, UI, deep links/callbacks |
| Password recovery | ⏸ Deferred | Send-reset repository method exists | Callback/deep link and update-password UI |
| Onboarding | ✅ Working | Five-step provider/UI, validation, username check, time picker, atomic RPC persistence, retry/loading behavior, tests | Production manual journey test; pixel-perfect design and real reminder scheduling are deferred |
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
Password recovery and Google OAuth callbacks remain deferred. Mobile
universal/app links are outside the scope of the Web demo.

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
4. Build the home lesson map and complete the remaining first usable learning
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
5. Remove the two remaining analyzer info notices.
6. Replace stale Firebase/Firestore descriptions in the legacy README.

## 9. Verification snapshot

Last local verification:

```text
flutter test
  -> all tests passed (9 tests)
  -> startup smoke: 1
  -> Auth registration and redirect: 3
  -> Onboarding provider and wizard: 5

dart analyze <changed Auth files>
  -> no issues

flutter analyze
  -> 2 pre-existing info-level notices in gemini_vision_service.dart

flutter build web --debug
  -> succeeded
  -> existing flutter_tts WebAssembly dry-run compatibility notices only

git diff --check
  -> passed
  -> line-ending warnings only (LF will be converted to CRLF)

Production onboarding RPC transaction check
  -> RPC completed inside a test transaction
  -> rollback left 0 persisted test rows
```

Manual verification of the real email-confirmation round trip and the complete
registration-to-home journey is still required. Automated Flutter tests do not
create Production Auth accounts.

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

