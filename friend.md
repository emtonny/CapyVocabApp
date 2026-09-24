# Kế hoạch chức năng Bạn bè

> Cập nhật: **2026-09-24**
> Trạng thái: **F1–F6 IMPLEMENTED / EXACT-STAGING VERIFIED**. Hai migration
> Friends đã apply đúng project Staging `nxteaznowkfennxpqjmt`; Production chưa
> apply. Runner exact Staging bật rõ `FRIENDS_ENABLED=true`; mặc định vẫn tắt để
> Production chưa có schema không vô tình kích hoạt. Luồng OTP phone phía client
> và exact-Staging synthetic OTP đã hoàn tất. SMS thật còn chờ cấu hình đủ Twilio;
> Phone provider và test OTP đã được trả về trạng thái tắt sau smoke.
> Phạm vi: tìm kiếm người dùng, gửi lời mời, chấp nhận/từ chối và danh sách
> bạn bè. Bảng xếp hạng tuần là milestone kế tiếp sau khi milestone này hoàn tất.

## 1. Mục tiêu

Người dùng đã đăng nhập có thể:

1. Tìm một người khác bằng username, email hoặc số điện thoại.
2. Gửi đúng một lời mời kết bạn.
3. Xem lời mời đã gửi và lời mời nhận được.
4. Chấp nhận hoặc từ chối lời mời nhận được.
5. Xem danh sách bạn bè đã chấp nhận.
6. Mở Chat với bạn bè đã có đủ hồ sơ ngôn ngữ.
7. Đọc danh sách đã cache khi offline; thao tác thay đổi quan hệ yêu cầu mạng
   trong MVP.

Milestone này phải tạo đầu vào ổn định cho bảng xếp hạng bạn bè nhưng chưa tính
điểm tuần và chưa render leaderboard.

## 2. Sự thật hiện tại

### Backend đã có

- `public.friends(user_id, friend_id, status, created_at)` với khóa chính hai cột.
- `status` hiện hỗ trợ `pending`, `accepted`, `rejected`.
- RLS cho phép hai phía nhìn thấy row liên quan.
- Trigger `private.guard_chat_friend_acceptance()` đã chặn:
  - tự kết bạn;
  - sender tự giả mạo trạng thái `accepted`;
  - người không phải recipient chấp nhận lời mời;
  - sửa identity của row.
- Chat yêu cầu hai row `accepted` đối ứng trước khi mở direct conversation.
- `get_public_profiles(UUID[])` trả projection công khai gồm ID, tên hiển thị,
  username, avatar, điểm, streak và level; không trả email, số điện thoại hoặc
  dữ liệu onboarding riêng tư.
- `public.users.email` là bắt buộc và unique; RLS hiện chỉ cho chủ tài khoản đọc
  trực tiếp profile đầy đủ của mình.
- `public.users.phone` là nullable, unique và hiện dùng contract Việt Nam
  `^0[0-9]{9}$`; onboarding mới kiểm tra định dạng/độ trùng, chưa có bằng chứng
  xác minh quyền sở hữu số điện thoại bằng OTP.
- Exact Staging đã có contract Friends F1 cùng bản vá tương thích định dạng số
  `84…` của Supabase Auth; post-apply dry-run sạch.

### Client hiện có

- F1–F5 đã có typed entity/repository, RPC-only Supabase gateway, session fence,
  Realtime invalidation, SQLite cache riêng theo project/account và UI tìm/gửi
  lời mời cùng discovery settings.
- Màn Bạn bè có `Thêm bạn`, ba tab request/accepted và lối mở Chat sau cờ
  `FRIENDS_ENABLED`. Runner Web/Android exact Staging bật cờ rõ ràng; default và
  Production vẫn tắt.
- Search hỗ trợ exact username/email/phone, debounce 350 ms, validation local,
  stale-query/account cancellation, offline fail-fast và result chỉ chứa public
  profile. Send không tự giả accepted và refresh outgoing sau kết quả server.
- Settings có opt-in email/phone độc lập và fail closed khi contact chưa được
  server xác minh. Phone chưa verified mở dialog gửi/nhập OTP qua Supabase Auth,
  chỉ dùng số private đã lưu của chính owner, che số trên UI và chỉ gọi
  `sync_my_verified_friend_phone()` sau Auth success.
- F4 thêm ba tab `Lời mời`, `Đã gửi`, `Bạn bè`, badge lời mời đến, cache-first
  hydrate, refresh nền/Realtime invalidation và accept/reject khóa theo từng
  peer. Chỉ xóa lời mời khỏi UI sau server success; offline/lỗi giữ cache để thử
  lại.
