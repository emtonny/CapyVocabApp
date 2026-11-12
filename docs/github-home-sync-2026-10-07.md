# Đồng bộ GitHub Home — 2026-10-07

Trạng thái: **source tích hợp và kiểm chứng local; chưa nghiệm thu backend/thiết bị của bản ghép**.

## Source và bảo toàn tiến trình

- Workspace đích: `D:\01_Projects\CapyVocabApp`, nhánh `interface`, HEAD `d03c80e`.
- Đã fetch GitHub; nguồn chức năng mới là `origin/home` tại `664a7c9`, có parent `4596ad4` (`origin/chat`).
- Phần staged local đã chứa phần lớn Chat/Friends/Auth tương ứng remote. Áp dụng riêng Home bằng `git cherry-pick --no-commit 664a7c9` trên toàn bộ snapshot local trong worktree; không merge lại lịch sử Chat/Friends và không tạo commit.
- Worktree kiểm chứng: `D:\01_Projects\CapyVocabApp-sync-home-20261007`, nhánh `sync/home-20261007`.
- Backup: `D:\01_Projects\CapyVocabApp-sync-backup-20261007`. Có `staged.patch`, `unstaged.patch`, `index.original`, toàn bộ file mới và file đã sửa trong `files`, SHA-256 `manifest.json`, danh sách `untracked.json`, `status.original` và log kiểm chứng. 210 đường dẫn được kiểm tra bản sao trước tích hợp. Artifact DOCX local được sao lưu, không đưa vào phần nhập source.
- Chỉ đưa chênh lệch giữa snapshot local và bản ghép về workspace đích; giữ nguyên index/staging ban đầu. Commit Home không xuất hiện trong lịch sử HEAD vì chưa được phép commit; code mới hiện ở working tree để review.

## Chức năng đã nhập

- Home: mission theo ngày/múi giờ, bản đồ bài học, tiến trình, streak, số dư xu vàng và phần chờ đồng bộ.
- Game ảnh: ghép từ với target đánh số; điền chữ có Unicode normalization; snapshot từ Library, kiểm tra owner/media/nguồn bị xóa; mastery đến khi hoàn thành.
- Session offline, tiếp tục lượt chơi, lịch sử attempt và kết quả qua SQLite Library v8; completion outbox và retry đồng bộ.
- Migration server cho completion receipts, settlement xu vàng, replay có thưởng và leaderboard tuần; test và runner tương ứng.
- Route `/lesson`, bộ lọc Library theo thời gian chụp và nút luyện tập từ Photo Note.

Giữ nguyên Chat hộp thư/ảnh Album/nhãn/avatar, thay đổi Friends/Settings local, Vilao và sửa lỗi backend ngày 01/10: ACK không xóa sửa đổi mới, consent/owner fence khi pull, SQLite tương thích 3.22, retry invalidation và cleanup queue. Bốn migration audit draft được giữ nguyên.

## Xung đột và khác biệt rule

