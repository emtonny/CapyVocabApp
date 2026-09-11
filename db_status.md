# Database & Storage Status

> Source of truth cho Database, local media, offline Library, Supabase sync và
> dữ liệu chuẩn bị cho on-device AI.  
> Cập nhật gần nhất: **2026-09-11 — đồng bộ UI GitHub `cbd7318`, giữ nguyên contract offline/Production**  
> Trạng thái tổng thể: **Nhánh `AI-scan` đã fast-forward đủ 6 commit giao diện/auth mới tới `cbd7318`. UI neo-brutalist, graph-paper, soft page transition và password recovery đã được hòa trộn với router onboarding synchronous, Library detail/trash, entitlement và Cloud Backup local hiện có; analyzer sạch và nhóm test liên quan đạt 73/73. Các file Edge Function đang chạy theo quota/circuit-breaker/ledger local được giữ nguyên trong working tree; thay đổi Vilao gateway từ commit mới chưa được đưa vào runtime/deploy và cần một increment backend riêng. Production M3A/M4.5 vẫn giữ nguyên, bucket private, default `LIBRARY_SYNC_ENABLED=false`; không có migration, cloud write hay deploy trong lần đồng bộ UI này.**

## Quy tắc bắt buộc cho các phiên sau

Mọi phiên làm việc có thay đổi liên quan database, schema, migration, local
file, Library repository, sync, consent, retention hoặc ML dataset phải:

1. Đọc file này trước khi lập kế hoạch hoặc sửa code.
2. Cập nhật file này trong cùng increment với thay đổi mã nguồn.
3. Thêm một entry có ngày vào phần **Change log**.
4. Ghi rõ `IMPLEMENTED`, `PARTIAL`, `PENDING` hoặc `BLOCKED`; không dùng từ
   “đã xong” nếu chưa có test hoặc runtime evidence.
5. Ghi chính xác command kiểm chứng và kết quả; không kế thừa kết quả test cũ
   cho code mới.
6. Nếu thay đổi quyết định D1–D10, phải ghi người/yêu cầu phê duyệt và ngày.
7. Không tuyên bố dữ liệu đã lên Supabase chỉ vì outbox đã được tạo.

## Trạng thái hiện tại

| Thành phần | Trạng thái | Sự thật hiện tại |
| --- | --- | --- |
| SQLite schema v3 | IMPLEMENTED | 22 bảng; thêm owner-scoped `library_pull_cursors`; native dùng `sqflite`, test/desktop dùng FFI, Web adapter dùng SQLite WASM/IndexedDB |
| Ảnh scan native | IMPLEMENTED/ANDROID VERIFIED | JPEG nén lưu app-private `capy_scans/`. Sau clean-install/rehydrate, explicit cloud restore đã tạo đúng 1 JPEG 116,892 byte; 4 cloud note còn lại vẫn metadata-only theo yêu cầu không tự tải |
| Scan JSON local | IMPLEMENTED/ANDROID VERIFIED | Lượt ảnh thật mới nhất có legacy `scan_results` và normalized `scan_runs` status `succeeded`, model `gemini-3.5-flash-lite`, tier `free` |
| Normalized Library aggregate | IMPLEMENTED/ANDROID REHYDRATE VERIFIED | Clean-install CPH2375 đã nhận 5 backed-up Photo Note cùng raw JSON/vocabulary vào SQLite v3 sau login + Cloud Backup ON; 2/7 bài local trước sự cố không có cloud copy để phục hồi |
| Atomic DB commit | IMPLEMENTED | Legacy row, queue link, aggregate và outbox dùng cùng một SQLite transaction |
| Offline repository read | IMPLEMENTED/LOCAL VERIFIED | Repository và owner-scoped stream đọc lại PhotoNote aggregate sau khi đóng/mở SQLite; integration test đồng thời đọc đúng app-private media mà không gọi mạng |
| Offline app startup | IMPLEMENTED/ANDROID VERIFIED | Cache onboarding owner-scoped hydrate trước `runApp`; router redirect synchronous. APK mới cold-start data/Wi-Fi OFF vào Home 6,963 ms, mở Library/detail qua mốc retry >30 giây với 0 profile/RPC request, `Failed host lookup` hoặc stack trace; Android network gate + exponential backoff không chặn UI |
| Storage/Library UI | IMPLEMENTED/ANDROID VERIFIED | Summary đếm media owner-scoped còn được active/Trash giữ lại, stat file app-private thật và cộng `File.length()` thay vì remote `byte_size_display`. CPH2375 render đúng 5 bài, 1/5 ảnh trên máy/114.2 KB, 4 trên cloud; card/detail phân biệt local, cloud-only và missing. Cloud-only chỉ tải sau explicit CTA |
| Photo Note Trash + dung lượng | IMPLEMENTED/STAGING + ANDROID E2E VERIFIED | Library có dung lượng media theo account, Trash 30 ngày, Restore và explicit permanent delete. Android fixture pass full Restore/retrash/permanent-delete, đúng một local file bị xóa và restart bền; Staging row cùng fixture không còn |
| Media recovery | IMPLEMENTED/ANDROID VERIFIED | M4.2 compensation/audit và M4.3A recovery đã pass CPH2375. `capy_quarantine/` chỉ nhận orphan sau explicit confirm; retention 30 ngày, Restore/Xóa ngay, re-audit chống stale action và path confinement. Fixture UI pass full round-trip/delete; orphan lịch sử giữ nguyên |
| Gemini Edge scan | IMPLEMENTED/STAGING + ANDROID LIVE VERIFIED | `gemini-vision-scan` v1 ACTIVE trên linked Staging, Gemini secret tồn tại, unauthenticated request trả `401`; authenticated fixture smoke và ảnh thật từ Android đều gọi `gemini-3.5-flash-lite` thành công. Lượt device mới nhất render 5 detection |
| Supabase cloud contract | IMPLEMENTED/STAGING + PRODUCTION VERIFIED | M3A/M4.5, private bucket, normalized schema/change feed và owner RLS pass cả Staging lẫn Production; Production history 21/21/up-to-date |
| Supabase upload | IMPLEMENTED/STAGING + ANDROID + PRODUCTION FIXTURE E2E VERIFIED | Android Staging scan và Production isolated fixture đều upload private + normalized evidence/raw JSON thành công. Build thường vẫn không upload vì rollout flag mặc định tắt |
| Cloud restore/download | IMPLEMENTED/ANDROID E2E VERIFIED | Android synced Photo Note bị tạm thiếu local JPEG chỉ hiện CTA ở detail; 0 download trước tap. Explicit tap tải private media, tạo lại đúng 116,892 byte/SHA-256, bỏ CTA và offline cold restart vẫn mở ảnh + 4 từ. Cloud-only metadata nay có thể xuất hiện trên máy mới nhưng JPEG vẫn chỉ tải sau explicit tap |
| Cloud metadata pull | IMPLEMENTED/STAGING + ANDROID + PRODUCTION FIXTURE VERIFIED | Auth + consent + build-flag gated; owner cursor/atomic merge và no-auto-media-download pass. Production fixture pull sang SQLite thứ hai + delete feed pass |
| Remote staging workflow | IMPLEMENTED/STAGING VERIFIED | Project inactive đã được restore làm Staging trên organization Free; repo link Staging; 21/21 migration đồng bộ và remote database up to date. Staging có đúng demo user do chủ dự án chỉ định, đã confirm email, có `public.users` profile và password login pass ngày 2026-09-05 |
| Production rollout safety | GATE 0–3 VERIFIED | DPAPI backup, fingerprint, history repair, exact two-migration apply, full worker E2E, two-user RLS/Storage và cleanup pass. Repo không relink; client rollout bật sync chưa thực hiện |
| Sync outbox | IMPLEMENTED/STAGING + ANDROID E2E VERIFIED | Upload consent-gated đã pass. Explicit pre-consent backfill tạo graph atomic/idempotent chỉ cho active owner note đủ media; live Staging upload/pull/purge/cleanup pass. Privacy purge vẫn chạy đúng owner kể cả Cloud Backup OFF và giữ tombstone khi remote lỗi |
| Cloud-backup consent UI | IMPLEMENTED/ANDROID VERIFIED | Settings switch ghi audit `cloud_backup`; hai consent AI độc lập. Khi ON có action `Sao lưu bài đã có`, dialog riêng trước enqueue, bỏ qua missing/Trash và báo số queued. Android zero-candidate UX pass; không tự backfill khi chỉ bật switch |
| Web scan durability | PENDING | Web scan vẫn dùng memory store dù SQLite WASM repository đã tồn tại |
| Training dataset | PARTIAL/FAIL-CLOSED VERIFIED | Có schema lineage/consent; AI prediction không tự thành nhãn. Missing media quarantine example liên quan. Permanent purge xóa source example + manifest/run links và invalidates model đã dùng source; historical non-content audit có thể còn. Builder/D6 vẫn chưa triển khai |
| On-device trainer | PENDING | Chưa có dataset builder, trainer, scheduler hoặc model activation runtime |

## Luồng runtime native hiện tại

```text
camera/gallery
  -> nén JPEG
  -> lưu file app-private capy_scans/
  -> gọi Gemini Edge Function
  -> giữ raw response trước client ranking
  -> một SQLite transaction:
       scan_results (compatibility)
       media_assets
       scan_runs
       vocab_detections
       photo_notes
       legacy_scan_import_queue = imported
       sync_operations (chỉ khi cloud_backup_enabled = true)
  -> notify Library stream sau khi commit
  -> nếu Vision/transaction lỗi: xóa bù đúng JPEG vừa tạo
  -> nếu build bật sync + user đã cloud consent:
       coordinator drain outbox theo dependency
       retry theo next_attempt_at hoặc app resume
```

Nếu transaction DB lỗi, toàn bộ row mới rollback và JPEG vừa tạo được cleanup
best-effort; lỗi cleanup không che lỗi scan gốc. Khi có authenticated session,
startup chạy audit nền account-global. Orphan chỉ chuyển sang quarantine sau
explicit user action; file đã cách ly được purge khi đủ 30 ngày. Missing media
không xóa Library aggregate nhưng fail-close training lineage liên quan.

## SQLite v3 — 22 bảng

### Account và consent

- `local_accounts`
- `consent_events`

### Scan và Library

- `scan_results`
- `media_assets`
- `scan_runs`
- `photo_notes`
- `vocab_detections`
- `vocab_annotations`
- `albums`
- `album_photo_notes`
- `legacy_scan_import_queue`

### Learning và model

- `learning_events`
- `srs_progress`
- `model_versions`
- `training_examples`
- `dataset_manifests`
- `dataset_manifest_examples`
- `training_runs`
- `training_run_examples`

### Sync và deletion

- `sync_operations`
- `sync_tombstones`
- `library_pull_cursors`

## Consent và dữ liệu AI

- Account mới mặc định fail-closed: `cloud_backup_enabled = false`,
  `local_personalization_enabled = false` và
  `federated_contribution_enabled = false`.
- Account đã tồn tại giữ nguyên consent; luồng scan không được ghi đè flag.
- Raw Gemini response là scan evidence, không phải nhãn đúng.
- AI predictions không được tự tạo `vocab_annotations` hoặc
  `training_examples`.
- Training milestone sau chỉ được chọn nhãn theo policy D6 đã được duyệt.

## Supabase — trạng thái upload và pull hiện tại

M3A cloud schema/private Storage, M3B worker và M3C runtime coordinator đã có.
Runtime chỉ được tạo trên native khi build với
`--dart-define=LIBRARY_SYNC_ENABLED=true`; mặc định cờ là `false` vì Production
chưa có M3A. Worker/gateway đã pass E2E trên Staging. Android app đã pass
install/startup, background/resume lifecycle và authenticated consent-to-upload
E2E trên chính device:

- SQLite là nguồn phục vụ offline hiện tại.
- Outbox chỉ là yêu cầu chờ đồng bộ, không phải bằng chứng upload thành công.
- Absolute local path không bao giờ được đưa lên cloud.
- Không được tự upload ảnh/raw JSON khi `cloud_backup_enabled = false`.
- Auth, outbox change, consent change, retry timer và app resume có thể đánh
  thức worker; lỗi sync không chặn UI hoặc local read.
- Sau upload drain, worker pull metadata theo owner cursor. Batch còn tiếp tục
  tự nối trong cùng single-flight; Library list/detail vẫn chỉ đọc SQLite và
  không tự tải JPEG từ Storage.

Audit M3 ngày 2026-09-03 xác nhận contract cũ chưa được phép tái sử dụng:

- Bucket `photo_notes` trong schema snapshot đang `public = true`.
- Storage SELECT policy hiện cho phép đọc mọi object trong bucket.
- INSERT policy chỉ kiểm tra role `authenticated`, chưa bắt object path bắt đầu
  bằng `auth.uid()`.