- F5 thay nội dung tab `Bạn bè` sau feature flag bằng accepted list public-profile
  cache-first. Danh sách refresh nền/Realtime, giữ cache khi offline và dùng
  snapshot phân trang đã có từ F2.
- Trước khi mở Chat, client tải lại accepted snapshot và chặn peer đã
  inactive/rejected. `openDirectChat(peerId)` hiện có vẫn là nguồn quyết định
  quan hệ hai chiều, hồ sơ ngôn ngữ hai phía và canonical conversation ID.
  Account switch trong lúc RPC chờ không điều hướng owner cũ. Live A/B/C
  Staging đã đạt trong F6.

## 3. Quyết định MVP

### 3.1 Tìm kiếm

- Hỗ trợ ba phương thức **username**, **email** và **số điện thoại** chính xác;
  UI cho người dùng chọn phương thức để tránh nhầm username chỉ gồm chữ số với
  số điện thoại.
- Username chuẩn hóa bằng `lower(trim(query))` và giữ contract hiện tại:
  `^[a-z0-9_]{3,20}$`.
- Email chuẩn hóa bằng `lower(trim(query))`, validate định dạng ở cả client và
  server, và chỉ match email đã được Supabase Auth xác nhận.
- Số điện thoại MVP hỗ trợ Việt Nam: nhận `0xxxxxxxxx` hoặc dạng `+84xxxxxxxxx`,
  loại bỏ khoảng trắng/dấu phân cách rồi canonicalize về `0xxxxxxxxx` để khớp
  dữ liệu hiện có. Số chưa xác minh OTP không được dùng cho discovery.
- Username được tìm thấy theo contract hiện tại. Email và số điện thoại chỉ được
  tìm thấy khi chủ tài khoản đã chủ động bật từng quyền discoverability tương
  ứng; user cũ mặc định tắt cả hai quyền.
- Không dùng `get_public_profiles(NULL)` để tải toàn bộ người dùng.
- RPC tìm kiếm chỉ trả tối đa một profile công khai và trạng thái quan hệ giữa
  người tìm với kết quả.
- Giới hạn tần suất tìm kiếm theo `auth.uid()` ở phía server; debounce phía
  client chỉ phục vụ UX và không được xem là biện pháp chống enumeration.
- Không trả về chính tài khoản hiện tại.
- Tài khoản không tồn tại, chưa xác minh hoặc đã tắt discoverability đều trả
  cùng một kết quả `not_found`; không tiết lộ lý do cụ thể.
- Không ghi raw email/số điện thoại vào log, analytics, crash report hoặc cache
  Friends.

### 3.2 Trạng thái quan hệ

Client dùng state domain sau:

| State | Ý nghĩa | Hành động hợp lệ |
| --- | --- | --- |
| `none` | Chưa có quan hệ | Gửi lời mời |
| `outgoingPending` | Tôi đã gửi | Xem trạng thái; hủy là phần mở rộng |
| `incomingPending` | Tôi nhận được | Chấp nhận hoặc từ chối |
| `accepted` | Hai phía đã là bạn | Mở Chat; dùng cho leaderboard sau này |
| `rejected` | Lời mời gần nhất bị từ chối | Không tự động gửi lại |

Invariant backend:

- `pending` chỉ có một row theo chiều requester → recipient.
- `accepted` luôn có đúng hai row đối ứng.
- Accept phải cập nhật row gốc và tạo row đối ứng trong cùng transaction.
- Reject chỉ đổi row pending gốc thành `rejected`; không tạo row đối ứng.
- Mọi thao tác phải idempotent khi client retry sau timeout/lost response.
- Self-request và thay đổi thay người khác phải fail-closed.

### 3.3 Online/offline

- Danh sách accepted và request inbox được cache để đọc offline.
- Search/send/accept/reject yêu cầu session hiện tại và validated network.
- MVP không queue thao tác quan hệ khi offline để tránh gửi/chấp nhận ngoài ý
  muốn sau một khoảng thời gian dài.
- Realtime chỉ là tín hiệu invalidation; client luôn pull snapshot có RLS sau khi
  nhận event.

## 4. Backend contract F1

Tạo một migration additive riêng. Không sửa lịch sử migration đã apply.

### 4.1 Bổ sung bảng `friends`

Thêm tối thiểu:

- `updated_at timestamptz not null default now()`
- `responded_at timestamptz null`

Thêm index phục vụ hai hướng:

- `(user_id, status, updated_at desc, friend_id)`
- `(friend_id, status, updated_at desc, user_id)`

Không thêm `blocked` hoặc đồng bộ danh bạ trong milestone này.

### 4.2 Quyền discovery và xác minh liên hệ

Bổ sung bảng private, ví dụ `private.friend_discovery_settings`:

