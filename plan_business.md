# Kế hoạch kiến trúc AI Scan và khả năng mở rộng kinh doanh

## Trạng thái

- Ngày lập: 2026-08-27.
- Cập nhật gần nhất: 2026-09-01.
- Trạng thái: Implementation `P0-P5` và `P4.1` đã hoàn thành; P6 đã có harness và đạt source/database checks nhưng load ladder và authenticated canary vẫn còn chờ.
- Phạm vi hiện tại: Tối ưu mã nguồn, RPD, entitlement, model routing, quyền sử dụng template và khả năng mở rộng.
- Đã triển khai remote: migration entitlement, scan ledger, circuit breaker và Edge Function P5 trên canary.
- Chưa thực hiện: Thanh toán thật, quảng cáo, credit, authenticated canary Free/Pro, stub load ladder, promote production hoặc nâng Gemini Tier 1.
- Phần nâng Gemini production project lên Tier 1 do chủ dự án thực hiện.

### Tiến độ đã xác nhận

| Mốc | Trạng thái | Bằng chứng chính |
| --- | --- | --- |
| P0 | Hoàn thành | Baseline dirty worktree, rollback manifest, Flutter/Deno baseline và remote version đã lưu. |
| P1 | Hoàn thành | Entitlement tập trung, subscription được harden và client không còn tự ghi subscription. |
| P2 | Hoàn thành | Model router Free/Pro đọc config phía server và đã có trên canary. |
| P3 | Hoàn thành | Request ID, idempotency và `ai_scan_requests` đã triển khai; image-hash cache tiếp tục hoãn. |
| P4 | Hoàn thành | Flutter entitlement provider và response tương thích ngược đã có; Flutter test cuối mốc đạt `196`. |
| P4.1 - Template entitlement | Hoàn thành local | `Mặc định` và `Tối giản` thuộc Free; `Tự thiết kế` dùng `ai_scan_advanced`, có paywall/fallback/restore tests. |
| P5 | Hoàn thành trên canary | Circuit breaker migration đã áp dụng; P5 Edge canary version `16`, SHA `c1a8a5cb...`. |
| Tier 1 | Chờ chủ dự án | Billing, budget alert và quota thực tế chưa có. |
| P6 | Đang thực hiện | Harness Gemini stub đã có; 72 Deno tests và DB/RLS checks đạt. Stub load ladder và authenticated canary còn chờ. |
| P7 | Chưa hoàn thành | Canary P5 đã deploy; soak và production promotion còn chờ. |
| P8 | Để sau | Payment, rewarded ads, credit và tier kinh doanh mới chưa triển khai. |

Trạng thái remote tại lần đối chiếu 2026-09-01:

- Production `gemini-vision-scan`: metadata version `35`, SHA `19059f670e...`; vẫn là bundle cũ và chưa nhận P1-P5.
- Canary `gemini-vision-scan-canary`: version `16`, SHA `c1a8a5cb...`; có entitlement, model router, ledger và circuit breaker P5.
- Canary liveness trả `200`; request thiếu JWT trả `401` trước khi ghi ledger hoặc gọi Gemini.
- Chủ dự án đã xác nhận scan giao diện thành công bằng một tài khoản Pro và một tài khoản Free sau khi đổi key tạm thời. Tuy nhiên Flutter mặc định vẫn gọi production version `35` và ledger remote có `0` row, nên chưa thể coi đây là authenticated test của canary P5.
- Các migration remote mới nhất gồm `harden_subscription_entitlements`, `add_ai_scan_request_ledger`, `restrict_ai_scan_ledger_service_role` và `add_gemini_model_circuit_breaker`.

### Thay đổi so với bản kế hoạch 2026-08-27

- Chuyển `P0-P5` từ trạng thái dự kiến sang trạng thái đã triển khai; giữ P6-P8 là công việc tiếp theo.
- Ghi nhận P5 đã được chủ dự án cho phép deploy lên canary version `16`; production vẫn giữ bundle cũ.
- Ghi nhận tài khoản demo nội bộ mặc định Pro bằng subscription dài hạn, thay vì dùng tài khoản này cho cả test Free và Pro.
- Chốt rằng không có cơ chế "3 Free + 1 Pro" trong hệ thống hiện tại.
- Bổ sung chính sách tách key theo môi trường nhưng không xoay nhiều key để né quota theo project.
- Giữ nguyên checkpoint Tier 1 vì billing/quota thật vẫn chưa được chủ dự án thực hiện.
- Bổ sung chính sách template: Free được dùng `Mặc định` và `Tối giản`; `Tự thiết kế` là quyền lợi Pro và phải dùng entitlement provider tập trung.

