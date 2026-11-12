# Kế hoạch rule xu (Capy Coins)

## Đồng bộ GitHub ngày 2026-10-07

Đã nhập source Home từ `origin/home` tại `664a7c9` theo yêu cầu đồng bộ toàn bộ chức năng mới. Hai game ảnh, session SQLite, đồng bộ kết quả, thưởng xu vàng và leaderboard đã có implementation; nhận định scaffold/chưa triển khai bên dưới là snapshot trước đồng bộ. Luồng Home hiện hành được mô tả trong [home.md](../home.md); kiểm chứng bản tích hợp và khác biệt với các đề xuất cũ nằm trong [github-home-sync-2026-10-07.md](github-home-sync-2026-10-07.md). Các rule đề xuất chưa khớp implementation không được xem là đã nghiệm thu hoặc tự động thay thế contract hiện hành.


Trạng thái: **đề xuất để duyệt, chưa triển khai giao dịch**. Phạm vi: xu gắn với tài khoản, cấp xu, tiêu xu, hoàn/điều chỉnh, hiển thị số dư; Pet Shop, Solo Arena và nạp xu chỉ áp dụng khi từng tính năng được mở. `study_points` là điểm học tập và **không** được cộng vào số dư xu. Scan credit là hạn mức AI Scan, **không** phải xu.

## 1. Bằng chứng hiện trạng và ranh giới

- `public.users.total_coins` là `int default 100 check (total_coins >= 0)` trong migration `20260725204011_initial_schema.sql`; trigger `handle_new_user` chỉ điền ID/email/tên, nên default 100 được dùng cho tài khoản mới. Đây là **hiện trạng schema**, chưa phải quyết định sản phẩm về thưởng đăng ký.
- Migration `20260730151830_harden_onboarding_security.sql` chỉ cấp quyền `UPDATE` một số cột hồ sơ, không có `total_coins` hoặc `study_points`. Client hiện không có quyền cập nhật trực tiếp hai cột này qua role `authenticated` theo migration đó. Cần kiểm chứng grant thực tế ở môi trường đích trước rollout.
- `UserSupabaseDataSource.addXpAndCoins` vẫn đọc hồ sơ rồi ghi lại cả điểm và xu. `ShopSupabaseDataSource.purchaseItem` đọc số dư, trừ xu, ghi inventory, ghi purchase bằng các request riêng; `itemPrice` và `userId` do caller truyền. Không có transaction xuyên bốn bước, khóa số dư hay idempotency được thể hiện trong code này.
- Pet Shop là coming-soon UI; Solo Arena là scaffold, `createMatch` chỉ tạo hàng trận với `bet_amount`; PaymentService trả kết quả giả lập. `PROJECT_STATUS.md` và `plan_business.md` chưa xem các luồng này là đã tích hợp. Không gọi các datasource/scaffold này là đường giao dịch xu đã hoạt động.
- Tài liệu này không sửa schema, migration, client, cloud hay `db_status.md`. Khi triển khai bất kỳ thay đổi DB/Supabase nào, cập nhật `db_status.md` cùng increment theo `AGENTS.md`.

## 2. Ngôn ngữ và mô hình chuẩn đề xuất

| Khái niệm | Định nghĩa/rule |
|---|---|
| `owner` | `auth.uid()` sau khi server xác thực. Client không được chỉ định chủ sở hữu có hiệu lực bằng `userId` trong body. |
| `balance` | Số xu **đã xác nhận** của một tài khoản, kiểu số nguyên. Không dùng `double`, không chấp nhận âm, `null` hoặc overflow. |
| `event` | Một nguyên nhân nghiệp vụ có ID ổn định làm thay đổi xu: cấp thưởng, mua vật phẩm, hoàn xu, điều chỉnh, đặt cược/trả cược. |
| `operation_id` | ID duy nhất do client/server tạo trước lần gửi đầu, giữ nguyên qua retry của cùng thao tác. Cùng ID nhưng payload khác phải báo xung đột. |
| `source_key` | Khóa duy nhất của nguồn thưởng/hoàn/nạp đã được server xác minh; ví dụ `(source_type, source_id, owner)`. Cản phát xu hai lần qua hai `operation_id` khác nhau. |
| `ledger` | Nhật ký append-only của các biến động xu đã commit, có owner, amount có dấu, loại, nguồn, operation ID, thời gian server và số dư sau giao dịch. Sửa sai bằng event bù, không sửa/xóa event cũ. |
| Trạng thái UI | `confirmed` đọc từ server, `pending` chỉ mô tả thao tác chưa xác nhận, `unknown` khi chưa thể xác định kết quả. Số pending không được cộng vào số dư khả dụng. |