- `user_id uuid primary key`
- `discoverable_by_email boolean not null default false`
- `discoverable_by_phone boolean not null default false`
- `phone_verified_at timestamptz null`
- `updated_at timestamptz not null default now()`

Bảng private không cấp quyền trực tiếp cho `anon`/`authenticated`. Chủ tài khoản
đọc/đổi hai cờ qua RPC owner-only; RPC tìm kiếm chỉ đọc nội bộ và không trả các
cờ cho người tìm. Mỗi lần đổi quyền ghi audit event không chứa raw contact.

- Email chỉ đủ điều kiện khi khớp email hiện hành trong Auth và có
  `email_confirmed_at`.
- Luồng OTP phải dùng Supabase phone verification/link identity hoặc provider
  được phê duyệt. Chỉ callback/server tin cậy được ghi `phone_verified_at`;
  client không được tự xác nhận.
- F1 dùng `auth.users.phone_confirmed_at` cùng số Auth khớp số profile làm nguồn
  tin cậy; `sync_my_verified_friend_phone()` chỉ đồng bộ dấu thời gian sau khi
  kiểm tra này đạt.
- Trigger khi `public.users.phone` đổi phải xóa `phone_verified_at` và tự tắt
  phone discoverability cho tới khi số mới được xác minh.
- Migration phải audit duplicate/case của email và tính hợp lệ/độ trùng của
  phone trước khi thêm index phục vụ lookup. Không tự bật quyền cho user cũ.
- Dùng RPC owner-only để đọc/cập nhật hai cờ; không mở SELECT thông tin liên hệ
  của user khác.
- RPC onboarding cũ `check_phone_available` giữ nguyên chữ ký nhưng chỉ xác nhận
  định dạng, không còn tiết lộ số đã thuộc tài khoản khác; unique constraint của
  lần ghi onboarding là kết quả cuối cùng.

### 4.3 RPC tìm kiếm

`search_friend(p_method text, p_query text)` với method
`username|email|phone`:

- chỉ `authenticated` được gọi;
- validate method và chuẩn hóa identifier ở server theo contract mục 3.1;
- email/phone chỉ match tài khoản đã xác minh và bật discoverability tương ứng;
- trả tối đa một row public profile;
- trả thêm `relationship_state` đã tính theo caller;
- không trả email, phone, tuổi, role hoặc onboarding state;
- không cho query rỗng/wildcard;
- `not_found` dùng chung cho không tồn tại, chưa xác minh và opt-out;
- log chỉ error code, không log query hoặc profile data.

### 4.4 RPC gửi lời mời

`send_friend_request(p_target_user_id uuid)`:

- lấy requester từ `auth.uid()`, không nhận requester từ client;
- khóa hai hướng của cặp user trước khi quyết định;
- từ chối self-request và target không tồn tại;
- nếu đã accepted: trả `already_accepted`;
- nếu outgoing pending đã tồn tại: trả cùng kết quả `outgoing_pending`;
- nếu có incoming pending: trả `incoming_pending`, không auto-accept;
- nếu lời mời gần nhất đã bị từ chối: trả `rejected`, không tự mở lại hoặc tạo
  row mới trong MVP;
- nếu chưa có quan hệ: insert đúng một row `pending`;
- response dùng enum ổn định, không phụ thuộc message PostgreSQL.

### 4.5 RPC phản hồi lời mời

`respond_friend_request(p_requester_id uuid, p_decision text)` với decision
`accept|reject`:

- recipient luôn lấy từ `auth.uid()`;
- row pending được lock `FOR UPDATE`;
- chỉ recipient được phản hồi;
- `accept` cập nhật row gốc và UPSERT row đối ứng `accepted` trong cùng
  transaction;
- `reject` cập nhật row gốc thành `rejected` và không tạo mirror;
- retry cùng decision trả cùng trạng thái;
- decision mâu thuẫn sau khi đã xử lý phải fail với error code ổn định.
- RPC tự ghi `updated_at`/`responded_at` theo giờ server; client không truyền
  timestamp quyết định.

### 4.6 RPC đọc danh sách

Hai RPC keyset-paginated:

- `list_friend_requests(p_direction, p_cursor, p_limit)` cho
  `incoming|outgoing`.
- `list_accepted_friends(p_cursor, p_limit)` trả profile công khai của peer.

Mặc định `limit=30`, tối đa `100`. Cursor dùng `updated_at + peer_id`, không dùng
offset. Kết quả chỉ chứa các row caller có quyền xem.

### 4.7 Quyền và tương thích Chat

- Client mới chỉ gọi RPC cho mutation; không INSERT/UPDATE trực tiếp `friends`.
- Sau khi client cũ không còn được hỗ trợ, thu hẹp grant direct write của
  `authenticated` và giữ SELECT/RPC.
