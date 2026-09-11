# Kiến trúc Offline-first và ML-ready cho Thư viện

> Trạng thái: **DRAFT — chờ duyệt D1–D10**  
> Ngày lập: 2026-09-01  
> Phạm vi milestone: M0 — chốt data contract, nguồn sự thật, quyền riêng tư và vòng đời dữ liệu.  
> Tài liệu này không phải migration và không xác nhận tính năng đã được triển khai.

## 1. Mục tiêu

Thiết kế Thư viện để người dùng có thể xem ảnh, Album, từ vựng và ôn bài khi
không có mạng; khi kết nối trở lại, thay đổi được đồng bộ lên Supabase mà không
mất dữ liệu hoặc tạo bản ghi trùng. Dữ liệu được lưu từ hôm nay phải có đủ
provenance, version và consent để sau này tạo tập huấn luyện cho model cá nhân
trên thiết bị.

## 2. Hiện trạng được xác nhận từ source

- Native lưu JPEG trong thư mục ứng dụng và lưu kết quả scan vào bảng SQLite
  `scan_results`.
- Web dùng memory store; reload làm mất ảnh và record.
- `ScanResultStore` mới có thao tác `save`; chưa có list/read/update/delete.
- Luồng scan hiện không gọi `StorageService`, không đồng bộ Album theo user và
  không chuyển sang một Thư viện đã hoạt động.
- Supabase có bảng `photo_notes`, bảng nối `photo_note_vocabularies` và bucket
  `photo_notes`, nhưng contract hiện tại chưa biểu diễn Album, Trash, provenance
  đầy đủ hoặc dữ liệu ML.
- Startup hiện bị chặn nếu Supabase health check thất bại, vì vậy chưa đáp ứng
  yêu cầu mở Thư viện offline.

Nguồn đối chiếu chính:

- `../../lib/features/ai_scan/data/datasources/scan_result_local_datasource.dart`
- `../../lib/features/ai_scan/data/services/scan_image_storage_io.dart`
- `../../lib/features/ai_scan/data/services/scan_image_storage_memory.dart`
- `../../lib/features/ai_scan/presentation/providers/scan_provider.dart`
- `../../lib/core/services/storage_service.dart`
- `../../lib/main.dart`
- `../../supabase/schema/supabase_schema_final_secure.sql`
- `../scan_feature_handoff.md`

## 3. Phạm vi và ngoài phạm vi

### Trong phạm vi M0

- Nguồn sự thật local/cloud.
- Boundary giữa UI, local persistence, sync và ML dataset.
- Vòng đời Photo Note, media, annotation, event và model checkpoint.
- Decision log D1–D10.
- Rủi ro, migration guard và điều kiện chuyển sang M1/M2.

### Ngoài phạm vi M0

- Chọn hoặc thêm package database.
- Viết Dart entity/repository/provider.
- Tạo local migration hoặc Supabase migration.
- Thay đổi bucket, RLS hoặc startup gate.
- Xây UI Thư viện.
- Chạy inference/training model on-device.

## 4. Các invariant bắt buộc

1. UI chỉ đọc và ghi qua local repository; không query Supabase trực tiếp để
   render trạng thái chính.
2. Một thay đổi local thành công phải hiển thị ngay cả khi mất mạng.
3. Mọi entity đồng bộ dùng UUID ổn định do client tạo.
4. Raw ảnh và raw response AI là bằng chứng bất biến; normalize không được làm
   mất dữ liệu gốc.
5. Prediction AI không phải ground truth. Chỉnh sửa/xác nhận của người dùng được
   lưu thành annotation riêng.
6. Outbox được ghi trong cùng transaction với thay đổi nghiệp vụ.
7. Retry local/cloud phải idempotent.
8. Xóa Album không xóa Photo Note; quan hệ nhiều-nhiều dùng bảng nối.
9. Xóa vĩnh viễn phải xử lý cả local, cloud, training projection và checkpoint
   đã sử dụng dữ liệu đó.
10. Model không train trực tiếp từ bảng UI; chỉ train từ training projection có
    builder version, eligibility và dataset split.
11. User A không được đọc cache, media, event hoặc checkpoint của User B.
12. App phải mở được dữ liệu đã lưu khi không có mạng.

## 5. Kiến trúc mục tiêu

```text
Flutter UI / Riverpod
        |
        v
Domain repositories
        |
        +------------------------------+
        |                              |
        v                              v
Local structured store          Local media store
(source of truth cho UI)        (original/display/model-input)
        |                              |
        +---------------+--------------+
                        |
                        v
                 Transactional outbox
                        |
                 Sync coordinator
                        |
        +---------------+----------------+
        |                                |
        v                                v
Supabase PostgreSQL              Supabase private Storage
(cloud mirror/backup)            (media backup theo consent)

Local raw evidence + annotations + learning events
                        |
                        v
             Versioned dataset builder
                        |
                        v
          Eligible local training examples
                        |
                        v
      On-device trainer -> checkpoint -> evaluation -> activation/rollback
```

