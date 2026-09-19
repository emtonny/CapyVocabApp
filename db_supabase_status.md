# Hướng dẫn đồng bộ Supabase — Staging và Production

> Cập nhật: **2026-09-19**
> Interface/runtime reconciliation 2026-09-19: mọi nhánh Git liên quan đã nằm
> trong `interface`; không cần merge. Source `chat-translation-worker` version 1
> bị thiếu khỏi toàn bộ Git refs đã được phục hồi byte-for-byte từ deployed
> Staging bundle, thêm config `verify_jwt=false` và 12 tests. Full Edge 96/96,
> Flutter 544 pass + 1 skip, analyzer sạch. Không deploy hoặc đổi remote.
> Migration reconciliation 2026-09-19: ba file Chat Translation ngày 2026-09-18
> được phục hồi nguyên văn từ remote Staging history; local/remote khớp 28/28,
> dry-run up to date và Android Staging build/install/launch pass. Không repair,
> pull, push ghi thật hoặc thay đổi Production.
> Earlier Device/Auth checkpoint 2026-09-16: Android Staging build/update/startup PASS,
> second user-approved test Auth account created/login verified. Both accounts lack
> C1 profiles/mutual accepted relation; setup approval pending. USB unauthorized,
> live C3 smoke PARTIAL. No migrations/Production/profile/friend changes.
> Later user approval 2026-09-16: exact test pair now accepted two directions,
> verified by both owner JWT/RLS reads. Friends-tab list is verified on Android for
> the signed-in account after fixing the missing native network-status handler shared
> by Chat/Library. Full suite 492 pass/1 existing skip/0 failure; Staging APK build,
> install-r and cold launch pass. At that friendship checkpoint profiles were
> unchanged; no Production.
> Latest approval 2026-09-16: primary `vi→en`, test peer `en→vi` configured as exactly
> 2 C1 rows on Staging. Android Settings/cache + picker pass; real `open_direct_chat`
> yields 1 conversation/2 active members/0 messages. Gemini/Training/Production=0.
> Web checkpoint 2026-09-16: raw Web launch without defines was confirmed to use the
> Production fallback. Guarded `web-device` now launches exact Staging with a visible
> environment banner; real Chrome login UI and Web build pass. Demo sign-in pending.
> Mục đích: giúp các thành viên đồng bộ code và kiểm tra Supabase mà không thao
> tác nhầm Production. Đây là runbook kỹ thuật, không chứa secret.

## 1. Định danh môi trường — không được suy đoán

| Môi trường | Project name | Project ref | Trạng thái |
| --- | --- | --- | --- |
| **Staging** | `emtonny's Project` | `nxteaznowkfennxpqjmt` | Repo đang linked tại đây |
| **Production** | `CapyVocabApp` | `vmxonxqxrlkssdzsucrg` | App config mặc định đang trỏ tại đây |

Các project là hai database/Storage/Edge Function độc lập. `git pull` không
apply migration, không deploy function và không sao chép dữ liệu giữa chúng.

Kiểm tra lại trước mọi thao tác remote:

```powershell
npx supabase projects list --output json
Get-Content supabase/.temp/project-ref
```

Kết quả mong đợi của file link:

```text
nxteaznowkfennxpqjmt
```

Nếu khác, dừng lại và xác nhận môi trường. Không dựa vào tên terminal, tên
branch hoặc URL đã nhớ.

## 2. Trạng thái đã kiểm tra

| Hạng mục | Staging | Production |
| --- | --- | --- |
| Migration remote | 28/28, linked dry-run up to date verified 2026-09-19 | 21, evidence 2026-09-12; không re-audit phiên này |
| Migration local | 28, không pending so với Staging | 28 file local; Production không re-audit/apply trong phiên này |
| Chat Language Profile C1 | APPLIED/BACKEND VERIFIED; approved two-account pair configured, primary Settings/cache verified on Android. General onboarding + second-account UI smoke pending | PENDING APPLY, cần Production approval riêng |
| Operational Chat C2 | APPLIED / REST + REALTIME VERIFIED; 47 local checks + 10 nhóm smoke, cleanup 0 | NOT APPLIED, cần Production gate riêng |
| Chat C3A/C3B + C3C UI | 89 combined chat tests, final full suite 493 pass/1 existing skip/0 failure, analyzer clean. Guarded Web Staging build + real Chrome login UI pass; demo login pending. Accepted pair + two C1 rows verified; Android Settings/picker/detail pass and real RPC produced 1 conversation/2 active members/0 messages. CHAT_RELAY_ENABLED default OFF/exact Staging only; two-client relay/offline restart pending | Không migration/Production/translation/Training rollout |
| Library M3A/M4.5 | Applied | Applied |
| Bucket `photo_notes` | Private | Private |
| Client sync mặc định | OFF | OFF |
| Dữ liệu Library | Demo/test | 0 row và 0 Storage object tại thời điểm audit |

