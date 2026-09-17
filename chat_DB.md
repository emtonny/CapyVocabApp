# Chat & Training Data Plan

> Tài liệu nguồn cho kiến trúc chat người-với-người, dịch Gemini dùng chung và
> quy trình tạo dữ liệu sạch để huấn luyện SLM on-device trong tương lai.
>
> Cập nhật: **2026-09-17 — C3 operational raw chat COMPLETE trên Staging**
> Trạng thái: **C2 IMPLEMENTED/STAGING REST + REALTIME VERIFIED — approved
> backup/apply, 47 local SQL checks + 10 nhóm multi-user smoke pass, cleanup 0.
> History 23/23, dry-run up to date. C1 backend regression pass; approved pair +
> primary Settings/cache verified, general onboarding/second-account UI pending.
> C3A/B/C COMPLETE trên exact Staging. Web↔Android raw relay, cold Web restore,
> Android offline outbox/restart/reconnect/single-render và physical A→B→A cache
> isolation đều verified. Lost-ACK/idempotency + membership revocation được đóng bằng
> 57 client tests và live synthetic smoke 10/10. Final regression 495 pass/1 existing
> skip/0 failure; analyzer clean. Runtime vẫn opt-in `CHAT_RELAY_ENABLED`. C4/C5
> bilingual translation/correction chưa triển khai; Gemini/Training OFF.
> 2026-09-16 Android update/startup verified, chat DB created/Library+3 JPEG kept;
> device smoke PARTIAL (USB unauthorized, profiles/friend test setup pending).

> Later 2026-09-16 approval: accepted relation between the two named test accounts
> now 2 directions, owner/RLS verified both sides. Real Friends tab list implemented
> and verified on Android with exactly one peer for the signed-in account. Missing
> Android network-status channel was fixed for Chat + Library. 14 widget tests pass;
> full regression 492 pass/1 existing skip/0 failure, analyzer clean (89 combined
> chat), Staging APK build/install/cold launch pass. At that checkpoint C1 profiles
> were still unchanged; the latest checkpoint below supersedes that prerequisite.
> Production chưa apply C1/C2; C4–C6/T0–T5
> chưa triển khai. Training OFF.**

> Earlier setup checkpoint 2026-09-16: user confirmed primary `vi→en`, test peer `en→vi`.
> Two C1 rows verified on exact Staging; signed-in Android Settings/cache and picker
> verified, then real `open_direct_chat` created 1 conversation with 2 active members.
> At that point Messages/Gemini/Training/Production writes remained 0 and the live
> exchange was pending; the later checkpoints below supersede those C3 gaps.

> 2026-09-16 Web checkpoint: raw `flutter run -d chrome` without defines was using
> the Production fallback, not the Staging Auth database. A guarded `web-device`
> target now starts exact Staging with an environment banner. Real Chrome renders
> the existing responsive login UI; no schema/data/Production/Training write occurred.

> 2026-09-16 live raw checkpoint: Web→Android and Android→Web are now both rendered.
> The stale Web side was traced to hidden-tab lifecycle/timer gating plus a descending
> PostgREST UUID order that violated the ascending `gt` cursor; Realtime connect could
> additionally supersede the in-flight pull. Fixes are live-verified after cold reload:
> conversation/history HTTP 200 and both raw bubbles in the Web owner cache. Read-only
> table estimates remain 1 conversation/2 members/2 raw messages and 0 derived rows.
> Android offline enqueue/cold-restart/reconnect/single-render is verified. The final
> C3 gates above supersede the earlier partial state; C4/C5 have not started.

> 2026-09-16 Android parity checkpoint: the installed 13:22 APK predated the shared
> sync fixes from 20:26–20:58. Guarded Staging rebuild + `install -r` preserved both
> SQLite DBs and 3 JPEG. Cold-start detail grew from 3 to 7 bubbles with zero matching
> sync/Failed/Exception log, proving missing remote history recovery. A new live
> Web→Android event after this install was user-verified on 2026-09-17.

## 1. Mục tiêu đã thống nhất

1. Chuyển chức năng chat từ chat với AI thành chat trực tiếp giữa người dùng.
2. Tin nhắn thô phải đến người nhận ngay; dịch lỗi hoặc chậm không được chặn chat.
3. Mỗi cặp `(message, target language, translator version)` chỉ gọi Gemini một
   lần. Hai máy cùng đọc kết quả dịch đã lưu trên server.
4. Mỗi máy hiển thị hai ngôn ngữ theo hồ sơ của người đang xem.
5. AI Scan tiếp tục dùng Gemini để nhận diện/dịch nội dung ảnh nhưng **không còn
   là nguồn dữ liệu huấn luyện model**.
6. Lịch sử chat vận hành và kho dữ liệu huấn luyện là hai miền dữ liệu tách biệt.
7. Bản dịch, prompt, response và tag tự sinh bởi Gemini không được đưa vào
   dataset huấn luyện.
8. Chỉ mẫu có đóng góp thực sự của con người, consent hợp lệ và vượt qua kiểm
   tra an toàn mới được promote vào kho Training.

## 2. Sự thật của dự án hiện tại

### Đã có

- Supabase Auth và bảng hồ sơ `public.users`.
- Quan hệ bạn bè trong `public.friends`.
- Bảng legacy `public.chat_messages` đang có dạng:
  `id, user_id, message, is_ai_response, timestamp`.
- `chat_messages` đã được thêm vào Supabase Realtime.
- `supabase_flutter` và `flutter_tts` đã có trong dự án.
- Hạ tầng consent/lineage cho Library và AI local đã có nền móng, nhưng chưa
  phải consent dành cho chat training.
- C1 language profile đã apply/verify backend Staging; approved pair and primary
  Android Settings/cache pass, general onboarding + second-account UI pending.
- C2 schema/RLS đã apply và REST/Realtime backend verified Staging.

### Chưa đáp ứng luồng mới

- Bảng legacy không có conversation, người nhận, membership, ngôn ngữ, trạng
  thái dịch, correction hoặc idempotency key.
- RLS legacy chỉ cho người dùng thao tác row của chính mình; không thể phục vụ
  chat hai người đúng cách.
- Account cũ chưa khai báo C1 vẫn có profile unknown; không tự backfill.
- C3C đã có UI/route chat text Staging opt-in; chưa live client smoke hoặc
  dual-language UI hoàn chỉnh (C5). Production chat vẫn chưa rollout.
- Chưa có Edge Function dịch chat, single-flight hoặc cache bản dịch dùng chung.
- Chưa có quy trình gắn tag bởi người dùng, dual consent, promotion hoặc dataset
  builder cho dữ liệu chat.
- Đã có bằng chứng raw relay hai tài khoản trên Android + Web, Android offline
  reconnect, physical A→B→A, exact lost-ACK/idempotency và membership revocation.

## 3. Ba luồng dữ liệu bắt buộc tách riêng

### A. AI Scan — chỉ phục vụ tính năng

```text
Camera/Gallery
  -> Gemini Vision Scan
  -> kết quả scan
  -> SQLite/Library local
  -> Supabase private backup nếu người dùng bật Cloud Backup
  -X-> Chat Training DB
  -X-> dataset builder
```

Ảnh, raw Gemini response, vocab detection và bản dịch scan không được dùng để
train model chat/translation. Không cần xóa schema scan hiện tại; chỉ đóng đường
đưa dữ liệu scan vào dataset policy sau này.

### B. Operational Chat — vận hành sản phẩm

