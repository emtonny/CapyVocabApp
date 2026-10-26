# Chat & Training Data Plan

> **Beta exact-Staging note 2026-10-22:** social group lifecycle đã live trên
> exact Staging: owner đổi tên/đóng nhóm, non-owner rời nhóm, closed group giữ
> history read-only, member/sender dùng public profile projection bounded và UI
> không còn hiển thị UUID khi đã có profile. Backup DPAPI verified tại
> `20261022T125142Z-463f91dc` (572.713 byte), apply đúng hai migration social,
> live transaction smoke pass 29/29, rollback cleanup 0 và post-dry-run sạch.
> Production untouched.
>
> **Local beta baseline trước rollout 2026-10-22:** social group lifecycle đã hoàn thiện local:
> owner đổi tên/đóng nhóm, non-owner rời nhóm, closed group giữ history read-only,
> member/sender dùng public profile projection bounded và UI không còn hiển thị
> UUID khi đã có profile. Migration
> `20261022120000_complete_social_group_beta.sql` thêm lifecycle + private audit;
> SQLite chat nâng additive lên v8 để giữ `social_owner_id`. PostgreSQL isolated
> pass 29/29, Chat targeted pass 92/92, full Flutter pass 798 + 1 opt-in skip,
> analyzer sạch, Web release và Android APK release build pass. UI mang nhãn
> `Beta`; tại checkpoint này hai social migrations còn pending exact Staging.
> Trạng thái đã được thay thế bởi note exact-Staging phía trên.

> **Gemini Chat translation note 2026-10-21:** Exact Staging đã backup DPAPI,
> apply riêng `20261021110000_add_gemini_chat_translation_v3.sql`, đổi worker
> sang provider `gemini`, model `gemini-3-flash-preview`, prompt
> `chat-translate-p3`, translator `chat-translate-v3` và deploy Edge Function
> v21. V1/v2 giữ nguyên để đọc lịch sử; tin mới chỉ enqueue v3. Live GT5 smoke
> pass 19 nhóm với `translation_mode=succeeded`, Realtime ba client và cleanup
> Auth/database 0. Social migration vẫn pending; Production untouched.

> **Social Group Chat note 2026-10-21:** local migration
> `20261021120000_add_social_group_chat.sql` thêm `kind='social'` cho nhóm chat
> thông thường. Cả tài khoản cá nhân và giáo viên đều có thể tạo nhóm tối đa 20
> người từ quan hệ bạn bè accepted hai chiều; membership MVP cố định sau khi
> tạo. Social group dùng raw chat, offline cache/outbox, Realtime và shared
> translation hiện có, nhưng không được dùng correction/manual annotation,
> Training promotion hoặc bất kỳ RPC nhiệm vụ/tiến độ/ảnh nào của learning
> group. Flutter có nút `Tạo nhóm chat` riêng và tái sử dụng model/cache group để
> giữ migration SQLite bằng 0. PostgreSQL cô lập pass 15/15; migration này chưa
> apply exact Staging hay Production. Chat/onboarding targeted pass 88/88; full
> Flutter pass 796 + 1 opt-in skip, analyzer sạch và Web release build pass.
> Client không select cột social mới trong inventory, nên direct/learning chat
> tương thích khi client chạy trước migration; RPC tạo social group fail-safe
> cho tới rollout.

> **Group Chat note 2026-10-20:** GT3 đã được triển khai và xác minh trên exact
> Staging theo
> contract tại `group.md`. Conversation được mở rộng additive cho learning group,
> còn C1–C6 direct chat 1–1 giữ tương thích. Group dùng lại raw message, offline
> outbox, Realtime và shared translation `vi↔en`; correction/manual tagging cùng
> Training promotion vẫn chỉ dành cho direct chat. Exact-Staging đã backup, apply
> đúng migration GT3, post-dry-run sạch và live smoke ba client/13 nhóm pass với
> cleanup 0. Gemini translation v3 hiện đã live-verified với
> `translation_mode=succeeded`. GT4 dashboard đã
> exact-Staging verified với owner-only invite metadata/moderation audit, SQLite
> detail cache offline và archived read-only. Smoke GT3+GT4 pass 16 nhóm, cleanup
> 0; Production chưa thay đổi.

> Tài liệu nguồn cho kiến trúc chat người-với-người, bản dịch dùng chung và
> quy trình tạo dữ liệu sạch để huấn luyện SLM on-device trong tương lai.
>
> Cập nhật: **2026-09-22 — CHAT C1–C6 STAGING VERIFIED**
> Trạng thái: **C2 IMPLEMENTED/STAGING REST + REALTIME VERIFIED — approved
> backup/apply, 47 local SQL checks + 10 nhóm multi-user smoke pass, cleanup 0.
> History 23/23, dry-run up to date. C1 COMPLETE: backend regression, approved
> pair, primary device Settings/cache và second-account owner-isolation UI verified.
> C3A/B/C COMPLETE trên exact Staging. Web↔Android raw relay, cold Web restore,
> Android offline outbox/restart/reconnect/single-render và physical A→B→A cache
> isolation đều verified. Lost-ACK/idempotency + membership revocation được đóng bằng
> 57 client tests và live synthetic smoke 10/10. Final regression 495 pass/1 existing
> skip/0 failure; analyzer clean. Runtime vẫn opt-in `CHAT_RELAY_ENABLED`. C4A
> contract, C4B PostgreSQL queue/claim, C4C worker core, C4D Gemini adapter, C4E
> client cache và C4F runtime reconcile đã complete local. C4G backup verified;
> Các migration đã apply exact Staging theo approval và post-apply dry-run sạch.
> Vault/`pg_cron`/`pg_net` cùng signatures đều verified; SQL C4B/C4G 58/58.
> Chat secrets tách riêng đã cấu hình, worker v18 `ACTIVE`, Vilao live success và
> synthetic multi-user/RLS/single-flight/cleanup smoke đều verified trên Staging.
> C4F regression:
> coordinator 26/26, cache 9/9, Chat 115/115, full Flutter 561 pass + 1 opt-in
> skip, analyzer sạch. C4G đã qua live gate; C5 song ngữ đã qua local, Android và
> Web↔Android hai-client live gate trên exact Staging. C5 COMPLETE. C6A đã thêm
> TTS `vi-VN`/`en-US` theo từng dòng raw/translation; local test, Android APK,
> exact-Staging live playback và cold restart pass. C6A COMPLETE. C6B bổ sung
> chọn span tiếng Anh → `Tra từ`, chỉ đọc vocabulary owner-scoped trong SQLite
> Library, ưu tiên correction mới nhất và không dùng network fallback. Local,
> Android exact-Staging và cold restart pass. C6B COMPLETE. Training OFF.
> C6C backend đã apply/verify exact Staging. CPH2375 đã mở dialog, gửi proposal
> hợp lệ Android→Staging và nhận đúng row/audit. Device smoke phát hiện rồi sửa
> vòng đời `TextEditingController` và guard ngôn ngữ khớp RLS; Chat 139/139,
> full Flutter 590 pass + 1 opt-in skip, analyzer sạch. Accept/reject UI trên
> raw-sender Web đã live verified nên C6C COMPLETE. C6D đã thêm
> manual Unicode span annotation sau accepted correction, SQLite v5 cache/outbox,
> source-speaker-only RLS/trigger và UI additive. Local SQL 17/17, Chat 149/149,
> full Flutter 600 pass + 1 opt-in skip và analyzer sạch. Migration C6D đã backup,
> apply và smoke trên exact Staging; Android APK build/cài/khởi động pass. Live
> Web raw sender đã accept correction và lưu tag `ok` `[0,2)` loại `other`, dạng
> chuẩn `đồng ý`; Web và Android peer cùng render qua Realtime, Android cold
> restart khôi phục đúng card/tag. C6 COMPLETE; Training OFF.
> C6E thay thao tác bôi đen mặc định bằng token picker: chạm một từ để chọn,
> chạm từ khác để mở rộng cụm, xem trước/bỏ chọn và có haptic phản hồi. Bôi đen
> theo ký tự được thu gọn thành fallback. Không đổi schema, RLS, rune offsets,
> outbox hay backend. Correction panel 7/7, Chat 149/149 và full Flutter 600
> pass + 1 opt-in skip; analyzer sạch. Exact-Staging APK build/cài/cold start
> trên CPH2375 pass và log nghiêm trọng bằng 0. Raw-sender Web đã dùng token
> picker lưu thêm tag `ok` `[0,2)` loại `slang`, dạng chuẩn `được`; read-only
> remote check xác nhận role `source_speaker`, status `active` và đúng actor.
> Luồng đảo chiều cũng đã pass: Android raw sender gửi
> `C6EANDROIDRAW0248`, Web đề xuất correction, Android chấp nhận rồi dùng token
> picker lưu span `[0,17)` loại `slang`, dạng chuẩn `android c6e`. Exact-Staging
> read-only check xác nhận correction `accepted`, annotation `active`, actor đúng
> raw sender; hồ sơ Web tạm đổi đã được trả về `vi -> en`. Android cold restart
> mở lại conversation và PID-scoped fatal log bằng 0.
> Không có chatbot riêng. UI và Edge Function chatbot tạo nhầm đã được gỡ.
> Key Vilao nằm server-side trong `chat-translation-worker` chỉ để dịch Chat
> người-với-người. Migration v2 và worker v18 đã deploy exact Staging; live
> synthetic Vilao smoke, RLS, single-flight và cleanup đều verified.
> Training OFF.

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
3. Mỗi cặp `(message, target language, translator version)` chỉ có một job và
   một kết quả dùng chung. Success path gọi provider dịch một lần; lỗi transient chỉ
   retry tuần tự theo cap đã khóa, không có hai provider call đồng thời.
