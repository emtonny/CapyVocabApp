# Deery Vocab

Ứng dụng học từ vựng đa nền tảng viết bằng Flutter. Tên package/repository hiện
vẫn là `capy_vocab`/`CapyVocabApp`; tên hiển thị trong ứng dụng là **Deery
Vocab**.

## Tài liệu

- [Trạng thái dự án](PROJECT_STATUS.md)
- [Kiến trúc hệ thống](docs/architecture.md)
- [Design system](docs/design-system.md)
- [AI Scan handoff](docs/scan-feature.md)
- [Đồng bộ GitHub và Vilao ngày 12/09/2026](docs/github-vilao-sync.md)
- [Database, Library và cloud sync](db_status.md)
- [Quy tắc cho coding agent](AGENTS.md)

Code và test hiện tại là nguồn sự thật cuối cùng khi tài liệu chưa kịp cập nhật.

## Yêu cầu

- Flutter SDK tương thích với `pubspec.yaml`.
- Android Studio/Android SDK để chạy Android.
- Chrome để chạy Flutter Web.
- Xcode trên macOS để build hoặc chạy iOS.
- Supabase CLI qua dependency npm của dự án khi làm việc với backend local.

## Cài đặt

```powershell
flutter pub get
```

Chỉ cần cài npm dependency khi sử dụng Supabase CLI trong repository:

```powershell
npm install
```

Flutter nạp cấu hình Supabase public từ `assets/config/client.config`. Chỉ đặt
`SUPABASE_URL` và public/publishable key trong file này. Không đưa Gemini API
key, service-role key hoặc secret khác vào Flutter assets.

## Chạy ứng dụng

```powershell
# Android emulator đã được tạo trên máy phát triển
flutter emulators --launch Capy_Pixel_API_35
flutter devices
flutter run -d emulator-5554 --no-dds

# Web mặc định/Production
flutter run -d chrome --web-port=3000

# Web Staging có Chat test; tự lấy public key vào file tạm và cleanup khi dừng
powershell -ExecutionPolicy Bypass -File tool/run_staging_device_smoke.ps1 `
  -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' `
  -Target web-device -WebPort 3000 -ChatRelayEnabled
```

Nếu ID emulator khác `emulator-5554`, dùng ID do `flutter devices` trả về. Cờ
`--no-dds` là workaround cho Dart Development Service trên môi trường Windows
hiện tại; có thể bỏ cờ này nếu DDS hoạt động bình thường trên máy khác.

Không dùng lệnh Web mặc định để thử tài khoản Staging: khi thiếu `dart-define`,
ứng dụng cố ý fallback về project trong `assets/config/client.config` (Production).

Nếu ID emulator không phải `emulator-5554`, dùng ID Android do
`flutter devices` trả về. Cờ `--no-dds` tránh lỗi Dart Development Service
trên môi trường Windows hiện tại và vẫn hỗ trợ quy trình debug/hot reload cơ
bản. Cấu hình public của Supabase được nạp từ
`assets/config/client.config`; không đưa khóa API bí mật vào Flutter assets.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

Các test TypeScript của Supabase Edge Function cần Deno:

```powershell
deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan
```

AI Scan mặc định gọi Vilao qua Edge Function. Server tiếp tục dùng
`GEMINI_API_KEY` cho Vilao consumer key, `GEMINI_BASE_URL` (mặc định
`https://api.vilao.ai/v1`) và `GEMINI_MODEL` (mặc định `gemini-3.8-flash`).
Các biến này chỉ thuộc server; xem [báo cáo đồng bộ](docs/github-vilao-sync.md)
để biết thứ tự ưu tiên cấu hình và trạng thái deploy.

## Cấu hình Supabase Auth

Thêm các redirect URL mobile sau vào allowlist:

- `capyvocab://login-callback/`
- `capyvocab://reset-password/`

Với Web, thêm chính xác origin triển khai và trang reset tương ứng, ví dụ:

- `https://<domain>`
- `https://<domain>/reset-password`

Bật **Confirm email** và đặt minimum password length là `6`. Email xác nhận và
khôi phục phải giữ `{{ .ConfirmationURL }}` để Supabase hoàn tất PKCE rồi quay
lại đúng callback. Luồng PKCE yêu cầu người dùng mở liên kết trên cùng thiết
bị/trình duyệt đã gửi yêu cầu.

Mẫu email nguồn:

- `supabase/templates/confirmation.html`
- `supabase/templates/recovery.html`

Production nên dùng custom SMTP với sender name `Deery Vocab`; SMTP mặc định
của Supabase chỉ phù hợp thử nghiệm. Thông báo quên mật khẩu phải giữ nội dung
trung tính để không tiết lộ email nào đã đăng ký.

Checklist thủ công cho Auth:

1. Đăng ký và mở email xác nhận.
2. Đăng nhập và hoàn thành onboarding.
3. Gửi email quên mật khẩu.
4. Mở callback và đặt mật khẩu mới.
5. Xác nhận phiên recovery đã đăng xuất.
6. Đăng nhập bằng mật khẩu mới và xác nhận mật khẩu cũ không còn dùng được.

## Backend

Mọi thay đổi database mới phải nằm trong `supabase/migrations/`. File
`supabase/schema/supabase_schema_final_secure.sql` là snapshot thiết kế, không
thay thế migration. Gemini API key chỉ được cấu hình ở Supabase Edge Function.
