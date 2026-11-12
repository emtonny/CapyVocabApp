# Kế hoạch Group Chat, Nhóm học và Không gian Giáo viên

> Cập nhật: **2026-10-22**
>
> Trạng thái: **BETA EXACT-STAGING VERIFIED; GT5 + GEMINI V3 + SOCIAL CHAT LIVE**
>
> GT3 đã mở rộng chat hiện có theo hướng additive cho learning group, giữ direct
> chat tương thích, thêm SQLite v7, inbox/detail, offline outbox, Realtime,
> translation `vi↔en`, mute/archive read-only và moderation có audit. PostgreSQL
> cô lập pass 20/20. Exact Staging đã backup DPAPI 510.558 byte, apply đúng
> migration GT3, post-dry-run sạch và live smoke 13 nhóm pass với ba WebSocket,
> RLS, mute/remove/archive, moderation cùng cleanup fixture/database 0. Chat
> translation đã chuyển sang Gemini-native v3, model `gemini-3-flash-preview`;
> live smoke xác nhận `translation_mode=succeeded`. GT4 đã bổ sung owner-only invite metadata,
> moderation audit projection, SQLite detail cache offline và dashboard read-only
> khi archived. Migration GT4 đã apply exact Staging, smoke 16 nhóm pass và
> cleanup 0. GT5 local thêm nhiệm vụ học số từ mới, dashboard tổng quan và chia
> sẻ từ vựng dạng chữ theo opt-in; không sao chép ảnh hoặc metadata nguồn. SQL
> isolated pass 17/17, Groups pass 25/25, full Flutter pass 792 + 1 opt-in skip,
> analyzer sạch và Web release build pass. Exact Staging đã backup DPAPI mới
> 530.874 byte, apply duy nhất GT5 và live smoke pass 19 nhóm với task,
> opt-in/projection text-only, RLS, Realtime cùng cleanup fixture/database 0.
> Tại checkpoint GT5, post-dry-run chỉ còn social migrations; rollout social mới
> nhất được ghi bên dưới. Production không được truy cập hoặc thay đổi.
>
> Social group chat là miền song song, không phải learning group: mọi tài khoản
> cá nhân hoặc giáo viên đều có thể tạo nhóm tối đa 20 người từ bạn bè accepted
> hai chiều. Social group không có invite lớp học, dashboard, nhiệm vụ, progress
> projection hay quyền xem Library/ảnh; correction/annotation/Training vẫn chỉ
> dành cho direct chat. Beta thêm owner đổi tên/đóng nhóm, thành viên rời nhóm,
> history read-only sau khi đóng, public member profile bounded và tên người gửi
> thật; SQLite chat nâng additive lên v8. Hai migration local
> `20261021120000_add_social_group_chat.sql` và
> `20261022120000_complete_social_group_beta.sql` pass PostgreSQL 29/29; Chat
> targeted pass 92/92; full Flutter pass 798 + 1 opt-in skip; analyzer sạch,
> Web release và Android APK release build pass. Exact Staging đã backup DPAPI,
> apply đúng hai migration social và live transaction smoke pass 29/29 với
> rollback/cleanup 0. Production chưa apply.

## 1. Mục tiêu

Tạo một miền **Nhóm học** dùng chung cho Web và ứng dụng:

- Giáo viên đã được xác minh có thể tạo và quản lý lớp học riêng tư.
- Học viên tham gia bằng mã/link mời và phải được giáo viên duyệt.
- Mỗi nhóm có một phòng group chat, khu vực thông báo và danh sách thành viên.
- Giáo viên có thể giao nhiệm vụ học số từ mới và xem tiến độ tối thiểu của học
  viên đã chủ động bật chia sẻ trong nhóm.
- Chat trực tiếp, dữ liệu Library cá nhân và dữ liệu quản lý lớp phải giữ ranh
  giới quyền riêng tư độc lập.

Tên milestone của miền này là `GT0`–`GT6`; không dùng tiếp H6/H7 của Home.

## 2. Sự thật hiện tại của dự án