- `StorageService` cũ trả public URL và tạo key bằng timestamp; không dùng
  MediaAsset ID/idempotency key.

M3A đã thay contract trong source bằng private bucket + owner-prefixed
deterministic object key. Production vẫn giữ trạng thái cũ cho đến khi migration
được review và apply; không được trỏ M3B runtime vào Production trước bước đó.

Đổi bucket sang private sẽ làm public URL legacy ngừng hoạt động. Production
rollout bắt buộc kiểm kê/backfill `image_path`, deploy signed-URL reader và có
rollback trước khi apply migration.

## Decision log

| ID | Quyết định | Trạng thái |
| --- | --- | --- |
| D1 | Giữ họ `sqflite`: native + FFI + Web WASM/IndexedDB | APPROVED — 2026-09-02 |
| D2 | Giữ display/model-input khi note active; original chỉ opt-in/quota | APPROVED — 2026-09-03 |
| D3 | Cloud backup OFF mặc định; private; hỏi trước khi purge | APPROVED — 2026-09-03 |
| D4 | Mức offline parity trên Web | PENDING |
| D5 | Model cá nhân đầu tiên | PENDING |
| D6 | Loại nhãn đủ điều kiện training | PENDING |
| D7 | UX/save/navigation sau scan | PENDING |
| D8 | Federated learning scope | PENDING |
| D9 | Trash/quarantine 30 ngày; Restore hoặc purge ngay; purge local/cloud/ML và giữ receipt tối thiểu | APPROVED — 2026-09-08; purge detail approved 2026-09-09 |
| D10 | Local data khi logout/account delete | PENDING |

## Milestone status

| Milestone | Trạng thái | Kết quả |
| --- | --- | --- |
| M0 | DOCUMENTED | Kiến trúc offline-first, data ownership, privacy và decision log |
| M1 | IMPLEMENTED | Pure-Dart entities và 6 repository contracts |
| M2A | IMPLEMENTED/PARTIAL WEB VERIFY | SQLite v3 + migration v2→v3; native/FFI pass, Web build pass, Chrome runtime runner bị treo |
| M2B | IMPLEMENTED | SQLite codecs và repository implementations |
| M2C | IMPLEMENTED | Native scan ghi trực tiếp legacy + normalized aggregate local |
| M3A | IMPLEMENTED/STAGING + PRODUCTION VERIFIED | Normalized schema/RLS/private bucket/change feed history 21/21; full fixture upload/pull/purge và two-user isolation pass Production |
| M3B | IMPLEMENTED/STAGING VERIFIED | Worker dependency graph/two-phase media pass local tests và live Staging với authenticated owner, file thật, raw JSON và cleanup |
| M3C | IMPLEMENTED/ANDROID E2E VERIFIED | Auth/lifecycle coordinator, SQLite retry timer và offline startup pass local regression; Android Staging sync-enabled launch/resume và authenticated outbox drain 8/8 operation pass |
| M3D | IMPLEMENTED/ANDROID E2E VERIFIED | Consent UI account-scoped + SQLite audit pass; device UI opt-in OFF→ON và scan/upload private sang Staging đã được đối chiếu local/remote |
| M4 đề xuất | IMPLEMENTED/STAGING + ANDROID VERIFIED | M4.1–M4.4 giữ nguyên evidence. M4.5 pass local contract, live Staging bằng hai SQLite độc lập và physical clean-install rehydrate → explicit 1-media restore → quiet offline cold restart; máy Android thứ hai thật vẫn là rollout coverage bổ sung |
| M5 đề xuất | PENDING | Dataset builder và on-device training theo consent |

## Verification gần nhất

Ngày 2026-09-11, Production Gate 3 execution sau explicit approval:

```text
pre-apply target guard + audit + db push --dry-run
  -> explicit Production ref, repo vẫn linked Staging
  -> backup manifest present; 0 rows/objects/legacy
  -> exactly M3A + M4.5 proposed

db push --project-ref <Production> --yes
  -> applied 20260903120000_add_library_cloud_storage_contract.sql
  -> applied 20260910120000_add_library_cloud_pull_feed.sql

post-apply migration list + dry-run + audit v2
  -> local/Production 21/21; upToDate=true
  -> media_assets present; bucket private; inventory complete

real SQLite store/worker/gateway E2E on Production
  -> private upload + normalized raw JSON/evidence pass
  -> pull to second SQLite with no automatic media download pass
  -> permanent purge/delete feed/fixture cleanup pass

two-user Production RLS/Storage smoke
  -> owner row/read/upload/download + signed URL 200
  -> cross-user media/note reads []
  -> cross-user row insert 403; Storage read/upload 400

final cleanup audit
  -> 0 photo_notes, 0 media objects, 0 legacy/unreferenced
  -> Auth fixture marker count 0; Production dry-run upToDate=true
```

Lượt cross-user đầu báo false failure vì PowerShell bọc decoded `[]` thành một
`$null`; raw JSON rerun pass. Audit harness được sửa cùng root cause bằng
`{Exists, Rows}`, Production empty-table và populated Staging regression đều
pass. Không có bằng chứng RLS leak. Default client sync flag vẫn OFF.

Ngày 2026-09-11, Production Gate 0–2 execution sau explicit approval:

```text
supabase db dump --project-ref <Production>
  -> Docker path fail-closed vì Docker engine không chạy; không tạo backup dở

PostgreSQL 18 pg_dump/pg_restore + Supabase temporary login
  -> public schema SQL + full public custom dump + pre-repair history
  -> Windows DPAPI CurrentUser encrypted outside repo
  -> 3/3 SHA-256 decrypt round-trip pass; pg_restore --list pass
  -> plaintext temp removed

psql catalog fingerprint
  -> all 15 baseline tables present
  -> subscription unique + AI ledger/function/final grants present
  -> 3 circuit-breaker functions present; M3A/M4.5 tables absent

pre-repair Production audit
  -> 0 photo_notes, 0 objects, inventory complete; no backfill required

migration repair --status reverted <4 remote aliases>
migration repair --status applied <baseline + 4 local canonical>
  -> both commands pass against explicit Production ref

post-repair migration list + db push --dry-run
  -> history matches local through 20260829152311
  -> only 20260903120000 and 20260910120000 local-only
  -> dry-run proposes exactly M3A + M4.5; no SQL applied

post-repair audit + linked Staging dry-run
  -> Production remains 0 rows/objects, bucket public, M3A absent
  -> repo still links Staging; Staging upToDate=true
```

Backup manifest:
`%LOCALAPPDATA%\CapyVocabApp\production_backups\20260911T105509Z\manifest.json`.
Khôi phục DPAPI yêu cầu cùng Windows user/profile context. Gate 3 Production
apply chưa được duyệt hoặc thực hiện.

Ngày 2026-09-11, Production Library rollout audit read-only:

```text
tool/audit_supabase_library_rollout.ps1 (Staging)
  -> 5 photo_notes normalized, 10 normalized Storage objects
  -> 0 legacy/missing/mismatch/unreferenced; bucket private; inventory complete

tool/audit_supabase_library_rollout.ps1 (Production)
  -> 0 photo_notes, 0 Storage objects; inventory complete
  -> bucket public, media_assets absent; không có legacy data cần backfill

npx supabase migration list --linked + db push --linked --dry-run
  -> Staging local/remote 21/21; upToDate=true

npx supabase migration list --project-ref vmxonxqxrlkssdzsucrg
  -> 14 shared, baseline local-only, 4 remote-only aliases,
     4 local canonical aliases + M3A + M4.5 local-only

npx supabase migration fetch --project-ref <Production> (OS temp only)
  -> semantic diff xác nhận 4 alias pairs cùng final SQL behavior
  -> temp directory đã xóa; remote history không đổi
```

PowerShell parser pass; targeted cloud migration/rollout contract test pass
8/8; `flutter analyze --no-pub` sạch. Không có Production
repair/apply/relink/row/object/policy mutation.

Ngày 2026-09-11, explicit pre-consent Library backfill verification:

```text
flutter test <consent provider + Settings UI + SQLite store>
  -> 35/35 pass

flutter analyze
  -> No issues found

flutter test test/features/settings test/features/library
  -> 123 pass + 1 opt-in live Staging skip, 0 fail

flutter test
  -> 351 pass + 1 opt-in live Staging skip, 0 fail

tool/run_staging_library_sync_e2e.ps1
  -> migration dry-run upToDate=true
  -> pre-consent save tạo 0 operation
  -> explicit backfill queue 1 aggregate/5 dependency operations
  -> worker thật upload private media + normalized JSON/evidence/note
  -> SQLite B pull pass; permanent purge + Auth/rows/Storage cleanup pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> migration dry-run upToDate=true
  -> sync-enabled APK build pass; final incremental Gradle 20.1s

adb install -r build/app/outputs/flutter-apk/app-debug.apk
  -> Success
  -> SQLite SHA-256 trước/sau final install: 4ed3cf60...d415f
  -> cả 3 JPEG giữ nguyên SHA-256: ea1145e8..., 27999b50..., a6664293...

Android CPH2375 Settings
  -> Cloud Backup checked=true
  -> action: Sao lưu bài đã có
  -> dialog nêu active/đủ media/skip missing + Trash/không train AI
  -> confirm: Không có bài cũ nào cần sao lưu.
```

Hai JPEG khác có mtime 16:53, trước `lastUpdateTime=17:14:21`; chúng không do
APK/action mới tạo. PID mới không có log download/restore hoặc runtime/network/
SQLite exception. Increment không đổi schema/migration và không ghi Production.

Ngày 2026-09-11, Library actual local-media usage UX verification:

```text
flutter analyze
  -> No issues found

flutter test --reporter compact test/features/library
  -> 105 pass + 1 opt-in live Staging skip, 0 fail

flutter test --reporter compact
  -> 346 pass + 1 opt-in live Staging skip, 0 fail

tool/run_staging_device_smoke.ps1 -Target android-build
  -> Staging migration dry-run upToDate=true
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

adb install -r build/app/outputs/flutter-apk/app-debug.apk
  -> Success
  -> SQLite SHA-256 trước/sau: 3c0f377f...64a4a
  -> JPEG SHA-256 trước/sau: a6664293...fe27da

Android CPH2375 UI hierarchy
  -> 5 bài trong thư viện
  -> 1/5 ảnh trên máy • 114.2 KB
  -> 4 trên cloud; 0 trong rác
  -> local card: Ảnh trên máy
  -> cloud-only cards: Ảnh trên cloud
  -> cloud detail: Tải ảnh từ cloud + thông báo chỉ tải khi người dùng chọn
  -> app_flutter/capy_scans vẫn đúng 1 JPEG, 116,892 byte
```

Regression test mới bao phủ local/cloud-only/missing, byte count lấy từ file
thật, detail notice và download chỉ sau explicit tap. Thay đổi không thêm
dependency, không đổi SQLite schema/migration, consent, cloud rows, ML lineage
hoặc Production.

Ngày 2026-09-11, physical Android smoke dừng do install xóa sandbox:

```text
flutter devices
  -> CPH2375 / 665fdb60 / Android 13 được nhận

flutter install -d 665fdb60 --use-application-binary=app-debug.apk
  -> output: "Uninstalling old version..." rồi install thành công

adb shell run-as com.capyvocab.app ls -la
  -> chỉ có cache và code_cache
adb shell run-as com.capyvocab.app ls -la databases
  -> No such file or directory
adb shell run-as com.capyvocab.app ls -la files
  -> No such file or directory

adb shell am start -W -n com.capyvocab.app/.MainActivity
  -> COLD launch Status=ok, TotalTime=7,909 ms, PID=7158
  -> Supabase init completed; 0 Flutter/AndroidRuntime error trong log lọc
  -> chờ chủ dự án tự nhập credential Staging
```

Sau khi được duyệt tiếp tục, chủ dự án đăng nhập thành công. ADB xác nhận
`capy_vocab.db` mới 282,624 byte; log có `Library media audit: 0 orphan, 0
missing`; UI Settings đọc `Sao lưu đám mây / Chỉ lưu trên thiết bị` với
`checked=false`. Vì consent local fail-closed, cloud pull chưa được kích hoạt.
Không clear thêm, không tạo scan và không được dùng live two-SQLite E2E để tuyên
bố dữ liệu app-private cũ đã phục hồi.

Chủ dự án sau đó bật Cloud Backup (`checked=true`). Sau 3 giây, Library hiển thị
5 cloud Photo Note, DB tăng lên 290,816 byte nhưng
`app_flutter/capy_scans` vẫn không tồn tại. Detail bài đầu hiển thị manual CTA
`Tải ảnh từ cloud`, 4 từ cùng nghĩa và log không có sync/SQLite/runtime error.
Summary đồng thời ghi sai `5 bài đã lưu trên thiết bị` và `707.0 KB ảnh local`;
đây là UX bug vì toàn bộ 5 JPEG vẫn cloud-only.