```text
Client A tạo message_id và lưu pending local
  -> INSERT raw_text vào Supabase
  -> Realtime relay raw_text tới A và B
  -> server claim translation job duy nhất
  -> Gemini dịch một lần
  -> lưu chat_translation
  -> Realtime đẩy cùng kết quả tới A và B
  -> mỗi client tự chọn dòng chính/phụ theo language profile
```

Miền này được phép giữ lịch sử cần thiết để hai người đọc lại chat:

- Câu nhập thô.
- Bản dịch Gemini dùng để hiển thị.
- Trạng thái gửi/dịch và correction.
- Metadata vận hành tối thiểu cho đồng bộ, chống trùng và chống abuse.

Miền này **không phải nguồn query của trainer** và không được export hàng loạt
sang pipeline huấn luyện.

### C. Training — chỉ nhận mẫu được promote rõ ràng

```text
Tin nhắn có giá trị học tập
  + A xác nhận tag trong ngôn ngữ nguồn
  + B tự viết câu đích tự nhiên
  + A chấp nhận câu sửa
  + A và B đồng ý đóng góp đúng mẫu
  + kiểm tra PII/nội dung/chất lượng
  -> promotion service tạo Training Candidate
  -> review/revoke gate
  -> immutable dataset manifest
  -> đánh giá SLM
  -> chỉ fine-tune khi benchmark chứng minh cần thiết
```

Không có đường kết nối trực tiếp từ bảng chat sang trainer. Chỉ promotion service
được phép tạo một bản ghi tối thiểu trong miền Training.

## 4. Luồng chat chi tiết

### 4.1 Khởi tạo cuộc trò chuyện

1. A và B phải đăng nhập và có quan hệ bạn bè `accepted`.
2. Server tạo hoặc trả về conversation 1:1 duy nhất cho cặp người dùng.
3. RLS chỉ cho thành viên hiện tại đọc conversation và message.
4. Client tải trang lịch sử có giới hạn, sau đó subscribe Realtime.
5. Mỗi client đọc language profile của chính mình để render; không ghi hai bản
   sao message chỉ vì thứ tự hiển thị khác nhau.

MVP không gồm group chat, attachment, voice message hoặc E2EE.

### 4.2 Gửi text và hoạt động offline

1. Client sinh `message_id`/`client_generated_id` trước khi gửi.
2. Tin nhắn được ghi vào local outbox và hiện ngay với trạng thái `pending`.
3. Khi có mạng, client gửi idempotent insert lên Supabase.
4. Server xác thực sender là member rồi ghi `sent_at` canonical.
5. Realtime chuyển row thô tới cả hai máy.
6. Retry cùng ID không được tạo message thứ hai.
7. Khi offline, người dùng đọc cache và soạn/gửi pending; ứng dụng không được
   gọi Gemini trực tiếp hoặc chờ network timeout để mở màn chat.

Thứ tự hiển thị dùng `sent_at` của server, với `client_created_at` và ID làm
tie-breaker. Raw text đã gửi là immutable; edit nếu được bổ sung sau phải có
revision/audit riêng.

### 4.3 Dịch đúng một lần

Translation key tối thiểu:

```text
(message_id, target_language_code, translator_version)
```

Luồng server:

1. Message insert phát sinh yêu cầu dịch nền.
2. Edge Function/RPC atomically claim translation key.
3. Unique constraint bảo đảm chỉ một worker được gọi Gemini.
4. Row chuyển `pending -> processing -> succeeded|failed`.
5. Khi thành công, lưu một output vận hành và phát Realtime.
6. Khi lỗi, raw text vẫn đọc được; retry có exponential backoff và giới hạn.
7. Hai client retry/refresh đồng thời vẫn đọc cùng row, không gọi Gemini lần hai.

Không đặt Gemini API key trong Flutter/Web client. Edge Function chat phải tách
khỏi `gemini-vision-scan` để quota, prompt, audit và rollout độc lập.

### 4.4 Render hai ngôn ngữ

Một message và một translation được render khác nhau theo người xem:

- Người học ngôn ngữ đích của translation: translation là dòng chính, raw text
  là dòng phụ.
- Người đang học ngôn ngữ của raw text: raw text là dòng chính, translation là
  dòng phụ.
- Nếu language profile không khớp hoặc translation chưa có: raw text là dòng
  chính và UI hiện trạng thái dịch rõ ràng.

Quy tắc render là logic client; không nhân đôi row để lưu “giao diện của A” và
“giao diện của B”.

## 5. Tagging kết hợp với chat

Tagging là thao tác học tập tùy chọn sau correction, không phải bước bắt buộc
khi gửi mọi tin nhắn.

### 5.1 Trải nghiệm đề xuất

Ví dụ:

```text
Raw của A:       Tối nay đi quẩy k bro?
Gemini display:  Are we going partying tonight, bro?
B sửa:           Hit the club tonight, bro?
```

Luồng:

1. B nhấn **Sửa giúp bạn** và tự viết câu đích tự nhiên.
2. Correction xuất hiện riêng dưới message; không ghi đè raw text hoặc bản dịch
   Gemini.
3. A chọn **Chấp nhận** hoặc **Từ chối** correction.
4. Sau khi chấp nhận, UI hỏi A: “Câu này có từ lóng hoặc viết tắt không?” với
   hai lựa chọn **Đánh dấu** và **Bỏ qua**.
5. A bôi đen span trong raw text, chọn loại và nhập dạng chuẩn trong chính ngôn
   ngữ nguồn.
6. UI hiển thị preview mẫu; A và B xác nhận consent đóng góp riêng cho mẫu đó.
7. Server kiểm tra điều kiện rồi mới promote.

Không làm popup tagging tự động cho mọi tin nhắn. Có thể gom lời mời tagging vào
inbox “Đóng góp học tập” để không làm gián đoạn chat.

### 5.2 Vai trò con người

| Vai trò | Trách nhiệm |
| --- | --- |
| A — người thành thạo ngôn ngữ nguồn | Chọn span, phân loại slang/viết tắt và ghi dạng chuẩn trong ngôn ngữ nguồn |
| B — người thành thạo ngôn ngữ đích | Tự viết `gold_target` tự nhiên |
| A | Chấp nhận/từ chối câu sửa để xác nhận đúng ý định câu gốc |
| Cả A và B | Đồng ý hoặc từ chối đóng góp mẫu vào Training |
| Gemini | Chỉ tạo bản dịch hiển thị trong Operational Chat |

Ứng dụng chưa có bằng chứng tự động rằng một người là “bản xứ”. MVP chỉ nên gọi
đây là ngôn ngữ người dùng tự khai báo/thành thạo; quality gate phải dựa thêm vào
review, consistency và benchmark.

### 5.3 Cấu trúc tag

Không lưu tag mơ hồ kiểu `quẩy = party`. Tag nên trỏ đúng span và chuẩn hóa trong
ngôn ngữ nguồn:

```json
{
  "span_text": "quẩy",
  "span_start": 12,
  "span_end": 17,
  "tag_type": "slang",
  "normalized_source": "đi chơi hoặc đi bar",
  "annotator_role": "source_speaker"
}
```

Các loại MVP:

- `slang`
- `abbreviation`
- `informal_address`
- `idiom`
- `typo_or_phonetic_spelling`
- `other`

Span offset phải được định nghĩa theo Unicode code point hoặc grapheme cluster,
không dùng byte offset. Quyết định kỹ thuật cuối phải đồng nhất giữa Flutter,
PostgreSQL và dataset builder.

### 5.4 Gemini gợi ý tag

MVP chọn cách sạch nhất:

- Người dùng tự chọn span và tự xác nhận dạng chuẩn.
- Có thể dùng từ điển local để gợi ý loại tag.
- Không gọi Gemini lần hai để sinh tag.