- Schema nhận `personal`, `parent` hoặc `teacher`; onboarding mới chỉ hiển thị
  `personal` và `teacher`, còn `parent` được giữ để tương thích dữ liệu cũ.
- Role teacher vẫn không phải cơ chế cấp quyền quản trị nếu chưa được server xác
  minh; chỉ teacher verified được tạo/quản lý learning group.
- Exact Staging đang có direct chat, learning-group chat GT3/GT4 và GT5 nhiệm vụ
  cùng progress text-only đã live verified.
- Beta trên exact Staging có social group chat cho cả personal/teacher, tối đa 20 thành
  viên từ friendship accepted hai chiều, có rename/leave/close và member profile
  an toàn; hai migration social đã apply và post-dry-run sạch.
- Flutter `ChatConversation.group` và SQLite cache hiện biểu diễn cả learning
  group lẫn social group; server metadata và quyền vẫn tách biệt theo `kind`.
- Raw chat, outbox offline, Realtime và bản dịch `vi↔en` dùng chung. Correction,
  tagging và Training evidence vẫn chỉ dành cho direct chat.

GT1 trở đi phải dùng migration additive và giữ toàn bộ direct chat hiện tại
tương thích ngược.

## 3. Quyết định sản phẩm đã khóa trong GT0

### 3.1. Ý nghĩa của Group

- Trong tài liệu GT0–GT6 này, `Group` là **lớp/nhóm học riêng tư**. Social group
  chat là miền riêng và không được suy ra quyền học tập từ cùng một UI model.
- Một tài khoản có thể tham gia nhiều nhóm.
- Một giáo viên đã xác minh có thể sở hữu nhiều nhóm.
- MVP có một giáo viên sở hữu và tối đa 50 học viên active trong mỗi nhóm.
- Không có tìm kiếm nhóm công khai. Người dùng chỉ vào nhóm bằng mã/link mời.
- Group membership không tự tạo friendship và không mở direct chat giữa các
  thành viên. Direct chat tiếp tục tuân theo contract Friends hiện tại.

### 3.2. Giáo viên và quyền đặc biệt

- `account_role='teacher'` chỉ biểu diễn lựa chọn UX của người dùng.
- Quyền tạo/quản lý nhóm chỉ được cấp khi hồ sơ giáo viên có trạng thái
  `verified` ở server.
- Người dùng tự chọn Teacher không được tự nâng quyền.
- Chỉ trusted admin/service workflow được chuyển trạng thái giáo viên giữa
  `pending`, `verified`, `suspended` và `rejected`.
- Giáo viên bị suspend mất quyền mutation ngay; dữ liệu nhóm không bị xóa ngầm.
- GT0 không thiết kế cổng admin xác minh. GT1 phải cung cấp contract server và
  thao tác vận hành tối thiểu trước khi bật UI Teacher.

### 3.3. Phạm vi bản đầu

Bản đầu gồm:

- Tạo, sửa tên/mô tả và archive nhóm.
- Tạo, xoay vòng hoặc thu hồi mã mời.
- Duyệt, từ chối, loại và mute học viên.
- Danh sách thành viên và thông báo của giáo viên.
- Một group chat text cho mỗi nhóm.
- Cache đọc offline; group chat tiếp tục có outbox offline.

Chưa làm trong bản đầu:

- Nhóm công khai, discovery, marketplace hoặc trường/tổ chức nhiều tầng.
- Co-teacher, chuyển quyền sở hữu hoặc nhiều phòng chat trong một nhóm.
- Attachment, voice/video call, livestream, sticker hoặc file bài tập.
- Mã hóa đầu-cuối; ứng dụng không được quảng cáo group chat là E2EE.
- AI moderation tự động, chatbot trong lớp hoặc tự động dùng chat làm Training.

Giao bài và tiến độ là GT5, sau khi membership/group chat đã ổn định.

## 4. Mô hình quyền

### 4.1. Vai trò toàn cục

