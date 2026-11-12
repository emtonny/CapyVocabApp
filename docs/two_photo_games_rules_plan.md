# Kế hoạch rule cho hai mini-game dùng ảnh

## Luồng ngày chụp cập nhật 2026-10-08

Bài học theo ngày chạy bắt buộc hai vòng: nối từ đúng hết trước, rồi điền chữ.
Mỗi ảnh được chia thành các nhóm tối đa bốn đồ vật; ảnh và số đánh dấu của nhóm
được giữ giống nhau trong hai vòng. Nếu một nhóm còn câu sai, nhóm đó được làm
lại đầy đủ. Game 2 hiển thị ô ký tự riêng cho từng đồ vật, dùng một vùng nhập
liên tục cho mỗi từ để giữ bộ gõ và Backspace hoạt động; chạm ô để sửa ký tự,
giữ khoảng trắng của từ ghép và chấm theo normalizer Unicode hiện hành.

Mỗi box có bóng đèn 3D nhỏ bên phải dòng đồ vật/số ký tự. Ba lần bấm mở
lần lượt nghĩa tiếng Việt, phiên âm và đáp án tiếng Anh, giữ các gợi ý trước.
Mức gợi ý của từng đồ vật lưu cùng bản nháp; không tự điền ô chữ và không thay
đổi cách chấm/thưởng. Dữ liệu thiếu được báo rõ. Nguồn icon và giấy phép xem
[fluent_light_bulb_asset.md](fluent_light_bulb_asset.md).
Khung gợi ý tự ẩn sau 5 giây đọc (tính sau khi tải xong dữ liệu). Bấm bóng đèn
sau mức 3 để xem lại; mỗi đồ vật có thời gian riêng. Mức gợi ý được giữ khi mở
lại bài, còn khung gợi ý chỉ hiện khi chủ động bấm.

Chỉ sau vòng điền đúng hết mới tạo kết quả hoàn thành và bản ghi chờ đồng bộ
thưởng. SQLite v9 thêm `lesson_sessions.game_sequence_version`; câu hỏi, bản
nháp và lịch sử vẫn lưu trong các trường JSON hiện có. Phiên ngày chưa xong
được chuyển sang luật hai vòng khi mở lại, giữ ảnh nguồn và lịch sử nối từ;
tiến trình hoàn thành tính lại theo game điền. Phiên đã kết thúc giữ kết quả cũ.
Lượt chơi lại chạy hai vòng kể cả khi bài gốc dùng luật một vòng; lượt chơi lại
chưa xong được chuyển sang luật mới khi mở. Ôn tập Library chọn ghép từ hoặc
trộn cũng có vòng điền tiếp theo; chọn riêng điền chữ giữ luồng một game.

Sau khi đúng hết game 1, màn kết quả có hai nút: **Về Home** lưu bài ngày ở
trạng thái tạm dừng với câu hỏi game 2, hoặc **Tiếp đến game điền từ** mở vòng
điền ngay. Chưa tạo kết quả hoàn thành hay thưởng khi chỉ xong game 1.
Thông báo kết quả mỗi lượt hiển thị trong khung giữa màn hình trên nền game
làm mờ; bàn phím được ẩn khi chấm bài. Khung có thể cuộn nếu nội dung dài.
Phần kế hoạch cũ bên dưới là thông tin lịch sử. Kiểm chứng và giới hạn xem
[db_status.md](../db_status.md).

## Đồng bộ GitHub ngày 2026-10-07

Đã nhập source Home từ `origin/home` tại `664a7c9` theo yêu cầu đồng bộ toàn bộ chức năng mới. Hai game ảnh, session SQLite, đồng bộ kết quả, thưởng xu vàng và leaderboard đã có implementation; nhận định scaffold/chưa triển khai bên dưới là snapshot trước đồng bộ. Luồng Home hiện hành được mô tả trong [home.md](../home.md); kiểm chứng bản tích hợp và khác biệt với các đề xuất cũ nằm trong [github-home-sync-2026-10-07.md](github-home-sync-2026-10-07.md). Các rule đề xuất chưa khớp implementation không được xem là đã nghiệm thu hoặc tự động thay thế contract hiện hành.