## 1. Yêu cầu kinh doanh đã chốt

- Tài khoản mới mặc định là `free`.
- Không cần tạo subscription Free cho mọi tài khoản.
- Subscription `active` và chưa hết hạn thì người dùng là `pro`.
- Subscription hết hạn hoặc bị hủy thì người dùng quay về Free.
- Ngoại lệ nội bộ: `capyvocabapp@gmail.com` là tài khoản demo Pro dài hạn thông qua subscription server-side `capy_pro_monthly`, hết hạn `2099-12-31`; không hard-code email này trong Flutter hoặc Edge Function.
- Không có chính sách tự động "3 lượt Free rồi 1 lượt Pro". Nếu cần ưu đãi kiểu này trong tương lai, phải thiết kế promotional entitlement/credit riêng phía server.
- Free sử dụng `gemini-3.5-flash-lite`.
- Pro sử dụng `gemini-3.7-flash`.
- Pro có thể fallback sang `gemini-3.6-flash` khi 3.7 gặp lỗi hệ thống.
- Free không được fallback sang model Pro.
- Model phải được chọn ở server; Flutter không được tự khai báo tier hoặc model.
- Free và Pro dùng chung response schema để không phải duy trì hai luồng UI.
- Sự khác biệt về chất lượng giữa Flash-Lite và Flash đã được kiểm tra thực tế và được chấp nhận làm quyền lợi Pro.
- Template `Mặc định` và `Tối giản` được mở cho cả Free và Pro.
- Template `Tự thiết kế`, editor tùy chỉnh và thao tác lưu mẫu tự thiết kế chỉ dành cho Pro.
- Free nhấn vào `Tự thiết kế` sẽ thấy paywall; không tự nâng quyền hoặc mở editor ở client.

### 1.1. Chính sách API key và quota

- `GEMINI_API_KEY` chỉ tồn tại trong Supabase Secrets; không đưa key vào Flutter, log hoặc repository.
- Có thể dùng key/project riêng cho test và production để cô lập môi trường, nhưng không round-robin nhiều key để né quota.
- Nhiều API key trong cùng Google Cloud project vẫn dùng chung RPM, TPM và RPD; đổi key cùng project không làm tăng quota.
- Không dùng nhiều tài khoản Google như cơ chế mở rộng sản phẩm hoặc né giới hạn Free Tier.
- Key rotation chỉ phục vụ bảo mật, thu hồi key hoặc tách môi trường; không phải thuật toán cân bằng RPD.
- Khả năng phục vụ nhiều người dùng phải dựa vào paid tier, quota thật, admission/credit, idempotency và kiểm soát tải.

## 2. Mục tiêu kỹ thuật

- Một scan thành công trung bình không vượt quá `1.05` Gemini request.
- Duplicate Gemini call bằng `0` đối với cùng user và request ID.
- Không thể gọi Gemini ngoài luồng xác thực và entitlement.
- Free và Pro có quota, retry, health và circuit breaker tách biệt theo model pool.
- Có thể thay model bằng config/canary mà không phát hành lại Flutter.
- Có thể thêm tính năng Pro sau này thông qua capability tập trung.
- Đủ khả năng load test từ `15` đến `500 RPM` sau khi nâng Tier 1.

## 3. Kiến trúc mục tiêu

```text
Flutter
  | JWT + request_id + image
  v
Supabase Edge: gemini-vision-scan
  |- Xác thực user
  |- Resolve entitlement/capabilities
  |- Kiểm tra idempotency
  |- Chọn model policy
  |    |- Free -> Gemini 3.5 Flash-Lite
  |    `- Pro  -> Gemini 3.7 Flash -> Gemini 3.6 Flash fallback
  |- Gọi Gemini
  |- Ghi model/token/attempt/latency/error
  `- Trả kết quả theo một response schema
```

## 4. Phân biệt tối ưu RPD với tối ưu token

RPD chỉ giảm khi giảm số lần gọi Gemini:

```text
RPD tiêu thụ
= unique scan
+ upstream retry
+ duplicate request bị lọt
+ synthetic Gemini health check
```