- Trigger hiện có tiếp tục là defense-in-depth trong giai đoạn chuyển tiếp.
- `open_direct_chat` tiếp tục yêu cầu accepted hai chiều; migration Friends phải
  chạy regression toàn bộ C2–C6.
- `get_public_profiles(UUID[])` chỉ dùng với danh sách ID đã biết. Cân nhắc làm
  tham số `NULL` trả rỗng để chặn profile enumeration, sau khi xác nhận không có
  caller hợp lệ cần tải toàn bộ.

## 5. Client contract

### 5.1 Domain

Hoàn thiện các kiểu:

- `FriendPublicProfile`
- `FriendConnection`
- `FriendRequestDirection`
- `FriendRelationshipState`
- `FriendPage<T>` và keyset cursor
- `FriendSearchMethod`: username, email, phone
- `FriendDiscoverySettings`: discoverableByEmail, discoverableByPhone,
  phoneVerified
- error code ổn định: unauthenticated, invalidUsername, invalidEmail,
  invalidPhone, contactNotVerified, userNotFound, selfRequest, alreadyAccepted,
  incomingPending, staleRequest, offline, rateLimited, unavailable

Entity không chứa email, phone hoặc raw Supabase response.

### 5.2 Repository và gateway

Tách interface khỏi Supabase SDK:

- `searchFriend(method, query)`
- `getDiscoverySettings`
- `updateDiscoverySettings`
- `sendRequest`
- `respondToRequest`
- `listIncomingRequests`
- `listOutgoingRequests`
- `listAcceptedFriends`
- `watchInvalidations`

Gateway phải capture JWT/owner tại đầu request và kiểm tra lại session generation
sau mỗi `await`. Kết quả cũ từ account A không được commit sau khi đã chuyển sang
account B.

### 5.3 Cache local

Cache owner-scoped tối thiểu:

- connection/request theo `project_ref + owner_id + peer_id`;
- public profile theo `project_ref + owner_id + peer_id`;
- cursor/sync metadata riêng cho incoming, outgoing và accepted.

Merge snapshot theo transaction. Khi logout/account switch:

- stream owner cũ dừng ngay;
- UI không render cache owner cũ;
- dữ liệu owner cũ có thể giữ trên máy nhưng luôn bị scope bằng owner ID.

### 5.4 Provider

`FriendsNotifier` chịu trách nhiệm:

- hydrate cache trước;
- refresh từng tab theo single-flight;
- debounce search 300–400 ms nhưng chỉ gọi server khi query hợp lệ theo phương
  thức đã chọn;
- optimistic state chỉ dùng cho loading/disabled button, không tự giả accepted;
- reconcile authoritative snapshot sau send/accept/reject;
- hủy/ignore response cũ khi query, session hoặc owner thay đổi.

## 6. Luồng UX

### 6.1 Tìm và gửi lời mời

1. Người dùng mở `Thêm bạn`.
2. Chọn **Username**, **Email** hoặc **Số điện thoại**, sau đó nhập giá trị;
   client normalize và validate tại chỗ.
3. Server trả profile công khai cùng relationship state.
4. UI hiển thị đúng một card hoặc trạng thái không tìm thấy.
5. Nút hành động phụ thuộc state:
   - `none`: **Gửi lời mời**;
   - `outgoingPending`: **Đã gửi**;
   - `incomingPending`: **Xem lời mời**;
   - `accepted`: **Đã là bạn**;
   - `rejected`: **Đã từ chối**, không có CTA gửi lại trong MVP.
6. Sau send thành công, pull lại outgoing requests; retry không tạo row trùng.

### 6.2 Cài đặt quyền được tìm thấy

1. Settings có hai công tắc riêng: **Cho phép tìm bằng email** và **Cho phép
   tìm bằng số điện thoại**; mặc định tắt.
2. Email chưa xác nhận không thể bật công tắc email và dẫn tới luồng xác nhận
   hiện có.
3. Phone chưa xác minh không thể bật công tắc phone và dẫn tới luồng OTP.
4. UI không hiển thị email/phone của người khác trong kết quả, lời mời hoặc danh
   sách bạn bè.
5. Tắt công tắc có hiệu lực cho lần tìm mới; quan hệ/lời mời đã tồn tại không bị
   xóa.

### 6.3 Nhận và phản hồi

1. Tab `Lời mời` có badge số incoming pending.
2. Mỗi row có **Chấp nhận** và **Từ chối**.
3. Khi đang gửi, khóa riêng hai nút của row đó.
4. Accept thành công chuyển row sang tab `Bạn bè` trên cả hai tài khoản.
5. Reject thành công xóa row khỏi inbox nhưng không xóa audit state backend.
6. Lỗi mạng giữ row và cho thử lại; không hiển thị accepted trước khi server xác
   nhận.