**Source of truth mục tiêu:** Postgres transaction phía server là nơi duy nhất chốt số dư và ledger. `public.users.total_coins` nên là số dư materialized được cập nhật trong cùng transaction với ledger; ledger là nguồn kiểm toán/đối soát. Hai giá trị phải khớp theo công thức tại mục 3. Client cache, Realtime và thông báo UI chỉ là bản sao. Đường ghi là RPC/handler được khóa quyền và kiểm chứng theo từng nghiệp vụ; không mở RPC “cộng N xu” tự do cho client.

## 3. Invariant toàn hệ thống

Mức vi phạm: **P0** = sai lệch số dư, phát/tiêu trùng, truy cập trái phép hoặc mất tính nguyên tử; chặn rollout và xử lý ngay. **P1** = sai hiển thị/phân loại khi số dư server vẫn đúng; sửa trước khi mở rộng rollout. Đây là mức nghiêm trọng của **vi phạm rule**, không phải mức ưu tiên triển khai tính năng.

| ID | Invariant bắt buộc | Mức vi phạm | Nơi enforce chính | Chứng minh |
|---|---|---|---|---|
| COIN-I01 | Với mỗi owner, `balance = SUM(committed ledger.amount)`, trong đó đúng một event `opening` chứa số dư đầu kỳ; không có event committed mà balance chưa đổi hoặc ngược lại. | P0 | Một DB transaction; job đối soát read-only | T-01, T-10 |
| COIN-I02 | `0 <= balance <= INT_MAX`; mọi `amount` là số nguyên khác 0 và không overflow. Giá 0 chỉ hợp lệ khi catalog đánh dấu vật phẩm miễn phí. | P0 | Constraint + RPC validation | T-02 |
| COIN-I03 | Một `operation_id` có tối đa một kết quả committed; cùng ID/cùng payload trả lại kết quả cũ, cùng ID/khác payload bị từ chối. | P0 | Unique index + RPC | T-03 |
| COIN-I04 | Một `source_key` chỉ phát xu một lần cho đúng owner. | P0 | Unique index + kiểm tra nguồn server | T-04 |
| COIN-I05 | Client không thể sửa số dư, ledger, giá, tồn kho, kết quả trận, trạng thái thanh toán hoặc sự kiện thưởng để tự tạo xu. | P0 | GRANT/RLS + server authorization | T-05 |
| COIN-I06 | Tiêu xu chỉ commit nếu số dư khả dụng tại thời điểm khóa tài khoản đủ; không có âm số dư hoặc hai giao dịch đồng thời cùng tiêu một khoản. | P0 | Row lock/atomic conditional update trong DB | T-06 |
| COIN-I07 | Một purchase committed tương ứng đúng một debit và đúng một quyền sở hữu/vật phẩm; mọi thành phần cùng commit hoặc cùng rollback. | P0 | DB transaction | T-07 |
| COIN-I08 | Một lần đặt/trả cược, hoàn hoặc điều chỉnh chỉ gắn với đúng một sự kiện nguồn và đúng một chuyển trạng thái hợp lệ. | P0 | DB state machine + unique source key | T-08 |
| COIN-I09 | Số dư của tài khoản A không lộ sang B qua API, cache, Realtime, đăng xuất/đổi tài khoản. | P0 | RLS + cache owner fence | T-09 |
| COIN-I10 | Xu, điểm học tập và scan credit có ledger/nguồn riêng; không tự quy đổi hoặc chi chéo. | P1 | Domain contract + API validation | T-11 |