Người dùng sau đó explicit nhấn `Tải ảnh từ cloud` ở bài đầu. ADB xác nhận file
`cloud_cf9c36b2-d5d5-4c87-9872-5d2fc889a7c3.jpg` 116,892 byte, SHA-256
`a6664293feafded7a7ecc74d7d90713bd8c3d60ae0e4b7d02b9c680481fe27da`;
CTA biến mất và ảnh render. Cold restart offline đầu tiên mở được Home/Library/
detail nhưng log lộ hai RPC pull thất bại cách 30 giây, xác nhận coordinator chưa
gate network. Sau khi thêm Android validated-network gate và exponential
backoff, verification lại như sau:

```text
dart format <3 changed Dart files>
  -> 3 files formatted, clean

flutter test test/features/library/application/library_sync_coordinator_test.dart
  -> 9/9 pass; offline gate không drain/pull/report error, retry 1x→2x

flutter test test/features/library
  -> 104 pass + 1 opt-in live Staging skip, 0 fail

flutter test
  -> 345 pass + 1 opt-in live Staging skip, 0 fail

flutter analyze
  -> No issues found

tool/run_staging_device_smoke.ps1 -Target android-build
  -> Staging migration dry-run upToDate=true
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

adb install -r build/app/outputs/flutter-apk/app-debug.apk
  -> Success; SQLite/JPEG SHA-256 trước và sau cài giống hệt

Android CPH2375, Wi-Fi + mobile data OFF
  -> COLD launch Status=ok, TotalTime=6,963 ms, PID=18309
  -> Home → Library 5 bài → detail ảnh local + 4 từ
  -> giữ offline qua mốc retry >30 giây
  -> log: 0 Failed host lookup, 0 pull_library_delta/RPC, 0 stack trace/runtime error
  -> Wi-Fi + mobile data đã bật lại; Wi-Fi kết nối Tang 5
```

Thay đổi chỉ nằm ở coordinator/network gate Android và test/tài liệu; không đổi
SQLite schema, migration, consent, cloud data hoặc ML lineage. Production không
linked/apply/reset/ghi.

Ngày 2026-09-11, M4.5 cloud metadata pull local + Staging verification:

```text
dart format lib/features/library test/features/library
  -> 86 files, 0 thay đổi sau format cuối

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 344 pass + 1 opt-in Staging test skipped, 0 fail

tool/run_staging_library_sync_e2e.ps1
  -> migration preflight up to date
  -> live owner A upload aggregate + private JPEG
  -> independent SQLite B pull metadata/raw JSON/vocabulary, outbox=0, JPEG absent
  -> A remote purge; B nhận 1 delete receipt và local source purge
  -> Auth/row/Storage/library_change_events fixture cleanup pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> build/app/outputs/flutter-apk/app-debug.apk
  -> LIBRARY_SYNC_ENABLED=true, PASS
```

Migration `20260910120000_add_library_cloud_pull_feed.sql` đã apply đúng linked
Staging `nxteaznowkfennxpqjmt`; migration history local/remote khớp 21/21 và
post-apply dry-run `upToDate=true`. Production không linked/apply/reset/ghi.

Ngày 2026-09-10, M4.4 Android manual cloud media restore E2E:

```text
CPH2375 Android 13, synced Photo Note `bracelet, notebook, smartphone`
  -> Settings xác nhận Cloud Backup ON; Wi-Fi + mobile data online
  -> rời Library để dispose media provider, tạm đổi tên đúng JPEG app-private
  -> detail chỉ khi đó hiện `Ảnh đang có trên Cloud Backup` và CTA thủ công
  -> trước tap: original absent, backup present; không auto-download
  -> explicit tap tạo lại JPEG 116,892 byte; CTA biến mất, ảnh render lại
  -> SHA-256 downloaded file == SHA-256 pre-smoke backup; backup cleanup pass

Wi-Fi/mobile data OFF + force-stop/cold restart
  -> COLD TotalTime=5,315 ms; Library giữ 7 bài
  -> đúng restored detail có ảnh local + 4 từ, không còn CTA cloud
  -> 0 Failed host lookup/Socket/PostgREST/onboarding_completed/SQLite/FATAL
  -> startup audit chạy 1 lần sau khi file đã restore; không có missing window
  -> mobile_data=1 và Wi-Fi enabled được khôi phục; UI temp cleanup pass
```

Không restart/resume trong lúc file tạm thiếu, tránh để integrity audit thay đổi
training lineage của fixture. Nếu probe/download sai, workflow có rollback file
backup; thực tế hash match nên chỉ backup tạm bị xóa. Không thêm code/dependency/
schema, không ghi Production và không tự tải media ở startup/list/detail.

Ngày 2026-09-10, M4.3C Photo Note physical purge local verification:

```text
flutter test --no-pub <sync coordinator + worker + SQLite + media purger + UI>
  -> 37/37 pass
  -> gồm exact 30-day boundary, owner isolation, idempotency, shared-media
     retention, purge sau khi local rows đã mất và purge khi backup OFF

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 329 pass, 1 opt-in Staging test skipped, 0 failure

tool/run_staging_library_sync_e2e.ps1
  -> đúng linked Staging, migration dry-run upToDate=true
  -> fixture upload rồi local purge; Cloud Backup OFF vẫn remote purge pass
  -> 0 remote row/object còn lại; purge payload cleanup và receipt retained
  -> temporary Auth user cùng mọi fixture cleanup pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> đúng linked Staging, migration dry-run upToDate=true; không push
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

flutter devices --device-timeout 5
  -> lượt đầu chưa có Android; sau khi user cắm lại nhận CPH2375/665fdb60

adb install -r + data-off cold restart + UI hierarchy/log audit
  -> cài đè giữ data; online cold start 7,002 ms, offline cold start 4,858 ms
  -> offline vào Home, Library 8 bài/1.1 MB, detail có ảnh local + 3 từ
  -> Trash empty state đúng copy Restore trong 30 ngày
  -> background/resume giữ PID 330, HOT TotalTime=139 ms
  -> 0 Failed host lookup/Socket/PostgREST/onboarding_completed/SQLite/FATAL/
     deletion-maintenance error trong log PID
  -> capy_scans giữ 9 JPEG, quarantine rỗng, DB giữ 315,392 byte
  -> mobile_data được khôi phục 1; UI hierarchy tạm được xóa
```

M4.3C không thêm dependency hoặc database migration. Local purge không chờ
mạng; cloud failure giữ tombstone/outbox để retry trên startup/resume sau với
đúng authenticated owner. Remote-delete E2E đã pass trên Staging bằng fixture
tạm và cleanup. Android user fixture sau đó pass Restore → retrash → permanent
delete: local file 9→8, active note 8→7, Trash 1→0; restart giữ kết quả và remote
Photo Note title query trên đúng Staging trả raw empty array. Storage object của
device fixture chưa được định danh để query riêng; gateway Storage purge đã được
chứng minh bởi live Staging E2E biệt lập. Debug cold start vẫn có skipped-frame
log; cần profile/release benchmark trước khi kết luận hiệu năng. Production
không bị thao tác.

Ngày 2026-09-09, M4.4 explicit cloud media restore local verification:

```text
flutter test --no-pub <cloud restore service + app-private writer + UI>
  -> 14/14 pass
  -> 0 download trước user tap; owner/hash/size/path fail-closed;
     atomic write, no overwrite và UI explicit CTA pass

flutter test --no-pub
  -> 323 pass, 1 opt-in Staging test skipped, 0 failure

flutter analyze --no-pub
  -> No issues found

flutter build web --no-pub
  -> pass; giữ warning flutter_tts WASM/Cupertino font có sẵn

tool/run_staging_device_smoke.ps1 -Target android-build
  -> linked Staging ACTIVE_HEALTHY, migration dry-run upToDate=true
  -> không push; APK debug sync-enabled build pass
```

M4.4 không thêm dependency hoặc schema. Standard build giữ restore disabled qua
`LIBRARY_SYNC_ENABLED=false`; Web factory trả null. Chưa gọi/download Staging
trong verification này và Production không bị thao tác.

Ngày 2026-09-09, M4.3B Photo Note Trash + storage summary local verification:

```text
flutter test --no-pub <SQLite Library store + Storage/Trash widgets>
  -> 19/19 pass
  -> gồm owner-scoped active/Trash, move, restore, tombstone-hide,
     restore-after-permanent-request bị chặn và narrow-width overflow regression

flutter analyze --no-pub
  -> No issues found
```

M4.3B không thêm dependency, không đổi SQLite/Supabase schema và không gọi mạng.
Physical purge sau deadline/tombstone vẫn là phần bắt buộc trước khi đánh dấu
Photo Note Trash hoàn tất.

Ngày 2026-09-08, M4.3A recovery UX + ML fail-closed local/Android verification:

```text
flutter test --no-pub <media recovery service + native inventory + SQLite + UI>
  -> 23/23 pass
  -> gồm re-audit chống stale orphan action; path confinement; quarantine,
     Restore, explicit delete và 30-day purge; missing media giữ Library JSON/
     vocabulary nhưng quarantine training lineage và chặn training run

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 313 pass, 1 opt-in Staging test skipped, 0 failure
```

M4.3A không thêm dependency, không đổi SQLite/Supabase schema. Workflow Staging
chỉ chạy migration dry-run `upToDate=true`, không push/ghi remote; Production
không bị thao tác.

```text
flutter build web --no-pub
  -> pass; giữ hai warning có sẵn: flutter_tts WASM dry-run và Cupertino font

tool/run_staging_device_smoke.ps1 -Target android-build
  -> migration dry-run upToDate=true, migrations=[]; không push
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

CPH2375 Android 13 interaction smoke
  -> cài đè APK cuối giữ data; startup audit: 1 orphan, 0 missing, 0 purged
  -> Library render 5 bài + banner đúng 1 mục; bottom sheet không overflow
  -> fixture tạm làm audit 2 orphan; confirm quarantine move đúng sang
     capy_quarantine và UI hiện hạn 08/10/2026 + Restore/Xóa ngay
  -> Restore move fixture về capy_scans; cách ly lại + confirm delete chỉ xóa
     fixture; orphan lịch sử vẫn nguyên và capy_quarantine rỗng
  -> Wi-Fi/mobile data OFF cold start TotalTime=5,042 ms; Library vẫn 5 bài,
     banner 1 mục, audit 1/0/0; không có Failed host lookup/Socket/PostgREST/
     onboarding_completed/SQLite/FATAL trong bộ lọc PID
  -> giữ đúng 6 JPEG; mobile_data=1 và Wi-Fi Tang 5 đã bật lại
```

Ngày 2026-09-08, M4.2 media compensation + startup integrity audit:

```text
flutter test --no-pub <AI scan cleanup + media audit + SQLite targets>
  -> 29/29 pass
  -> gồm success giữ file, scan failure cleanup, cleanup failure không che lỗi
     gốc, native idempotent delete/path confinement, orphan/missing/dedup và
     account-global SQLite reference set

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 306 pass, 1 opt-in Staging test skipped, 0 failure

tool/run_staging_device_smoke.ps1 -Target android-build
  -> đúng linked Staging; migration dry-run upToDate=true, không push
  -> APK debug với LIBRARY_SYNC_ENABLED=true build pass

adb devices -l
  -> CPH2375/665fdb60 Android 13 ở trạng thái device

adb install -r + PID-scoped log + app-private metadata
  -> cài đè giữ data; online cold launch PID 18621, TotalTime=7,726 ms
  -> startup audit báo 1 orphan, 0 missing; 6 JPEG và DB 299,008 byte giữ nguyên

controlled offline image selection
  -> Wi-Fi/mobile data OFF; trước scan có 6 JPEG
  -> khi dialog `Không thể quét ảnh` mở có 7 JPEG
  -> đóng dialog xong trở lại 6 JPEG; DB vẫn 299,008 byte/mốc cũ
  -> log có 0 cleanup failed, SQLiteException và FATAL

offline force-stop/cold-start
  -> PID 24631, TotalTime=6,162 ms; audit vẫn 1 orphan, 0 missing
  -> 6 JPEG giữ nguyên; session mở Home và có tab Library
  -> 0 media-audit failure, Failed host lookup, onboarding profile request,
     PostgREST/Socket/SQLite/media/FATAL trong bộ lọc PID
  -> Wi-Fi Tang 5 và mobile_data=1 đã được khôi phục sau smoke
```

M4.2 không thêm dependency, không đổi SQLite/Supabase schema, không xóa orphan
lịch sử và controlled failure không tạo DB/outbox nên không upload dữ liệu mới.
File orphan đã biết trên device vẫn được giữ cho đến khi D9 xác định
retention/quarantine và user action. Screenshot chẩn đoán tạm local/device đã
được xóa.

