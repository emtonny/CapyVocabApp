# Audit backend/database: Friends, Library và Chat

Ngày kiểm tra: **2026-10-01**. Trạng thái: **AUDIT HOÀN THÀNH; ĐÃ SỬA MỘT PHẦN SOURCE, CHƯA ROLLOUT DATABASE**.

## Tiến độ khắc phục ngày 2026-10-01

| Finding | Đã thực hiện | Còn lại / điều kiện hoàn thành |
|---|---|---|
| F01 | Migration mới thu hồi Friends DML ở bảng và cột; giữ SELECT/RPC | Chạy SQL security suite, kiểm tra tương thích Production rồi rollout riêng |
| F02 | Migration dùng `IS DISTINCT FROM` cho trường label bắt buộc; CHECK MIME/size khác NULL; giữ EXECUTE validator | Chạy SQL suite; defensive decode phía client chưa thực hiện |
| F03 | Thay hai UPSERT không hỗ trợ SQLite 3.22 bằng helper SELECT + INSERT/UPDATE trong transaction | Test local đạt; chưa kiểm tra trên thiết bị Android 9 thực |
| F04 | Chưa đổi hành vi Album | Chờ chọn Album local-only hay triển khai đầy đủ cloud contract |
| F05 | Chưa đổi generation của ảnh chia sẻ | Chờ xác nhận ảnh khôi phục được chia sẻ mới, trong khi bản cũ vẫn bị thu hồi |
| F06 | Lỗi tạm thời không còn bị chặn vĩnh viễn ở lần thử thứ 8; backoff được giới hạn | Chưa giải quyết late send, receipt blocked cũ và server generation |
| F07 | Lỗi Storage cleanup giữ công việc trong queue; draft RPC trả lại cả path đã invalidated để retry | Chưa chặn overwrite; chưa có orphan sweep; RPC chưa deploy |
| F08 | Draft migration khóa transaction theo owner trước khi cấp feed sequence | Chưa chạy kiểm thử hai writer đồng thời; chưa có sửa cursor lịch sử |
| F09 | ACK Photo Note kiểm tra `updated_at`; pull kiểm tra owner/consent trước và sau request | Chưa có server revision/CAS, session epoch, đầy đủ consent fence hay xử lý sửa cùng timestamp |
| F10 | Harness PostgreSQL tạm và 23 assertion bảo mật đã soạn; PowerShell parse đạt | SQL chưa chạy; concurrency, CI, benchmark và vận hành còn lại |

Kiểm chứng source: bộ Friends/Chat/Library/consent đạt **349 test**, **1 test opt-in skip**;
thêm **1 test worker** chứng minh ACK upload không xóa pending deletion phát sinh trong request.
Worker dịch Deno đạt **52 test**, `flutter analyze --no-pub` sạch.
`git diff --check` không có lỗi whitespace; Git có cảnh báo chuyển đổi LF/CRLF.
Chưa build/cài APK mới, chưa chạy smoke trên thiết bị, chưa commit/push.

Bốn migration `20261001014150`, `20261001014152`, `20261001014515`,
`20261001014725` là **draft chưa SQL-verified / chưa apply**.
Máy thiếu PostgreSQL native, Docker Desktop không khởi động được; đã hỏi quyền
tải PostgreSQL portable vào thư mục tạm để chạy harness, chưa cài runtime.
Khi có runtime, chạy `tool/test_backend_audit_schema.ps1 -PostgresBin <bin>`;
sau đó bổ sung/chạy test concurrency trước khi rollout migration feed.
Toàn bộ phần mô tả bên dưới là bằng chứng ở thời điểm audit trước các bản sửa source này.

## 1. Phạm vi và cách đọc kết quả