4. Mỗi máy hiển thị hai ngôn ngữ theo hồ sơ của người đang xem.
5. AI Scan tiếp tục dùng Gemini để nhận diện/dịch nội dung ảnh nhưng **không còn
   là nguồn dữ liệu huấn luyện model**.
6. Lịch sử chat vận hành và kho dữ liệu huấn luyện là hai miền dữ liệu tách biệt.
7. Bản dịch, prompt, response và tag tự sinh bởi provider không được đưa vào
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
- C1 language profile đã apply/verify backend Staging; approved pair, primary
  Android Settings/cache và second-account owner-isolation UI regression đều pass.
- C2 schema/RLS đã apply và REST/Realtime backend verified Staging.

### Chưa đáp ứng luồng mới

- Bảng legacy không có conversation, người nhận, membership, ngôn ngữ, trạng
  thái dịch, correction hoặc idempotency key.
- RLS legacy chỉ cho người dùng thao tác row của chính mình; không thể phục vụ
  chat hai người đúng cách.
- Account cũ chưa khai báo C1 vẫn có profile unknown; không tự backfill.
- C3C đã có UI/route chat text Staging opt-in; C5 đã render song ngữ và qua live
  A/B client smoke. Production chat vẫn chưa rollout.
- Edge Function/single-flight/cache bản dịch dùng chung đã có và đã qua live
  Staging gate với Vilao v2.
- C6 đã có correction và gắn tag thủ công bởi người dùng; dual consent,
  promotion và dataset builder cho dữ liệu chat vẫn chưa triển khai.
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
  -> Vilao dịch một lần
  -> lưu chat_translation
  -> Realtime đẩy cùng kết quả tới A và B
  -> mỗi client tự chọn dòng chính/phụ theo language profile
```

Miền này được phép giữ lịch sử cần thiết để hai người đọc lại chat:

- Câu nhập thô.
- Bản dịch từ provider dùng để hiển thị.
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
   gọi provider trực tiếp hoặc chờ network timeout để mở màn chat.

Thứ tự hiển thị dùng `sent_at` của server, với `client_created_at` và ID làm
tie-breaker. Raw text đã gửi là immutable; edit nếu được bổ sung sau phải có
revision/audit riêng.

### 4.3 Dịch single-flight và dùng chung kết quả

Translation key tối thiểu:

```text
(message_id, target_language_code, translator_version)
```

Luồng server:

1. Message insert phát sinh yêu cầu dịch nền.
2. Edge Function/RPC atomically claim translation key.
3. Unique key kết hợp atomic claim/lease bảo đảm chỉ một worker giữ claim hợp lệ.
4. Row chuyển `pending -> processing -> succeeded|failed`.
5. Khi thành công, lưu một output vận hành và phát Realtime.
6. Khi lỗi, raw text vẫn đọc được; retry có exponential backoff và giới hạn.
7. Hai client retry/refresh đồng thời vẫn đọc cùng row và không tự tạo provider
   call; provider failure chỉ retry tuần tự theo contract C4A.

Không đặt provider API key trong Flutter/Web client. Edge Function chat phải tách
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
Dịch hiển thị:   Are we going partying tonight, bro?
B sửa:           Hit the club tonight, bro?
```

Luồng:

1. B nhấn **Sửa giúp bạn** và tự viết câu đích tự nhiên.
2. Correction xuất hiện riêng dưới message; không ghi đè raw text hoặc bản dịch
   hiển thị.
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
| Vilao | Chỉ tạo bản dịch hiển thị trong Operational Chat |

Ứng dụng chưa có bằng chứng tự động rằng một người là “bản xứ”. MVP chỉ nên gọi
đây là ngôn ngữ người dùng tự khai báo/thành thạo; quality gate phải dựa thêm vào
review, consistency và benchmark.

### 5.3 Cấu trúc tag

Không lưu tag mơ hồ kiểu `quẩy = party`. Tag nên trỏ đúng span và chuẩn hóa trong
ngôn ngữ nguồn:

```json
{
  "span_text": "quẩy",
  "span_start": 11,
  "span_end": 15,
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

Span offset dùng chỉ số Unicode code point zero-based, half-open `[start, end)`;
không dùng byte offset hoặc UTF-16 code unit. Flutter chuyển selection UTF-16
sang `runes`, PostgreSQL kiểm tra lại bằng `substring`, và dataset builder sau
này phải giữ cùng contract.

### 5.4 Gợi ý tag

MVP chọn cách sạch nhất:

- Người dùng tự chọn span và tự xác nhận dạng chuẩn.
- Có thể dùng từ điển local để gợi ý loại tag.
- Không gọi provider lần hai để sinh tag.

Nếu sau này thử provider tag suggestion, output chỉ được giữ trong miền vận hành
tạm thời, không tự động promote. Vì mẫu người dùng sửa từ output provider vẫn có
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

- `id`, `message_id`, `correction_id`, `created_by`
- `span_text`, `span_start`, `span_end`, `tag_type`
- `normalized_source`, `annotator_role = source_speaker`, `status`, `created_at`

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

- Bản dịch từ provider.
- Tag tự sinh, prompt, response hoặc reasoning của provider.
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

- **COMPLETE — LOCAL UI + STAGING BACKEND VERIFIED.**
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

**Exit C1:** đạt. Onboarding/Settings/logout-login, owner-scoped cache và đổi
tài khoản A→B đã có regression; exact-Staging smoke hai tài khoản pass 7 nhóm và
cleanup về baseline. CPH2375 cold-start rồi mở Settings/dialog đúng `vi→en` và
`beginner`; thao tác Hủy không ghi thay đổi. Chrome-platform runner bị dừng vì
treo ở `loading`, nên không được tính là browser pass.

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

- **C3A IMPLEMENTED/LOCAL VERIFIED 2026-09-15:** entity and initial separate
  SQLite chat v1 (subsequently upgraded additively to v3 by C3/C4E),
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

C2 đã có `chat_translations`, unique key
`(message_id, target_language_code, translator_version)`, trạng thái job,
`attempt_count`, `next_attempt_at`, RLS/Realtime và quyền ghi service-only. C4
chỉ bổ sung phần còn thiếu; không tạo bảng song song hoặc thay đổi raw-message
contract đã verify ở C3.

#### C4A — Khóa translation contract và test matrix

**Trạng thái 2026-09-18: COMPLETE / DOCUMENTATION VERIFIED.** Contract chuẩn:
[`docs/data/c4a_chat_translation_contract.md`](docs/data/c4a_chat_translation_contract.md).

- Chốt cách tạo job, xác định target language, `translator_version`,
  `prompt_version`, model policy, timeout, attempt cap và backoff.
- Chốt failure taxonomy: retryable, quota/circuit-open, malformed response,
  denied/inactive message và terminal failure.
- Chốt dữ liệu được phép log; raw/translated text, JWT và API key không xuất hiện
  trong log vận hành.
- Liệt kê test concurrency, stale lease, hidden/deleted message, provider failure,
  account isolation và raw-first behavior.

**Exit C4A: ĐẠT.** Contract không còn quyết định mở; schema delta và test cases
đã được ghi rõ. C4B hiện đã complete/verify local theo contract này; chưa apply
Staging, deploy, secret hoặc Gemini call.

#### C4B — Queue và atomic claim ở PostgreSQL

**Trạng thái 2026-09-18: IMPLEMENTED / LOCAL SQL VERIFIED.** Migration chuẩn:
`supabase/migrations/20260918120000_add_chat_translation_queue_claim.sql`.

- Dùng bảng `chat_translations` hiện có để enqueue idempotent, claim một job,
  complete success hoặc schedule failure/retry.
- Đã bổ sung additive claim token/lease/attempt timestamps, processing recovery
  index và private provider circuit state; không backfill message cũ.
- Function claim/complete/fail chỉ cho trusted service; client vẫn SELECT-only.
- Local PostgreSQL tests bao phủ nhiều worker cùng claim, unique key, lease hết
  hạn, retry cap, immutable success và message/member không còn hợp lệ.

**Exit C4B: ĐẠT Ở LOCAL.** Cùng translation key luôn có một row và một claim
winner tại mỗi thời điểm; worker chết có thể phục hồi bằng lease/token mới,
stale token không thể complete/fail. PostgreSQL 18 isolated suite **49/49 pass**,
gồm hai connection thật tranh cùng job. Apply Staging vẫn cần approval riêng.

#### C4C — Worker core độc lập provider

**Trạng thái 2026-09-18: IMPLEMENTED / LOCAL VERIFIED.** Source chuẩn:
`supabase/functions/chat-translation-worker/`.

- Tạo Edge Function riêng cho Chat translation; không ghép vào
  `gemini-vision-scan`.
- Worker chỉ làm orchestration: claim → đọc raw/profile hợp lệ → gọi adapter →
  validate → complete/fail; mọi dependency thời gian/fetch/provider đều inject
  được trong test.
- Timeout/cancel/retry không được sửa raw message hoặc làm hỏng relay C3.
- Unit/integration tests dùng fake provider, không secret và không network thật.

**Exit C4C: ĐẠT Ở LOCAL.** State machine qua đủ success, malformed, timeout,
retryable, terminal và lost-response cases; suite tại checkpoint C4C **28/28
pass**. C4D hiện đã nối adapter source; thiếu Chat Gemini key vẫn fail trước
claim. Chưa deploy hoặc gọi Gemini thật.

#### C4D — Gemini adapter và operational guardrails

**Trạng thái 2026-09-18: IMPLEMENTED / LOCAL VERIFIED.** Adapter chuẩn:
`supabase/functions/chat-translation-worker/gemini_provider.ts`.

- API key chỉ ở server; request gắn model/prompt/translator version rõ ràng.
- Validate response, giới hạn độ dài, timeout, quota, circuit breaker và safe
  error mapping; không log prompt, raw text, translated text hoặc credential.
- Fake HTTP tests xác nhận request/response contract, 429/5xx, invalid JSON,
  empty output và provider timeout.
- Live provider smoke là opt-in riêng, bounded và không dùng nội dung người dùng.

**Exit C4D: ĐẠT Ở LOCAL.** Native `generateContent` adapter deterministic với
fake upstream; request không retry/fallback nội bộ, key ở header và secret Chat
tách riêng. Adapter chuyển lỗi/`Retry-After` vào circuit state C4B; combined
Deno suite **50/50 pass**, type-check/lint/format và secret scan sạch. Chưa gọi
Gemini live, deploy hoặc coi C4 hoàn thành; C4E–C4G vẫn bắt buộc.

#### C4E — Client translation entity và cache local

**Trạng thái 2026-09-18: IMPLEMENTED / LOCAL VERIFIED.** Source chuẩn nằm trong
`lib/features/chat/domain/operational_chat.dart` và `data/operational_chat_*`.

- Thêm entity translation và SQLite owner/project-scoped bằng migration local
  additive; không nhét translation vào raw-message row.
- Supabase gateway đọc phân trang/Realtime invalidation từ `chat_translations`
  theo membership/RLS hiện có.
- Store upsert idempotent, giữ successful result immutable và chống stale owner,
  stale version hoặc account-switch leakage.
- C4E chỉ cache/stream dữ liệu; UI song ngữ thuộc C5 và chưa render ở đây.

**Exit C4E: ĐẠT Ở LOCAL.** SQLite v2→v3 migration, codec, merge/read stream,
success immutability, stale-state/version guard, owner/project isolation,
PostgREST pagination/RLS relation và Realtime invalidation đều pass. Chat
**108/108**, full Flutter **554 pass + 1 opt-in skip**, analyzer sạch. Raw chat
vẫn hoạt động khi translation rỗng/lỗi. C4F sau đó đã nối runtime reconcile; C5
chưa render song ngữ.

#### C4F — Runtime reconcile và subscription

**Trạng thái 2026-09-18: IMPLEMENTED / LOCAL VERIFIED.** Coordinator hiện commit
raw history và visibility trước, rồi mới pull/merge translation của từng
conversation theo version đã khóa.

- Realtime chỉ invalidation, các signal trùng được coalesce bởi single-flight và
  refresh version; reconnect tiếp tục bổ sung cache idempotent.
- Cold/offline tiếp tục đọc cache local. Lỗi translation fetch tạo backoff nhưng
  raw ACK/outbox đã commit vẫn đọc/gửi được.
- Epoch, invalidation và transaction guard loại kết quả muộn sau background,
  logout/account switch hoặc membership revoke.
- Client chỉ gọi Supabase gateway SELECT; không chứa Gemini key, provider HTTP
  call hoặc translation write.

**Exit C4F: ĐẠT Ở LOCAL.** Coordinator **26/26**, translation cache **9/9**,
toàn bộ Chat **115/115**, full Flutter **561 pass + 1 opt-in skip**, analyzer
sạch. Giao diện vẫn raw-only cho đến C5; exact-Staging rollout thuộc C4G.

#### C4G — Exact-Staging rollout và E2E gate

**Trạng thái 2026-09-19: STAGING LIVE VERIFIED / C4 COMPLETE.** Exact Staging
đã apply đúng năm migration: hai onboarding pending có trước, C4B queue, enable
`pg_net` và wake-up webhook/Cron. Post-apply dry-run `upToDate=true`; Vault,
`pg_cron`, `pg_net`, function signatures và worker `ACTIVE` đều verified. Hai
Edge secret dành riêng cho Chat và hai Vault entry đã được cấu hình; live Gemini
smoke hoàn tất mà không đọc lại key từ clipboard.

- Backup + migration dry-run trước; apply migration, set secret và deploy Edge
  Function chỉ sau approval riêng cho từng external write.
- Synthetic multi-worker smoke chứng minh nhiều wake-up đồng thời cùng key chỉ
  tạo một provider call trong success path và một successful shared row; failure
  retry tuần tự, bounded và không overlap.
- Hai client thật nhận raw trước, sau đó đọc cùng translation row; provider
  timeout/quota/circuit-open vẫn để raw chat hoạt động.
- Verify bounded retry, cold restore, account isolation, RLS outsider denial,
  safe logs, fixture cleanup và Gemini/translation counts chính xác.

Local gate có **58/58** SQL checks trên PostgreSQL tạm và **50/50** Deno
worker/provider checks. Migration wake-up đọc URL/trigger secret từ Vault, phát
`pg_net` request sau commit và có Cron mỗi phút; thiếu/sai secret hoặc lỗi mạng
không rollback raw message. Live runner khóa exact project/migration/function/
secret, từ chối trigger thiếu/sai, tạo ba account synthetic, xác nhận hai member
đọc cùng một Gemini translation row, outsider đọc 0 row, năm wake-up đồng thời
không tạo duplicate success, ba wake-up sau success đều idle và cleanup trở về
đúng baseline. Remote không có Training table nên worker không có đích ghi
Training; Production không được truy cập.

**Exit C4 / bắt đầu C5:** C4A–C4G đều đạt; exact Staging có bằng chứng
single-flight end-to-end. Production vẫn cần rollout approval riêng.

### C5 — Personalized dual-language UI

**Trạng thái 2026-09-19: STAGING A/B LIVE VERIFIED / C5 COMPLETE.**
Mailbox nổi và route `/chat` cùng subscribe translation cache local. Khung UI,
drag/dock, header, composer, nút gửi và raw text vừa cập nhật được giữ nguyên;
C5 chỉ bổ sung nội dung song ngữ cùng trạng thái dịch trong bubble.

- Dòng chính/phụ dựa trên viewer profile.
- Loading/failed/retry states không nhảy layout khó đọc.
- Accessibility, copy/select text và responsive mobile/Web.

Local evidence: cùng một row `vi→en` cho viewer native `vi` render translation
trước/raw sau; viewer native `en` render raw trước/translation sau. Raw luôn còn
selectable. Pending/queued/processing/automatic-retry/terminal-failure/cache-error
đều có nhãn ổn định và không chặn composer. Chat tests **118/118**, full Flutter
**564 pass + 1 opt-in skip**, analyzer sạch; Web build pass với cảnh báo Wasm
`flutter_tts`/Cupertino font có sẵn từ dependency. Mailbox 320px và route
phone/wide không overflow.

Android live evidence: guarded runner xác nhận exact Staging khỏe và migration
dry-run `upToDate=true`; APK Chat-enabled cài đè bằng `adb install -r` trên
CPH2375. Hai message smoke đi từ raw → worker → translation thành công. Câu
`xin chao day la kiem tra c5 android` render `hello this is android c5 check` ở
dòng chính `Bản dịch · Tiếng Anh`, raw ở dòng phụ `Tin gốc · Tiếng Việt`.
Cold restart 4.478 ms vẫn giữ đúng hai dòng từ cache; log đúng PID không có
fatal/Flutter/overflow/network/auth/sync match.

Device navigation check phát hiện route `/chat` chưa có entry từ màn Bạn bè.
Fix additive thêm đúng một nút `Mở trang Chat` cạnh `Làm mới bạn bè`; vị trí cuối
không chồng avatar/Cài đặt. CPH2375 xác nhận tap mở inbox full-screen, chọn row
mở detail và hai raw/translation pair vẫn hiện `Server đã nhận`.

Two-client live evidence: Web exact-Staging mở bằng guarded runner ở tài khoản
đối diện, mailbox hiển thị 11 unread và preview đúng Android marker mới. Cùng
message `xin chao day la kiem tra c5 android`/translation
`hello this is android c5 check` hiện trên cả hai client: Android viewer native
`vi` đặt translation trước/raw sau; Web viewer native `en` đặt raw trước/
translation sau. Web không overflow hoặc runtime error; Android PID 6481 có 0
error match. Runner và toàn bộ file dart-define tạm đã cleanup về 0.

**Exit local + Android + Web↔Android two-client live:** đạt. **C5 COMPLETE.**

### C6 — Learning interactions

- TTS bằng `flutter_tts` trên thiết bị.
- Tra từ ưu tiên vocabulary/dictionary local.
- Correction append-only, accept/reject và audit.
- Tagging thủ công theo span sau correction được accept.

Chia nhỏ để mỗi increment có gate độc lập:

- **C6A — TTS:** ANDROID LIVE VERIFIED / COMPLETE. Mỗi dòng
  gốc/dịch có nút nghe riêng, chọn đúng `vi-VN` hoặc `en-US`, giữ nguyên
  selectable text và touch target 48×48. Exact-Staging CPH2375 xác nhận hai
  locale, trạng thái đang phát, completion và cold restart.
- **C6B — Local vocabulary/dictionary lookup:** ANDROID LIVE VERIFIED /
  COMPLETE. Nhấn giữ/chọn span tiếng Anh giữ nguyên menu Copy và bổ sung
  `Tra từ`; bottom sheet chỉ đọc SQLite Library của owner hiện tại, ưu tiên
  correction active mới nhất, loại Photo Note đã xóa/tombstone và không gọi
  mạng. Có loading/empty/error/retry/result rõ ràng, touch target tối thiểu
  48×48 và không thay giao diện C5/C6A.
- **C6C — Append-only correction + accept/reject/audit:** TWO-CLIENT LIVE
  VERIFIED / COMPLETE 2026-09-21. B có thể tạo proposal riêng cho tin raw của A; proposal
  không thay raw hoặc Gemini translation. A là raw sender duy nhất có thể
  accept/reject qua RPC row-locked, idempotent; mỗi transition tạo audit event
  trigger-owned. SQLite Chat nâng additive v3→v4 với owner-scoped cache/outbox,
  retry/offline/account-switch/membership guards. Route Chat và mailbox chỉ thêm
  card `Sửa giúp bạn`, trạng thái và nút accept/reject; giao diện C5/C6A/C6B
  vẫn giữ nguyên. PostgreSQL 18 isolated **24/24**, C2 regression **47/47** và
  toàn bộ Chat **139/139**, full Flutter **590 pass + 1 opt-in skip**; analyzer
  toàn dự án sạch. Exact-Staging backup DPAPI verified, migration apply và
  post-dry-run `upToDate=true`; smoke ba account synthetic pass 9 nhóm, cleanup
  baseline/0 fixture/0 Gemini/0 Training. APK Chat-enabled build/cài/chạy pass
  trên CPH2375. Android proposal hợp lệ đã persist với đúng một audit event;
  profile test tạm đổi đã được khôi phục cả remote và cache. Device smoke đồng
  thời phát hiện/sửa controller dispose sớm và ẩn CTA khi native language không
  thỏa RLS. Web raw sender đã accept proposal thật; remote xác nhận đúng actor,
  trạng thái `accepted` và đúng một audit event. C6C COMPLETE.
- **C6D — Manual Unicode span tagging after accepted correction:** TWO-CLIENT
  LIVE VERIFIED / COMPLETE 2026-09-21.
  Raw sender chỉ được tạo tag sau correction đã accept; span dùng Unicode code
  point zero-based half-open và server xác minh lại đúng substring. Sáu loại tag
  MVP, normalized source và `source_speaker` được lưu riêng, không sửa raw hoặc
  Gemini output và không đi vào Training. SQLite Chat nâng additive v4→v5 với
  owner-scoped cache/outbox, retry/lost-ACK/account-switch/membership guards.
  PostgreSQL 18 isolated **17/17**, C6C regression **24/24**, C2 regression
  **47/47**, Chat **149/149**, full Flutter **600 pass + 1 opt-in skip** và
  analyzer sạch. Exact-Staging backup DPAPI 247.051 byte verified, migration
  apply/post-dry-run pass; smoke 10 nhóm với ba account và sáu Realtime table
  subscriptions pass, cleanup 0 fixture/0 Gemini/0 Training. APK Chat-enabled
  build/cài/khởi động và screenshot màn chính pass trên CPH2375. Web raw sender
  chọn span `ok`, loại `Khác`, normalized source `đồng ý` và lưu thành đúng một
  row `[0,2)`, `source_speaker`, `active`. Cả Web và Android correction-author
  render chip qua Realtime; Android cold restart khôi phục card/tag. C6 COMPLETE.

**Exit:** correction không ghi đè raw/Gemini output; tag Unicode round-trip đúng.

### Sau C6 — Chức năng Chat phụ trợ (DEFERRED)

- Chỉ bắt đầu thiết kế và triển khai chức năng phụ sau khi C6, milestone Chat
  cuối cùng hiện tại, đã hoàn thành và vượt qua đầy đủ test/runtime gate.
- Phạm vi ưu tiên sau C6 gồm gửi ảnh và sticker; attachment khác, voice message
  hoặc tiện ích tương tự phải được duyệt như increment riêng.
- Không dựng nút, preview hoặc trạng thái UI giả trước khi có contract end-to-end
  cho upload/Storage, message metadata, RLS, offline outbox, retry, retention,
  moderation và cleanup trên cả máy gửi lẫn máy nhận.
- Nút gửi ảnh thử nghiệm của C3 đã được gỡ vì chỉ giữ bytes trong RAM máy gửi và
  không truyền ảnh tới người nhận. Việc gỡ này không hủy yêu cầu gửi ảnh về sau.

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
 -> C4A contract
 -> C4B queue/atomic claim
 -> C4C worker core
 -> C4D Gemini adapter
 -> C4E client cache
 -> C4F runtime reconcile
 -> C4G Staging E2E
 -> C5
 -> C6
 -> chức năng phụ trợ Chat (ảnh, sticker, ...)
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
- Cùng translation key ở success path tạo đúng một provider call dù có nhiều
  wake-up; failure retry tuần tự theo cap và không overlap.
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

## 15. Evidence C1/C2/C3/C4/C5/C6

### 2026-09-27 — Exact-Staging Web/Android client handoff

- Guarded Web Staging session đang chạy tại `http://localhost:3000`, HTTP 200;
  Friends/Chat mặc định bật nhưng exact-project/session/RLS guards vẫn giữ.