### 6.4 Danh sách bạn bè

- Hiển thị avatar, display name, username, streak và level từ public projection.
- Không hiển thị email/phone.
- CTA Chat chỉ bật khi Chat runtime và hồ sơ ngôn ngữ đáp ứng điều kiện hiện có.
- Có empty, loading, offline-cache, refresh-error và pagination states.
- Leaderboard sẽ dùng chính accepted friend IDs từ repository này; không tự query
  toàn bộ `users`.

## 7. Chia nhỏ triển khai

### F1 — Contract và SQL security

**Trạng thái 2026-09-22:** IMPLEMENTED/LOCAL VERIFIED.

**Phạm vi:** migration additive, discovery settings, trạng thái phone verified,
RPC lookup/mutation, index, grants, trigger compatibility và SQL tests.

**Exit:** chứng minh self/forged/cross-user bị chặn; send/accept/reject idempotent;
email/phone opt-out và unverified không thể bị tìm; accept atomic hai chiều; Chat
accepted-pair regression pass.

**Evidence:** migration `20260922120000_add_friend_management_contract.sql` và
bản vá `20260923120000_accept_supabase_auth_phone_format.sql` qua 68/68 kiểm tra
PostgreSQL 18 cô lập, gồm định dạng Auth `84…`, hai client gửi ngược chiều đồng
thời và rollback khi tạo mirror lỗi. C2 regression hiện có qua 47/47. Cả hai
migration đã apply exact Staging; Production chưa apply.

### F2 — Domain, gateway và local cache

**Phạm vi:** typed entities, repository, Supabase RPC adapter, owner-scoped cache,
pagination và Realtime invalidation.

**Exit:** fake HTTP/SQLite tests pass cho pagination, stale result, account switch,
offline read và duplicate invalidation.

**Trạng thái:** `IMPLEMENTED/LOCAL VERIFIED` ngày 2026-09-22. Client mới chỉ gọi
các RPC F1, dùng private Supabase client với access token bất biến, kiểm tra lại
session trước/sau request và coi Realtime `friends` là tín hiệu invalidation.
Cache nằm trong DB riêng `capy_friends.db`, mọi row/meta đều scope theo
`project_ref + owner_id`; email và phone không có trong entity/schema cache.

**Evidence:** analyzer toàn dự án sạch; 14/14 test fake HTTP/SQLite pass và full
Flutter suite 615 pass + 1 opt-in Staging test skip; Web build pass. F2 tests bao
phủ exact RPC payload, keyset pagination tới trang rỗng, thứ tự/cursor sai,
safe error, stale in-flight response, account switch trước commit, single-flight,
duplicate peer, timestamp chống hồi quy trạng thái, project/account isolation và
cold reopen đọc offline với 0 remote call. Tại checkpoint F2 chưa nối
provider/UI F3 và chưa gọi Staging/Production; trạng thái F3 ở mục kế tiếp.

### F3 — Tìm kiếm và gửi lời mời UI

**Phạm vi:** `AddFriendModal`, bộ chọn phương thức, validation, result card,
discovery settings/verification entry, send state và error UX.

**Exit:** phone 320 px, wide/Web, keyboard, screen reader và duplicate tap tests
pass; username/email/phone exact lookup đều có trạng thái hợp lệ, opt-out và
unverified được xử lý mà không lộ nguyên nhân.

**Trạng thái:** `IMPLEMENTED/LOCAL VERIFIED` ngày 2026-09-22. Màn Bạn bè chỉ
thêm CTA `Thêm bạn` khi `FRIENDS_ENABLED=true`; mặc định cờ vẫn tắt. Modal có
debounce 350 ms, validation/normalize riêng cho username, email và phone Việt
Nam, bỏ response cũ khi query/account đổi, chặn thao tác offline và khóa double
tap. Result chỉ render public profile và đủ năm state quan hệ. Settings có hai
công tắc opt-in riêng, mặc định tắt, chỉ bật được khi server trả contact đã xác
minh; lỗi backend được ánh xạ sang thông báo an toàn.

**Evidence:** analyzer toàn dự án sạch; **45/45** test Friends + Settings pass,
gồm phone 320 px, text scale 1.3, bàn phím, Web rộng tối đa 640 px, semantics,
touch target 48–50 dp, username/email/phone normalized exact lookup, năm action
state, stale response, account switch, offline, duplicate tap và verification
gate. Full Flutter suite **633 pass + 1 opt-in Staging test skip**; Web build
pass. Mobile-audit regex báo false positive vì coi kích thước icon/gap/progress
là touch target; kiểm thử widget đo control mới xác nhận nút 48–50 dp.