- Rà luồng Flutter repository/gateway → SQLite/outbox → Supabase RPC, RLS, Storage, Realtime và worker dịch Chat.
- Đối chiếu migration trong workspace với lịch sử remote, quyền thực tế, trigger/constraint và thống kê dữ liệu không chứa nội dung cá nhân.
- Staging: `nxteaznowkfennxpqjmt`; Production: `vmxonxqxrlkssdzsucrg`.
- Remote chỉ dùng truy vấn đọc và đọc cấu hình/log tổng hợp. Không INSERT/UPDATE/DELETE, apply migration, deploy, gọi provider dịch hay sửa tài khoản thật.
- Workspace đã có nhiều thay đổi staged/unstaged/untracked trước audit. Báo cáo dựa trên **working tree hiện tại**, không chỉ HEAD. Không commit/push hay chỉnh code ứng dụng.
- **Xác nhận runtime:** truy vấn read-only trên remote hoặc probe chạy thật tại local. **Xác nhận source/schema:** đường lỗi được chứng minh bằng source/quyền/constraint; chưa gây lỗi trên tài khoản thật. **Rủi ro cạnh tranh:** có lịch thực thi gây sai kết quả, cần test nhiều transaction/session để tái hiện trước khi sửa.
- P1: nên xử lý trước khi mở rộng sử dụng/rollout. P2: xử lý tiếp để bảo đảm độ tin cậy, tính toàn vẹn và khả năng vận hành. Không có kết luận rằng dữ liệu hiện tại đã bị khai thác hay bị mất.

## 2. Hiện trạng đã xác minh

| Hạng mục | Kết quả |
| --- | --- |
| Migration local / Staging | 40 file / 40 migration; Staging mới nhất `20260930130000_restore_chat_label_validator_execute` |
| Migration Production | 22 migration; mới nhất `20260916120000_add_onboarding_language_preferences`; chưa có operational Chat/Friends contract mới |
| Tính tái lập bản phát hành | 6 migration cuối đang untracked trong workspace; có file trên máy nhưng chưa được Git quản lý |
| Feature gate | Friends/Chat gateway và owner provider chỉ cho exact Staging; chưa rollout Production là chủ đích, không tự coi là migration lỗi |
| Library | Native sync cần `LIBRARY_SYNC_ENABLED=true`, mặc định false; Web cloud sync/restore chưa bật theo D4 trong `db_status.md` |
| RLS | Các bảng public được liệt kê trên hai project đều bật RLS; điều này không thay thế kiểm tra nội dung policy và quyền SQL |
| Storage | `photo_notes` private trên cả hai project; `chat_album_images` private trên Staging, giới hạn 8 MiB |
| Dữ liệu Staging | 0 accepted friendship lệch một chiều; 0 active conversation thiếu accepted pair; 0 Photo Note có media FK bị thiếu |
| Ảnh Chat Staging | 7 message ảnh; 0 object mồ côi theo phép đối chiếu object path; 0 object còn tồn tại của message đã invalidated; 0 row thiếu các key nhãn bắt buộc; 0 row ảnh thiếu MIME/size |
| Dịch Chat | 22 translation đều `succeeded`, 0 processing quá một giờ; worker ACTIVE v19; cron recovery đang bật mỗi phút |
| Log worker trong cửa sổ 24 giờ mặc định lúc audit | 1.383 HTTP 204 và 2 HTTP 200; không thấy status lỗi trong nhóm request worker này. Không suy rộng thành mọi log backend đều sạch |

Các số liệu là ảnh chụp tại thời điểm đọc, không phải giám sát liên tục. Lịch sử migration trùng không chứng minh toàn bộ definition remote trùng byte với file; audit đã đọc thêm các policy, constraint và helper trực tiếp liên quan phát hiện bên dưới.

## 3. Phát hiện và hướng xử lý

### F01 — P1: Friends vẫn cho ghi trực tiếp, vượt qua workflow RPC

**Bằng chứng:** `has_table_privilege('authenticated','public.friends', ...)` trả `true` cho INSERT/UPDATE/DELETE trên cả Staging và Production. Policy `Users manage friend requests` là `FOR ALL`, cho phép row khi caller là một trong hai đầu quan hệ.

- Production **không có trigger** trên `friends`. Vì vậy policy không bắt buộc recipient chấp nhận trước khi một row mang status `accepted`; cũng không giữ bất biến hai đầu quan hệ. Client gate Staging không bảo vệ REST API Production.
- Staging có `guard_chat_friend_acceptance` bảo vệ INSERT/UPDATE một phần, nhưng không bảo vệ DELETE. Caller có thể xóa riêng một chiều, hoặc ghi trực tiếp không qua pair advisory lock của RPC. Hai chiều accepted không còn là invariant được bảo đảm cho mọi write path.
- `is_active_chat_member`/`can_insert_chat_message` kiểm tra membership, không kiểm tra friendship hiện tại. Xóa friendship không tự thu hồi quyền của conversation đã mở.

