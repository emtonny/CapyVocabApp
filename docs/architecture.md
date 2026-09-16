# Deery Vocab — Architecture

Tài liệu này mô tả kiến trúc ổn định của repository. Trạng thái feature và
backlog thay đổi theo thời gian nằm trong [PROJECT_STATUS.md](../PROJECT_STATUS.md).

Đồng bộ ngày 2026-09-12 bổ sung offline Library/SQLite, onboarding cache và
consent-gated cloud sync. Các mục chi tiết bên dưới còn giữ baseline cũ;
contract Database/Storage hiện tại nằm trong [db_status.md](../db_status.md),
gateway Vilao trong [github-vilao-sync.md](github-vilao-sync.md).

## Tổng quan hệ thống

```text
Flutter application
  ├── Presentation: screen, widget, Riverpod state
  ├── Domain: entity và repository contract khi feature cần tách lớp
  ├── Data: model, repository implementation, datasource
  └── Core/Shared: routing, theme, service và UI dùng chung
          |
          v
Supabase
  ├── Auth và PKCE callback
  ├── PostgreSQL + RLS/RPC
  ├── Storage
  ├── Realtime
  └── Edge Function -> Vilao (OpenAI-compatible, mặc định)
```

Repository dùng kiến trúc feature-first. Không phải mọi feature scaffold đều đã
hoàn thiện đủ ba lớp; xem status thay vì suy ra mức hoàn thành chỉ từ sự tồn tại
của file hoặc datasource.

## Cấu trúc chính

```text
lib/
├── main.dart                 # Nạp config, khởi tạo/health-check Supabase
├── app.dart                  # MaterialApp.router
├── core/
│   ├── constants/            # Token và chuỗi dùng chung
│   ├── routes/               # GoRouter và auth guard
│   ├── services/             # Supabase, Gemini client, local services
│   ├── theme/                # ThemeData
│   └── utils/                # Validation/formatting
├── features/                 # Module nghiệp vụ
└── shared/                   # Navigation và widget dùng chung

supabase/
├── functions/                # Edge Functions và test TypeScript
├── migrations/               # Lịch sử thay đổi database chuẩn
├── schema/                   # Snapshot thiết kế và migration legacy
└── templates/                # Email confirmation/recovery
```

## Bootstrap

`lib/main.dart` thực hiện theo thứ tự:

1. Khởi tạo Flutter binding.
2. Nạp `assets/config/client.config`.
3. Khởi tạo Supabase client.
4. Kiểm tra khả năng truy cập backend.
5. Render ứng dụng hoặc màn retry khi health check thất bại.
6. Bọc ứng dụng bằng `ProviderScope`.

Config đóng gói cùng Flutter chỉ được chứa Supabase URL và public/publishable
key. Secret Gemini và service-role key không được xuất hiện trong client.

## Auth và routing

GoRouter lắng nghe Supabase auth state. Quy tắc guard chính:

1. Không có session: chỉ cho vào Auth/Reset Password phù hợp.
2. Recovery session: điều hướng đến `/reset-password`.
3. Session thường: đọc `public.users.onboarding_completed`.
4. Hồ sơ chưa hoàn tất: điều hướng đến `/onboarding`.
5. Hồ sơ hoàn tất: cho vào các route đã xác thực, mặc định `/home`.

Auth UI không tự ép route sau đăng nhập; router là owner của quyết định điều
hướng dựa trên trạng thái hồ sơ.

## Data ownership

- Supabase Auth quản lý identity/session.
- `public.users` và `public.user_settings` quản lý hồ sơ/onboarding.
- `complete_onboarding` cập nhật dữ liệu onboarding theo transaction phía
  database.
- Schema snapshot hiện có 15 bảng public; snapshot không thay thế migration.
- Mọi thay đổi schema mới phải tạo file mới trong `supabase/migrations/`.
- RLS và authorization phải được kiểm tra server-side; client validation chỉ là
  lớp UX.

## AI Scan boundary

```text
Camera/Gallery
  -> normalize và nén JPEG
  -> Flutter gửi ảnh + Supabase access token
  -> Supabase Edge Function
  -> Gemini model chain
  -> validate/normalize response
  -> local result store
  -> overlay renderer
```

Flutter không gọi Gemini trực tiếp. Edge Function sở hữu API key, request
schema, model failover và error mapping. Native lưu kết quả scan bằng SQLite;
Web hiện chỉ lưu trong bộ nhớ. Contract chi tiết nằm trong
[scan-feature.md](scan-feature.md).

## UI ownership

- Token thực thi nằm trong `lib/core/constants/` và `lib/core/theme/`.
- Đặc tả thiết kế nằm trong [design-system.md](design-system.md).
- Widget dùng chung chỉ đặt trong `shared/` hoặc `core/` khi có nhiều consumer
  thực tế; widget riêng của feature ở lại trong feature đó.

## Tài liệu và nguồn sự thật

| Nội dung | Owner |
| --- | --- |
| Cài đặt/chạy dự án | `README.md` |
| Quy tắc coding agent | `AGENTS.md` |
| Trạng thái/backlog | `PROJECT_STATUS.md` |
| Kiến trúc ổn định | `docs/architecture.md` |
| Design language | `docs/design-system.md` |
| AI Scan contract | `docs/scan-feature.md` |
| Lịch sử thay đổi | Git history |

Khi tài liệu mâu thuẫn với implementation, code, migration và test hiện tại có
ưu tiên cao hơn; sau đó phải cập nhật lại tài liệu owner tương ứng.