**Lịch sử checkpoint:** tại F3 chưa có entry OTP. Increment hoàn thiện sau F6 đã
thêm luồng Supabase Auth phone-change OTP và vẫn fail closed. Exact-Staging
synthetic OTP được xác minh ngày 2026-09-24; SMS thật chưa chạy vì cấu hình Twilio
thiếu credential. Không có remote write, migration apply hoặc deploy trong F3.

### F4 — Inbox và chấp nhận/từ chối

**Phạm vi:** incoming/outgoing tabs, badge, atomic response, refresh và cached
state.

**Exit:** A gửi → B nhận → B accept/reject; account-switch không lộ request;
offline mutation fail nhanh và có thông báo phục hồi được.

**Trạng thái:** `IMPLEMENTED/LOCAL VERIFIED` ngày 2026-09-22. Màn Friends có ba
tab `Lời mời`, `Đã gửi`, `Bạn bè`; tab thứ ba giữ nguyên nội dung cũ. Provider
đọc incoming/outgoing cache trước, đồng bộ nền sau đó, refresh khi Realtime báo
thay đổi và tách state lỗi/refresh theo từng danh sách. Accept/reject có
single-flight theo peer, khóa cả hai action của đúng hàng đang xử lý và chỉ bỏ
row sau kết quả server thành công. Reject không refresh accepted list; accept
refresh incoming và accepted. Account/session đổi dispose subscription và không
render dữ liệu owner cũ.

**Evidence:** notifier + widget F4 **10/10**; toàn Friends **40/40**; Friends +
Settings **55/55**. Ca kiểm thử bao phủ cache-first/background refresh, Realtime,
double accept chỉ gọi một mutation, accept/reject, offline zero remote call,
account switch, outgoing read-only và bố cục 320 px với text scale 1.3/touch
target 48 dp. Full Flutter **643 pass + 1 opt-in Staging skip**; analyzer toàn dự
án sạch; Web build pass với các warning phụ thuộc Wasm/Cupertino font có sẵn.
Mobile-audit regex vẫn báo false positive khi coi icon/font/padding là touch
target; widget test đo trực tiếp các control F4 là 48 dp.

**Giới hạn:** chưa gọi/apply/deploy hoặc ghi Staging/Production; vì vậy chuỗi A
gửi → B nhận → B accept/reject mới được chứng minh bằng fake repository/local
cache, chưa phải live A/B evidence. Cờ `FRIENDS_ENABLED` vẫn mặc định tắt cho tới
F6. F4 không đổi schema/version `capy_friends.db` và không thay contract F1.

### F5 — Danh sách bạn bè và Chat handoff

**Phạm vi:** `FriendListItem`, accepted list, pagination, public profile và mở
direct Chat qua contract hiện có.

**Exit:** hai phía thấy cùng quan hệ; outsider không thấy; accepted peer mở đúng
canonical conversation; inactive/rejected không mở Chat.

**Trạng thái:** `IMPLEMENTED/LOCAL VERIFIED` ngày 2026-09-23. Tab `Bạn bè` đọc
accepted snapshot owner-scoped từ SQLite trước, refresh toàn bộ keyset pages ở
nền và cập nhật lại khi Realtime invalidation đến. Card chỉ hiển thị public
profile: avatar, display name, username, điểm, streak và level; không đọc/render
raw email hoặc phone. Offline/lỗi giữ danh sách cache và có retry.

Chat handoff chỉ bật khi owner Friends/Chat trùng project + account và hồ sơ ngôn
ngữ local của chính tài khoản hợp lệ. Trước RPC, provider kiểm tra mạng, refresh
accepted snapshot rồi xác nhận peer vẫn accepted. Sau đó nó gọi contract hiện có
`OperationalChatCoordinator.openDirectChat(peerId)` và chỉ điều hướng
`/chat/:conversationId` bằng UUID server trả về. RPC vẫn kiểm tra authoritative
mutual acceptance và hồ sơ ngôn ngữ của cả hai; peer thiếu điều kiện nhận thông
báo an toàn. Account/session đổi trước, trong hoặc sau await đều không điều hướng
dữ liệu owner cũ.

**Evidence:** F5 notifier/widget **10/10**; toàn Friends **50/50**; Friends +
Settings **65/65**. Coverage gồm cache-first/background refresh, Realtime,
pagination regression, offline zero RPC, revoked relation chặn Chat, canonical
conversation route, language-profile gate, account-switch race, public-only
semantics và Chat action 48 dp trên 320 px/text scale 1.3. Full Flutter **653
pass + 1 opt-in Staging skip**; analyzer sạch; Web build pass với warning phụ
thuộc Wasm/Cupertino font có sẵn. Mobile-audit regex vẫn báo false positive do
coi icon/font/padding/gap là touch target; widget test đo control thật là 48 dp.