| Trạng thái | Ý nghĩa | Quyền nhóm |
| --- | --- | --- |
| `personal` | Người học cá nhân | Tham gia nhóm như học viên |
| `parent` | Phụ huynh/giám sát | Chưa có quyền nhóm đặc biệt trong MVP |
| `teacher` + chưa verified | Đã chọn UX giáo viên | Không tạo/quản lý nhóm |
| `teacher` + `verified` | Giáo viên hợp lệ | Tạo và sở hữu nhóm |
| `teacher` + `suspended/rejected` | Không còn đủ điều kiện | Không mutation quản trị |

### 4.2. Vai trò trong nhóm MVP

- `owner_teacher`: đúng một người, phải là giáo viên verified.
- `student`: học viên active đã được duyệt.

Không suy ra quyền từ client, route, cache hoặc chuỗi `account_role`. Mọi RPC và
RLS phải kiểm tra server-side cả trạng thái teacher lẫn membership hiện tại.

### 4.3. Ma trận quyền tối thiểu

| Hành động | Owner teacher | Student active | Người ngoài |
| --- | ---: | ---: | ---: |
| Xem nhóm/thành viên an toàn | Có | Có | Không |
| Sửa/archive nhóm | Có | Không | Không |
| Xoay/thu hồi mã mời | Có | Không | Không |
| Duyệt/loại/mute học viên | Có | Không | Không |
| Đăng thông báo | Có | Không | Không |
| Đọc group chat | Có | Có | Không |
| Gửi group chat | Có | Có, nếu không mute | Không |
| Ẩn message khỏi nhóm | Có, qua RPC có audit | Không | Không |
| Xem direct chat của thành viên | Không | Không | Không |
| Xem Library/ảnh cá nhân | Không | Không | Không |
| Giao/đóng nhiệm vụ học số từ mới | Có | Không | Không |
| Xem tổng quan/từ đã học dạng chữ | Có, khi học viên opt-in | Không | Không |
| Bật/tắt chia sẻ tiến độ của bản thân | Không | Có | Không |
| Xem email/phone/tuổi/ví Yuzu | Không | Không | Không |

## 5. Membership và lời mời

### 5.1. Trạng thái

```text
invite code hợp lệ
  -> pending
  -> active | rejected
active
  -> left | removed
```

- Một user chỉ có một membership row cho mỗi nhóm.
- `pending -> active/rejected` chỉ owner teacher thực hiện.
- Học viên chỉ được tự chuyển `active -> left`.
- Giáo viên chỉ được chuyển `active -> removed`.
- `left/removed/rejected` không tự quay lại active; phải tạo yêu cầu mới qua
  contract server có audit.
- Rời hoặc bị loại làm mất quyền đọc/ghi group chat ngay lập tức.

### 5.2. Mã mời

- Mã mời có entropy đủ mạnh, có hạn dùng và có thể revoke/rotate.
- Server chỉ lưu hash của secret token; không log hoặc trả token cũ lần hai.
- Join dùng RPC rate-limited; không cho client query bảng invite trực tiếp.
- Mã hợp lệ chỉ tạo membership `pending`, không tự cho vào lớp.
- Giới hạn 50 học viên được kiểm tra atomically khi giáo viên approve để chống
  hai request đồng thời vượt giới hạn.

## 6. Group chat

### 6.1. Kiến trúc

- Không tạo một hệ thống message thứ hai.
- Mở rộng `chat_conversations` theo hướng additive để có `kind='group'` và liên
  kết một-một với `learning_groups`; direct conversation cũ giữ nguyên.
- Tái sử dụng `chat_members`, `chat_operational_messages`, Realtime, outbox và
  translation worker hiện có.
- `ChatConversation`/SQLite phải được nâng để biểu diễn `direct` hoặc `group`,
  trong đó group có `title`, avatar tùy chọn và member count thay cho `peerId`.
- Mỗi group chỉ có một conversation trong MVP.

### 6.2. Luật gửi/đọc

- Chỉ membership `active` mới được đọc group conversation và message.
- Student bị mute vẫn đọc được nhưng không gửi được.
- Group chat không yêu cầu friendship.
- Raw message vẫn immutable, idempotent và tối đa 4.000 Unicode characters.
- Teacher moderation chỉ đổi visibility bằng RPC và ghi audit; client không
  hard-delete raw message.
