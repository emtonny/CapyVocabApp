# Chính sách Privacy, Consent, Retention và Deletion cho dữ liệu Thư viện/ML

> Trạng thái: **DRAFT — không phải chính sách pháp lý đã phát hành**  
> Ngày lập: 2026-09-01  
> Kiến trúc: `../architecture/offline_ml_storage.md`  
> Data contract: `library_data_contract.md`

## 1. Mục tiêu

Thiết lập hành vi kỹ thuật tối thiểu để dữ liệu ảnh, kết quả AI, lịch sử học và
model cá nhân không bị thu thập, đồng bộ, lưu giữ hoặc dùng để train ngoài mong
đợi của người dùng. Tài liệu này cần được review pháp lý/sản phẩm trước release.

## 2. Phân loại dữ liệu

| Nhóm | Ví dụ | Mức nhạy cảm | Mặc định |
| --- | --- | --- | --- |
| Raw media | Ảnh camera/gallery, EXIF còn giữ | Cao | App-private, không public |
| AI raw response | JSON Gemini, bbox, nghĩa | Trung bình/cao vì suy ra nội dung ảnh | Local; cloud theo backup consent |
| User annotation | Từ/nghĩa/bbox người dùng sửa | Trung bình | Local; cloud theo backup consent |
| Learning event | Đúng/sai, response time, hint | Trung bình, hành vi học tập | Local; cloud theo backup consent |
| Operational metadata | Album, title, timestamps | Trung bình | Local; cloud theo backup consent |
| Training projection | Feature/label đã derive | Cao vì dùng cho model | Local-only mặc định |
| Model checkpoint | Weights cá nhân | Cao, có thể encode hành vi | Local-only mặc định |
| Sync/diagnostic metadata | Error code, retry count | Thấp nếu đã redacted | Không chứa nội dung ảnh/token |

Ảnh có thể vô tình chứa người, tài liệu, địa chỉ hoặc thông tin cá nhân. Không
được coi ảnh vocabulary là dữ liệu không nhạy cảm.

## 3. Ba consent độc lập

### 3.1 Cloud backup consent

Cho phép upload media, raw JSON và dữ liệu nghiệp vụ lên Supabase để backup và
đồng bộ thiết bị. Việc bật consent chỉ tự áp dụng cho dữ liệu mới. Bài đã có
chỉ được backfill sau một xác nhận riêng; chỉ active owner note đủ media được
enqueue, còn missing media và Trash bị bỏ qua. Tắt consent:

- Dữ liệu mới vẫn hoạt động local.
- Không tạo cloud upload mới.
- Pending uploads bị hủy hoặc blocked.
- Dữ liệu cloud đã có được giữ hay purge phải theo lựa chọn rõ ràng của user.

### 3.2 Local personalization consent

Cho phép dataset builder và trainer dùng dữ liệu eligible trên chính thiết bị.
Tắt consent:

- Dừng scheduled/local training.
- Không sinh training manifest mới.
- Personalized checkpoint bị disable; chính sách xóa/rebuild cần user-facing.
- Base model/inference thông thường vẫn hoạt động.

### 3.3 Federated contribution consent

Cho phép gửi model update/aggregate contribution trong tương lai. Mặc định
`false`. Consent này không được suy ra từ cloud backup hoặc local
personalization. M0 không cho phép upload raw training examples dưới nhãn
"federated".

## 4. Consent record requirements

Mỗi consent change cần lưu:

- user ID;
- consent type;
- old/new value;
- policy version;
- timestamp;
- source screen/action;
- pending enforcement status nếu cần cleanup async.

Không lưu consent chỉ bằng SharedPreferences không gắn account. UI phải cho phép
xem và thay đổi từng consent độc lập.

## 5. Storage security target

### Local

- Media nằm trong app-private storage.
- DB/cache namespace theo user.
- Token không nằm trong Library DB hoặc JSON payload.
- Không log raw JSON, signed URL, local absolute path hoặc nội dung ảnh.
- Application-layer encryption cho media/DB là decision cần threat model riêng;
  OS sandbox không được mô tả như bảo vệ tuyệt đối trên thiết bị root/jailbreak.
- Checkpoint và training manifest nằm trong app-private storage.

### Cloud

- Bucket media phải private.
- DB lưu object path, không lưu public URL lâu dài.
- Signed URL ngắn hạn chỉ cấp sau authorization.
- Storage policies bắt buộc path owner `user_id`.
- RLS áp dụng SELECT/INSERT/UPDATE/DELETE cho owner.
- Service role chỉ tồn tại ở trusted backend; không đóng gói trong Flutter.