**Giới hạn:** F5 không đổi schema/version `capy_friends.db` hoặc Chat schema.
Exact-Staging E2E đã hoàn tất ở F6. Cờ `FRIENDS_ENABLED` vẫn mặc định tắt để việc
bật rollout là một thay đổi sản phẩm riêng; Production chưa apply Friends.

### F6 — Exact-Staging E2E

**Phạm vi:** backup/preflight, apply migration sau approval, ba account fixture,
REST/Realtime ba client và cleanup.

**Exit:**

- A tìm thấy B lần lượt bằng exact username, email đã opt-in và phone đã
  verified/opt-in nhưng không nhận raw email/phone trong response.
- A không tìm thấy B qua email/phone khi B opt-out; response giống tài khoản
  không tồn tại.
- A gửi một request; retry không tạo duplicate.
- A không thể tự accept; outsider C không thể đọc hoặc sửa.
- B thấy incoming và accept; A/B đều có accepted list giống nhau.
- Chat mở được sau accept và bị chặn trước accept.
- Reject path pass với fixture riêng.
- Logout/account switch không lộ cache.
- Auth/row/cache fixture cleanup về baseline; Production không bị truy cập.

**Trạng thái:** `EXACT-STAGING VERIFIED`, chạy lại thành công ngày 2026-09-24.
Backup mã hóa được tạo
trước mỗi lần apply. Migration F1 và bản vá Auth phone đều xuất hiện đúng một
lần trong history; post-apply dry-run trả `upToDate=true`. Bản vá giữ yêu cầu
`phone_confirmed_at` và chỉ coi ba biểu diễn tương đương `0…`, `+84…`, `84…`
là cùng một số Việt Nam đã chuẩn hóa.

**Evidence:** runner `tool/run_staging_friend_f6_e2e.ps1` dùng ba tài khoản
synthetic A/B/C và ba WebSocket thật. Username/email/phone, opt-in/opt-out,
public-only projection, send retry, incoming/outgoing, accept hai chiều, reject,
outsider RLS/Realtime isolation và canonical Chat đều pass. Cleanup theo đúng
`test_scope + run_id` trả Auth/profile/friends/chat về baseline và còn 0 fixture;
Production/Training/Library writes đều bằng 0. SQL local **68/68**, Friends +
Settings **65/65**, full Flutter **653 pass + 1 opt-in skip**, analyzer sạch.

**Rerun 2026-09-24:** exact Staging vẫn `ACTIVE_HEALTHY`; preflight và hậu kiểm
`db push --linked --dry-run` đều trả `upToDate=true`. F6 live pass đủ tám nhóm,
gồm ba verified account, exact discovery/consent, ba WebSocket thật, forged/self/
outsider denial, idempotent request, accepted list đối xứng, canonical Chat và
reject path. Cleanup trả `fixture_count_remaining=0`; Production, Training và
Library đều `0 writes`.

### Hoàn thiện sau F6 — rollout UI và phone OTP

**Trạng thái 2026-09-24:** `SOURCE/LOCAL/STAGING SYNTHETIC OTP VERIFIED`; SMS thật
chờ cấu hình đủ credential Twilio trên exact Staging.

- Hai widget scaffold cũ `AddFriendModal` và `FriendListItem` đã có triển khai
  thật. Accepted list dùng thẻ public-profile chung; màn chính chỉ còn nhãn
  `Bạn bè`, không hứa hẹn leaderboard tuần trước khi có point ledger.
- Lối mở trang Chat cũ được giữ tương thích. Môi trường không bật Friends hiển
  thị trạng thái không khả dụng rõ ràng, không còn nhãn “Đang phát triển”.
- Settings gửi OTP đến số private đã lưu trong `public.users` của owner, chuẩn
  hóa `0…`/`+84…`/`84…`, từ chối số Auth khác số profile, che số khi render,
  khóa double tap và chỉ nhận mã sáu chữ số. Raw phone/OTP không được cache,
  log hoặc đưa vào entity Friends.
- `tool/run_staging_device_smoke.ps1` và `tool/run_bluestacks.ps1 -Staging` bật
  `FRIENDS_ENABLED=true`; cờ mặc định vẫn `false`, owner vẫn khóa exact host
  `nxteaznowkfennxpqjmt.supabase.co`, Production chưa apply migration.