- Router ghép tự động; không khôi phục route/màn Chat cũ đã xóa local.
- Bốn migration trùng tên (`20260928120000`, `20260928130000`, `20260929132557`, `20260929143000`) khác comment/khoảng trắng; SQL giống nhau sau loại comment/whitespace. Giữ file local nguyên bản.
- `db_status.md` giữ cả lịch sử Home upstream và lịch sử sửa lỗi local; các entry live upstream không phải kiểm chứng mới cho bản ghép.
- `docs/two_photo_games_rules_plan.md` và `docs/coin_rules_plan.md` giữ các đề xuất cũ kèm ghi chú trạng thái. Home dùng target đánh số để giải thích thứ tự, không coi vị trí không gian hoặc `displayOrder` là đáp án ngầm. Sai được luyện lại đến mastery 100%.
- Thưởng nhiệm vụ/replay hiện theo `home.md` và RPC server, không theo điểm mỗi câu. Ledger H5 chỉ bao phủ thưởng lesson; không có nghĩa toàn bộ đề xuất opening ledger, shop, cược và nạp xu đã được triển khai.
- Result sync vẫn cần `LESSON_RESULT_SYNC_ENABLED=true`; mặc định false. Runner Staging nhập từ Home bật flag này. Cloud media vẫn đi qua Library contract; không tự tải media để chơi game.
- Nhập hai dependency Home: [flutter_timezone 3.0.1](https://pub.dev/packages/flutter_timezone/versions/3.0.1) lấy timezone thiết bị (Apache-2.0), [unorm_dart 0.3.2](https://pub.dev/packages/unorm_dart/versions/0.3.2) chuẩn hóa Unicode (MIT). `pub get` giữ các ràng buộc upstream; SDK hiện tại điều chỉnh `meta` lên 1.18.0 và `test_api` lên 0.7.11. Không nâng Flutter hay đổi dependency ngoài nhu cầu resolution.

## Kiểm chứng bản ghép

| Lệnh/check | Kết quả |
| --- | --- |
| `flutter pub get` | Pass |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub test/features/home test/features/mini_games test/features/library test/features/chat test/features/friends test/features/settings test/shared --reporter expanded` | 493 pass, 1 live opt-in skip |
| `flutter test --no-pub --reporter expanded` | 777 pass, 1 live opt-in skip |
| `deno test --config supabase/functions/chat-translation-worker/deno.json --node-modules-dir=auto --allow-env supabase/functions/chat-translation-worker` | 52 pass |
| `deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan` | 80 pass |
| `dart format --output=none --set-exit-if-changed` trên 65 file Dart của increment Home | 0 thay đổi |
| `flutter build web --no-pub` | Pass, JavaScript build |
| `flutter build apk --debug --no-pub` | Pass |
| PowerShell parse `tool/run_staging_device_smoke.ps1` | Pass |
| Diff check của increment so với snapshot local | Pass |
| `tool/test_home_h2a_schema.ps1` | Blocked: thiếu PostgreSQL native, chưa chạy SQL |
| `tool/run_staging_friend_f6_e2e.ps1 -SelfTest` | Blocked: script yêu cầu PowerShell 7, máy dùng 5.1 và không có `pwsh` |

Full diff với HEAD có blank line EOF đã tồn tại trong draft `20261001014515_order_library_change_feed.sql`; không sửa file audit để che cảnh báo. Web vẫn cảnh báo Wasm của `flutter_tts` và thiếu CupertinoIcons; Android cảnh báo plugin Kotlin Gradle và lệch SDK XML. Các build được chạy ở chế độ hiện hành và exit 0.

## Kiểm chứng sau khi đưa về workspace chính

Đã chuyển 89 đường dẫn của increment về `interface`, so sánh nội dung với worktree và xác nhận `staged.patch` ban đầu không đổi. `flutter pub get` và `flutter analyze --no-pub` tại workspace chính pass; 20 regression tests cho router/onboarding cache, Library upload ACK/pull và Chat Album picker pass. Không còn unmerged index hoặc conflict marker.

## Giới hạn và bước nghiệm thu còn lại

- Chưa apply/deploy, ghi tài khoản thật, thay đổi consent hoặc thao tác media trên remote.
- Cần PostgreSQL để chạy Home và backend audit SQL suites của bản ghép; không tự cài runtime. Audit migration ngày 01/10 vẫn draft chưa apply.
- Cần kiểm tra migration history/schema của môi trường đích trước rollout; không suy ra runtime khớp chỉ từ các file source hoặc entry upstream.
- Cần smoke thiết bị online → offline → reconnect, đổi account, nguồn bị xóa và receipt/reward/leaderboard của bản ghép. iOS không build trên Windows.
- Backup và worktree được giữ lại. Chỉ hoàn tác bằng patch/index/file backup sau khi kiểm tra không có công việc mới phát sinh; không `stash pop` bản cũ lên trạng thái đã ghép.

## BlueStacks launch sau đồng bộ — 2026-10-07

Runner BlueStacks được bổ sung `LESSON_RESULT_SYNC_ENABLED=true` cho Staging và parse sạch. `tool/run_bluestacks.ps1 -Port 5555 -Staging` build/cài debug APK thành công; MainActivity ở foreground, process sống sau Flutter detach, không có fatal/Flutter error lúc startup. Không clear data/uninstall, không apply/deploy, chưa chạy gameplay/reward E2E. Dry-run của runner nghiệm thu riêng xác nhận bốn migration audit ngày 01/10 còn thiếu trên remote; database giữ nguyên.