Ngày 2026-09-19, read-only history trên exact Staging phát hiện ba version
remote-only `20260918120000`, `20260918125000`, `20260918130000`. Statements
được đọc từ `supabase_migrations.schema_migrations` và phục hồi thành đúng ba
file local; canonical SHA-256 của từng file khớp remote. Sau phục hồi,
`migration list --linked` khớp 28/28 và `db push --linked --dry-run` trả
`upToDate=true`. Không dùng `migration repair`, `db pull` hoặc `db push` ghi thật.
Android APK exact Staging + Chat build pass, `adb install -r` và launch pass trên
`127.0.0.1:5555`, không phát hiện lỗi runtime trong log lọc sau startup.

Audit Production được chạy lại bằng
`tool/audit_supabase_library_rollout.ps1` lúc 2026-09-12 và trả
`access_mode=secret_read_only`, `m3a_schema_present=true`,
`bucket_is_private=true`, `complete_inventory=true`. Script chỉ đọc và không
in API key, user ID, object path hoặc nội dung bản ghi.

Audit cùng ngày trên Staging cũng pass: 5 Photo Note, 10 object chuẩn hóa,
không có path legacy/missing/mismatch/unreferenced và bucket private.

Production có 10 `public.users`, 5 `user_settings`, 1 `subscription`; các bảng
`lessons`, `vocabularies`, `user_vocab_progress`, `photo_notes`,
`media_assets`, `scan_runs`, `vocab_detections`, `vocab_annotations` và
`library_change_events` đều có 0 row tại thời điểm audit.

Production Edge Function:

- `gemini-vision-scan` version 41, ACTIVE, cập nhật 2026-09-10.
- `gemini-vision-scan-canary` version 19, ACTIVE.
- Có `GEMINI_API_KEY`.
- Source hiện tại chỉ yêu cầu Gemini; `VILAO_API_KEY` và `VILAO_BASE_URL` chưa
  được Edge Function hiện tại sử dụng và không được ghi là secret bắt buộc.

Ngày 2026-09-15, Staging đã apply đúng
`20260914120000_add_chat_language_profiles.sql` sau backup/test/exact dry-run.
History 22/22, post-apply dry-run up to date; two-account RLS/RPC smoke pass và
fixture cleanup còn 0. Audit Library vẫn 5 bài/10 private object chuẩn hóa,
không legacy/missing/mismatch/unreferenced. Production không bị gọi/ghi phiên này.
Migration tạo profile ngôn ngữ C1 và overload onboarding RPC mới. Client chứa C1
phải được rollout theo thứ tự **migration môi trường -> audit -> client build**;
nếu chạy client mới trước migration, màn Settings không thể đọc bảng profile.
Production cần gate phê duyệt riêng và không được suy ra từ việc Staging pass.

Runner dùng lại cho C1 (chỉ đúng linked Staging; không dùng demo user):

```powershell
.\tool\backup_staging_database.ps1 -SelfTest
.\tool\backup_staging_database.ps1
pwsh -NoProfile -File .\tool\run_staging_language_profile_smoke.ps1
```

Backup dùng PostgreSQL 18 native, không cần Docker và không cài thêm dependency.
Artifact DPAPI nằm ngoài repo tại
`%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T105000Z-805486b7`;
bao gồm `public`/`private` custom archive cùng migration history mã hóa riêng.
Auth/Storage/object bytes không thuộc dump này; C1 không thay đổi chúng. Restore
cần cùng Windows profile. Android/Web onboarding/Settings UI smoke C1 vẫn pending.
Lượt Chrome widget test ngày 2026-09-15 treo `loading` và đã dừng, không có test
pass; Flutter hiện không nhận Android kết nối. Backend smoke dùng PowerShell 7
đã có trên máy, không cài thêm runtime.