## 6. Data minimization

- Chỉ giữ EXIF field cần thiết; GPS/device metadata bị strip hoặc phải có mục
  đích/consent riêng.
- Không dùng email, phone, username, giới tính, tuổi hoặc vị trí làm ML feature
  nếu task không thực sự cần và chưa được review.
- Learning event chỉ lưu answer text khi cần cho task; ưu tiên normalized result
  và correctness thay vì input thô.
- Diagnostic logs dùng ID kỹ thuật/redacted code, không chứa payload.
- Training projection không nhân bản original media nếu có thể reference asset
  có kiểm soát.

## 7. Retention draft

D2/D3 đã được duyệt ngày 2026-09-03. D9 được duyệt ngày 2026-09-08; chi tiết
physical purge local/cloud/ML được chủ dự án duyệt ngày 2026-09-09.
Logout/account delete vẫn chờ D10.

| Dữ liệu | Retention đề xuất |
| --- | --- |
| Active Photo Note/Album | Đến khi user xóa hoặc account bị xóa |
| Trash local/cloud | 30 ngày; purge ở cơ hội app startup/sign-in/resume đầu tiên sau deadline, hoặc ngay theo explicit action |
| Orphan media local | Chỉ đưa vào quarantine sau explicit action; giữ 30 ngày, cho Restore/xóa ngay |
| Original media local | Theo quota + user setting; không tự xóa nếu chưa đảm bảo offline policy |
| Display/model-input media | Giữ khi Photo Note active và cần offline/training |
| Raw AI response | Cùng vòng đời Photo Note, trừ audit tối thiểu đã anonymize |
| User annotation | Cùng vòng đời source/Photo Note |
| Learning events | Cùng account hoặc retention riêng được công bố |
| Sync operations completed | Purge sau khoảng ngắn đủ debug; không giữ payload vô hạn |
| Quarantined migration data | Giữ đến khi repair/export/purge được user xác nhận |
| Training examples/manifests | Derived; rebuild/purge khi source/consent thay đổi |
| Personalized checkpoint | Đến reset model, consent revoke, invalidation hoặc account purge |

Không được tự động xóa local display copy chỉ vì cloud upload thành công nếu sản
phẩm vẫn cam kết ôn offline.

“Tự động sau 30 ngày” không có nghĩa tiến trình nền chạy khi ứng dụng đã bị hệ
điều hành kết thúc. Deadline được kiểm tra ở cơ hội an toàn đầu tiên khi app
khởi động, có authenticated owner hoặc resume. Local purge không chờ mạng;
cloud purge có thể hoàn tất sau khi đúng owner đăng nhập và mạng hoạt động.

## 8. Soft delete, permanent delete và account delete

### Soft delete

1. Đặt `deleted_at` và tạo tombstone trong local transaction.
2. Loại khỏi Photos/Album active views.
3. Giữ khả năng restore trước purge deadline.
4. Queue cloud tombstone nếu backup/sync đang dùng.
5. Training eligibility chuyển sang `excluded` ngay.

### Restore

- Chỉ cho phép trước permanent purge.
- Phục hồi entity và quan hệ hợp lệ.
- Không tự phục hồi training checkpoint cũ; dataset builder đánh giá lại
  eligibility ở manifest kế tiếp.

### Permanent delete một Photo Note

Thứ tự logic:

1. Khóa entity khỏi update mới.
2. Đánh dấu deletion request/idempotency key.
3. Loại và xóa source khỏi training examples cùng manifest/run links.
4. Xác định training runs/checkpoints đã dùng source.
5. Disable/rebuild checkpoint theo unlearning policy.
6. Xóa quan hệ Album, annotations và materialized SRS state phù hợp.
7. Xóa local media variants khi không còn Photo Note active khác dùng chung
   MediaAsset.
8. Xóa cloud rows và private Storage objects; nếu offline thì queue. Nghĩa vụ
   privacy purge vẫn được retry khi Cloud Backup đã OFF, nhưng chỉ cho đúng
   authenticated owner; consent OFF vẫn chặn mọi upload mới.
9. Đánh dấu purge hoàn tất, giữ tối thiểu non-content deletion receipt nếu cần
   cho idempotency/audit.

Local rows/file có thể được xóa trước cloud. Trong trường hợp đó, outbox purge
được phép giữ tối thiểu owner/entity ID và remote object target cần thiết cho
retry. Payload này phải được xóa sau khi remote purge hoàn tất; tombstone receipt
không được chứa ảnh, raw JSON, từ vựng hoặc local absolute path.

