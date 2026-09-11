# M2C — Native scan persistence vào Library offline

> Ngày triển khai: 2026-09-03  
> Trạng thái: **IMPLEMENTED VÀ ĐÃ KIỂM THỬ TRÊN SQLITE FFI**  
> Phạm vi: Android/iOS/desktop native; Web vẫn dùng memory store.

## Kết quả

Sau khi Gemini trả kết quả thành công, luồng scan native lưu cùng một lần:

1. File JPEG đã nén trong thư mục ứng dụng `capy_scans/`.
2. Row tương thích cũ trong `scan_results`.
3. Aggregate chuẩn M2B trong SQLite gồm `media_assets`, `scan_runs`,
   `vocab_detections` và `photo_notes`.
4. Row `legacy_scan_import_queue` ở trạng thái `imported`, liên kết đúng
   MediaAsset và ScanRun vừa tạo.

Các row ở bước 2–4 nằm trong **một transaction SQLite**. Nếu bất kỳ insert hoặc
outbox operation nào lỗi, toàn bộ account mới, legacy row, queue row và
aggregate đều rollback. File ảnh được tạo trước transaction nên cơ chế dọn
orphan file khi DB commit lỗi vẫn thuộc D2.

## Dữ liệu được giữ để offline và ML về sau

- MediaAsset giữ đường dẫn tương đối, SHA-256, kích thước ảnh, số byte, nguồn
  camera/gallery và phiên bản preprocessing.
- ScanRun giữ request ID, provider/model/tier, thời gian chạy, schema version,
  raw JSON response trước client ranking và SHA-256 của response.
- VocabDetection giữ từ gốc, từ chuẩn hóa, phiên âm, nghĩa tiếng Việt,
  part-of-speech, bounding box chuẩn hóa và thứ tự hiển thị.
- PhotoNote giữ owner, media/scan relation, tiêu đề và template được chọn.
- Dự đoán AI **không** được tự tạo thành `vocab_annotations` hoặc
  `training_examples`. Chỉ nhãn người dùng xác nhận mới được phép đi vào
  training dataset ở milestone sau.

Với account lần đầu thấy trên thiết bị, các consent flag mặc định fail-closed:
cloud backup, local personalization và federated contribution đều tắt. Nếu
account đã tồn tại, insert kiểu `ignore` giữ nguyên consent hiện tại.

## Ranh giới chưa triển khai

- Chưa upload ảnh hoặc JSON/aggregate lên Supabase.
- Chưa có sync worker xử lý outbox và retry.
- Chưa có media two-phase commit, orphan cleanup, quota hay retention policy.
- Chưa import tự động các `scan_results` lịch sử không có owner.
- Chưa có UI Library đọc repository này và chưa có on-device trainer.
- Web scan vẫn chỉ lưu trong memory; SQLite WASM repository có nhưng scan Web
  chưa được nối vì media durable storage trên Web chưa được quyết định.

Do đó M2C đáp ứng mục tiêu **scan mới có thể xem/luyện offline từ dữ liệu local
ở tầng repository**, nhưng chưa thể tuyên bố đồng bộ Supabase hoặc trải nghiệm
Storage UI end-to-end cho tới các milestone tiếp theo.

## Verification

| Check | Kết quả |
| --- | --- |
| M2C aggregate + stream + raw evidence | Pass |
| M2C rollback account/legacy/aggregate/outbox | Pass |
| Toàn bộ Flutter test suite | 252/252 pass |
| `flutter analyze --no-pub` | No issues found |
| `flutter build web --no-pub` | Pass |

Web build còn cảnh báo không chặn từ `flutter_tts` khi Wasm dry-run và thiếu
font CupertinoIcons; đây là cảnh báo có sẵn, không phát sinh từ M2C.
