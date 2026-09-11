# M2B — SQLite Repository cho Library Offline/ML

> Ngày triển khai: 2026-09-02  
> Trạng thái: **IMPLEMENTED VÀ PASS TRÊN SQLITE FFI**  
> Gate: D1 approved; D2–D10 vẫn pending.

## Phạm vi đã triển khai

- `LibrarySqliteCodec` ánh xạ toàn bộ entity M1 sang schema SQLite v2 và ngược
  lại, gồm JSON, UTC timestamp, enum snake_case, nullable và bounding box.
- `SqliteLibraryStore` triển khai sáu contract: Library, Album, Learning, Sync,
  Training và Consent trên một database/transaction boundary.
- Aggregate Photo Note lưu nguyên tử MediaAsset, raw ScanRun, Detection,
  Annotation, PhotoNote và outbox dependency chain.
- Khi `cloud_backup_enabled = 0`, không sinh cloud operation. Khi đã consent,
  outbox đi theo thứ tự media → scan → detection → annotation; PhotoNote phụ
  thuộc media và scan.
- LearningEvent là append-only; SRS progress dùng owner-scoped upsert.
- Dataset manifest và training run lưu cùng relation links trong transaction;
  lineage truy ngược source → example → run → model.
- Yêu cầu xóa vĩnh viễn hiện chỉ tạo tombstone, loại training example và
  invalidate model liên quan. Không physical-delete khi D9 chưa được duyệt.
- Consent event cập nhật materialized flag và audit row trong cùng transaction,
  đồng thời kiểm tra `oldValue` để chặn ghi từ màn hình stale.
- Upsert entity quan trọng không được đổi owner hoặc `created_at`.

## Tương thích scan_results v1

`ScanResultLocalDataSource` native không còn tự mở `capy_vocab.db` version 1.
Nó dùng một `SqliteLibraryStore` dùng chung trên database version 2. Kể từ M2C,
scan mới ghi legacy row, queue row ở trạng thái imported và aggregate chuẩn
MediaAsset/ScanRun/VocabDetection/PhotoNote trong cùng một transaction.

`LegacyScanImportQueue`:

- chỉ liệt kê raw candidate, không tự gán owner;
- chỉ đánh dấu imported khi MediaAsset và ScanRun đã tồn tại và cùng owner được
  caller chỉ định;
- cho phép quarantine JSON lỗi mà vẫn giữ nguyên raw `scan_results`;
- không auto-import absolute `local_path`, vì media retention/path migration và
  logout ownership còn phụ thuộc D2/D10.

## Verification

| Check | Kết quả |
| --- | --- |
| M2B SQLite integration | 8/8 pass |
| M2A/M2B + scanner regression subset | 18/18 pass trước increment cuối |
| Toàn bộ Flutter test suite | 250/250 pass |
| `flutter analyze` toàn repository | No issues found |
| `flutter build web` | Pass; worker và WASM có trong output |
| IndexedDB close/reopen trên Chrome | Chưa chạy được; Chrome test runner treo trước test body |

Integration test bao phủ round-trip offline, tenant scope, transaction rollback,
consent gating, outbox dependencies, album non-cascade, append-only learning,
SRS, sync state/dependency, training lineage/invalidation và legacy queue owner
verification.

## Phần chưa nối/chưa được phép tự quyết

- Storage/Library UI chưa dùng repository mới.
- Web scan vẫn dùng memory store; D4 chưa duyệt và Web media hiện chưa durable.
- Không auto-convert các legacy row lịch sử không có owner sang normalized
  aggregate; scan mới đã được normalize trực tiếp từ M2C.
- Không quyết định giữ/xóa ảnh gốc, quota, trash TTL, logout purge hay label
  eligibility policy.
- Sync worker/Supabase upload, media two-phase commit và on-device trainer thuộc
  milestone sau.