- APK exact-Staging mới build và cài đè giữ data trên CPH2375 `665fdb60`;
  launcher foreground, PID `31217`, startup fatal markers 0.
- Production Web artifact trỏ đúng Supabase Staging đã build tại `build/web`;
  chỉ dùng cấu hình backend Supabase. Supabase Storage không host Flutter SPA vì HTML
  được trả dạng plain text, nên public HTTPS URL vẫn cần một static host riêng.
  Không Production/apply/push.

### 2026-09-26 — Friends/Chat final UX runtime gate (EXACT-STAGING VERIFIED)

- Operational runtime chủ động khởi tạo `languageProfileProvider` sau đăng
  nhập. Hồ sơ remote được đưa vào owner-scoped cache mà không cần người dùng mở
  Cài đặt; source/correction action và Friends→Chat tự cập nhật từ cache.
- Regression mới khóa trường hợp máy/tài khoản mới. Friends + Chat **206/206**,
  focused Chat UI/runtime **18/18**, analyzer sạch. Nhãn phụ Chat được nâng lên
  tối thiểu 12px; action chính vẫn có hit area 48dp và test 320px/large text.
- F6 email-only pass 8 nhóm trên exact Staging: username-only discovery,
  request/accept/reject Realtime, chống self/forged acceptance, symmetric list,
  canonical direct chat, outsider denial và exact cleanup.