Ngày 2026-09-08, M4.1 synchronous onboarding routing + Android Staging smoke:

```text
flutter analyze
  -> No issues found

flutter test --reporter compact
  -> 298 pass, 1 opt-in Staging test skipped, 0 failure
  -> gồm cache unknown/multi-user/persistence, complete/reset/sign-in/sign-up,
     single-flight/backoff và Home -> Library -> detail = 0 profile request

tool/run_staging_device_smoke.ps1 -Target android-build
  -> đúng linked Staging ACTIVE_HEALTHY; migration dry-run upToDate=true
  -> APK debug sync-enabled build pass; temp dart-define credential được cleanup

adb install -r + airplane_mode=1 + Wi-Fi/data OFF + 3 cold restarts
  -> install giữ app data; cả ba cold launch giữ session và vào Home
  -> Home -> Library hiện đúng 5 bài; mở `bowl, blender, bottle`
  -> app-private image=true, vocab_count=4, offline-local copy=true
  -> lượt cuối source bàn giao TotalTime=6,693 ms trên debug APK;
     route/tab/detail không chờ
     profile request hay network timeout
  -> log đúng Capy PID: 0 `Failed host lookup`, `onboarding_completed`,
     `Failed to load onboarding`, PostgREST, Socket/TimeoutException,
     SQLiteException, media error hoặc FATAL
```

M4.1 không thêm dependency, không đổi SQLite/Supabase schema, không ghi dữ liệu
Staging/Production. Supabase/RLS vẫn là authority; cache chỉ quyết định UX route.
Hai dòng `ofbOpen/sysOpen` lúc process start được xác minh là Oplus vendor runtime
trước Flutter load, không phải file media/SQLite của ứng dụng.

Ngày 2026-09-08, M4 Android airplane-mode + cold-restart smoke trên CPH2375:

```text
adb devices -l
  -> 665fdb60 / CPH2375 / Android 13 API 33 ở trạng thái device

tool/run_staging_device_smoke.ps1 -Target android-device -DeviceId 665fdb60
  -> linked target guard pass; Staging ACTIVE_HEALTHY; migration dry-run
     upToDate=true; APK debug có LIBRARY_SYNC_ENABLED=true build thành công
  -> lượt cài đầu bị dừng vì USB mất kết nối; temp dart-define credential đã
     cleanup, sau đó adb install -r cùng APK pass và giữ nguyên app data

adb settings/cmd wifi + UI accessibility read-only
  -> airplane_mode=1, Wi-Fi disabled
  -> trước restart: detail app-private image + 4 từ hiển thị
  -> force-stop không xóa data; PID 32173 -> 3807 sau cold restart
  -> session giữ nguyên, Home mở được, Library còn đủ 5 bài
  -> mở lại `bowl, blender, bottle`: image=true, vocab_count=4,
     `bowl — cái tô` và `blender — máy xay sinh tố` đều hiện

PID-scoped log + run-as metadata read-only
  -> fatal=0, SQLiteException=0, media load error=0
  -> app-private capy_scans có 6 file; capy_vocab.db tồn tại, 299,008 byte
  -> 36 log occurrence `Failed to load onboarding status` do router tiếp tục
     lookup Supabase profile trên startup/navigation khi offline
```

Kết luận: yêu cầu xem ảnh và dữ liệu bài cũ sau mất mạng + kill/restart đã được
chứng minh trên Android thật. Residual router không làm mất dữ liệu hoặc crash,
nhưng phải được sửa để offline navigation không chờ remote và không spam retry.
Smoke không tạo scan mới, không sửa/xóa local data và không ghi Production.

Ngày 2026-09-06, M4 offline Library UI local verification:

```text
flutter test --no-pub test/features/library/data/local/library_media_loader_test.dart test/features/library/presentation/storage_album_screen_test.dart --reporter expanded
  -> 7/7 pass: safe relative-path media read, traversal/missing-file handling,
     list/empty/detail UI và vocabulary fallback khi ảnh thiếu

flutter test --no-pub test/features/library/presentation/storage_album_offline_integration_test.dart --reporter expanded
  -> 1/1 pass: ghi aggregate, đóng/mở SQLite, đọc lại note/detection và byte ảnh
     app-private mà không có network dependency

flutter test --no-pub test/features/settings/cloud_backup_consent_provider_test.dart test/features/settings/settings_screen_test.dart test/features/library/data/local/sqlite_library_store_test.dart --reporter compact
  -> 22/22 pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter compact
  -> 289 pass, 1 opt-in Staging test skipped, 0 failure

flutter build web --no-pub
  -> pass; chỉ còn cảnh báo dependency `flutter_tts` cho WASM dry-run và
     CupertinoIcons asset đã tồn tại trước increment
```

Đây là bằng chứng local tự động; chưa phải Android airplane-mode/restart smoke.
Web compile pass nhưng media loader Web hiện fail closed vì Web scan durability
vẫn pending. Increment không gọi Supabase và không thay đổi Staging/Production.

Ngày 2026-09-06, authenticated consent-to-upload trên Android Staging CPH2375:

```text
adb shell run-as com.capyvocab.app ...
  -> ảnh mới capy_scan_1788631639993447.jpg, 189,147 byte
  -> capy_vocab.db cập nhật cùng lượt scan; snapshot integrity_check=ok

SQLite snapshot read-only bằng Python sqlite3
  -> cloud_backup_enabled=true
  -> đúng 1 consent event cloud_backup OFF->ON, privacy-v1, applied
  -> scan mới succeeded bằng gemini-3.5-flash-lite/Free, có 5 detection
  -> MediaAsset và PhotoNote mới đều synced, remote display path đã ghi
  -> 8/8 operation done, mỗi operation attempt_count=1, không error/retry/block

Supabase CLI target guard + REST/Storage GET chỉ đọc
  -> linked target emtonny's Project ACTIVE_HEALTHY; organization có 2 active project
  -> đúng device ID: 1 media_assets, 1 scan_runs, 5 vocab_detections, 1 photo_notes
  -> private photo_notes object GET HTTP 200, image/jpeg, 189,147 byte
  -> object SHA-256 trùng content_hash_sha256 trong device SQLite
  -> bucket photo_notes public=false
```

Đây là bằng chứng upload thật từ UI/device, không chỉ là bằng chứng outbox local.
Truy vấn remote không tạo, sửa hoặc xóa row/object; Production không được chạm.

Ngày 2026-09-06, ảnh thật trên Android Staging CPH2375:

```text
adb devices -l
  -> CPH2375/665fdb60 ở trạng thái device

adb shell run-as com.capyvocab.app ...
  -> package debuggable; app-private baseline có 2 JPEG
  -> sau scan có JPEG thứ 3, file mới 133,353 byte lúc 00:57 local
  -> capy_vocab.db cập nhật lúc 00:58; app giữ cùng PID sau khi render kết quả

SQLite snapshot read-only bằng sqflite schema/Python sqlite3
  -> scan_results=2, media_assets=2, scan_runs=2, photo_notes=2
  -> vocab_detections=5 tổng; scan mới nhất có 3 detection
  -> latest legacy/media cùng trỏ file JPEG mới
  -> latest scan succeeded, tier free, model gemini-3.5-flash-lite
  -> latest PhotoNote local_only; cloud_backup_enabled=false
  -> sync_operations=0, consent_events=0
```

Có 3 JPEG nhưng chỉ 2 file được legacy/normalized DB tham chiếu. File cũ
`capy_scan_1788609600412190.jpg` là orphan từ trước lượt smoke này; chưa xóa vì
recovery/cleanup lịch sử còn chờ D9 và dữ liệu app-private của người dùng không
được tự ý xóa. Snapshot DB trên máy tính và script chẩn đoán tạm đã được xóa.

Ngày 2026-09-06, Gemini Edge Function trên linked Staging:

```text
deno test --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan
  -> 72 passed, 0 failed

supabase secrets set GEMINI_API_KEY=<in-memory> --project-ref <staging>
  -> secret set pass; key không được in hoặc ghi vào repository

supabase functions deploy gemini-vision-scan --project-ref <staging> --use-api
  -> deploy pass không cần Docker

supabase functions list --project-ref <staging> --output json
  -> gemini-vision-scan v1 ACTIVE, verify_jwt=false theo config

supabase secrets list --project-ref <staging> --output json
  -> GEMINI_API_KEY và các Supabase runtime secret names tồn tại

POST không có credential tới /functions/v1/gemini-vision-scan
  -> HTTP 401

Authenticated JPEG fixture smoke bằng demo user
  -> response contract pass; tier free; model gemini-3.5-flash-lite
  -> ledger status succeeded; fixture trả 0 từ
  -> session logout pass; JPEG tạm xóa; smoke ledger cleanup xác nhận còn 0 row
```

Giới hạn: đây là backend live smoke bằng golden fixture kỹ thuật, chưa phải ảnh
camera/gallery thật và chưa chứng minh UI device lưu normalized aggregate hoặc
drain outbox sau consent.

Ngày 2026-09-05, Android Staging smoke trên CPH2375 (Android 13/API 33):

```text
flutter doctor -v
  -> pass; Android toolchain/SDK 36.1/JDK 21 và device được nhận

tool/run_staging_device_smoke.ps1 -Target android-build
  -> linked Staging/migration preflight pass
  -> build/app/outputs/flutter-apk/app-debug.apk tạo thành công với sync flag bật
  -> rebuild sau auth fix pass; APK mới được `adb install -r` thành công

tool/run_staging_device_smoke.ps1 -Target android-device -DeviceId 665fdb60
  -> cài/launch package com.capyvocab.app thành công
  -> Supabase Staging initialize pass
  -> sau fix native redirect, hot restart không còn StateError
  -> HOME/resume giữ cùng PID 4974; log 120 dòng sau resume không có fatal/Flutter exception
  -> phiên Flutter kết thúc sạch và file dart-define tạm không còn tồn tại

adb install -r build/app/outputs/flutter-apk/app-debug.apk + launcher smoke
  -> install Success; process PID 14516 chạy từ APK rebuild
  -> Supabase init pass; không còn StateError trong log process

flutter test --no-pub test/features/auth/auth_repository_impl_test.dart test/features/auth/auth_screen_test.dart
  -> 6/6 pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter expanded --concurrency=4
  -> 281 tests pass, 1 opt-in Staging test skip theo thiết kế

CI=true dart format --output=none --set-exit-if-changed <2 auth files>
  -> 2 files formatted, 0 changed

git diff --check -- <tracked files thuộc increment>
  -> pass; chỉ có cảnh báo LF/CRLF của working tree
```

Giới hạn: device ở Auth screen, chưa có authenticated Staging session và consent
nên chưa tạo scan/outbox trên device; đây không phải bằng chứng upload từ UI.
Hai lần gọi test trong sandbox không có quyền ghi Flutter SDK cache/lock nên đã
được dừng; lượt chạy có đúng quyền hoàn tất trong 22 giây và là evidence ở trên.

Ngày 2026-09-04, sau M3C local verification (các lệnh Supabase bên dưới là
evidence M3A ngày 2026-09-03):

```text
flutter pub get
  -> pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter compact
  -> 273/273 tests passed (sau M3C)
  -> một lượt trước đó báo 1 failure không giữ được tên do output song song bị
     cắt; hai lượt full suite kế tiếp đều pass 273/273, cần theo dõi flakiness

flutter build web --no-pub --dart-define=LIBRARY_SYNC_ENABLED=true
  -> pass
  -> còn cảnh báo không chặn từ flutter_tts Wasm dry-run và CupertinoIcons

Baseline/M3A migration contract test
  -> 4/4 pass

supabase db push --linked --dry-run (trước apply)
  -> pass; đúng 20 migration theo thứ tự

supabase db push --linked --yes
  -> pass trên Staging

supabase migration list --linked
  -> local/remote khớp 20/20

supabase db push --linked --dry-run (sau apply)
  -> upToDate=true

Staging two-user RLS/private Storage runtime
  -> pass; cleanup pass

tool/run_staging_library_sync_e2e.ps1
  -> pass 4 lượt trên linked Staging; migration preflight up to date
  -> 5/5 operation done; 2 private JPEG + 5 normalized entity groups verified
  -> owner download, raw JSON marker, SHA-256 ảnh/JSON và deterministic paths pass
  -> objects, rows và Auth test user cleanup assertions pass
  -> lần preflight đầu từ chối giả do PowerShell 5.1 nested JSON array; không có
     remote mutation, parser được sửa và giữ nguyên fail-closed checks

flutter test --no-pub --reporter compact (sau live harness)
  -> 273 pass, 1 opt-in Staging test skipped theo thiết kế

git diff --check -- <M2C scope>
  -> pass; chỉ có cảnh báo LF/CRLF của working tree
```

