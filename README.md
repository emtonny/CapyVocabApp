# Capy Vocab — Spa Từ Vựng Chill (Flutter)

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
│   ├── services/              # AudioService, TtsService, ConfettiService, LocalStorage, CloudVisionService, PaymentService, FirestoreService
│   └── utils/                 # Validators, Formatters (định dạng tên bạn mới...)
├── features/                 # Mỗi module M1–M9 trong FRD = 1 feature
│   ├── auth/                  # M1 — AuthRepositoryImpl nối Firebase Auth thật
│   ├── onboarding/            # M1 — FR-ONBD-xx, UC-ONBD-01 (wizard 5 bước)
│   ├── home/                  # M2 — UserFirestoreDataSource (Streak, XP, Profile)
│   ├── ai_scan/                # M3 — CloudVisionService (Label & Text OCR Detection)
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
2. **Google Cloud Vision API Service**: `CloudVisionService` hỗ trợ Label Detection & Text Detection (OCR) cho tính năng AI Scan.
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

