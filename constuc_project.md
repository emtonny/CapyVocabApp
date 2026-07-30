# 🦫 CapyVocabApp — Master Blueprint cho AI Web (ChatGPT / Claude / Gemini)

> **MỤC ĐÍCH:** File này là **nguồn sự thật duy nhất (Single Source of Truth)** về toàn bộ dự án CapyVocabApp.  
> Đính kèm hoặc dán file này vào bất kỳ AI Web nào (ChatGPT, Claude, Gemini) để AI hiểu đầy đủ dự án và có thể phối hợp phát triển đúng chuẩn.

---

## 📑 MỤC LỤC

1. [🎯 Tổng Quan Dự Án](#1-tổng-quan-dự-án)
2. [🏛️ Kiến Trúc Hệ Thống](#2-kiến-trúc-hệ-thống)
3. [🛠️ Tech Stack & Dependencies](#3-tech-stack--dependencies)
4. [🗄️ Supabase Database Schema (15 Bảng Thực Tế)](#4-supabase-database-schema-15-bảng-thực-tế)
5. [🗂️ Cấu Trúc Thư Mục Chi Tiết](#5-cấu-trúc-thư-mục-chi-tiết)
6. [🎨 Design System & Capy Aesthetic](#6-design-system--capy-aesthetic)
7. [📱 Mobile Design Rules (Từ Skill mobile-design)](#7-mobile-design-rules-từ-skill-mobile-design)
8. [💙 Flutter Expert Rules (Từ Skill flutter-expert)](#8-flutter-expert-rules-từ-skill-flutter-expert)
9. [🎨 UI/UX Pro Max Rules (Từ Skill ui-ux-pro-max)](#9-uiux-pro-max-rules-từ-skill-ui-ux-pro-max)
10. [🔌 Supabase Integration Pattern](#10-supabase-integration-pattern)
11. [✅ Checklist Trước Khi Giao Code](#11-checklist-trước-khi-giao-code)
12. [⛔ Anti-Patterns Cấm Tuyệt Đối](#12-anti-patterns-cấm-tuyệt-đối)

---

## 1. 🎯 TỔNG QUAN DỰ ÁN

| Thông Tin | Chi Tiết |
|-----------|---------|
| **Tên App** | Capy Vocab — Spa Từ Vựng Chill |
| **Platform** | Flutter (iOS + Android, cross-platform) |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| **Kiến trúc** | Feature-first + Clean Architecture |
| **State** | Riverpod 2.x (StateNotifier pattern) |
| **Routing** | GoRouter (named routes) |
| **Ngôn ngữ** | Dart 3.x (Null Safety) |
| **Min SDK** | Flutter `>=3.3.0 <4.0.0` |
| **Mascot** | Chú chuột Capybara đáng yêu |

### 🎮 11 Tính Năng Chính (Feature Modules)

| Module | Feature | Mô Tả |
|--------|---------|--------|
| M1 | `auth` | Đăng nhập/Đăng ký qua Supabase Auth, Google Social Login |
| M1 | `onboarding` | Wizard 5 bước nhập thông tin mới dùng |
| M2 | `home` | Bản đồ bài học Lesson Map (Winding Path), Streak Flame, Leaderboard |
| M3 | `ai_scan` | Quét ảnh bằng **Gemini 1.5 Flash** (nhận diện từ vựng + tọa độ), lưu Photo Note Album |
| M4 | `mini_games` | 2 mini game: Photo Letter Fill & Photo Order Quiz |
| M5 | `solo_arena` | Đấu trường PvP 1v1 Realtime đặt cược điểm XP |
| M6 | `pet_shop` | Cửa hàng trang phục, đồ ăn & nuôi chú chuột Capybara |
| M7 | `friends` | Kết bạn, tìm bạn, bảng xếp hạng bạn bè |
| M8 | `chatbot` | Chatbot AI Capybara luyện tiếng Anh, draggable toggle |
| M9 | `settings` | Cài đặt tài khoản, Dark/Light Mode, Gói PRO Subscription |
| - | `notifications` | Trung tâm thông báo hệ thống & nhắc nhở học tập |

---

## 2. 🏛️ KIẾN TRÚC HỆ THỐNG

```
┌──────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                     │
│    Screens / Widgets / Riverpod Providers                │
│    → Chỉ chứa UI logic & state binding                   │
│    → KHÔNG viết SQL hay HTTP call trực tiếp              │
├──────────────────────────────────────────────────────────┤
│                    DOMAIN LAYER                          │
│    Entities (thuần Dart) / Repository Interfaces         │
│    → Không phụ thuộc package bên thứ ba                  │
│    → Business rules sống ở đây                           │
├──────────────────────────────────────────────────────────┤
│                     DATA LAYER                           │
│    Models (fromJson/toJson) / Datasources / Repo Impl    │
│    → Gọi SupabaseService.from('table')                   │
│    → Xử lý serialization & error mapping                 │
├──────────────────────────────────────────────────────────┤
│                     CORE LAYER                           │
│    Services / Theme / Utils / Constants / Widgets        │
│    → SupabaseService, AudioService, StorageService, TTS  │
│    → AppColors, AppTextStyles, AppRouter, Cute3DButton   │
└──────────────────────────────────────────────────────────┘
                          │
                   ┌──────┴──────┐
                   │  Supabase   │
                   │  Backend    │
                   │ PostgreSQL  │
                   │  + Auth     │
                   │  + Storage  │
                   │  + Realtime │
                   └─────────────┘
```

### 📁 Quy Tắc Phân Tầng Mỗi Feature

```
features/[feature_name]/
├── data/
│   ├── models/          # XxxModel.fromJson / .toJson
│   ├── datasources/     # XxxSupabaseDatasource — gọi Supabase trực tiếp
│   └── repositories/    # XxxRepositoryImpl — implement interface
├── domain/
│   ├── entities/        # XxxEntity — Dart thuần, không phụ thuộc SDK
│   └── repositories/    # XxxRepository — abstract interface
└── presentation/
    ├── providers/        # XxxProvider / XxxNotifier (Riverpod)
    ├── screens/          # XxxScreen (full page widget)
    └── widgets/          # XxxWidget (component nhỏ tái sử dụng)
```

---

## 3. 🛠️ TECH STACK & DEPENDENCIES

```yaml
# pubspec.yaml — Các package đang dùng trong dự án
dependencies:
  supabase_flutter: ^2.8.0    # Backend SDK (Auth, DB, Storage, Realtime)
  flutter_dotenv: ^5.2.0      # Nạp .env (SUPABASE_URL, SUPABASE_ANON_KEY)
  flutter_riverpod: ^2.5.1    # State management chính
  go_router: ^14.2.0          # Navigation & deep linking
  google_fonts: ^6.2.1        # Fredoka + Nunito fonts
  audioplayers: ^6.0.0        # Âm thanh đúng/sai, nhạc nền
  flutter_tts: ^4.0.2         # Phát âm từ vựng tiếng Anh
  confetti: ^0.7.0            # Pháo hoa khi hoàn thành bài
  shared_preferences: ^2.2.3  # Lưu theme/session cục bộ
  http: ^1.2.1                # REST API Gemini 1.5 Flash (AI Vision Scan)
  flutter_image_compress: ^2.3.0  # Nén ảnh JPEG trước khi gửi Gemini
  sqflite: ^2.3.3             # SQLite cục bộ — cache kết quả AI Scan
```

### 📄 Cấu Hình Môi Trường

File `.env` ở thư mục gốc (bắt buộc để app chạy được):
```env
SUPABASE_URL=https://vmxonxqxrlkssdzsucrg.supabase.co
SUPABASE_ANON_KEY=sb_publishable_72nUsedb3E0c2Yi07zDaQA_L2iGT3TH
```

File `.env` được khai báo trong `pubspec.yaml → flutter → assets: [.env]`  
Được nạp trong `main.dart` qua `await dotenv.load(fileName: '.env');`

---

## 4. 🗄️ SUPABASE DATABASE SCHEMA (15 BẢNG THỰC TẾ)

> **Tất cả 15 bảng đã được tạo thành công trên Supabase Production DB**  
> Kết nối đã xác nhận `✅ Supabase connected` từ `SupabaseService.testConnection()`

| # | Tên Bảng | Primary Key | Quan Hệ Chính | Vai Trò |
|---|----------|-------------|----------------|---------|
| 1 | `public.users` | `id UUID` ref `auth.users(id)` | - | Hồ sơ user: XP, streak, coins, level |
| 2 | `public.user_settings` | `user_id UUID` | users(1-1) | Cài đặt: theme, daily target, reminder |
| 3 | `public.lessons` | `id TEXT` | - | Bản đồ bài học (order_index, min_points) |
| 4 | `public.vocabularies` | `id TEXT` | lessons | Thư viện từ: word, phonetic, meaning, audio |
| 5 | `public.user_vocab_progress` | `(user_id, vocab_id)` | users + vocabs | SRS: mastery_level, next_review_at |
| 6 | `public.photo_notes` | `id UUID` | users | Album AI Scan: image_path, template, title |
| 7 | `public.photo_note_vocabularies` | `(note_id, vocab_id)` | photo_notes + vocabs | N-N linking table |
| 8 | `public.solo_arena_matches` | `id UUID` | users(host+guest) | PvP 1v1: bet, score, status, winner |
| 9 | `public.pet_items` | `id TEXT` | - | Catalogue Shop: price, rarity, category |
| 10 | `public.user_pet_inventory` | `(user_id, item_id)` | users + pet_items | Tủ đồ: is_equipped |
| 11 | `public.friends` | `(user_id, friend_id)` | users | Quan hệ bạn bè: status (pending/accepted) |
| 12 | `public.chat_messages` | `id UUID` | users | Chatbot history: message, is_ai_response |
| 13 | `public.shop_purchases` | `id UUID` | users + pet_items | Lịch sử mua: payment_method, transaction_id |
| 14 | `public.subscriptions` | `id UUID` | users | Gói PRO: plan_type, status, end_date |
| 15 | `public.notifications` | `id UUID` | users | Thông báo: title, body, type, is_read |

### 🔍 Indexes Tối Ưu Hiệu Suất

```sql
-- Leaderboard sort by XP & streak
CREATE INDEX idx_users_leaderboard ON public.users (study_points DESC, streak_days DESC);
-- SRS: lấy từ đến hạn ôn tập
CREATE INDEX idx_vocab_srs_due ON public.user_vocab_progress (user_id, next_review_at ASC);
-- Photo notes theo thời gian tạo
CREATE INDEX idx_photo_notes_user ON public.photo_notes (user_id, created_at DESC);
-- Chat history chronological
CREATE INDEX idx_chat_messages_user ON public.chat_messages (user_id, timestamp ASC);
```

---

## 5. 🗂️ CẤU TRÚC THƯ MỤC CHI TIẾT

```text
c:\CapyVocabApp\capy_vocab\            ← ROOT PROJECT
│
├── .env                               # ⚠️ SUPABASE_URL + SUPABASE_ANON_KEY (KHÔNG commit git)
├── .env.example                       # Template môi trường cho đồng đội
├── pubspec.yaml                       # Package config + assets khai báo .env
├── pubspec.lock                       # Lock file (commit nhưng không tự sửa)
├── supabase/                          # Quản lý Database & Migrations Supabase
│   ├── migrations/                    # File SQL migrations theo thời gian
│   ├── schema/                        # File snapshot schema tổng thể (supabase_schema_final_secure.sql)
│   └── DATABASE_README.txt            # Tài liệu hướng dẫn sử dụng cơ sở dữ liệu
├── analysis_options.yaml              # Dart lint config
├── README.md                          # Tóm tắt dự án
│
└── lib/
    ├── main.dart                      # Entry Point: dotenv.load() → SupabaseService.initialize()
    ├── app.dart                       # Root Widget: MaterialApp.router + ProviderScope
    │
    ├── core/                          # ══ TẦNG LÕI ══
    │   │
    │   ├── constants/
    │   │   ├── app_assets.dart        # Đường dẫn assets (ảnh mascot, icon, âm thanh)
    │   │   ├── app_colors.dart        # Color Tokens: primary, secondary, accent, bg, text
    │   │   ├── app_strings.dart       # Chuỗi văn bản tĩnh / i18n chuẩn bị
    │   │   └── app_text_styles.dart   # TextStyle dùng chung (Fredoka, Nunito)
    │   │
    │   ├── routes/
    │   │   └── app_router.dart        # GoRouter: tất cả named routes + deep linking
    │   │
    │   ├── services/
    │   │   ├── supabase_service.dart  # ★ Client wrapper: initialize(), testConnection()
    │   │   ├── audio_service.dart     # Phát âm đúng/sai, nhạc nền, hiệu ứng
    │   │   ├── gemini_vision_service.dart # ★ Gemini 1.5 Flash API (AI Scan — nén ảnh, timeout, error 429)
    │   │   ├── confetti_service.dart  # Điều khiển hiệu ứng pháo hoa
    │   │   ├── local_storage_service.dart # SharedPreferences wrapper
    │   │   ├── payment_service.dart   # Xử lý IAP / MoMo / ZaloPay
    │   │   ├── storage_service.dart   # Supabase Storage: upload/download file
    │   │   └── tts_service.dart       # Text-to-Speech phát âm từ vựng
    │   │
    │   ├── theme/
    │   │   ├── app_theme.dart         # ThemeData Light + Dark mode
    │   │   └── theme_provider.dart    # Riverpod provider toggle dark/light
    │   │
    │   ├── utils/
    │   │   ├── formatters.dart        # Format ngày, số, chuỗi
    │   │   └── validators.dart        # Form validation rules
    │   │
    │   └── widgets/                   # ★ SHARED WIDGET COMPONENTS
    │       ├── cute_3d_button.dart    # ★ Nút bấm 3D Capy signature
    │       ├── mascot_banner.dart     # Banner mascot Capybara responsive
    │       ├── floating_points_effect.dart # +XP bay lên animation
    │       ├── loading_overlay.dart   # Màn loading toàn màn hình
    │       └── custom_confirm_dialog.dart  # Dialog xác nhận tái sử dụng
    │
    ├── shared/                        # ══ THÀNH PHẦN CHIA SẺ ══
    │   └── navigation/
    │       └── bottom_nav_bar.dart    # Bottom Navigation 5 tab + FAB Camera giữa
    │
    └── features/                      # ══ CÁC MODULE TÍNH NĂNG ══
        │
        ├── auth/                      # 🔐 XÁC THỰC
        │   ├── data/models/user_model.dart
        │   ├── data/repositories/auth_repository_impl.dart
        │   ├── domain/entities/user_entity.dart
        │   ├── domain/repositories/auth_repository.dart
        │   ├── presentation/providers/auth_provider.dart
        │   ├── presentation/screens/auth_screen.dart
        │   └── presentation/widgets/social_auth_button.dart
        │
        ├── onboarding/                # 🎯 WIZARD ONBOARDING 5 BƯỚC
        │   ├── domain/entities/onboarding_data.dart
        │   ├── presentation/providers/onboarding_provider.dart
        │   ├── presentation/screens/onboarding_wizard_screen.dart
        │   └── presentation/widgets/
        │       ├── step1_name_username.dart   # Bước 1: Tên & username
        │       ├── step2_age_phone.dart       # Bước 2: Tuổi & SĐT
        │       ├── step3_role_selector.dart   # Bước 3: Mục đích học
        │       ├── step4_study_time.dart      # Bước 4: Thời gian học/ngày
        │       └── step5_daily_target.dart    # Bước 5: Mục tiêu từ/ngày
        │
        ├── home/                      # 🏠 MÀN HÌNH CHÍNH
        │   ├── data/datasources/user_supabase_datasource.dart
        │   ├── data/repositories/vocab_repository.dart
        │   ├── presentation/providers/home_provider.dart
        │   ├── presentation/providers/streak_provider.dart
        │   ├── presentation/screens/home_screen.dart
        │   └── presentation/widgets/
        │       ├── lesson_map_winding_path.dart  # ★ Bản đồ học winding path
        │       ├── mini_leaderboard_podium.dart  # Podium top 3 bạn bè
        │       └── streak_flame_widget.dart      # Ngọn lửa streak animation
        │
        ├── ai_scan/                   # 🤖 QUÉT ẢNH AI VISION
        │   ├── domain/entities/photo_note_entity.dart
        │   ├── domain/entities/vocab_entity.dart
        │   ├── presentation/providers/scan_provider.dart
        │   ├── presentation/screens/
        │   │   ├── photo_scan_bottom_sheet.dart  # Bottom sheet chọn ảnh
        │   │   ├── selected_vocab_screen.dart    # Xác nhận từ AI nhận diện
        │   │   └── storage_album_screen.dart     # Thư viện ảnh đã quét
        │   └── presentation/widgets/
        │       ├── note_template_selector.dart   # Chọn template ghi chú
        │       └── scan_loading_overlay.dart     # Skeleton loading AI
        │
        ├── chatbot/                   # 💬 CHATBOT AI CAPYBARA
        │   ├── data/datasources/chat_supabase_datasource.dart
        │   ├── domain/entities/chat_message_entity.dart
        │   ├── presentation/providers/chat_provider.dart
        │   ├── presentation/screens/chat_window.dart
        │   └── presentation/widgets/
        │       ├── chat_detail_view.dart          # Chi tiết cuộc hội thoại
        │       ├── chat_inbox_view.dart           # Danh sách inbox
        │       └── draggable_chat_toggle.dart     # ★ Nút chat kéo thả được
        │
        ├── friends/                   # 👥 BẠN BÈ & XÃ HỘI
        │   ├── data/datasources/friends_supabase_datasource.dart
        │   ├── domain/entities/friend_entity.dart
        │   ├── presentation/providers/friends_provider.dart
        │   ├── presentation/screens/friends_leaderboard_screen.dart
        │   └── presentation/widgets/
        │       ├── add_friend_modal.dart
        │       └── friend_list_item.dart
        │
        ├── mini_games/                # 🎮 MINI GAMES
        │   ├── photo_letter_fill/     # Game 1: Điền chữ cái từ ảnh
        │   │   ├── presentation/providers/photo_letter_fill_provider.dart
        │   │   ├── presentation/screens/photo_letter_fill_screen.dart
        │   │   └── presentation/widgets/letter_input_box.dart
        │   └── photo_order_quiz/      # Game 2: Sắp xếp thứ tự từ ảnh
        │       ├── presentation/providers/photo_order_quiz_provider.dart
        │       ├── presentation/screens/photo_order_quiz_screen.dart
        │       └── presentation/widgets/order_number_chip.dart
        │
        ├── solo_arena/                # ⚔️ ĐẤU TRƯỜNG SOLO PvP
        │   ├── data/datasources/solo_arena_supabase_datasource.dart
        │   ├── domain/entities/solo_question_entity.dart
        │   ├── presentation/providers/solo_arena_provider.dart
        │   ├── presentation/screens/
        │   │   ├── solo_lobby_screen.dart         # Phòng chờ / tìm đối thủ
        │   │   ├── solo_battle_screen.dart        # Màn hình trận đấu thực tế
        │   │   └── solo_result_screen.dart        # Kết quả & XP thắng/thua
        │   └── presentation/widgets/
        │       ├── bet_slider.dart                # Thanh trượt đặt cược XP
        │       └── countdown_timer.dart           # Đếm ngược 10s mỗi câu
        │
        ├── pet_shop/                  # 🛍️ CỬA HÀNG THÚ CƯNG
        │   ├── data/datasources/shop_supabase_datasource.dart
        │   ├── domain/entities/shop_item_entity.dart
        │   ├── presentation/providers/pet_shop_provider.dart
        │   ├── presentation/screens/pet_shop_screen.dart
        │   └── presentation/widgets/
        │       ├── pet_preview_card.dart          # Card xem trước thú cưng
        │       └── shop_item_card.dart            # Card vật phẩm trong shop
        │
        ├── settings/                  # ⚙️ CÀI ĐẶT
        │   ├── data/datasources/subscription_supabase_datasource.dart
        │   ├── presentation/providers/settings_provider.dart
        │   ├── presentation/screens/settings_screen.dart
        │   └── presentation/widgets/
        │       ├── pro_paywall_modal.dart         # Modal nâng cấp PRO
        │       └── theme_toggle_button.dart       # Nút chuyển Dark/Light
        │
        └── notifications/             # 🔔 THÔNG BÁO
            ├── data/datasources/notification_supabase_datasource.dart
            ├── presentation/providers/notification_provider.dart
            ├── presentation/screens/notification_center_screen.dart
            └── presentation/widgets/notification_item.dart
```

---

## 6. 🎨 DESIGN SYSTEM & CAPY AESTHETIC

### 🌈 Color Tokens (AppColors)

| Token | Hex | Vai Trò |
|-------|-----|---------|
| `primary` | `#F5A623` | Capy Gold — màu chủ đạo nút bấm, highlight |
| `primaryDark` | `#D4891E` | Đế 3D của Cute3DButton, pressed state |
| `secondary` | `#4A7C59` | Sage Green — màu bản đồ bài học, progress bar |
| `accent` | `#FF85A1` | Peach Pink — đúng câu, confetti, thưởng XP |
| `bgLight` | `#FAFAFA` | Nền sáng |
| `bgDark` | `#1E1E2C` | Nền tối |
| `cardLight` | `#FFFFFF` | Màu card chế độ sáng |
| `cardDark` | `#2A2A3D` | Màu card chế độ tối |
| `textPrimary` | `#2D3142` | Chữ chính (sáng) |
| `textPrimaryDark` | `#F8F9FA` | Chữ chính (tối) |
| `textMuted` | `#9C9EB9` | Chữ phụ, caption, placeholder |
| `error` | `#E74C3C` | Lỗi, sai câu |
| `success` | `#27AE60` | Đúng câu, kết nối thành công |

### ✒️ Typography (AppTextStyles)

```dart
// Heading / Nút bấm → Fredoka (bo tròn, playful)
GoogleFonts.fredoka(fontSize: 28, fontWeight: FontWeight.w700)

// Nội dung bài học, card → Nunito (chuẩn đọc)
GoogleFonts.nunito(fontSize: 16, height: 1.5)

// Caption, phụ → Nunito Light
GoogleFonts.nunito(fontSize: 13, color: AppColors.textMuted)
```

### 🔘 Component Chuẩn Capy Aesthetic

#### 1. Cute3DButton (Nút Bấm 3D Đặc Trưng)
```dart
// Cấu tạo: mặt nút phẳng + đế 3D dày 5-6px đậm hơn
Container(
  decoration: BoxDecoration(
    color: AppColors.primaryDark,   // đế 3D
    borderRadius: BorderRadius.circular(18),
  ),
  child: Transform.translate(
    offset: isPressed ? Offset(0, 4) : Offset(0, 0), // nhấn xuống khi tap
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.primary,   // mặt nút
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label, style: AppTextStyles.button),
    ),
  ),
)
```

#### 2. FloatingPointsEffect (+XP Bay Lên)
- `+10 XP`, `+5 Streak` nảy nảy, bay lên, fade out trong `600ms`.
- Trigger: mỗi khi trả lời đúng hoặc hoàn thành bài học.

#### 3. ConfettiWidget (Pháo Hoa Chiến Thắng)
- Dùng package `confetti: ^0.7.0`.
- Bắn đồng loạt 2 bên khi: hoàn thành cấp độ, thắng Solo Arena, mua vật phẩm hiếm.

#### 4. MascotBanner (Linh Vật Capybara)
- Biểu cảm thay đổi theo context: 😊 vui khi đúng, 😢 an ủi khi sai, 🎉 cổ vũ khi level up.

### 📐 Spacing & Border Radius

| Token | Value | Dùng cho |
|-------|-------|---------|
| `radiusSmall` | `8dp` | Input fields, chips |
| `radiusMedium` | `16dp` | Cards, modals |
| `radiusLarge` | `24dp` | Nút bấm chính, bottom sheets |
| `radiusXL` | `32dp` | Full rounded pill buttons |
| `spacingBase` | `8dp` | Spacing unit cơ sở (grid 8pt) |
| `shadowCard` | `0 4px 16px rgba(0,0,0,0.08)` | Card shadow mặc định |

---

## 7. 📱 MOBILE DESIGN RULES (TỪ SKILL mobile-design)

> **Triết lý:** Touch-first. Battery-conscious. Platform-respectful. Offline-capable.  
> **Core:** Mobile KHÔNG phải desktop thu nhỏ — luôn nghĩ đến giới hạn mobile.

### ⚡ Quy Tắc Bắt Buộc

| Quy Tắc | Giá Trị | Lý Do |
|---------|---------|-------|
| Touch Target tối thiểu | `44×44 dp` | Ngón tay tiếp xúc ~7mm, không thể chính xác như chuột |
| Khoảng cách giữa targets | `≥ 8dp` | Tránh tap nhầm |
| Micro-animation duration | `150–300ms` | Dưới 150ms không cảm nhận được, trên 300ms khó chịu |
| Animation Curve | `Curves.easeInOut` | Tự nhiên nhất trên mobile |
| Body font size tối thiểu | `16sp` | Đọc được khi đặt điện thoại xa |
| Giãn dòng (line-height) | `1.5` | Chuẩn đọc trên màn hình nhỏ |

### 📍 Thumb Zone — Vùng Chạm Ngón Cái

```
┌──────────────────────┐
│   HARD TO REACH ☆    │ ← Menu, settings, back button
│      (kéo dài)       │
├──────────────────────┤
│   OK TO REACH ◎      │ ← Secondary actions, filters
│     (tự nhiên)       │
├──────────────────────┤
│ EASY TO REACH ★★★   │ ← PRIMARY CTAs, Tab Bar
│  (vùng ngón cái)     │ ← Nút Học, Nút Đấu, FAB Camera
└──────────────────────┘
       [HOME BAR]
```

**→ Áp dụng trong CapyVocabApp:**
- Tab Bar 5 nút ở **đáy màn hình** = vùng dễ reach nhất ✅
- FAB Camera quét ảnh ở **giữa Tab Bar** = dễ tap nhất ✅
- Nút Học / Nút Đấu = vùng dưới, ưu tiên Bottom Sheet thay modal giữa màn ✅

### 🚀 Flutter Performance Rules (từ mobile-design/flutter)

```dart
// ✅ ĐÚNG: const constructor ngăn rebuild thừa
class VocabCard extends StatelessWidget {
  const VocabCard({super.key, required this.word}); // PHẢI có const!
  final String word;

  @override
  Widget build(BuildContext context) {
    return const Column( // Column tĩnh → const!
      children: [
        Icon(Icons.volume_up),
      ],
    );
  }
}

// ✅ ĐÚNG: ListView.builder cho danh sách dài (KHÔNG dùng Column + map)
ListView.builder(
  itemCount: vocabs.length,
  itemBuilder: (context, index) => VocabCard(word: vocabs[index].word),
)

// ✅ ĐÚNG: Chỉ animate transform & opacity (GPU)
// ❌ SAI: Animate width/height/margin (CPU → jank)
AnimatedContainer(
  duration: Duration(milliseconds: 200),
  transform: Matrix4.translationValues(0, offset, 0), // ✅ GPU
)
```

---

## 8. 💙 FLUTTER EXPERT RULES (TỪ SKILL flutter-expert)

### 📝 Dart 3.x Best Practices

```dart
// ✅ Pattern Matching Dart 3
switch (result) {
  case Success(data: final d) => handleSuccess(d),
  case Failure(error: final e) => handleError(e),
}

// ✅ Records thay vì class nhỏ
(String word, String phonetic) getVocabInfo() => ('hello', '/həˈloʊ/');

// ✅ Sealed class cho domain errors
sealed class AuthError {}
class InvalidCredentials extends AuthError {}
class NetworkError extends AuthError {}

// ✅ Async/Await với mounted check
Future<void> loadData() async {
  final result = await SupabaseService.from('vocabularies').select();
  if (!mounted) return; // ← BẮT BUỘC sau mỗi await có dùng context
  setState(() => _vocabs = result);
}
```

### 🏗️ Repository Pattern Chuẩn

```dart
// domain/repositories/vocab_repository.dart
abstract class VocabRepository {
  Future<List<VocabEntity>> getVocabsByLesson(String lessonId);
  Future<void> updateProgress(String vocabId, int masteryLevel);
}

// data/repositories/vocab_repository_impl.dart
class VocabRepositoryImpl implements VocabRepository {
  @override
  Future<List<VocabEntity>> getVocabsByLesson(String lessonId) async {
    try {
      final data = await SupabaseService.from('vocabularies')
          .select()
          .eq('lesson_id', lessonId);
      return data.map((e) => VocabModel.fromJson(e).toEntity()).toList();
    } catch (e) {
      throw DataException('Không thể tải từ vựng: $e');
    }
  }
}
```

### 🎛️ Riverpod State Notifier Pattern

```dart
// presentation/providers/vocab_provider.dart
@riverpod
class VocabNotifier extends _$VocabNotifier {
  @override
  AsyncValue<List<VocabEntity>> build() => const AsyncData([]);

  Future<void> loadVocabs(String lessonId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(vocabRepositoryProvider).getVocabsByLesson(lessonId),
    );
  }
}
```

---

## 9. 🎨 UI/UX PRO MAX RULES (TỪ SKILL ui-ux-pro-max)

### 🎯 Design Thinking Cho CapyVocabApp

- **Product Type:** EdTech Gamification App (education + gaming)
- **Style:** Claymorphism + Cute 3D — bề mặt mềm mại bo tròn, bóng đổ màu, màu sắc tươi sáng
- **Tone:** Playful / Toy-like — không bao giờ generic, luôn có character
- **Differentiator:** Linh vật Capybara responsive + Cute 3D Button đặc trưng

### 🚦 Priority Rules (Theo Thứ Tự Ưu Tiên)

#### Priority 1 — Accessibility (CRITICAL)
- Tỷ lệ tương phản chữ/nền: **≥ 4.5:1** (văn bản thường) / **≥ 3:1** (heading lớn)
- Focus states hiển thị rõ trên tất cả interactive element
- Mọi icon button phải có `Semantics(label: '...')` để screen reader đọc được
- `prefers-reduced-motion` → giảm animation khi user chọn chế độ ít chuyển động

#### Priority 2 — Touch & Interaction (CRITICAL)
- Touch target tối thiểu `44×44dp` — KHÔNG có ngoại lệ
- Nút bấm trong quá trình async → **disable + hiện loading indicator**
- Thông báo lỗi hiển thị **gần vị trí gây lỗi**, không chỉ toast chung
- Mọi phần tử có thể click đều thêm `InkWell` / `GestureDetector` với `Cursor.pointer`

#### Priority 3 — Animation Quality (MEDIUM)
- Duration: `150ms` cho micro-interactions, `300ms` cho transitions, `600ms` cho celebrations
- Chỉ animate: `Transform`, `Opacity` (GPU-accelerated) — **không animate** `width`, `height`
- Skeleton loading thay vì spinner cho content load

#### Priority 4 — Light/Dark Mode Contrast
| Vấn đề | ❌ Sai | ✅ Đúng |
|--------|-------|--------|
| Card light mode | `bg-white/10` (quá trong suốt) | `#FFFFFF` với border nhẹ |
| Text light mode | `#94A3B8` (quá mờ) | `#2D3142` (contrast đủ) |
| Text muted | `gray-300` (invisible) | `#9C9EB9` (vẫn readable) |

### 📋 Pre-Delivery UI Checklist

Trước mỗi PR / bàn giao code có UI:
- [ ] Không dùng màu hardcode — phải import từ `AppColors`
- [ ] Không dùng `TextStyle()` inline — phải import từ `AppTextStyles`
- [ ] Tất cả nút bấm chính dùng `Cute3DButton` widget
- [ ] Heading dùng Fredoka, body dùng Nunito
- [ ] Touch targets ≥ 44×44dp
- [ ] Loading state đã xử lý (`AsyncValue.when(loading: ...)`)
- [ ] Error state đã xử lý (`AsyncValue.when(error: ...)`)
- [ ] Responsive: test trên màn 360dp (nhỏ) và 414dp (lớn)

---

## 10. 🔌 SUPABASE INTEGRATION PATTERN

### Cách Đúng Gọi Supabase

```dart
// lib/core/services/supabase_service.dart
class SupabaseService {
  // Truy cập client toàn cục
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  // Shorthand query table
  static SupabaseQueryBuilder from(String table) => client.from(table);
  static RealtimeChannel channel(String name) => client.channel(name);

  // Khởi tạo từ .env
  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    await Supabase.initialize(url: url, anonKey: key, debug: kDebugMode);
  }

  // Test kết nối
  static Future<bool> testConnection() async {
    try {
      await client.from('vocabularies').select().limit(1);
      debugPrint('✅ Supabase connected');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase error: $e');
      return false;
    }
  }
}
```

### Ví Dụ Datasource Chuẩn

```dart
// data/datasources/user_supabase_datasource.dart
class UserSupabaseDatasource {
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await SupabaseService.from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } on PostgrestException catch (e) {
      throw DataException('Lỗi DB: ${e.message}');
    }
  }
}
```

### Auth Pattern

```dart
// Đăng ký
await SupabaseService.auth.signUp(email: email, password: password);

// Đăng nhập
await SupabaseService.auth.signInWithPassword(email: email, password: password);

// Lấy user hiện tại
final user = SupabaseService.auth.currentUser;

// Nghe trạng thái auth thay đổi
SupabaseService.auth.onAuthStateChange.listen((data) {
  final session = data.session;
});
```

---

## 11. ✅ CHECKLIST TRƯỚC KHI GIAO CODE

### Code Quality
- [ ] Phân tầng đúng: UI code không chứa SQL/HTTP
- [ ] `const` constructor đặt đúng chỗ
- [ ] Không dùng `!` toán tử nguy hiểm
- [ ] `if (!mounted) return;` sau mỗi `await` có dùng context

### Supabase
- [ ] Gọi qua `SupabaseService.from()` không gọi trực tiếp
- [ ] Bọc `try-catch` với error message thân thiện
- [ ] RLS policy đã cân nhắc (user chỉ đọc data của mình)

### UI/UX
- [ ] Màu từ `AppColors`, style từ `AppTextStyles`
- [ ] Nút chính dùng `Cute3DButton`
- [ ] Loading state (`AsyncLoading`) đã xử lý
- [ ] Error state (`AsyncError`) đã xử lý với retry
- [ ] Touch targets ≥ 44×44dp

### Performance
- [ ] Danh sách dài dùng `ListView.builder`, không `Column + map`
- [ ] `const` widget cho phần tĩnh
- [ ] Dispose controllers/subscriptions trong `dispose()`

---

## 12. ⛔ ANTI-PATTERNS CẤM TUYỆT ĐỐI

| ❌ TUYỆT ĐỐI KHÔNG | ✅ THAY BẰNG |
|---------------------|-------------|
| Hardcode màu `Color(0xFFF5A623)` trực tiếp | `AppColors.primary` |
| Hardcode `TextStyle(fontFamily: 'Fredoka')` | `AppTextStyles.heading` |
| Gọi `Supabase.instance.client` trực tiếp ở UI | `SupabaseService.from('table')` |
| `Column(children: vocabs.map(...).toList())` cho list dài | `ListView.builder` |
| Business logic trong Screen widget | Chuyển vào Notifier/Provider |
| `setState` trong StatelessWidget | Dùng Riverpod `ref.watch` |
| Token/key nhạy cảm hardcode trong code | Chỉ đặt trong `.env` |
| `debugPrint` bỏ lại trong production | Xóa hoặc dùng log conditional |
| Widget `!mounted` crash sau async | Luôn kiểm tra `if (!mounted) return` |
| Không có error state | Luôn handle `AsyncError` và show retry |

---

*📅 Cập nhật: 28/07/2026 — CapyVocabApp Master Blueprint v2.1*  
*🔌 Kết nối Supabase: ✅ Đã xác nhận thành công*  
*🗄️ Database: 15 bảng đã khởi tạo trên Production DB*  
*📝 v2.1 bổ sung: §13 Gemini Vision Error Handling · §14 AI Scan Canvas Flow · §15 Payment Integration · §16 Error Catalog · §17 Testing Strategy*

---

## 13. 🤖 GEMINI VISION ERROR HANDLING (AI SCAN — PHẦN 1)

> **AI Model thực tế:** Gemini 1.5 Flash (qua REST API / Google AI SDK)  
> **Service file:** `lib/core/services/gemini_vision_service.dart`  
> **KHÔNG phải:** Google Cloud Vision REST API thuần

### 📦 Quy Trình Tiền Xử Lý Ảnh (BẮT BUỘC trước khi gửi API)

```
Ảnh gốc từ Camera / Gallery
         │
         ▼
┌─────────────────────────────────┐
│  flutter_image_compress          │
│  • Resize tối đa 1024×1024 px   │
│  • Format: JPEG, quality: 85     │
│  • Giới hạn output < 300 KB      │
└─────────────────────────────────┘
         │
         ▼
  Mã hóa Base64 → nhúng vào JSON body
         │
         ▼
  POST → Gemini 1.5 Flash API
```

**Lý do bắt buộc nén trước:**
- Gemini có giới hạn payload size — ảnh gốc từ camera thường 3-10 MB sẽ bị từ chối.
- Nén về < 300 KB giữ chất lượng OCR đủ tốt và giảm latency mạng.

```dart
// lib/core/services/gemini_vision_service.dart
Future<Uint8List> _compressImage(File imageFile) async {
  final compressed = await FlutterImageCompress.compressWithFile(
    imageFile.absolute.path,
    minWidth: 512,
    minHeight: 512,
    quality: 85,
    format: CompressFormat.jpeg,
  );
  // Nếu vẫn > 300KB, giảm quality thêm
  if (compressed != null && compressed.length > 300 * 1024) {
    return await FlutterImageCompress.compressWithList(
      compressed, quality: 60, format: CompressFormat.jpeg,
    ) ?? compressed;
  }
  return compressed ?? await imageFile.readAsBytes();
}
```

### ⏱️ Timeout & Loading State

| Thông số | Giá Trị | Lý Do |
|----------|---------|-------|
| HTTP timeout | **12 giây** | Gemini 1.5 Flash thường trả về < 5s; 12s buffer cho mạng chậm |
| Hiển thị trong khi chờ | `LoadingOverlay` **toàn màn hình, chặn tap** | Không cho user chụp thêm ảnh khi API đang xử lý |
| Retry tự động | **Không** — yêu cầu user bấm lại | Tránh spam API gây tốn quota |

```dart
final response = await http.post(
  Uri.parse(geminiEndpoint),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(requestBody),
).timeout(
  const Duration(seconds: 12),
  onTimeout: () => throw TimeoutException('Gemini timeout sau 12 giây'),
);
```

### 🚦 Xử Lý Lỗi Theo HTTP Status Code

| HTTP Code | Nguyên Nhân | Hành Vi App | Thông Báo User |
|-----------|-------------|-------------|----------------|
| `200 OK` | Thành công | Parse JSON → lưu SQLite → render Canvas | _(không hiện thông báo)_ |
| `400` | Request body sai (ảnh lỗi) | Log lỗi, show snackbar | "Ảnh không hợp lệ, hãy chụp lại" |
| `429` | **Hết quota Gemini** | Show Dialog + nút điều hướng PRO | "Hệ thống đang bận, nâng cấp PRO để dùng không giới hạn" → điều hướng `pro_paywall_modal.dart` |
| `500` | Lỗi server Gemini | Retry 1 lần sau 2s, nếu vẫn lỗi show snackbar | "Dịch vụ AI tạm thời gián đoạn, thử lại sau" |
| `TimeoutException` | Mạng chậm / ảnh lớn | Show snackbar | "Quét ảnh mất quá nhiều thời gian, kiểm tra kết nối mạng" |

### 📄 Định Dạng JSON Response Mong Đợi Từ Gemini

```json
{
  "detected_vocabulary": [
    {
      "word": "hello",
      "phonetic": "/həˈloʊ/",
      "meaning": "xin chào",
      "part_of_speech": "exclamation",
      "bounding_box": {
        "x": 0.12,
        "y": 0.35,
        "w": 0.08,
        "h": 0.04
      }
    }
  ],
  "image_language": "en",
  "confidence": 0.94
}
```

> Tọa độ `x, y, w, h` là **tỷ lệ tương đối** so với kích thước ảnh (0.0–1.0), KHÔNG phải pixel tuyệt đối — để Canvas render đúng trên mọi kích thước màn hình.

---

## 14. 🖼️ LUỒNG LƯU TRỮ & RENDER CANVAS AI SCAN (PHẦN 2)

> **Nguyên tắc cốt lõi:** Ảnh luôn sống trên máy user — KHÔNG phụ thuộc mạng để hiển thị lại.

### 📐 Sơ Đồ 4 Bước Chính Xác

```
┌──────────────────────────────────────────────────────────────┐
│ BƯỚC 1 — LƯU LOCAL (offline-first)                          │
│                                                              │
│  Chụp ảnh / Chọn từ Gallery                                 │
│         ↓                                                    │
│  Nén ảnh (JPEG, max 1024×1024, < 300KB)                     │
│         ↓                                                    │
│  Lưu vào bộ nhớ máy user                                    │
│  → Lấy local_path: /data/user/0/.../capy_scan_1722156000.jpg│
│  ⛔ KHÔNG upload Supabase Storage ở bước này                │
└──────────────────────────────────────────────────────────────┘
         ↓
┌──────────────────────────────────────────────────────────────┐
│ BƯỚC 2 — GỬI GEMINI API                                     │
│                                                              │
│  Đọc file từ local_path → mã hóa Base64                     │
│  Tạo JSON request → POST Gemini 1.5 Flash                   │
│  Timeout: 12 giây                                            │
│  → Nhận JSON response: [{word, phonetic, meaning, x,y,w,h}] │
└──────────────────────────────────────────────────────────────┘
         ↓
┌──────────────────────────────────────────────────────────────┐
│ BƯỚC 3 — LƯU SQLite CỤC BỘ (cache tốc độ)                  │
│                                                              │
│  Bảng: scan_results                                          │
│  Lưu: { id, local_path, vocab_json (TEXT), created_at }      │
│                                                              │
│  ⚠️ SQLite ở đây KHÔNG phải nguồn đồng bộ đa thiết bị       │
│  → Mục đích: hiển thị tức thì khi mở lại, không cần mạng    │
│  → Supabase KHÔNG lưu ảnh/tọa độ Canvas                     │
│  → Chỉ đồng bộ lên Supabase: danh sách từ vựng đã chọn     │
│     vào bảng vocabularies / user_vocab_progress              │
└──────────────────────────────────────────────────────────────┘
         ↓
┌──────────────────────────────────────────────────────────────┐
│ BƯỚC 4 — RENDER CANVAS (không tải lại từ server)            │
│                                                              │
│  Lớp nền: Image.file(File(local_path))                       │
│  → Load tức thì từ ổ đĩa, zero latency mạng                 │
│                                                              │
│  Lớp đè: CustomPaint(painter: VocabOverlayPainter(vocabs))  │
│  → Đọc x, y, w, h từ vocab_json trong SQLite                │
│  → Vẽ ô highlight + label từ vựng chính xác trên ảnh nền    │
└──────────────────────────────────────────────────────────────┘
```

### 🗃️ Schema SQLite Cục Bộ (scan_results)

```sql
CREATE TABLE IF NOT EXISTS scan_results (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  local_path TEXT NOT NULL,        -- đường dẫn file ảnh trên máy
  vocab_json TEXT NOT NULL,        -- JSON array từ Gemini response
  created_at TEXT DEFAULT (datetime('now'))
);
```

### 🔄 Chiến Lược Đồng Bộ (SQLite ↔ Supabase)

| Dữ Liệu | Lưu Ở Đâu | Đồng Bộ Supabase? | Lý Do |
|---------|-----------|-------------------|-------|
| File ảnh nén | SQLite local_path | ❌ Không | Quá lớn, mỗi thiết bị tự quản |
| Tọa độ Canvas (x,y,w,h) | SQLite vocab_json | ❌ Không | Gắn liền với ảnh cụ thể trên máy đó |
| Từ vựng user đã chọn lưu | **Supabase** `vocabularies` | ✅ Có | Cần học trên mọi thiết bị |
| Tiến độ học từ (SRS) | **Supabase** `user_vocab_progress` | ✅ Có | Core feature đa thiết bị |

### 🎨 Render Canvas Code Pattern

```dart
// presentation/widgets/vocab_canvas_overlay.dart
class VocabOverlayPainter extends CustomPainter {
  final List<VocabBoundingBox> vocabs;
  final Size imageSize;
  VocabOverlayPainter({required this.vocabs, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    for (final vocab in vocabs) {
      final rect = Rect.fromLTWH(
        vocab.x * imageSize.width * scaleX,
        vocab.y * imageSize.height * scaleY,
        vocab.w * imageSize.width * scaleX,
        vocab.h * imageSize.height * scaleY,
      );
      // Vẽ ô highlight
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = AppColors.accent.withOpacity(0.35)
              ..style = PaintingStyle.fill,
      );
      // Vẽ border
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = AppColors.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

---

## 15. 💳 PAYMENT INTEGRATION — KIẾN TRÚC TÍCH HỢP THANH TOÁN (PHẦN 3)

### 🗺️ Luồng Thanh Toán Tổng Quan

```
User bấm "Nâng Cấp PRO" (pro_paywall_modal.dart)
         │
         ▼
[Flutter App] gọi payment_service.dart
         │ createTransaction(userId, planType, amount)
         ▼
[Cổng thanh toán] (MoMo / ZaloPay / App Store IAP / Google Play)
         │ Trả về paymentUrl / deeplink
         ▼
[Mở WebView / Deep Link] → User hoàn tất thanh toán
         │
         ▼
[Cổng thanh toán] gửi Webhook POST đến:
  → Supabase Edge Function: /functions/v1/payment-webhook
         │
         ▼
[Edge Function] verify signature → update subscriptions table
  {
    user_id: ...,
    plan_type: 'monthly' | 'yearly',
    status: 'active',
    end_date: now + 30/365 ngày
  }
         │
         ▼
[Flutter App] lắng nghe Supabase Realtime channel 'subscriptions'
→ Tự động cập nhật UI, unlock tính năng PRO
```

### 🔐 Bảo Mật Webhook (Chống Giả Mạo)

| Biện Pháp | Mô Tả |
|-----------|-------|
| **Verify HMAC Signature** | Mỗi cổng thanh toán gửi header `X-Signature` — Edge Function verify bằng secret key lưu trong Supabase Vault |
| **Idempotency check** | Lưu `transaction_id` vào `shop_purchases` — nếu webhook gửi lại duplicate, bỏ qua (không cộng thêm thời gian) |
| **IP Whitelist** (tùy chọn) | Chỉ nhận webhook từ IP cố định của cổng thanh toán |
| **HTTPS only** | Endpoint Edge Function mặc định HTTPS — không cần cấu hình thêm |

```typescript
// supabase/functions/payment-webhook/index.ts
Deno.serve(async (req) => {
  const signature = req.headers.get('X-Signature') ?? '';
  const body = await req.text();
  const secret = Deno.env.get('PAYMENT_WEBHOOK_SECRET')!;

  // 1. Verify chữ ký HMAC-SHA256
  const expectedSig = await hmacSha256(secret, body);
  if (signature !== expectedSig) {
    return new Response('Unauthorized', { status: 401 });
  }

  const payload = JSON.parse(body);
  if (payload.status !== 'SUCCESS') {
    return new Response('Ignored non-success', { status: 200 });
  }

  // 2. Idempotency check
  const { data: existing } = await supabase
    .from('shop_purchases')
    .select('id')
    .eq('transaction_id', payload.transactionId)
    .single();
  if (existing) return new Response('Duplicate', { status: 200 });

  // 3. Update subscriptions
  const endDate = new Date();
  endDate.setDate(endDate.getDate() + (payload.planType === 'yearly' ? 365 : 30));
  await supabase.from('subscriptions').upsert({
    user_id: payload.userId,
    plan_type: payload.planType,
    status: 'active',
    start_date: new Date().toISOString(),
    end_date: endDate.toISOString(),
  });

  return new Response('OK', { status: 200 });
});
```

### ⚠️ Xử Lý Thanh Toán Thất Bại / Timeout

| Tình Huống | Hành Vi App | Thông Báo User |
|-----------|-------------|----------------|
| User tắt app giữa chừng | Webhook vẫn đến → subscription tự cập nhật lần sau mở app | Không cần xử lý thêm |
| Cổng thanh toán timeout | App nhận callback thất bại → **KHÔNG** update subscription | "Thanh toán chưa hoàn tất, kiểm tra lịch sử giao dịch trong ví" |
| Webhook chậm > 1 phút | App poll `subscriptions` table 1 lần sau 30s | "Đang xác nhận thanh toán, vui lòng chờ..." |
| Subscription hết hạn khi đang dùng | Check `end_date` mỗi lần mở app → nếu hết hạn, disable PRO features | Dialog: "Gói PRO đã hết hạn, gia hạn để tiếp tục" |

---

## 16. 🚨 ERROR CATALOG — LỖI CỤ THỂ THEO NGHIỆP VỤ (PHẦN 4)

> Bảng này thay thế cách xử lý "AsyncError chung chung" — mỗi case có hành vi **rõ ràng và thông báo thân thiện**.

### 📋 Bảng Lỗi Theo Nghiệp Vụ

| # | Tình Huống | Hành Vi App Mong Muốn | Thông Báo Hiển Thị Cho User |
|---|-----------|----------------------|-----------------------------|
| **E-01** | **Mất mạng giữa trận Solo Arena** | Dừng timer, lưu state hiện tại vào local cache, hiện Dialog với 2 lựa chọn: Đợi kết nối lại hoặc Bỏ cuộc | "Mất kết nối! Trận đấu bị tạm dừng. Kết nối lại để tiếp tục." + nút "Bỏ cuộc (-{betAmount} XP)" |
| **E-02** | **Kết nối lại trong Solo Arena** | Resume timer từ chỗ dừng, sync state từ Supabase Realtime, hiện toast | "Đã kết nối lại! ⚡" |
| **E-03** | **Solo Arena — đối thủ mất mạng > 30s** | Tự động thắng cho user còn lại, update kết quả vào DB | "Đối thủ mất kết nối — bạn thắng! 🏆" |
| **E-04** | **Gemini timeout (ảnh lớn / mạng chậm)** | Dismiss LoadingOverlay, hiện Snackbar có nút Retry | "Quét ảnh mất quá lâu. Kiểm tra mạng và thử lại" + nút "Thử lại" |
| **E-05** | **Gemini 429 — hết quota** | Show Dialog, nút điều hướng PRO paywall | "Hệ thống đang bận. Nâng cấp PRO để quét không giới hạn!" |
| **E-06** | **Ảnh quét không nhận diện được từ nào** | Hiện màn hình rỗng với hướng dẫn | "Không tìm thấy từ vựng trong ảnh này. Thử chụp ảnh rõ hơn có chứa chữ tiếng Anh." |
| **E-07** | **Thanh toán bị gián đoạn giữa chừng** | KHÔNG update subscription, hiện Dialog hướng dẫn kiểm tra ví | "Thanh toán chưa hoàn tất. Kiểm tra lịch sử trong ứng dụng thanh toán của bạn." |
| **E-08** | **Token auth hết hạn khi đang dùng app** | Intercept 401 response → gọi `auth.refreshSession()` tự động → nếu refresh thất bại, điều hướng về `auth_screen.dart` | "Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại." |
| **E-09** | **Supabase DB offline / maintenance** | Hiện banner cảnh báo ở đầu màn hình, tiếp tục cho dùng offline (SQLite cache) | "Đang gặp sự cố kết nối máy chủ. Một số tính năng có thể bị hạn chế." |
| **E-10** | **Tải bảng từ vựng lỗi** | Hiện màn hình error với nút Retry rõ ràng | "Không thể tải bài học. Kiểm tra kết nối và thử lại." + nút "Thử Lại" |
| **E-11** | **User xóa tài khoản nhưng còn subscription** | Kiểm tra và hủy subscription trước khi xóa, gửi webhook hủy thanh toán | Dialog xác nhận: "Xóa tài khoản sẽ hủy gói PRO và mất toàn bộ dữ liệu. Bạn có chắc?" |

### 🔧 Pattern Xử Lý Lỗi Chuẩn Trong Notifier

```dart
// Mọi Notifier đều follow pattern này
Future<void> loadData() async {
  state = const AsyncLoading();
  try {
    final result = await repository.fetchData();
    state = AsyncData(result);
  } on SocketException {
    state = AsyncError('Không có kết nối mạng', StackTrace.current);
  } on TimeoutException {
    state = AsyncError('Yêu cầu hết thời gian chờ, thử lại', StackTrace.current);
  } on PostgrestException catch (e) {
    if (e.code == '401') {
      // Refresh token
    }
    state = AsyncError('Lỗi cơ sở dữ liệu: ${e.message}', StackTrace.current);
  } catch (e) {
    state = AsyncError('Đã xảy ra lỗi không mong muốn', StackTrace.current);
  }
}
```

---

## 17. 🧪 TESTING STRATEGY (PHẦN 5)

> **Mục tiêu:** Định nghĩa phạm vi test tối thiểu trước release — không cần viết hết ngay nhưng phải biết NHỮNG GÌ cần test.

### 🔬 Unit Tests — Business Logic Bắt Buộc

| Module | Test Case | Lý Do Quan Trọng |
|--------|-----------|------------------|
| **Solo Arena Scoring** | Tính điểm đúng khi trả lời đúng/sai trong time limit | Logic cốt lõi ảnh hưởng XP và tiền ảo |
| **Solo Arena Betting** | Trừ/cộng XP đúng khi thắng/thua, không trừ âm | Liên quan trực tiếp đến tài khoản user |
| **Streak Calculation** | Streak tăng khi học đủ ngày, reset khi bỏ 1 ngày | Feature quan trọng, logic ngày/múi giờ dễ sai |
| **SRS Mastery Level** | `next_review_at` tính đúng theo `interval_days` và `ease_factor` | Thuật toán lặp lại ngắt quãng — sai = user học không hiệu quả |
| **XP Threshold** | Level up đúng khi đủ XP, giới hạn XP hợp lệ | Không để XP âm hoặc level vượt giới hạn |
| **Image Compression** | Ảnh sau nén < 300KB và vẫn là JPEG hợp lệ | Đảm bảo Gemini nhận ảnh đúng định dạng |
| **Bounding Box Render** | Tọa độ tương đối × kích thước ảnh = pixel đúng | Canvas render sai vị trí = UX tệ |

### 🖥️ Widget Tests — Màn Hình Chính

| Screen | Những Gì Cần Test |
|--------|------------------|
| `auth_screen.dart` | Form validation (email format, password length), nút Submit disable khi loading |
| `home_screen.dart` | Lesson Map render đúng số node, Streak widget hiển thị đúng số ngày |
| `solo_battle_screen.dart` | Countdown timer đếm ngược đúng, nút trả lời disable sau khi chọn |
| `photo_scan_bottom_sheet.dart` | LoadingOverlay hiển thị khi gọi API, ẩn khi xong |
| `pet_shop_screen.dart` | Nút Mua disable khi không đủ coins, hiện đúng giá |
| `pro_paywall_modal.dart` | Các tính năng PRO hiển thị đúng, nút CTA dẫn đến đúng flow payment |

### 🔗 Integration Tests — Luồng Quan Trọng Nhất

| Luồng | Mô Tả |
|-------|-------|
| **Auth Flow** | Đăng ký → Onboarding 5 bước → Home screen |
| **Complete Lesson** | Học bài → trả lời đúng → XP cộng → Streak tăng → Confetti |
| **AI Scan Full Flow** | Chụp ảnh → nén → gửi Gemini → render Canvas → lưu từ |
| **Solo Arena Match** | Tạo phòng → ghép đối thủ → trận đấu → kết quả → XP update |

### 📊 Coverage Mục Tiêu Trước Release

| Loại Test | Minimum Coverage | Ưu Tiên |
|-----------|-----------------|----------|
| Unit (business logic) | **≥ 80%** | 🔴 Cao nhất |
| Widget (UI screens) | **≥ 60%** | 🟡 Trung bình |
| Integration (flows) | ≥ 4 luồng chính | 🟡 Trung bình |

### ⚙️ Cấu Trúc Thư Mục Test

```
test/
├── unit/
│   ├── solo_arena_scoring_test.dart
│   ├── streak_calculator_test.dart
│   ├── srs_algorithm_test.dart
│   └── image_compression_test.dart
├── widget/
│   ├── auth_screen_test.dart
│   ├── home_screen_test.dart
│   ├── solo_battle_screen_test.dart
│   └── pet_shop_screen_test.dart
└── integration/
    ├── auth_flow_test.dart
    ├── lesson_complete_flow_test.dart
    └── solo_arena_flow_test.dart
```