### C2 — đã apply/verify backend Staging theo approval

Ngày 2026-09-15, C2 đã implement migration
`20260915120000_add_operational_chat_security.sql`; **47 native PostgreSQL
SQL/RLS checks pass**. Staging read-only audit xác nhận 0 legacy messages và
0 friends. Sau user approval riêng, backup mới + exact apply và smoke Staging
đã pass. Legacy API `chat_messages` giữ nguyên; chat mới dùng
`chat_operational_messages`, không backfill. Không tạo/nối Training pipeline.

```powershell
pwsh -NoProfile -File .\tool\test_chat_operational_schema.ps1
pwsh -NoProfile -File .\tool\audit_staging_chat_legacy.ps1
pwsh -NoProfile -File .\tool\run_staging_operational_chat_smoke.ps1
npx supabase db push --project-ref nxteaznowkfennxpqjmt --dry-run
```

Pre-apply dry-run chỉ C2; exact apply đã hoàn tất, history 23/23 và post-apply
dry-run up to date. Backup DPAPI mới trước C2:
`%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T113034Z-c9e9c096`,
archive 146,004 byte, decrypt/SHA-256/pg_restore list verified. Không dùng backup
trước C1 thay cho backup này; Auth/Storage/object bytes không thuộc dump.

Live smoke dùng **3 synthetic accounts/3 native WebSocket sessions**, 10 nhóm
checks pass: raw tới A/B trước shared translation/correction, member-only reads,
service-only translation, idempotency/immutability/held/inactive. Outsider cả
5 bảng REST empty/0 Realtime events trong cửa sổ test. Cleanup 0 và baseline
counts preserved; không dùng demo/Gemini/Training. C1 regression 7 nhóm pass;
Library vẫn 5 bài/10 private normalized objects, không mismatch/legacy/orphan.
Không gọi Production. C3A cache/outbox local foundation đã implement và verify
23 SQLite FFI/fake transport tests ngày 2026-09-15 (full suite 426 pass/1 skip,
analyzer clean). C3B.1 Staging-only private SDK adapter local verified: 24 adapter
tests tại checkpoint C3B.1; C3B.2 hiện 75 combined chat tests (gateway 26), SDK
auth/lifecycle/network + atomic cache refresh/deadline scheduler/socket restart đã
nối opt-in app host. Local inbox/detail không profile/network reads; current
session/token/account fenced. C3C raw inbox/detail + accepted-friend UI local verified
(11 widget tests/analyzer clean), gated CTA từ Bạn bè; chưa live adapter/device chat.
SDK restart chỉ
localhost verified. Requires CHAT_RELAY_ENABLED=true/exact Staging host/session/
foreground; flag default OFF. Staging runner có -ChatRelayEnabled/web-build và
exact-ref guard, parser pass; dry-run upToDate=true, no apply/deploy.
2026-09-15 final `-Target web-build -ChatRelayEnabled` compile PASS/exit0,
source cuối 93.8s; Library + Chat flags ON, key/URL Staging qua temporary defines
được cleanup. Existing Wasm/font warnings remain; no browser/device launch.
History giữ C2 checkpoint; Production C1/C2 vẫn chưa apply.
Không suy ra product chat E2E từ backend smoke hoặc fake transport.
2026-09-15 C3C checklist/build commands và known gaps:
[c3c_operational_chat_ui_smoke.md](docs/data/c3c_operational_chat_ui_smoke.md).
At the 2026-09-15 checkpoint, device inventory was empty and no relation was added.
That historical constraint did not authorize silent fixtures. C0 policy vẫn chưa chốt.
2026-09-15 C3C evidence: full suite 489 pass/1 existing skip/0 failure, exit0; combined
chat 86. Analyzer clean; Web Staging source cuối PASS/exit0/92.8s, existing Wasm/font
warnings. Dry-run upToDate=true, no apply/deploy. Không kế thừa device smoke Library
trước đây thành smoke chat; không rollout Production C1/C2.
Production cần gate riêng.