- Chat correction/tag smoke pass độc lập; full smoke pass bằng active worker,
  immutable shared translation và 5-table Realtime. C6D annotation pass với
  source-speaker-only Unicode span và 6-table Realtime. Live Vilao E2E chuyên
  dụng VERIFIED; fixture còn 0, Training write 0.
- Không đổi schema/migration, không deploy, Production untouched và không push.

### 2026-09-22 — C1 second-account closure (COMPLETE)

- Thêm widget regression đổi Settings từ owner A `vi→en` sang owner B `en→vi`
  trên cùng cache; UI chỉ hiển thị hồ sơ B và không lộ hồ sơ A.
- C1 onboarding/Settings/auth-router/language-profile suite pass **45/45**; full
  Flutter pass **601 + 1 opt-in skip**, analyzer sạch.
- Exact-Staging `nxteaznowkfennxpqjmt` smoke pass 7 nhóm với hai account fixture:
  atomic onboarding, owner/anonymous RLS, invalid-pair rollback/constraint,
  server timestamp, legacy RPC compatibility và cleanup. Fixture còn lại `0`,
  profile baseline được giữ nguyên.
- CPH2375 cold-start `Status: ok` trong 5.290 ms; UI hierarchy xác nhận Settings
  `Tiếng Việt → Tiếng Anh · Mới bắt đầu` và dialog `vi`/`en`/`beginner`. Đã bấm
  Hủy, không đổi profile. Chrome-platform test treo ở `loading` và đã dừng nên
  không tính là pass. Không đổi schema, migration, Production hay Training.

### 2026-09-21 — Vilao for person-to-person Chat translation (STAGING LIVE VERIFIED)

- Chỉ giữ Chat người-với-người. Đã gỡ AI card/dialog Deery-sensei, source/test
  `chat-bot` và xóa function đó khỏi exact Staging.
- `chat-translation-worker` chỉ bật adapter Vilao khi
  `CHAT_TRANSLATION_PROVIDER=vilao`: HTTPS `/chat/completions`, bearer secret ở
  server, model `gemini-3.8-flash`, prompt `chat-translate-p2`, translator
  `chat-translate-v2` và không fallback model/provider.
- Raw message vẫn đến peer trước; translation được tạo một lần trong queue dùng
  chung và chỉ là dữ liệu hiển thị. Gemini/Vilao output không vào Training.
- Migration additive `20260921120000` giữ nguyên row v1, chỉ enqueue v2 cho tin
  mới; Flutter đọc cả v1/v2 và ưu tiên v2. SQLite Chat nâng v5→v6 tương thích.
- Deno **52/52**, Chat **149/149**, PostgreSQL **58/58**, full Flutter **600
  pass + 1 opt-in skip** và analyzer sạch. Migration đã apply exact Staging;
  `chat-translation-worker` v18 ACTIVE.
- Live E2E Vilao **VERIFIED**: đúng một provider attempt, hai member đọc cùng
  translation, outsider bị chặn, duplicate wake-up không sửa success và fixture
  synthetic được cleanup về baseline.
- Secret chuẩn là `CHAT_TRANSLATION_API_KEY`; alias `CHATBOT_API_KEY` và secret
  Chat Gemini cũ đã xóa. Không có source/function chatbot. Production untouched;
  Training OFF.

### 2026-09-21 — C6E tap-to-select annotation UX (TWO-CLIENT LIVE VERIFIED)

- Dialog gắn nhãn dùng token picker làm luồng chính: chạm một từ để chọn; chạm
  từ khác mở rộng span liên tục; chạm token đang nằm trong span để thu về token
  đó. Preview luôn hiển thị nguyên văn span và có nút `Bỏ chọn`.
- Token dùng `FilterChip` Material với vùng chạm tối thiểu 48 px, selected state,
  semantics mặc định và haptic selection. Dấu câu biên không trở thành token;
  cụm nhiều từ vẫn giữ nguyên khoảng trắng/dấu câu nằm giữa hai đầu span.
- Selection theo ký tự cũ được giữ trong mục mở rộng làm fallback cho trường hợp
  token hóa không đúng ý. Luồng lưu vẫn chuyển UTF-16 selection sang Unicode
  code-point `[start,end)` nên không đổi contract C6D, schema, RLS hoặc dữ liệu.
- Widget test correction panel **7/7 pass**, gồm viewport điện thoại 360×800,
  vùng chạm 48 px, chọn một từ, mở rộng cụm, bỏ chọn và trạng thái nút lưu.
  Toàn bộ Chat **149/149 pass**, full Flutter **600 pass + 1 opt-in skip**;
  Flutter analyzer toàn dự án sạch.
- Không thêm dependency, không deploy/apply backend, không ghi Production và
  Training vẫn OFF.
- Exact-Staging dry-run `upToDate=true`; APK debug build, cài đè và cold start
  trên CPH2375 pass, màn hình Chat không overflow và log nghiêm trọng bằng 0.
  Raw-sender Web đã dùng token picker và nhấn lưu; remote read-only check xác
  nhận row mới `ok` `[0,2)`, type `slang`, normalized `được`, role
  `source_speaker`, status `active`, actor đúng message sender và correction
  `accepted`. Phương án UX này được chốt.
- Luồng đảo chiều live cũng pass: Android raw sender gửi marker
  `C6EANDROIDRAW0248`; Web correction author tạo một proposal; Android nhận qua
  Realtime, chấp nhận, mở token picker, chọn token, xem preview và lưu nghĩa
  chuẩn `android c6e`. Exact-Staging xác nhận correction `accepted` bởi raw
  sender và annotation `C6EANDROIDRAW0248` `[0,17)`, type `slang`, role
  `source_speaker`, status `active`, creator đúng raw sender.
- Profile Web chỉ đổi tạm để thỏa language guard khi tạo proposal và đã được
  khôi phục `vi -> en`; read-only remote check xác nhận cả hai tài khoản về
  `vi -> en`. Android cold restart mở lại conversation/cache thành công;
  PID-scoped log có 0 `FATAL EXCEPTION`/`E/flutter`/unhandled exception.

### 2026-09-21 — C6D manual span tagging (TWO-CLIENT LIVE VERIFIED / C6 COMPLETE)

- Thêm `chat_slang_annotations` trong miền Operational Chat với FK tới raw
  message và accepted correction. Trigger khóa raw sender là người gắn tag,
  xác minh exact Unicode code-point substring, server sở hữu role/status/time và
  chặn update; RLS chỉ cho active two-member conversation đọc.
- Nâng riêng SQLite operational Chat v4→v5, thêm cache/outbox owner-scoped cùng
  retry bounded, lost-ACK readback, account/membership guards và merge bất biến.
  Coordinator đồng bộ correction trước annotation; Realtime chỉ làm invalidation.
- UI correction card chỉ bổ sung CTA sau accepted correction cho raw sender.
  Dialog giữ raw selectable, chọn một trong sáu loại tag, nhập normalized source
  và chuyển selection UTF-16 sang code-point `[start,end)`; raw/Gemini output và
  toàn bộ giao diện C5/C6A/C6B/C6C vẫn giữ nguyên.