Coverage mới của M3A gồm deterministic owner/media object path, traversal và
extension boundary, signed URL TTL, normalized cloud tables, raw JSON, owner
foreign keys, private bucket policies, baseline ordering và runtime isolation.
Coverage M3B gồm dependency drain, transient/two-phase retry, restart recovery,
consent, auth resume và tombstone purge. Coverage M3C gồm consent/outbox trigger,
retry timer, logout cancellation, concurrent owner-switch isolation,
coordinator error recovery và offline startup contract. M2C regression vẫn
nằm trong full suite. Web build với cờ bật xác
nhận conditional factory không kéo native SQLite/file sync vào Web runtime.
Live Staging coverage dùng chính SQLite store, worker và Supabase gateway; không
gọi Gemini và không phải device lifecycle test.

Project-scoped Supabase CLI hiện hoạt động; PostgreSQL 18 `psql.exe` có trên máy
nhưng không nằm trong PATH. M3A đã parse/apply và pass RLS/Storage runtime test
với hai user trên Staging; Production chưa được apply.

### Remote staging không Docker

- Project-scoped Supabase CLI 2.116.0 hoạt động; tài khoản CLI đã đăng nhập.
- Management API xác nhận organization chứa hai project đang ở plan `free`.
- Project inactive `emtonny's Project` đã được restore và đạt
  `ACTIVE_HEALTHY`; cùng Production tạo thành đúng 2 project active trong giới
  hạn Free. Không tạo project thứ ba và không bật add-on/paid plan.
- Repository hiện link với `emtonny's Project` và coi đây là Staging;
  `CapyVocabApp` Production vẫn `ACTIVE_HEALTHY` nhưng không còn là linked
  target của CLI.
- Baseline schema gốc từ commit khởi tạo đã được khôi phục thành migration
  `20260725204011_initial_schema.sql`; không chứa row hay dữ liệu Production.
- Baseline + 19 migration kế tiếp đã apply thành công trên Staging. Migration
  history local/remote khớp 20/20 và dry-run sau apply trả `upToDate=true`.
- Staging có 21 bảng public thực tế: 20 bảng product/Library cùng bảng
  `gemini_model_health` được tạo bởi migration health.
- Runtime test với hai authenticated user xác nhận owner insert/read hoạt động,
  cross-user row read trả rỗng, cross-user insert bị `403`, cross-user Storage
  read/upload bị chặn, owner upload/signed URL hoạt động và bucket là private.
  Toàn bộ user/row/object test đã cleanup.
- Worker live E2E bổ sung xác nhận local outbox thật upload hai media variant,
  upsert media/scan/detection/annotation/Photo Note, giữ raw JSON, owner tải lại
  private object và cleanup toàn bộ artifact. Bốn lượt live đều pass.
- Production không bị apply migration, reset hoặc thay đổi dữ liệu trong bước
  thiết lập staging này.

## Việc tiếp theo an toàn

Sau Production Gate 3:

1. Quyết định rollout client Production: vẫn giữ sync OFF hoặc build/smoke có
   `LIBRARY_SYNC_ENABLED=true` bằng account test trước khi release. Không tự
   upload dữ liệu user hiện tại chỉ vì backend đã sẵn sàng.
2. Duyệt D10 và hoàn thiện account delete cùng multi-device conflict
   tests (live-test cleanup không thay thế product recovery).

## Tài liệu liên quan

- `docs/architecture/offline_ml_storage.md`
- `docs/data/library_data_contract.md`
- `docs/data/privacy_and_retention.md`
- `docs/data/m2a_sqlite_spike.md`
- `docs/data/m2b_sqlite_repository.md`
- `docs/data/m2c_native_scan_persistence.md`
- `docs/data/m3a_cloud_contract.md`
- `docs/data/m3b_outbox_sync_worker.md`
- `docs/data/m3c_runtime_sync.md`
- `docs/data/m4_cloud_metadata_pull.md`
- `PROJECT_STATUS.md`

## Change log

### 2026-09-11 — GitHub UI sync tới `cbd7318`, offline contract preserved

- Fetch và fast-forward `AI-scan` từ `fba6f38` lên `cbd7318` (6 commit).
- Nhận design system neo-brutalist, graph-paper background, Scan/Auth/Onboarding/
  navigation polish, soft page transition và password-recovery UI/route.
- Hòa trộn router để redirect onboarding vẫn synchronous từ cache, không query
  profile khi chuyển Home → Library → detail; giữ route Library detail/trash.
- Giữ entitlement Pro cho custom note template và Cloud Backup consent UI trong
  giao diện mới; cập nhật test doubles cho auth/password-recovery contract.
- `dart analyze`: `No issues found`; nhóm UI/router/auth/settings/offline test:
  73/73 pass.
- Bổ sung Kotlin Android plugin còn thiếu trong scaffold GitHub; Android debug
  build pass và tạo `build/app/outputs/flutter-apk/app-debug.apk`.
- Không đổi schema/migration/consent/retention/ML lineage, không ghi Supabase và
  không deploy. Vilao gateway trong commit `cbd7318` chưa hòa vào Edge Function
  local đã rollout; cần kiểm tra backend riêng trước khi áp dụng.

### 2026-09-11 — Production Gate 3 M3A/M4.5 + isolation verified

- Chủ dự án duyệt explicit Gate 3 trong chat. Preflight xác nhận đúng Production
  ref, repo vẫn link Staging, backup manifest tồn tại, audit 0 row/object và
  dry-run chỉ có M3A + M4.5.
- `db push --project-ref <Production> --yes` apply đúng
  `20260903120000_add_library_cloud_storage_contract.sql` và
  `20260910120000_add_library_cloud_pull_feed.sql`.
- Post-apply history khớp 21/21, dry-run `upToDate=true`, bucket private và M3A
  tables present. Audit harness ban đầu báo sai table rỗng là absent do
  PowerShell collapse empty array; sửa result thành `{Exists, Rows}` và bump
  audit v2. Production empty + Staging populated regression pass.
- Tái sử dụng full live Library test trên Production: SQLite outbox/private
  upload/normalized raw JSON/pull sang DB thứ hai/no-auto-download/permanent
  purge/delete feed/cleanup đều pass.
- Hai-user runtime: owner access/upload/download/signed URL pass; other user
  thấy 0 media/note, row insert 403, Storage read/upload 400. Lượt đầu false
  fail do `@($null).Count`; raw JSON rerun pass, không có RLS leak.
- Final audit xác nhận 0 fixture row/object/legacy/unreferenced; Auth fixture
  marker 0. Repo không relink, không deploy Edge Function/app build và default
  `LIBRARY_SYNC_ENABLED=false` giữ nguyên.
- Final audit v2 pass; targeted cloud migration/rollout contract pass 8/8;
  `flutter analyze --no-pub` trả `No issues found`.

### 2026-09-11 — Production Gate 0–2 backup/fingerprint/history repair verified

- Chủ dự án duyệt Gate 0–2 trong chat; phạm vi duyệt không gồm apply M3A/M4.5.
- Supabase Docker dump fail-closed do Docker engine không chạy; backup dở và
  plaintext được xóa. Dùng PostgreSQL 18 local làm fallback với temporary login
  trong memory, không in/ghi credential.
- Tạo backup ngoài repo tại
  `%LOCALAPPDATA%\CapyVocabApp\production_backups\20260911T105509Z`: public
  schema, full public custom dump và pre-repair history đều mã hóa DPAPI
  CurrentUser. 3/3 decrypt SHA-256 round-trip và `pg_restore --list` pass;
  manifest ghi restore constraint cùng Windows profile và aggregate Library
  snapshot trước/sau repair; manifest re-read verification pass.
- Catalog fingerprint pass: đủ 15 baseline tables, subscription uniqueness,
  AI request ledger/function/final service-role privileges, ba circuit-breaker
  functions; M3A/M4.5 tables chưa tồn tại.
- Re-audit ngay trước repair vẫn 0 Photo Note/0 Storage object và complete, nên
  không chạy backfill.
- Repair đúng migration ledger Production: đánh dấu 4 remote aliases reverted,
  baseline + 4 local canonical applied. Không chạy product SQL.
- Post-repair history khớp local qua `20260829152311`; Production dry-run đề
  xuất đúng M3A + M4.5. Hậu kiểm xác nhận bucket vẫn public, M3A absent, 0
  row/object; repo vẫn link Staging và Staging dry-run up-to-date.
- PowerShell parser pass; targeted cloud rollout/migration contract pass 8/8;
  `flutter analyze --no-pub` trả `No issues found`.
- Tại thời điểm entry Gate 0–2 này, Gate 3 apply còn
  `BLOCKED PENDING SEPARATE APPROVAL`; entry Gate 3 mới hơn ở phía trên ghi nhận
  apply/runtime verification đã hoàn tất. Production sync build vẫn chưa chạy.

### 2026-09-11 — Production Library rollout audited; writes blocked

- Thêm `tool/audit_supabase_library_rollout.ps1`: validate đúng project
  name/ref/status, chỉ dùng Data API GET và Storage list read-only, tự test sáu
  loại path, paginate, đối chiếu đủ display/original/model-input, và chỉ xuất
  aggregate counts; không xuất key/user ID/note ID/URL/object path.
- Live Staging audit: 5 normalized Photo Note, 10 normalized private object,
  không legacy, missing/mismatch hoặc unreferenced; inventory không truncate.
- Live Production audit: 0 Photo Note, 0 object, bucket public và `media_assets`
  chưa tồn tại. Vì vậy không chạy backfill; kết quả chỉ đúng tại thời điểm audit
  và bắt buộc chạy lại ngay trước apply.
- `migration list` xác nhận Staging 21/21/up-to-date. Production có 14 version
  chung, thiếu baseline history, 4 remote-only version và 7 local-only version
  (baseline + 4 canonical alias + M3A + M4.5).
  Fetch vào OS temp + semantic diff xác nhận bốn remote-only là alias của bốn
  migration local canonical; khác ở transaction/comment/semicolon và revoke
  trung gian nhưng final schema/grant tương đương. Temp đã xóa.
- Thêm `docs/data/production_library_rollout.md` với backup gate, conditional
  two-phase legacy backfill không bịa scan/label, proposed history mapping,
  dry-run/apply gate và fail-forward rollback giữ dữ liệu.
- Cập nhật M3A contract và thêm hai static contract test. PowerShell parser
  pass; targeted `library_cloud_migration_test.dart` pass 8/8;
  `flutter analyze --no-pub` trả `No issues found`.
- History repair, migration apply, bucket/policy mutation, row/object write và
  relink Production đều chưa thực hiện, trạng thái
  `BLOCKED PENDING APPROVAL`.

### 2026-09-11 — Explicit pre-consent Library backfill verified

- Thêm Settings action `Sao lưu bài đã có` chỉ khi Cloud Backup ON, với dialog
  explicit riêng; bật switch không tự backfill. Snackbar báo số note queued và
  số note thiếu media bị bỏ qua.
- Store chỉ chọn active note đúng owner, chưa synced/chưa có Photo Note outbox/
  tombstone. Controller stat đủ display/original/model-input khi cần upload;
  Trash và missing media fail-closed, media đã ở cloud không bị upload lặp.
- Enqueue dùng lại graph hiện có trong một transaction, đổi media/note sang
  pending và idempotent khi nhấn lại; coordinator hiện tại nhận `sync` notify.
- Targeted 35/35, Settings+Library 123 pass + 1 skip, full suite 351 pass + 1
  skip, analyzer sạch. Live Staging pass pre-consent→backfill→upload→pull→purge
  và cleanup toàn bộ fixture.
- Android Staging build/cài đè pass và giữ SQLite/cả ba JPEG checksum. Settings
  render action/dialog đúng; 5 note đã synced trả zero-candidate. Hai JPEG khác
  có mtime trước lần update APK nên không phải side effect của action mới.
- Không thêm dependency, không đổi schema/migration, AI consent/ML lineage,
  demo account data hoặc Production.

### 2026-09-11 — Library actual local-media usage UX Android verified

- Sửa storage summary để lấy danh sách media owner-scoped còn được Photo Note
  active/Trash giữ lại, kiểm tra file app-private và cộng dung lượng thực bằng
  `File.length()`; remote `byte_size_display` không còn bị gắn nhãn dung lượng
  local.
- Library/card/detail phân biệt ba trạng thái: `Ảnh trên máy`, `Ảnh trên cloud`
  và `Thiếu ảnh`. Cloud-only vocabulary vẫn xem offline; JPEG chỉ tải khi người
  dùng explicit nhấn `Tải ảnh từ cloud`.
- Regression test local/cloud-only/missing pass; toàn Library 105 pass + 1 live
  skip, full suite 346 pass + 1 live skip, analyzer sạch. Staging build pass sau
  migration dry-run up to date.