2026-09-16 approved test setup: the exact pair is now mutually accepted and both
owner JWT/RLS views pass. Android
`MainActivity` now implements the existing `network_status` channel used by Chat and
Library, with `ACCESS_NETWORK_STATE` and validated-network semantics. Exact-Staging
APK build 92.6s, install-r and cold launch pass; one accepted peer is visible on the
signed-in device. Both C1 profiles are still absent, so new direct chat/send and the
two-client live exit remain blocked until language roles are explicitly configured.
No migration/apply/deploy/Production/Training change occurred.

Later 2026-09-16 user confirmation configured exactly two Staging C1 rows:
primary `vi→en`, accepted peer `en→vi`, both `beginner`. Android Settings loaded the
primary profile into cache; picker showed one peer without language/runtime errors.
The real `open_direct_chat` RPC then created/reused exactly one pair conversation with
2 active members and 0 messages. No synthetic chat text, Gemini, Training or Production
write occurred. Remaining live gate is a second-account client raw exchange plus
reconnect/no-duplicate and airplane-mode cold restart.
Contract và remaining C0 decisions:
[c2_operational_chat_contract.md](docs/data/c2_operational_chat_contract.md).

## 3. Ba thao tác hoàn toàn khác nhau

### Đồng bộ code

```powershell
git fetch --prune origin
git status --short --branch
git pull --ff-only origin AI-scan
```

Chỉ thay đổi working tree Git. Không chạm Supabase.

### Đồng bộ schema

Chỉ các file trong `supabase/migrations/` mới tham gia migration. Luôn kiểm tra
list và dry-run trước. Không chạy `db push` chỉ vì vừa pull code.

### Đồng bộ Edge Function

Code trong `supabase/functions/` chỉ lên remote sau lệnh deploy tường minh.
Migration thành công không có nghĩa function đã được deploy.

## 4. Quy trình an toàn cho Staging

Repo phải linked đúng Staging trước khi dùng `--linked`:

```powershell
Get-Content supabase/.temp/project-ref
npx supabase migration list --project-ref nxteaznowkfennxpqjmt
npx supabase db push --project-ref nxteaznowkfennxpqjmt --dry-run
```

Chỉ apply Staging sau khi đã review danh sách migration được đề xuất:

```powershell
npx supabase db push --project-ref nxteaznowkfennxpqjmt --yes
```

Kiểm tra function Staging:

```powershell
npx supabase functions list --project-ref nxteaznowkfennxpqjmt --output json
npx supabase secrets list --project-ref nxteaznowkfennxpqjmt --output json
```

Chỉ deploy function sau khi test local/static contract đạt:

```powershell
npx supabase functions deploy gemini-vision-scan --project-ref nxteaznowkfennxpqjmt
```

## 5. Quy trình Production — bắt buộc có phê duyệt riêng

Các lệnh kiểm tra chỉ đọc:

```powershell
npx supabase migration list --project-ref vmxonxqxrlkssdzsucrg
npx supabase db push --project-ref vmxonxqxrlkssdzsucrg --dry-run
npx supabase functions list --project-ref vmxonxqxrlkssdzsucrg --output json
npx supabase secrets list --project-ref vmxonxqxrlkssdzsucrg --output json
```

Không chạy các lệnh sau nếu chưa có backup, review và phê duyệt Production cho
đúng increment:

```text
supabase db push ... --yes
supabase migration repair ...
supabase functions deploy ...
supabase secrets set ...
```

Không dùng `--linked` cho thao tác ghi Production vì repo đang linked Staging.
Luôn ghi project ref Production tường minh.

## 6. Cấu hình Flutter và nguy cơ trỏ nhầm môi trường

`assets/config/client.config` hiện trỏ Production. Dart define có độ ưu tiên cao
hơn file này; script staging tạo define file tạm và không in key ra log.

Build Staging phải dùng script đã có:

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_staging_device_smoke.ps1 -Target android-build

# Web Staging tương tác, Chat bật rõ ràng, chạy tại localhost:3000
powershell -ExecutionPolicy Bypass -File tool/run_staging_device_smoke.ps1 `
  -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' `
  -Target web-device -WebPort 3000 -ChatRelayEnabled