- Local verification: PostgreSQL 18 C6D **17/17**, C6C **24/24**, C2 **47/47**;
  focused Flutter **108/108**, Chat **149/149**, full Flutter **600 pass + 1
  opt-in skip**, analyzer toàn dự án sạch và correction panel **7/7** sau khi
  sửa dropdown overflow.
- Exact Staging `nxteaznowkfennxpqjmt`: dry-run chỉ liệt kê migration C6D;
  backup DPAPI/`pg_restore` 247.051 byte `VERIFIED`; apply pass; hậu kiểm
  `upToDate=true`. Smoke ba account pass 10 nhóm gồm source-only Unicode tag,
  six-table Realtime, immutable/RLS/held/inactive-member; cleanup baseline, còn
  0 fixture, 0 Gemini call và 0 Training write.
- APK Chat-enabled build/cài/chạy trên CPH2375 Android 13; Supabase init và Dart
  VM pass. Web `…12e38bb1` được xác minh là raw sender, Android `…51a164ac` là
  correction author. Web accept proposal thật; remote có đúng một audit event.
- Web chọn `ok`, loại `Khác`, nhập `đồng ý` và lưu. Remote xác nhận đúng một row,
  offsets `[0,2)`, type `other`, actor raw sender, role `source_speaker`, status
  `active`. Hai client cùng render chip qua Realtime; Android cold restart mở lại
  vẫn render correction/tag và log nghiêm trọng bằng 0. C6 COMPLETE. Production
  không được ghi hoặc apply; Training vẫn OFF.

### 2026-09-20 — C6B local vocabulary lookup (ANDROID LIVE VERIFIED / COMPLETE)

- Thêm contract `LocalVocabularyLookupRepository` hẹp và implementation ngay
  trên `SqliteLibraryStore`; không mở rộng remote repository. Query validate
  owner UUID/limit, chuẩn hóa Unicode và dấu câu biên, chỉ đọc scan succeeded
  gắn với Photo Note active của đúng owner, loại tombstone và ưu tiên
  `vocab_annotations` active có revision mới nhất trước detection gốc.
- Mỗi dòng tiếng Anh selectable của UI C5 giữ menu chuẩn `Copy`/`Select all`
  và bổ sung `Tra từ`. Span rỗng, không phải tiếng Anh hoặc dài hơn 80 code
  point fail-closed. Bottom sheet nêu rõ Library local/không dùng mạng, có
  loading, kết quả, empty, error và retry; account switch trong lúc tra từ bị
  chặn trước/sau mỗi await.
- Không đổi raw/Gemini output, thứ tự song ngữ, TTS, composer, schema/version/
  migration SQLite hoặc Supabase, outbox/sync, cloud data, Production và
  Training. Không thêm dependency và không khôi phục ảnh/sticker đã defer.
- Test C6B tập trung **7/7 pass**: owner isolation, latest correction, trash,
  Unicode normalization, sheet states/retry/hit area, context menu giữ Copy và
  screen wiring đúng owner với zero HTTP. Full Flutter **575 pass + 1 opt-in
  skip**; analyzer sạch. Mobile audit heuristic nhận nhầm font/padding/icon
  không tương tác là touch target; widget test đo nút đóng/thử lại 48×48.
- Guarded runner khóa exact Staging `nxteaznowkfennxpqjmt`, migration dry-run
  `upToDate=true`; Android APK build pass, cài đè và chạy trên CPH2375. Trên
  thiết bị, chọn English text hiện đồng thời `Tra từ` + `Copy`; tra cả câu chưa
  lưu mở đúng local empty state. Positive local match/correction được SQLite và
  screen integration test xác nhận mà không tạo dữ liệu giả trên máy.
- Cold restart tạo PID 25514; quay lại Chat vẫn có hint C6B cùng UI C5/C6A,
  critical log match bằng 0. Runner android-build kết thúc sạch và file define
  tạm bằng 0. Phiên `flutter run` build/install/live trước đó bị kết thúc thủ
  công do session không có stdin detach nên trả mã 1 sau khi smoke đã hoàn tất;
  đây không phải lỗi ứng dụng hay build.

### 2026-09-19 — C6A per-language device TTS (ANDROID LIVE VERIFIED / COMPLETE)

- Tái sử dụng dependency `flutter_tts` hiện có; mở rộng `TtsService` từ locale
  cố định `en-US` sang mapping giới hạn `vi` → `vi-VN`, `en` → `en-US` và chờ
  utterance hoàn tất để UI phản ánh đúng trạng thái phát.
- Thêm nút nghe riêng cho từng dòng raw/translation trong message body C5. Raw
  vẫn selectable, thứ tự cá nhân hóa C5 không đổi, nút có tooltip/semantic từ
  Material và hit area được widget test đo đúng 48×48.
- Lỗi TTS chỉ hiện SnackBar có thể phục hồi; không sửa raw text, Gemini output,
  SQLite/Supabase schema, correction/tagging, Production hoặc Training.
- Test hẹp 5/5 pass; regression Chat + TTS 122/122 pass; full Flutter 568 pass
  + 1 opt-in skip; analyzer toàn dự án sạch; Android debug APK bật Chat build
  pass. Mobile audit heuristic gắn nhầm
  `fontSize`/`Icon` thành touch target nhỏ, trong khi widget test đo chính nút
  C6A là 48×48.
- Guarded runner khóa exact Staging `nxteaznowkfennxpqjmt`, xác nhận migration
  dry-run `upToDate=true`, build/cài APK lên CPH2375 Android 13 và tự cleanup
  dart-define tạm về 0. Không truy cập Production.
- Hai nút thật trong cùng bilingual message được phát qua Google TTS: English
  báo `eng-USA`/`en-US`, Vietnamese báo `vie-VNM`/`vi-VN`; cả hai đều có
  utterance started, AudioTrack active và completed. Ảnh trạng thái cho thấy
  spinner đúng từng dòng, không overflow và raw/translation vẫn hiện nguyên.
- Cold force-stop/launch tạo PID mới 18068, cache C5 và bốn nút loa của hai
  message vẫn phục hồi; phát English lần nữa có started/completed. Lọc log đúng
  PID có 0 fatal/Flutter/overflow/network/auth/chat failure match.

### 2026-09-19 — C5 Web↔Android A/B live gate verified (C5 COMPLETE)

- Guarded Web runner khóa exact Staging, migration dry-run `upToDate=true`, Chat
  relay bật và Supabase init thành công. Web đã có phiên tài khoản đối diện với
  Android; mailbox hiển thị 11 unread và preview đúng marker Android mới.
- Cùng canonical message lúc 17:32 và cùng translation content được render ở hai
  cache owner-scoped: Android native `vi` hiển thị English translation làm dòng
  chính/Việt raw làm dòng phụ; Web native `en` hiển thị Việt raw làm dòng chính/
  English translation làm dòng phụ. Đây là đúng hai nhánh personalized-order C5.
- Web conversation tải thành công sau initial spinner, không overflow hoặc lỗi
  Flutter/Supabase trong runner output. Android PID 6481 tiếp tục có 0 fatal,
  Flutter, overflow, host/PostgREST/Auth/MissingPlugin/chat-sync error match.
- Runner hiện tại đã dừng; file define của phiên và hai file stale từ 16/9 được
  xóa, final temp define count 0. Screenshot/UI artifact tạm không được giữ lại.
- C5 **COMPLETE** trên exact Staging. Hai smoke messages còn trong conversation
  demo theo bằng chứng người dùng; không migration/apply/deploy/secret,
  Production hoặc Training write ở bước A/B này. C6 là milestone tiếp theo.

### 2026-09-19 — C5 Android live translation smoke (PARTIAL LIVE VERIFIED)

- CPH2375/Android 13 được ADB authorize. Guarded runner khóa exact Staging
  `nxteaznowkfennxpqjmt`, `ACTIVE_HEALTHY`, migration dry-run `upToDate=true`;
  Production không được truy cập.
- APK C5 bật Chat relay build pass trong 201,0 giây và `adb install -r` thành
  công. Phiên đăng nhập, hội thoại cũ và SQLite được giữ; Chat DB chứa lịch sử
  trước đó cùng hai raw/translation cache mới sau restart.
- Mailbox, search, drag/dock shell, header, composer và send vẫn render ở
  720×1612. Hai tin smoke được gửi trong conversation hiện có; worker hoàn tất
  translation và UI hiện rõ primary English/secondary Vietnamese. Không có nút
  gửi ảnh/sticker.
