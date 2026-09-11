# M3B — Library outbox sync worker

Status: **IMPLEMENTED / LOCAL VERIFIED — chưa nối scheduler, chưa apply Production**

## Phạm vi đã triển khai

- Worker xử lý tuần tự và giới hạn số operation mỗi lần chạy.
- Kiểm tra `cloud_backup_enabled` trước mọi đọc/upload cloud; consent OFF không
  đổi trạng thái outbox.
- Kiểm tra authenticated Supabase user đúng owner; thiếu session chuyển
  operation sang `blocked/auth_required`, đăng nhập lại cùng owner sẽ release.
- Dependency mới bảo đảm thứ tự media → scan → detection/annotation → Photo
  Note.
- Media dùng two-phase flow: upload các variant bằng object key cố định, upsert
  `media_assets`, sau đó mới ghi remote path/sync status về SQLite.
- Nếu upload đã thành công nhưng metadata commit lỗi, retry upload lại đúng key
  với `upsert`, không tạo object mới.
- Operation `running` quá 15 phút được phục hồi thành `retry` sau app restart.
- Backoff xác định bắt đầu 5 giây, nhân đôi và chặn trần 6 giờ.
- Permanent-delete chỉ đánh dấu tombstone complete sau khi remote delete thành
  công.
- Các entity chưa có M3A cloud table (`album`, relation, learning, SRS) bị
  `blocked/cloud_entity_contract_missing`; worker không tự đoán schema.

Outbox cũ có `payload_json = {}` vẫn chạy được vì worker đọc snapshot mới nhất
từ SQLite theo owner/entity ID. Absolute local path không được đưa vào Supabase
row; native gateway nhận một resolver để đổi relative app path thành `File` tại
biên thiết bị.

## Chưa thuộc M3B

- App lifecycle/network scheduler tự gọi worker.
- Toggle/UI cho cloud-backup và luồng enforcement hoàn chỉnh.
- Staging end-to-end dùng worker thật với file thật; M3A RLS/Storage đã được test
  riêng với hai user.
- Production migration/backfill legacy public URL.
- Web media resolver và Web scan persistence.
- Multi-device conflict/version merge.

## Verification 2026-09-04

```text
flutter test --no-pub
  test/features/library/application/library_sync_worker_test.dart
  test/features/library/data/local/sqlite_library_store_test.dart
  test/core/services/storage_service_test.dart
  -> 20/20 pass

flutter analyze --no-pub
  lib/features/library
  test/features/library/application/library_sync_worker_test.dart
  -> No issues found

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter compact
  -> 267/267 pass
```

Test cases gồm full dependency drain, offline/transient retry, metadata failure
sau upload, deterministic replay, restart recovery, consent OFF→ON, logout/login
auth unblock và remote purge/tombstone completion.
