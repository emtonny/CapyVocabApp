# Đồng bộ GitHub — 2026-11-03

Trạng thái: **đã tích hợp source; kiểm thử trọng tâm đạt; còn lỗi test local có sẵn và chưa nghiệm thu backend/thiết bị**.

## Nguồn và phạm vi

- Đã `git fetch --all` từ origin và vocab1. `interface` vẫn khớp `origin/interface` tại `d03c80e`.
- Nhập thay đổi `origin/home..origin/group`, commit `8116e251ddc26e7633e02fd3e7b6406b4aec0417` (26/10/2026).
- `git cherry origin/group origin/Friend` xác nhận 9 commit Friends đã có patch tương đương trong chuỗi Chat; bổ sung patch riêng `b2dee3e` cho runner F6. Nội dung runner này thực tế đã khớp local nên không tạo thay đổi bổ sung.
- Các nhánh origin/main, AI-scan, chat, home và vocab1/main, vocab1/nam-30-7 không có patch riêng ngoài group. Các commit riêng của interface đã có trong HEAD local, được giữ nguyên.
- Không tạo commit, push, đổi nhánh chính, apply migration, deploy function hoặc sửa dữ liệu remote.

## Bảo toàn và xử lý xung đột

- Backup `D:\01_Projects\CapyVocabApp-sync-backup-20261103`: staged/unstaged binary patches, index ban đầu, status, manifest SHA-256 và bản sao 347 đường dẫn sửa/xóa/mới. Kiểm tra hash bản sao trước ghép.
- Worktree riêng: `D:\01_Projects\CapyVocabApp-sync-group-20261103`, detached tại HEAD ban đầu. Dùng Git tree và index tạm để so sánh, không tạo commit.
- Giữ các chỉnh sửa Home, Library, Album Chat, ảnh/nhãn, avatar, Settings và giao diện local. Không khôi phục màn Chat cũ đã xóa.
- Thêm nhóm học/giáo viên, quản lý thành viên, bài tập, chia sẻ tiến trình dạng text, chat nhóm và social group beta theo source upstream.
- Nút nhóm học nằm tại Friends. Chat nhóm học mở qua mailbox hiện có; tạo social group, hiển thị người gửi và quản lý social group được nối vào mailbox.
- Giữ chức năng gửi ảnh Album cho chat riêng. Chat nhóm dùng text theo contract upstream; composer tắt gửi và đính kèm khi chỉ đọc.
- Hai nhánh dùng SQLite Chat v7/v8 cho mục đích khác nhau. Giữ migrations Album v7/v8, thêm group v9, social owner v10 và translation v3 v11. Test nâng cấp từ cache local v8 xác nhận giữ tin nhắn, nhãn/đường dẫn ảnh, hàng đợi invalidation và bản dịch Vilao v2; schema mới nhận thêm Gemini v3.
- Migration wallet `20261008173000` giữ bản local: upstream chỉ thêm một câu lệnh rỗng `;` cuối file, không có khác biệt hành vi SQL.
- Giữ default upstream `LESSON_RESULT_SYNC_ENABLED=true` và Groups bật mặc định. Không thay dependency hoặc nâng SDK.
- Các ghi nhận live/staging trong tài liệu upstream là lịch sử của upstream, không phải xác minh mới cho bản ghép.

## Kiểm chứng

Log lưu trong thư mục backup.

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter pub get` | Đạt; không đổi pubspec/lockfile |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub test/features/chat test/features/groups test/features/friends test/features/onboarding test/features/mini_games --reporter expanded` | 331 đạt |
| `flutter test --no-pub --reporter expanded` trước 2 test adapter cuối | 863 đạt, 1 live opt-in skip, 3 lỗi có sẵn |
| Worker: `deno test --config supabase/functions/chat-translation-worker/deno.json --node-modules-dir=auto --allow-env supabase/functions/chat-translation-worker` | 52 đạt |
| `flutter build web --no-pub` | Đạt, JavaScript build |
| `flutter build apk --debug --no-pub` | Đạt |
| Format Dart của increment | Đạt |
| Git diff check của increment | Đạt |
| Parse các PowerShell script của increment | 0 lỗi |
| `powershell -NoProfile -File tool/test_group_gt1_schema.ps1` | Không chạy SQL: thiếu native PostgreSQL |

Ba lỗi có sẵn được chạy lại ngay trên workspace chính trước khi đưa source ghép về:

- `test/features/settings/settings_screen_test.dart`: `missing database avatar does not show a demo image`.
- `test/shared/navigation/bottom_nav_bar_test.dart`: golden lệch 1.12% (784 pixel).
- `test/shared/widgets/sticker_button_test.dart`: golden lệch 1.52% (301 pixel).

Không sửa expectation, cập nhật golden hoặc bỏ qua các test này để làm xanh kết quả.
Web còn cảnh báo Wasm của flutter_tts và thiếu CupertinoIcons. Android còn cảnh báo Kotlin Gradle Plugin và SDK XML. Các build hiện hành exit 0.

## Chưa nghiệm thu

- Chưa chạy các SQL security/concurrency suites của nhóm và translation v3 vì thiếu PostgreSQL; không cài runtime mới.
- Chưa kiểm tra migration history/schema môi trường đích, apply migration hoặc deploy translation worker.
- Chưa smoke thiết bị cho giáo viên/học viên, chat nhóm, realtime, offline/reconnect và đổi tài khoản của bản ghép.
- Chưa build iOS trên Windows. Source đã tích hợp không đồng nghĩa backend hoặc thiết bị đã sẵn sàng phát hành.

## Ki?m ch?ng sau khi chuy?n v? workspace ch?nh

- ?? chuy?n v? ki?m tra SHA-256 c?a 91 ???ng d?n thu?c increment; staged binary patch ban ??u gi? nguy?n, kh?ng c? unmerged index.
- `flutter pub get`: ??t; kh?ng thay dependency ho?c lockfile.
- `flutter analyze --no-pub`: No issues found.
- `flutter test --no-pub --reporter expanded`: **865 ??t, 1 live opt-in skip, ??ng 3 l?i c? s?n ?? li?t k? ? tr?n**. Hai test adapter b? sung x?c nh?n t?o social group t? mailbox v? m? chat nh?m h?c qua mailbox hi?n h?nh m? kh?ng c?n route Chat c?.
- `flutter build apk --debug --no-pub`: ??t t?i workspace ch?nh. APK t?i `build/app/outputs/flutter-apk/app-debug.apk`; kh?ng c?i ho?c ch?y app tr?n thi?t b?.
- `dart format --output=none --set-exit-if-changed` tr?n 44 file Dart c?a increment: 0 file thay ??i.
- Bi?n b?n, backup v? worktree ???c gi? ?? review; HEAD v? nh?nh `interface` gi? nguy?n v? kh?ng t?o commit.