### Account delete

- Block sync/training ngay.
- Purge toàn bộ local DB namespace, media, training artifacts và checkpoints.
- Gửi/hoàn tất cloud deletion theo backend workflow.
- Auth logout đơn thuần không được làm User B nhìn thấy data User A.
- Nếu cloud delete chưa hoàn tất do offline, UI phải nói rõ pending state và có
  retry; không tuyên bố dữ liệu đã xóa hoàn toàn.

## 9. Model unlearning/rebuild policy

Vì một checkpoint có thể đã học từ data bị xóa, chỉ xóa row/source là chưa đủ.
Mỗi TrainingRun phải lưu tập TrainingExample đã sử dụng.

Policy đề xuất cho personalized model nhỏ:

1. Invalidate checkpoint có source bị purge/consent revoked.
2. Restore base model.
3. Rebuild dataset chỉ từ source còn eligible.
4. Train lại khi đủ điều kiện tài nguyên và sample.
5. Validate lại trước activation.
6. Nếu không train lại được, tiếp tục dùng base model.

Implementation hiện tại xóa training example và các liên kết lineage tới source,
đồng thời invalidates model đã dùng source. Historical run/model audit không
chứa nội dung source có thể còn để giải thích việc invalidation. Trainer/rebuild
runtime chưa được triển khai, vì vậy không tuyên bố mathematical machine
unlearning hoặc đã train lại model.

## 10. User controls bắt buộc trước release

- Xem dung lượng local/cloud theo nhóm media/data.
- Bật/tắt Cloud backup.
- Bật/tắt Local personalization.
- Federated contribution riêng, mặc định tắt.
- Xóa original nhưng giữ display copy nếu policy cho phép.
- Reset personalized model.
- Export dữ liệu có cấu trúc và media nếu sản phẩm cam kết portability.
- Empty Trash/xóa vĩnh viễn với mô tả ảnh hưởng offline/cloud/model.
- Xóa tài khoản.

## 11. Logging và telemetry

Được phép log:

- operation/request ID đã pseudonymize;
- entity type;
- error code;
- retry count;
- duration/byte count aggregate;
- model/runtime version và metric aggregate không định danh.

Không được log:

- access/refresh token;
- raw Gemini JSON;
- word/meaning/answer text nếu không có review riêng;
- signed URL;
- local absolute path;
- image bytes/hash dùng như cross-service identifier;
- checkpoint contents.

## 12. Failure handling

- Consent enforcement thất bại phải fail closed cho upload/training mới.
- Delete cloud thất bại giữ tombstone và retry; không làm sống lại local entity.
- Việc tắt Cloud Backup không được hủy nghĩa vụ xóa cloud đã tạo trước đó;
  upload mới vẫn phải fail closed.
- Corrupt media/JSON đi quarantine, không được train.
- Media bị thiếu giữ Photo Note/JSON/từ vựng để ôn offline, nhưng mọi training
  example liên quan phải `quarantined/excluded`; checkpoint đã dùng source đó
  phải bị invalidated.
- Auth mismatch dừng sync queue của account đó.
- Unknown schema version giữ raw data nhưng không normalize/train.
- Storage quota error không được xóa dữ liệu âm thầm.

## 13. Review checklist

- [x] D2: original chỉ giữ khi opt-in/quota; display/model-input giữ khi note active.
- [x] D3: cloud backup mặc định OFF, private, hỏi trước khi purge.
- [ ] D6: training eligibility chỉ dùng label đủ chất lượng được duyệt.
- [ ] D8: federated contribution mặc định tắt được duyệt.
- [x] D9: Trash/quarantine 30 ngày, Restore/purge ngay và physical purge
  local/cloud/ML với receipt tối thiểu được duyệt.
- [ ] D10: logout/account-delete local cache behavior được duyệt.
- [ ] Product copy giải thích rõ ảnh được gửi đến AI service khi scan online.
- [ ] Legal/privacy review trước production release.
- [ ] RLS/private bucket runtime tests được lên kế hoạch.
- [x] Delete/unlearning local integration test đã có.
- [x] Delete/cloud purge E2E trên Staging đã chạy bằng fixture tạm và cleanup.

Cho đến khi checklist được duyệt, tài liệu giữ trạng thái DRAFT và không được dùng
để tuyên bố compliance hoặc tính năng đã hoàn thành.
