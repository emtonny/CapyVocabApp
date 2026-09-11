# M3C — Library runtime sync và offline startup

Status: **IMPLEMENTED / STAGING + ANDROID ONLINE/OFFLINE VERIFIED — runtime mặc định tắt**

## Phạm vi đã triển khai

- Bỏ network health preflight khỏi bootstrap. App không còn chặn toàn bộ UI khi
  Supabase tạm thời không truy cập được.
- Session đã lưu có thể đi vào app khi truy vấn
  `users.onboarding_completed` lỗi do offline. SQLite và media app-private vẫn
  có thể được đọc; đây là fallback cho session cũ, không thay thế cache trạng
  thái onboarding lâu dài.
- `LibrarySyncRuntime` theo dõi authenticated user và app lifecycle. Login,
  thay đổi outbox/consent và app resume đều có thể đánh thức coordinator.
- `LibrarySyncCoordinator` chỉ drain outbox/pull khi cloud backup consent đang
  bật và Android báo có mạng đã được xác thực. Offline không phát HTTP request;
  retry nền backoff 30 giây theo cấp số nhân tới tối đa 15 phút. Thành công hoặc
  đổi user reset failure count; logout/consent OFF hủy lịch phù hợp.
- Native resolver đổi đường dẫn tương đối `capy_scans/...` thành file trong app
  documents directory. Absolute local path không được gửi lên Supabase.
- Web dùng factory fail-closed và không mở SQLite/native file gateway cho sync.
- Runtime sync nằm sau compile-time flag `LIBRARY_SYNC_ENABLED`; mặc định là
  `false` để bản build đang trỏ Production không vô tình dùng M3A khi migration
  Production chưa được áp dụng.

## Luồng runtime

```text
app bootstrap
  -> initialize Supabase client từ cấu hình local
  -> render app ngay, không gọi remote health gate
  -> session/auth event
       -> LibrarySyncRuntime chọn owner
       -> coordinator theo dõi consent + outbox count
       -> consent ON và có operation
            -> worker drain dependency graph
            -> retry theo SQLite next_attempt_at nếu remote tạm lỗi
  -> app resumed
       -> trigger drain lại

offline / Supabase unreachable
  -> UI và local Library không bị chặn
  -> scan/media/JSON tiếp tục nằm trong SQLite + app-private files
  -> Android offline gate chặn drain/pull trước HTTP, không log host lookup
  -> outbox giữ retry state cho lần có kết nối sau
```

## Cách bật có kiểm soát

Chỉ bật cho một build đã xác nhận đang dùng Staging. URL và anon key có thể
được truyền cùng cờ sync mà không sửa `.env`:

```text
flutter run \
  --dart-define=SUPABASE_URL=https://<staging-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging-anon-key> \
  --dart-define=LIBRARY_SYNC_ENABLED=true
```

Không bật cờ cho Production trước khi migration M3A, legacy media backfill,
signed-URL reader và rollback plan được review/apply. Cờ này không thay đổi
Supabase URL; môi trường build vẫn quyết định project đích.

## Verification 2026-09-04

```text
flutter test --no-pub
  test/features/library/application/library_sync_coordinator_test.dart
  test/features/library/application/library_sync_worker_test.dart
  test/features/library/data/local/sqlite_library_store_test.dart
  test/core/startup_offline_contract_test.dart
  test/widget_test.dart
  -> 23/23 pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter compact
  -> 273/273 pass

flutter build web --no-pub --dart-define=LIBRARY_SYNC_ENABLED=true
  -> pass; Web sync factory trả null như thiết kế
  -> còn cảnh báo không chặn từ flutter_tts Wasm dry-run và CupertinoIcons

tool/run_staging_library_sync_e2e.ps1
  -> preflight xác nhận linked Staging ACTIVE_HEALTHY và migration up to date
  -> chính SqliteLibraryStore + LibrarySyncWorker + Supabase gateway pass 1/1
  -> 5/5 outbox operation done
  -> 2 JPEG thật upload/download được qua private owner session
  -> media, scan raw JSON, detection, annotation và Photo Note đọc lại đúng
  -> SHA-256 ảnh và raw JSON cloud khớp dữ liệu local thật
  -> Storage objects, 5 nhóm row và test user cleanup pass
  -> pass bốn lượt; không gọi Gemini và không thay đổi Production

flutter test --no-pub --reporter compact
  -> 279 pass, 1 opt-in live test skipped theo thiết kế

flutter test --no-pub
  test/features/settings/cloud_backup_consent_provider_test.dart
  test/features/settings/settings_screen_test.dart
  -> 13/13 pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> Staging preflight pass, migration up to date
  -> Android debug APK build pass với sync flag bật

tool/run_staging_device_smoke.ps1 -Target android-device -DeviceId 665fdb60
  -> cài và launch `com.capyvocab.app` trên CPH2375 / Android 13
  -> Supabase Staging initialize pass; background/resume giữ cùng process
  -> smoke ban đầu bắt lỗi native `Uri.base.origin`; fix omits redirect cho
     `file:` URI, hot restart và lifecycle log sau fix không còn exception
  -> device chưa có authenticated session/consent nên chưa chứng minh outbox
     được drain từ app

flutter test --no-pub --reporter expanded --concurrency=4
  -> 281 pass, 1 opt-in Staging test skipped theo thiết kế
```