**Trạng thái:** đề xuất để duyệt; chưa triển khai gameplay, lưu lượt chơi hoặc thưởng. **Hai game trong scope:** `photo_order_quiz` (FR-GAME1: sắp xếp từ theo ảnh) và `photo_letter_fill` (FR-GAME2: điền chữ theo ảnh đồ vật). `solo_arena` là chế độ khác, không nằm trong tài liệu này. Rule xu/cược nằm ở [coin_rules_plan.md](coin_rules_plan.md).

## 1. Hiện trạng và điều đã biết

- Hai màn hình, provider và widget game hiện chỉ là scaffold/TODO; `PROJECT_STATUS.md` cũng ghi Mini-games chưa có gameplay, scoring hay persistence. Chưa có rule điểm, số vòng, thời gian hoặc thưởng được triển khai.
- Library có `PhotoNoteSnapshot` gồm Photo Note, MediaAsset, primary ScanRun, detections và annotations. `LibraryRepository.getPhotoNoteSnapshot(userId, photoNoteId)` trả snapshot theo owner; `PhotoNote` có `deletedAt`; detection có `displayOrder`; annotation của chủ sở hữu có thể sửa từ. `displayOrder` là thứ tự hiển thị detection, **chưa có bằng chứng** rằng đó là thứ tự đáp án của game 1.
- Library hoạt động offline-first. Metadata từ cloud có thể tồn tại khi JPEG chưa được tải; cơ chế hiện hành chỉ tải ảnh sau hành động rõ ràng của người dùng. Game không được tự tải ảnh hoặc dùng cloud-only metadata như thể đã có ảnh.
- `docs/data/library_data_contract.md` định nghĩa effective vocabulary theo correction hợp lệ mới nhất → confirmation → prediction; đây là tài liệu draft. Khi triển khai, phải đối chiếu resolver Library thực tế, không tạo resolver cạnh tranh trong game.
- `AppCapability.premiumGames` tồn tại trong enum nhưng không được cấp trong `AppEntitlements.free` hoặc `.pro`; không suy ra hai game là Pro-only. Chính sách mở khóa là quyết định sản phẩm.

## 2. Mô hình chung và source of truth

| Dữ liệu | Chủ sở hữu | Source of truth mục tiêu | Bản sao/đầu ra |
|---|---|---|---|
| Ảnh, Photo Note, từ, correction | Tài khoản sở hữu Library | Owner-scoped local Library cho chơi offline; cloud sync chỉ cập nhật Library theo contract hiện có | Question builder chỉ đọc, không sửa Library |
| Nội dung một lượt (`run`) | Cùng owner | Snapshot câu hỏi bất biến được tạo từ Library ở `start`; chứa ID nguồn, revision/hash, đáp án chuẩn và rule version | UI render từ snapshot; không tính đáp án lại từ state màn hình |
| Câu trả lời và kết quả luyện tập | Cùng owner | Run state + append-only local learning/attempt event nếu được triển khai | UI/result, SRS theo contract riêng |
| Xu/phần thưởng có giá trị kinh tế | Cùng owner | Server coin ledger theo `coin_rules_plan.md`, sau khi có nguồn bằng chứng server xác minh | Không lấy local score/client callback làm bằng chứng cấp xu |

**Quy tắc mặc định khi chưa duyệt điểm/thưởng:** game chỉ hiển thị kết quả luyện tập; không sửa `study_points`, `total_coins`, SRS hoặc entitlement. Nếu sau này ghi learning event/SRS, cập nhật `db_status.md` cùng increment vì thay đổi offline Library persistence. Không dùng vị trí index trong list hoặc đường dẫn file làm identity; dùng owner + ID Photo Note/MediaAsset/detection và version của snapshot.

## 3. Mức nghiêm trọng và invariant chung

**P0:** lộ dữ liệu giữa tài khoản, dùng nội dung đã xóa, kết quả bị nhân đôi, chấm sai mà vẫn trao thưởng/xu, ghi trạng thái một phần hoặc tự tải media trái contract. Chặn rollout. **P1:** chấm/hiển thị sai nhưng không có thưởng hoặc mất dữ liệu, lỗi phục hồi lượt chơi, UX không thể hoàn thành. Sửa trước mở rộng rollout. **P2:** lệch trình bày không đổi kết quả; sửa theo chu kỳ UI.