- `adb install -r` giữ nguyên SQLite/JPEG checksum. CPH2375 hiển thị đúng
  `5 bài trong thư viện`, `1/5 ảnh trên máy • 114.2 KB`, `4 trên cloud`; mở
  cloud-only detail không tự tải và `capy_scans/` vẫn đúng 1 JPEG 116,892 byte.
- Không thêm dependency, không đổi schema/migration, consent, ML lineage,
  cloud data hoặc Production.

### 2026-09-11 — Android explicit restore + quiet-offline sync verified

- Sau clean-install metadata rehydrate, explicit CTA tải bài đầu đã ghi đúng 1
  JPEG app-private 116,892 byte/SHA-256 `a6664293...fe27da`; CTA biến mất, ảnh và
  4 từ mở lại được sau force-stop/cold-start offline. Bốn JPEG khác không tự tải.
- Smoke đầu tái hiện `pull_library_delta` ném `Failed host lookup` lúc startup và
  sau 30 giây. Root cause: coordinator có retry timer nhưng không có network gate.
- Thêm Android `ConnectivityManager` validated-network MethodChannel và quyền
  `ACCESS_NETWORK_STATE`; không thêm package. Coordinator chặn drain/pull khi
  offline, không report network absence như runtime error, và exponential backoff
  30 giây→60 giây→... tối đa 15 phút; success/user switch reset failure count.
- Test coordinator 9/9, toàn Library 104 pass + 1 live skip, full suite 345 pass
  + 1 live skip và analyzer sạch. APK Staging sync-enabled build pass sau
  migration dry-run up to date.
- Cài APK bằng `adb install -r`; checksum SQLite/JPEG trước/sau giữ nguyên. Cold
  start offline 6,963 ms; Home→Library→detail qua hơn 30 giây có 0 RPC/host lookup/
  stack trace. Wi-Fi/mobile data đã khôi phục. Không đổi DB/ML/Production.

### 2026-09-11 — Android install incident; sandbox cleared

- CPH2375 được nhận đúng qua Flutter. Dùng `flutter install` với APK Staging đã
  build và `--use-application-binary` theo giả định sẽ cài đè giữ dữ liệu.
- Command thực tế in `Uninstalling old version...`; read-only `run-as` sau cài
  xác nhận sandbox mới chỉ có `cache/code_cache`, không còn `databases/files`.
- Dừng trước launch/sign-in. Chưa thử cloud metadata pull hoặc manual media
  restore; dữ liệu local-only/orphan không có bằng chứng phục hồi được.
- Sau khi chủ dự án duyệt tiếp tục, cold-launch app Staging pass 7,909 ms,
  Supabase init pass, PID 7158 và log lọc không có Flutter/AndroidRuntime error.
  Chủ dự án đăng nhập thành công; SQLite mới 282,624 byte và startup audit sạch.
- UI Settings xác nhận Cloud Backup OFF sau cài sạch. Chưa tự thay consent;
  chủ dự án sau đó bật/confirm và UI trả `checked=true`.
- Android metadata rehydrate pass: Library có 5 note, detail có raw-derived
  vocabulary/4 từ và manual cloud CTA; SQLite 282,624→290,816 byte, không có
  `capy_scans`, không có runtime error. Không auto-download JPEG.
- Ghi nhận UX bug: storage summary dùng remote metadata byte-size nhưng gắn nhãn
  `ảnh local`, và subtitle gọi cloud-only note là `đã lưu trên thiết bị`.
  Manual download/offline cold restart từng PENDING tại thời điểm entry này; đã
  pass trong entry `Android explicit restore + quiet-offline sync verified` ở trên.
- Không thay đổi source/schema/migration, không ghi Staging/Production trong
  bước device này. M4.5 local/live Staging evidence trước sự cố vẫn hợp lệ,
  physical Android rehydrate/offline smoke nay đã pass theo entry mới hơn.

### 2026-09-11 — M4.5 cloud metadata pull Staging E2E verified

- Nâng SQLite schema lên v3/22 bảng với `library_pull_cursors` theo user; apply
  snapshot/delete/cursor trong một transaction. Local note chưa `synced` không
  bị ghi đè; tombstone chặn resurrection và fail-close training example/model.
- Thêm RPC owner-scoped + change feed identifiers-only; không chứa JPEG/raw JSON
  duplicate. Migration `20260910120000_add_library_cloud_pull_feed.sql` apply
  đúng linked Staging; migration history 21/21 và post-apply dry-run up to date.
- Coordinator upload trước rồi pull metadata nền. Hết batch budget nhưng server
  còn trang sẽ tự chạy lượt kế trong cùng single-flight; cursor không tiến thì
  fail contract và đi theo backoff, tránh lặp vô hạn.
- Live owner tạm với hai SQLite pass: A upload private aggregate/JPEG; B nhận
  metadata, raw Gemini JSON và vocabulary, cursor tiến, outbox 0, JPEG vẫn thiếu;
  sau remote purge B nhận đúng delete receipt và xóa source local.
- Teardown xác nhận xóa user tạm, normalized rows, Storage object và change-feed
  fixture. Production không linked/apply/reset/thay đổi. Không thêm dependency,
  không auto-download và không thay đổi database phục vụ AI ngoài fail-closed
  lineage khi nguồn bị xóa.
- Targeted pull/coordinator 13/13 và SQLite 17/17 pass; analyzer toàn dự án sạch,
  full suite 344 pass + 1 opt-in live skip. Live Staging test 1/1 pass và cleanup
  pass; APK debug Staging với `LIBRARY_SYNC_ENABLED=true` build pass.

### 2026-09-10 — M4.4 manual cloud restore Android E2E verified

- Settings trên CPH2375 xác nhận account Cloud Backup ON. Chọn đúng synced
  Photo Note `bracelet, notebook, smartphone`; rời Library để dispose provider
  cache rồi tạm đổi tên JPEG local thành backup app-private có rollback.
- Khi original thiếu, detail mới hiện `Ảnh đang có trên Cloud Backup` và
  `Tải ảnh từ cloud`; kiểm tra trước tap xác nhận original vẫn absent nên không
  có automatic download ở startup, Library list hoặc detail.
- Explicit tap tải lại đúng `capy_scan_1788969413220772.jpg` 116,892 byte;
  SHA-256 trùng backup trước smoke, ảnh render, CTA biến mất và backup được xóa.
- Sau khi file hoàn chỉnh, tắt Wi-Fi/mobile data, force-stop/cold-start 5,315 ms:
  Library giữ 7 bài, restored detail mở ảnh + 4 từ và log network/profile/SQLite/
  FATAL đều 0. Mạng cùng file hierarchy tạm được khôi phục/dọn sạch.
- Không restart/resume trong missing window nên startup integrity audit không
  thấy false missing và không đổi training lineage. Không sửa source/schema,
  không thao tác Production; M4 còn cloud-only metadata pull/multi-device.

### 2026-09-10 — M4.3C Android Restore/permanent-delete E2E verified

- Chủ dự án đưa rõ một Photo Note `container, router, cat` vào Trash để dùng
  làm fixture. Baseline có 8 active note, Trash 1, 9 JPEG và DB 315,392 byte.
- Android UI pass Trash → Restore (Trash trống) → đúng menu item → confirm đưa
  lại Trash (active 7/Trash 1) → confirm permanent delete với copy local/cloud.
- Permanent delete làm `capy_scans` giảm đúng 9→8 và chỉ xóa
  `capy_scan_1788971916677667.jpg`; Trash về 0. Cold restart 5,400 ms giữ 7 bài,
  8 JPEG và fixture không sống lại; log PID có 0 network/SQLite/FATAL/purge lỗi.
- Read-only audit trên đúng linked Staging `ACTIVE_HEALTHY` trả raw REST `[]`
  cho Photo Note title fixture. Lượt đếm đầu báo sai 1 do PowerShell 5.1 nested
  array; metadata null đã làm lộ lỗi và raw-response rerun xác nhận 0 chính xác.
- Storage object của device fixture không được query riêng vì media UUID đã bị
  xóa local trước audit; Storage folder deletion đã có live Staging E2E biệt
  lập. Không ghi Production, không chạm 7 bài còn lại; file hierarchy tạm đã
  xóa và mạng giữ airplane OFF/mobile data ON/Wi-Fi ON.

### 2026-09-10 — M4.3C Photo Note physical purge local verified

- Thêm owner-scoped deletion maintenance: Trash đủ đúng 30 ngày được chuyển
  thành permanent request ở startup/sign-in/resume; explicit delete chạy ngay.
- Native media purger chỉ xóa file con trực tiếp trong app-private
  `capy_scans/`, idempotent và từ chối path ngoài phạm vi.
- SQLite finalizer xóa aggregate/source độc quyền, learning projection,
  training examples và manifest/run links; shared media chỉ bị xóa khi không
  còn Photo Note active khác. Model đã dùng source bị invalidated; tombstone
  receipt tối thiểu được giữ.
- Cloud delete được tách khỏi upload consent: Cloud Backup OFF không tạo upload
  mới nhưng privacy purge vẫn retry cho đúng authenticated owner; payload purge
  giữ remote target sau khi local rows/file đã bị xóa.
- Targeted suite 37/37 pass; analyzer sạch; full suite 329 pass + 1 opt-in
  Staging skip. Live Staging fixture pass upload → local purge → backup OFF →
  cloud row/Storage purge, retained payload cleanup và tombstone receipt; user,
  row và object fixture cleanup pass. APK Staging sync-enabled build pass;
  không thêm dependency/migration và không thao tác Production.
- Android CPH2375 cài đè giữ data; data-off cold restart mở Home → Library 8 bài
  → detail ảnh local/3 từ → Trash empty state. Resume giữ PID và hoàn tất 139 ms;
  log network/profile/SQLite/purge error đều 0. 9 JPEG/DB giữ nguyên, mobile data
  đã bật lại; không tạo/xóa fixture vì không được phép dùng bài thật.
- Debug cold start online/offline lần lượt 7,002/4,858 ms và có skipped-frame
  warning; chưa có profile/release benchmark nên không tuyên bố đã đạt mục tiêu
  hiệu năng sản phẩm.

### 2026-09-09 — M4.4 manual cloud media restore local verified

- Detail chỉ hiện `Tải ảnh từ cloud` khi local read lỗi, MediaAsset có private
  remote display path và build sync-enabled; render/open detail không gọi
  download.
- Explicit tap mới gọi private Storage download. Service fail-closed nếu auth
  owner/object prefix sai, payload rỗng, byte size hoặc SHA-256 không khớp.
- Native writer dùng relative-path validation, file tạm + rename atomically,
  không overwrite local copy đã xuất hiện đồng thời và dọn file tạm khi lỗi.
- Targeted restore/writer/UI 14/14 pass; full suite 323 pass + 1 opt-in Staging
  skip; analyzer sạch; Web build pass với warning có sẵn; Staging migration
  dry-run up-to-date và APK sync-enabled build pass.
- Không thêm dependency/schema, không auto-download, không triển khai Gallery
  export, không pull cloud-only metadata sang máy mới và không thao tác remote.

### 2026-09-09 — M4.3B Photo Note Trash UI + storage summary local verified

- Thêm active-account storage summary từ normalized MediaAsset metadata và
  hiển thị số bài active, số bài trong Trash, dung lượng display/original local.
- Thêm route/UI Trash 30 ngày; move yêu cầu confirm, Restore khả dụng trước
  tombstone và xóa vĩnh viễn tạo request rõ ràng thay vì báo cloud đã xóa ngay.
- Trash query không hiển thị Photo Note đã có permanent-delete tombstone;
  repository chặn restore item đang chờ purge và vẫn giữ content ẩn cho đến khi
  local/cloud finalizer hoàn tất.
- Widget test đầu bắt được overflow 58 px ở popup hẹp; CTA được rút gọn và test
  rerun pass. Targeted SQLite + widget 19/19 pass; analyzer toàn dự án sạch.
- Không thêm dependency, không đổi schema, không tải media cloud và không thao
  tác Staging/Production.

### 2026-09-09 — Cloud download UX chốt là thủ công

- Chủ dự án yêu cầu tải ảnh/cloud Library là tùy chọn, không tự động tải xuống.
- M4 cloud restore phải hiển thị trạng thái cloud-only/missing-local và chỉ ghi
  media vào app-private sau hành động rõ ràng của user; startup, reconnect,
  Library list và detail không được âm thầm tải binary media.
- Download về app-private để CapyVocab dùng offline không đồng nghĩa export ảnh
  sang Gallery/Photos của hệ điều hành; export là một feature riêng nếu được
  duyệt sau.
- Đây là cập nhật requirement/tài liệu, chưa triển khai code, chưa thay đổi
  SQLite/Supabase schema hoặc dữ liệu và không kế thừa kết quả test cũ làm bằng
  chứng implementation.

### 2026-09-08 — D9 approved; M4.3A recovery UX Android verified