- Device smoke phát hiện màn Bạn bè chưa có đường vào route `/chat`. Thêm một
  CTA `Mở trang Chat` cạnh nút refresh, không xóa UI cũ; đặt ngoài vùng avatar
  toàn cục. CPH2375 xác nhận CTA mở inbox, row mở route detail và hai bản dịch
  cached hiện đúng cùng trạng thái `Server đã nhận`.
- Cold restart `Status: ok`, `LaunchState: COLD`, 4.478 ms. Semantic tree sau
  restart vẫn chứa cả translation và raw của hai tin mới. Log PID 28603 có 0
  match cho fatal, Flutter error, unhandled exception, RenderFlex overflow,
  host/PostgREST/Auth/MissingPlugin hoặc `capy.chat.sync` error.
- Final CTA APK cài đè/cold-start thành công; PID 6481 có cùng error-match count
  0. Chat **118/118**, full Flutter **564 pass + 1 opt-in skip**, analyzer sạch.
- Đây là Android single-client live smoke. Hai-client A/B viewing cùng row vẫn
  pending trước khi đánh dấu C5 complete; không migration/apply/deploy/secret,
  Production hoặc Training change trong increment này.

### 2026-09-19 — C5 personalized dual-language UI (LOCAL VERIFIED)

- Thêm owner-scoped translation stream từ SQLite cache đã có; không gọi Gemini,
  không ghi translation và không tạo schema/provider contract mới.
- Thêm một message-body dùng chung cho mailbox nổi và route `/chat`: viewer native
  trùng source thấy translation ở dòng chính; viewer native trùng target thấy raw
  ở dòng chính. Profile thiếu/sai tiếp tục ưu tiên raw.
- Raw text luôn còn selectable. Loading, queued, processing, automatic retry,
  terminal failure và cache error dùng status line cố định; successful row hiển
  thị hai dòng có nhãn ngôn ngữ và semantic label cho screen reader.
- Giữ nguyên mailbox/drag/dock/header/composer/send và toàn bộ phong cách UI vừa
  cập nhật; không khôi phục nút ảnh đã defer sau C6.
- Verification: targeted overlay **6/6**, state + route **16/16**, toàn Chat
  **118/118**, full Flutter **564 pass + 1 existing opt-in skip**, analyzer sạch
  và Web build pass; cảnh báo Wasm `flutter_tts`/Cupertino font có sẵn không chặn
  build. Các widget check 320px và phone/wide không overflow.
- Không migration, deploy, secret, remote write, Gemini call, Production hoặc
  Training change. Live A/B client smoke còn pending trước khi gọi C5 complete.

### 2026-09-19 — C4G exact-Staging live gate verified

- Theo approval 1–4, `supabase db push --linked --yes` apply đúng năm migration
  đã dry-run: onboarding `20260916120000` + `20260917120000`, C4B queue
  `20260918120000`, enable `pg_net` `20260918125000` và wake-up/Cron
  `20260918130000` trên exact Staging; Production không được truy cập.
- Post-apply dry-run trả `upToDate=true`. Read-only SQL preflight xác nhận
  `pg_net`, `pg_cron`, `supabase_vault`, `net.http_post`, Cron functions và hai
  Vault relations đều tồn tại, không còn capability thiếu.
- Gemini auth key dành riêng cho Chat vượt model preflight rồi được đặt vào
  `CHAT_GEMINI_API_KEY`; internal trigger riêng được đồng bộ giữa Edge secret và
  Vault. Clipboard và plaintext temp đã được xóa; không log/commit secret.
- Deploy `chat-translation-worker` thành công; remote xác nhận đúng một worker
  `ACTIVE`, `verify_jwt=false`, hai Edge secret name và hai Vault entry.
- Final inventory giữ `CHAT_GEMINI_API_KEY` tách khỏi `GEMINI_API_KEY` của Scan.
  `chat-translation-worker` ở version 1; `gemini-vision-scan` vẫn `ACTIVE` và
  Supabase báo version 2 sau lượt cập nhật project secrets, dù không có command
  deploy nào nhắm vào source Scan.
- Lần smoke đầu sau deploy phát hiện runner chỉ đọc migration table trong khi CLI
  mới trả JSON; parser được sửa và self-test cả JSON/table. Lần tiếp theo phát
  hiện `training_examples` là bảng SQLite local-only, không phải REST table;
  baseline được giới hạn về năm operational table và PostgreSQL xác nhận remote
  không tồn tại Training table.
- Live smoke cuối **VERIFIED**: Gemini `gemini-3.5-flash-lite` tạo đúng một
  successful translation attempt; hai member thấy cùng row, outsider thấy 0;
  duplicate wake-up giữ nguyên success; ba synthetic Auth account và toàn bộ row
  liên quan được cascade cleanup, counts trở về baseline.
- Final local rerun: SQL **58/58**, Deno **50/50**, Flutter Chat **115/115**,
  analyzer/check/lint/format và ba PowerShell self-test đều sạch. Deno rerun đã
  thay lease fixture hết hạn theo ngày trong worker/handler test bằng một mốc
  future-only ổn định.
- C4G **COMPLETE** trên Staging; C4 đủ điều kiện bắt đầu C5. Production không
  được truy cập và vẫn cần approval rollout riêng.

### 2026-09-18 — C4G rollout prepared (LOCAL + READ-ONLY STAGING VERIFIED)

- Tạo backup exact Staging `public/private` dạng PostgreSQL custom archive, mã
  hóa DPAPI và verify round-trip/list; archive 193.285 byte, plaintext tạm đã xóa.
- Read-only capability query xác nhận exact linked Staging có Vault + `pg_cron`;
  `pg_net`/`net.http_post` chưa bật. Thêm migration prerequisite
  `20260918125000_enable_chat_translation_wakeup_extensions.sql` theo contract
  Supabase managed extension.
- Thêm additive migration `20260918130000_add_chat_translation_worker_wakeup.sql`:
  Vault-only URL/trigger secret, async post-commit `pg_net` trigger và recovery
  Cron mỗi phút. Missing/invalid config hoặc lỗi hạ tầng fail-open cho raw chat;
  function private bị revoke khỏi anon/authenticated/service role.
- SQL suite mở rộng **58/58 pass** trên PostgreSQL 18 tạm, gồm wake-up metadata-only,
  malformed/missing Vault config, duplicate raw, Cron và two-connection claim.
  Deno worker/provider suite vẫn **50/50 pass**.
- Thêm fail-closed read-only preflight và exact-Staging live runner. Runner yêu
  cầu ba migration C4, active Edge Function, hai Edge secret, fixed Staging ref,
  synthetic multi-worker/shared-row/RLS checks và cleanup về baseline.
- Dry-run exact Staging đề xuất đúng năm migration theo thứ tự:
  `20260916120000`, `20260917120000`, `20260918120000`, `20260918125000`,
  `20260918130000`. Hai migration đầu là onboarding pending có trước, nên không
  thể dùng `db push` để chỉ apply riêng C4B.
- Chưa apply migration, bật extension, ghi Vault/Edge secret, deploy function,
  tạo fixture remote hoặc gọi Gemini live. C4G vẫn **PARTIAL** cho đến khi từng
  external write được duyệt và live E2E/cleanup pass; C5 chưa bắt đầu.

### 2026-09-18 — C4F runtime translation reconcile (LOCAL VERIFIED)

- Nối coordinator theo thứ tự raw-first: complete history + visibility commit
  trước, sau đó mới `fetchTranslations` và merge cache theo conversation/version.
- Giữ Realtime payload ở vai trò invalidation-only; duplicate signal, reconnect
  và repair refresh dùng single-flight hiện có, không tạo provider call từ client.
- Session epoch/invalidation/transaction guard chặn late translation sau logout,
  account switch hoặc membership revoke. Offline giữ cache; translation fetch
  failure không xóa raw ACK hay làm pending outbox gửi lại.
- Cache bỏ qua response có `updated_at` cũ kể cả khi local đã success, nhưng vẫn
  từ chối mutation mới của successful row và identity/policy conflict.
- Verification: coordinator **26/26**, cache **9/9**, combined targeted **35/35**,
  Chat **115/115**, full Flutter **561 pass + 1 existing opt-in skip**, analyzer
  và `git diff --check` sạch.
- Không UI C5, remote schema/apply/deploy, secret, live Gemini call, remote write,
  dependency mới hoặc Training. C4G cần approval riêng cho external writes.

### 2026-09-18 — C4E client translation entity/cache (LOCAL VERIFIED)