**Nguồn:** `supabase/migrations/20260725204011_initial_schema.sql:245`; `20260915120000_add_operational_chat_security.sql:4,151,163,183`; `20260922120000_add_friend_management_contract.sql:584,644`.

**Xử lý:** thu hồi DML trực tiếp của client, giữ SELECT cần thiết và RPC đã xác thực; rà cả column grants. Production cần một bản hardening nhỏ, không kéo toàn bộ Chat vào chỉ để sửa lỗ hổng này. Nếu có client cũ đang ghi trực tiếp, xác minh trước khi rollout. Unfriend/block là quyết định sản phẩm riêng: khi bổ sung phải cập nhật hai chiều và quyền gửi/đọc ảnh theo contract trong cùng transaction; không tự suy đoán rằng phải xóa lịch sử.

**Nghiệm thu:** A không thể tạo accepted với B, tự đổi recipient, xóa một chiều hay tạo hai pending cạnh tranh qua REST; B vẫn accept/reject bằng RPC; A↔B gửi đồng thời không tạo trạng thái lệch; outsider C không đọc được conversation/ảnh.

### F02 — P1: Validator attachment chấp nhận dữ liệu thiếu, có thể làm lỗi toàn bộ history fetch

**Tái hiện read-only trên Staging:**

```sql
select private.valid_chat_album_image_labels('[{}]'::jsonb);
-- true
select private.valid_chat_album_image_labels('[{"number":1,"word":"cat"}]'::jsonb);
-- true
```