- Khi group `archived`, chat chuyển read-only cho thành viên còn active.

### 6.3. Dịch và tính năng học tập

- MVP tiếp tục chỉ hỗ trợ `vi↔en`; một bản dịch đối ngôn ngữ được dùng chung.
- Lỗi dịch không chặn raw group chat.
- Correction, accept/reject và manual tagging hiện có được **tắt trong group
  chat MVP** vì contract 1–1 đang giả định đúng một “thành viên còn lại”.
- Group chat không đi vào Training dataset; mở promotion sau này cần consent và
  policy mới riêng, không tái dùng mặc định contract 1–1.

## 7. Không gian Giáo viên

### 7.1. Điều hướng

- Giữ nguyên bốn tab dưới cùng; không thêm tab thứ năm.
- Thêm route `/groups` từ khu vực Friends/nhóm học.
- Teacher verified thấy CTA `Quản lý lớp`; học viên thấy `Nhóm của tôi`.
- Group chat xuất hiện trong inbox Chat hiện có với tên/avatar nhóm.
- Toàn bộ control phải có touch target tối thiểu 48 dp, semantic label và trạng
  thái loading/error/empty rõ ràng trên Web lẫn Android.

### 7.2. Dashboard MVP

- Danh sách lớp active/archived.
- Tổng active/pending/muted.
- Hộp duyệt yêu cầu tham gia.
- Xoay mã mời và xem hạn dùng.
- Danh sách học viên với remove/mute/unmute.
- Soạn/pin/unpin thông báo.
- Mở group chat và xem moderation audit do chính giáo viên thực hiện.
- Giao/đóng nhiệm vụ hệ thống dạng “học N từ mới” cho toàn bộ học viên active.
- Xem tổng số từ đã học, mức hoàn thành nhiệm vụ và danh sách từ dạng chữ của
  từng học viên đã bật chia sẻ.

Các mutation quản lý yêu cầu online. Cache offline chỉ để đọc và phải hiển thị
timestamp; không queue offline thao tác approve/remove/mute để tránh xung đột
quyền. Riêng message chat tiếp tục dùng outbox offline hiện có.

## 8. Ranh giới dữ liệu học tập và quyền riêng tư

- Teacher chỉ thấy aggregate và projection từ dạng chữ mà học viên chủ động chia
  sẻ trong đúng group; mặc định chia sẻ tắt.
- Không được đọc toàn bộ Home history, Photo Note, Library, ảnh gốc, raw Vision
  response, Friends, direct chat, contact hoặc lịch sử mua Yuzu của học viên.
- Profile hiển thị trong group chỉ gồm projection an toàn: `id`, display name,
  username và avatar.
- GT5 chỉ trả tổng số từ, trạng thái/chỉ số hoàn thành và `word` cùng thời điểm
  học đầu/gần nhất. RPC giáo viên không trả receipt/item/Photo Note/media ID,
  đường dẫn ảnh, bounding box hoặc raw Vision; không sao chép ảnh vào không gian
  giáo viên.
- Tiến độ chỉ được chiếu từ lesson completion receipt đã được server chấp nhận
  ở mastery 100%. Tắt chia sẻ hoặc rời/bị loại khỏi nhóm xóa projection của nhóm.
- Mỗi nhiệm vụ đếm từ mới có `first_learned_at` nằm từ lúc giao đến hạn; học viên
  active hiện tại là tập được giao trong MVP, không có upload bài làm riêng.
- Thành viên khác không được xem tiến độ cá nhân; leaderboard lớp nếu có phải là
  tính năng opt-in riêng và không dùng số dư ví.
- Mọi hành động teacher ảnh hưởng thành viên/message phải có actor, timestamp,
  reason code và audit row không client-mutable.

## 9. Data contract dự kiến cho GT1–GT5

GT0 chỉ khóa trách nhiệm; tên cột chính xác được chốt trong migration review.

