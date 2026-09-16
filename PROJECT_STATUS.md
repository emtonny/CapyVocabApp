# Deery Vocab — Project Status

> Last verified: 2026-09-12 (local checks; remote migration history read-only)
> Phạm vi: trạng thái implementation hiện tại, khoảng trống và công việc tiếp
> theo. Code và test là nguồn sự thật khi có khác biệt.

Đã fast-forward `AI-scan` lên `b742ea4` và ghép lại Vilao làm gateway mặc định.
Giữ cấu trúc tài liệu local; lịch sử Database/Library từ GitHub nằm trong
[db_status.md](db_status.md). Chi tiết kiểm chứng và phần chưa deploy nằm trong
[docs/github-vilao-sync.md](docs/github-vilao-sync.md).

## Tổng quan

- Loại dự án: Flutter client cho Android, iOS và Web.
- Backend: Supabase Auth, PostgreSQL, Storage, Realtime và Edge Functions.
- Kiến trúc: feature-first, Riverpod và GoRouter.
- Mốc hiện tại: hoàn thiện vòng học từ vựng đầu tiên.
- Release-ready: chưa.

Luồng chạy được hiện tại:

```text
startup config + local onboarding cache
  -> email/password auth hoặc password recovery
  -> route guard đọc cache owner-scoped; refresh profile chạy nền
  -> onboarding 5 bước khi hồ sơ chưa hoàn tất
  -> home shell và bottom navigation
  -> chụp/chọn ảnh, AI Scan qua Vilao và render nhãn từ vựng
  -> SQLite Library, detail, Trash và consent-gated cloud sync
```

## Trạng thái chức năng

| Khu vực | Trạng thái | Hiện có | Còn thiếu chính |
| --- | --- | --- | --- |
| Bootstrap | Đã test local | Nạp config, cache onboarding; không chặn startup bởi health check mạng | Kiểm thử bản ghép trên thiết bị thật |
| Auth email/password | Hoạt động | Đăng ký, xác nhận email, đăng nhập, ghi nhớ email, đăng xuất | Acceptance test production đầy đủ |
| Password recovery | Hoạt động | Gửi email, callback/deep link, đặt mật khẩu mới, kết thúc recovery session | Kiểm thử thủ công trên từng domain/thiết bị production |
| Route guard | Đã test local | Session và onboarding cache owner-scoped, refresh nền | Khôi phục intended route sau đăng nhập |
| Onboarding | Hoạt động | Wizard 5 bước, validation, kiểm tra username/phone, RPC lưu nguyên tử | Reminder scheduling thực tế |
| Home | Một phần | Shell, header, navigation, giao diện mẫu | Lesson map và tiến trình học còn dùng dữ liệu/scaffold chưa hoàn chỉnh |
| AI Scan | Đã test local, chờ deploy bản ghép | Vilao mặc định, auth/entitlement, circuit breaker, ledger, overlay và persistence native | Live scan bản ghép, TTS, Web scan durability |
| Storage album | Đã test local | SQLite Library, detail, Trash, media recovery và explicit cloud restore | Web scan durability; kiểm thử thiết bị bản ghép |
| Settings | Một phần | Profile, đăng xuất, Cloud Backup consent/backfill; đã sửa Material regression | Theme và thanh toán hoàn chỉnh |
| Friends/Pet shop | Scaffold UI | Route, coming-soon UI và một số datasource | Provider, business flow và persistence end-to-end |
| Solo Arena/Mini-games | Scaffold | Route/file nền | Gameplay, state, scoring và persistence |
| Chat/Notifications | Scaffold | Datasource hoặc file nền | UI, provider và flow end-to-end |
| Payment | Chưa tích hợp | Một số abstraction/shell | SDK thực, backend verification và webhook |

Chi tiết implementation của AI Scan nằm trong
[docs/scan-feature.md](docs/scan-feature.md).

## Route hiện tại

| Route | Vai trò |
| --- | --- |
| `/auth` | Đăng ký/đăng nhập và yêu cầu password recovery |
| `/reset-password` | Đặt mật khẩu mới trong recovery session |
| `/onboarding` | Hồ sơ 5 bước bắt buộc |
| `/home` | Home shell |
| `/storage` | Library album, detail và Trash từ SQLite |
| `/scan` | AI Scan bottom sheet |
| `/scan-overlay` | Màn kết quả riêng, không phải flow mặc định |
| `/solo-arena` | Solo Arena scaffold |
| `/pet-shop` | Pet Shop coming soon |
| `/friends` | Friends coming soon |
| `/settings` | Cài đặt và đăng xuất |

## Backend và dữ liệu

- Flutter chỉ chứa Supabase URL và public/publishable key.
- 21 migration local khớp database mà client đang trỏ tới qua kiểm tra read-only;
  đây là đối chiếu history, không thay thế kiểm chứng toàn bộ schema/RLS runtime.
- Thay đổi database mới phải được ghi bằng migration trong
  `supabase/migrations/`.
- `GEMINI_API_KEY` và service-role key chỉ thuộc môi trường Edge Function.
- AI Scan gọi `supabase/functions/gemini-vision-scan` thay vì gọi Gemini trực
  tiếp từ Flutter.
- Kết quả scan dùng SQLite trên native và bộ nhớ tạm trên Web.

## Ưu tiên tiếp theo

### P0 — Trước khi release

1. Chạy acceptance test production cho đăng ký, xác nhận email, đăng nhập và
   password recovery trên Android, iOS và Web.
2. Audit RLS, Storage policy, trigger, grant và cấu hình JWT của Edge Function.
3. Hoàn thiện lesson map, một hoạt động từ vựng và lưu tiến trình để tạo vòng
   học đầu tiên có giá trị sử dụng thực.

### P1 — Sau vòng học đầu tiên

1. Kiểm thử album/lifecycle trên thiết bị với bản ghép mới; hoàn thiện Web durability.
2. Chốt một UX kết quả Scan duy nhất: inline hoặc route `/scan-overlay`.
3. Nối TTS/accessibility cho label và kiểm thử camera trên thiết bị thật.
4. Hoàn thiện Settings/theme rồi mới mở rộng sang social, shop và game.
5. Chuẩn hóa tên sản phẩm còn sót giữa `Capy`, `Deer` và `Deery` trong code.

## Verification snapshot

Đã chạy tại repository hiện tại ngày 2026-09-12:

```text
flutter analyze
  -> No issues found

flutter test
  -> 390 passed, 1 opt-in live Staging test skipped

deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan
  -> 82 passed (gồm mock integration qua handler thực)

flutter build web --no-pub
flutter build apk --debug --no-pub
  -> cả hai build thành công; xem báo cáo để biết warnings
```

Chưa được xác minh trong đợt này:

- Deploy Edge Function mới và live Vilao scan.
- Build iOS (máy Windows).
- Auth, email, camera và AI Scan trên môi trường production/thiết bị thật.

## Điểm vào quan trọng

- Bootstrap: `lib/main.dart`
- App root: `lib/app.dart`
- Routing/Auth guard: `lib/core/routes/app_router.dart`
- Supabase wrapper: `lib/core/services/supabase_service.dart`
- Auth: `lib/features/auth/`
- Onboarding: `lib/features/onboarding/`
- AI Scan orchestration: `lib/features/ai_scan/`
- Overlay geometry: `lib/features/vocab_scan/`
- Database: `supabase/migrations/` và `supabase/schema/`

Kiến trúc ổn định và quy tắc ownership được mô tả trong
[docs/architecture.md](docs/architecture.md).