```

Giữ terminal runner mở trong lúc test; dừng runner thì local Web server dừng và
file define tạm được xóa. Banner `STAGING TEST · WEB` chỉ hiện khi runtime đồng
thời là Web, đúng exact Staging host và Chat flag đang bật.

Không dùng lệnh dưới đây để gọi là “Staging build”:

```text
flutter build apk --dart-define=LIBRARY_SYNC_ENABLED=true
flutter run -d chrome --web-port=3000
```

Lý do: nếu không override `SUPABASE_URL` và `SUPABASE_ANON_KEY`, app sẽ lấy
`client.config` và kết nối Production.

Các cổng độc lập:

1. Build flag `LIBRARY_SYNC_ENABLED=true` cho phép tạo sync runtime.
2. User phải đăng nhập đúng project.
3. User phải bật Cloud Backup.

Thiếu một trong ba thì Library vẫn local-first và không upload.

## 7. Storage và dữ liệu Library

- SQLite/app-private media là nguồn đọc chính của UI.
- Supabase là cloud mirror/backup theo consent.
- Bucket `photo_notes` phải luôn private.
- Object path chuẩn: `{user_id}/{media_asset_id}/{variant}.{extension}`.
- App lưu object path, không giữ public URL làm contract.
- Metadata pull không tự tải JPEG.
- JPEG chỉ tải về app-private sau hành động rõ ràng của user.
- Outbox row không phải bằng chứng upload thành công.

## 8. Trạng thái Web

- Flutter có route/UI cho Auth, Home, Library, Scan và Settings.
- Web scan đã ghi JPEG vào media database SQLite WASM/IndexedDB và ghi JSON/
  aggregate Library vào local SQLite thay vì memory store.
- Library/Trash/detail đọc ảnh qua Web media adapter; xóa vĩnh viễn dọn đúng
  blob tương ứng.
- Cloud sync/restore Web chưa được bật; không được suy ra từ native runtime.
- Settings Web khóa công tắc Cloud Backup và giải thích dữ liệu đang lưu cục
  bộ, tránh tạo outbox khi chưa có Web sync gateway.
- Build Web mặc định dùng config Production nếu không có dart define riêng.
- Chưa có hosting/deployment pipeline Production trong repo.
- Artifact Flutter hiện sinh service worker tự unregister; local IndexedDB bền
  không đồng nghĩa app shell có thể cold-start hoàn toàn khi mất mạng. PWA cache
  và hosting là increment riêng trước khi công bố Web offline hoàn chỉnh.

Mọi thay đổi Web persistence phải được kiểm tra bằng reload/cold restart trên
Chrome. Build Web và test contract local đã đạt ngày 2026-09-12; guarded Chrome
Staging runner + login UI đã chạy ngày 2026-09-16. Scan → Library reload/cold-
restart persistence vẫn chưa browser-smoke, nên đây còn là checkpoint bắt buộc
trước khi bật cloud sync Web.

## 9. Checklist bàn giao giữa hai người

- [ ] `git status --short --branch` không có thay đổi ngoài phạm vi.
- [ ] Ghi rõ commit hash vừa bàn giao.
- [ ] Ghi rõ target là Staging hay Production cùng project ref.
- [ ] Liệt kê migration mới; nếu không có phải ghi “không có migration mới”.
- [ ] Liệt kê Edge Function thay đổi; Git commit không được gọi là deploy.
- [ ] Không gửi hoặc commit service-role/secret key.
- [ ] Chạy analyzer và test liên quan.
- [ ] Với database remote: list → dry-run → backup → approval → apply → audit.
- [ ] Cập nhật `db_status.md` trong cùng increment nếu có thay đổi database,
      local media, sync, consent, retention hoặc ML lineage.

## 10. Khi có lỗi

1. Dừng thao tác ghi tiếp theo.
2. Ghi project name/ref và lệnh vừa chạy.
3. Giữ nguyên lỗi đầu tiên có thể hành động.
4. Xác định lỗi thuộc Git, schema, function, secret hay client config.
5. Không reset/repair Production để thử vận may.

Audit REST `tool/audit_supabase_library_rollout.ps1` ưu tiên API key loại
`secret`, fallback `service_role` cho project cũ, lấy key đầy đủ bằng
`supabase projects api-keys --reveal` chỉ trong bộ nhớ và đặt User-Agent của
tool máy chủ. Người chạy phải đăng nhập Supabase CLI; không copy key vào lệnh,
file hoặc chat. Audit Production ngày 2026-09-12 đã pass với key mới.

Chi tiết lịch sử và evidence: [db_status.md](./db_status.md).