`opening_balance`: khi migration ledger diễn ra, tạo đúng một event `opening` cho **số dư thực tế được xác minh** của mỗi tài khoản hiện hữu. Tài khoản mới có đúng một event khởi tạo theo chính sách sản phẩm đã duyệt. Không cộng mặc định 100 lần nữa trên tài khoản cũ. Đối soát lệch phải cảnh báo và chặn phát hành/tiêu trên tài khoản liên quan cho tới khi sửa bằng quy trình có audit; không âm thầm sửa số dư.

## 4. Rule nghiệp vụ: điều kiện vào → kết quả ra

| ID | Điều được phép xảy ra; điều kiện đầu vào | Kết quả thành công | Tuyệt đối không được xảy ra; lỗi/edge case | Enforce | Test | Mức |
|---|---|---|---|---|---|---|
| COIN-01 Khởi tạo | Auth tạo tài khoản mới; chưa có `opening` cho owner. | Tạo profile và đúng một số dư khởi tạo theo chính sách, có `opening` cùng transaction. | Trigger chạy lại hoặc retry không cấp lần hai; không suy ra 100 xu khi không có profile. Lỗi tạo profile phải rollback hoặc đánh dấu account chưa sẵn sàng. | DB trigger/RPC | T-01, T-03 | P0 |
| COIN-02 Cấp thưởng học tập | Server xác minh activity đủ điều kiện, owner, rule version, source ID chưa dùng, quota/cooldown theo cấu hình đã duyệt. | Một credit với amount do rule server xác định; trả `balance_after` và event ID. | Client gửi `coinsGained`/`xpGained` không là bằng chứng; repeat, activity giả, activity bị hủy, amount âm/0 không cấp xu. Nếu học offline, chỉ cấp sau khi server xác minh; không xác minh được thì giữ pending hoặc từ chối. | Nguồn activity + reward RPC | T-04, T-12 | P0 |
| COIN-03 Mua bằng xu | Owner đã xác thực; item đang bán; giá lấy từ catalog server; chưa sở hữu nếu item chỉ mua một lần; số dư đủ tại lúc commit. | Trừ đúng giá, thêm inventory và purchase receipt với cùng operation ID; trả số dư và item. | Không tin `itemPrice`, `paymentMethod`, `userId` từ client; item hết bán/đổi giá/đã sở hữu/thiếu xu thì không có debit hay inventory. Cần chính sách riêng cho item mua lặp. | Purchase RPC trong DB | T-06, T-07 | P0 |
| COIN-04 Hoàn xu | Có purchase/charge gốc committed; lý do hợp lệ; actor có quyền; tổng số đã hoàn và số xin hoàn không vượt số đã trừ. | Credit bù gắn event gốc và receipt; cập nhật/thu hồi item theo chính sách đã duyệt trong cùng transaction. | Không replay cùng yêu cầu hoàn, không hoàn quá số đã trả, không xóa event gốc. Việc cho phép hoàn một phần và xử lý item đã dùng/equip phải được duyệt trước khi thực thi. | Refund RPC + audit | T-08 | P0 |
| COIN-05 Điều chỉnh thủ công | Actor quản trị được ủy quyền, có lý do/ticket, amount và owner hợp lệ, giới hạn quyền. | Event bù có actor và reason; balance thay đổi atomically. | Client thường không gọi được; không chỉnh trực tiếp cột balance hay sửa ledger; debit không vượt số dư trừ khi có chính sách nợ được duyệt. | Privileged server path | T-05, T-08 | P0 |
| COIN-06 Đặt cược Solo | Chỉ khi Solo Arena được mở và chính sách cược được duyệt; match hợp lệ, hai bên đủ xu, match chưa bắt đầu. | Giữ/trừ tiền cược đúng một lần mỗi bên và chuyển match sang trạng thái chơi cùng transaction. | Không cho một bên đặt cược nhiều lần, tự ghi thắng/thua, cược âm/0 hoặc vượt giới hạn. Không cho match bắt đầu khi một bên chưa lock cược. | Match RPC/state machine | T-08, T-13 | P0 |
| COIN-07 Kết toán Solo | Kết quả trận được server xác minh; match đang chơi; chưa kết toán. | Credit thưởng/trả cược theo công thức đã duyệt, chuyển match sang completed cùng transaction. | Không tin `winner_id`/score do một client tự gửi; không trả hai lần; hòa/ngắt mạng/timeout/cancel phải có công thức rõ trước rollout. | Settlement RPC | T-08, T-13 | P0 |
| COIN-08 Nạp xu bằng tiền | Chỉ khi payment được mở; receipt/webhook được xác minh phía server, đúng product/owner/currency, external transaction ID chưa dùng. | Credit đúng gói xu và lưu tham chiếu thanh toán đã xác thực. | `PaymentService.processPayment` giả lập hoặc client báo success không cấp xu; webhook lặp không cấp lần hai; chargeback dùng event đảo theo policy. | Payment verifier + credit RPC | T-04, T-14 | P0 |
| COIN-09 Hiển thị | Owner đọc balance của chính mình; payload hợp lệ và có phiên hiện hành. | UI hiển thị số dư confirmed, thời điểm cập nhật và trạng thái pending/unknown khi cần. | Không hiển thị cache tài khoản khác; không dùng số dư stale làm quyết định mua; Realtime đến lệch thứ tự không được giảm phiên bản đã xác nhận. | RLS + client repository | T-09, T-15 | P1 |

