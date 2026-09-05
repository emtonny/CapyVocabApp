# Capy Vocab — Spa Từ Vựng Chill (Flutter)

## Chạy ứng dụng

```powershell
# Android emulator đã được tạo trên máy phát triển
flutter emulators --launch Capy_Pixel_API_35
flutter devices
flutter run -d emulator-5554 --no-dds

# Web
flutter run -d chrome --web-port=3000
```

Nếu ID emulator không phải `emulator-5554`, dùng ID Android do
`flutter devices` trả về. Cờ `--no-dds` tránh lỗi Dart Development Service
trên môi trường Windows hiện tại và vẫn hỗ trợ quy trình debug/hot reload cơ
bản. Cấu hình public của Supabase được nạp từ
`assets/config/client.config`; không đưa khóa API bí mật vào Flutter assets.

Để email/OAuth quay lại ứng dụng mobile, thêm hai redirect URL sau vào
allowlist của Supabase Auth:

- `capyvocab://login-callback/`
- `capyvocab://reset-password/`

Với Supabase hosted, cấu hình **Authentication → URL Configuration** thêm cả
URL web chính xác (`https://<domain>` và `https://<domain>/reset-password`),
bật **Confirm email**, và đặt minimum password length là `6`. Production cần
cấu hình custom SMTP; SMTP mặc định của Supabase chỉ phù hợp thử nghiệm và có
giới hạn gửi thấp. Email xác nhận/khôi phục phải giữ `{{ .ConfirmationURL }}`
để Supabase hoàn tất PKCE rồi trả về đúng redirect. Luồng PKCE hiện yêu cầu
người dùng mở liên kết trên cùng thiết bị/trình duyệt đã yêu cầu email.

Trong **Authentication → Email Templates**, cấu hình hai mẫu hosted sau:

- **Confirm signup** — subject
  `Chào mừng bạn đến với Deery Vocab - Xác nhận email`; nội dung thông báo đăng
  ký thành công và nút xác nhận dùng `{{ .ConfirmationURL }}`.
- **Reset password / Recovery** — subject `Đặt lại mật khẩu Deery Vocab`; nút
  đặt lại mật khẩu cũng phải dùng `{{ .ConfirmationURL }}`.

Phản hồi “đã gửi email” chỉ xác nhận Supabase đã nhận yêu cầu gửi, không chứng
minh hộp thư tồn tại. Chỉ xem email là đã được sở hữu sau khi người dùng mở và
hoàn tất liên kết xác nhận; màn hình quên mật khẩu luôn dùng thông báo trung
tính để không làm lộ tài khoản nào đã đăng ký.

Mẫu HTML hoàn chỉnh nằm tại `supabase/templates/confirmation.html` (xác nhận
đăng ký) và `supabase/templates/recovery.html` (đặt lại mật khẩu). Hai mẫu dùng
linh vật emoji trong HTML nên không phụ thuộc ảnh hoặc `SiteURL` công khai. Tên
và avatar tròn bên cạnh người gửi trong Gmail không thuộc HTML; muốn thay
`Supabase Auth <noreply@mail.app.supabase.io>` cần cấu hình custom SMTP với
sender name `Deery Vocab` và tên miền gửi riêng.

Với project Free mới dùng email provider mặc định của Supabase, hosted template
có thể bị khóa chỉnh sửa. Khi đó cần bật custom SMTP trước rồi mới áp dụng mẫu
email thương hiệu này.

Cấu hình local tương ứng nằm trong `supabase/config.toml`. Kiểm thử thủ công
đầy đủ: đăng ký → mở email xác nhận → đăng nhập → quên mật khẩu → mở email
reset → đặt mật khẩu mới từ 6 ký tự → phiên recovery đăng xuất → đăng nhập bằng
mật khẩu mới; đồng thời xác nhận mật khẩu cũ không còn đăng nhập được.

Ứng dụng iOS chỉ có thể build/chạy bằng Xcode trên macOS; runner và URL scheme
iOS đã được cấu hình sẵn trong repository.

> **Current implementation status and AI handoff:** see
> [PROJECT_STATUS.md](PROJECT_STATUS.md). This is the source of truth for what
> is working, what remains scaffolded, and how future websites should connect.
>
> The architecture notes below are legacy scaffold documentation and may still
> contain outdated Firebase/Firestore references.

Cấu trúc dự án được sinh tự động từ tài liệu **FRD & Full Use Case
Specifications** (`capy_vocab_frd_usecases.md`). Đây là bộ khung
(scaffold) theo **Feature-based Clean Architecture**, chưa hiện thực
hoá logic nghiệp vụ — mỗi file đều có comment `// TODO` kèm mã
FR-xxx / UC-xxx tương ứng để đội dev bám theo khi triển khai.

## Kiến trúc tổng quan