- `teacher_profiles`: owner, verification status, verified/suspended audit.
- `learning_groups`: owner teacher, title, description, status, timestamps.
- `learning_group_members`: group/user, role, membership status, mute state.
- `learning_group_invites`: token hash, expiry, revoke/use metadata.
- `learning_group_announcements`: teacher-authored, pin state, timestamps.
- `learning_group_moderation_events`: immutable action audit.
- `chat_conversations`: additive group discriminator/reference.
- `private.learning_group_system_tasks`: nhiệm vụ số từ mới và request ID.
- `private.learning_group_vocabulary_shares`: opt-in riêng theo group/học viên.
- `private.learning_group_vocabulary_progress`: projection chữ riêng tư từ
  receipt đã chấp nhận; giữ source ID nội bộ để lineage nhưng không expose qua RPC.

Không dùng `friends` làm membership và không nhét quyền teacher vào JWT metadata
do client điều khiển. Database là nguồn quyền authoritative.

## 10. Failure và lifecycle

- Teacher verification bị revoke: mutation bị từ chối ngay; group vẫn tồn tại
  nhưng vào trạng thái cần xử lý, không tự chuyển ownership.
- Group archived: membership và history giữ nguyên, không nhận join/message mới.
- Member bị remove/left: local cache có thể giữ dữ liệu mã hóa theo owner để
  hiển thị trạng thái đã rời, nhưng runtime phải purge/hide nội dung group sau
  khi server xác nhận mất quyền.
- Account switch: mọi cache/provider phải owner-scoped và hủy subscription cũ.
- Realtime chỉ là invalidation; sau event client phải đọc lại bằng RLS, không
  tin payload để cấp quyền.
- Retry cùng request ID không được tạo hai membership, message hoặc moderation
  event.

## 11. Verification bắt buộc

### SQL/RLS

- User tự chọn `teacher` nhưng chưa verified không thể tạo group.
- Teacher A không quản lý group của Teacher B.
- Student/outsider không sửa group, membership, invite, announcement hoặc audit.
- Invite expired/revoked/sai mã bị từ chối mà không lộ group.
- Hai approve đồng thời không vượt cap và không tạo duplicate membership.
- Removed/muted/archive có hiệu lực với group chat trong cùng transaction hoặc
  fail an toàn.
- Group membership không mở direct chat hoặc dữ liệu riêng tư.
- Service/admin verification path không được exposed cho authenticated client.
- Chỉ owner verified đọc aggregate/từ đã chia sẻ; student/outsider bị từ chối.
- Tắt consent/rời/bị loại phải xóa projection và direct table access bị từ chối.

### Flutter/local

- Owner/account switch không lộ cache nhóm.
- Teacher pending/suspended không thấy action quản trị khả dụng.
- Student pending/removed không mở được chat từ cache cũ.
- Direct chat regression giữ nguyên peer/inbox/outbox/translation.
- Group inbox, history, offline outbox và reconnect không render duplicate.
- Giao diện 320 px, text scale 1.3, Web responsive và semantics pass.

### Live Exact Staging

- Ít nhất hai teacher fixture và ba student fixture để kiểm tra cross-group RLS.
- Join/approve/mute/unmute/remove/archive và Realtime đa client pass.
- Web↔Android group message raw trước translation pass.
- Fixture, invite, chat, audit và Auth cleanup còn 0.
- Production không apply cho đến khi có backup, dry-run, approval và rollback.

## 12. Roadmap triển khai

### GT0 — Contract và ranh giới quyền — `HOÀN THÀNH 2026-10-13`

- Khóa phạm vi, roles, privacy, lifecycle, group chat reuse và test matrix.
- Không đổi code/schema/remote.

### GT1 — Teacher identity và server authorization — `HOÀN THÀNH 2026-10-13`

- Migration additive cho role `teacher` và teacher verification.
- Cập nhật onboarding/domain/UI nhưng giữ tài khoản cũ tương thích.
- RPC/RLS test chứng minh self-selected role không cấp quyền.
- `teacher_profiles` owner-readable; trạng thái gồm pending/verified/suspended/
  rejected. Client không có quyền mutation.