- `request_id`, idempotency, cache ngắn hạn và retry đúng cách giúp giảm RPD.
- Nén ảnh, rút prompt, giảm output và thinking chủ yếu giảm TPM, latency và chi phí; chúng không trực tiếp giảm một RPD của request đã gửi.

Mục tiêu:

- `calls_per_scan <= 1.05`.
- `duplicate_calls = 0`.
- Synthetic Gemini health không quá `2-4 request/model/ngày`.
- Không retry khi đã chạm RPD.

## 5. P0 - Baseline và bảo toàn mã nguồn hiện tại

Mã nguồn đang có nhiều thay đổi chưa commit trong khu vực AI Scan và Edge Function. Trước khi sửa:

1. Lưu `git status` và diff hiện tại.
2. Không ghi đè các thay đổi hierarchy, ranking, bounding box, health-store và Flutter scan flow.
3. Chạy baseline:
   - Flutter analyze.
   - Flutter tests liên quan AI Scan.
   - Deno check.
   - Deno tests.
   - Deno lint.
4. Ghi rõ lỗi nào có sẵn trước triển khai.
5. Xác nhận version production/canary hiện tại để có đường rollback.

Điều kiện hoàn thành: Có baseline và phạm vi diff rõ ràng trước lần sửa đầu tiên.

## 6. P1 - Entitlement và capability tập trung

### 6.1. Nguồn quyền chính thức

Tái sử dụng bảng `public.subscriptions` hiện có. Một user là Pro khi:

```text
status = 'active'
AND end_date > now()
AND plan_type thuộc nhóm Pro được hỗ trợ
```

Yêu cầu database:

- Kiểm tra duplicate trước khi thêm unique constraint.
- Thêm index `(user_id, status, end_date DESC)`.
- User chỉ được đọc subscription của chính mình.
- Authenticated client không được insert/update/cancel subscription.
- Chỉ service role, admin hoặc purchase webhook được ghi subscription.
- Thêm `updated_at` nếu schema thực tế xác nhận cần.
- Không sử dụng `user_metadata` làm quyền Pro.

Hàm Flutter cho phép tự tạo/gia hạn subscription phải được loại bỏ. Trong giai đoạn test, quyền Pro chỉ được cấp qua admin/service-role.

### 6.2. Capability policy

Tạo module dùng chung:

```text
supabase/functions/_shared/entitlements.ts
```

API tối thiểu:

```text
resolveEntitlements(userId)
hasCapability(userId, capability)
requireCapability(userId, capability)
```

Capability ban đầu:

```text
Free -> ai_scan_basic
Pro  -> ai_scan_basic + ai_scan_advanced
```

Mapping template ban đầu tái sử dụng capability hiện có, chưa tạo capability mới:

```text
Mặc định    -> Free + Pro
Tối giản    -> Free + Pro
Tự thiết kế -> Pro, yêu cầu ai_scan_advanced
```

Chỉ tách capability riêng như `custom_label_design` khi chính sách kinh doanh cần bán quyền template độc lập với AI Scan nâng cao.

Capability có thể bổ sung sau:

```text
unlimited_scan
advanced_statistics
premium_games
cloud_backup
priority_processing
```

Flutter có thể ẩn/hiện UI theo capability, nhưng mọi chức năng có giá trị vẫn phải kiểm tra lại phía server.

### 6.3. Xác thực

- Production Edge Function bắt buộc JWT.
- Server lấy `user_id` từ phiên đã xác thực.
- Không tin `user_id`, `is_pro`, `tier` hoặc `model` từ request body.
- Database entitlement lỗi thì trả `503` và không gọi Gemini.

Điều kiện hoàn thành: User Free không thể giả thành Pro bằng request hoặc APK đã chỉnh sửa.

## 7. P2 - Model router Free/Pro

Tạo policy riêng, ví dụ:

```text
supabase/functions/gemini-vision-scan/model_policy.ts
```

Policy:

```text
Free:
  primary  = gemini-3.5-flash-lite
  fallback = none

Pro:
  primary  = gemini-3.7-flash
  fallback = gemini-3.6-flash
```

Model name đọc từ Supabase Secrets/config:

```text
GEMINI_FREE_MODEL
GEMINI_PRO_MODEL
GEMINI_PRO_FALLBACK_MODEL
```

Quy tắc:

- Client không được chọn model.
- Free không fallback sang Pro.
- `429` không được dùng làm lý do fallback để né quota.
- Pro chỉ fallback khi 3.7 gặp lỗi hệ thống hoặc network phù hợp.
- `503/network` tối đa một retry có jitter.
- `400/401/403/422` không retry.
- Giữ chung prompt và response schema ban đầu.
- Không cố tình giới hạn Free để tạo khác biệt giả.
- Loại `gemini-3.5-flash` khỏi production chain đã chọn.
- Health-store hiện có tiếp tục theo dõi từng model.

Response bổ sung nhưng vẫn tương thích ngược:

```json
{
  "scan_id": "...",
  "service_tier": "free",
  "model_used": "gemini-3.5-flash-lite",
  "words": []
}
```

Điều kiện hoàn thành: Free luôn dùng Lite; active Pro luôn ưu tiên 3.7; không có fallback chéo tier.

## 8. P3 - Request ID, idempotency và scan ledger

### 8.1. Request contract

Flutter tạo một UUID cho mỗi thao tác scan. Retry của cùng thao tác phải giữ nguyên ID:

```json
{
  "request_id": "uuid",
  "image_base64": "..."
}
```

Flutter không gửi `tier` hoặc `model`.

### 8.2. Bảng `ai_scan_requests`

Các trường dự kiến:

```text
id
client_request_id
user_id
service_tier
status
model_used
attempt_count
prompt_tokens
output_tokens
thinking_tokens
total_tokens
word_count
latency_ms
error_code
result_json
created_at
completed_at
expires_at
```

Constraints/index:

- Unique `(user_id, client_request_id)`.
- Index `(user_id, created_at DESC)`.
- Index `(service_tier, created_at DESC)` nếu report sử dụng.
- Index foreign key `user_id`.
- RLS: user chỉ đọc request của mình; không tự ghi tier/model/token.
- Không lưu ảnh.

Luồng xử lý:

1. Insert/reserve request bằng transaction ngắn.
2. Nếu request đã thành công, trả `result_json` cũ.
3. Nếu request đang chạy, không gọi Gemini lần hai.
4. Gọi Gemini bên ngoài database transaction.
5. Cập nhật success/error/token bằng statement ngắn.
6. Giữ result khoảng 24 giờ để xử lý retry mất mạng.

Không giữ lock database trong khi chờ Gemini.

### 8.3. Cache hash ảnh tùy chọn

Chỉ bổ sung sau khi telemetry chứng minh người dùng thường scan lại cùng ảnh:

- Hash ảnh đã nén.
- Cache theo `(user_id, image_hash)`.
- TTL `5-10 phút`.
- Không cache dùng chung giữa user.
- Không lưu ảnh chỉ để cache.

Điều kiện hoàn thành: Gửi cùng request 10 lần vẫn chỉ có một Gemini call.

## 9. P4 - Flutter entitlement provider

Tạo provider tập trung:

```text
lib/core/entitlements/entitlement_provider.dart
```

API UI:

```dart
entitlements.can(AppCapability.aiScanAdvanced)
```

Provider chịu trách nhiệm:

- Hiện/ẩn chức năng Pro.
- Hiện paywall hoặc badge Pro.
- Refresh sau thanh toán.
- Restore quyền khi đăng nhập thiết bị khác.
- Cung cấp trạng thái Free mặc định khi không có subscription hợp lệ.

Flutter vẫn không có quyền tự nâng plan. Endpoint server phải kiểm tra capability lại.

Các test cần có:

- Request ID giữ nguyên khi retry.
- Response cũ không có tier/model vẫn parse được.
- Response mới parse được metadata.
- Các exception `401/429/503` hiện tại không bị phá.
- Scan provider/controller và widget/golden tests tiếp tục chạy.

### 9.1. P4.1 - Entitlement cho template

Trạng thái: Đã triển khai local vào Flutter; chưa commit/push/release.

Mock quyền tại một điểm duy nhất trong UI:

```dart
final canUseCustomTemplate =
    entitlements.can(AppCapability.aiScanAdvanced);
```

Quy tắc UI:

- `NoteLabelTemplate.standard` (`Mặc định`) luôn khả dụng cho Free và Pro.
- `NoteLabelTemplate.minimal` (`Tối giản`) luôn khả dụng cho Free và Pro.
- `NoteLabelTemplate.custom` (`Tự thiết kế`) chỉ mở editor, cho phép áp dụng và lưu mẫu khi `canUseCustomTemplate == true`.
- Free vẫn nhìn thấy `Tự thiết kế` ở trạng thái khóa để có thể mở paywall; không ẩn hoàn toàn quyền lợi nâng cấp.
- Khi Pro hết hạn, không xóa dữ liệu mẫu đã lưu. UI khóa editor và tạm fallback về `Mặc định`; khi Pro được khôi phục thì mẫu cũ dùng lại được.
- Sau thanh toán hoặc restore purchase, gọi refresh entitlement hiện có để mở khóa mà không cần khởi động lại app.
- Nếu sau này mẫu tự thiết kế được đồng bộ cloud, endpoint ghi/đọc giá trị Pro phải kiểm tra `ai_scan_advanced` phía server; không tin cờ từ Flutter.

Test bắt buộc cho P4.1:

- Free chọn được `Mặc định` và `Tối giản`.
- Free nhấn `Tự thiết kế` nhận paywall và không mở editor/không lưu mẫu.
- Pro mở editor, áp dụng và lưu mẫu tự thiết kế.
- Pro hết hạn fallback về `Mặc định` nhưng dữ liệu mẫu không bị xóa.
- Refresh entitlement sau nâng cấp mở lại editor và mẫu đã lưu.

Bằng chứng hoàn thành local ngày 2026-09-01:

- Bottom sheet đọc `ai_scan_advanced` từ `entitlementProvider`; trạng thái loading/error fail closed như Free.
- Mẫu custom đã lưu vẫn tồn tại local nhưng bị khóa áp dụng đối với Free.
- Flutter analyze không có lỗi và toàn bộ `215` tests đạt.

## 10. P5 - Retry, health và circuit breaker

Trạng thái: Đã triển khai database và canary Edge version `16`; production chưa promote.

Theo dõi riêng ba model pool:

- Flash-Lite Free.
- Flash 3.7 Pro.
- Flash 3.6 Pro fallback.

Trạng thái circuit:

```text
healthy -> degraded -> open -> half_open
```

Quy tắc:

- Free pool lỗi không ảnh hưởng Pro pool.
- Pro pool lỗi không tiêu quota Flash-Lite.
- `429 quota` không được xem là model hỏng.
- `RPD exhausted` không retry.
- `RPM exhausted` tôn trọng `Retry-After`.
- Circuit mở sau lỗi hệ thống liên tiếp theo cấu hình.
- Sau cooldown chỉ thử một request half-open.
- Log riêng quota metric, tier, model, attempt và latency.

Health check:

- Edge liveness không gọi Gemini.
- Synthetic Gemini health tối đa `2-4 lần/model/ngày`.
- Không dùng scan đầy đủ để health check liên tục.

Chưa thêm queue, Redis, VPS hoặc dependency mới. Chỉ bổ sung khi load test chứng minh cần.

Cấu hình circuit mặc định hiện tại:

```text
GEMINI_CIRCUIT_FAILURE_THRESHOLD = 3
GEMINI_CIRCUIT_COOLDOWN_SECONDS = 60
GEMINI_CIRCUIT_HALF_OPEN_LEASE_SECONDS = 45
```

Các giá trị này có thể thay bằng Supabase Secrets/config sau telemetry; không chứa quota Free Tier hard-code.

Trạng thái model pool tại lần đối chiếu 2026-08-31:

- `gemini-3.5-flash-lite`: `healthy`.
- `gemini-3.6-flash`: `healthy`.
- `gemini-3.7-flash`: `open` với `4` lỗi hệ thống đã có trước đó; quota error RPM/TPM/RPD đều bằng `0`.

## 11. Checkpoint do chủ dự án thực hiện - Gemini Tier 1

Chủ dự án thực hiện:

1. Nâng Gemini production project lên Tier 1.
2. Thiết lập billing/prepay.
3. Đặt budget alert và spend cap phù hợp.
4. Ghi lại quota thực tế của:
   - Gemini 3.5 Flash-Lite.
   - Gemini 3.7 Flash.
   - Gemini 3.6 Flash.
   - RPM.
   - TPM.
   - RPD.
5. Cung cấp quota thực tế trước khi cấu hình limiter và load test production.

Không hard-code quota Free Tier cũ vào mã nguồn production.