```
lib/
├── main.dart                # Entry point, bọc ProviderScope & Firebase.initializeApp()
├── app.dart                 # MaterialApp.router + theme + routes
├── firebase_options.dart    # [NEW] Firebase platform options configuration
├── core/                    # Thành phần dùng chung toàn app
│   ├── constants/           # Design tokens (màu, font Fredoka/Nunito, strings, assets)
│   ├── theme/                # Light/Dark ThemeData + themeModeProvider (FR-SETT-01)
│   ├── routes/               # AppRouter (go_router) — tương đương activateView(viewId)
│   ├── widgets/               # Cute3DButton, MascotBanner, ConfirmDialog, LoadingOverlay...
│   ├── services/              # AudioService, TtsService, ConfettiService, LocalStorage, GeminiVisionService, PaymentService, FirestoreService
│   └── utils/                 # Validators, Formatters (định dạng tên bạn mới...)
├── features/                 # Mỗi module M1–M9 trong FRD = 1 feature
│   ├── auth/                  # M1 — AuthRepositoryImpl nối Firebase Auth thật
│   ├── onboarding/            # M1 — FR-ONBD-xx, UC-ONBD-01 (wizard 5 bước)
│   ├── home/                  # M2 — UserFirestoreDataSource (Streak, XP, Profile)
│   ├── ai_scan/                # M3 — GeminiVisionService (Gemini 1.5 Flash Vision nhận diện từ vựng + tọa độ)
│   ├── mini_games/
│   │   ├── photo_order_quiz/  # M4 — FR-GAME1-xx
│   │   └── photo_letter_fill/ # M4 — FR-GAME2-xx
│   ├── solo_arena/             # M5 — SoloArenaFirestoreDataSource (Match 1v1 Real-time)
│   ├── pet_shop/                # M6 — PetShopFirestoreDataSource (Shop & Capybara Inventory)
│   ├── friends/                  # M7 — FriendsFirestoreDataSource (Friends & Leaderboard)
│   ├── chatbot/                   # M8 — FR-CHAT-xx, UC-CHAT-01 (AI + P2P, draggable)
│   ├── notifications/              # FR-NOTIF-01 (trung tâm thông báo)
│   └── settings/                    # M9 — PaymentService (Pro Paywall, IAP/MoMo/ZaloPay)
├── shared/
│   └── navigation/bottom_nav_bar.dart  # Bottom Bar 5 tab + FAB Cam giữa
```

Mỗi feature tuân theo 3 lớp:
- **domain/** — entity + repository abstraction (không phụ thuộc Flutter/SDK ngoài)
- **data/** — model (fromJson/toJson) + repository implementation + firestore data sources
- **presentation/** — provider (Riverpod `StateNotifier`), screen, widget

## Stack đề xuất (đã khai trong `pubspec.yaml`)
| Nhu cầu | Package |
| --- | --- |
| State management | `flutter_riverpod` |
| Điều hướng | `go_router` |
| Firebase Platform | `firebase_core` |
| Xác thực người dùng | `firebase_auth` |
| Cơ sở dữ liệu Realtime | `cloud_firestore` |
| HTTP Networking (AI Vision) | `http` |
| Font Fredoka/Nunito | `google_fonts` |
| Lưu theme/local | `shared_preferences` |
| Âm thanh đúng/sai | `audioplayers` |
| Đọc phát âm từ vựng | `flutter_tts` |
| Hiệu ứng pháo hoa | `confetti` |

## Các thành phần hạ tầng mới được bổ sung
1. **Firebase Integration**: `firebase_options.dart`, `Firebase.initializeApp()` trong `main.dart`, `AuthRepositoryImpl` tích hợp `FirebaseAuth.instance`.
2. **Gemini 1.5 Flash Vision Service**: `GeminiVisionService` gửi ảnh JPEG nén (< 300 KB) lên Gemini 1.5 Flash API, nhận về JSON chứa danh sách từ vựng + tọa độ tương đối (x, y, w, h) để render Canvas.
3. **Payment Service Gateway**: `PaymentService` xử lý mua gói Pro & nạp Capy Coins trong Pet Shop qua IAP, MoMo, ZaloPay.
4. **Firestore Data Sources**: `FirestoreService` (CRUD/Stream wrapper), `UserFirestoreDataSource`, `PetShopFirestoreDataSource`, `FriendsFirestoreDataSource`, `SoloArenaFirestoreDataSource`.

## Ghi chú quan trọng
- **FR-SCAN-02** (quét AI Vision **không giới hạn lượt**) — đã phản ánh trong `ScanNotifier`: không có field đếm quota, chỉ cần bám theo comment TODO khi hiện thực state.
- Toàn bộ `Global State Variables` ở Phần 4 của FRD (`currentAuthUser`, `studyPoints`, `unlockedItems`, `soloBetAmount`...) nên được tách thành các Riverpod provider tương ứng trong từng feature thay vì 1 object toàn cục.
- Các luồng Exception/Edge Case (Phần 5, mục 3) cần bổ sung validate + dialog cảnh báo khi hiện thực từng provider.

## Bước tiếp theo
1. `flutter pub get`
2. Kết nối Riverpod Providers ở tầng `presentation/` với các Data sources / Services vừa bổ sung.
3. Build UI theo Design Tokens (`AppColors`, `AppTextStyles`) và micro-interactions mô tả ở Phần 5.