- RPC xác minh vừa kiểm tra JWT `service_role`, vừa chỉ grant cho service role;
  mọi thay đổi trạng thái/reason được ghi audit private.
- Gate local pass: PostgreSQL isolated 32/32, onboarding 14/14, full Flutter
  763 pass + 1 skip và analyzer sạch.
- Exact Staging đã backup DPAPI; migration history thiếu local
  `20261008173000` đã được fetch đúng từ remote. Hai migration GT1
  `20261013120000` và hardening `20261013130000` đã apply; post-dry-run
  `upToDate=true`.
- Live smoke hai account pass 7 nhóm: pending không có quyền, client mutation
  bị chặn, cross-account RLS, service verification, bắt buộc RPC, suspension
  revoke quyền và cleanup còn 0 fixture.

### GT2 — Learning group và membership — `HOÀN THÀNH 2026-10-17`

- Migration additive tạo group, membership, invite chỉ lưu SHA-256, announcement,
  rate limit và moderation audit private; authenticated client không có direct
  mutation hoặc quyền đọc secret/audit.
- RPC kiểm tra teacher verified server-side, join không lộ group khi token sai,
  request ID idempotent và advisory transaction lock giữ cap 50 atomically.
- PostgreSQL 18 cô lập pass 43/43; test hai session approve đồng thời tại 49/50
  cho đúng một success, một reject và không tạo duplicate audit/membership.
- Flutter có domain/gateway/cache SQLite owner + project scoped, session fence,
  Realtime-as-invalidation, provider cache-first và UX `/groups` với create/join.
- Teacher pending/suspended không thấy mutation quản trị; Friends có điểm vào
  Groups 48 dp, route Groups giữ tab Friends và layout 320 px/text scale 1.3 pass.
- Groups/Friends/navigation pass 74/74, Direct Chat pass 150/150, full Flutter
  pass 776 + 1 opt-in skip và analyzer sạch.
- Exact Staging backup DPAPI 439.122 byte verified; migration
  `20261013140000` apply đúng một lần và post-dry-run `upToDate=true`.
- Live smoke 5 account pass 9 nhóm: capability, idempotency, cross-owner RLS,
  invite/pending/approve/reject, Realtime announcement hai client, pin/mute/
  remove, rejoin/leave/archive và cleanup Auth + database còn 0 fixture.
- Chưa bật group chat hoặc action dashboard GT4. Production không được truy cập
  hoặc thay đổi.

### GT3 — Group chat — `EXACT-STAGING VERIFIED 2026-10-20`

- Migration additive `20261017120000_add_learning_group_chat.sql` tạo đúng một
  conversation cho mỗi learning group, mirror active membership vào chat member,
  giữ group không phụ thuộc friendship và giữ toàn bộ direct-chat contract.
- RLS cho active member đọc; student bị mute vẫn đọc nhưng không gửi; group
  archived chuyển read-only. Teacher moderation chỉ đổi visibility qua RPC có
  audit, không hard-delete raw message.
- SQLite v7 lưu group conversation owner-scoped; inbox/detail, offline outbox,
  Realtime invalidation và shared translation `vi↔en` dùng lại pipeline chat.
  Correction, accept/reject và slang annotation bị khóa server-side cho group.
- PostgreSQL 18 cô lập pass 20/20, gồm translation claim với hơn hai member,
  mute/archive/removal, moderation audit và direct regression. Direct Chat pass
  153/153; full Flutter pass 779 + 1 opt-in skip; analyzer sạch; Web release build
  thành công. Overlay group ở 320 px/text scale 1.3 pass.