| ID | Invariant | Enforce chính | Test | Mức |
|---|---|---|---|---|
| MG-I01 | Mọi source, run và attempt thuộc cùng `owner`; đổi/logout tài khoản không truy cập được run của owner cũ. | Repository owner filter + session fence | G-01 | P0 |
| MG-I02 | Câu hỏi chỉ dùng Photo Note active, media active, JPEG local tồn tại/đọc được và vocabulary hợp lệ; không tự tải cloud media. | Question builder + Library media resolver | G-02 | P0 |
| MG-I03 | Đáp án chuẩn của một question được chốt một lần trong run snapshot; UI shuffle/render không sửa đáp án. | Pure question builder + immutable model | G-03 | P0 |
| MG-I04 | Một `question_id` chỉ có tối đa một câu trả lời cuối cùng; một `run_id` chỉ có tối đa một kết quả hoàn thành và một learning event tương ứng. | Run state + unique local key/transaction | G-04 | P0 |
| MG-I05 | Điểm luyện tập, nếu có, chỉ derive từ các question đã chấm; không âm, không vượt tối đa theo rule version; không quy đổi tự động ra xu/XP. | Scoring domain | G-05 | P0 |
| MG-I06 | Số câu được chấm bằng tổng đúng + sai; câu chưa nộp không được tính là đúng/sai. | Run reducer | G-05 | P1 |
| MG-I07 | Snapshot đang chơi không bị sửa âm thầm bởi correction/sync mới; xóa/thu hồi nguồn đang chơi thì không tiếp tục dùng ảnh/từ bị xóa. | Run coordinator + Library invalidation | G-06 | P0 |
| MG-I08 | Retry, double-tap, app restart và callback đến muộn không tạo hai attempt/result/reward. | State machine + idempotency key | G-04, G-07 | P0 |
| MG-I09 | Chỉ câu hỏi có đáp án duy nhất theo normalization policy mới được đưa vào pool; thiếu hoặc mơ hồ thì skip, không tự đoán. | Question validation | G-08 | P1 |
| MG-I10 | Nếu chưa có question hợp lệ, game trả empty state rõ ràng; không tạo run rỗng hoặc điểm/thưởng. | Start use case | G-02 | P1 |

## 4. State và hợp đồng thao tác chung

`idle → loading → ready → answering → submitted → feedback → next/finished`. Nhánh lỗi: `loading → empty/error`, `answering → paused/aborted`, `submitted → unknown` khi lưu kết quả chưa rõ. `finished` và `aborted` là trạng thái cuối; không chuyển ngược sang `answering`.

| Thao tác | Điều kiện đầu vào | Kết quả đầu ra | Trường hợp lỗi |
|---|---|---|---|
| `start(owner, game_type, source_scope)` | Phiên owner hiện hành; quyền truy cập game nếu có; đủ câu hỏi hợp lệ; media local | `run_id`, frozen questions, `rule_version`, state `ready` | Chưa có media/từ: `empty`; lỗi đọc: `error`; không tạo run nửa vời |
| `submit(run_id, question_id, answer, attempt_id)` | Run của owner đang `answering`; question hiện hành; answer đúng schema; chưa nộp | Một verdict/feedback và attempt đã lưu; state `feedback` | Trùng cùng attempt trả cùng verdict; trùng khác answer trả conflict; sai owner/state bị từ chối |
| `next(run_id)` | Question hiện hành đã có verdict | Chuyển đúng một lần sang câu kế hoặc `finished` | Double-tap không bỏ qua câu; callback cũ không tác động câu mới |
| `pause/resume` | Run chưa kết thúc; owner không đổi; source còn hợp lệ | Khôi phục cùng question, answer draft và rule version theo chính sách lưu run | Nếu snapshot hỏng, media mất hoặc source bị xóa: `aborted` có lý do; không chấm từ dữ liệu đoán lại |
| `finish/quit` | Run hiện hành của owner | Result đúng một lần hoặc aborted không thưởng | Không ghi completion hai lần; quit không biến câu chưa trả lời thành đúng |

Khi offline, game được đọc local Library và chạy local. Sync/cloud không phải điều kiện bắt đầu. Nếu lựa chọn sản phẩm có lưu run, dùng transaction local owner-scoped cho attempt + progress + learning event; retry bằng cùng `attempt_id`/`run_id`. Nếu mất ACK giữa commit và UI, đọc lại run state thay vì chấm lại. Media cloud-only chỉ hiện hướng dẫn tải qua luồng Library do người dùng chủ động chọn. Việc có cho pause/resume qua app restart hay luôn hủy run cần chốt trước khi làm persistence; trong cả hai trường hợp không được mất hoặc nhân đôi kết quả đã commit.