## 12. P6 - Verification và load test

Trạng thái: Đang thực hiện. Harness dùng Gemini stub, source tests và kiểm tra DB/RLS đã đạt; authenticated canary và load ladder chưa chạy. Bằng chứng chi tiết lưu tại `docs/baselines/p6-verification-20260901.md`.

### 12.1. Edge/Deno

- Anonymous request trả `401`.
- Free luôn route Lite.
- Active Pro chưa hết hạn route 3.7.
- Pro hết hạn/cancelled route Lite.
- Client gửi `model=3.7` nhưng Free vẫn dùng Lite.
- Free `429` không fallback sang Pro.
- Pro lỗi hệ thống fallback đúng sang 3.6.
- Duplicate request chỉ gọi Gemini một lần.
- Usage metadata được ghi đúng.
- Entitlement database lỗi không cấp Pro.
- Response schema cũ vẫn hợp lệ.

Tài khoản demo `capyvocabapp@gmail.com` hiện luôn resolve thành Pro. Vì vậy:

- Dùng tài khoản demo để test Pro thật.
- Dùng một tài khoản không có subscription để test Free thật.
- Không tạm hạ tài khoản demo về Free nếu mục tiêu là giữ nó mặc định Pro.

### 12.2. Database/RLS

- [x] Subscription RLS chỉ cho user đọc subscription của chính mình.
- [x] Authenticated user không có quyền insert/update subscription.
- [x] Scan ledger không cấp quyền client; service role có quyền đọc/ghi cần thiết.
- [x] Index entitlement, ledger và circuit health tồn tại và được remote sử dụng.
- [x] Remote schema lint không có error; database/security advisors đã chạy.
- [ ] Thực hiện thử nghiệm runtime User A/User B và service-role write trên môi trường test cô lập.
- [ ] Xác nhận đường rollback migration trên local stack.

### 12.3. Load profile

Chạy riêng:

1. `100% Free`.
2. `100% Pro`.
3. `99% Free / 1% Pro`.
4. `98% Free / 2% Pro`.

Các nấc:

```text
15 -> 50 -> 150 -> 500 RPM
```

Mục tiêu:

- Success `>= 99%`.
- `429 < 1%` khi quota còn đủ.
- `calls_per_scan <= 1.05`.
- Không duplicate call.
- Không fallback chéo tier.
- P95 không xấu hơn baseline được duyệt.
- Supabase CPU, RAM và connections ổn định.

Load test Supabase bằng Gemini stub trước; chỉ chạy end-to-end thật sau khi quota Tier 1 cho phép.

Harness đã tạo tại `supabase/functions/gemini-vision-scan/p6/` với chốt an toàn bắt buộc `P6_CONFIRM_GEMINI_STUB=YES`. Docker Desktop hiện chưa chạy nên bốn profile và các nấc RPM chưa được thực thi. Việc nâng Tier 1 không chặn stub load local; Tier 1 chỉ chặn load thật vào Gemini.

## 13. P7 - Canary và production rollout

Trạng thái: Canary P5 đã deploy; scan giao diện Free/Pro trên production đã được chủ dự án xác nhận, nhưng authenticated canary, soak test và production promotion chưa hoàn thành.

1. [x] Deploy canary với JWT enforcement. Hiện canary dùng xác thực JWT trong function trong khi platform `verify_jwt=false`; request thiếu JWT đã được xác nhận trả `401`.
2. [ ] Chỉ dùng tài khoản nội bộ trong giai đoạn canary. Chưa có allowlist riêng; app production chưa trỏ tới canary.
3. [ ] Test Free và Pro thật.
4. [ ] Soak test `3-7 ngày`.
5. [ ] Theo dõi:
   - Request và RPD theo model.
   - Calls-per-scan.
   - Token/scan.
   - Word count.
   - P50/P95/P99 latency.
   - Retry/fallback/error rate.
   - Supabase CPU/RAM/connections.
6. [ ] Cảnh báo quota/budget ở `50%`, `75%`, `90%`.
7. [ ] Chỉ promote production khi đạt tiêu chí.
8. [x] Giữ Edge Function production/baseline version trước để rollback.

## 14. P8 - Mở rộng kinh doanh trong tương lai

### 14.1. Thanh toán

```text
Store payment
-> webhook server xác minh
-> upsert subscriptions
-> entitlement thành Pro
-> Flutter refresh capabilities
```