- Exact Staging `nxteaznowkfennxpqjmt` đã backup DPAPI tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20261020T112124Z-ba7526a7`, apply
  đúng migration GT3 và post-dry-run `upToDate=true`.
- Live smoke pass 13 nhóm: group conversation ba active member, ba WebSocket nhận
  raw, outsider RLS, shared translation row/direct-only learning, moderation có
  audit, mute/remove/archive fail closed và cleanup fixture/database còn 0.
- Translation worker lặp lại `PROVIDER_UNAVAILABLE`; smoke chỉ chấp nhận đúng
  trạng thái degraded này và không claim happy path dịch live. Direct Chat
  correction-only regression pass; Production không đổi.

### GT4 — Teacher management dashboard — `EXACT-STAGING VERIFIED 2026-10-20`

- Bottom sheet dashboard mở từ group card cho member đã active; student xem danh
  sách/thông báo/chat, còn owner teacher active mới thấy mutation quản trị.
- Đã nối pending approve/reject, mute/unmute, remove, rotate/revoke invite 7 ngày,
  create/pin announcement, archive và mở group chat qua contract GT2/GT3 hiện có.
- Migration `20261020120000_add_learning_group_management_reads.sql` thêm hai
  RPC owner-only cho active-invite metadata và moderation audit projection có
  limit; không trả token, hash hoặc request ID và vẫn fail closed khi suspended.
- SQLite Groups v2 lưu detail snapshot theo owner/project/group và đúng management
  scope; offline đọc snapshot đã commit, còn denied/unauth/not-found purge toàn bộ
  detail cache. Archived owner chỉ xem trạng thái/audit, không thấy mutation.
- PostgreSQL 18 cô lập pass 10/10; Groups pass 21/21, Chat pass 153/153, full
  Flutter pass 788 + 1 opt-in skip, analyzer sạch và Web release build thành công.
- Exact Staging đã backup DPAPI 525.465 byte tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20261020T120651Z-6ad3ed4b`, apply
  đúng migration GT4 và post-dry-run `upToDate=true`. Live GT3+GT4 smoke pass 16
  nhóm, Realtime ba client pass sau subscription stabilization và cleanup Auth/
  database còn 0. Translation vẫn degraded `PROVIDER_UNAVAILABLE`; Production
  không đổi.

### GT5 — Assignment và progress tối thiểu — `EXACT-STAGING VERIFIED 2026-10-21`

- Migration additive `20261020130000_add_learning_group_assignments.sql` thêm
  nhiệm vụ “học N từ mới”, opt-in chia sẻ theo group và projection từ dạng chữ.
- Progress được suy ra từ `lesson_completion_receipts` server-accepted; payload
  mới chỉ bổ sung canonical `word`, không chứa ảnh/path/box/raw Vision.
- Owner verified xem tổng quan và danh sách từ bounded; student chỉ xem nhiệm vụ
  cùng tiến độ bản thân và tự bật/tắt chia sẻ. Tắt/rời/remove purge projection.
- Tạo/đóng nhiệm vụ dùng request ID idempotent và ghi moderation audit; không cấp
  quyền direct table cho authenticated client.
- PostgreSQL 18 cô lập pass 17/17; Groups pass 25/25; full Flutter pass 792 + 1
  opt-in skip; analyzer sạch và Web release build thành công.
- Automatic projection được bật mặc định trong beta; vẫn có thể tắt bằng
  `--dart-define=LESSON_RESULT_SYNC_ENABLED=false`. Exact Staging đã backup DPAPI,
  apply duy nhất GT5 và live smoke pass 19 nhóm với task, text-only projection,
  RLS, Realtime cùng cleanup Auth/database 0. Production không đổi.

### GT6 — Rollout và acceptance — `LOCAL BETA ACCEPTANCE VERIFIED 2026-10-22`

- SQL isolated 29/29, Flutter full regression 798 + 1 opt-in skip, analyzer sạch,
  Web/Android release builds pass.
- Backup + exact-Staging apply, synthetic multi-user smoke và device matrix.
- Production chỉ sau explicit approval.

## 13. Điều kiện bắt đầu GT1

- GT0 là nguồn luật duy nhất cho Group/Teacher.
- Mọi thay đổi quyền phải fail closed và test server-side.
- Migration phải additive; direct Chat/Friends/Home hiện tại không được phá vỡ.
- Trước GT1 phải đọc `db_status.md`, backup theo quy trình và xác nhận exact
  Staging; GT1 không tự apply remote khi chưa có phê duyệt riêng.