## 5. Game 1 — Sắp xếp từ theo ảnh (`photo_order_quiz`)

**Chưa rõ từ repo:** người chơi sắp các thẻ từ theo thứ tự nào. Tên game không xác định đó là trái→phải theo vị trí đồ vật, thứ tự phát hiện, thứ tự câu chuyện hay một dãy đã biên tập. Rule dưới đây chỉ có hiệu lực khi mỗi câu hỏi có `canonical_sequence` **được tạo bằng cơ chế đã duyệt và có thể giải thích cho người chơi**. `displayOrder` của scan không tự động là đáp án đúng.

| ID | Rule: điều kiện vào → kết quả ra; cấm/edge | Enforce | Test | Mức |
|---|---|---|---|---|
| O-01 Chọn câu | Ảnh local hợp lệ, có ít nhất 2 mục từ active phân biệt, mọi mục có ID và vị trí trong `canonical_sequence` duy nhất → tạo cards và ảnh. Thiếu một điều kiện thì skip question. | Question builder | O-01 | P1 |
| O-02 Tạo đáp án | `canonical_sequence` là hoán vị đúng một lần của toàn bộ card IDs; question snapshot lưu sequence trước khi shuffle. Card trùng chữ được phân biệt bằng ID hoặc bị loại theo policy được duyệt. | Domain validator | O-02 | P0 |
| O-03 Tương tác | Người chơi chọn/sắp xếp mỗi card đúng một lần; undo/reorder trước submit được phép. Không tự nộp khi chạm cuối nếu rule UX chưa duyệt. | Provider reducer | O-03 | P1 |
| O-04 Nộp | Chỉ chấp nhận khi số card đã xếp bằng số card câu hỏi và không lặp ID → so sánh sequence theo IDs; trả correct/incorrect cùng feedback. Thiếu card/lặp/ID lạ: lỗi validation, không chấm. | Domain grading | O-04 | P0 |
| O-05 Sau nộp | Chốt verdict một lần, khóa sửa answer; hiển thị thứ tự đúng theo snapshot. Retry/double-tap không đổi điểm hay tạo event thứ hai. | Run reducer | O-05 | P0 |

Nếu sequence do người dùng tự biên tập, phải lưu nguồn/thời điểm/revision để có thể tái hiện đáp án. Nếu dùng bbox để suy ra thứ tự không gian, ảnh thiếu bbox hoặc nhiều vật chồng lấn phải bị loại hay được biên tập; không âm thầm chọn một thứ tự tùy ý.

## 6. Game 2 — Điền chữ theo ảnh đồ vật (`photo_letter_fill`)

Mỗi câu phải xác định **một target detection/annotation** trên ảnh. Nếu ảnh có nhiều đồ vật, UI phải chỉ rõ target (ví dụ vùng đánh dấu hoặc gợi ý); ảnh một mình không phải đáp án duy nhất. Effective word được lấy từ Library theo revision chốt lúc bắt đầu; không lấy `word_raw` nếu có correction hợp lệ mới hơn.

| ID | Rule: điều kiện vào → kết quả ra; cấm/edge | Enforce | Test | Mức |
|---|---|---|---|---|
| F-01 Chọn câu | Ảnh local và target active, effective word trong learning locale hợp lệ, target không mơ hồ → tạo question với target ID và đáp án frozen. Thiếu/không đọc được ảnh hoặc target bị reject: skip. | Question builder | F-01 | P1 |
| F-02 Hiển thị ô chữ | Số ô/keyboard phù hợp với phép tách ký tự đã duyệt; hỗ trợ ký tự Unicode và nhập bằng IME. Không dùng byte length để đếm chữ. Nếu từ có dấu cách, dấu nối hoặc nhiều đáp án, chỉ đưa vào pool khi policy tương ứng đã được duyệt. | Text/normalization domain + widget | F-02 | P1 |
| F-03 Sửa trước nộp | Cho nhập, xóa, thay chữ; ô rỗng được báo tại ô/đường hướng dẫn, không tạo attempt. `shakeEmpty`/viền cam chỉ là feedback UI, không là rule chấm. | Provider/widget | F-03 | P2 |
| F-04 Nộp | Answer không rỗng, đúng giới hạn độ dài và cùng question hiện hành → chuẩn hóa bằng một `normalizer_version` rồi so sánh với tập đáp án được duyệt; trả correct/incorrect. Không chấp nhận khoảng trắng/dấu/khác hoa thường theo phỏng đoán ngoài policy. | Pure grading function | F-04 | P0 |
| F-05 Sau nộp | Chốt verdict một lần, cho xem đáp án chuẩn và giải thích; không sửa answer để đổi verdict. Input đến muộn/submit lặp không tạo thêm event. | Run reducer | F-05 | P0 |