## 6. Nguồn sự thật theo loại dữ liệu

| Dữ liệu | Nguồn đọc của UI | Cloud | Tính chất |
| --- | --- | --- | --- |
| Photo Note, Album, Trash | Local DB | Mirror/backup | Mutable, có version/timestamp |
| Media dùng offline | Local file | Backup tùy consent | Content-addressable theo hash |
| Raw response AI | Local DB/file | Mirror | Append-only, bất biến |
| AI detection | Local DB | Mirror | Prediction, không phải ground truth |
| User annotation | Local DB | Mirror | User data, ưu tiên hơn AI |
| Learning event | Local DB | Append-only mirror | Không update record cũ |
| Sync operation | Local DB | Không mirror như entity nghiệp vụ | Hàng đợi kỹ thuật |
| Training example | Derived local store | Không upload mặc định | Có thể tái dựng |
| Personalized checkpoint | Local file | Không upload mặc định | Có base version và rollback |

## 7. Luồng hoạt động chuẩn

### 7.1 Scan online

1. Người dùng chọn/chụp ảnh.
2. Media pipeline ghi bản gốc/tạm và tính content hash.
3. Pipeline tạo display variant và model-input variant có version.
4. Client gửi model-input bytes kèm request ID tới Edge Function.
5. Client nhận raw JSON, lưu nguyên response và response hash.
6. Client normalize detections nhưng không ghi đè raw response.
7. Một local transaction tạo `media_asset`, `scan_run`, `photo_note`,
   `vocab_detection` và outbox operations.
8. Chỉ sau khi transaction commit, UI thông báo thành công và hiển thị note.
9. Sync chạy sau, không chặn UI.

Nếu file đã được ghi nhưng DB transaction thất bại, compensation xóa file. Nếu
app chết giữa hai bước, startup orphan sweeper đối chiếu manifest với DB.

### 7.2 Mở và ôn bài offline

1. App khởi tạo local account context và local DB trước network.
2. Thư viện đọc Photo Note/Album/Trash từ local query.
3. Ảnh ưu tiên display file local.
4. SRS và mini-game đọc vocabulary local.
5. Kết quả học được ghi thành append-only learning event và update local SRS.
6. Outbox giữ các thay đổi chờ sync.

Không có mạng thì không tạo scan Gemini mới, nhưng mọi nội dung đã lưu và hoạt
động ôn bài cũ vẫn sử dụng được.

### 7.3 Kết nối trở lại

1. Sync coordinator kiểm tra session và user context.
2. Xử lý outbox theo dependency: media -> parent entity -> relation/event.
3. Mỗi operation có idempotency key.
4. Thành công thì đánh dấu entity `synced` và hoàn tất operation.
5. Lỗi retryable dùng backoff; lỗi auth dừng queue; lỗi contract đưa vào
   quarantine và hiển thị recovery action.
6. Delta pull có thể áp dụng metadata cloud và conflict policy vào local DB,
   nhưng không tự tải binary media.
7. Media cloud chỉ tải về app-private sau thao tác rõ ràng của user trong
   Library; không auto-download khi startup, reconnect, mở list hoặc detail.

### 7.4 Xóa

- Soft delete tạo `deleted_at` và tombstone; dữ liệu vẫn có thể restore.
- Trash được giữ 30 ngày; deadline được thực thi ở cơ hội app
  startup/sign-in/resume đầu tiên sau hạn, còn explicit permanent delete chạy
  ngay.
- Permanent delete loại và xóa training projection trước khi xóa file/row;
  shared media chỉ xóa khi không còn Photo Note active tham chiếu.
- Cloud delete được queue nếu đang offline và tiếp tục retry cho đúng owner kể
  cả khi Cloud Backup đã OFF; upload mới vẫn bị consent chặn.
- Nếu training run đã dùng example bị xóa, checkpoint phải bị vô hiệu hóa hoặc
  rebuild từ base bằng tập dữ liệu còn hợp lệ.
- Chỉ giữ tombstone receipt tối thiểu; không giữ ảnh/raw JSON/từ vựng trong
  receipt. Không tuyên bố mathematical unlearning khi mới invalidation/rebuild.

## 8. Platform strategy

| Concern | Android/iOS | Web |
| --- | --- | --- |
| Structured persistence | Persistent local DB | Persistent browser DB, quyết định tại D1 |
| Media | App-private file system | Persistent browser media store |
| Offline Library | Bắt buộc | Bắt buộc nếu D4 được duyệt |
| Cloud sync | Supabase | Supabase |
| On-device training | Mục tiêu tương lai | Ngoài phạm vi giai đoạn đầu |
| Checkpoint | App-private file | Không cam kết trong giai đoạn đầu |