Các nguồn như daily quest, streak reward, quảng cáo thưởng, referral chưa có rule định lượng/nguồn xác minh trong repo. Mỗi nguồn mới phải có `source_key`, bằng chứng đủ điều kiện, mức thưởng, giới hạn, thời gian hiệu lực, cơ chế thu hồi và test giống COIN-02 trước khi bật. Không gộp rewarded-ad scan credit vào xu nếu chưa có quyết định sản phẩm riêng.

## 5. State, offline, retry và concurrency

### State của thao tác xu

`created_local` → `submitted` → một trong `committed`, `rejected`, `unknown`.

- `committed` và `rejected` là kết quả cuối theo `operation_id`; retry trả lại đúng kết quả đã lưu. `unknown` nghĩa là client mất ACK hoặc timeout, **không** có nghĩa thất bại. Client truy vấn trạng thái cùng ID rồi mới cho thử lại.
- Không tạo `operation_id` mới cho cùng tap/retry. Chặn double-tap ở UI chỉ giúp UX; unique key và transaction trên server mới là bảo đảm.
- Khi offline, đọc số dư confirmed gần nhất nếu cache thuộc đúng owner và ghi rõ là số dư cũ. Mua, nạp, hoàn, cược không được xác nhận offline. Có thể queue ý định thưởng học tập nếu có bằng chứng activity và ID ổn định; chỉ server mới cấp xu sau sync. Việc có queue thưởng hay không là quyết định sản phẩm/thiết kế nguồn activity.
- Mọi mutation tuần tự hóa theo owner ở DB; hai thiết bị và retry cùng lúc phải cho kết quả tương đương một thứ tự commit hợp lệ. Không dùng read-modify-write ở Flutter.
- Client đổi tài khoản, logout hoặc token hết hạn: hủy/ẩn pending của phiên cũ và xóa/partition cache theo owner. Request cũ khi tới server vẫn được xét theo auth tại thời điểm xử lý; kết quả không hiển thị trên phiên owner khác.

### Lỗi giữa chừng

| Điểm lỗi | Kết quả bắt buộc |
|---|---|
| Trước khi bắt đầu DB transaction | Không có ledger, balance, inventory hay purchase mới. Client có thể retry cùng ID. |
| Sau validation nhưng trước commit | Toàn bộ transaction rollback; không cấp/trừ xu một phần. |
| DB commit thành công nhưng mất ACK | Query bằng operation ID trả receipt đã commit; không thực hiện thêm một biến động. |
| Inventory/receipt/settlement ghi lỗi | Rollback cả balance và ledger. |
| Realtime trễ, lặp hoặc đảo thứ tự | Re-fetch snapshot hoặc áp dụng version tăng dần; không suy ra balance bằng cách cộng event trên client. |
| Upstream payment/ads timeout | Không credit cho đến khi nguồn được xác minh; webhook/reconciliation retry theo external ID. |
| Job đối soát thấy lệch | Cảnh báo P0, tạm khóa mutation owner liên quan, điều tra; sửa bằng event bù có audit và quy trình được duyệt. |