Client không được tự xác nhận thanh toán hoặc tự ghi subscription.

### 14.2. Quảng cáo Free

```text
AdMob rewarded ad
-> Server-Side Verification
-> cộng scan credit
-> admission kiểm tra credit
-> Free được gọi Flash-Lite
```

Credit phải dùng ledger bất biến và idempotent theo external event ID. Không tin callback quảng cáo từ client.

### 14.3. Tier mới

Ví dụ:

```text
Free     -> Flash-Lite
Pro      -> Flash 3.7
Pro Plus -> model cao hơn hoặc priority throughput
```

Khi chỉ có `2-3` tier, capability mapping giữ trong code. Chỉ chuyển thành bảng policy động khi số tier và feature thực sự nhiều.

### 14.4. Nâng model

Khi Google thay model:

1. Đổi model config ở canary.
2. Chạy regression dataset hiện có.
3. So sánh chất lượng, token, latency và lỗi.
4. Soak test.
5. Promote config production.

Không cần thay đổi Flutter nếu response schema không đổi.

## 15. Thứ tự triển khai

```text
P0 -> P1 -> P2 -> P3 -> P4 -> P5  [đã hoàn thành]
                              |
                              v
          P6 stub load + authenticated canary
                              |
                              v
          Chủ dự án nâng Tier 1 + budget alert
                              |
                              v
               P6 real load -> P7 rollout
                              |
                              v
                         P8 về sau
```

## 16. Phạm vi khuyến nghị hiện tại

- `P0-P5` đã hoàn thành ở source/database, `P4.1` đã hoàn thành local và P5 đã deploy canary.
- Scan giao diện Pro/Free đã được chủ dự án xác nhận trên endpoint production; việc cần làm ngay là lặp lại hai scan trên canary và đối chiếu ledger/circuit/model_used.
- Có thể chạy P6 stub load local trước Tier 1 ngay khi Docker Desktop hoạt động.
- Sau functional canary và stub load, dừng tại checkpoint Tier 1 để lấy quota thật trước real Gemini load và P7 rollout.
- Để sau: `P8`.
- Production vẫn giữ bundle cũ cho tới khi canary đạt tiêu chí; không promote chỉ vì unit test đã pass.
- Không tạo hai Edge Function riêng cho Free và Pro.
- Không thêm queue, Redis, VPS, Kubernetes hoặc nhà cung cấp AI thứ hai trước khi có số liệu load test.
- Không thay đổi response schema hiện tại theo cách phá vỡ Flutter cũ.
- Mọi thay đổi phải có migration, test, canary và rollback tương ứng.

## 17. Các quyết định mặc định đang đề xuất

- Pro fallback: `gemini-3.6-flash`.
- Thời gian giữ result idempotency: `24 giờ`.
- Synthetic AI health: `2-4 lần/model/ngày`.
- Retry upstream: tối đa `1` cho lỗi tạm thời phù hợp.
- Calls-per-scan mục tiêu: `<= 1.05`.
- Free/Pro dùng chung prompt và schema ở lần triển khai đầu.
- Capability và model policy là hai nguồn cấu hình tập trung phía server.
- Tài khoản demo nội bộ giữ Pro bằng subscription server-side; mọi tài khoản thông thường vẫn tuân theo entitlement chuẩn.
- Template Free gồm `Mặc định` và `Tối giản`; `Tự thiết kế` dùng `ai_scan_advanced` và chỉ dành cho Pro.

Các quyết định này có thể được điều chỉnh sau telemetry nhưng không được thay đổi âm thầm trong lúc triển khai.

## 18. Vấn đề tồn đọng và cập nhật triển khai về sau

Mục này là backlog chính thức cho các lần triển khai tiếp theo. Không đánh dấu hoàn thành nếu chưa có bằng chứng runtime tương ứng.

### 18.1. Việc có thể thực hiện trước Tier 1