- D9 chốt retention 30 ngày: orphan chỉ vào `capy_quarantine/` sau explicit
  confirm; UI cho Restore/Xóa ngay và startup chỉ purge file đã được cách ly đủ
  30 ngày. Adapter giới hạn mutation ở file con trực tiếp, từ chối traversal,
  wrong-directory và collision; service re-audit ngay trước move để tránh race.
- Library hiển thị banner/bottom sheet recovery với touch target tối thiểu 48dp,
  confirm cho quarantine/delete và không đưa absolute path ra UI/log.
- Missing media giữ Photo Note, scan JSON, detection và vocabulary nhưng chuyển
  training example liên quan sang `quarantined/excluded`; model đã dùng source
  bị invalidated và training run kiểm tra eligibility lại trước khi ghi lineage.
- Targeted regression pass 23/23; analyzer sạch; full suite pass 313 + 1 opt-in
  Staging skip; Web và APK Staging build pass, migration dry-run up-to-date.
- CPH2375 fixture pass confirm quarantine → Restore → cách ly lại → confirm
  delete; chỉ fixture bị xóa, orphan lịch sử/6 JPEG thật giữ nguyên. Offline cold
  restart 5,042 ms giữ 5 bài/banner 1 mục/audit 1 orphan, 0 missing, 0 purged;
  không có lỗi network/profile/SQLite/FATAL trong bộ lọc PID và mạng đã bật lại.

### 2026-09-08 — M4.2 Android media recovery smoke verified

- ADB nhận đúng CPH2375/665fdb60 Android 13; `adb install -r` APK Staging cuối
  giữ session, 6 JPEG app-private và SQLite 299,008 byte.
- Online cold startup PID 18621 báo `Library media audit: 1 orphan, 0 missing`;
  audit không xóa file lịch sử và UI giữ authenticated Home.
- Tắt Wi-Fi/mobile data rồi chọn một ảnh local: file count từ 6 lên 7 trong khi
  dialog lỗi scan mở, sau khi đóng dialog quay về 6. SQLite size/mtime không đổi
  và log không có cleanup failure, SQLiteException hoặc FATAL.
- Offline force-stop/cold-start PID 24631 báo lại đúng 1 orphan/0 missing, giữ
  6 file, session/Home/Library; bộ lọc PID không có profile/network/storage lỗi.
- Khôi phục mobile_data=1 và Wi-Fi kết nối lại `Tang 5`; screenshot chẩn đoán
  tạm ở device/workspace đã xóa. Controlled failure không tạo DB/outbox hoặc
  upload mới; Production không bị thao tác.

### 2026-09-08 — M4.2 media compensation and startup audit locally verified

- Mở rộng scan image storage với cleanup idempotent; native chỉ cho phép xóa
  file con trực tiếp của app-private `capy_scans`, từ chối path ngoài phạm vi.
- Bottom sheet chỉ giữ JPEG khi `ScanResultRecord` đã commit. Vision/SQLite lỗi
  hoặc widget đóng giữa chừng đều cleanup best-effort; lỗi cleanup không thay
  thông báo lỗi gốc và log không chứa absolute local path.
- Thêm account-global SQLite media reference query và native inventory; audit
  một lần khi có session, chạy nền, không chặn router/UI và không gọi network.
- Audit chỉ trả orphan/missing set bất biến và runtime chỉ log count; không xóa,
  quarantine hoặc sửa DB lịch sử khi D9 chưa được duyệt.
- Targeted regression 29/29 pass; analyzer sạch; full Flutter suite 306 pass +
  1 opt-in Staging skip. Staging migration dry-run up-to-date và APK debug
  sync-enabled build pass; không push migration hay ghi remote.
- Android runtime evidence đã được bổ sung trong increment kế tiếp; M4 vẫn
  PARTIAL cho UX xử lý orphan/missing lịch sử theo D9.

### 2026-09-08 — M4.1 synchronous onboarding routing Android verified

- Thêm cache onboarding `unknown/incomplete/complete` trong SharedPreferences,
  key theo Supabase user ID; hydrate trước `runApp`, không có state dùng chung.
- Chuyển GoRouter redirect từ async remote profile query sang synchronous cache
  read. `unknown` fail-open cho local/offline UX; `incomplete` vào onboarding.
- Nối complete/reset/sign-up vào cache sau thao tác server thành công; sign-in,
  auth identity change và app resume chỉ kích hoạt refresh nền.
- Refresher deduplicate request đang chạy theo owner và exponential backoff
  30 giây đến 15 phút; failure không block UI và không in network stack noisy.
- Thêm unit/widget regression cho owner isolation, persistence, unknown,
  single-flight/backoff và Home → Library → detail tạo 0 profile request.
- Analyzer sạch; full Flutter suite 298 pass + 1 opt-in Staging skip. APK debug
  Staging sync-enabled build pass và ba Android airplane cold restart giữ đủ
  5 bài/ảnh local/4 từ, log profile/network/storage theo PID bằng 0.
- Không thêm dependency, không đổi database/schema AI, không ghi Staging hoặc
  Production; preflight Staging chỉ đọc và migration chỉ dry-run.

### 2026-09-08 — M4 Android offline restart smoke verified

- Cài APK Staging debug bằng `adb install -r` để giữ app data; preflight xác
  nhận đúng linked Staging, migration dry-run up to date và sync build flag bật.
- Trên CPH2375, xác nhận airplane mode ON và Wi-Fi disabled; detail ảnh/từ vựng
  vẫn hiển thị trước restart. Force-stop/cold-restart đổi PID 32173 sang 3807,
  giữ session và vào Home mà không có mạng.
- Sau restart, Library còn đủ 5 bài; mở lại bài mới nhất có app-private image,
  4 từ và nghĩa đúng. Log có 0 fatal, 0 SQLiteException, 0 media load error;
  sandbox app có 6 media file và DB 299,008 byte.
- Phát hiện global router vẫn lookup Supabase profile trên mỗi navigation khi
  offline: 36 log occurrence trước/trong smoke, gây delay và stack-trace noise.
  Ghi thành residual bắt buộc sửa; không hạ kết luận thành offline tức thời.
- Lượt cài runner đầu mất USB sau build; runner cleanup file credential tạm.
  Smoke sau đó không tạo scan mới, không xóa/sửa local data và không ghi
  Production.

### 2026-09-06 — M4 offline Library UI locally verified

- Nối màn Storage vào owner-scoped SQLite stream và thêm route detail theo
  PhotoNote ID; giữ export tương thích ở feature `ai_scan`.
- Thêm app-private media loader dùng persisted relative path, chặn URI/absolute/
  parent traversal và đóng gói lỗi file; Web implementation hiện fail closed.
- List/detail hiển thị thumbnail/ảnh local, số từ, detection/annotation đã sửa,
  model source và trạng thái sync; dữ liệu từ vựng vẫn hiện nếu ảnh bị thiếu.
- Widget tests pass 7/7; SQLite close/reopen + media integration pass 1/1;
  regression Settings/SQLite pass 22/22; full suite pass 289 với 1 opt-in test
  skipped; analyzer sạch và Web build pass.
- Chưa chạy Android airplane-mode/restart smoke và chưa triển khai orphan/media
  recovery. Increment không gọi Supabase, không sửa Staging hoặc Production.

### 2026-09-06 — Android consent-to-upload E2E verified

- Chủ dự án bật Cloud Backup trong Settings và quét ảnh mới trên authenticated
  Staging build. SQLite audit xác nhận consent `cloud_backup` OFF→ON,
  `privacy-v1`, enforcement `applied`; hai consent AI vẫn OFF.
- Ảnh thứ tư được auto-save app-private với 189,147 byte. Normalized aggregate
  mới có 1 MediaAsset, 1 ScanRun succeeded, 5 VocabDetection và 1 PhotoNote.
- Transaction tạo đúng 8 dependency operation; worker hoàn tất 8/8 ở lần thử
  đầu, không có error/retry/block, MediaAsset và PhotoNote chuyển `synced`.
- Truy vấn GET chỉ đọc trên đúng linked Staging xác nhận toàn bộ remote ID khớp
  device: 1 media, 1 scan, 5 detection và 1 Photo Note. Private JPEG tải lại
  HTTP 200, 189,147 byte, MIME `image/jpeg`, SHA-256 trùng SQLite; bucket vẫn
  `public=false`.
- Không tạo/sửa/xóa dữ liệu khi đối chiếu; không chạm Production. Snapshot DB và
  hai script chẩn đoán tạm được xóa sau verification.

### 2026-09-06 — Android real-photo scan persisted locally

- Kết nối CPH2375 qua ADB, mở đúng debug package `com.capyvocab.app` và theo dõi
  đúng process trong khi chủ dự án quét ảnh thật; UI đã render kết quả.
- Baseline có 2 JPEG app-private; lượt scan tạo JPEG thứ 3 kích thước 133,353
  byte và cập nhật `capy_vocab.db`. Snapshot read-only xác nhận latest legacy
  path và MediaAsset cùng tham chiếu file mới.
- SQLite có 2 legacy result, 2 MediaAsset, 2 ScanRun, 2 PhotoNote và 5 detection;
  scan mới nhất `succeeded` bằng `gemini-3.5-flash-lite`/Free với 3 detection.
- Account cloud-backup đang OFF, chưa có consent event; latest PhotoNote là
  `local_only` và `sync_operations=0`, nên lượt scan này chưa upload Supabase
  đúng theo contract fail-closed.
- Phát hiện một JPEG cũ không được DB tham chiếu. Không xóa vì đây là dữ liệu
  app-private có trước smoke; retention/quarantine lịch sử vẫn chờ D9.
- Dừng log monitor, xóa DB snapshot và script chẩn đoán tạm sau khi đọc; không
  sửa database/device data, không thay đổi Staging remote hoặc Production.

### 2026-09-06 — Staging Gemini Edge deployed and live verified

- Chủ dự án cung cấp Gemini test key qua clipboard; key được đọc vào bộ nhớ,
  đặt thành `GEMINI_API_KEY` trên đúng linked Staging rồi clipboard được ghi đè.
  Key/token không được in, ghi vào source hoặc giữ trong script/file tạm.
- Trước deploy, full Edge Function suite chạy bằng Deno với dependency auto
  install: 72 test pass, 0 fail. Lượt đầu dừng trước test logic vì thiếu local
  `npm:@types/node`; rerun với `--node-modules-dir=auto` giải quyết đúng lỗi môi
  trường.
- Deploy `gemini-vision-scan` bằng Management API bundling, không Docker; remote
  list xác nhận version 1 `ACTIVE`, `verify_jwt=false` theo config và secret
  names đầy đủ.
- Request không credential trả `401`. Authenticated JPEG smoke bằng demo user
  pass response contract, Free tier dùng `gemini-3.5-flash-lite`, ledger ghi
  `succeeded`; golden fixture kỹ thuật trả 0 từ nên chưa thay thế device smoke
  bằng ảnh thật.
- Logout session và xóa JPEG tạm pass. REST DELETE ledger bị `403` đúng theo
  hardening không cấp DELETE cho `service_role`; cleanup fail-closed qua
  Management API SQL xóa đúng một smoke row và REST re-read xác nhận còn 0 row.
- Xóa toàn bộ script provisioning/smoke/cleanup tạm. Production có 0 thao tác
  ghi, không deploy function và không thay đổi secret.

### 2026-09-05 — Staging demo Auth account provisioned and login verified

- Theo yêu cầu của chủ dự án, đọc đúng Auth identity và profile tối thiểu của
  demo account được chỉ định từ Production; Production có `0` thao tác ghi.
- Tạo identity tương ứng trên linked Staging, confirm email và xác nhận trigger
  đã tạo `public.users`; chỉ đồng bộ `display_name` và
  `onboarding_completed`.
- Password grant thật trên Staging trả đúng user/session; logout session kiểm
  thử pass. Auth Admin re-read xác nhận user tồn tại, email đã confirm và profile
  tồn tại.
- Email/mật khẩu, access/refresh token và API key chỉ tồn tại trong bộ nhớ tiến
  trình; không ghi vào source, `db_status.md` hoặc file tạm. Script provisioning
  tạm đã được xóa sau khi chạy.
- Không sao chép media, scan, learning data, consent, subscription hoặc billing.
  Chưa thao tác đăng nhập/consent trên Android device trong increment này.

### 2026-09-05 — Staging demo login failure diagnosed read-only

- Xác minh APK Android hiện tại là build Staging; truy vấn Auth Admin chỉ trên
  linked project đã kiểm tra đúng tên/trạng thái trả `total_users = 0` và
  `confirmed_users = 0`.
- Vì Staging không có user nào, credential demo thuộc project cũ/Production
  không thể đăng nhập vào build này dù email/mật khẩu đó vẫn đúng ở project gốc.
