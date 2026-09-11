# M3A — Supabase cloud schema và private media contract

> Ngày triển khai: 2026-09-03  
> Trạng thái: **IMPLEMENTED, STAGING + PRODUCTION VERIFIED**  
> Gate: D2 và D3 được chủ dự án duyệt ngày 2026-09-03.

## Phạm vi đã triển khai

- Phần database của migration là additive: tạo `media_assets`, `scan_runs`, `vocab_detections` và
  `vocab_annotations` trên Supabase.
- `photo_notes` cũ được mở rộng bằng media/scan relation, `updated_at`,
  `deleted_at` và `sync_version`; dữ liệu cũ không bị tự chuyển hoặc xóa.
- Owner-composite foreign key ngăn entity của user này tham chiếu evidence của
  user khác.
- Raw Gemini response dùng `jsonb`; request ID unique theo user để chuẩn bị
  idempotent retry ở M3B.
- RLS cho toàn bộ normalized tables dùng cả `USING` và `WITH CHECK` theo
  `auth.uid()`.
- Bucket `photo_notes` được chuyển sang private; SELECT/INSERT/UPDATE/DELETE
  chỉ cho object có segment đầu bằng `auth.uid()`.
- Flutter Storage service không trả public URL. Upload trả object path xác định
  dạng `{userId}/{mediaAssetId}/{variant}.{extension}`; URL đọc là signed URL
  có thời hạn.

## D2/D3 đã duyệt

- Luôn giữ local display/model-input khi Photo Note còn active.
- Original chỉ giữ khi user opt-in và còn quota.
- Cloud backup mặc định OFF và chỉ chạy sau explicit opt-in.
- Cloud media luôn private theo account, không dùng public URL.
- Khi tắt backup, không xóa cloud âm thầm; phải hỏi user trước khi purge.
- Media recovery/orphan cleanup sẽ được triển khai cùng M3B/M4.

## Trạng thái Production rollout

- M3A và M4.5 đã được apply vào Supabase Production sau explicit Gate 3
  approval ngày 2026-09-11; migration history hiện khớp 21/21 và dry-run
  up-to-date.
- Audit read-only ngày 2026-09-11 xác nhận Production có `0` Photo Note và `0`
  object trong bucket, nên hiện không có dữ liệu legacy cần backfill.
- Production hiện có normalized tables/change feed và bucket `photo_notes`
  private; final audit có 0 product row/object vì fixture đã cleanup.
- Sau explicit approval ngày 2026-09-11, migration ledger Production đã được
  repair để baseline + bốn version local canonical khớp schema thực tế; bốn
  remote alias được đánh dấu reverted trước Gate 3.
- Hai-user Production RLS/Storage runtime pass; full sync/upload/pull/purge E2E
  cũng pass và cleanup toàn bộ fixture.

Outbox worker, consent UI, runtime upload/pull, manual restore và purge đã được
triển khai, kiểm thử trên Staging/Android ở các milestone sau M3A. Chi tiết gate
history, pre-apply re-audit và rollback nằm tại
`docs/data/production_library_rollout.md`.

Việc đổi bucket từ public sang private là thay đổi hành vi có chủ đích. Gate 3
đã chạy sau kiểm kê 0 legacy row/object, backup/fingerprint/history reconcile
và rollback review. Build mặc định vẫn không bật sync; Production app rollout
là bước riêng.

## Verification

- 8 M3A/baseline contract tests pass trong full suite: deterministic owner/media
  object path, path traversal, extension/MIME boundary, signed URL TTL,
  normalized tables, raw JSON, owner FK, private bucket, bốn Storage policies,
  schema snapshot và baseline ordering.
- `flutter analyze --no-pub`: No issues found.
- Full Flutter suite: 260/260 pass.
- `flutter build web --no-pub`: pass; chỉ còn cảnh báo dependency/font đã biết.
- Baseline + 19 migration apply thành công trên Staging; migration history khớp
  20/20 và dry-run sau apply báo remote up to date.
- Staging runtime test với hai authenticated user: owner row insert/media upload
  và signed URL pass; cross-user row read trả rỗng, row insert bị `403`, Storage
  read/upload bị chặn; bucket private và cleanup pass.
- Production Gate 3: full SQLite worker upload/pull/purge pass; hai-user owner/
  cross-owner row và Storage isolation pass; final audit 0 fixture row/object/
  Auth user, bucket private, schema present, history 21/21.

Migration: `supabase/migrations/20260903120000_add_library_cloud_storage_contract.sql`.