`jsonb_typeof(item->'key') <> 'type'` cho NULL khi key không tồn tại. Nhánh `IF` không bắt được trường hợp đó. Constraint attachment cũng thiếu `IS NOT NULL` riêng cho MIME/size; biểu thức shape với MIME hoặc size NULL trả NULL. PostgreSQL chấp nhận CHECK khi biểu thức là TRUE **hoặc NULL**, theo [tài liệu constraints](https://www.postgresql.org/docs/current/ddl-constraints.html).

Client `OperationalChatImageLabel.fromJson` từ chối dữ liệu này; `fetchHistory` decode cả danh sách bằng `map(...).toList()`. Một row không hợp lệ có thể làm refresh conversation thất bại, kéo theo các bước reconcile còn lại không chạy. **Chưa có row sai dạng được tìm thấy trong Staging hiện tại.**

**Nguồn:** `supabase/migrations/20260929143000_add_chat_album_image_labels.sql:19–57,68–83`; `lib/features/chat/domain/operational_chat.dart:64`; `lib/features/chat/data/operational_chat_supabase_gateway.dart:291`.

**Xử lý:** migration mới kiểm tra đủ required keys, type theo cách không lọt NULL, range/size; yêu cầu MIME/size không NULL ở nhánh ảnh. Giữ grant EXECUTE đã khôi phục ngày 30/09. Thêm khả năng cô lập một attachment lỗi mà vẫn giữ raw message và đọc được các row hợp lệ, kèm mã lỗi an toàn.

**Nghiệm thu:** thiếu key, JSON null, sai type, nhãn vượt biên, >15 nhãn, quá dung lượng đều bị chặn; text/ảnh cũ và ảnh hợp lệ vẫn gửi được bằng role authenticated. Test phải chạy INSERT thật trong DB test, không chỉ tìm chuỗi migration.

### F03 — P1: Cloud pull Library vẫn chứa UPSERT không chạy trên SQLite 3.22

`applyLibraryCloudDelta` dùng `INSERT ... ON CONFLICT ... DO UPDATE` tại cả tombstone và **mọi lần ghi cursor**, kể cả delta rỗng. Chính helper `_upsert` của repository ghi nhận Android 9/SQLite 3.22 và đã có cách insert/update tương thích, nhưng hai chỗ này chưa dùng.

UPSERT dạng này chỉ có từ SQLite 3.24, theo [SQLite UPSERT](https://sqlite.org/lang_upsert.html). FFI test dùng SQLite mới nên vẫn pass. Đây là lỗi tương thích source đã xác nhận; chưa chạy probe mới trên Android 9 trong audit này.

**Nguồn:** `lib/features/library/data/local/sqlite_library_store.dart:2360,2496,3088`.

**Xử lý:** dùng select/insert/update trong transaction hiện tại; giữ nguyên phép MAX deletion version và tính nguyên tử giữa dữ liệu/cursor. Không dùng REPLACE vì có thể gây delete/reinsert và tác dụng phụ FK.

**Nghiệm thu:** delta rỗng, lần pull đầu, cursor có sẵn, tombstone mới/cũ và rollback khi lỗi đều chạy trên SQLite 3.22 thực tế; kiểm tra cold restart/offline sau pull.

### F04 — P1: Album được enqueue nhưng backend chưa hỗ trợ đồng bộ

`saveAlbum`, favorite, thêm/gỡ membership và xóa Album tạo outbox khi Cloud Backup bật. `LibrarySyncWorker._execute` lại luôn trả `cloud_entity_contract_missing` với `album` và `albumPhotoNote`. Hai remote không có bảng Album tương ứng.

**Probe local đã chạy:** tạo Album với cloud consent ON → drain → `blocked=1`, `last_error_code=cloud_entity_contract_missing`, không có remote call. Đây là mâu thuẫn producer/consumer, không phải lỗi mạng có thể tự retry hết.

**Nguồn:** `lib/features/library/data/local/sqlite_library_store.dart:1539,1608,1641,1703,1747`; `lib/features/library/application/library_sync_worker.dart:312`.

**Xử lý đề xuất:** trước mắt giữ Album local-only rõ ràng và không tạo công việc backend chắc chắn không hỗ trợ; không tự đánh dấu các operation cũ là đã backup. Nếu sản phẩm yêu cầu backup toàn bộ cấu trúc Album, làm milestone riêng gồm owner-scoped schema/RLS, gateway, feed, restore membership, soft-delete và backfill. Việc chọn contract local-only hay cloud Album cần chốt trước triển khai.

**Nghiệm thu:** tạo/sửa/xóa Album không để pending/blocked giả; các Photo Note vẫn backup độc lập. Nếu bật cloud Album, thiết bị thứ hai phải tái tạo đúng tên, favorite và membership, không phục hồi Album đã xóa.

### F05 — P1: Xóa → restore → gửi lại ảnh gây lệch trạng thái hai phía

Invalidation local khóa theo `source_photo_note_id` vĩnh viễn. `completeAlbumImageInvalidation` dùng `blocked=1,next_attempt_at=NULL`; enqueue lại dùng `ConflictAlgorithm.ignore`. Tuy nhiên enqueue message ảnh mới không kiểm tra tombstone này.

**Probe local đã tái hiện:** hoàn tất invalidation của một source → enqueue ảnh mới cùng source → relay gửi thành công → server giả lập giữ `available=true`, nhưng `_merge` của sender ép thành `available=false`; invalidation lần tiếp theo không tạo công việc due.

Nguồn ảnh có thể trở lại picker sau Restore trong Library. Vì thế người gửi/người nhận có thể nhìn khác nhau; lần xóa thứ hai có thể không thu hồi ảnh mới qua local outbox.

**Nguồn:** `lib/features/chat/data/operational_chat_store.dart:822,881,1081,1128`; `lib/features/chat/application/operational_chat_relay.dart:42`.

**Xử lý:** giữ ảnh đã gửi trước lần xóa ở trạng thái unavailable vĩnh viễn. Chốt một trong hai contract cho ảnh được restore: cấm share lại cùng source, hoặc cho share mới theo generation/share ID và invalidation chỉ áp dụng đúng thế hệ. Khuyến nghị share mới có identity vòng đời riêng nếu Restore vẫn cho phép chọn ảnh; không xóa tombstone cũ để bật lại mọi ảnh cũ.

**Nghiệm thu:** gửi → xóa → restore → gửi lại → xóa lần nữa; hai thiết bị hiển thị thống nhất, ảnh cũ không sống lại, ảnh mới được thu hồi đúng contract, restart không mất trạng thái.

### F06 — P1: Thu hồi ảnh chưa bảo đảm trước request gửi đến muộn; retry có thể dừng vĩnh viễn

RPC invalidation chỉ UPDATE các message **đã tồn tại**, không ghi tombstone remote chặn future INSERT của source đã xóa. Request gửi ảnh đang chạy hoặc thiết bị khác giữ source cũ có thể INSERT sau invalidation và nhận mặc định `attachment_available=true`. Đây là rủi ro concurrency xác nhận từ write paths; chưa cố tình tạo race trên remote.

Ở local, sau 8 lần lỗi invalidation bị `blocked`; lần bridge replay sau đó không reset vì INSERT IGNORE. Không có cơ chế retry riêng cho privacy invalidation như nút retry message. Với source local-only không có row `public.photo_notes`, không thể dựa vào trigger Library cloud để bù lại.

**Nguồn:** `supabase/migrations/20260929132557_add_chat_album_image_shares.sql:98–145`; `lib/features/chat/application/operational_chat_coordinator.dart:460–484`; `lib/features/chat/data/operational_chat_store.dart:1081–1158`.

**Xử lý:** durable remote revocation theo owner/source/generation, được kiểm tra cùng transaction khi nhận message; serialize send/revoke theo identity phù hợp. Tách privacy retry thành trạng thái pending/retry/completed/needs-attention; lỗi tạm thời không được biến thành bỏ cuộc không thể phục hồi. Không bắt buộc Photo Note phải có cloud row vì chia sẻ ảnh local-only đang là luồng hợp lệ.

**Nghiệm thu:** giữ request send ở barrier → revoke commit → thả send; ảnh không được trở lại khả dụng. Mất mạng/lỗi 5xx kéo dài, restart và đổi tài khoản vẫn bảo toàn nghĩa vụ thu hồi của đúng owner.

### F07 — P2: Nội dung file ảnh Chat có thể đổi sau gửi; dọn Storage không bền vững

- Policy `Chat senders update Album images` chỉ kiểm tra owner prefix; sender có thể overwrite binary của message đã gửi. Gateway dùng `upsert:true` trước mỗi lần thử gửi. Metadata/label bất biến nhưng bytes chưa bất biến và không có hash attachment để đối chiếu.
- Nếu upload thành công nhưng insert message thất bại vĩnh viễn, chưa có đường dọn object mồ côi rõ ràng.
- Invalidation nuốt `StorageException` rồi được đánh dấu hoàn tất. Lần gọi tiếp chỉ trả path của message còn `attachment_available=true`; khi trigger cloud đã invalidated trước, RPC không trả các path đó nữa. Có thể giữ file thừa lâu dài dù recipient đã bị chặn đọc.

**Nguồn:** `supabase/migrations/20260929132557_add_chat_album_image_shares.sql:109,173–211`; `lib/features/chat/data/operational_chat_supabase_gateway.dart:127–146,189–218`.

**Xử lý:** upload identity bất biến với hash/size; retry kiểm tra object/canonical message trước, không ghi đè nội dung đã finalize. Tách revoke access khỏi durable Storage cleanup; có cleanup job/receipt và thời gian grace cho object upload chưa gắn message. Dùng Storage API để xóa file, không DELETE metadata `storage.objects` trực tiếp.

**Nghiệm thu:** lost ACK không đổi bytes/nhân đôi message; overwrite sau finalize bị chặn; xóa Storage lỗi rồi retry thành công; job không xóa ảnh của message pending còn hợp lệ. Hiện chưa thấy orphan trong snapshot Staging.

### F08 — P1, cần test concurrency: Cursor Library có thể bỏ sót transaction commit muộn

Feed dùng identity sequence, pull lấy `MAX(sequence)` của row nhìn thấy rồi lần sau dùng `sequence > cursor`; chưa có cơ chế bảo đảm thứ tự cấp sequence tương ứng thứ tự commit của các writer cùng owner.

Lịch gây lỗi: transaction A ghi note X nhận sequence 101 nhưng chưa commit → B ghi note Y nhận 102 và commit → client pull thấy 102, lưu cursor 102 → A mới commit 101 → các pull sau không lấy 101 nữa. Sequence là bộ cấp số, không phải watermark commit; xem [PostgreSQL sequence functions](https://www.postgresql.org/docs/current/functions-sequence.html). Chưa có bằng chứng một người dùng hiện tại đã bị mất delta.

**Nguồn:** `supabase/migrations/20260910120000_add_library_cloud_pull_feed.sql:8,81,157,179`; `lib/features/library/application/library_cloud_pull_worker.dart:61`.

**Xử lý:** trước tiên tái hiện bằng hai writer và một reader trên DB test. Chọn cơ chế feed bảo đảm commit ordering trong phạm vi owner; phương án nhỏ là serialize mutation cùng owner trước cấp sequence, với thứ tự khóa nhất quán cho tất cả write paths. Nếu không kiểm soát được writer, cần thiết kế feed/watermark khác. Không vá bằng timestamp hoặc delay tùy ý. Chuẩn bị resync có bảo vệ local edits/tombstone cho cursor đã đi qua sự kiện bỏ sót.

**Nghiệm thu:** đảo thứ tự commit, rollback, ghi/xóa cùng note, pagination qua biên batch; mọi thay đổi committed được áp dụng hoặc supersede có chủ đích, không bỏ mất note độc lập.

### F09 — P1, cần test nhiều thiết bị: Upsert Library chưa có chống ghi đè phiên bản cũ

Gateway upsert theo `id` và gửi `sync_version:1`; không có expected-version/CAS hoặc tombstone remote chặn stale writer. Local bỏ qua snapshot khi chưa synced chỉ bảo vệ cache ở một máy, không bảo vệ server khỏi payload cũ từ máy khác. ACK `markPhotoNoteSynced` cũng không ràng buộc revision đã upload.

Hệ quả có thể xảy ra: máy offline cũ ghi đè title/soft-delete của máy mới; upsert lại aggregate sau hard purge có thể tái tạo dữ liệu nếu các dependency cũng được upload lại. Đây là khoảng trống conflict contract xác nhận từ source, chưa tái hiện mất dữ liệu trên remote.

**Nguồn:** `lib/features/library/data/remote/supabase_library_sync_gateway.dart:112–135,214–232`; `lib/features/library/data/local/sqlite_library_store.dart:2242,2414`; `lib/features/library/application/library_sync_worker.dart:282–311`.

**Xử lý:** server revision + conditional mutation, quy tắc delete-wins và tombstone bền vững; ACK chỉ clear đúng revision của operation đã gửi. Không áp last-write-wins dựa trên đồng hồ client. Bổ sung session/consent epoch cho Library worker/pull trước remote action kế tiếp và trước commit response; gateway Library hiện dùng mutable global client, khác Chat/Friends có captured token.

**Nghiệm thu:** hai thiết bị sửa cùng note, soft-delete đối đầu stale edit, hard purge đối đầu retry cũ, edit trong lúc ACK về, revoke consent/logout/account switch giữa các await. Không hồi sinh dữ liệu đã purge hoặc advance cursor của owner sai.

### F10 — P2: Khoảng trống kiểm thử SQL và hardening vận hành

- `test/features/chat/operational_chat_migration_test.dart` chỉ tìm chuỗi grant trong file; không chứng minh validator/constraint/RLS hoạt động sau khi apply toàn chuỗi migration.
- Các script SQL hiện chia checkpoint; `tool/test_chat_operational_schema.ps1` chỉ apply C2 rồi chạy C2 checks, không bao phủ hai migration attachment mới.
- Advisor xác nhận `capture_library_change_event()` vẫn có EXECUTE cho anon/authenticated trên cả hai project dù migration chỉ revoke PUBLIC. Đây là quyền dư cần thu hẹp; **không coi là exploit đã xác nhận** vì hàm trả trigger, không phải RPC nghiệp vụ thường gọi được trực tiếp.
- Advisor còn báo nhiều FK thiếu covering index, RLS `auth.uid()` đánh giá theo từng row, và policy Friends SELECT trùng. Cần chọn index theo query/EXPLAIN, không tự thêm toàn bộ hoặc xóa index bị báo unused trong database nhỏ.
- Bucket `photo_notes` chưa có giới hạn size riêng tại bucket; cần kiểm tra giới hạn toàn project và quota sản phẩm trước khi chọn mức. RLS gửi Chat chưa có quota theo sender để giới hạn chi phí dịch tự động.

**Xử lý:** CI DB disposable chạy các migration liên quan theo đúng thứ tự, role-based negative tests và concurrency tests; nâng harness theo PostgreSQL 17 để sát remote (script hiện mặc định tìm PostgreSQL 18). Áp least privilege cho trigger helpers; đo workload trước khi tối ưu; tách quota/cost policy thành cấu hình backend có test.

Advisor tham khảo: [SECURITY DEFINER callable by anon](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [missing FK indexes](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys), [duplicate permissive policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies).

## 4. Những điểm không nên sửa nhầm

- Không bật Friends/Chat Production chỉ vì Staging có nhiều migration hơn. Cần rollout riêng với khả năng rollback và test hai tài khoản.
- Không mở Web Library cloud sync: D4 hiện chủ đích giữ local persistence, chưa có cloud adapter.
- Không thêm policy cho các bảng private/service-only chỉ để làm hết advisory “RLS enabled no policy”; deny client có thể là đúng thiết kế.
- Không revoke hàng loạt EXECUTE của các RPC SECURITY DEFINER hợp lệ. Kiểm tra auth/owner/role riêng từng hàm; lỗi validator EXECUTE ngày 30/09 đã được sửa và hiện grant đã tồn tại.
- Không coi legacy `chat_messages` và operational `chat_operational_messages` là trùng cần gộp. Chúng đang có contract khác nhau.
- Không đổi raw Chat thành nguồn Training, không tự upload lại thư viện cũ và không thay quyết định consent/retention trong đợt sửa này.
- Không xóa lịch sử rejected friendship hoặc mở unfriend/retry-rejected nếu chưa chốt nghiệp vụ hiện tại trong `friend.md`.

## 5. Kế hoạch triển khai đề xuất

| Bước | Mục tiêu và phạm vi | Điều kiện bắt đầu | Điều kiện hoàn thành |
| --- | --- | --- | --- |
| M0 — Baseline và test harness | Chụp working-tree/migration manifest; đưa 6 migration untracked vào tập review; tạo DB test disposable phù hợp và suite attachment hiện tại | Chưa cần sửa hành vi sản phẩm | Có replay migration + 3-role A/B/C harness; các regression mới tái hiện lỗi trước fix; không lấy test lịch sử làm bằng chứng mới |
| M1 — Quyền Friends và validator | Sửa F01/F02 bằng migration additive; defensive attachment decode; giữ RPC/grant cần thiết | M0; xác minh client nào còn dùng direct Friends DML | Unauthorized direct mutation bị từ chối; text/ảnh hợp lệ pass; malformed attachment không phá lịch sử; đánh giá hotfix Production độc lập |
| M2 — Library trên thiết bị đang hỗ trợ | Sửa F03; giải quyết F04 theo contract Album đã chốt | Có Android 9/SQLite 3.22 để nghiệm thu; xác nhận Album local-only hay cloud | Pull/cursor/deletion không lỗi cú pháp; Album không có công việc bị blocked giả; Photo Notes vẫn backup/restore được |
| M3 — Vòng đời ảnh chia sẻ | Sửa F05/F06/F07 theo một thiết kế source/share generation, durable revoke và cleanup | Chốt restore-share semantics; không bắt buộc cloud backup nguồn | Chuỗi xóa/restore/gửi/xóa lần nữa thống nhất hai máy; late send không hồi sinh ảnh; retry bền vững; bytes sau finalize bất biến |
| M4 — Tính đúng của sync nhiều thiết bị | Tái hiện và sửa F08/F09; epoch/session/consent fences | Test DB nhiều transaction; mô hình revision/tombstone được review | Commit đảo thứ tự không mất delta; stale writer không hồi sinh/ghi đè dữ liệu; local edits không bị ACK cũ clear |
| M5 — Vận hành và hiệu năng | F10: cleanup permissions, SQL CI, workload benchmark, quota/retention/monitoring | Correctness M1–M4 đã ổn định | Chỉ còn advisory có giải thích; baseline/after được đo; cảnh báo queue age, invalidation pending, orphan grace và blocked sync |
| M6 — Staging E2E và rollout riêng | Hai tài khoản + outsider, Android 9 + thiết bị thứ hai; snapshot/backup, apply/recheck, mở gate có kiểm soát | Tất cả gate liên quan pass; có phê duyệt deploy/apply phù hợp | Migration/grant thực tế đúng; flow online/offline/restart pass; Production chỉ nhận phần đã duyệt, không kéo theo scope ngoài kế hoạch |

**Thứ tự ưu tiên:** M0 → M1 → M2 → M3 → M4 → M5 → M6. Hotfix giới hạn direct Friends DML Production có thể đi sớm qua một gate riêng sau M0/M1; không chờ đầy đủ feature rollout.

**Ba quyết định cần chốt trước milestone tương ứng:** Album có thuộc cam kết Cloud Backup không; ảnh restore có được tạo share mới không; nếu thêm unfriend/block thì giữ quyền đọc lịch sử hay thu hồi cả lịch sử. Đây là điểm quyết định cho triển khai sau audit, không ngăn việc xác minh các lỗi hiện tại.

**Migration/rollback:** mỗi nhóm có migration mới, preflight dữ liệu hiện tại và test role; không sửa tên/nội dung migration đã deployed để “sửa lịch sử”. Backup/manifest trước apply; dữ liệu sai cần dry-run repair riêng, không tự xóa. Khi có sự cố, dừng feature/writer liên quan và dùng migration sửa tiếp; không rollback bằng cách mở lại quyền rộng hay xóa tombstone bảo vệ dữ liệu. Mỗi increment thay DB/sync/media phải cập nhật trạng thái và changelog `db_status.md`.

## 6. Kiểm chứng đã thực hiện

| Lệnh/kiểm tra | Kết quả mới trong audit |
| --- | --- |
| `flutter test test/features/friends test/features/chat test/features/library test/features/settings/cloud_backup_consent_provider_test.dart --reporter expanded` | **341 pass, 1 skip**; skip là Library staging E2E opt-in |
| `flutter analyze` | **No issues found**; pub thông báo dependency mới ngoài constraint, chưa cập nhật dependency |
| `deno test --allow-env --allow-read supabase/functions/chat-translation-worker` | **52 pass, 0 fail** |
| Hai probe AUDIT ngoài repo dùng fixture từ tests hiện có | **2 pass**: pass nghĩa là tái hiện đúng lỗi F04 và F05, không có nghĩa lỗi đã được sửa |
| Read-only Supabase | Projects, migrations, table/RLS inventory, policies/grants/triggers/constraints, buckets, publications, advisors, worker/cron, aggregate data và worker status log đã đọc |
| Validator probe Staging | `[{}]` và label thiếu geometry đều được chấp nhận; authenticated có EXECUTE; shape MIME/size NULL trả NULL |
| `powershell -NoProfile -File tool/test_friend_f1_schema.ps1` | **Không chạy được SQL suite:** thiếu native PostgreSQL tools tại `C:\Program Files\PostgreSQL\18\bin` |
| `docker version --format '{{.Server.Version}}'` | **Không có Docker daemon hoạt động**; không tự cài/khởi tạo runtime |

Probe command:

```powershell
$auditProbeRoot = Join-Path $env:TEMP 'capy-backend-audit-20261001'
flutter test --no-pub "$auditProbeRoot/chat_audit_test.dart" `
  "$auditProbeRoot/library_audit_test.dart" --plain-name AUDIT --reporter expanded
```

Log tại `%TEMP%/capy-backend-audit-flutter.log`, `capy-backend-audit-deno.log`, `capy-backend-audit-analyze.log`. Các probe nằm ngoài repository, dùng synthetic data và fake remote; không là test triển khai chính thức.

**Chưa xác minh:** replay toàn bộ migration/SQL security suite, race test PostgreSQL, hành vi mới trên Android 9, two-device live E2E, full app build, restore/purge thật trên Storage, benchmark tải lớn, so sánh byte-for-byte bundle Edge deployed với source và dependency vulnerability audit. Không cần giả lập các kết quả này để hoàn thành báo cáo; chúng là gate bắt buộc của kế hoạch sửa tương ứng.

## 7. Kết luận audit

Hệ thống có nền tảng tốt: owner-scoped cache, private Storage, raw Chat bất biến ở DB, idempotency sender/client ID, queue dịch với lease, và test hiện tại đều pass. Tuy nhiên test xanh chưa bao phủ các lỗi quyền Friends, attachment validation, SQLite compatibility, Album cloud contract và vòng đời ảnh đã tái hiện/đối chiếu ở trên. Nên xử lý các P1 trước khi mở rộng rollout, rồi giải quyết race nhiều thiết bị và vận hành theo từng milestone có bằng chứng nghiệm thu.