- Thêm typed `OperationalChatTranslation` cho bốn trạng thái queue, policy cố
  định `chat-translate-v1`, timestamp UTC, stable error và output Unicode tối đa
  16.000 code point. Codec remote fail-closed với shape/policy/time sai.
- Nâng riêng Operational Chat SQLite từ v2 lên v3 bằng bảng
  `chat_translations`; row giữ `owner_scope=project:user`, unique translation key,
  FK cascade tới raw message và không thay đổi Library/AI database.
- Store merge-only chỉ nhận translation cho raw sent trong conversation active,
  giữ success immutable, bỏ response cũ theo `updated_at`, từ chối conflict cùng
  timestamp/attempt regression và cung cấp owner-scoped read/watch stream.
- Supabase gateway đọc phân trang `chat_translations` theo exact translator
  version và inner relation conversation dưới RLS hiện có. Realtime channel thêm
  table translation dưới dạng invalidation-only; client vẫn không ghi provider row.
- Verification: local cache/migration **8/8**, gateway **28/28**, toàn Chat
  **108/108**, toàn Flutter **554 pass + 1 opt-in skip**, analyzer sạch. Test bao
  phủ v2→v3 preserve raw, codec, idempotency, account/project isolation, stale/
  immutable/rollback/cascade, pagination và foreign-conversation rejection.
- Tại checkpoint C4E chưa nối coordinator C4F, không render UI C5, không
  dependency/schema remote, migration apply/deploy/secret/live Gemini/remote
  write hoặc Training. C4F sau đó đã complete local ở entry phía trên.

### 2026-09-18 — C4D Gemini adapter and guardrails (LOCAL VERIFIED)

- Thêm Native Gemini `generateContent` adapter cho model cố định
  `gemini-3.5-flash-lite`, prompt/version C4A và `thinkingLevel=MINIMAL`; raw text
  là user part riêng. Một claim chỉ có một HTTP request, không SDK retry, model
  fallback hoặc hidden repair request.
- `CHAT_GEMINI_API_KEY` chỉ được đọc trong Edge runtime và gửi bằng
  `x-goog-api-key`, không nằm trong URL/log. Thiếu key giữ handler fail trước
  queue claim; secret Chat tách biệt secret AI Scan.
- Guardrail chặn language/policy sai trước HTTP, map 401/403/408/429/5xx theo
  stable taxonomy, parse/cap `Retry-After` 5 phút và chuyển vào circuit/retry
  state machine C4B. Response chỉ nhận đúng một candidate `STOP`/một text
  nonblank tối đa 16.000 Unicode code point; blocked/truncated/ambiguous/JSON lỗi
  đều fail-closed.
- Fake HTTP tests mới **22/22 pass**; combined worker suite **50/50 pass**, gồm
  hai chiều `vi↔en`, exact request, missing key/policy mismatch, HTTP taxonomy,
  Retry-After, malformed/output invalid và worker timeout abort. `deno check`,
  lint, format và credential-pattern scan sạch.
- Tài liệu model/API chính thức được đối chiếu ngày 2026-09-18. Không dependency
  mới, không deploy/set secret, live Gemini call, webhook/Cron, migration/apply,
  remote write, Flutter/local DB hoặc Training. C4E là increment tiếp theo.

### 2026-09-18 — C4C provider-neutral worker complete (LOCAL VERIFIED)

- Tạo Edge Function riêng `chat-translation-worker` gồm HTTP trigger guard,
  Supabase queue RPC gateway và provider-neutral orchestration
  `claim → translate → validate → complete/fail`; không ghép AI Scan.
- Worker inject queue/provider/logger/time/abort, chỉ gọi provider một lần cho
  mỗi claim, timeout 15 giây, forward stable failure/retry-after và validate
  output trước complete. Version/lease sai fail trước provider.
- Lost completion response không ghi failure mâu thuẫn; database/fail persistence
  outage giữ row cho lease recovery. Log/HTTP response chỉ chứa metadata cho phép,
  không raw/translated text, claim token, credential hoặc exception body.
- Internal POST dùng `X-Chat-Translation-Trigger` constant-time comparison;
  user/wrong secret bị chặn. `index.ts` hiện cố ý không có provider C4D và trả
  `provider_not_configured` trước claim, nên source chưa hoàn chỉnh không tiêu
  hao attempt.
- Verification: Deno **28/28 pass** với fake queue/provider/HTTP; `deno check`,
  `deno lint`, `deno fmt --check` sạch. Sandbox Deno 2.9.5 gặp Windows named-pipe
  panic; cùng command chạy ngoài sandbox pass, đây là lỗi runner chứ không phải
  test failure.
- Chưa deploy, chưa cấu hình webhook/Cron/secret, chưa gọi Gemini hoặc remote
  database, không đổi C4B schema/local Flutter Chat DB/Training. C4D tiếp theo.

### 2026-09-18 — C4B queue/atomic claim complete (LOCAL SQL VERIFIED)

- Thêm additive migration `20260918120000_add_chat_translation_queue_claim.sql`:
  enqueue v1 transaction-local, claim token + lease 60 giây, attempt cap 4,
  processing recovery index và private per-version circuit state.
- Ba `SECURITY DEFINER` RPC service-only thực hiện claim/complete/fail; client và
  service-role direct table mutation bị chặn. Policy snapshot và successful output
  immutable; raw message/RLS/Realtime contract C2 được giữ nguyên.
- Retry tiers `5s/30s/2m`, Retry-After cap 5 phút, transient circuit, auth/quota
  circuit, terminal/ineligible/policy mismatch và stale-token behavior đã được
  kiểm tra bằng dữ liệu synthetic.
- `tool/test_chat_translation_queue.ps1`: **49/49 pass** trên PostgreSQL 18 tạm,
  gồm hai kết nối thật chứng minh `FOR UPDATE SKIP LOCKED` chỉ có một claim winner;
  C2 correction regression pass, cleanup temp cluster pass, remote writes 0.
- Chưa apply migration lên Staging/Production, chưa cấu hình webhook/Cron/secret,
  chưa deploy worker và chưa gọi Gemini. C4C là increment tiếp theo.

### 2026-09-18 — C4A translation contract complete (DOCUMENTATION VERIFIED)

- Khóa target deterministic `vi↔en`, job key/version, Gemini native model không
  fallback, secret Chat riêng, timeout 15 giây, lease 60 giây, tối đa 4 provider
  attempts và backoff `5s/30s/2m`.
- Chốt enqueue transaction-local nhưng provider async; claim token + expiry,
  `FOR UPDATE SKIP LOCKED`, stale-response rejection, provider circuit policy,
  failure taxonomy và safe-log allow/deny list.
- Ghi schema delta additive bắt buộc cho C4B và ma trận test DB/worker/client/
  exact-Staging trong `docs/data/c4a_chat_translation_contract.md`. Raw message
  vẫn là nguồn chuẩn; không backfill message cũ, không nối Training.
- Verification tài liệu/diff thực hiện local. Không tạo migration/code worker,
  không deploy, không set secret, không remote write và không gọi Gemini.

### 2026-09-18 — C4 split into bounded increments (PLAN)

- Chia C4 thành C4A–C4G: contract, PostgreSQL queue/claim, provider-neutral
  worker, Gemini adapter/guardrails, client cache, runtime reconcile và exact
  Staging E2E.
- Mỗi increment có exit gate riêng; C5 không bắt đầu trước khi C4G chứng minh
  single-flight end-to-end và raw chat vẫn hoạt động khi provider lỗi.
- Kế hoạch tái sử dụng bảng `chat_translations`/unique key/RLS/Realtime đã có từ
  C2; không tạo schema song song. Migration/deploy/secret/Staging write vẫn cần
  approval riêng, chưa thực hiện trong increment tài liệu này.

### 2026-09-18 — Deferred image/sticker features until after C6 (DOCUMENTED)

- Khóa thứ tự triển khai theo yêu cầu sản phẩm: hoàn thành và verify C4–C6 trước,
  sau đó mới bắt đầu gửi ảnh, sticker và các chức năng Chat phụ trợ.
- UI chọn ảnh C3 đã được gỡ để tránh gây hiểu nhầm về khả năng gửi ảnh hiện tại;
  yêu cầu gửi ảnh vẫn được giữ trong backlog sau C6.
- Không thay đổi schema, migration, Storage, relay, cloud data, Gemini hoặc
  Training trong cập nhật tài liệu này.

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
