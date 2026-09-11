# M2A SQLite Spike — Library Offline-first

> Ngày chạy: 2026-09-02  
> Trạng thái: **D1 APPROVED — VM PASS, WEB BUILD PASS, WEB RUNTIME TEST BLOCKED**  
> Phạm vi: schema v2 đã được scanner native dùng chung; Library UI chưa nối.

## 1. Mục tiêu

Kiểm chứng phương án ít thay đổi nhất: tiếp tục dùng họ `sqflite` hiện có cho
local source of truth, với schema versioned và `DatabaseFactory` được inject để
chạy SQLite thật trong unit/integration test.

Spike phải trả lời được:

- Schema M0 có biểu diễn được trên SQLite không.
- Transaction có rollback đồng thời aggregate và outbox không.
- Foreign key có chặn liên kết chéo tài khoản không.
- Raw scan evidence và LearningEvent có bảo vệ bất biến cần thiết không.
- Migration từ database version 1 có giữ nguyên `scan_results` không.
- Test database có chạy được trên Windows/Dart VM không cần thiết bị thật không.

## 2. Dependency decision

- Runtime giữ nguyên `sqflite 2.4.2+1` đang khóa trong project.
- Test thêm `sqflite_common_ffi 2.4.0+3` dưới `dev_dependencies`.
- Web dùng `sqflite_common_ffi_web 1.1.1`, `sqlite3.wasm` và
  `sqflite_sw.js`; bản 1.1.2 yêu cầu Dart 3.12 trong khi toolchain hiện tại là
  Dart 3.11.
- Không chọn bản `2.4.2+1` vì bản đó yêu cầu Dart 3.12, trong khi project hiện
  dùng Dart 3.11.
- Package thuộc cùng hệ sinh thái sqflite, dùng giấy phép BSD-2-Clause và được
  mô tả chính thức cho desktop/unit tests.

Không thêm ORM, code generator hoặc runtime database thứ hai trong M2A.

## 3. Kết quả schema

Schema version 2 tạo 21 bảng, gồm:

- Nguồn legacy: `scan_results`, `legacy_scan_import_queue`.
- Account/consent: `local_accounts`, `consent_events`.
- Library evidence: `media_assets`, `scan_runs`, `photo_notes`,
  `vocab_detections`, `vocab_annotations`.
- Album: `albums`, `album_photo_notes`.
- Learning: `learning_events`, `srs_progress`.
- Sync: `sync_operations`, `sync_tombstones`.
- ML lineage: `training_examples`, `dataset_manifests`,
  `dataset_manifest_examples`, `model_versions`, `training_runs`,
  `training_run_examples`.

Các constraint đã chạy thật:

- Composite foreign key chặn Photo Note của user B tham chiếu media user A.
- Scan `succeeded` bắt buộc có raw JSON và SHA-256.
- Trigger chặn sửa raw evidence sau khi đã ghi.
- Trigger chặn update LearningEvent.
- Training example không eligible chỉ được nằm ở split `excluded`.
- Non-SRS training example bắt buộc có detection hoặc annotation provenance.
- Consent audit fields bất biến; chỉ enforcement state được phép tiến triển.
- Mỗi user/task chỉ có tối đa một model ở trạng thái `active`.
- Transaction lỗi outbox rollback cả MediaAsset và PhotoNote trước đó.

## 4. Migration version 1 → 2

Migration không backfill thẳng legacy row sang entity mới vì `scan_results`
không có `user_id`. Tự tạo owner sẽ có nguy cơ gắn dữ liệu cho sai tài khoản.

Thay vào đó:

1. Giữ nguyên bảng và toàn bộ row `scan_results`.
2. Tạo một row `pending` trong `legacy_scan_import_queue` cho mỗi legacy ID.
3. Không parse hoặc sửa `vocab_json` trong schema migration.
4. Row JSON lỗi vẫn được bảo toàn để importer M2B quarantine riêng.
5. Queue dùng `INSERT OR IGNORE`, nên mở database nhiều lần không nhân bản.

Importer M2B chỉ được chạy sau khi xác định account owner và chính sách logout.

## 5. Kết quả kiểm thử và đo

| Check | Kết quả |
| --- | --- |
| Tạo schema version 2 | Pass |
| `PRAGMA foreign_keys = ON` | Pass |
| Upgrade v1 → v2 | Pass |
| Legacy rows byte-for-byte theo field | Pass |
| Queue migration idempotent | Pass |
| Transaction rollback | Pass |
| Raw evidence immutable | Pass |
| LearningEvent không update | Pass |
| 200 aggregate / 600 insert trong một transaction | 136–262 ms, Windows FFI |

Khoảng đo trên chỉ là baseline máy phát triển, không phải cam kết hiệu năng
Android/iOS. Benchmark thiết bị thật vẫn bắt buộc trước production rollout.

## 6. Kết quả M2A-Web và quyết định D1

D1 được chủ dự án duyệt ngày 2026-09-02. `flutter build web` thành công và đầu
ra chứa cả worker lẫn WASM. Adapter dùng cùng `LibraryDatabase` và schema v2;
test browser kiểm tra close/reopen qua IndexedDB đã được thêm.

Test browser chưa thể xác nhận trên máy này: `flutter test --platform chrome`
treo ở pha loading trước khi chạy cả một smoke test rỗng. Đây là khoảng trống
môi trường, không được ghi nhận là runtime pass. Rollback đã chốt là tắt Web
Library persistence nhưng giữ native M2B và không downgrade/xóa DB.

Các việc vẫn chưa được duyệt/kiểm chứng:

- Benchmark Android/iOS thiết bị thật.
- Crash recovery giữa media file commit và DB transaction.
- D2, D4, D9, D10 cho media/Web/retention/logout.