## 6. Nơi enforce và hợp đồng API mục tiêu

1. **DB schema:** ledger append-only; unique `(owner, operation_id)` và unique `source_key` theo từng nguồn; `CHECK` amount/range; foreign key tới nguồn; trạng thái transaction; index tra cứu owner và source. Chỉ role server được ghi ledger/balance trực tiếp.
2. **DB transaction/RPC:** xác thực `auth.uid()` hoặc service actor; kiểm tra quyền theo loại event; đọc giá/rule từ server; khóa owner; ghi ledger, balance và tài nguyên liên quan trong một transaction; trả `{operation_id, status, event_id, balance_after, resource_id}`. `SECURITY DEFINER` chỉ khi thực sự cần, khóa `search_path`, thu hồi quyền `PUBLIC`, kiểm tra actor trong thân hàm, và cấp `EXECUTE` tối thiểu.
3. **Nguồn sự kiện:** activity học tập, catalog, match result, payment webhook có validator riêng. RPC generic cộng/trừ tùy ý không được mở cho authenticated client.
4. **Flutter:** tạo ID ổn định, gửi request, hiển thị `pending/unknown/confirmed`, reconcile sau reconnect; không tính toán số dư authoritative hoặc ghi thẳng `total_coins`. Thay đường `addXpAndCoins` và `purchaseItem` trước khi bật tính năng liên quan; tách XP và xu theo contract riêng.
5. **Quan sát:** metrics duplicate/conflict/insufficient/rollback, đối soát balance-ledger, log không chứa token, receipt thô hoặc dữ liệu nhạy cảm. Admin adjustment có audit actor/lý do.

## 7. Bộ test chấp nhận tối thiểu

| ID | Test và kỳ vọng |
|---|---|
| T-01 | Tạo tài khoản, replay trigger/init, migration opening cho tài khoản cũ: đúng một opening; balance bằng tổng ledger. |
| T-02 | Amount 0, âm sai chiều, `INT_MAX` overflow, balance âm, null và giá 0 sai catalog đều bị từ chối; không side effect. |
| T-03 | Gửi 10 request cùng ID song song: một event; retry cùng payload trả receipt cũ; khác payload nhận conflict. |
| T-04 | Hai ID khác nhau nhưng cùng activity/payment external ID: một credit. Nguồn giả/owner sai: 0 credit. |
| T-05 | REST/SQL với `anon`, user A, user B thử sửa `total_coins`, ledger, giá, inventory, kết quả trận và gọi RPC sai quyền: đều bị từ chối. |
| T-06 | Hai purchase song song khi chỉ đủ tiền cho một: đúng một thành công; balance không âm. |
| T-07 | Inject lỗi sau debit, sau inventory, sau receipt: rollback toàn bộ; retry cùng ID cho đúng một purchase. |
| T-08 | Refund/adjust/settle lặp, sai trạng thái, sai actor, vượt số tiền gốc: không phát/trừ lần hai. |
| T-09 | Hai tài khoản trên cùng thiết bị, logout/login, Realtime stale và cache cold restart: không lộ xu/cập nhật chéo. |
| T-10 | Tính lại tổng ledger cho nhiều owner; sai lệch tạo cảnh báo và khóa mutation theo chính sách. |
| T-11 | XP tăng không tự tăng xu; scan credit không đổi xu; xu không dùng thay scan credit. |
| T-12 | Activity hợp lệ/không hợp lệ, offline retry, quota, cooldown, ngày đổi múi giờ: chỉ cấp khi điều kiện server thỏa. |
| T-13 | Hai bên đặt cược, match cancel/draw/disconnect, kết toán cạnh tranh: bảo toàn tổng xu theo công thức đã duyệt. |
| T-14 | Payment mock/client success, webhook giả, webhook lặp, chargeback: chỉ receipt xác minh được cấp đúng một lần. |
| T-15 | UI timeout sau commit rồi reconnect: trạng thái unknown chuyển committed từ receipt cũ; không nhân đôi hiển thị hay gửi giao dịch mới. |