- Supabase trả `invalid_credentials` cho trường hợp này; client hiện ánh xạ mã
  đó thành “Mật khẩu không đúng”, nên thông báo chưa phân biệt được account
  không tồn tại với password sai và dễ gây hiểu nhầm.
- Không đọc/in email hay mật khẩu, không tạo/xóa user, không đổi Auth config và
  không truy vấn/thay đổi Production trong bước chẩn đoán.

### 2026-09-05 — Android v2 host and Staging device lifecycle smoke

- Theo application ID được chủ dự án duyệt, scaffold Android v2 embedding và
  đặt `namespace`/`applicationId` thành `com.capyvocab.app`; thêm INTERNET
  permission và giữ Web metadata hiện có.
- Mở rộng runner với target Android build/device, Staging/migration preflight,
  sync flag và cleanup dart-define file. Runner xóa/khôi phục biến `DEBUG` để
  Gradle không echo command chứa client credential.
- Android debug APK build, cài và launch pass trên CPH2375 Android 13; Supabase
  Staging initialize thành công. HOME/resume giữ cùng PID và log sau resume
  không có crash. APK rebuild sau fix cũng được cài lại và launch sạch.
- Smoke đầu tiên phát hiện `Uri.base.origin` ném `StateError` trên native
  `file:///`. Auth repository giờ chỉ dùng origin cho HTTP(S), omits redirect
  trên native; 6 auth tests pass, analyzer sạch và full suite pass 281 với một
  opt-in Staging test skip theo thiết kế.
- Build đầu trước hardening đã in Staging anon client credential trong local
  tool output do biến `DEBUG` toàn cục. Đây không phải service-role secret;
  không có credential trong source hoặc temp file còn lại. Dù vậy sự cố được
  ghi nhận và đường echo đã bị đóng.
- Device dừng ở Auth screen và báo không có network trong lifecycle command;
  chưa có authenticated consent-to-upload/outbox drain trên device. Worker
  upload thật vẫn chỉ được chứng minh bởi Staging E2E đã cleanup.
- Debug launch có startup frame skips và log codec riêng của OPPO; chưa chạy
  release/profile benchmark nên không kết luận hiệu năng sản phẩm.
- Production không linked/apply/reset/thay đổi.

### 2026-09-04 — Cloud-backup consent UI implemented; device smoke blocked

- Thêm Settings switch account-scoped đọc trực tiếp `local_accounts`; mặc định
  OFF, disable khi logout/loading, có retry khi SQLite stream lỗi.
- Bật backup bắt buộc dialog nói rõ ảnh + dữ liệu của bài quét mới được upload
  private, local copy vẫn dùng offline, bài cũ chưa backfill và cloud consent
  không phải consent train AI. Tắt upload không tự purge dữ liệu cloud.
- Thêm controller bootstrap account fail-closed bằng insert-ignore, ghi
  `consent_events` với old/new, `privacy-v1`, source action, UTC timestamp và
  enforcement `applied`; hai consent AI còn lại không bị thay đổi.
- Tách secure UUID v4 generator thành core utility dùng chung; consent không
  phụ thuộc module Gemini và request ID scan giữ nguyên contract.
- `SupabaseService` nhận `SUPABASE_URL`/`SUPABASE_ANON_KEY` từ dart-define với
  ưu tiên cao hơn `.env`; runner Staging chỉ đưa anon key vào build file tạm và
  luôn xóa file trong `finally`.
- Targeted consent/Settings tests pass 13/13; full analyzer sạch; full Flutter
  suite pass 279 với 1 opt-in live test skip; live Staging worker E2E pass và
  cleanup pass. Production không linked/apply/reset/thay đổi.
- Device smoke chưa hoàn tất: `flutter devices` chỉ có Windows/Chrome/Edge,
  không có Android/iOS emulator; Windows host không được cấu hình. Android APK
  build dừng với `use of deleted Android v1 embedding` vì repo chỉ còn Gradle
  wrapper/GeneratedPluginRegistrant và thiếu Android v2 scaffold. Chưa tự chọn
  application ID để tránh khóa sai định danh phát hành.
- Mobile audit script báo các regex warning/issue trên kích thước icon/font có
  sẵn; consent control dùng `SwitchListTile.adaptive` với toàn hàng là touch
  target, nên không xác nhận đây là lỗi touch target của switch.

### 2026-09-04 — Real Library worker E2E passed on Staging

- Thêm opt-in live test chạy chính `SqliteLibraryStore`,
  `LibrarySyncWorker` và `SupabaseLibrarySyncGateway`; full test bình thường
  skip nên không vô tình ghi cloud.
- Thêm PowerShell runner fail-closed: xác minh linked Staging/name/health, tối
  đa hai active project, migration dry-run up to date và không in/commit key.
- Tạo Auth owner tạm, local SQLite aggregate + hai JPEG thật; 5/5 operation
  hoàn tất, private owner download, SHA-256 ảnh/JSON và 5 nhóm normalized
  row/raw JSON pass.
- Deterministic cleanup target được ghi trước network write; teardown luôn thử
  đủ mọi bước. Storage object, row và test user cleanup assertions pass trên bốn
  live run.
- Lần chạy đầu dừng trước mutation vì PowerShell 5.1 nested JSON array; parser
  được sửa bằng `ConvertFrom-Json -InputObject`, không hạ điều kiện an toàn.
- Full analyzer sạch; default Flutter suite pass 273 với 1 opt-in live test
  skipped. Production không linked, không apply/reset/thay đổi.

### 2026-09-04 — M3C runtime sync and offline startup locally verified

- Bỏ `SupabaseHealthGate`/remote preflight khỏi bootstrap để mất mạng không chặn
  SQLite, ảnh local và giao diện ôn tập.
- Nối coordinator vào auth session, consent/outbox stream, app resume và SQLite
  `next_attempt_at`; logout/consent OFF hủy lịch.
- Thêm native app-documents media resolver và Web fail-closed factory.
- Đặt toàn bộ runtime sync sau `LIBRARY_SYNC_ENABLED`, mặc định `false`, để
  không vô tình ghi Production trước migration/backfill.
- Targeted runtime/worker/SQLite/startup suite pass 23/23; full analyzer sạch,
  Flutter suite pass 273/273 và Web build với cờ bật thành công.
- Self-review bổ sung generation guard để auth event đồng thời không giữ
  subscription owner cũ; regression owner-switch pass.
- Chưa chạy worker E2E trên Staging, chưa thêm consent UI, không apply hoặc thay
  đổi Staging/Production trong increment này.
- Ghi nhận residual risk: profile query lỗi sẽ ưu tiên local access và có thể
  đưa account mới vào Home; cần local onboarding cache để phân biệt chính xác.
- Ghi nhận một full-test run báo 1 failure không xác định do output bị cắt; hai
  full rerun liên tiếp pass 273/273, chưa có bằng chứng đây là hồi quy M3C.

### 2026-09-04 — M3B outbox worker implemented and locally verified

- Thêm `LibrarySyncSource`, SQLite owner-scoped loaders, auth unblock và phục
  hồi operation `running` bị gián đoạn.
- Thêm bounded outbox worker với consent/auth gate, deterministic exponential
  backoff, error state `retry/blocked/done` và contract fail-closed.
- Thêm native Supabase gateway map đủ 5 M3A entity; media upload trước, metadata
  upsert sau, rồi mới ghi remote path/sync status vào SQLite.
- Siết dependency Photo Note để chờ toàn bộ detection/annotation evidence.
- Permanent purge chỉ hoàn tất tombstone sau remote delete thành công.
- Targeted M3B + SQLite + Storage test pass 20/20; targeted analyzer sạch.
- Full regression sau cùng: analyzer sạch và Flutter suite pass 267/267.
- Chưa nối scheduler/app lifecycle, chưa chạy worker E2E trên Staging và không
  apply/thay đổi Production.
- Self-review xác nhận `SupabaseHealthGate` hiện vẫn chặn offline app startup;
  ghi thành blocker M3C, không tuyên bố offline end-to-end đã hoàn tất.

### 2026-09-03 — Baseline + M3A verified on Staging

- Khôi phục schema gốc 15 bảng từ commit khởi tạo thành migration baseline
  `20260725204011_initial_schema.sql`; không sao chép dữ liệu Production.
- Thêm static contract test bắt buộc baseline là migration đầu tiên và không
  chứa các bảng được tạo ở migration sau.
- Dry-run xác nhận 20 migration theo đúng thứ tự; `db push` apply thành công
  toàn bộ trên Staging. Migration list local/remote khớp 20/20 và dry-run sau
  apply trả `upToDate=true`.
- `inspect db table-stats` xác nhận 21 bảng public đã tồn tại.
- Runtime hai user: owner row insert `201`, cross-user row read rỗng,
  cross-user row insert `403`, owner media upload `200`, cross-user media
  upload/read bị chặn, owner signed URL pass, bucket private và cleanup pass.
- Lần chạy runtime đầu báo false failure vì PowerShell bọc JSON `[]` thành mảng
  lồng; kiểm tra được sửa sang raw JSON và pass. Không có bằng chứng RLS leak.
- Production không bị apply/reset/thay đổi dữ liệu.
- Regression sau cùng: `flutter analyze --no-pub` sạch và full Flutter suite
  pass 260/260.

### 2026-09-03 — Free remote staging restored and linked

- Theo phê duyệt của chủ dự án, tái sử dụng project inactive làm Staging với
  điều kiện không phát sinh phí.
- Xác minh organization plan là `free` qua Management API và chỉ có một project
  active trước restore; restore tạo đúng project active thứ hai.
- Restore thành công tới `ACTIVE_HEALTHY`; repo đã đổi link từ Production sang
  Staging. Production không bị apply/reset/thay đổi dữ liệu.
- `supabase migration list --linked`: Staging có 0 migration remote và 19
  migration local-only.
- `supabase inspect db table-stats --linked`: không có bảng public.
- `supabase db push --linked --dry-run`: pass, dự kiến 19 migration; không push
  vì thiếu baseline schema mà migration đầu tiên phụ thuộc.
- Có một request restore ban đầu bị API từ chối do project ref không hợp lệ;
  không tạo side effect. Request sau dùng scalar/fail-fast validation và thành
  công.

### 2026-09-03 — Remote staging preflight không Docker

- Xác nhận project đã có Supabase CLI 2.116.0 và CLI session hợp lệ; không cần
  cài thêm dependency.
- Liệt kê project và migration history bằng thao tác read-only.
- Project active đang link chưa được xác nhận là staging nên không chạy push.
- Phát hiện migration drift: 4 remote-only, 5 local-only; yêu cầu reconcile
  trước khi dry-run/apply để tránh vô tình đẩy migration ngoài M3A.
- Không thay đổi Supabase remote trong preflight.
- Tạo staging mới đã được yêu cầu, nhưng thao tác create đang chờ xác nhận cho
  phép compute charge nếu organization là paid và cho phép CLI sinh password
  mạnh, dùng để create/link mà không in hoặc commit secret.

### 2026-09-03 — D2/D3 approved, M3A implemented in source

- Ghi nhận phê duyệt D2/D3 trực tiếp từ chủ dự án.
- Thêm additive Supabase migration cho normalized Library evidence, owner RLS
  và private `photo_notes` bucket.
- Đồng bộ schema snapshot; thay public URL/timestamp key bằng deterministic
  private object path và signed URL có hạn trong Flutter Storage service.
- Thêm unit/static contract tests. Migration chưa apply Production và runtime
  outbox upload chưa được nối; các phần này không được ghi là đã hoạt động.
- Verification: analyzer sạch, 7/7 M3A tests và 259/259 full tests pass, Web
  build pass; SQL runtime chưa chạy do môi trường thiếu Supabase CLI/PostgreSQL.

### 2026-09-03 — M3 cloud contract audit

- Audit `SyncRepository`, SQLite outbox, `StorageService`, Supabase
  `photo_notes` schema và Storage policies.
- Xác nhận outbox local đã có dependency/state transition nhưng chưa có worker.
- Phát hiện bucket/policy/service cũ không đạt private owner isolation; đánh
  dấu Supabase upload `BLOCKED` cho đến khi D2/D3 được phê duyệt và M3A thay
  contract này.
- Không upload hoặc thay đổi Production Supabase trong audit này.

### 2026-09-03 — Khởi tạo DB status sau M2C

- Tạo source of truth riêng cho database/storage để các phiên sau không phải
  suy luận lại từ lịch sử chat.
- Ghi nhận local JPEG + raw Gemini JSON + normalized aggregate đã hoạt động ở
  native và được kiểm thử.
- Ghi rõ Supabase upload/sync worker, Storage UI và on-device trainer chưa được
  triển khai.
- Ghi nhận D1 đã duyệt; D2–D10 vẫn pending.
- Baseline verification: analyzer sạch, 252/252 test pass, Web build pass.