Normalizer phải có test cho tiếng Anh, Unicode, chữ hoa/thường, khoảng trắng đầu/cuối, apostrophe, dấu nối và ký tự tổ hợp. Không tự bỏ dấu hoặc gộp các từ khác nghĩa chỉ để tăng tỷ lệ đúng.

## 7. Lỗi, edge case và concurrency

| Tình huống | Kết quả bắt buộc |
|---|---|
| Không có Photo Note/từ đủ điều kiện | Empty state, hướng dẫn tạo/chọn nội dung; không sinh câu giả. |
| Cloud-only metadata, thiếu/hỏng JPEG | Skip câu; không tự download. Nếu đang chơi, pause/abort theo policy; không chấm ảnh không nhìn được. |
| Photo Note chuyển Trash/permanent delete trong lúc chơi | Ngừng hiển thị nguồn ngay khi Library báo invalidation; abort câu/run liên quan, không tạo câu mới từ nguồn đó. Learning event cũ tuân theo retention của Library. |
| Annotation đổi khi run đang chơi | Câu chưa bị xóa giữ frozen answer đến hết run; run mới dùng revision mới. Nếu correction khiến đáp án cũ không còn hợp lệ theo policy sản phẩm, abort câu thay vì chấm lặng lẽ bằng đáp án mới. |
| Hai thiết bị hoặc hai màn hình mở game | Run ID độc lập; cùng attempt ID không chấm hai lần. Thưởng có giá trị kinh tế, nếu sau này mở, phải được server kiểm tra idempotency và bằng chứng. |
| App crash sau lưu attempt nhưng trước feedback | Khôi phục verdict đã lưu; không tự tăng điểm lần hai. |
| Submit trong lúc loading/feedback/finished, stale callback | Bị từ chối hoặc trả trạng thái hiện có; không sửa state. |
| User logout/chuyển account | Hủy/ẩn run cũ, đóng media và cache owner cũ; account mới không thấy kết quả/ảnh cũ. |
| Entitlement thay đổi giữa run | Chỉ áp dụng gate đã duyệt; không ghi thưởng từ run không còn hợp lệ. Cần quyết định có cho hoàn thành run đã bắt đầu không. |

## 8. Nơi enforce

1. **Library repository/media resolver:** owner filter, active state, quyền đọc file, không tự tải cloud. Tái dùng Library contract thay vì query SQLite riêng trong widget.
2. **Question builder/domain:** chọn tập nguồn đủ điều kiện, effective vocabulary, target/canonical sequence, frozen snapshot, normalization version; hàm thuần để test.
3. **Run reducer/provider:** state transition, current question, undo, submit, feedback, pause/abort; loại event sai state hoặc callback cũ.
4. **Local persistence nếu có:** transaction cho run/attempt/learning event, unique IDs, owner partition, migration/recovery; cập nhật `db_status.md` khi triển khai.
5. **Server khi có xu/leaderboard:** xác minh bằng chứng và áp dụng ledger/RPC riêng. Client score hoặc local event không được tự ghi `total_coins`/`study_points`.
6. **UI:** chỉ render state, báo thiếu ảnh/từ, đáp án sai/đúng, trạng thái offline và accessibility. UI disable nút không thay thế validation domain.

## 9. Test chấp nhận

