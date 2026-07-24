# Capy Vocab — Spa Từ Vựng Chill (Flutter)

Cấu trúc dự án được sinh tự động từ tài liệu **FRD & Full Use Case
Specifications** (`capy_vocab_frd_usecases.md`). Đây là bộ khung
(scaffold) theo **Feature-based Clean Architecture**, chưa hiện thực
hoá logic nghiệp vụ — mỗi file đều có comment `// TODO` kèm mã
FR-xxx / UC-xxx tương ứng để đội dev bám theo khi triển khai.

## Kiến trúc tổng quan

```
lib/
├── main.dart                # Entry point, bọc ProviderScope (Riverpod)
├── app.dart                 # MaterialApp.router + theme + routes
├── core/                    # Thành phần dùng chung toàn app
│   ├── constants/           # Design tokens (màu, font Fredoka/Nunito, strings, assets)
│   ├── theme/                # Light/Dark ThemeData + themeModeProvider (FR-SETT-01)
│   ├── routes/               # AppRouter (go_router) — tương đương activateView(viewId)
│   ├── widgets/               # Cute3DButton, MascotBanner, ConfirmDialog, LoadingOverlay...
│   ├── services/              # AudioService (beep), TtsService, ConfettiService, LocalStorage
│   └── utils/                 # Validators, Formatters (định dạng tên bạn mới...)
├── features/                 # Mỗi module M1–M9 trong FRD = 1 feature
│   ├── auth/                  # M1 — FR-AUTH-xx, UC-AUTH-01
│   ├── onboarding/            # M1 — FR-ONBD-xx, UC-ONBD-01 (wizard 5 bước)
│   ├── home/                  # M2 — FR-HOME-xx, UC-HOME-01 (streak, lesson map, podium)
│   ├── ai_scan/                # M3 — FR-SCAN-xx / FR-STOR-xx, UC-SCAN-01 / UC-STOR-01
│   ├── mini_games/
│   │   ├── photo_order_quiz/  # M4 — FR-GAME1-xx
│   │   └── photo_letter_fill/ # M4 — FR-GAME2-xx
│   ├── solo_arena/             # M5 — FR-SOLO-xx (lobby, battle, result)
│   ├── pet_shop/                # M6 — FR-SHOP-xx
│   ├── friends/                  # M7 — FR-FRND-xx, UC-FRND-01 (leaderboard, thêm bạn)
│   ├── chatbot/                   # M8 — FR-CHAT-xx, UC-CHAT-01 (AI + P2P, draggable)
│   ├── notifications/              # FR-NOTIF-01 (trung tâm thông báo)
│   └── settings/                    # M9 — FR-SETT-xx, UC-SETT-01 (theme, PRO paywall, đăng xuất)
├── shared/
│   └── navigation/bottom_nav_bar.dart  # Bottom Bar 5 tab + FAB Cam giữa
```

Mỗi feature tuân theo 3 lớp:
- **domain/** — entity + repository abstraction (không phụ thuộc Flutter/SDK ngoài)
- **data/** — model (fromJson/toJson) + repository implementation (nơi gọi API/AI Vision thật)
- **presentation/** — provider (Riverpod `StateNotifier`), screen, widget

Không phải feature nào cũng cần đủ 3 lớp (vd: các feature chủ yếu là
UI tương tác cục bộ như `mini_games`, `solo_arena` chỉ có
`presentation/` — bổ sung `domain/data` khi kết nối API thật).

## Stack đề xuất (đã khai trong `pubspec.yaml`)
| Nhu cầu | Package |
| --- | --- |
| State management | `flutter_riverpod` |
| Điều hướng | `go_router` |
| Font Fredoka/Nunito | `google_fonts` |
| Lưu theme/local | `shared_preferences` |
| Âm thanh đúng/sai | `audioplayers` |
| Đọc phát âm từ vựng | `flutter_tts` |
| Hiệu ứng pháo hoa | `confetti` |

## Ghi chú quan trọng
- **FR-SCAN-02** (quét AI Vision **không giới hạn lượt**) — đã phản
  ánh trong `ScanNotifier`: không có field đếm quota, chỉ cần bám
  theo comment TODO khi hiện thực state.
- Toàn bộ `Global State Variables` ở Phần 4 của FRD (`currentAuthUser`,
  `studyPoints`, `unlockedItems`, `soloBetAmount`...) nên được tách
  thành các Riverpod provider tương ứng trong từng feature thay vì 1
  object toàn cục — đã bố trí sẵn `xxx_provider.dart` cho mục đích này.
- Các luồng Exception/Edge Case (Phần 5, mục 3) chưa được code — cần
  bổ sung validate + dialog cảnh báo khi hiện thực từng provider.

## Bước tiếp theo
1. `flutter pub get`
2. Hiện thực entity/model theo state ở Phần 4 của FRD.
3. Nối `AuthRepositoryImpl`, `ScanNotifier`... với API thật (nếu có) —
   hiện tại chỉ là giả lập (delay/progress) theo đúng Main Flow trong
   Use Case.
4. Build UI theo Design Tokens (`AppColors`, `AppTextStyles`) và
   micro-interactions mô tả ở Phần 5.