- Verification: Friends + Settings + màn Chat liên quan **86/86**; full Flutter
  **658 pass + 1 opt-in skip**; analyzer toàn dự án sạch. Exact-Staging migration
  dry-run trả `upToDate=true` và Web build với Friends + Chat bật đã pass. Warning
  Web còn lại thuộc `flutter_tts` Wasm interop/Cupertino font đã có sẵn.
- Lần thử từ tài khoản người dùng xác nhận client đọc đúng số private nhưng Auth
  trả HTTP 500 ở bước cập nhật phone. Management config cho thấy provider được
  chọn là Twilio nhưng thiếu Account SID, Auth Token và Message Service SID, nên
  chưa thể gửi SMS thật.
- Smoke synthetic dùng test OTP chính thức của Supabase đã pass trọn luồng trên
  exact Staging: request 200, verify 200, có `phone_confirmed_at`, gọi
  `sync_my_verified_friend_phone()` và đọc lại `phone_verified=true`. Fixture Auth
  đã xóa; `external_phone_enabled=false`, test OTP rỗng và cổng Web test đã đóng.
  Backup cấu hình nằm ngoài repo tại
  `C:\Users\ASUS\AppData\Local\CapyVocabApp\staging_backups\20260923T195806Z-friends-phone-otp-smoke`.

## 8. Ma trận test bắt buộc

### SQL

- anonymous denied;
- exact username/email/phone normalization và validation;
- email chưa confirmed, phone chưa verified và contact opt-out đều không match;
- chỉ owner thay đổi discovery settings; client không tự set phone verified;
- đổi phone xóa verified state và tắt phone discovery;
- lookup response/log/cache không chứa raw email/phone;
- self-request denied;
- duplicate/lost-response idempotency;
- incoming/outgoing direction đúng;
- sender/outsider forged accept denied;
- recipient accept atomic hai row;
- reject không tạo mirror;
- concurrent send/accept không tạo trạng thái một chiều;
- public projection không lộ email/phone;
- existing Chat friendship trigger và `open_direct_chat` regression.

### Flutter

- codec/domain validation;
- owner/project cache isolation;
- account switch trong lúc search/pull/mutation;
- keyset pagination và duplicate merge;
- debounce/cancel stale search cho cả ba phương thức;
- discovery settings mặc định tắt, verification gate và trạng thái lỗi;
- offline cached list + mutation fail-fast;
- từng relationship state render đúng CTA;
- narrow/wide/large text không overflow;
- accessibility label và touch target tối thiểu 48×48.

### Live Staging

- ba tài khoản synthetic với email/phone test đã xác minh theo đúng luồng, hai
  thiết bị/client logic;
- bật/tắt email và phone discoverability rồi xác minh lookup thay đổi đúng;
- Realtime chỉ invalidate, snapshot mới là authoritative;
- retry/lost ACK;
- RLS outsider;
- cleanup và baseline counts;
- không ghi Production, Training, Library hoặc Chat content ngoài fixture.

## 9. Điều kiện bàn giao sang bảng xếp hạng

Chỉ bắt đầu leaderboard khi F1–F6 đạt và repository trả ổn định:

- `self + accepted friend IDs`;
- public profile của từng ID;
- account-scoped Realtime/cache;
- pagination và cleanup đã live verified.

Leaderboard tuần vẫn cần milestone dữ liệu riêng:

- append-only point event ledger có `source`, `amount`, `occurred_at`,
  idempotency key và week bucket;
- RPC cộng điểm nguyên tử phía server;
- RPC xếp hạng chỉ tổng hợp `self + accepted friends`;
- bỏ luồng client đọc rồi tự cập nhật `study_points` vì có race và không đủ làm
  điểm tuần đáng tin cậy.

## 10. Ngoài phạm vi

- Đồng bộ danh bạ, tìm gần đúng/prefix và tìm phone ngoài contract Việt Nam.
- Hiển thị email/số điện thoại của người khác trong kết quả hoặc danh sách.
- Block/report/mute và gợi ý bạn bè.
- Leaderboard, point ledger, streak reward và daily quest.
- Solo Arena hoặc mời chơi game.
- Group chat.
- Production rollout.

## 11. Definition of Done

- F1–F6 đều đạt exit criteria.
- Không còn TODO trong domain/provider/widget thuộc phạm vi Friends MVP.
- SQL, Flutter, analyzer, format và full regression pass.
- Exact-Staging search/send/respond/list/Chat handoff và cleanup pass.
- Không lộ dữ liệu riêng tư hoặc cache chéo tài khoản.
- Email/phone discovery có consent riêng, verification gate, generic not-found
  và rate limit phía server.
- `friend.md` và `db_status.md` được cập nhật bằng evidence thật.
- Chưa tuyên bố leaderboard hoàn thành cho đến khi point ledger/RPC riêng được
  triển khai và xác minh.