Nếu sau này thử Gemini tag suggestion, output chỉ được giữ trong miền vận hành
tạm thời, không tự động promote. Vì mẫu người dùng sửa từ output Gemini vẫn có
rủi ro điều khoản/nguồn gốc dữ liệu, tính năng này cần legal gate riêng.

## 6. Schema — C1/C2 contract và Training design

C1/C2 đã khóa contract SQL tại migrations và
[c2_operational_chat_contract.md](docs/data/c2_operational_chat_contract.md).
Annotation/consent/Training bên dưới vẫn là thiết kế chưa triển khai.

### 6.1 Hồ sơ ngôn ngữ

`user_language_profiles`

- `user_id`
- `native_language_code`
- `learning_language_code`
- `proficiency_level`
- `updated_at`

Mã ngôn ngữ dùng chuẩn ổn định như BCP 47/ISO đã chọn thống nhất; không lưu label
giao diện làm khóa dữ liệu.

### 6.2 Operational Chat

`chat_conversations`

- `id`, `kind`, `created_at`, `last_message_at`
- `participant_low`, `participant_high`; ordered unique pair, tạo qua RPC

`chat_members`

- `conversation_id`, `user_id`, `joined_at`, `left_at`
- unique `(conversation_id, user_id)`

`chat_operational_messages` — additive; không đổi legacy `chat_messages`

- `id`, `conversation_id`, `sender_id`
- `raw_text`, `source_language_code`
- `client_generated_id`, `client_created_at`, `sent_at`
- `deleted_at`, `moderation_state`
- unique `(sender_id, client_generated_id)`

`chat_translations`

- `id`, `message_id`, `target_language_code`
- `translated_text`, `provider`, `model`, `prompt_version`
- `translator_version`, `status`, `attempt_count`, `next_attempt_at`
- `error_code`, `created_at`, `completed_at`
- unique `(message_id, target_language_code, translator_version)`

`chat_corrections`

- `id`, `message_id`, `author_id`, `target_language_code`
- `proposed_text`, `status`
- `accepted_by`, `accepted_at`, `rejected_by`, `rejected_at`, `created_at`

`chat_slang_annotations`

- `id`, `message_id`, `created_by`
- `span_text`, `span_start`, `span_end`, `tag_type`
- `normalized_source`, `status`, `created_at`

`chat_training_consent_receipts`

- `id`, `candidate_key`, `user_id`, `role`
- `policy_version`, `decision`, `created_at`, `revoked_at`

Các annotation/consent trên vẫn nằm ở vùng chuẩn bị vận hành. Trainer không đọc
trực tiếp chúng.

### 6.3 Training schema

Giai đoạn đầu có thể dùng schema PostgreSQL riêng trong cùng project để không
cần project Supabase thứ ba, nhưng phải:

- Không expose bảng Training qua client API thông thường.
- Không cấp SELECT/INSERT trực tiếp cho `anon` hoặc `authenticated`.
- Chỉ promotion service có quyền ghi.
- Trainer chỉ đọc eligible view hoặc immutable export manifest.

`training.translation_candidates` đề xuất:

- `id`
- `source_text_sanitized`
- `source_language_code`, `target_language_code`
- `human_slang_annotations` dạng có cấu trúc
- `human_gold_target`
- `correction_mode = independent_human_write`
- `source_consent_receipt_id`, `target_consent_receipt_id`
- `consent_policy_version`
- `pii_review_state`, `quality_state`
- `promotion_version`, `created_at`, `revoked_at`
- `operational_source_ref` chỉ server nhìn thấy để xử lý revoke/delete; trường
  này không xuất vào dataset/model artifact

### 6.4 Cấm lưu/xuất vào Training

- Bản dịch Gemini.
- Gemini slang tags, prompt, response hoặc reasoning.
- Toàn bộ conversation context không cần thiết.
- Email, username, user ID, device ID hoặc định danh trực tiếp.
- Tin nhắn chưa có dual consent.
- Tin nhắn bị xóa, revoke, report hoặc chưa qua kiểm tra PII.
- Ảnh và dữ liệu từ AI Scan.

## 7. RLS và trust boundary

1. Client chỉ được insert message khi `sender_id = auth.uid()` và người gửi là
   member đang hoạt động của conversation.
2. Chỉ member được đọc message, translation và correction của conversation.
3. Client không được tự ghi `translated_text`, provider/model metadata hoặc đổi
   trạng thái job; chỉ service role/Edge Function được làm việc đó.
4. Người viết correction phải là member còn lại; người gửi raw text là người
   accept/reject.
5. Annotation ngôn ngữ nguồn chỉ do người gửi hoặc reviewer được ủy quyền xác
   nhận.
6. Promotion phải kiểm tra consent của cả hai phía tại server, không tin flag do
   client tự gửi.
7. Realtime không thay thế RLS; mọi bảng publish vẫn phải bị RLS chặn đúng.
8. Log không được chứa raw chat, API key hoặc nội dung nhạy cảm.

## 8. Consent, retention và xóa dữ liệu

### 8.1 Hai consent khác nhau

- **Chat service consent/privacy notice:** cần để vận hành lưu/chuyển tin nhắn.
- **Training contribution consent:** mặc định OFF, theo từng mẫu, tách biệt hoàn
  toàn với chat và Cloud Backup.

Bật Cloud Backup cho Library không đồng nghĩa đồng ý dùng chat để train.

### 8.2 Thu hồi

- Trước khi candidate vào manifest: revoke phải làm candidate không eligible.
- Sau khi vào manifest nhưng chưa train: invalidate manifest và tạo lại.
- Sau khi model đã train: ghi lineage để xác định run/model bị ảnh hưởng; policy
  retrain/unlearn phải được quyết định trước Production collection.
- Receipt tối thiểu có thể được giữ để chứng minh đã xử lý yêu cầu, nhưng không
  giữ nội dung đã thu hồi trong receipt.

### 8.3 Quyết định retention còn mở

- Lịch sử chat giữ bao lâu.
- “Xóa phía tôi” khác “thu hồi với cả hai” như thế nào.
- Có cho edit message hay chỉ delete/correction.
- Thời gian giữ failed translation/abuse metadata.
- Quy trình report, legal hold và account deletion.

Chưa khóa retention thì chưa được triển khai auto purge hoặc cam kết UI.

## 9. Chính sách Gemini — Production blocker

Trước khi bật chat dịch thật phải kiểm tra lại điều khoản hiện hành tại thời điểm
rollout:

- [Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms)
- [Gemini API Prohibited Use Policy](https://ai.google.dev/gemini-api/docs/usage-policies)
- [Zero Data Retention](https://ai.google.dev/gemini-api/docs/zdr)
- [Logs and datasets policy](https://ai.google.dev/gemini-api/docs/logs-policy)

Các điểm phải giải quyết bằng xác nhận pháp lý/Google trước Production:

- Ứng dụng có cho người dưới 18 tuổi dùng Gemini-powered chat translation không.
- Tier thanh toán/khu vực triển khai và việc Google dùng/giữ prompt-response.
- Không bật opt-in log/dataset sharing ngoài chủ ý.
- Khả năng dùng dữ liệu liên quan để phát triển model có cạnh tranh với Gemini.
- Nội dung chat có thể chứa dữ liệu cá nhân/nhạy cảm; cần cảnh báo, giảm dữ liệu
  gửi và chính sách moderation phù hợp.

Mặc định an toàn: không đưa output Gemini vào Training và không bật thu thập
Training cho đến khi các điểm trên được duyệt.

## 10. Kế hoạch triển khai theo milestone

### C0 — Product & policy decisions

**Mục tiêu:** khóa hành vi trước khi thiết kế migration.

- Chọn phạm vi tuổi và khu vực phát hành.
- Chốt retention/xóa/edit/report.
- Chốt correction cần A accept trước khi dùng.
- Chốt dual consent per-sample.
- Chốt ngôn ngữ MVP và cách xác định proficiency.
- Chốt training lưu cùng project ở schema riêng hay hệ thống riêng sau này.

**Đã khóa đủ cho C1:** MVP chỉ hỗ trợ cặp `vi`/`en`; ngôn ngữ do người dùng tự
khai báo; không suy đoán hoặc tự backfill account cũ; profile thiếu/không hợp lệ
phải fail-closed. Tuổi/khu vực, retention và consent Training vẫn chưa khóa nên
không được bật chat/thu thập Production.

**Trạng thái:** `PARTIAL` — đủ quyết định để hoàn tất C1; exit C0 đầy đủ vẫn chờ
các mục policy/retention/consent nêu ở phần 13.

### C1 — Language profile

- **IMPLEMENTED/LOCAL + STAGING BACKEND VERIFIED, UI SMOKE PENDING.**
- Đã thêm schema/profile RPC và cache local owner-scoped theo account.
- Onboarding/Settings đã cho chọn ngôn ngữ gốc, ngôn ngữ học và trình độ.
- Account cũ không bị backfill suy đoán; chưa có profile thì giữ trạng thái
  unknown cho tới khi người dùng tự chọn.
- Đã test unknown/corrupt, multi-user, đổi ngôn ngữ và offline cache.
- Migration `20260914120000_add_chat_language_profiles.sql` đã apply Staging
  sau encrypted backup và exact dry-run; history 22/22, post-apply up to date.
- Two-account backend smoke pass owner RLS, anon/cross-owner rejection, atomic
  onboarding, invalid pair rejection, server timestamp và RPC 8-arg compatibility.
- Fixture Auth/profile cleanup pass; demo account/Library không bị sửa.
- Production chưa apply C1; không có deploy Gemini hay thu thập Training.

**Exit local/backend Staging:** đạt. **UI rollout checkpoint:** còn Android/Web
onboarding/Settings/logout-login smoke; không kế thừa device evidence cũ cho C1.

### C2 — Operational chat schema & security

- **IMPLEMENTED/LOCAL SQL VERIFIED 2026-09-15:** additive migration
  `20260915120000_add_operational_chat_security.sql`; five-table RLS, restricted
  client INSERT, service-only translation writes, atomic direct-chat RPC,
  idempotency, immutable raw/derived content, indexes và Realtime publication.
- Bảo vệ friendship acceptance để sender không giả accepted; giữ flow accept
  và mirror UPSERT hiện tại.
- Audit Staging read-only: 0 legacy messages/0 friends. Không backfill;
  `chat_operational_messages` phục vụ chat mới. Legacy `chat_messages` vẫn đọc/
  ghi theo API cũ tới client cutover; không ép read-only làm hỏng client hiện tại.
- 47 native PostgreSQL SQL/RLS checks pass. User duyệt riêng gate Staging;
  backup mới verified, exact C2 applied 2026-09-15, history 23/23/up to date.
- Runner REST/Realtime ba synthetic accounts pass 10 nhóm, five-table
  subscriptions ready; A/B raw trước shared translation/correction; outsider
  REST empty/0 events trong cửa sổ test. Cleanup 0/baseline preserved.
- Contract: [c2_operational_chat_contract.md](docs/data/c2_operational_chat_contract.md).
- Không đổi Flutter/SQLite/Library/Training; chỉ schema + scoped fixtures Staging,
  không Gemini/Production. C1 regression 7 nhóm pass; Library vẫn 5 bài/10 objects.

**Exit local + backend Staging:** đạt. C3 cache/outbox/UI/reconnect chưa triển khai,
chưa tuyên bố device chat E2E. C0 retention/edit/delete/account cascade policy
vẫn cần chốt trước product rollout; C2 chưa cung cấp correction decision/client
delete API. Production cần approval riêng.

### C3 — Local-first text relay

- **C3A IMPLEMENTED/LOCAL VERIFIED 2026-09-15:** entity, separate SQLite chat v1,
  project+owner-scoped cache/message-as-outbox, atomic enqueue, immutable ACK/
  echo/canonical ID merge, ordering/local streams, complete-only membership/
  visible-history reconcile, single-flight/durable backoff/cap và stale-owner guards.
- 23 SQLite FFI + fake transport tests pass; full suite 426 pass/1 skip, analyzer
  clean. Chưa wire vào app hoặc gọi Supabase; không dependency/Library AI DB change.
- Contract: [c3a_operational_chat_local_contract.md](docs/data/c3a_operational_chat_local_contract.md).
- **C3B IMPLEMENTED/STAGING VERIFIED:** C3B.1 Staging-only SDK adapter:
  captured session JWT, insert/conflict/canonical ACK, RPC open-direct, keyset
  pagination/visibility verification, lazy one-channel Realtime invalidations
  và guarded detach/re-listen/disposal. Gateway hiện 26 tests, gồm fresh socket;
  runtime đã nối C3B.2 opt-in; live REST/Realtime smoke pass 10/10.
- **C3B.2 IMPLEMENTED/LOCAL VERIFIED:** SDK auth/current-token owner guard,
  cache-only language source; Android existing channel/Web navigator network gate;
  lifecycle opt-in host, single-flight refresh, per-ID visibility + atomic guarded
  SQLite apply, coalesced events/30s periodic repair/fresh socket restart và
  durable native-language deadline scheduler/100-row batches. 19 coordinator +
  7 provider tests; combined chat 75 pass, gateway now 26 including restart.
  Không được truyền paged history vào complete-snapshot reconcile của C3A.
  App host đã mount, mặc định OFF; live Web/Android chat đã verified trên Staging.
- Contract: [c3b_operational_chat_supabase_contract.md](docs/data/c3b_operational_chat_supabase_contract.md).
- **C3C IMPLEMENTED/STAGING WEB + ANDROID VERIFIED 2026-09-17:** inbox/detail
  routes + CTA từ Bạn bè, explicit accepted-friend picker (scoped ID-only paged
  read; open-direct RPC authoritative), cache-only history/profile, optimistic
  durable enqueue, pending/server-received/blocked states, owner-keyed draft reset.
  11 widget tests + analyzer pass; combined chat 86, full suite 489 pass/1 existing
  skip/0 failure và Web Staging build pass. Bidirectional client E2E, offline cold
  restart/reconnect và physical A→B→A owner isolation đã pass.
- Checklist: [c3c_operational_chat_ui_smoke.md](docs/data/c3c_operational_chat_ui_smoke.md).

**C3 overall:** COMPLETE trên Staging. Hai real authenticated clients đã gửi/nhận raw
text Web↔Android; retry không duplicate, inactive membership fail-closed, cold restore,
offline restart/reconnect và physical A→B→A owner-cache isolation đều verified.
C4/C5 song ngữ/hiệu chỉnh vẫn là milestone riêng và chưa được suy ra từ C3.

### C4 — Single-flight translation

- Edge Function riêng cho chat translation.
- Atomic claim + unique key + bounded retry/backoff.
- Secret/quota/circuit-breaker và safe logging.
- Client subscribe translation, không gọi Gemini trực tiếp.

**Exit:** hai clients và nhiều retry tạo đúng một Gemini call cho cùng key; raw
chat vẫn dùng được khi Gemini fail.

### C5 — Personalized dual-language UI

- Dòng chính/phụ dựa trên viewer profile.
- Loading/failed/retry states không nhảy layout khó đọc.
- Accessibility, copy/select text và responsive mobile/Web.

**Exit:** A/B thấy thứ tự ngôn ngữ đúng từ cùng một message/translation row.

### C6 — Learning interactions

- TTS bằng `flutter_tts` trên thiết bị.
- Tra từ ưu tiên vocabulary/dictionary local.
- Correction append-only, accept/reject và audit.
- Tagging thủ công theo span sau correction được accept.

**Exit:** correction không ghi đè raw/Gemini output; tag Unicode round-trip đúng.

### T0 — Training policy gate

- Privacy notice và consent copy riêng.
- Age/region/provider/legal review.
- Duyệt danh sách field được phép/cấm và revoke semantics.

**Exit:** có policy version và testable eligibility rules. Chưa đạt thì Training
pipeline tiếp tục fail-closed.

### T1 — Human contribution workflow

- Preview đúng mẫu trước consent.
- Dual consent receipt và withdrawal UI.
- Server kiểm tra roles, acceptance và source provenance.

**Exit:** thiếu một xác nhận bất kỳ thì không thể promote.

### T2 — Isolated Training store & promotion

- Tạo schema/quyền riêng cho Training.
- Promotion function chỉ copy field tối thiểu đã sanitize.
- Trainer credential không có quyền đọc Operational Chat.
- Revoke/delete propagation và audit receipt.

**Exit:** database tests chứng minh client/trainer không đọc được lịch sử chat;
promotion không thể chứa trường Gemini bị cấm.

### T3 — Quality review

- PII/content filtering, duplicate/conflict detection.
- Human review cho mẫu bất định hoặc bị report.
- Quality score dựa trên evidence, không dựa riêng vào self-declared native.

**Exit:** chỉ candidate `eligible` mới đi tiếp.

### T4 — Dataset builder & lineage

- Export chỉ eligible/non-revoked rows.
- Split theo contributor/conversation để tránh leakage.
- Immutable manifest chứa policy/promotion/builder version và hashes.
- Invalidate manifest/run/model khi nguồn bị revoke theo policy.

**Exit:** cùng input tạo manifest deterministic; không có định danh hoặc output
Gemini trong artifact.

### T5 — Benchmark trước fine-tune

- Đánh giá SLM baseline trên slang/abbreviation normalization và translation.
- Ưu tiên model hẹp cho normalization nếu giải quyết đủ bài toán.
- Chỉ fine-tune khi benchmark chứng minh baseline không đạt.
- Model activation phải có version, rollback và on-device resource budget.

**Exit:** có số liệu chất lượng, latency, RAM/storage và rollback; không tuyên bố
model sẵn sàng chỉ vì đã có dataset.

## 11. Thứ tự thực hiện đề xuất

```text
C0
 -> C1
 -> C2
 -> C3
 -> smoke hai tài khoản
 -> C4
 -> C5
 -> C6
 -> T0
 -> T1
 -> T2
 -> thu thập có consent
 -> T3
 -> T4
 -> T5
```

Chat vận hành có thể phát hành sau C5/C6 mà không cần chờ Training. T0–T5 phải
giữ OFF độc lập; việc thiếu pipeline train không được chặn người dùng chat.

## 12. Test gates bắt buộc

### Chat

- Hai account/member đọc đúng; account thứ ba đọc/ghi bị chặn.
- Người lạ hoặc friend chưa accepted không tạo conversation.
- Offline send -> restart -> reconnect gửi đúng một message.
- Realtime reconnect không duplicate hoặc mất thứ tự.
- Hai thiết bị nhận raw text trước translation.
- Cùng translation key tạo đúng một provider call.
- Gemini timeout/quota/failure không khóa chat.
- Logout/login account khác không lộ cache cũ.
- Delete/report/block tuân thủ quyết định C0.

### Tagging và Training

- B không thể tự xác nhận tag nguồn thay A trong luồng MVP.
- A không thể tự tạo `gold_target` rồi giả đóng góp của B.
- Correction chưa accept không eligible.
- Thiếu/revoke một consent không eligible.
- Unicode span vẫn trỏ đúng sau serialize/deserialize.
- Promotion rejects mọi Gemini output/prompt/response field.
- Trainer credential không SELECT được Operational Chat.
- Dataset export không có user ID, conversation ID hoặc source ref.
- Revoke trước export loại mẫu; revoke sau manifest invalidates lineage đúng.

### Rollout

- Local SQL/static tests trước.
- Staging migration dry-run và backup/audit.
- Staging two-user RLS + Realtime + Edge Function E2E.
- Android thật và Web smoke.
- Production cần gate phê duyệt riêng cho migration, Edge deploy, secret và bật
  feature flag.

## 13. Các quyết định đã khóa và còn chờ

### Đã khóa theo yêu cầu sản phẩm

- Scan dùng Gemini nhưng không dùng dữ liệu scan để train.
- Chat là người-với-người.
- Dịch một lần trên server và chia sẻ cho hai client.
- Operational Chat được giữ để vận hành, không nối trực tiếp trainer.
- Training không chứa bản dịch/tag/prompt/response Gemini.
- Tagging là tùy chọn; người dùng nguồn xác nhận tag, người dùng đích tự viết câu
  sửa, cả hai đồng ý mới promote.
- C1 dùng cặp ngôn ngữ MVP `vi`/`en`, self-declared, hai ngôn ngữ phải khác nhau;
  không tự đoán/backfill hồ sơ account cũ.

### Chờ duyệt tại C0/T0

- Tuổi tối thiểu, khu vực và nhà cung cấp dịch Production.
- Retention, edit, delete-for-me, revoke-for-both, report/block.
- Việc mở rộng ngoài `vi`/`en` và tiêu chí xác minh người thành thạo/người bản
  xứ cho đóng góp Training.
- Consent per-sample cuối cùng và cách rút consent sau khi model đã train.
- Training schema trong cùng Supabase hay hệ thống tách vật lý khi tăng quy mô.
- Có cần human moderator/reviewer thứ ba trước khi gắn nhãn `eligible`.

## 14. Phạm vi sau increment C1

- C1 đã sửa Flutter và apply migration lên Staging sau backup/test.
- Không deploy Edge Function hoặc thay secret.
- Staging chỉ thay schema C1 và tạo/xóa các fixture riêng; không đổi demo user.
- Không thay đổi Production hoặc database Training.
- Không thêm dependency.
- Không bật thu thập training.
- Không triển khai group chat, attachment, voice message hoặc E2EE.

## 15. Evidence C1/C2/C3

### 2026-09-17 — C3 COMPLETE: lost-ACK, membership và account switch verified

- Relay/coordinator/screen suite passed **57/57**, including durable lost-response
  retry with the same key, no duplicate canonical merge, late old-owner ACK rejection,
  account history/draft isolation and inactive-membership local pruning/blocking.
- Staging smoke baseline initially failed safely on PostgREST exact-count HEAD 206.
  Runner now accepts 200/206 only when exact `Content-Range` remains parseable.
- Rerun passed all **10** live synthetic REST/Realtime/RLS checks, including retry
  no-duplicate and inactive membership fail-closed; cleanup returned every baseline,
  fixtures remaining 0, Gemini calls 0 and Training writes 0.
- Android A→B→A is verified. B loaded `en→vi` with a distinct local owner scope; A
  then loaded `vi→en` and, with both radios disabled, reopened its original cached
  conversation/history/composer. No owner/profile/history/draft mixing was observed.
  Cloud Backup B stayed OFF (`Để sau`); no consent changed and no password entered
  tooling/logs. Network was restored to Wi-Fi OFF/mobile data ON; current-process
  chat-sync/Failed/Exception matches remained 0.
- Final analyzer clean; full suite **495 pass / 1 existing opt-in skip / 0 failure**.
  C3 is COMPLETE; C4/C5 translation/correction and Training remain OFF/pending.

### 2026-09-17 — Fresh post-install Web→Android receive verified

- User performed the requested Web send after APK replacement and confirmed the
  Android client received/displayed it. No additional synthetic message was needed.
- Historical logcat had rotated, so verification does not invent old log evidence.
  Independent cold start passed in 5,485 ms; detail reopened, chat SQLite was updated
  at 18:37 and the current foreground process had zero matching sync/Failed/Exception
  entries. Seven materialized viewport bubbles are not treated as a total DB count.
- Fresh Web→Android and earlier Android→Web/raw-history paths are now verified. C3
  remains PARTIAL for account-switch, induced lost-ACK and membership revocation.
  No schema/migration, Production, Gemini, translation, Training or Library write.

### 2026-09-16 — Android APK parity restored; missing remote history rendered

- Root cause of the reversed direction was a stale device artifact, not Web port 3001:
  Android package/artifact timestamps were 13:22/13:21 while the corrected shared chat
  source was 20:26–20:58. Phone was foreground and internet-reachable.
- Exact-Staging runner dry-run reported up-to-date/no migrations; Android build PASS
  in 110.2 s. `adb install -r` succeeded without clearing data. Two SQLite DBs and
  3 app-private JPEG were preserved; cold launch passed in 7,569 ms.
- Android detail rendered 7 bubbles after refresh versus 3 before replacement, so the
  missing remote history was restored. New-process log matches for `capy.chat.sync`,
  `Failed` and `Exception` were all zero.
- Startup pull is verified; a fresh post-install Web→Android Realtime event is still a
  separate live check. No schema/migration apply, Production, Gemini, Training or
  Library data mutation occurred.

### 2026-09-16 — Android offline queue/restart/reconnect verified

- Exact Staging Android build was identified by the in-app environment label before
  testing. One neutral diagnostic raw row was enqueued with Wi-Fi/data disabled;
  the device network probe was unreachable, so no server send could have preceded
  the optimistic local insert.
- The row survived process force-stop and a 5,527 ms offline cold activity launch.
  After Wi-Fi restore, it changed to server-accepted and remained exactly one render
  after a second 5,122 ms online cold launch. This proves durable pending → ACK →
  reconcile for the normal reconnect path, not delivery/read receipt or an induced
  lost-ACK race.
- Current Android process logs had zero matching `Failed`, `Exception` and
  `capy.chat.sync` failures. Temporary UI/screenshot artifacts were deleted. One
  operational Staging test message remains as normal chat history; Gemini,
  translation, Training, Production, schema and migration writes remain zero.
- C3 remains **PARTIAL** for account-switch, exact lost-ACK, membership revocation
  and receipt of this reconnect marker on the second client.

### 2026-09-16 — Bidirectional raw render and cold Web reload verified

- Exact Staging and the two approved accounts were reused; no new message, account,
  relation, profile or schema was created in this increment. Production was not called.
- Root cause 1: Web treated `hidden` like a native suspended app and disposed/paused
  sync; initial/resume work also depended on a throttled timer. Web now stays active and
  calls immediate single-flight reconciliation; native still pauses outside `resumed`.
- Root cause 2: `postgrest 2.9.1` defaults `.order()` to descending, but `_pages`
  requires monotonic ascending UUIDs with `gt`. Two history rows therefore failed closed
  as `Non-advancing chat page`. Chat and accepted-friend cursors now explicitly request
  ascending order. The fail-closed page guard remains unchanged.
- Realtime `connected`/`disconnected` now request a follow-up refresh without invalidating
  the REST snapshot already in flight; actual `changed` events still supersede/fence it.
- Live final evidence after cold reload: successful `chat_conversations` and
  `chat_operational_messages` HTTP 200 reads, then Web detail rendered two raw bubbles
  with correct incoming/outgoing alignment. No payload/token/UID was logged in diagnostics.
- `flutter test` for gateway/provider/coordinator: **54 pass**, including new explicit
  ascending-order and connect-during-inventory regressions. C3 remains **PARTIAL** for
  offline pending/restart, reconnect/lost ACK, account-switch and Android cold restart.
  Gemini translation/dual-language UI C4/C5 and all Training promotion remain pending.
- Final full suite: **495 pass + 1 existing opt-in skip, 0 failures**; analyzer clean.
  Guarded exact-Staging Web build PASS/130.5s after migration dry-run
  `upToDate=true`; existing flutter_tts Wasm/Cupertino font warnings are unchanged.

### 2026-09-16 — Two raw rows on Staging; Web incoming render still partial

- The two approved accounts exchanged one raw message in each direction. Android
  rendered the Web message. The reverse message did not immediately appear on Web.
- Safe linked-project table statistics report estimates of 1 conversation, 2
  active-member rows and 2 operational-message rows. Translation/correction estimates
  are 0; no message
  content, account ID, key or token was inspected or logged.
- Android filtered logs show no Chat/Realtime/WebSocket/PostgREST/Auth/Flutter error.
  The Web tab was hidden/online, which pauses the foreground-gated coordinator. When
  focused again it performed successful conversation/history requests (`HTTP 200`).
- Reopen-detail render is the remaining discriminator. No fix is claimed and no
  code/schema/Production/Gemini/Training write occurred. This is partial live C3
  evidence, not completion of C3 and not implementation of C4/C5 bilingual chat.

### 2026-09-16 — Guarded Web Staging runner + real login UI verified

- Diagnosed the reported Web login mismatch before changing Auth: raw Flutter Web
  had no Staging defines and therefore used the Production fallback config. The old
  local server later returned connection refused because it was stopped.
- Added interactive `web-device` + configurable `WebPort` to the existing runner.
  Exact linked/healthy Staging guard and migration dry-run still run first; public
  client config is temporary and cleaned on runner exit. `-ChatRelayEnabled` remains
  explicit and default OFF.
- The real Auth UI now has a visible `STAGING TEST · WEB` banner only when runtime is
  Web + exact Staging + Chat flag. Production/default/native behavior is unchanged.
  Browser screenshot confirms header, responsive login/register controls and form;
  this is not a mock page.
- Auth widget tests 14 pass at phone/wide constraints. Final full suite 493 pass +
  1 existing opt-in skip/0 failures after one transient full-suite failure and a clean
  rerun; targeted analyzer clean. Guarded Web Staging build PASS/99.6s; existing
  third-party Wasm/font warnings remain.
- No migration apply, schema/data/Storage write, Gemini, Training or Production call.
  C3 remains PARTIAL until the user completes demo Web login and two authenticated
  clients exchange/reconnect/offline-restart raw messages.

### 2026-09-16 — Approved test language pair + real direct-chat open

- User confirmed the account roles: primary `vi→en`, accepted peer `en→vi`;
  proficiency uses the existing `beginner` default. Exact healthy linked Staging only.
- Safe idempotent maintenance upsert/read-back produced exactly 2 C1 rows. Pair was
  resolved from the previously verified one-peer UI evidence and reciprocal accepted
  relation; no credential/identity was logged or committed. Production/Training untouched.
- Settings loaded the primary row through the normal provider into owner cache and
  displayed the correct pair. Chat inbox → Chat mới showed exactly one enabled peer;
  missing-language/runtime/fetch errors were absent.
- Selecting the peer passed the real `open_direct_chat` profile + friendship checks,
  committed the conversation locally, and opened empty detail with composer. Backend
  aggregate is exactly 1 conversation, 2 active members and 0 message; Gemini/Training 0.
- Sanitized device log counters for host/socket/PostgREST/Auth/Flutter/overflow are 0;
  both SQLite DBs + 3 local JPEG remain. No test message was inserted. Second-client
  receive/send, reconnect/no-duplicate and airplane-mode restart remain C3 exit gaps.

### 2026-09-16 — User-approved test friendship + accepted Friends tab

- Approved ONLY exact Staging pair acceptance; idempotent upsert of A→B/B→A
  to accepted after complete Auth/public-user resolution. Both owner JWT list reads
  verify reciprocal peer exactly once. No passwords/C1/consent/Production changes.
- Friends tab placeholder could not show DB relations. Added actual accepted ID
  list for opt-in exact Staging; reuse existing paged source, account key/guards,
  network loading/error/retry/empty states. No fabricated emails/names; card shows ID.
- Profile unknown does not hide friends; compose/open-direct still checks profile.
  Default/Production UI unchanged. No invitation/acceptance management UI implemented.
- 14 widget tests pass, including unknown-profile list/reciprocal account switch/
  offline zeroHTTP. Full suite 492 pass/1 existing skip/0 failure, exit0; JSON collector
  parseErrors=0. Combined chat 89, analyzer clean/exit0 (123.1s), format3files0changes/
  diff-check exit0.
- First on-device Friends view entered the truthful network error state. Root cause:
  Dart reused `com.capyvocab.app/network_status`, but current Android `MainActivity`
  had lost the handler documented at the 2026-09-11 checkpoint, so the shared
  Chat/Library network gate always failed closed. Restored the channel using
  `ConnectivityManager` and required INTERNET + VALIDATED network;
  added `ACCESS_NETWORK_STATE`. No dependency/schema/API or remote-data change.
- Post-fix: targeted Chat/Friends 21 pass; full suite 492 pass/1 existing opt-in
  skip/0 failure; targeted analyzer clean. Exact Staging Android build pass (92.6s),
  dry-run upToDate/no apply, temp define cleanup 0; `adb install -r` Success and cold
  launch Status ok/9281ms. Signed-in device UI shows exactly one accepted peer with
  accepted marker, no error/empty state. This is not a second-device chat exchange.
- Runtime counters after navigation: Failed host lookup/Socket/PostgREST/Auth/
  Flutter-unhandled/overflow/MissingPlugin each 0. Both SQLite DBs + 3 local JPEG kept.
- C3 PARTIAL: existing raw relay two-client/offline exit still pending. No Training.

### 2026-09-16 — C3C Android startup verified; live two-client prerequisites pending

- CPH2375 authorized initially; Staging Android debug build flags chat+Library ON
  PASS (143.2s), exact-ref guard/dry-run upToDate=true/no apply. `adb install -r`
  Success preserves data; activity cold launch Status ok/9727ms, Home visually rendered.
- Chat separate DB created; Library DB and 3 app-private JPEG preserved. New PID
  startup counters fatal/Flutter-unhandled/Failed host lookup/overflow each 0.
  Not equivalent to chat route UI or offline cold restart smoke.
- User explicitly approved second named test Auth account if absent: created
  confirmed/test-only Staging account, password login verified, existing passwords
  unchanged. Account retained for user testing, no credential/UID/session saved here.
- At this earlier checkpoint, both accounts had 0 C1 profiles and accepted friend
  directions=0.
  Test role setup and mutual acceptance not written; user approval requested.
- USB dropped during Friends navigation; device now unauthorized. Unlock/allow
  debugging required. **C3 PARTIAL**: route UI, actual two-client raw exchange,
  reconnect/no duplicates/offline restart/multi-account and Library regression pending.
- No app/Training schema/source/consent/Production changes; only explicit Auth create.

### 2026-09-15 — C3C inbox/detail/accepted-friend UI local verified

- `/chat` + detail UUID routes; opt-in exact-Staging CTA từ Bạn bè. Reuse shared
  graph-paper/tokens, responsive width; existing placeholder scrolls if short.
  Legacy chatbot APIs untouched; no dependencies/Library/AI schema/migration change.
- History/profile render cache-only; scoped draft reset, durable optimistic raw
  enqueue, pending/server-received/blocked states (not delivered/read receipts).
  Invalid/uncached/inactive deep-link and unknown language fail closed for composing.
- Explicit accepted-friend ID picker exhausts keyset pages, checks current token/
  owner/disposal; runtime/profile ready guard before open. RPC alone validates
  mutual accepted/profiles and creates canonical membership. No invite/accept UI added.
- 11 SQLite FFI/Auth/network widget tests pass; analyzer clean, format 6files/0changes.
  Includes offline 0HTTP, whitespace/emoji/Unicode limit, A/B history+draft isolation,
  profile-cache notification, canonical commit/route, phone+wide+keyboard and CTA gate.
- Test fixture compile/fake-clock/unique-peer/imperative URL issues corrected.
  Concurrent compile/full-suite exposed fixed-delay completion/failed-assert teardown
  race; use expected-state deadline/unmount-before-resource-cleanup, tests not skipped.
- Final Web Staging `-Target web-build -ChatRelayEnabled` PASS/exit0 (92.8s),
  chat+Library flags ON; dry-run upToDate=true/no apply. Existing Wasm/font warnings
  remain; not browser/device smoke. Final `flutter test --no-pub --reporter json`
  489 pass/1 existing opt-in skip/0 failure, exit0/done.success=true;
  collector parseErrors=0/truncated=false (preserves JSON fragments). Combined
  chat 86. Final analyzer clean/formatter 6files0changes/diff-check exit0.
  Test open awaits route/dialog completion, not fixed delay after SQL commit. adb empty;
  live two authenticated clients/reconnect/lost ACK/airplane-mode cold restart still
  **PENDING**, C3 **PARTIAL**. C4–C6/T0–T5/Training OFF; Production C1/C2 not applied.
- Next checkpoint: [C3C smoke](docs/data/c3c_operational_chat_ui_smoke.md).

### 2026-09-15 — C3B.2 runtime/cache scheduler local verified

- SDK auth/token/actual-owner providers, lifecycle host, local inbox/detail/cache
  language guards, Android channel/Web onLine network gate. Requires explicit
  CHAT_RELAY_ENABLED/exact Staging/foreground; Production/default builds OFF.
- Coordinator raw drain before pull, single-flight/150ms coalescing/2–300s
  backoff/30s periodic repair/fresh socket. Guarded per-ID inventory/history
  SQLite apply and durable current-native deadline/100-row scheduler implemented.
- `flutter test --no-pub test/features/chat`: **75 pass**; 26 gateway including
  actual SDK restart localhost, 19 coordinator/SQL, 7 provider/auth, 23 C3A.
  New local enqueue/ACK/fail guards reject session change while waiting SQL lock.
- Full-suite fixture failures diagnosed: first-tick offline/idle race and arbitrary
  5-second 101-row polling threshold. Tests now assert zero network/attempts and
  explicit batch completion with uniqueness/empty outbox checks still intact.
- Final `flutter test --no-pub --reporter json`: **478 pass + 1 opt-in skip,
  0 failures/exit0**; analyzer clean, final format 15 files 0 changes.
- `tool/run_staging_device_smoke.ps1` parser pass; optional -ChatRelayEnabled +
  web-build/exact Staging guard added. Dry-run upToDate=true, no apply/deploy.
  Final `./tool/run_staging_device_smoke.ps1 -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' -Target web-build -ChatRelayEnabled`:
  PASS/exit0, source cuối Web compile 93.8s, temp defines cleanup. Existing Wasm
  flutter_tts/Cupertino font warnings remain; not a browser/device/Wasm smoke.
- C3B IMPLEMENTED/LOCAL VERIFIED; C3 PARTIAL until C3C UI/live two-client/restart
  smoke. Operational Training/export OFF, Gemini translation C4 not implemented,
  Production/Library/scan DB unchanged. No commit/push.

### 2026-09-15 — C3B.1 Staging-only Supabase adapter local verified

- Thêm `OperationalChatSupabaseGateway`: private captured-JWT client, strict
  Staging+owner guard, immutable insert/conflict read ACK, open-direct RPC,
  keyset pagination đến empty và cached-ID visibility checks fail-closed.
- Lazy Realtime invalidations một channel/3 operational tables; session/channel
  generation fence, detach/re-listen và dispose đợi channel removal. Không tin
  payload event như complete snapshot; không nối paged history vào sweep C3A.
- SDK custom-token first-join race tái hiện bằng localhost: empty ref/no signal.
  Fixed headers + tắt resolver trên private Realtime instance giải quyết;
  không sửa SDK/global client/dependency. Unexpected disconnect recovery còn pending.
- `flutter test --no-pub test/features/chat/operational_chat_supabase_gateway_test.dart`:
  24 pass. `flutter test --no-pub test/features/chat`: 47 pass, exit 0 sau sửa
  fixture HTTP Response.request và chờ cả hai leave trước server teardown.
- Full regression lượt đầu fail ở teardown fixture WebSocket (449 pass/1 skip/
  1 failure). Sau fix, `flutter test --no-pub --reporter json`: exit 0,
  final `done.success=true`. Analyzer cuối sạch; format check 2 files 0 changes.
- Không remote call/migration/app wiring/Production/Gemini/Training. C3B.1
  local verified; C3B.2 runtime/reconcile/scheduler và C3C UI/live smoke pending.

### 2026-09-15 — C3A local foundation

- Targeted `test/features/chat/operational_chat_relay_test.dart`: 23 pass,
  disposable SQLite FFI + fake transport; không live remote/API/UI.
- Full suite `flutter test --no-pub`: 426 pass + 1 opt-in skip, exit 0.
- Analyzer rerun clean sau sửa 6 lint mới; format 5 files sạch.
- C3B/C3C/device browser smoke pending; không claim C3 exit đã đạt hoặc app
  đã chat được. Không Supabase/Production/Gemini/Training writes trong C3A.

### 2026-09-15 — C2 approved Staging apply và live backend smoke

- Backup mới DPAPI public/private + history verified: archive 146,004 byte tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T113034Z-c9e9c096`.
- 47 local SQL checks pass; exact dry-run/apply chỉ C2. Migration list 23/23,
  post-apply dry-run upToDate=true. Không gọi/ghi Production.
- `tool/run_staging_operational_chat_smoke.ps1`: 10 nhóm REST/real WebSocket
  checks pass với 3 synthetic accounts; five-table subscriptions, raw trước
  translation/shared derived, authorization/immutability/idempotency/inactive.
  Outsider REST empty/0 events trong cửa sổ test; cleanup Auth + counts baseline
  preserved. Gemini calls=0/Training writes=0; chưa C3 client/device smoke.
- Final rerun cũng pass 10 nhóm/cleanup 0: translation content trùng ở A/B,
  accepted correction nhận cả hai; parser/whitespace/diff checks sạch.
- C1 backend regression 7 nhóm pass và cleanup 0. Library audit vẫn 5 bài/10
  normalized private objects, không legacy/missing/mismatch/unreferenced;
  legacy chat/friends audit 0/0.

### 2026-09-15 — C2 local SQL verified, remote apply pending

- `pwsh -NoProfile -File .\tool\test_chat_operational_schema.ps1`: 47 SQL/RLS
  checks pass trong native PostgreSQL 18 cluster riêng; rollback/stop/cleanup,
  không Docker hoặc ghi remote. Bootstrap minimal, không full Supabase stack.
- `pwsh -NoProfile -File .\tool\audit_staging_chat_legacy.ps1`: read-only;
  legacy columns verified, 0 messages/0 friends. Không backfill, giữ legacy API.
- `npx supabase db push --project-ref nxteaznowkfennxpqjmt --dry-run`: chỉ đề
  xuất C2. Remote 22/local 23 migrations, chưa apply. Production không bị gọi.
- Realtime chỉ catalog verified; REST/WebSocket và client relay chưa smoke.
  Không Flutter/runtime/Training changes; C0 deletion/cascade policy pending.

### 2026-09-15 — Staging apply và backend smoke

- `tool/backup_staging_database.ps1 -SelfTest`: parser quoting/missing/duplicate
  và shell expansion rejection pass; PowerShell parser của hai runner sạch.
- Backup native PostgreSQL 18 `public` + `private`, migration history CLI riêng,
  DPAPI CurrentUser mã hóa ngoài repo tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T105000Z-805486b7`.
  Archive 133,403 byte; decrypt SHA-256 round-trip, persisted hash và
  `pg_restore --list` pass. Auth/Storage/ảnh object không thuộc dump này và không
  bị migration C1 thay đổi. Plaintext tạm đã xóa; restore cần cùng Windows profile.
- Backup ban đầu fail-closed do role selection: login tạm cần `--role=postgres`
  giống script CLI chuẩn; không tạo role/nâng grant để giải quyết.
- Local C1 tests chạy lại `8/8` pass trước apply; dry-run chỉ đề xuất đúng C1.
- `supabase db push --project-ref nxteaznowkfennxpqjmt --yes`: apply đúng C1;
  migration list 22/22, post-apply dry-run `upToDate=true`, không có migration còn chờ.
- `tool/run_staging_language_profile_smoke.ps1`: 7 nhóm kiểm tra pass, hai tài
  khoản fixture được xóa và profile baseline giữ nguyên. Không dùng demo account.
- Library audit Staging: 5 Photo Note/10 object chuẩn hóa, private bucket, không
  legacy/missing/mismatch/unreferenced; không gọi/ghi Production trong increment.
- `flutter devices`: không có Android kết nối. Widget tests C1 trên Chrome với
  `--timeout 30s` vẫn treo ở `loading`, không chạy assertion; runner đã dừng
  Ctrl+C. Không có Web UI test pass từ lượt này; live UI/account-switch smoke
  vẫn pending, không quy kết lỗi cho C1 khi chưa có reproduction/assertion.

### 2026-09-14 — Local implementation

- Targeted language/onboarding/settings: `43` test pass; sau hardening timestamp
  phía PostgreSQL, riêng Language Profile chạy lại `8/8` pass.
- Full Flutter suite: `403` pass, `1` opt-in test skip, `0` failure.
- `flutter analyze --no-pub`: sạch.
- `flutter build web --no-pub`: build thành công; còn warning Wasm từ
  `flutter_tts` và warning font Cupertino, không chặn JavaScript Web build.
- `supabase db push --project-ref nxteaznowkfennxpqjmt --dry-run`: chỉ đề xuất
  migration C1; không push và không ghi remote.

## 16. Quy tắc cập nhật tài liệu

Sau mỗi increment liên quan chat DB hoặc training data:

1. Cập nhật trạng thái milestone trong file này.
2. Cập nhật `db_status.md` trong cùng increment.
3. Ghi rõ `PLAN`, `IMPLEMENTED`, `PARTIAL`, `VERIFIED` hoặc `BLOCKED`.
4. Ghi lệnh test/evidence thật; không kế thừa kết quả cũ cho code mới.
5. Không ghi “đã sync/đã train” chỉ vì có queue, candidate hoặc manifest.
6. Mọi migration/deploy/Production rollout vẫn cần phê duyệt riêng.