Business logic, schema semantics và repository contract phải thống nhất; adapter
lưu trữ và scheduler có thể khác theo platform.

## 9. Decision log D1–D10

Các recommendation dưới đây là đề xuất, chưa phải quyết định được phê duyệt.

| ID | Câu hỏi | Lựa chọn | Recommendation | Trạng thái |
| --- | --- | --- | --- | --- |
| D1 | Local DB engine nào? | Giữ `sqflite` + Web adapter; hoặc DB cross-platform/type-safe | Giữ họ `sqflite`: native plugin trên Android/iOS, FFI cho test/desktop, WASM + IndexedDB cho Web | APPROVED — 2026-09-02 |
| D2 | Có giữ ảnh gốc? | Luôn giữ; giữ theo quota; chỉ giữ bản chuẩn hóa | Luôn giữ local display + model-input khi note active; original chỉ khi opt-in và còn quota | APPROVED — 2026-09-03 |
| D3 | Cloud backup mặc định? | Bật; tắt; hỏi khi onboarding | Mặc định OFF; explicit opt-in; private theo account; tắt backup phải hỏi trước khi purge | APPROVED — 2026-09-03 |
| D4 | Web có offline parity? | Có; read-only cache; không hỗ trợ | Có persistence cho Library; chưa train model trên Web | PENDING |
| D5 | Model cá nhân đầu tiên? | SRS/recommendation; vision head; embedding reranker | SRS/recommendation nhỏ để chứng minh pipeline và rollback | PENDING |
| D6 | Nhãn nào được train? | AI-only; confirmed; corrected; mixed threshold | Chỉ `user_confirmed` và `user_corrected` mặc định eligible | PENDING |
| D7 | UX sau scan? | Auto sang Library; preview rồi Save; auto-save + preview | Auto-save local sau commit, hiển thị preview; điều hướng theo CTA/UX đã duyệt | PENDING |
| D8 | Federated learning? | Không; chuẩn bị contract; triển khai sớm | Chỉ chuẩn bị consent/provenance, chưa xây transport/aggregation | PENDING |
| D9 | Trash retention? | Không auto purge; 7/30/90 ngày | 30 ngày, cho phép Restore/xóa vĩnh viễn ngay; purge local/cloud/ML và giữ receipt tối thiểu; orphan chỉ vào quarantine sau xác nhận | APPROVED — 2026-09-08; purge detail approved 2026-09-09 |
| D10 | Local data khi logout? | Purge; giữ mã hóa/khóa; hỏi user | Khóa theo account, có tùy chọn purge; account delete luôn purge | PENDING |

### D1 — Quyết định được duyệt ngày 2026-09-02

- Người duyệt: chủ dự án, qua yêu cầu trực tiếp “thực hiện D1 triển khai M2B và
  M2A”.
- Android/iOS dùng `sqflite` hiện có.
- Unit/integration test và desktop spike dùng `sqflite_common_ffi`.
- Web dùng `sqflite_common_ffi_web` với SQLite WASM lưu trong IndexedDB.
- Domain/repository contract không phụ thuộc database engine; mọi factory được
  inject để có thể rollback adapter mà không đổi entity contract.
- Nếu Web adapter không đạt persistence/cross-tab/recovery test, rollback là
  tắt Web Library persistence và giữ native M2B; không downgrade schema hoặc
  xóa dữ liệu tự động.
- D1 không phê duyệt thay D2–D10 và không cho phép tự suy ra media retention,
  cloud consent, training label hoặc logout purge.

### D2/D3 — Quyết định được duyệt ngày 2026-09-03

- Người duyệt: chủ dự án, qua yêu cầu trực tiếp “duyệt D2/D3, triển khai
  M3A”.
- Display/model-input local được giữ khi Photo Note còn active để bảo đảm ôn
  offline và chuẩn bị on-device ML.
- Original media chỉ được giữ khi user opt-in và quota cho phép.
- Cloud backup mặc định OFF; chỉ upload sau explicit consent.
- Cloud object luôn private và owner-scoped; ứng dụng lưu object path, không
  lưu public URL làm contract.
- Tắt backup không tự động xóa dữ liệu cloud. UI phải hỏi user trước khi tạo
  purge request.
- D2/D3 không tự phê duyệt D4–D10.

### D9 — Quyết định được duyệt ngày 2026-09-08

- Người duyệt: chủ dự án, qua yêu cầu tiếp tục phương án “không silent-delete;
  quarantine orphan 30 ngày, cho Restore/Xóa ngay; media thiếu giữ JSON và từ
  vựng nhưng không đưa vào train”.