| Vấn đề | Trạng thái hiện tại | Cập nhật cần thực hiện | Điều kiện hoàn thành |
| --- | --- | --- | --- |
| Stub load chưa chạy | Docker Desktop/local Supabase chưa hoạt động | Chạy đủ bốn profile tại `15 -> 50 -> 150 -> 500 RPM`; dừng ở nấc lỗi đầu tiên | Lưu success, 429, P50/P95/P99, calls-per-scan, duplicate và tài nguyên DB cho từng nấc |
| Chưa có authenticated canary | Hai scan Free/Pro đã đi qua endpoint production mặc định; ledger remote vẫn có `0` row | Gọi canary bằng tài khoản demo Pro và một tài khoản Free riêng | Ledger ghi đúng `service_tier`, `model_used`, attempt, token và latency; không fallback chéo tier |
| RLS mới xác minh bằng catalog/grant | Chưa có runtime isolation test User A/User B | Chạy test đọc chéo subscription/ledger và service-role write trong môi trường test | Client không đọc/ghi trái phép; service role ghi đúng |
| Rollback migration chưa diễn tập local | Migration remote tồn tại nhưng local Docker chưa chạy | Chạy migration lên/xuống trên local stack có dữ liệu mẫu | Không mất dữ liệu ngoài phạm vi và có lệnh rollback được ghi lại |
| Canary chưa soak | Chưa có telemetry đủ dài | Soak bằng tài khoản nội bộ trong `3-7 ngày` | Không có duplicate/cross-tier; error, retry, latency và circuit ổn định |

### 18.2. Checkpoint Tier 1 do chủ dự án thực hiện

1. Nâng đúng Google Cloud/Gemini production project lên Tier 1.
2. Nạp billing/prepay và đặt budget alert tại `50%`, `75%`, `90%`.
3. Ghi quota thực tế RPM, TPM và RPD theo từng model Free/Pro/fallback.
4. Xác nhận key tạm dùng để test đã được thu hồi hoặc xoay sau khi kết thúc kiểm thử.
5. Không dùng thêm tài khoản/key để né quota; key chỉ được tách theo môi trường và lưu trong secret store.

### 18.3. Việc triển khai sau Tier 1

| Hạng mục | Cách triển khai | Điều kiện promote |
| --- | --- | --- |
| Rate limiter | Tính từ quota Tier 1 thực tế, tách pool Lite/3.7/3.6 và giữ headroom vận hành | Không hard-code giới hạn Free Tier cũ; 429 dưới ngưỡng P6 |
| Real Gemini load | Chạy tăng dần với ngân sách/request cap rõ ràng, không bắt đầu ở `500 RPM` | Đạt mục tiêu P6 và không vượt budget alert |
| Production rollout | Promote đúng bundle canary đã soak; giữ production version `35` làm mốc rollback cho đến lúc promote | Free/Pro, ledger, circuit, fallback và schema tương thích đều được xác minh |
| Theo dõi vận hành | Dashboard theo tier/model cho RPD, token, latency, retry, fallback và lỗi quota | Có cảnh báo và người chịu trách nhiệm xử lý sự cố |

### 18.4. Chỉ bổ sung khi telemetry chứng minh cần

- Image-hash cache theo user chỉ thêm khi tỷ lệ scan lặp ảnh đủ lớn để giảm RPD có ý nghĩa.
- Queue chỉ thêm khi load test chứng minh burst RPM là nút thắt; không dùng queue để che lỗi quota RPD.
- Redis/distributed circuit state chỉ thêm khi nhiều Edge instance làm state hiện tại thiếu nhất quán ở mức đo được.
- Nhà cung cấp AI thứ hai chỉ xem xét khi có yêu cầu kinh doanh về SLA/gián đoạn và đã tính chi phí duy trì hai schema/model.
- Tier/credit động trong database chỉ thêm khi số gói và luật kinh doanh vượt khả năng mapping capability hiện tại.
- Payment webhook, rewarded-ad verification và scan credit tiếp tục thuộc P8; không tin trạng thái thanh toán/quảng cáo từ client.

### 18.5. Hardening nền tảng cần lên lịch riêng

Các cảnh báo này đã tồn tại ngoài phạm vi P1-P6 và không được sửa kèm AI Scan nếu chưa có kế hoạch regression riêng:

- Rà soát các RPC public dùng `SECURITY DEFINER`: `check_phone_available`, `check_username_available`, `reset_my_onboarding`.
- Bật và kiểm tra leaked-password protection của Supabase Auth.
- Tối ưu các RLS init-plan và policy permissive trùng trên các bảng cũ được database advisors báo cáo.

Ưu tiên hardening trước production promotion nếu advisor đánh dấu lỗi bảo mật mức cao; cảnh báo hiệu năng có thể xử lý theo số liệu tải thực tế.