Test DB cần chạy trên Postgres local với ít nhất hai session thật cho concurrency, sau đó smoke có kiểm soát trên exact Staging. Không áp dụng migration, deploy hoặc ghi Production trong bước lập rule. Mỗi test phải kiểm tra cả balance, ledger và tài nguyên nghiệp vụ; chỉ HTTP success chưa đủ chứng minh invariant.

## 8. Thứ tự triển khai và cổng nghiệm thu

1. **Chốt quyết định sản phẩm** ở mục 9. Chưa chốt thì giữ UI giao dịch xu ở trạng thái coming soon và không gọi datasource cũ.
2. **Khóa đường ghi cũ và lập baseline:** kiểm tra grant/RLS trên môi trường đích; chặn hoặc thay mọi client path có thể ghi `total_coins`; snapshot/đối soát số dư hiện hữu, xác định account bất thường trước migration. Exit: T-05 pass, danh sách nguồn xu có owner.
3. **Ledger + opening + RPC lõi:** migration additive, backfill không cộng trùng, transaction/idempotency, quyền tối thiểu; cập nhật `db_status.md`. Exit: T-01 đến T-06 và T-10 pass local; dry-run/rollback rehearsal.
4. **Nguồn thưởng đầu tiên:** chỉ tích hợp activity có bằng chứng server, thay `addXpAndCoins`, test offline/retry. Exit: T-11, T-12, T-15 pass.
5. **Pet Shop:** server catalog + purchase atomic, thay datasource cũ, receipt/UI. Exit: T-06, T-07, T-09 pass; kiểm tra multi-device.
6. **Solo Arena, nạp xu và nguồn khác:** từng tính năng là milestone riêng sau khi rule sản phẩm tương ứng được duyệt; không dùng `PaymentService` mock làm bằng chứng. Exit: T-08, T-13/T-14 pass theo tính năng.
7. **Rollout:** exact Staging backup → migrate → test → giám sát/đối soát; chỉ đề xuất Production sau khi kiểm tra đầy đủ và có kế hoạch rollback. Không auto commit/push/deploy.

## 9. Quyết định sản phẩm còn thiếu (chặn triển khai nghiệp vụ liên quan)

| Quyết định | Vì sao phải chốt |
|---|---|
| Xu khởi tạo cho tài khoản mới có tiếp tục là 100 không; tài khoản cũ giữ số dư hiện tại thế nào? | Ảnh hưởng trực tiếp số dư và migration opening. |
| Hoạt động nào được xu; mức xu, quota/ngày, cooldown, múi giờ, điều kiện thu hồi? | COIN-02/T-12 không thể định lượng nếu thiếu. |
| Item nào bán bằng xu; giá, phiên bản giá, item mua lại, item miễn phí, refund/equip policy? | Quyết định atomic purchase và refund. |
| Hoàn xu toàn phần hay từng phần; item đã sử dụng được hoàn không? | Quyết định giới hạn tổng hoàn và xử lý inventory. |
| Solo Arena có cược xu thật không; mức cược, phí, thưởng, hòa, cancel, disconnect, gian lận? | Quyết định bảo toàn xu và chuyển trạng thái trận. |
| Có nạp xu bằng tiền thật không; nền tảng thanh toán và chính sách hoàn/chargeback? | Quyết định verifier và tính pháp lý/kinh doanh. |
| Khi offline có lưu ý định nhận thưởng không, và activity nào có bằng chứng đồng bộ đáng tin? | Quyết định outbox và UX pending. |
| Ai được điều chỉnh xu, giới hạn, quy trình duyệt và lưu audit bao lâu? | Quyết định quyền quản trị và vận hành. |

**Quy tắc mặc định khi chưa quyết định:** không phát, trừ, đặt cược, nạp hoặc hoàn xu từ client; chỉ đọc số dư hiện có của chính tài khoản và giữ các tính năng giao dịch chưa mở. Đây là trạng thái an toàn đề xuất, không tuyên bố rằng toàn bộ server hiện đã enforce các rule mục tiêu.