- Orphan trong `capy_scans/` chỉ được chuyển sang `capy_quarantine/` sau hộp
  thoại xác nhận nói rõ thời hạn 30 ngày; startup chỉ tự purge file đã đi qua
  hành động xác nhận này.
- Người dùng có thể Restore hoặc xóa vĩnh viễn ngay trong Library. Mọi mutation
  chỉ nhận file con trực tiếp trong hai thư mục app-private và fail safe khi
  trùng tên.
- Media reference bị thiếu không xóa Photo Note, raw/normalized JSON hay từ
  vựng. Training example liên quan chuyển sang `quarantined/excluded`, training
  run kiểm tra lại eligibility và model đã dùng source bị invalidated.
- D9 phê duyệt policy retention; việc đo/hiển thị dung lượng và Trash Photo Note
  đã được triển khai theo các increment M4.3B/M4.3C. Physical purge chạy ở cơ
  hội startup/sign-in/resume đầu tiên sau deadline; explicit delete bỏ qua thời
  gian chờ. Local purge không chờ mạng, còn cloud purge giữ tombstone/outbox để
  đúng owner retry kể cả khi backup đã OFF. D9 không phê duyệt D10.

### Ràng buộc UX cloud download — duyệt ngày 2026-09-09

- Người duyệt: chủ dự án, qua yêu cầu trực tiếp “trong phần chức năng tải ảnh
  và library đó là tùy chọn không tự động tải xuống”.
- Library có thể đồng bộ metadata để cho biết item đang cloud-only hoặc thiếu
  media local, nhưng không được dùng trạng thái đó để tự tải binary ảnh.
- Chỉ tải media về app-private sau hành động rõ ràng của user; không tải ngầm
  khi app startup, có mạng trở lại, mở Library hoặc mở detail.
- Tải về app-private không đồng nghĩa xuất sang Gallery/Photos hệ điều hành;
  export cần một feature và quyền platform riêng nếu được duyệt.

## 10. Conflict policy đề xuất

| Entity | Policy |
| --- | --- |
| Raw scan | Append-only; cùng request ID là cùng scan |
| AI detection | Append-only theo scan run |
| User annotation | User correction thắng AI; giữ revision/history |
| Photo title/emoji | Latest valid write theo version/timestamp |
| Album membership | Operation-based add/remove, idempotent |
| Learning event | Append-only |
| SRS progress | Recompute từ ordered events khi conflict không giải quyết được |
| Delete | Tombstone mới hơn thắng update cũ |
| Checkpoint | Không merge weights tùy tiện; giữ riêng theo training run |

## 11. Rủi ro và biện pháp

| Rủi ro | Tác động | Biện pháp M0/M1–M2 |
| --- | --- | --- |
| Chọn DB trước khi test Web/migration | Phải viết lại persistence | M2A spike có tiêu chí đo rõ ràng |
| Chỉ giữ ảnh nén hiện tại | Mất thông tin cho vision training | Tách original/display/model-input |
| Dùng prediction AI làm label | Self-training feedback loop | Annotation + eligibility policy |
| Đổi schema JSON không version | Không tái dựng dataset | Raw JSON + response schema version |
| Public media URL | Lộ ảnh người dùng | Private bucket + signed access |
| Xóa DB nhưng sót file/checkpoint | Privacy/storage leak | Tombstone, deletion ledger, rebuild policy |
| App bắt buộc online khi startup | Không truy cập bài cũ | Local-first bootstrap, network background |
| Cùng ảnh rơi vào train và test | Data leakage | Group split theo media asset |
| User A/B dùng chung cache | Cross-account exposure | Local account namespace và logout policy |

## 12. Gate chuyển sang M1/M2

M0 chỉ được đổi trạng thái thành `APPROVED` khi:

- [ ] D1–D10 có người phê duyệt và ngày phê duyệt.
- [ ] `library_data_contract.md` được duyệt field ownership/nullability.
- [ ] `privacy_and_retention.md` được duyệt consent, deletion và retention.
- [ ] Xác nhận Android/iOS là target training đầu tiên; phạm vi Web rõ ràng.
- [ ] Xác nhận không train trực tiếp từ raw Gemini predictions.
- [ ] Xác nhận migration phải bảo toàn `scan_results` hiện có.

Sau gate này mới triển khai M1 domain contract và M2A database spike.

### Ghi nhận implementation tạm thời — 2026-09-02

Theo yêu cầu triển khai, M1 domain contract và M2A SQLite spike đã được tạo dưới
dạng code cô lập, chưa nối vào runtime production. Kết quả M2A nằm tại
`docs/data/m2a_sqlite_spike.md`. Việc này không đồng nghĩa D1–D10 đã được duyệt;
database hiện tại của người dùng chưa bị mở, nâng version hoặc migrate.