Test coordinator bao phủ consent/outbox trigger, retry timer không phụ thuộc
package mới, validated-network offline gate, exponential backoff, logout hủy
lịch, unexpected-error retry và auth owner-switch đồng thời. Startup contract bảo vệ việc không gọi
`testConnection`/`SupabaseHealthGate` và giữ rollout flag mặc định tắt.

Một lượt full compact ngay sau khi thêm owner-switch test từng báo 1 failure;
output song song bị cắt nên không giữ được tên test. Hai lượt full suite kế tiếp
(expanded fail-fast và compact) đều đạt 273/273. Đây được giữ như tín hiệu
flakiness cần theo dõi, không được coi là lỗi đã xác định nguyên nhân.

## Verification bổ sung 2026-09-11

- Test coordinator 9/9 pass, gồm offline gate không drain/pull/report lỗi và
  backoff tăng 1x→2x; toàn Library 104 pass + 1 live skip; full suite 345 pass +
  1 live skip; analyzer sạch.
- APK Staging sync-enabled build pass sau migration dry-run `upToDate=true`.
  `adb install -r` giữ nguyên checksum SQLite và JPEG app-private.
- CPH2375 cold-start với Wi-Fi/mobile data OFF trong 6,963 ms; Home→Library→
  detail vẫn mở ảnh local + 4 từ. Qua hơn 30 giây không có
  `Failed host lookup`, RPC pull, stack trace hoặc Android runtime error.
- Wi-Fi/mobile data được khôi phục sau smoke. Không đổi schema, migration,
  consent, ML lineage hoặc Production.

## Consent UI đã nối

- Settings đọc account-scoped consent từ SQLite và giữ mặc định OFF.
- Opt-in cần xác nhận rõ; cloud backup không suy ra local-personalization hoặc
  federated/on-device-training consent.
- Bật switch chỉ áp dụng tự động cho bài quét mới; không backfill âm thầm.
- Khi consent đang ON, action **Sao lưu bài đã có** yêu cầu confirm riêng rồi
  enqueue graph cho active owner note chưa sync. App kiểm tra đủ các rendition
  local cần upload, bỏ qua missing/Trash, không upload lại media đã ở cloud và
  báo số bài được xếp.
- Tắt consent chặn upload tiếp theo nhưng không tự purge bản cloud hiện có.

## Phần còn lại sau Android startup/lifecycle smoke

- Native network gate tương đương cho platform ngoài Android nếu sau này bật
  Library sync tại đó; Web factory hiện vẫn fail-closed.
- Web scan/media persistence parity, multi-device conflict và Production
  migration/backfill.

## Live-test entry points

- `test/features/library/data/remote/library_sync_staging_e2e_test.dart`
- `tool/run_staging_library_sync_e2e.ps1`
- `tool/run_staging_device_smoke.ps1`

Test mặc định bị skip. Runner lấy credential client tạm qua Supabase CLI, ghi
dart-define vào file tạm và xóa trong `finally`; runner từ chối nếu linked project sai
tên/trạng thái, có migration drift hoặc có hơn hai project active trong cùng
organization. Runner xóa/khôi phục biến `DEBUG` quanh Flutter command để Gradle
không echo dart-defines. Một build đầu tiên đã in Staging anon client credential
do biến `DEBUG` toàn cục; không phải service-role secret, không lưu vào source
hoặc file tạm sau run, và đường log này đã được đóng. Deterministic object key
được đăng ký cho teardown trước network
write đầu tiên để failure giữa two-phase upload vẫn có target cleanup. Teardown
luôn thử mọi bước xóa độc lập rồi mới báo lỗi, nên một lỗi Storage không ngăn
việc tiếp tục xóa row/Auth user.