| ID | Kịch bản và kỳ vọng |
|---|---|
| G-01 | Account A/B cùng thiết bị, logout/login/cold restart: không thấy run, ảnh hoặc attempt của nhau. |
| G-02 | Active local, Trash, permanently deleted, cloud-only, file hỏng, không có vocab: chỉ active local hợp lệ được chọn; 0 tải tự động. |
| G-03 | Shuffle card hoặc rebuild widget: đáp án frozen giữ nguyên theo ID và rule version. |
| G-04 | 10 submit/retry song song cùng `attempt_id`: đúng một verdict/event; payload khác ID giống nhau bị conflict. |
| G-05 | Nhiều câu đúng/sai/bỏ dở: counts và score theo rule version, không âm/vượt max, không cộng xu/XP. |
| G-06 | Annotation sửa, Photo Note vào Trash/purge trong run: không leak nguồn xóa, run mới dùng revision mới. |
| G-07 | Crash sau commit, app resume, stale callback, double-tap Next: không nhân đôi/bỏ qua câu. |
| G-08 | Thiếu/ambiguous answer, từ trùng, unsupported token: skip thay vì chấm đoán. |
| O-01 | Ảnh có 0/1/2+ từ; chỉ 2+ item có sequence hợp lệ được chọn. |
| O-02 | Sequence thiếu/trùng/card lạ và thẻ có cùng chữ: validator loại hoặc định danh đúng bằng ID. |
| O-03 | Reorder/undo trước submit, double-tap sau submit: state đúng. |
| O-04 | Sequence đúng/sai/thiếu/thừa: chỉ full permutation được chấm. |
| O-05 | Sau verdict chỉ một attempt; đáp án đúng hiển thị theo snapshot. |
| F-01 | Ảnh một/nhiều object, target rõ/mơ hồ, corrected/rejected vocab: chọn đúng hoặc skip. |
| F-02 | Unicode, emoji, apostrophe, hyphen, nhiều từ, IME composition: số ô và input không cắt sai ký tự. |
| F-03 | Input rỗng/xóa/sửa: hướng dẫn và feedback, 0 attempt trước submit hợp lệ. |
| F-04 | Ma trận normalization đã duyệt: đúng/sai deterministic, version được lưu; answer quá dài bị từ chối. |
| F-05 | Correction đến sau submit, retry và stale input: verdict không đổi, không tạo event thứ hai. |

Test domain dùng fixture Library snapshot thực tế; widget test kiểm tra input/feedback/accessibility; SQLite integration test cho owner, transaction, restart và deletion; E2E trên thiết bị cho ảnh local/cloud-only và offline. Khi có server reward, thêm kiểm thử RLS, idempotency và concurrency tương ứng trong plan xu. Không coi test của scaffold hiện có là bằng chứng các rule này đã hoạt động.

## 10. Milestone và quyết định cần chốt

| Milestone | Exit criteria |
|---|---|
| M1 — Chốt sản phẩm | Có mô tả cơ chế sắp xếp của Game 1, target/đáp án Game 2, normalization, số câu, thời gian, điểm, quyền truy cập và thưởng. Ví dụ đúng/sai được duyệt. |
| M2 — Question builder | G-01 đến G-03, G-08, O-01/O-02, F-01/F-02 pass; không tự tải ảnh. |
| M3 — Gameplay | State/submit/feedback hoàn chỉnh; G-04/G-05, O-03 đến O-05, F-03 đến F-05 pass. |
| M4 — Persistence/offline | Owner-scoped run/attempt nếu được yêu cầu; crash/retry/deletion G-06/G-07 pass, cập nhật `db_status.md`. |
| M5 — Rewards/rollout | Chỉ nếu được duyệt: server verification, coin ledger, security/concurrency tests và staging smoke pass trước khi bật. |

**Cần quyết định trước khi code gameplay:**

1. Game 1 sắp xếp các từ theo tiêu chí cụ thể nào, và ai tạo/duyệt `canonical_sequence`?
2. Game 2 chọn đồ vật mục tiêu ra sao khi ảnh có nhiều object; có chấp nhận đồng nghĩa, số nhiều, dấu cách/dấu nối không?
3. Mỗi lượt có bao nhiêu câu, giới hạn thời gian, số lần thử, hint, bỏ qua và cách tính điểm?
4. Chơi game miễn phí hay cần entitlement; offline có đầy đủ chức năng không?
5. Có lưu tiến độ qua restart/thiết bị, cập nhật SRS/XP hoặc thưởng xu không? Nếu có, tần suất/giới hạn và bằng chứng server để chống farm là gì?
6. Source bị sửa/xóa hoặc quyền truy cập thay đổi giữa lượt thì abort toàn run hay chỉ câu liên quan?

**Mặc định trong khi chưa chốt:** không mở gameplay chấm điểm/thưởng; không dùng `displayOrder` làm đáp án Game 1; không chọn ngẫu nhiên một từ trên ảnh nhiều đồ vật cho Game 2. Các rule ở trên là contract mục tiêu, chưa phải trạng thái runtime hiện hành.
