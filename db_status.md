# Database & Storage Status

> Source of truth cho Database, local media, offline Library, Supabase sync và
> dữ liệu chuẩn bị cho on-device AI.  
> Cập nhật gần nhất: **2026-10-06 — HOME H5 RELEASE CANDIDATE VERIFIED; GIT PREP READY**
> Final gate chạy lại trên exact Staging `nxteaznowkfennxpqjmt`: migration
> dry-run `upToDate=true`, synthetic hai-account smoke pass 9 nhóm và cleanup
> còn 0 fixture. PostgreSQL cô lập pass 58/58, full Flutter pass 763 + 1 skip,
> analyzer sạch, Web release và APK release 70,7 MB build pass. Quét secret
> không thấy private key, personal access token hay JWT thật. ADB không thấy
> thiết bị ở lần kiểm tra 06/10, nên smoke Android vật lý gần nhất vẫn là lần
> pass 04/10. Production không bị thay đổi; chưa commit hoặc push.
>
> Trạng thái trước: **2026-10-04 — HOME H5A–H5D COMPLETE; EXACT-STAGING + ANDROID VERIFIED**
> H5A settlement server-authoritative đã áp dụng bảng thưởng đúng hạn/muộn,
> replay một phần ba chỉ vào ví, streak không phục hồi khi muộn và ledger
> owner-readable/không client-mutable. SQLite nâng additive v7→v8 bằng bảng
> `rewarded_replay_sessions`; snapshot gameplay đầu tiên được tái sử dụng và
> outbox vẫn owner-scoped/idempotent. H5C thêm RPC weekly leaderboard chỉ cho
> self + mutual accepted friends, lấy duy nhất `weekly_yuzu` đã xác nhận; Home
> có cache owner-scoped và offline timestamp. Exact Staging backup DPAPI
> 385.711 byte tại `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20261004T082658Z-adba54ec`;
> hai migration `20261004120000`/`20261004130000` apply pass, post-dry-run sạch.
> Synthetic hai-account smoke pass 9 nhóm, cleanup còn 0 fixture. SQL isolated
> pass 58/58, Home pass 49/49, full Flutter pass 763 + 1 skip, analyzer sạch,
> Web release và APK release exact-Staging build pass. APK được cài đè giữ dữ
> liệu trên CPH2375; cold-start online, cache offline, reconnect cùng tiến trình
> và điều hướng Library/Shop/Friends/Camera/Chat đều pass. Home profile stream
> retry backoff 2/5/15/30 giây sau lỗi tạm thời nên không còn kẹt offline đến
> lần restart kế tiếp. Wi-Fi và mobile data đã khôi phục đúng trạng thái ban đầu.
> Production không bị thay đổi.
>
> Trạng thái trước: **2026-10-01 — HOME H4 EXACT-STAGING VERIFIED; ANDROID INSTALL PENDING**
> SQLite được nâng additive từ v5 lên v6 với trạng thái sync riêng cho
> `lesson_completion_results`; gameplay payload vẫn immutable, review result
> không vào queue. Worker/coordinator owner-scoped xử lý sign-in, resume, local
> change, reconnect, exponential backoff và manual retry; restart không mất
> completion hoặc tạo result thứ hai. Home/màn kết quả hiển thị `Chờ đồng bộ`,
> `Đã đồng bộ`, `Đồng bộ lỗi` và tách Yuzu dự kiến khỏi số dư chi tiêu.
> Migration `20260930160000_add_lesson_completion_sync.sql` tạo receipt immutable
> và RPC authenticated/RLS idempotent; H4 không ghi Yuzu, streak hoặc leaderboard.
> PostgreSQL isolated pass 35/35, Home + mini-game + SQLite pass 92/92, full
> Flutter pass 756 + 1 skip và analyzer sạch. Exact Staging
> `nxteaznowkfennxpqjmt` đã backup DPAPI 371.127 byte tại
> `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20261001T054525Z-2723e4d2`;
> dry-run chỉ có H4, apply pass, hậu kiểm `upToDate=true`. Synthetic REST/RPC
> smoke pass 6 nhóm, cleanup còn 0 fixture và reward writes bằng 0. APK release
> exact-Staging với `LESSON_RESULT_SYNC_ENABLED=true` build pass; chưa cài lại vì
> `adb devices` đang rỗng. Production không bị truy cập.
>
> Trạng thái trước: **2026-09-30 — H3 MARKER VISIBILITY/PERFORMANCE VERIFIED**
> Badge marker đã tách khỏi constraint bbox, giữ 36 dp với contrast vàng/đen;
> ảnh local decode theo kích thước render và được cô lập repaint. Mini-game pass
> 34/34, analyzer toàn dự án sạch; không đổi file media, schema hoặc sync.
>
> Library SQLite được nâng additive từ v4 lên v5 với ba bảng owner-scoped:
> `lesson_sessions`, `lesson_attempts` và `lesson_completion_results`.
> Snapshot/rule/source của session được đóng băng; attempt append-only; chỉ
> mastery 100% mới tạo đúng một immutable completion result. Store transaction
> đã qua test pause/khôi phục draft sau reopen, requeue, retry idempotent,
> payload conflict rollback, account isolation và bỏ bài giữ tiến trình nhưng
> tắt quyền thưởng. Migration v4→v5 giữ nguyên daily mission; targeted SQLite
> pass 12/12. H3C/H3D đã nối source builder, controller, hai game UI, Home và
> Library review vào cùng store v5; review result không có mission date và
> không đủ điều kiện nhận thưởng. Full Flutter suite pass 748, skip 1; analyzer
> sạch; Web release và APK debug build thành công. APK exact-Staging đã cài trên
> CPH2375: session auth được khôi phục, online/offline/reconnect Home pass và
> mạng được trả về `wifi=1/mobile_data=1`. Tài khoản có `0/10` từ hợp lệ và
> Library trống nên gameplay background/force-stop chưa thể smoke trên device.
> Đây vẫn chỉ là local
> persistence: chưa thêm outbox/Supabase sync, chưa apply remote, deploy hoặc
> push.
>
> Trạng thái trước: **2026-09-28 — HOME H2A–H2D COMPLETE ON STAGING; ONLINE/OFFLINE/RECONNECT PASS**
> Ba migration `20260928120000`, `20260928130000` và `20260928140000` đã apply
> đúng Staging `nxteaznowkfennxpqjmt`; history khớp và dry-run hậu apply
> `upToDate=true`. Migration cuối thêm `public.users` idempotently vào
> `supabase_realtime`; authenticated SELECT và owner RLS không đổi. SQL isolated
> gate pass 23/23. APK exact-Staging trên CPH2375: online không còn banner
> offline, offline thật `wifi=0/mobile_data=0` vẫn render mission cache, và
> reconnect online bỏ banner trở lại; không có Auth/PostgREST/Realtime/crash
> error. Mission vẫn đúng 1 row/1 owner-day, publication đúng 1 entry. Mạng đã
> khôi phục `1/1`. Production không bị truy cập; chưa deploy hoặc push.
>
> Mốc Home H2 ngày 27/09 đã thêm lớp đọc owner-scoped trên Library SQLite, gom Photo Note
> theo `media_assets.captured_at`, khử trùng từ hợp lệ và dựng node tuần/tháng.
> Khi đó chưa đổi schema/version/write path/outbox/sync. Mục tiêu ngày đọc
> `user_settings.daily_target_words` và cache SharedPreferences theo user.
> Boundary 23:59/00:00 cùng delayed recognition đã qua test; Android offline
> smoke xác nhận thẻ nhiệm vụ/bản đồ thoát loading, đổi Tuần/Tháng và không có
> crash/overflow. Các giới hạn account timezone/per-day immutable target của
> mốc này đã được H2A/H2B xử lý cục bộ như trạng thái mới nhất ở trên.
> Web release build pass nhưng Chrome test runner riêng bị treo và đã dừng.
> Không apply migration, deploy hay push.
>
> Home H1 đọc `users.total_coins` như số dư Yuzu đã xác nhận và lưu snapshot
> SharedPreferences theo từng user. Cache chỉ chứa display name, số dư, streak,
> Yuzu chờ và thời gian cập nhật; tài khoản khác không đọc chung key. Lỗi cache
> không chặn dữ liệu Supabase mới. Không đổi schema, migration, RLS, outbox hay
> contract Library sync. Badge thông báo đọc stream hiện có; leaderboard tuần
> không dùng `study_points` giả thay point ledger. Analyzer sạch, targeted
> Home/navigation 13/13 và full Flutter 675 pass + 1 live skip; Web release và
> APK debug build pass. Chrome widget runner riêng bị timeout, nhưng Web release
> build pass. APK Staging được cài đè giữ data lên CPH2375 Android 13; Home render
> đúng và PID-scoped startup log không có crash/Flutter error/overflow. Không
> deploy/push.
>
> Friends F1–F6: **IMPLEMENTED / EXACT-STAGING VERIFIED** — migration additive cho exact
> username/email/phone discovery, private opt-in/audit/rate limit, atomic friend
> request/response và keyset list đã qua PostgreSQL 18 **68/68**; C2 regression
> **47/47**. Flutter F2 thêm typed RPC gateway, session fence, Realtime
> invalidation và SQLite cache riêng theo project/account; **14/14** fake
> HTTP/SQLite tests pass. F3 thêm UI exact search/send và discovery opt-in; F4
> thêm incoming/outgoing tabs, badge, cache-first/Realtime refresh và atomic
> accept/reject theo từng peer. F5 thêm accepted public-profile list, revalidate
> quan hệ trước Chat và canonical conversation handoff. Sau increment hoàn thiện,
> Friends + Settings + màn Chat liên quan **86/86**, full Flutter **658 pass +
> 1 opt-in skip**, analyzer sạch và Web build pass. Exact-Staging A/B/C REST + ba WebSocket,
> consent lookup, request/accept/reject, outsider isolation, canonical Chat và
> cleanup baseline đều pass. Increment hoàn thiện thay scaffold widget bằng UI
> thật, giữ Chat CTA tương thích, thêm Supabase Auth phone-change OTP từ Settings
> và bật Friends/Chat mặc định trong source cùng runner exact Staging. Runtime
> vẫn fail-closed ngoài exact Staging; Production chưa apply. UI MVP được thu gọn còn
> username; email/phone discovery và OTP không còn được render. Contract, RLS và
> migration vẫn giữ nguyên. Quyết định sản phẩm mới đã duyệt xác nhận email và
> giữ SMS quốc tế ở trạng thái dormant để tránh chi phí, đổi liên hệ có xác nhận,
> hiển thị liên hệ chỉ cho bạn bè đã chấp nhận và giữ gói hiện hành tới hết hạn.
> Migration email-only `20260924120000` đã apply exact Staging sau backup DPAPI;
> post-apply history khớp và dry-run sạch. Live ba tài khoản xác nhận Chat,
> Realtime, correction, raw-sender-only annotation/RLS và cleanup pass. Hai demo
> account vẫn đăng nhập, có quan hệ accepted đối xứng, đủ language profile và
> cùng một conversation. Production không linked/apply; Git không push.
>
> Các migration đã apply exact Staging theo approval; post-apply dry-run sạch và
> Vault/pg_cron/pg_net/signatures verified. SQL C4B/C4G 58/58; Deno 52/52.
> Dedicated Chat secrets + Vault entries configured; worker ACTIVE and live
> Gemini multi-user/single-flight/RLS/cleanup smoke VERIFIED. Production untouched.
> C5 reads the owner-scoped local translation cache in both Chat surfaces;
> personalized order/states/accessibility pass locally and on real Web↔Android
> clients. CPH2375 raw→worker→translation/cold cache and A/B order pass. C5 complete.
> C6B adds a read-only, owner-scoped lookup over the existing Library SQLite
> tables. Latest active vocabulary correction wins; deleted/tombstoned Photo
> Notes are excluded. No schema version, migration, write path, outbox, sync,
> cloud data, Production or Training change. Local tests and CPH2375 exact-
> Staging selection/empty-state/cold restart pass. C6B complete.
> C6C source adds an additive Supabase correction resolver/audit migration and
> separate operational Chat SQLite v4 cache/outbox. Raw messages and Gemini
> translations remain immutable. Local PostgreSQL 18 security checks pass
> 24/24, C2 regression passes 47/47, Chat Flutter tests pass 139/139, full
> Flutter passes 590 + 1 opt-in skip, and the full analyzer is clean.
> Exact-Staging backup/apply/post-dry-run and a three-account synthetic C6C smoke
> passed with complete fixture cleanup, zero Gemini calls and zero Training
> writes. Chat-enabled Android APK builds/installs/runs on CPH2375. A valid
> Android proposal persisted with one audit event; the temporary language-profile
> swap was restored remotely and in cache. Raw-sender accept/reject UI on Web was
> later live verified, closing C6C. Production was untouched.
> C6D adds `chat_slang_annotations` to Operational Chat and upgrades its local
> SQLite cache/outbox from v4 to v5. Only the raw sender may tag an exact Unicode
> code-point span after accepting a correction; rows are immutable and remain
> outside Training. Local SQL passes 17/17 plus C6C 24/24 and C2 47/47; Chat
> passes 149/149, full Flutter passes 600 + 1 opt-in skip, analyzer is clean.
> Exact-Staging backup/apply/post-dry-run and 10-group synthetic smoke passed
> with six-table Realtime, cleanup 0, Gemini 0 and Training 0. Android build,
> install and boot pass. Web raw sender accepted the real proposal and created
> one `[0,2)` `other` annotation for `ok` normalized to `đồng ý`; Web and Android
> peer rendered it through Realtime and Android cold restart restored it. C6 complete.
> C6E keeps the same database/RLS/rune-offset contract and replaces the primary
> selection UX with tap-to-select tokens. Web raw sender saved a second live
> annotation: `ok` `[0,2)`, type `slang`, normalized `được`; remote read-only
> verification confirmed `source_speaker`, `active`, accepted correction and
> actor = raw sender. The reversed live flow also passed: Android sent raw marker
> `C6EANDROIDRAW0248`, received and accepted the Web proposal, then selected the
> token and saved `[0,17)`/`slang`/`android c6e`. Exact-Staging confirmed the
> accepted correction and active source-speaker annotation with the Android raw
> sender as actor. The temporary Web profile swap was restored to `vi -> en`;
> Android cold restart reopened the conversation and PID-scoped fatal matches
> were 0.
> Không có chatbot riêng. Thẻ/UI/Edge Function `chat-bot` tạo nhầm đã được gỡ.
> Key Vilao nằm server-side trong `chat-translation-worker` chỉ để dịch Chat
> người-với-người. Migration v2 và worker v18 đã deploy exact Staging; live
> synthetic Vilao smoke, RLS, single-flight và cleanup đều verified. Production
> và Training không đổi.
>
> Snapshot trước đó: Chat có bubble toàn cục 64dp kiểu AssistiveTouch, kéo/bám mép và tự lùi
> vào mép sau 5 giây; panel neo-brutalist có tìm kiếm, thông báo AI chưa mở,
> profile bạn bè thật, preview, sắp xếp/badge chưa đọc. Local operational Chat
> DB nâng additive từ v1 lên v2: thêm `last_read_at` và bảng cache owner-scoped
> `chat_peer_profiles`; không đổi Supabase schema. Analyzer sạch, 95/95 Chat và
> full suite 541 pass + 1 opt-in skip. APK exact Staging cài đè/giữ data và panel
> render đúng trên BlueStacks Android 9, không có Overlay/overflow/SQLite runtime
> error. Hai migration onboarding vẫn chỉ dry-run/pending; không có remote write.
>
> Theo yêu cầu chuyển môi trường, repo đã relink từ Production sang exact Staging
> `nxteaznowkfennxpqjmt` (`ACTIVE_HEALTHY`). APK debug được build bằng runner có
> `CHAT_RELAY_ENABLED=true`, cài đè giữ dữ liệu và launch thành công trên BlueStacks
> Android 9. Migration chỉ dry-run; hai migration onboarding còn pending và không
> được apply. Production không bị ghi hoặc thay đổi.
>
> AI-scan increment: **empty-result retry và tối ưu ảnh; SOURCE/TEST VERIFIED**
>
> Increment hiện tại xác nhận độ trễ mở preview camera trên BlueStacks Android 9
> nằm trong app camera/HAL bên ngoài Flutter (hai lần đo khoảng 11,8 giây và
> 11,3 giây). Pipeline Flutter đã giảm phần chờ sau khi chụp bằng cách yêu cầu
> ảnh 1024px/quality 85 từ picker, tái sử dụng JPEG đã đạt giới hạn và bỏ một
> lần decode preview thừa. Edge Function nay thử lại đúng một lần khi upstream
> trả HTTP 200 với `words: []`, không ghi ledger success rỗng, và trả 422 nếu
> lần thứ hai vẫn rỗng. Source đã qua targeted Flutter/Edge tests và analyzer;
> Edge Function **chưa deploy**, không có migration hoặc cloud-data write.
>
> Snapshot trước đó (2026-09-16):
> Increment chèn bước ngôn ngữ ở vị trí 2/6 của onboarding, lưu
> `interface_locale` và `learning_locale` vào `user_settings` qua RPC
> `complete_onboarding`. Migration đã được apply lên Production project
> `vmxonxqxrlkssdzsucrg`; chỉ thay đổi schema/RPC, không ghi dữ liệu cloud.
> Targeted onboarding tests
> đạt 26/26 và analyzer riêng cho onboarding sạch. Full-project analyzer đang
> bị chặn bởi các file tách Library chưa hoàn chỉnh có sẵn trong working tree.
>
> Snapshot trước đó (2026-09-15):
> Increment hiện tại bổ sung sub-tab Album, bố cục Library đồng bộ nền/style, tạo/yêu thích/xóa
> đơn và hàng loạt, xem chi tiết, thêm/gỡ Photo Note bằng contract `AlbumRepository` hiện có. Không đổi
> schema, migration, media lifecycle, consent, sync flag hoặc dữ liệu cloud.
> Analyzer sạch; full Flutter suite 410 pass + 1 opt-in live skip. Targeted
> 20/20 widget test Thư viện và 22/22 SQLite pass, gồm viewport 360px;
> APK debug đã cài và kiểm tra trực tiếp trên BlueStacks.
>
> Snapshot đồng bộ backend trước đó (2026-09-12):
> Increment hiện tại đã kéo toàn bộ code GitHub, giữ Vilao làm gateway mặc định,
> giữ auth/entitlement/ledger/circuit breaker và contract SQLite/Library mới.
> Flutter 390 pass + 1 live skip; Edge 82 pass; analyzer, Web và APK debug pass.
> Read-only history trên project client khớp 21/21 migration. Không apply
> migration, deploy, đổi secret/consent hay ghi dữ liệu cloud trong increment.
> Các bằng chứng Staging/Production phía dưới là lịch sử nhập từ GitHub,
> không phải kết quả chạy lại của bản ghép Vilao. Xem `docs/github-vilao-sync.md`.
>
> Snapshot trước đồng bộ (2026-09-11):
> Trạng thái tổng thể: **Nhánh `AI-scan` đã fast-forward đủ 6 commit giao diện/auth mới tới `cbd7318`. UI neo-brutalist, graph-paper, soft page transition và password recovery đã được hòa trộn với router onboarding synchronous, Library detail/trash, entitlement và Cloud Backup local hiện có; analyzer sạch và nhóm test liên quan đạt 73/73. Các file Edge Function đang chạy theo quota/circuit-breaker/ledger local được giữ nguyên trong working tree; thay đổi Vilao gateway từ commit mới chưa được đưa vào runtime/deploy và cần một increment backend riêng. Production M3A/M4.5 vẫn giữ nguyên, bucket private, default `LIBRARY_SYNC_ENABLED=false`; không có migration, cloud write hay deploy trong lần đồng bộ UI này.**
>
> Chat branch snapshot:
> Cập nhật gần nhất: **2026-09-21 — C6 COMPLETE / C6E TWO-CLIENT LIVE VERIFIED**
> Trạng thái tổng thể: **C2 đã apply Staging theo approval sau backup mới;
> 47 local SQL/RLS checks và 10 nhóm REST/Realtime multi-user smoke pass,
> fixtures cleanup 0. Staging history 23/23, dry-run up to date. C1 COMPLETE:
> backend regression, approved pair, primary Settings/cache device evidence và
> second-account owner-isolation UI regression pass. Production chưa apply C1/C2;
> C3A/B/C đã COMPLETE trên exact Staging: bidirectional Web/Android raw relay,
> cold Web restore, Android offline enqueue/restart/reconnect/single-render và
> physical A→B→A owner-cache restoration đều verified. Lost-ACK/idempotency và
> inactive-membership fail-closed được đóng bằng 57 client tests + live 10/10
> REST/Realtime/RLS smoke. Final full suite 495 pass/1 existing skip/0 failure;
> analyzer clean. Runtime vẫn opt-in `CHAT_RELAY_ENABLED`, exact Staging và
> foreground. C4A contract, C4B PostgreSQL, C4C worker, C4D Gemini adapter, C4E
> client cache và C4F runtime reconcile đã complete local. C4B/C4G schema đã apply
> exact Staging; dedicated secrets/Vault, active worker và live Gemini
> multi-user/RLS/single-flight/cleanup smoke đều verified. C4 COMPLETE;
> C5 personalized dual-language UI đã qua local, CPH2375 send/translate/cold
> restart và Web↔Android two-client personalized-order gate. C5 COMPLETE;
> C6A TTS và C6B owner-scoped local vocabulary lookup đã complete. C6C đã
> implement/verify với append-only proposal, sender-only accept/reject,
> trigger-owned audit và SQLite v4 outbox; exact-Staging backend cùng Android
> proposal path pass; Web raw sender accept UI và audit đã live verified.
> C6D source/SQLite v5/UI và exact-Staging backend đã verify; Web tạo tag thật,
> hai client nhận Realtime và Android cold restart khôi phục. C6 COMPLETE. Chat
> Flutter 149/149, full Flutter 600 pass + 1
> opt-in skip và analyzer toàn dự án sạch. T0–T5 chưa triển khai.
> C6E token picker đã two-client live verified: Web lưu row
> `ok`/`slang`/`được`; luồng đảo chiều Android raw sender nhận correction từ Web,
> chấp nhận và lưu `C6EANDROIDRAW0248` `[0,17)`/`slang`/`android c6e`. Remote
> actor/status/offset check và Android cold restart/PID-scoped fatal log đều pass;
> profile Web tạm đổi đã khôi phục `vi -> en`.
> Training OFF;
> Production untouched.**

> Earlier increment 2026-09-16: raw `flutter run -d chrome` was confirmed unsafe
> for Staging because missing defines fall back to Production `client.config`.
> Added guarded `web-device` runner, exact-Staging/Chat banner and responsive Auth
> test. Exact Staging dry-run remains up to date; final Web build and real Chrome
> login UI at `localhost:3000` pass. No schema, migration, remote row, Storage,
> Production, Gemini or Training write occurred. Demo login and two-client raw relay
> were later verified in the live smoke recorded immediately below.

> Latest live smoke 2026-09-16: user sent one raw message Web→Android and one
> Android→Web. Android received the Web message; read-only linked Staging table stats
> report estimates of 1 conversation/2 members/2 operational messages and 0 translations.
> Web stale-history root cause is fixed and verified: Web no longer pauses the chat
> runtime when hidden; initial/resume reconciliation starts immediately; Realtime
> connect no longer invalidates an in-flight pull; every UUID cursor explicitly orders
> ascending to match `gt`. Cold reload issued conversation/history HTTP 200 reads and
> the detail rendered both raw bubbles from its owner-scoped cache. The final C3 gates
> above now supersede the earlier partial state; C4/C5 translation UI remains
> unimplemented.

> Earlier live setup 2026-09-16: user explicitly confirmed primary `vi→en` and
> second test account `en→vi`. Exact Staging now has 2 verified C1 rows at beginner;
> Android Settings loaded `Tiếng Việt → Tiếng Anh`, picker showed one accepted peer,
> and `open_direct_chat` produced exactly 1 conversation/2 active members/0 messages.
> Gemini/Training/Production writes remained 0 at that checkpoint. Later live smokes
> above supersede all raw relay, offline/reconnect, account-switch, exact lost-ACK and
> membership-revocation gaps for C3.

> Previous increment 2026-09-16: user approved only the two named test accounts
> becoming accepted friends. Exact Staging pair has 2 accepted directions, verified
> with both owner JWTs. Friends tab now renders accepted IDs (14 widget tests pass);
> full regression 492 pass/1 existing skip/0 failure, analyzer clean (89 combined chat).
> Android network-status channel fixed and device UI shows exactly one accepted peer;
> both C1 profiles remain unchanged/unknown, so opening/sending a new chat stays blocked.

## Quy tắc bắt buộc cho các phiên sau

Mọi phiên làm việc có thay đổi liên quan database, schema, migration, local
file, Library repository, sync, consent, retention hoặc ML dataset phải:

1. Đọc file này trước khi lập kế hoạch hoặc sửa code.
2. Cập nhật file này trong cùng increment với thay đổi mã nguồn.
3. Thêm một entry có ngày vào phần **Change log**.
4. Ghi rõ `IMPLEMENTED`, `PARTIAL`, `PENDING` hoặc `BLOCKED`; không dùng từ
   “đã xong” nếu chưa có test hoặc runtime evidence.
5. Ghi chính xác command kiểm chứng và kết quả; không kế thừa kết quả test cũ
   cho code mới.
6. Nếu thay đổi quyết định D1–D10, phải ghi người/yêu cầu phê duyệt và ngày.
7. Không tuyên bố dữ liệu đã lên Supabase chỉ vì outbox đã được tạo.

## Trạng thái hiện tại

> Increment 2026-09-15 status: **IMPLEMENTED/ANDROID EMULATOR + WIDGET VERIFIED**
> — selected Photo Notes open in selection order on a dedicated vocabulary
> screen; each image independently expands/collapses its vocabulary. Creating
> an Album from selected Photo Notes now commits the Album and all initial
> memberships in one SQLite transaction. No schema, migration, media lifecycle,
> consent, cloud data, or sync contract changed in this increment.
>
> Follow-up 2026-09-15 status: **IMPLEMENTED/ANDROID 9 VERIFIED** — replaced
> SQLite UPSERT syntax that is unavailable on the Android 9 SQLite runtime with
> transaction-scoped insert/update logic. Album creation and adding Photo Notes
> now work on the device; the Album screen exposes the reference “Chọn Album”
> action in the header.
>
> UX follow-up 2026-09-15 status: **IMPLEMENTED/ANDROID 9 COLD-RESTART
> VERIFIED** — choosing an existing Album from the selected-photo sheet now
> commits the memberships immediately and opens that Album. Switching tabs can
> no longer discard an uncommitted intermediate selection.
>
> UX layout follow-up 2026-09-15 status: **IMPLEMENTED/WIDGET + ANALYZER VERIFIED** —
> chuyển `_AlbumSelectionButton` ("Chọn Album") từ `_LibraryHeader` xuống thanh toolbar
> `_AlbumToolbar` ngay cạnh `_CreateAlbumButton` ("+ Tạo Album"). Đồng bộ kích cỡ
> compact giống 2 button bên tab "Ảnh" (borderRadius 12, padding 8x5, fontSize 12,
> border 2, shadow 0x3), bảo đảm hiển thị vừa vặn và không tràn dòng trên màn hình 360px.
> Không đổi schema, migration, SQLite hay sync contract.
>
> Multi-Album vocabulary follow-up 2026-09-15 status:
> **IMPLEMENTED/ANDROID + WIDGET VERIFIED** — chế độ chọn Album có thêm CTA
> “Xem từ vựng”; ảnh của các Album được đọc từ repository local, gom theo thứ
> tự Album đang hiển thị và loại trùng theo `PhotoNote.id` trước khi mở màn từ
> vựng hiện có. Album rỗng/lỗi đọc dữ liệu báo ở phía trên và giữ nguyên lựa
> chọn để thử lại. Không đổi schema, migration, membership, media lifecycle,
> sync hay cloud contract.
>
> UI & Sticker styling follow-up 2026-09-16 status:
> **IMPLEMENTED/WIDGET + ANALYZER VERIFIED** — đồng bộ kích thước chuẩn
> `Size(120, 48)` cho các nút action trong chi tiết Album ("← Tất cả Album" và
> "+ Thêm ảnh") theo `_libraryToolbarButtonSize`. Thiết kế lại bottom sheet
> "Thêm ảnh vào Album" sang phong cách NeoBrutal EdTech với container nền kem,
> viền đen, hard shadow, drag handle dày, và các thẻ `_NeoActionCard` có hiệu ứng
> nhấn vật lý. Không đổi schema, migration, SQLite hay sync contract.

| Thành phần | Trạng thái | Sự thật hiện tại |
| --- | --- | --- |
| SQLite schema v3 | IMPLEMENTED | 22 bảng; thêm owner-scoped `library_pull_cursors`; native dùng `sqflite`, test/desktop dùng FFI, Web adapter dùng SQLite WASM/IndexedDB |
| Ảnh scan native | IMPLEMENTED/ANDROID VERIFIED | JPEG nén lưu app-private `capy_scans/`. Sau clean-install/rehydrate, explicit cloud restore đã tạo đúng 1 JPEG 116,892 byte; 4 cloud note còn lại vẫn metadata-only theo yêu cầu không tự tải |
| Scan JSON local | IMPLEMENTED/ANDROID VERIFIED | Lượt ảnh thật mới nhất có legacy `scan_results` và normalized `scan_runs` status `succeeded`, model `gemini-3.5-flash-lite`, tier `free` |
| Normalized Library aggregate | IMPLEMENTED/ANDROID REHYDRATE VERIFIED | Clean-install CPH2375 đã nhận 5 backed-up Photo Note cùng raw JSON/vocabulary vào SQLite v3 sau login + Cloud Backup ON; 2/7 bài local trước sự cố không có cloud copy để phục hồi |
| Atomic DB commit | IMPLEMENTED | Legacy row, queue link, aggregate và outbox dùng cùng một SQLite transaction; Album tạo từ Photo Note đã chọn và toàn bộ membership ban đầu cũng commit/rollback cùng transaction |
| Offline repository read | IMPLEMENTED/LOCAL VERIFIED | Repository và owner-scoped stream đọc lại PhotoNote aggregate sau khi đóng/mở SQLite; integration test đồng thời đọc đúng app-private media mà không gọi mạng |
| Offline app startup | IMPLEMENTED/ANDROID VERIFIED | Cache onboarding owner-scoped hydrate trước `runApp`; router redirect synchronous. APK mới cold-start data/Wi-Fi OFF vào Home 6,963 ms, mở Library/detail qua mốc retry >30 giây với 0 profile/RPC request, `Failed host lookup` hoặc stack trace; Android network gate + exponential backoff không chặn UI |
| Storage/Library UI | IMPLEMENTED/ALBUM WIDGET + ANDROID LIBRARY VERIFIED | Sub-tab Album dùng repository local hiện có; Library dùng graph-paper chung, header gọn không lặp points/notification/settings, lưới Album tự cân theo chiều rộng, tạo/yêu thích/xóa đơn hoặc hàng loạt có xác nhận, xem chi tiết, thêm/gỡ Photo Note và responsive 360px pass widget test. Summary đếm media owner-scoped còn được active/Trash giữ lại, stat file app-private thật và cộng `File.length()` thay vì remote `byte_size_display`. CPH2375 render đúng 5 bài, 1/5 ảnh trên máy/114.2 KB, 4 trên cloud; card/detail phân biệt local, cloud-only và missing. BlueStacks xác nhận caro chỉ thuộc body, vùng CTA/navigation dùng nền kem phẳng và card cuối nằm trọn trước CTA/navigation; cloud-only chỉ tải sau explicit CTA |
| Photo Note Trash + dung lượng | IMPLEMENTED/STAGING + ANDROID E2E VERIFIED | Library có dung lượng media theo account, Trash 30 ngày, Restore và explicit permanent delete. Android fixture pass full Restore/retrash/permanent-delete, đúng một local file bị xóa và restart bền; Staging row cùng fixture không còn |
| Media recovery | IMPLEMENTED/ANDROID VERIFIED | M4.2 compensation/audit và M4.3A recovery đã pass CPH2375. `capy_quarantine/` chỉ nhận orphan sau explicit confirm; retention 30 ngày, Restore/Xóa ngay, re-audit chống stale action và path confinement. Fixture UI pass full round-trip/delete; orphan lịch sử giữ nguyên |
| Gemini Edge scan | IMPLEMENTED/STAGING + ANDROID LIVE VERIFIED | `gemini-vision-scan` v1 ACTIVE trên linked Staging, Gemini secret tồn tại, unauthenticated request trả `401`; authenticated fixture smoke và ảnh thật từ Android đều gọi `gemini-3.5-flash-lite` thành công. Lượt device mới nhất render 5 detection |
| Supabase cloud contract | IMPLEMENTED/STAGING + PRODUCTION VERIFIED | M3A/M4.5, private bucket, normalized schema/change feed và owner RLS pass cả Staging lẫn Production; Production history 21/21/up-to-date |
| Supabase upload | IMPLEMENTED/STAGING + ANDROID + PRODUCTION FIXTURE E2E VERIFIED | Android Staging scan và Production isolated fixture đều upload private + normalized evidence/raw JSON thành công. Build thường vẫn không upload vì rollout flag mặc định tắt |
| Cloud restore/download | IMPLEMENTED/ANDROID E2E VERIFIED | Android synced Photo Note bị tạm thiếu local JPEG chỉ hiện CTA ở detail; 0 download trước tap. Explicit tap tải private media, tạo lại đúng 116,892 byte/SHA-256, bỏ CTA và offline cold restart vẫn mở ảnh + 4 từ. Cloud-only metadata nay có thể xuất hiện trên máy mới nhưng JPEG vẫn chỉ tải sau explicit tap |
| Cloud metadata pull | IMPLEMENTED/STAGING + ANDROID + PRODUCTION FIXTURE VERIFIED | Auth + consent + build-flag gated; owner cursor/atomic merge và no-auto-media-download pass. Production fixture pull sang SQLite thứ hai + delete feed pass |
| Remote staging workflow | C1/C2 STAGING BACKEND VERIFIED | Repo link Staging; history 23/23, post-C2 dry-run up to date. C2 backup/apply/REST + Realtime/cleanup pass 2026-09-15. Demo giữ nguyên; không gọi Production |
| Production rollout safety | GATE 0–3 VERIFIED | DPAPI backup, fingerprint, history repair, exact two-migration apply, full worker E2E, two-user RLS/Storage và cleanup pass. Repo không relink; client rollout bật sync chưa thực hiện |
| Sync outbox | IMPLEMENTED/STAGING + ANDROID E2E VERIFIED | Upload consent-gated đã pass. Explicit pre-consent backfill tạo graph atomic/idempotent chỉ cho active owner note đủ media; live Staging upload/pull/purge/cleanup pass. Privacy purge vẫn chạy đúng owner kể cả Cloud Backup OFF và giữ tombstone khi remote lỗi |
| Cloud-backup consent UI | IMPLEMENTED/ANDROID VERIFIED | Settings switch ghi audit `cloud_backup`; hai consent AI độc lập. Khi ON có action `Sao lưu bài đã có`, dialog riêng trước enqueue, bỏ qua missing/Trash và báo số queued. Android zero-candidate UX pass; không tự backfill khi chỉ bật switch |
| Web scan durability | IMPLEMENTED/PARTIAL BROWSER VERIFY | Web scan ghi JPEG vào media SQLite WASM/IndexedDB riêng và ghi JSON/aggregate vào SQLite Library; loader/purger Web đã nối. VM persistence contract, analyzer và Web build pass; guarded Chrome Staging runner/login UI đã chạy, nhưng scan → reload/cold-restart persistence chưa browser-smoke. Generated service worker tự unregister nên PWA app-shell cold-start offline chưa được triển khai |
| Chat language profile (C1) | COMPLETE — LOCAL UI + STAGING BACKEND VERIFIED | `vi`/`en` self-declared; onboarding + Settings + owner-scoped cache/repository đã nối. Đổi owner A→B không lộ cache; Staging migration/RLS/atomic RPC/legacy compatibility/server timestamp và two-account fixture cleanup pass. Account cũ không tự backfill; Production chưa apply C1; Training vẫn OFF |
| Operational Chat (C2) | IMPLEMENTED / LOCAL + STAGING REST/REALTIME VERIFIED | 47 SQL checks + 10 nhóm smoke ba account/real WebSockets pass; A/B raw trước translation, shared derived relay, outsider REST empty/0 events trong cửa sổ test; RLS/service-only/immutable/idempotent/inactive pass. Exact C2 applied, history 23/23; cleanup baseline preserved. C3 client complete trên Staging; Training chưa nối |
| Training dataset | PARTIAL/FAIL-CLOSED VERIFIED | Có schema lineage/consent; AI prediction không tự thành nhãn. Missing media quarantine example liên quan. Permanent purge xóa source example + manifest/run links và invalidates model đã dùng source; historical non-content audit có thể còn. Builder/D6 vẫn chưa triển khai |
| Operational Chat local (C3A + C4E) | IMPLEMENTED/VERIFIED; C3–C6 COMPLETE | Separate SQLite Chat hiện ở v6 với project+owner scope, raw/outbox, read cursor/unread, peer-profile, correction/annotation và translation cache tương thích v1/v2; migration giữ dữ liệu cũ. Durable restart/lost-response, physical multi-owner restoration và account isolation verified |
| Operational Chat adapter (C3B.1) | IMPLEMENTED/VERIFIED; C3 COMPLETE | Private SDK captured JWT, exact Staging only; insert/conflict/RPC, exhausted keyset pages, visibility checks and guarded Realtime lifecycle. Local HTTP/WebSocket tests plus live REST/Realtime smoke pass |
| Operational Chat runtime (C3B.2) | DEFAULT ON / EXACT-STAGING GUARDED | Single-flight/cache/runtime guards, foreground reconnect and explicit ascending UUID cursors verified. Source default is ON; exact-Staging URL and current-session guards still deny Production and stale owners |
| Operational Chat UI (C3C) | IMPLEMENTED/STAGING WEB + ANDROID VERIFIED; C3–C6 COMPLETE | Global 64dp draggable mailbox bubble with 5-second edge retreat, responsive panel, search, real cached profile, unread-first ordering/badges; `/chat` detail remains the conversation route and marks cached inbound rows read when opened. Bidirectional raw relay/offline behavior and C5 bilingual Web↔Android A/B rendering are live verified. Sent still means server accepted, not delivery receipt; no Training |
| Operational Chat Android (C3C smoke) | COMPLETE 2026-09-17 | CPH2375/Android 13 exchanged both directions with Web, restored remote/local history, survived offline restart/reconnect and restored A's isolated cache after A→B→A. Current-process chat/sync/Failed/Exception matches: 0 after reconnect |
| Chat translation contract (C4A) | DOCUMENTATION VERIFIED 2026-09-18 | Job creation, `vi↔en` target, policy versions/model, claim lease/token, retry/circuit/failure/logging rules, additive C4B schema delta and DB/worker/client/Staging test matrix are locked. No migration, worker, secret, Gemini call or remote write |
| Chat translation queue (C4B) | STAGING APPLIED / LOCAL SQL VERIFIED 2026-09-19 | Additive `chat_translations` lease/token/timestamps, recovery index, private circuit state, transaction-local enqueue and service-only claim/complete/fail RPCs. Native PostgreSQL 18 verified including two-connection `SKIP LOCKED`; Production unapplied |
| Chat translation worker (C4C) | IMPLEMENTED/LOCAL VERIFIED 2026-09-18 | Separate provider-neutral Edge source with internal trigger auth, Supabase RPC queue adapter, injected state machine, timeout/output validation and safe logs. C4C checkpoint Deno 28/28; C4D now supplies the adapter; no deploy/live provider call |
| Gemini Chat translation adapter (C4D) | IMPLEMENTED/LOCAL VERIFIED 2026-09-18 | Native one-request `generateContent` adapter with fixed model/prompt/version, server-only Chat key, policy/output validation, stable HTTP/Retry-After mapping into C4B circuit and fake HTTP coverage. Combined Deno 50/50; no deploy/secret/live call |
| Chat translation client cache (C4E) | IMPLEMENTED/LOCAL VERIFIED 2026-09-18 | Operational Chat SQLite v3 adds owner/project/version-scoped translation rows separate from raw, immutable-success/stale-state guards, paged RLS read and Realtime invalidation. Cache now 9/9 including late stale response; C5 UI is locally verified |
| Chat translation runtime reconcile (C4F) | IMPLEMENTED/LOCAL VERIFIED 2026-09-18 | Coordinator commits raw history before translation pull/merge, coalesces Realtime/reconnect and rejects stale session or revoked membership. Coordinator 26/26, Chat 115/115, full Flutter 561+1 skip; C4G Staging rollout now verified |
| Chat translation Staging rollout (C4G) | STAGING LIVE VERIFIED / C4 COMPLETE 2026-09-19 | Five approved migrations applied; dry-run up to date; Vault/pg_cron/pg_net verified. Dedicated Chat secrets and Vault entries configured, worker ACTIVE. Live Gemini three-account smoke verified single attempt/shared row/RLS/duplicate idle/cleanup; Production untouched |
| Personalized dual-language Chat UI (C5) | STAGING WEB↔ANDROID A/B LIVE VERIFIED / C5 COMPLETE 2026-09-19 | Existing mailbox/drag/composer UI preserved. Both Chat surfaces read owner-scoped translation cache, order raw/translation from viewer language, keep raw selectable and expose stable loading/retry/failure semantics. Additive Friends CTA opens the full route on CPH2375; raw→worker→translation, cold-cache restore and opposite personalized ordering on Web/Android pass. Chat 118/118, full Flutter 564 pass + 1 opt-in skip, analyzer clean and Web build pass |
| Friend management (F1–F6) | DEFAULT ON / EXACT-STAGING GUARDED 2026-09-25 | Friends and Chat source defaults are ON so eligible Staging accounts work without extra build flags. Exact-Staging URL, signed-in owner, accepted relationship and language-profile guards remain authoritative; Production is denied. Public search exposes exact username only; email/phone lookup stays dormant |
| Account contact verification (A0–A6) | EMAIL-ONLY LOCAL, SMS DORMANT / NOT DEPLOYED 2026-09-25 | Email confirmation remains the onboarding gate. SMS fields/actions, phone sharing and phone change are hidden behind one disabled feature flag; dormant code/data contracts remain. Subscription phone snapshots are optional and the server no longer requires a verified phone. Verification for this increment is recorded in the change log; no push, remote migration, Auth config change or deploy |
| On-device trainer | PENDING | Chưa có dataset builder, trainer, scheduler hoặc model activation runtime |

## Luồng runtime native hiện tại

```text
camera/gallery
  -> nén JPEG
  -> lưu file app-private capy_scans/
  -> gọi Gemini Edge Function
  -> giữ raw response trước client ranking
  -> một SQLite transaction:
       scan_results (compatibility)
       media_assets
       scan_runs
       vocab_detections
       photo_notes
       legacy_scan_import_queue = imported
       sync_operations (chỉ khi cloud_backup_enabled = true)
  -> notify Library stream sau khi commit
  -> nếu Vision/transaction lỗi: xóa bù đúng JPEG vừa tạo
  -> nếu build bật sync + user đã cloud consent:
       coordinator drain outbox theo dependency
       retry theo next_attempt_at hoặc app resume
```

Nếu transaction DB lỗi, toàn bộ row mới rollback và JPEG vừa tạo được cleanup
best-effort; lỗi cleanup không che lỗi scan gốc. Khi có authenticated session,
startup chạy audit nền account-global. Orphan chỉ chuyển sang quarantine sau
explicit user action; file đã cách ly được purge khi đủ 30 ngày. Missing media
không xóa Library aggregate nhưng fail-close training lineage liên quan.

## SQLite v3 — 22 bảng

### Account và consent

- `local_accounts`
- `consent_events`

### Scan và Library

- `scan_results`
- `media_assets`
- `scan_runs`
- `photo_notes`
- `vocab_detections`
- `vocab_annotations`
- `albums`
- `album_photo_notes`
- `legacy_scan_import_queue`

### Learning và model

- `learning_events`
- `srs_progress`
- `model_versions`
- `training_examples`
- `dataset_manifests`
- `dataset_manifest_examples`
- `training_runs`
- `training_run_examples`

### Sync và deletion

- `sync_operations`
- `sync_tombstones`
- `library_pull_cursors`

## Consent và dữ liệu AI

- Account mới mặc định fail-closed: `cloud_backup_enabled = false`,
  `local_personalization_enabled = false` và
  `federated_contribution_enabled = false`.
- Account đã tồn tại giữ nguyên consent; luồng scan không được ghi đè flag.
- Raw Gemini response là scan evidence, không phải nhãn đúng.
- AI predictions không được tự tạo `vocab_annotations` hoặc
  `training_examples`.
- Training milestone sau chỉ được chọn nhãn theo policy D6 đã được duyệt.

## Supabase — trạng thái upload và pull hiện tại

M3A cloud schema/private Storage đã có trên cả Staging và Production; M3B
worker và M3C runtime coordinator đã có trên native. Runtime chỉ được tạo khi
build với `--dart-define=LIBRARY_SYNC_ENABLED=true`; mặc định cờ là `false` để
rollout vẫn fail-closed. Worker/gateway đã pass E2E trên Staging và bằng fixture
cô lập trên Production. Android app đã pass
install/startup, background/resume lifecycle và authenticated consent-to-upload
E2E trên chính device:

- SQLite là nguồn phục vụ offline hiện tại.
- Outbox chỉ là yêu cầu chờ đồng bộ, không phải bằng chứng upload thành công.
- Absolute local path không bao giờ được đưa lên cloud.
- Không được tự upload ảnh/raw JSON khi `cloud_backup_enabled = false`.
- Auth, outbox change, consent change, retry timer và app resume có thể đánh
  thức worker; lỗi sync không chặn UI hoặc local read.
- Sau upload drain, worker pull metadata theo owner cursor. Batch còn tiếp tục
  tự nối trong cùng single-flight; Library list/detail vẫn chỉ đọc SQLite và
  không tự tải JPEG từ Storage.

Audit M3 ngày 2026-09-03 từng xác nhận contract trước M3A không được phép tái
sử dụng (đây là evidence lịch sử, không phải trạng thái remote hiện tại):

- Bucket `photo_notes` trong schema snapshot đang `public = true`.
- Storage SELECT policy hiện cho phép đọc mọi object trong bucket.
- INSERT policy chỉ kiểm tra role `authenticated`, chưa bắt object path bắt đầu
  bằng `auth.uid()`.
- `StorageService` cũ trả public URL và tạo key bằng timestamp; không dùng
  MediaAsset ID/idempotency key.

M3A đã thay contract bằng private bucket + owner-prefixed deterministic object
key và được apply Production ngày 2026-09-11 sau audit/backup. Production không
có legacy Library row/object cần backfill; audit 2026-09-12 tiếp tục xác nhận
bucket private và inventory complete.

## Decision log

| ID | Quyết định | Trạng thái |
| --- | --- | --- |
| D1 | Giữ họ `sqflite`: native + FFI + Web WASM/IndexedDB | APPROVED — 2026-09-02 |
| D2 | Giữ display/model-input khi note active; original chỉ opt-in/quota | APPROVED — 2026-09-03 |
| D3 | Cloud backup OFF mặc định; private; hỏi trước khi purge | APPROVED — 2026-09-03 |
| D4 | Web có local persistence cho Library; chưa bật cloud sync/restore hoặc on-device training trên Web | APPROVED — 2026-09-12 |
| D5 | Model cá nhân đầu tiên | PENDING |
| D6 | Loại nhãn đủ điều kiện training | PENDING |
| D7 | UX/save/navigation sau scan | PENDING |
| D8 | Federated learning scope | PENDING |
| D9 | Trash/quarantine 30 ngày; Restore hoặc purge ngay; purge local/cloud/ML và giữ receipt tối thiểu | APPROVED — 2026-09-08; purge detail approved 2026-09-09 |
| D10 | Local data khi logout/account delete | PENDING |

## Milestone status

| Milestone | Trạng thái | Kết quả |
| --- | --- | --- |
| M0 | DOCUMENTED | Kiến trúc offline-first, data ownership, privacy và decision log |
| M1 | IMPLEMENTED | Pure-Dart entities và 6 repository contracts |
| M2A | IMPLEMENTED/PARTIAL WEB RUNTIME VERIFY | SQLite v3 + media blob store; native/FFI persistence pass, Web build pass, Chrome runtime runner bị treo trước test |
| M2B | IMPLEMENTED | SQLite codecs và repository implementations |
| M2C | IMPLEMENTED | Native scan ghi trực tiếp legacy + normalized aggregate local |
| M3A | IMPLEMENTED/STAGING + PRODUCTION VERIFIED | Normalized schema/RLS/private bucket/change feed history 21/21; full fixture upload/pull/purge và two-user isolation pass Production |
| M3B | IMPLEMENTED/STAGING VERIFIED | Worker dependency graph/two-phase media pass local tests và live Staging với authenticated owner, file thật, raw JSON và cleanup |
| M3C | IMPLEMENTED/ANDROID E2E VERIFIED | Auth/lifecycle coordinator, SQLite retry timer và offline startup pass local regression; Android Staging sync-enabled launch/resume và authenticated outbox drain 8/8 operation pass |
| M3D | IMPLEMENTED/ANDROID E2E VERIFIED | Consent UI account-scoped + SQLite audit pass; device UI opt-in OFF→ON và scan/upload private sang Staging đã được đối chiếu local/remote |
| M4 đề xuất | IMPLEMENTED/STAGING + ANDROID VERIFIED | M4.1–M4.4 giữ nguyên evidence. M4.5 pass local contract, live Staging bằng hai SQLite độc lập và physical clean-install rehydrate → explicit 1-media restore → quiet offline cold restart; máy Android thứ hai thật vẫn là rollout coverage bổ sung |
| M5 đề xuất | PENDING | Dataset builder và on-device training theo consent |

## Verification gần nhất

Ngày 2026-09-11, Production Gate 3 execution sau explicit approval:

```text
pre-apply target guard + audit + db push --dry-run
  -> explicit Production ref, repo vẫn linked Staging
  -> backup manifest present; 0 rows/objects/legacy
  -> exactly M3A + M4.5 proposed

db push --project-ref <Production> --yes
  -> applied 20260903120000_add_library_cloud_storage_contract.sql
  -> applied 20260910120000_add_library_cloud_pull_feed.sql

post-apply migration list + dry-run + audit v2
  -> local/Production 21/21; upToDate=true
  -> media_assets present; bucket private; inventory complete

real SQLite store/worker/gateway E2E on Production
  -> private upload + normalized raw JSON/evidence pass
  -> pull to second SQLite with no automatic media download pass
  -> permanent purge/delete feed/fixture cleanup pass

two-user Production RLS/Storage smoke
  -> owner row/read/upload/download + signed URL 200
  -> cross-user media/note reads []
  -> cross-user row insert 403; Storage read/upload 400

final cleanup audit
  -> 0 photo_notes, 0 media objects, 0 legacy/unreferenced
  -> Auth fixture marker count 0; Production dry-run upToDate=true
```

Lượt cross-user đầu báo false failure vì PowerShell bọc decoded `[]` thành một
`$null`; raw JSON rerun pass. Audit harness được sửa cùng root cause bằng
`{Exists, Rows}`, Production empty-table và populated Staging regression đều
pass. Không có bằng chứng RLS leak. Default client sync flag vẫn OFF.

Ngày 2026-09-11, Production Gate 0–2 execution sau explicit approval:

```text
supabase db dump --project-ref <Production>
  -> Docker path fail-closed vì Docker engine không chạy; không tạo backup dở

PostgreSQL 18 pg_dump/pg_restore + Supabase temporary login
  -> public schema SQL + full public custom dump + pre-repair history
  -> Windows DPAPI CurrentUser encrypted outside repo
  -> 3/3 SHA-256 decrypt round-trip pass; pg_restore --list pass
  -> plaintext temp removed

psql catalog fingerprint
  -> all 15 baseline tables present
  -> subscription unique + AI ledger/function/final grants present
  -> 3 circuit-breaker functions present; M3A/M4.5 tables absent

pre-repair Production audit
  -> 0 photo_notes, 0 objects, inventory complete; no backfill required

migration repair --status reverted <4 remote aliases>
migration repair --status applied <baseline + 4 local canonical>
  -> both commands pass against explicit Production ref

post-repair migration list + db push --dry-run
  -> history matches local through 20260829152311
  -> only 20260903120000 and 20260910120000 local-only
  -> dry-run proposes exactly M3A + M4.5; no SQL applied

post-repair audit + linked Staging dry-run
  -> Production remains 0 rows/objects, bucket public, M3A absent
  -> repo still links Staging; Staging upToDate=true
```

Backup manifest:
`%LOCALAPPDATA%\CapyVocabApp\production_backups\20260911T105509Z\manifest.json`.
Khôi phục DPAPI yêu cầu cùng Windows user/profile context. Gate 3 Production
apply chưa được duyệt hoặc thực hiện.

Ngày 2026-09-11, Production Library rollout audit read-only:

```text
tool/audit_supabase_library_rollout.ps1 (Staging)
  -> 5 photo_notes normalized, 10 normalized Storage objects
  -> 0 legacy/missing/mismatch/unreferenced; bucket private; inventory complete

tool/audit_supabase_library_rollout.ps1 (Production)
  -> 0 photo_notes, 0 Storage objects; inventory complete
  -> bucket public, media_assets absent; không có legacy data cần backfill

npx supabase migration list --linked + db push --linked --dry-run
  -> Staging local/remote 21/21; upToDate=true

npx supabase migration list --project-ref vmxonxqxrlkssdzsucrg
  -> 14 shared, baseline local-only, 4 remote-only aliases,
     4 local canonical aliases + M3A + M4.5 local-only

npx supabase migration fetch --project-ref <Production> (OS temp only)
  -> semantic diff xác nhận 4 alias pairs cùng final SQL behavior
  -> temp directory đã xóa; remote history không đổi
```

PowerShell parser pass; targeted cloud migration/rollout contract test pass
8/8; `flutter analyze --no-pub` sạch. Không có Production
repair/apply/relink/row/object/policy mutation.

Ngày 2026-09-11, explicit pre-consent Library backfill verification:

```text
flutter test <consent provider + Settings UI + SQLite store>
  -> 35/35 pass

flutter analyze
  -> No issues found

flutter test test/features/settings test/features/library
  -> 123 pass + 1 opt-in live Staging skip, 0 fail

flutter test
  -> 351 pass + 1 opt-in live Staging skip, 0 fail

tool/run_staging_library_sync_e2e.ps1
  -> migration dry-run upToDate=true
  -> pre-consent save tạo 0 operation
  -> explicit backfill queue 1 aggregate/5 dependency operations
  -> worker thật upload private media + normalized JSON/evidence/note
  -> SQLite B pull pass; permanent purge + Auth/rows/Storage cleanup pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> migration dry-run upToDate=true
  -> sync-enabled APK build pass; final incremental Gradle 20.1s

adb install -r build/app/outputs/flutter-apk/app-debug.apk
  -> Success
  -> SQLite SHA-256 trước/sau final install: 4ed3cf60...d415f
  -> cả 3 JPEG giữ nguyên SHA-256: ea1145e8..., 27999b50..., a6664293...

Android CPH2375 Settings
  -> Cloud Backup checked=true
  -> action: Sao lưu bài đã có
  -> dialog nêu active/đủ media/skip missing + Trash/không train AI
  -> confirm: Không có bài cũ nào cần sao lưu.
```

Hai JPEG khác có mtime 16:53, trước `lastUpdateTime=17:14:21`; chúng không do
APK/action mới tạo. PID mới không có log download/restore hoặc runtime/network/
SQLite exception. Increment không đổi schema/migration và không ghi Production.

Ngày 2026-09-11, Library actual local-media usage UX verification:

```text
flutter analyze
  -> No issues found

flutter test --reporter compact test/features/library
  -> 105 pass + 1 opt-in live Staging skip, 0 fail

flutter test --reporter compact
  -> 346 pass + 1 opt-in live Staging skip, 0 fail

tool/run_staging_device_smoke.ps1 -Target android-build
  -> Staging migration dry-run upToDate=true
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

adb install -r build/app/outputs/flutter-apk/app-debug.apk
  -> Success
  -> SQLite SHA-256 trước/sau: 3c0f377f...64a4a
  -> JPEG SHA-256 trước/sau: a6664293...fe27da

Android CPH2375 UI hierarchy
  -> 5 bài trong thư viện
  -> 1/5 ảnh trên máy • 114.2 KB
  -> 4 trên cloud; 0 trong rác
  -> local card: Ảnh trên máy
  -> cloud-only cards: Ảnh trên cloud
  -> cloud detail: Tải ảnh từ cloud + thông báo chỉ tải khi người dùng chọn
  -> app_flutter/capy_scans vẫn đúng 1 JPEG, 116,892 byte
```

Regression test mới bao phủ local/cloud-only/missing, byte count lấy từ file
thật, detail notice và download chỉ sau explicit tap. Thay đổi không thêm
dependency, không đổi SQLite schema/migration, consent, cloud rows, ML lineage
hoặc Production.

Ngày 2026-09-11, physical Android smoke dừng do install xóa sandbox:

```text
flutter devices
  -> CPH2375 / 665fdb60 / Android 13 được nhận

flutter install -d 665fdb60 --use-application-binary=app-debug.apk
  -> output: "Uninstalling old version..." rồi install thành công

adb shell run-as com.capyvocab.app ls -la
  -> chỉ có cache và code_cache
adb shell run-as com.capyvocab.app ls -la databases
  -> No such file or directory
adb shell run-as com.capyvocab.app ls -la files
  -> No such file or directory

adb shell am start -W -n com.capyvocab.app/.MainActivity
  -> COLD launch Status=ok, TotalTime=7,909 ms, PID=7158
  -> Supabase init completed; 0 Flutter/AndroidRuntime error trong log lọc
  -> chờ chủ dự án tự nhập credential Staging
```

Sau khi được duyệt tiếp tục, chủ dự án đăng nhập thành công. ADB xác nhận
`capy_vocab.db` mới 282,624 byte; log có `Library media audit: 0 orphan, 0
missing`; UI Settings đọc `Sao lưu đám mây / Chỉ lưu trên thiết bị` với
`checked=false`. Vì consent local fail-closed, cloud pull chưa được kích hoạt.
Không clear thêm, không tạo scan và không được dùng live two-SQLite E2E để tuyên
bố dữ liệu app-private cũ đã phục hồi.

Chủ dự án sau đó bật Cloud Backup (`checked=true`). Sau 3 giây, Library hiển thị
5 cloud Photo Note, DB tăng lên 290,816 byte nhưng
`app_flutter/capy_scans` vẫn không tồn tại. Detail bài đầu hiển thị manual CTA
`Tải ảnh từ cloud`, 4 từ cùng nghĩa và log không có sync/SQLite/runtime error.
Summary đồng thời ghi sai `5 bài đã lưu trên thiết bị` và `707.0 KB ảnh local`;
đây là UX bug vì toàn bộ 5 JPEG vẫn cloud-only.

Người dùng sau đó explicit nhấn `Tải ảnh từ cloud` ở bài đầu. ADB xác nhận file
`cloud_cf9c36b2-d5d5-4c87-9872-5d2fc889a7c3.jpg` 116,892 byte, SHA-256
`a6664293feafded7a7ecc74d7d90713bd8c3d60ae0e4b7d02b9c680481fe27da`;
CTA biến mất và ảnh render. Cold restart offline đầu tiên mở được Home/Library/
detail nhưng log lộ hai RPC pull thất bại cách 30 giây, xác nhận coordinator chưa
gate network. Sau khi thêm Android validated-network gate và exponential
backoff, verification lại như sau:

```text
dart format <3 changed Dart files>
  -> 3 files formatted, clean

flutter test test/features/library/application/library_sync_coordinator_test.dart
  -> 9/9 pass; offline gate không drain/pull/report error, retry 1x→2x

flutter test test/features/library
  -> 104 pass + 1 opt-in live Staging skip, 0 fail

flutter test
  -> 345 pass + 1 opt-in live Staging skip, 0 fail

flutter analyze
  -> No issues found

tool/run_staging_device_smoke.ps1 -Target android-build
  -> Staging migration dry-run upToDate=true
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

adb install -r build/app/outputs/flutter-apk/app-debug.apk
  -> Success; SQLite/JPEG SHA-256 trước và sau cài giống hệt

Android CPH2375, Wi-Fi + mobile data OFF
  -> COLD launch Status=ok, TotalTime=6,963 ms, PID=18309
  -> Home → Library 5 bài → detail ảnh local + 4 từ
  -> giữ offline qua mốc retry >30 giây
  -> log: 0 Failed host lookup, 0 pull_library_delta/RPC, 0 stack trace/runtime error
  -> Wi-Fi + mobile data đã bật lại; Wi-Fi kết nối Tang 5
```

Thay đổi chỉ nằm ở coordinator/network gate Android và test/tài liệu; không đổi
SQLite schema, migration, consent, cloud data hoặc ML lineage. Production không
linked/apply/reset/ghi.

Ngày 2026-09-11, M4.5 cloud metadata pull local + Staging verification:

```text
dart format lib/features/library test/features/library
  -> 86 files, 0 thay đổi sau format cuối

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 344 pass + 1 opt-in Staging test skipped, 0 fail

tool/run_staging_library_sync_e2e.ps1
  -> migration preflight up to date
  -> live owner A upload aggregate + private JPEG
  -> independent SQLite B pull metadata/raw JSON/vocabulary, outbox=0, JPEG absent
  -> A remote purge; B nhận 1 delete receipt và local source purge
  -> Auth/row/Storage/library_change_events fixture cleanup pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> build/app/outputs/flutter-apk/app-debug.apk
  -> LIBRARY_SYNC_ENABLED=true, PASS
```

Migration `20260910120000_add_library_cloud_pull_feed.sql` đã apply đúng linked
Staging `nxteaznowkfennxpqjmt`; migration history local/remote khớp 21/21 và
post-apply dry-run `upToDate=true`. Production không linked/apply/reset/ghi.

Ngày 2026-09-10, M4.4 Android manual cloud media restore E2E:

```text
CPH2375 Android 13, synced Photo Note `bracelet, notebook, smartphone`
  -> Settings xác nhận Cloud Backup ON; Wi-Fi + mobile data online
  -> rời Library để dispose media provider, tạm đổi tên đúng JPEG app-private
  -> detail chỉ khi đó hiện `Ảnh đang có trên Cloud Backup` và CTA thủ công
  -> trước tap: original absent, backup present; không auto-download
  -> explicit tap tạo lại JPEG 116,892 byte; CTA biến mất, ảnh render lại
  -> SHA-256 downloaded file == SHA-256 pre-smoke backup; backup cleanup pass

Wi-Fi/mobile data OFF + force-stop/cold restart
  -> COLD TotalTime=5,315 ms; Library giữ 7 bài
  -> đúng restored detail có ảnh local + 4 từ, không còn CTA cloud
  -> 0 Failed host lookup/Socket/PostgREST/onboarding_completed/SQLite/FATAL
  -> startup audit chạy 1 lần sau khi file đã restore; không có missing window
  -> mobile_data=1 và Wi-Fi enabled được khôi phục; UI temp cleanup pass
```

Không restart/resume trong lúc file tạm thiếu, tránh để integrity audit thay đổi
training lineage của fixture. Nếu probe/download sai, workflow có rollback file
backup; thực tế hash match nên chỉ backup tạm bị xóa. Không thêm code/dependency/
schema, không ghi Production và không tự tải media ở startup/list/detail.

Ngày 2026-09-10, M4.3C Photo Note physical purge local verification:

```text
flutter test --no-pub <sync coordinator + worker + SQLite + media purger + UI>
  -> 37/37 pass
  -> gồm exact 30-day boundary, owner isolation, idempotency, shared-media
     retention, purge sau khi local rows đã mất và purge khi backup OFF

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 329 pass, 1 opt-in Staging test skipped, 0 failure

tool/run_staging_library_sync_e2e.ps1
  -> đúng linked Staging, migration dry-run upToDate=true
  -> fixture upload rồi local purge; Cloud Backup OFF vẫn remote purge pass
  -> 0 remote row/object còn lại; purge payload cleanup và receipt retained
  -> temporary Auth user cùng mọi fixture cleanup pass

tool/run_staging_device_smoke.ps1 -Target android-build
  -> đúng linked Staging, migration dry-run upToDate=true; không push
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

flutter devices --device-timeout 5
  -> lượt đầu chưa có Android; sau khi user cắm lại nhận CPH2375/665fdb60

adb install -r + data-off cold restart + UI hierarchy/log audit
  -> cài đè giữ data; online cold start 7,002 ms, offline cold start 4,858 ms
  -> offline vào Home, Library 8 bài/1.1 MB, detail có ảnh local + 3 từ
  -> Trash empty state đúng copy Restore trong 30 ngày
  -> background/resume giữ PID 330, HOT TotalTime=139 ms
  -> 0 Failed host lookup/Socket/PostgREST/onboarding_completed/SQLite/FATAL/
     deletion-maintenance error trong log PID
  -> capy_scans giữ 9 JPEG, quarantine rỗng, DB giữ 315,392 byte
  -> mobile_data được khôi phục 1; UI hierarchy tạm được xóa
```

M4.3C không thêm dependency hoặc database migration. Local purge không chờ
mạng; cloud failure giữ tombstone/outbox để retry trên startup/resume sau với
đúng authenticated owner. Remote-delete E2E đã pass trên Staging bằng fixture
tạm và cleanup. Android user fixture sau đó pass Restore → retrash → permanent
delete: local file 9→8, active note 8→7, Trash 1→0; restart giữ kết quả và remote
Photo Note title query trên đúng Staging trả raw empty array. Storage object của
device fixture chưa được định danh để query riêng; gateway Storage purge đã được
chứng minh bởi live Staging E2E biệt lập. Debug cold start vẫn có skipped-frame
log; cần profile/release benchmark trước khi kết luận hiệu năng. Production
không bị thao tác.

Ngày 2026-09-09, M4.4 explicit cloud media restore local verification:

```text
flutter test --no-pub <cloud restore service + app-private writer + UI>
  -> 14/14 pass
  -> 0 download trước user tap; owner/hash/size/path fail-closed;
     atomic write, no overwrite và UI explicit CTA pass

flutter test --no-pub
  -> 323 pass, 1 opt-in Staging test skipped, 0 failure

flutter analyze --no-pub
  -> No issues found

flutter build web --no-pub
  -> pass; giữ warning flutter_tts WASM/Cupertino font có sẵn

tool/run_staging_device_smoke.ps1 -Target android-build
  -> linked Staging ACTIVE_HEALTHY, migration dry-run upToDate=true
  -> không push; APK debug sync-enabled build pass
```

M4.4 không thêm dependency hoặc schema. Standard build giữ restore disabled qua
`LIBRARY_SYNC_ENABLED=false`; Web factory trả null. Chưa gọi/download Staging
trong verification này và Production không bị thao tác.

Ngày 2026-09-09, M4.3B Photo Note Trash + storage summary local verification:

```text
flutter test --no-pub <SQLite Library store + Storage/Trash widgets>
  -> 19/19 pass
  -> gồm owner-scoped active/Trash, move, restore, tombstone-hide,
     restore-after-permanent-request bị chặn và narrow-width overflow regression

flutter analyze --no-pub
  -> No issues found
```

M4.3B không thêm dependency, không đổi SQLite/Supabase schema và không gọi mạng.
Physical purge sau deadline/tombstone vẫn là phần bắt buộc trước khi đánh dấu
Photo Note Trash hoàn tất.

Ngày 2026-09-08, M4.3A recovery UX + ML fail-closed local/Android verification:

```text
flutter test --no-pub <media recovery service + native inventory + SQLite + UI>
  -> 23/23 pass
  -> gồm re-audit chống stale orphan action; path confinement; quarantine,
     Restore, explicit delete và 30-day purge; missing media giữ Library JSON/
     vocabulary nhưng quarantine training lineage và chặn training run

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 313 pass, 1 opt-in Staging test skipped, 0 failure
```

M4.3A không thêm dependency, không đổi SQLite/Supabase schema. Workflow Staging
chỉ chạy migration dry-run `upToDate=true`, không push/ghi remote; Production
không bị thao tác.

```text
flutter build web --no-pub
  -> pass; giữ hai warning có sẵn: flutter_tts WASM dry-run và Cupertino font

tool/run_staging_device_smoke.ps1 -Target android-build
  -> migration dry-run upToDate=true, migrations=[]; không push
  -> APK debug LIBRARY_SYNC_ENABLED=true build pass

CPH2375 Android 13 interaction smoke
  -> cài đè APK cuối giữ data; startup audit: 1 orphan, 0 missing, 0 purged
  -> Library render 5 bài + banner đúng 1 mục; bottom sheet không overflow
  -> fixture tạm làm audit 2 orphan; confirm quarantine move đúng sang
     capy_quarantine và UI hiện hạn 08/10/2026 + Restore/Xóa ngay
  -> Restore move fixture về capy_scans; cách ly lại + confirm delete chỉ xóa
     fixture; orphan lịch sử vẫn nguyên và capy_quarantine rỗng
  -> Wi-Fi/mobile data OFF cold start TotalTime=5,042 ms; Library vẫn 5 bài,
     banner 1 mục, audit 1/0/0; không có Failed host lookup/Socket/PostgREST/
     onboarding_completed/SQLite/FATAL trong bộ lọc PID
  -> giữ đúng 6 JPEG; mobile_data=1 và Wi-Fi Tang 5 đã bật lại
```

Ngày 2026-09-08, M4.2 media compensation + startup integrity audit:

```text
flutter test --no-pub <AI scan cleanup + media audit + SQLite targets>
  -> 29/29 pass
  -> gồm success giữ file, scan failure cleanup, cleanup failure không che lỗi
     gốc, native idempotent delete/path confinement, orphan/missing/dedup và
     account-global SQLite reference set

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub
  -> 306 pass, 1 opt-in Staging test skipped, 0 failure

tool/run_staging_device_smoke.ps1 -Target android-build
  -> đúng linked Staging; migration dry-run upToDate=true, không push
  -> APK debug với LIBRARY_SYNC_ENABLED=true build pass

adb devices -l
  -> CPH2375/665fdb60 Android 13 ở trạng thái device

adb install -r + PID-scoped log + app-private metadata
  -> cài đè giữ data; online cold launch PID 18621, TotalTime=7,726 ms
  -> startup audit báo 1 orphan, 0 missing; 6 JPEG và DB 299,008 byte giữ nguyên

controlled offline image selection
  -> Wi-Fi/mobile data OFF; trước scan có 6 JPEG
  -> khi dialog `Không thể quét ảnh` mở có 7 JPEG
  -> đóng dialog xong trở lại 6 JPEG; DB vẫn 299,008 byte/mốc cũ
  -> log có 0 cleanup failed, SQLiteException và FATAL

offline force-stop/cold-start
  -> PID 24631, TotalTime=6,162 ms; audit vẫn 1 orphan, 0 missing
  -> 6 JPEG giữ nguyên; session mở Home và có tab Library
  -> 0 media-audit failure, Failed host lookup, onboarding profile request,
     PostgREST/Socket/SQLite/media/FATAL trong bộ lọc PID
  -> Wi-Fi Tang 5 và mobile_data=1 đã được khôi phục sau smoke
```

M4.2 không thêm dependency, không đổi SQLite/Supabase schema, không xóa orphan
lịch sử và controlled failure không tạo DB/outbox nên không upload dữ liệu mới.
File orphan đã biết trên device vẫn được giữ cho đến khi D9 xác định
retention/quarantine và user action. Screenshot chẩn đoán tạm local/device đã
được xóa.

Ngày 2026-09-08, M4.1 synchronous onboarding routing + Android Staging smoke:

```text
flutter analyze
  -> No issues found

flutter test --reporter compact
  -> 298 pass, 1 opt-in Staging test skipped, 0 failure
  -> gồm cache unknown/multi-user/persistence, complete/reset/sign-in/sign-up,
     single-flight/backoff và Home -> Library -> detail = 0 profile request

tool/run_staging_device_smoke.ps1 -Target android-build
  -> đúng linked Staging ACTIVE_HEALTHY; migration dry-run upToDate=true
  -> APK debug sync-enabled build pass; temp dart-define credential được cleanup

adb install -r + airplane_mode=1 + Wi-Fi/data OFF + 3 cold restarts
  -> install giữ app data; cả ba cold launch giữ session và vào Home
  -> Home -> Library hiện đúng 5 bài; mở `bowl, blender, bottle`
  -> app-private image=true, vocab_count=4, offline-local copy=true
  -> lượt cuối source bàn giao TotalTime=6,693 ms trên debug APK;
     route/tab/detail không chờ
     profile request hay network timeout
  -> log đúng Capy PID: 0 `Failed host lookup`, `onboarding_completed`,
     `Failed to load onboarding`, PostgREST, Socket/TimeoutException,
     SQLiteException, media error hoặc FATAL
```

M4.1 không thêm dependency, không đổi SQLite/Supabase schema, không ghi dữ liệu
Staging/Production. Supabase/RLS vẫn là authority; cache chỉ quyết định UX route.
Hai dòng `ofbOpen/sysOpen` lúc process start được xác minh là Oplus vendor runtime
trước Flutter load, không phải file media/SQLite của ứng dụng.

Ngày 2026-09-08, M4 Android airplane-mode + cold-restart smoke trên CPH2375:

```text
adb devices -l
  -> 665fdb60 / CPH2375 / Android 13 API 33 ở trạng thái device

tool/run_staging_device_smoke.ps1 -Target android-device -DeviceId 665fdb60
  -> linked target guard pass; Staging ACTIVE_HEALTHY; migration dry-run
     upToDate=true; APK debug có LIBRARY_SYNC_ENABLED=true build thành công
  -> lượt cài đầu bị dừng vì USB mất kết nối; temp dart-define credential đã
     cleanup, sau đó adb install -r cùng APK pass và giữ nguyên app data

adb settings/cmd wifi + UI accessibility read-only
  -> airplane_mode=1, Wi-Fi disabled
  -> trước restart: detail app-private image + 4 từ hiển thị
  -> force-stop không xóa data; PID 32173 -> 3807 sau cold restart
  -> session giữ nguyên, Home mở được, Library còn đủ 5 bài
  -> mở lại `bowl, blender, bottle`: image=true, vocab_count=4,
     `bowl — cái tô` và `blender — máy xay sinh tố` đều hiện

PID-scoped log + run-as metadata read-only
  -> fatal=0, SQLiteException=0, media load error=0
  -> app-private capy_scans có 6 file; capy_vocab.db tồn tại, 299,008 byte
  -> 36 log occurrence `Failed to load onboarding status` do router tiếp tục
     lookup Supabase profile trên startup/navigation khi offline
```

Kết luận: yêu cầu xem ảnh và dữ liệu bài cũ sau mất mạng + kill/restart đã được
chứng minh trên Android thật. Residual router không làm mất dữ liệu hoặc crash,
nhưng phải được sửa để offline navigation không chờ remote và không spam retry.
Smoke không tạo scan mới, không sửa/xóa local data và không ghi Production.

Ngày 2026-09-06, M4 offline Library UI local verification:

```text
flutter test --no-pub test/features/library/data/local/library_media_loader_test.dart test/features/library/presentation/storage_album_screen_test.dart --reporter expanded
  -> 7/7 pass: safe relative-path media read, traversal/missing-file handling,
     list/empty/detail UI và vocabulary fallback khi ảnh thiếu

flutter test --no-pub test/features/library/presentation/storage_album_offline_integration_test.dart --reporter expanded
  -> 1/1 pass: ghi aggregate, đóng/mở SQLite, đọc lại note/detection và byte ảnh
     app-private mà không có network dependency

flutter test --no-pub test/features/settings/cloud_backup_consent_provider_test.dart test/features/settings/settings_screen_test.dart test/features/library/data/local/sqlite_library_store_test.dart --reporter compact
  -> 22/22 pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter compact
  -> 289 pass, 1 opt-in Staging test skipped, 0 failure

flutter build web --no-pub
  -> pass; chỉ còn cảnh báo dependency `flutter_tts` cho WASM dry-run và
     CupertinoIcons asset đã tồn tại trước increment
```

Đây là bằng chứng local tự động; chưa phải Android airplane-mode/restart smoke.
Web compile pass nhưng media loader Web hiện fail closed vì Web scan durability
vẫn pending. Increment không gọi Supabase và không thay đổi Staging/Production.

Ngày 2026-09-06, authenticated consent-to-upload trên Android Staging CPH2375:

```text
adb shell run-as com.capyvocab.app ...
  -> ảnh mới capy_scan_1788631639993447.jpg, 189,147 byte
  -> capy_vocab.db cập nhật cùng lượt scan; snapshot integrity_check=ok

SQLite snapshot read-only bằng Python sqlite3
  -> cloud_backup_enabled=true
  -> đúng 1 consent event cloud_backup OFF->ON, privacy-v1, applied
  -> scan mới succeeded bằng gemini-3.5-flash-lite/Free, có 5 detection
  -> MediaAsset và PhotoNote mới đều synced, remote display path đã ghi
  -> 8/8 operation done, mỗi operation attempt_count=1, không error/retry/block

Supabase CLI target guard + REST/Storage GET chỉ đọc
  -> linked target emtonny's Project ACTIVE_HEALTHY; organization có 2 active project
  -> đúng device ID: 1 media_assets, 1 scan_runs, 5 vocab_detections, 1 photo_notes
  -> private photo_notes object GET HTTP 200, image/jpeg, 189,147 byte
  -> object SHA-256 trùng content_hash_sha256 trong device SQLite
  -> bucket photo_notes public=false
```

Đây là bằng chứng upload thật từ UI/device, không chỉ là bằng chứng outbox local.
Truy vấn remote không tạo, sửa hoặc xóa row/object; Production không được chạm.

Ngày 2026-09-06, ảnh thật trên Android Staging CPH2375:

```text
adb devices -l
  -> CPH2375/665fdb60 ở trạng thái device

adb shell run-as com.capyvocab.app ...
  -> package debuggable; app-private baseline có 2 JPEG
  -> sau scan có JPEG thứ 3, file mới 133,353 byte lúc 00:57 local
  -> capy_vocab.db cập nhật lúc 00:58; app giữ cùng PID sau khi render kết quả

SQLite snapshot read-only bằng sqflite schema/Python sqlite3
  -> scan_results=2, media_assets=2, scan_runs=2, photo_notes=2
  -> vocab_detections=5 tổng; scan mới nhất có 3 detection
  -> latest legacy/media cùng trỏ file JPEG mới
  -> latest scan succeeded, tier free, model gemini-3.5-flash-lite
  -> latest PhotoNote local_only; cloud_backup_enabled=false
  -> sync_operations=0, consent_events=0
```

Có 3 JPEG nhưng chỉ 2 file được legacy/normalized DB tham chiếu. File cũ
`capy_scan_1788609600412190.jpg` là orphan từ trước lượt smoke này; chưa xóa vì
recovery/cleanup lịch sử còn chờ D9 và dữ liệu app-private của người dùng không
được tự ý xóa. Snapshot DB trên máy tính và script chẩn đoán tạm đã được xóa.

Ngày 2026-09-06, Gemini Edge Function trên linked Staging:

```text
deno test --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan
  -> 72 passed, 0 failed

supabase secrets set GEMINI_API_KEY=<in-memory> --project-ref <staging>
  -> secret set pass; key không được in hoặc ghi vào repository

supabase functions deploy gemini-vision-scan --project-ref <staging> --use-api
  -> deploy pass không cần Docker

supabase functions list --project-ref <staging> --output json
  -> gemini-vision-scan v1 ACTIVE, verify_jwt=false theo config

supabase secrets list --project-ref <staging> --output json
  -> GEMINI_API_KEY và các Supabase runtime secret names tồn tại

POST không có credential tới /functions/v1/gemini-vision-scan
  -> HTTP 401

Authenticated JPEG fixture smoke bằng demo user
  -> response contract pass; tier free; model gemini-3.5-flash-lite
  -> ledger status succeeded; fixture trả 0 từ
  -> session logout pass; JPEG tạm xóa; smoke ledger cleanup xác nhận còn 0 row
```

Giới hạn: đây là backend live smoke bằng golden fixture kỹ thuật, chưa phải ảnh
camera/gallery thật và chưa chứng minh UI device lưu normalized aggregate hoặc
drain outbox sau consent.

Ngày 2026-09-05, Android Staging smoke trên CPH2375 (Android 13/API 33):

```text
flutter doctor -v
  -> pass; Android toolchain/SDK 36.1/JDK 21 và device được nhận

tool/run_staging_device_smoke.ps1 -Target android-build
  -> linked Staging/migration preflight pass
  -> build/app/outputs/flutter-apk/app-debug.apk tạo thành công với sync flag bật
  -> rebuild sau auth fix pass; APK mới được `adb install -r` thành công

tool/run_staging_device_smoke.ps1 -Target android-device -DeviceId 665fdb60
  -> cài/launch package com.capyvocab.app thành công
  -> Supabase Staging initialize pass
  -> sau fix native redirect, hot restart không còn StateError
  -> HOME/resume giữ cùng PID 4974; log 120 dòng sau resume không có fatal/Flutter exception
  -> phiên Flutter kết thúc sạch và file dart-define tạm không còn tồn tại

adb install -r build/app/outputs/flutter-apk/app-debug.apk + launcher smoke
  -> install Success; process PID 14516 chạy từ APK rebuild
  -> Supabase init pass; không còn StateError trong log process

flutter test --no-pub test/features/auth/auth_repository_impl_test.dart test/features/auth/auth_screen_test.dart
  -> 6/6 pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter expanded --concurrency=4
  -> 281 tests pass, 1 opt-in Staging test skip theo thiết kế

CI=true dart format --output=none --set-exit-if-changed <2 auth files>
  -> 2 files formatted, 0 changed

git diff --check -- <tracked files thuộc increment>
  -> pass; chỉ có cảnh báo LF/CRLF của working tree
```

Giới hạn: device ở Auth screen, chưa có authenticated Staging session và consent
nên chưa tạo scan/outbox trên device; đây không phải bằng chứng upload từ UI.
Hai lần gọi test trong sandbox không có quyền ghi Flutter SDK cache/lock nên đã
được dừng; lượt chạy có đúng quyền hoàn tất trong 22 giây và là evidence ở trên.

Ngày 2026-09-04, sau M3C local verification (các lệnh Supabase bên dưới là
evidence M3A ngày 2026-09-03):

```text
flutter pub get
  -> pass

flutter analyze --no-pub
  -> No issues found

flutter test --no-pub --reporter compact
  -> 273/273 tests passed (sau M3C)
  -> một lượt trước đó báo 1 failure không giữ được tên do output song song bị
     cắt; hai lượt full suite kế tiếp đều pass 273/273, cần theo dõi flakiness

flutter build web --no-pub --dart-define=LIBRARY_SYNC_ENABLED=true
  -> pass
  -> còn cảnh báo không chặn từ flutter_tts Wasm dry-run và CupertinoIcons

Baseline/M3A migration contract test
  -> 4/4 pass

supabase db push --linked --dry-run (trước apply)
  -> pass; đúng 20 migration theo thứ tự

supabase db push --linked --yes
  -> pass trên Staging

supabase migration list --linked
  -> local/remote khớp 20/20

supabase db push --linked --dry-run (sau apply)
  -> upToDate=true

Staging two-user RLS/private Storage runtime
  -> pass; cleanup pass

tool/run_staging_library_sync_e2e.ps1
  -> pass 4 lượt trên linked Staging; migration preflight up to date
  -> 5/5 operation done; 2 private JPEG + 5 normalized entity groups verified
  -> owner download, raw JSON marker, SHA-256 ảnh/JSON và deterministic paths pass
  -> objects, rows và Auth test user cleanup assertions pass
  -> lần preflight đầu từ chối giả do PowerShell 5.1 nested JSON array; không có
     remote mutation, parser được sửa và giữ nguyên fail-closed checks

flutter test --no-pub --reporter compact (sau live harness)
  -> 273 pass, 1 opt-in Staging test skipped theo thiết kế

git diff --check -- <M2C scope>
  -> pass; chỉ có cảnh báo LF/CRLF của working tree
```

Coverage mới của M3A gồm deterministic owner/media object path, traversal và
extension boundary, signed URL TTL, normalized cloud tables, raw JSON, owner
foreign keys, private bucket policies, baseline ordering và runtime isolation.
Coverage M3B gồm dependency drain, transient/two-phase retry, restart recovery,
consent, auth resume và tombstone purge. Coverage M3C gồm consent/outbox trigger,
retry timer, logout cancellation, concurrent owner-switch isolation,
coordinator error recovery và offline startup contract. M2C regression vẫn
nằm trong full suite. Web build với cờ bật xác
nhận conditional factory không kéo native SQLite/file sync vào Web runtime.
Live Staging coverage dùng chính SQLite store, worker và Supabase gateway; không
gọi Gemini và không phải device lifecycle test.

Project-scoped Supabase CLI hiện hoạt động; PostgreSQL 18 `psql.exe` có trên máy
nhưng không nằm trong PATH. M3A đã parse/apply và pass RLS/Storage runtime test
với hai user trên Staging; Production chưa được apply.

### Remote staging không Docker

- Project-scoped Supabase CLI 2.116.0 hoạt động; tài khoản CLI đã đăng nhập.
- Management API xác nhận organization chứa hai project đang ở plan `free`.
- Project inactive `emtonny's Project` đã được restore và đạt
  `ACTIVE_HEALTHY`; cùng Production tạo thành đúng 2 project active trong giới
  hạn Free. Không tạo project thứ ba và không bật add-on/paid plan.
- Repository hiện link với `emtonny's Project` và coi đây là Staging;
  `CapyVocabApp` Production vẫn `ACTIVE_HEALTHY` nhưng không còn là linked
  target của CLI.
- Baseline schema gốc từ commit khởi tạo đã được khôi phục thành migration
  `20260725204011_initial_schema.sql`; không chứa row hay dữ liệu Production.
- Baseline + 19 migration kế tiếp đã apply thành công trên Staging. Migration
  history local/remote khớp 20/20 và dry-run sau apply trả `upToDate=true`.
- Staging có 21 bảng public thực tế: 20 bảng product/Library cùng bảng
  `gemini_model_health` được tạo bởi migration health.
- Runtime test với hai authenticated user xác nhận owner insert/read hoạt động,
  cross-user row read trả rỗng, cross-user insert bị `403`, cross-user Storage
  read/upload bị chặn, owner upload/signed URL hoạt động và bucket là private.
  Toàn bộ user/row/object test đã cleanup.
- Worker live E2E bổ sung xác nhận local outbox thật upload hai media variant,
  upsert media/scan/detection/annotation/Photo Note, giữ raw JSON, owner tải lại
  private object và cleanup toàn bộ artifact. Bốn lượt live đều pass.
- Production không bị apply migration, reset hoặc thay đổi dữ liệu trong bước
  thiết lập staging này.

## Việc tiếp theo an toàn

Sau Production Gate 3:

1. Quyết định rollout client Production: vẫn giữ sync OFF hoặc build/smoke có
   `LIBRARY_SYNC_ENABLED=true` bằng account test trước khi release. Không tự
   upload dữ liệu user hiện tại chỉ vì backend đã sẵn sàng.
2. Duyệt D10 và hoàn thiện account delete cùng multi-device conflict
   tests (live-test cleanup không thay thế product recovery).

## Tài liệu liên quan

- `docs/architecture/offline_ml_storage.md`
- `docs/data/library_data_contract.md`
- `docs/data/privacy_and_retention.md`
- `docs/data/m2a_sqlite_spike.md`
- `docs/data/m2b_sqlite_repository.md`
- `docs/data/m2c_native_scan_persistence.md`
- `docs/data/m3a_cloud_contract.md`
- `docs/data/m3b_outbox_sync_worker.md`
- `docs/data/m3c_runtime_sync.md`
- `docs/data/m4_cloud_metadata_pull.md`
- `PROJECT_STATUS.md`

## Change log

### 2026-10-06 — Home H5 final gate and Git preparation

- Chuẩn hóa tên test/runner và comment milestone về H5; không tạo milestone
  H6/H7 mới. SQL executable của migration đã apply không thay đổi.
- Exact Staging `nxteaznowkfennxpqjmt` được xác nhận healthy và migration
  dry-run sạch. Synthetic hai-account smoke pass đủ 9 nhóm, ghi 3 reward test
  và cleanup còn 0 fixture; Production không bị truy cập hoặc thay đổi.
- PostgreSQL 18 isolated pass 58/58; `flutter analyze` sạch; full Flutter pass
  763 + 1 skip; 65 file Dart trong change set đúng formatter; `git diff
  --check` sạch.
- Web release exact-Staging build pass. Android release exact-Staging build
  pass tại `build/app/outputs/flutter-apk/app-release.apk` (70,7 MB).
- Quét credential không thấy private key, Supabase personal token, GitHub PAT,
  JWT hay Google API key thật. Đã loại 23 ảnh/XML chẩn đoán trong `.tmp` khỏi
  worktree và thêm ignore cho `.tmp/` cùng `devtools_options.yaml`.
- ADB daemon chạy nhưng danh sách thiết bị trống, nên không cài lại APK trong
  final gate này. Bằng chứng physical smoke gần nhất vẫn là CPH2375 pass ngày
  04/10/2026. Chưa commit, push hoặc deploy Production.

### 2026-10-04 — Home H5A–H5D exact-Staging + Android verified

- Thêm settlement H5 theo receipt ordinal: lần đầu 100/130/150 hoặc mức muộn
  67/87/100; lần hai `floor(first/3)` chỉ vào ví; lượt ba 0; lượt bốn bị từ
  chối. Replay quá cửa sổ `next_day_ends_at` 24 giờ nhận 0.
- Thêm `yuzu_reward_ledger`, `lesson_streak_days`, wallet/streak update atomic,
  RLS owner-read và chặn client mutation. Trigger immutable chỉ chặn UPDATE để
  account deletion vẫn cascade đúng quy trình retention.
- SQLite nâng additive lên v8 với `rewarded_replay_sessions`; client tái sử dụng
  snapshot bài đầu, tạo outbox replay idempotent và ước tính Yuzu chờ bằng một
  phần ba. Home mở đúng replay từ node completed.
- Thêm H5C RPC leaderboard self + mutual accepted friends, chỉ tổng hợp
  `weekly_yuzu`; client validate owner, cache riêng theo account/week, fallback
  offline có timestamp và giải thích điểm tuần khác thưởng replay.
- PostgreSQL 18 isolated pass 58/58; analyzer sạch; full Flutter pass 763 + 1
  skip; Web release build pass. Backup exact Staging DPAPI 385.711 byte tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20261004T082658Z-adba54ec`.
- Apply đúng hai migration H5A/H5C; post-dry-run `upToDate=true`. Synthetic live
  smoke hai fixture accepted hai chiều xác nhận ví 133, tuần 100, streak 1,
  leaderboard hai phía cùng ordering/rank, idempotency/RLS/conflict và cleanup
  còn 0 fixture.
- Sửa race cold-start của Home: cache vẫn render tức thời nhưng profile stream
  lỗi tạm thời nay retry backoff 2/5/15/30 giây. Regression test xác nhận lần
  đầu lỗi và lần hai online tự thay cache; nhóm Home pass 49/49.
- APK release exact-Staging build pass tại
  `build/app/outputs/flutter-apk/app-release.apk` (70,7 MB), cài đè bằng
  `adb install -r` trên CPH2375 nên giữ nguyên session/dữ liệu. Cold-start online
  pass; cold-start offline hiện đúng cache/timestamp; bật lại mạng thì banner
  offline tự biến mất trên cùng PID. Wi-Fi/mobile data được khôi phục 1/1.
- Smoke thiết bị mở đúng Library (2 ảnh local), Shop, Friends, Camera sheet và
  Chat inbox (1 bạn); focus vẫn thuộc CapyVocab, không ghi nhận crash/Flutter/
  SQLite exception. Production không đổi.

### 2026-10-01 — Home H4 completion sync exact-Staging verified

- Library SQLite v6 bổ sung metadata vận hành sync cho completion result và
  migration v5→v6 additive. Daily completion cũ đủ điều kiện chuyển `pending`;
  review giữ `not_applicable`. Trigger chỉ khóa payload nghiệp vụ, cho worker
  cập nhật trạng thái/attempt/backoff/server accepted time.
- Thêm typed gateway, worker và lifecycle coordinator. Queue phục hồi row bị
  kẹt ở `syncing`, tự drain khi sign-in/resume/local change/reconnect, dùng
  backoff 5 giây–6 giờ và có manual retry cho `failed`. Account switch hủy stream
  cũ; evidence không gửi đường dẫn ảnh local hoặc đáp án thô.
- Home, lesson map và màn completion dùng trạng thái DB thật: `Chờ đồng bộ`,
  `Đã đồng bộ`, `Đồng bộ lỗi`. Yuzu dự kiến nằm riêng khỏi `total_coins`; H4
  không settlement thưởng, streak hoặc weekly leaderboard.
- Migration `20260930160000_add_lesson_completion_sync.sql` tạo
  `lesson_completion_receipts`, owner SELECT RLS và RPC security-definer. RPC
  kiểm tra daily mission + evidence 100%, trả cùng receipt cho retry giống hệt,
  từ chối changed payload và xử lý race insert đồng thời bằng unique constraint
  + `ON CONFLICT DO NOTHING`.
- Verification: PostgreSQL 18 isolated 35/35; SQLite schema/store 15/15;
  coordinator 3/3; Home + mini-game + SQLite 92/92; full Flutter 756 pass +
  1 skip; analyzer sạch; Android exact-Staging release APK build pass.
- Backup exact Staging `nxteaznowkfennxpqjmt` dạng custom archive 371.127 byte,
  `pg_restore --list` + DPAPI round-trip verified tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20261001T054525Z-2723e4d2`.
  Dry-run chỉ liệt kê migration H4; apply pass; post-dry-run `upToDate=true`.
- Synthetic Staging smoke tự tạo một account/mission, sync receipt hai lần,
  xác nhận một row/cùng `accepted_at`, conflict 23505, direct/anon rejection,
  Yuzu và streak không đổi; xóa auth fixture cascade còn 0 receipt. Production
  không linked/apply. Điện thoại chưa được cài bản H4 vì ADB đang không có device.

### 2026-09-30 — H3 marker visibility and photo rendering optimized

- Ảnh thiết bị xác nhận badge số bị ép theo kích thước bbox, khiến target nhỏ
  co/cắt marker xuống vài pixel. Badge được tách khỏi frame, giữ 36 dp, clamp
  trong biên ảnh và dùng nền vàng với viền/chữ đen; frame chuyển sang viền vàng
  có outline đen để giữ tương phản trên cả nền sáng và tối.
- Lesson graph-paper là surface sáng cố định nhưng từng kế thừa palette tối của
  thiết bị, làm AppBar/thẻ/chip số gần trắng trên nền sáng. `LessonSessionScreen`
  nay áp light theme cục bộ; regression chạy dưới outer dark theme xác nhận chữ
  câu hỏi vẫn có màu tối.
- `LessonPhotoView` giới hạn decode ảnh local theo kích thước render nhân device
  pixel ratio và thêm `RepaintBoundary`; không đổi file gốc, metadata, bbox,
  gameplay, SQLite schema hoặc sync contract.
- Regression mới bao phủ bbox rất nhỏ, kích thước/contrast badge và resized
  image provider. Toàn bộ mini-game pass 34/34; analyzer toàn dự án sạch.
- Manifest chỉ có Flutter activity và quyền mạng cần thiết, không có
  service/receiver/tool điều khiển màn hình. APK smoke trước là debug nên chưa
  dùng làm bằng chứng hiệu năng release; lần device UX tiếp theo phải cài bản
  release exact-Staging.
- Staging phát sinh sẵn hai migration remote `20260929143000` và
  `20260930130000`; đã fetch bản SQL về local, phục hồi nguyên trạng 33 migration
  tracked vốn sạch và xác nhận dry-run `upToDate=true`. Không push/apply remote.
- Runner exact-Staging nay nhận build mode có validation, mặc định vẫn `debug`.
  APK release SHA-256
  `950AF59CD0B27D59A0EF4C49BA443B652025AEA8D02F343B0D30F1826B055B03`
  được ký v2, cài đè giữ data và cold-start `3.943 s`. Package không debuggable,
  không có Dart VM service, giữ auth/Home cùng draft lesson; marker 1–4 và dark
  theme contrast pass trực quan. Process log có 0 crash/FlutterError.
- `gfxinfo` trả `0` frame cho Flutter/Impeller nên không được dùng làm bằng chứng
  hiệu năng. Credential/screenshot tạm đều đã xóa; ADB server đã tắt và hậu kiểm
  có `0` process `adb`. Không deploy hoặc push Git.

### 2026-09-29 — H3 exact-Staging Android smoke partial

- Xác định APK debug được cài ban đầu đã build thiếu dart-define nên dùng
  `assets/config/client.config` và trỏ sang project fallback, không phải linked
  Staging. Vì vậy Supabase trả `invalid_credentials`; UI ánh xạ mã này thành
  `Mật khẩu không đúng` dù credential Staging hợp lệ.
- Đối chiếu linked ref đúng Staging `nxteaznowkfennxpqjmt`. Migration fetch chỉ
  đồng bộ về local migration remote đã tồn tại
  `20260929132557_add_chat_album_image_shares.sql`; không apply remote trong
  lượt này. `supabase db push --linked --dry-run` hậu kiểm trả
  `upToDate=true`, không có migration chờ apply.
- Runner có guard đã build APK với credential exact-Staging, xóa file define
  tạm sau build và cài đè giữ app data lên CPH2375. SHA-256 APK là
  `30B1CF9C623655AB249FA115CACEC7DD9BD3915C9ECDDA037E651CAC38085B79`.
- Cold-start khôi phục session hợp lệ và mở Home. Online không còn cảnh báo;
  offline thật với Wi-Fi/mobile data tắt vẫn render cache và hiện cảnh báo;
  reconnect render Home online và bỏ cảnh báo. Trạng thái mạng được khôi phục
  chính xác từ `1/1` về `1/1`; log tiến trình không có Auth/PostgREST/Realtime
  hoặc crash error.
- Library tài khoản smoke chưa có Photo Note và nhiệm vụ ngày có `0/10` từ hợp
  lệ, nên không tạo dữ liệu ảnh thay người dùng và chưa tuyên bố device pass cho
  background/force-stop/current draft/queue. Bằng chứng tự động H3C/H3D vẫn là
  748 pass, 1 skip và analyzer sạch. Project fallback chỉ nhận một lần đăng nhập
  thất bại từ APK build sai; không có migration, deploy hoặc data write lên
  Production và không push Git.

### 2026-09-29 — Home H3C/H3D lesson runtime and Library review verified

- Source builder chỉ nhận Photo Note đúng owner, media local active, scan hợp
  lệ và target có bounding box; answer/path/kích thước/revision được đóng băng
  trong session snapshot.
- Controller phối hợp hai game qua một mastery queue, lưu câu hiện tại/draft,
  chặn stale submission, khôi phục pause và không mang draft của câu vừa nộp
  sang câu kế tiếp khi app background tại feedback.
- Lesson shell hỗ trợ Back/X/background pause, progress `X/Y`, feedback,
  completion và các trạng thái empty/error/blocked/abandoned/expired. Home mở
  daily session; Library cho người dùng chọn `Trộn cả hai`, `Ghép từ` hoặc
  `Điền chữ` để tạo review session mới không thưởng.
- Không đổi schema sau SQLite v5. Review dùng cùng ba bảng H3B, giữ
  `mission_date = null` và `reward_eligible = 0`; completion result vẫn chỉ tạo
  đúng một lần khi mastery đạt 100%.
- Full Flutter suite pass 748, skip 1; analyzer sạch; Web release và APK debug
  build thành công. Android device/emulator chưa kết nối nên device smoke
  online/offline/background/force-stop còn chờ. Không apply remote, deploy hay
  push Git.

### 2026-09-29 — Home H3A/H3B gameplay contract and local persistence verified

- H3A thêm domain thuần Dart cho hai game dùng ảnh, Unicode NFC + trim +
  lowercase normalizer, grader theo item ID, mastery queue và idempotent
  `attempt_id`; đúng được loại khỏi queue, sai quay lại cuối queue.
- Library SQLite nâng additive từ v4 lên v5. `lesson_sessions` giữ frozen
  snapshot/current question/draft/queue; `lesson_attempts` append-only;
  `lesson_completion_results` immutable và unique theo session.
- Lớp store luôn query theo `user_id`, commit attempt + progress + completion
  trong một transaction, phát hiện retry cùng ID khác payload, và trả lại kết
  quả đã commit khi retry sau mất ACK.
- Pause/đóng mở DB khôi phục current question, draft và queue. `Bỏ bài` giữ
  snapshot/progress/history nhưng chuyển `abandoned` và `reward_eligible=0`;
  session terminal không nhận attempt mới.
- Migration v4→v5 giữ account/daily mission. Domain pass 11/11; schema/store
  SQLite pass 12/12; targeted analyzer sạch.
- H3 chưa thêm outbox, Supabase table/migration, Yuzu/XP/streak/SRS/leaderboard
  write hoặc quảng cáo. Không apply Staging/Production, deploy hay push Git.

### 2026-09-28 — Home H2D Realtime gate fixed and H2 completed on Staging

- Thêm migration idempotent
  `20260928140000_enable_users_realtime.sql`: chỉ thêm `public.users` vào
  `supabase_realtime` khi publication tồn tại và table chưa được publish. Không
  đổi grant, RLS policy hoặc replica identity.
- Regression test chứng minh đỏ trước migration và xanh sau migration. Native
  PostgreSQL isolated gate tăng từ 22 lên 23 kiểm tra và pass 23/23.
- Backup pre-apply mới `VERIFIED`, 351,940 bytes, mã hóa Windows DPAPI. Exact
  Staging guard `ACTIVE_HEALTHY`; dry-run chỉ có migration `20260928140000`;
  apply thành công, hậu kiểm `upToDate=true`, publication count đúng 1,
  authenticated SELECT và RLS vẫn bật.
- CPH2375 online cold launch 5,554 ms: Home tải profile live và banner offline
  biến mất. Offline thật `wifi=0/mobile_data=0` cold launch 5,209 ms: banner
  cache xuất hiện đúng, mission `0/10` vẫn render, không crash. Sau restore
  mạng `1/1`, reconnect cold launch 5,362 ms và banner biến mất lại.
- Hậu kiểm giữ `mission_count=1`, `distinct_owner_day=1` và
  `users_publication_count=1`; không có Auth/PostgREST/Realtime/crash error.
  H2A–H2D được chốt hoàn thành trên Staging. Production không bị truy cập;
  không deploy Edge Function hoặc push Git.

### 2026-09-28 — Home H2A/H2B applied Staging; Android online/offline mission pass

- Pre-apply PostgreSQL 18 isolated gate pass 22/22. Exact-project guard xác nhận
  linked project duy nhất là Staging `nxteaznowkfennxpqjmt`, `ACTIVE_HEALTHY`;
  dry-run chỉ liệt kê hai migration H2A/H2B.
- Tạo backup `public/private` 341,957 bytes tại thư mục backup cục bộ của ứng
  dụng; archive và migration history được mã hóa Windows DPAPI, hash/restore
  list/round-trip đều `VERIFIED`.
- Apply `20260928120000_add_daily_mission_contract.sql` và
  `20260928130000_ensure_daily_mission.sql` thành công. Migration history
  local/remote khớp; dry-run hậu apply trả `upToDate=true`.
- APK được build bằng guarded Staging runner và cài đè giữ data lên CPH2375
  Android 13. Phiên `Demo 1` khôi phục; lỗi đăng nhập do APK trước trỏ Production
  không còn xuất hiện. Online RPC tạo 1 mission ngày 28/09 và 1 timezone; sau
  nhiều restart vẫn `mission_count=1`, `distinct_owner_day=1`.
- Offline smoke tắt thật Wi-Fi/mobile data từ `1/1` xuống `0/0`; cold launch
  5,500 ms, Home/mission cache `0/10` render và không có crash. Khối cleanup đã
  khôi phục mạng về `1/1`; reconnect cold launch 5,449 ms, RPC không tạo trùng.
- Online Home còn một gate lỗi độc lập: banner vẫn ghi `Đang offline` dù Android
  có `INTERNET/VALIDATED`. `authenticated` có SELECT, RLS policy owner đúng,
  nhưng `public.users` không nằm trong `supabase_realtime`; client Home dùng
  `.stream()`. Chưa tự ý thay đổi publication hoặc client.
- Remote writes được giới hạn ở hai migration đã duyệt, 1 daily mission và 1
  timezone setting do runtime tạo. Production không bị truy cập; không deploy
  Edge Function hoặc push Git. H2D/H2 chưa chốt do gate Home Realtime.

### 2026-09-28 — Home H2D automated/Web gate verified; Android device pending

- Sửa coordinator offline rollover: nếu `now` nằm trong đúng biên ngày kế tiếp
  đã cache, app dùng timezone và biên authoritative của account snapshot, không
  phụ thuộc timezone thiết bị hiện tại hoặc việc plugin timezone có tải được.
- Bổ sung regression test cho target đóng băng khi setting đổi giữa ngày,
  timezone tài khoản thắng sau khi thiết bị đổi vùng, rollover qua 00:00 khi
  timezone loader lỗi, runtime refresh khi resume và timer tới biên ngày cache.
- PostgreSQL 18 isolated pass 22/22, gồm hai thiết bị gửi timezone khác nhau vẫn
  nhận cùng immutable mission row; setting target/timezone chỉ áp dụng ngày sau
  và DST vẫn giữ đúng biên server.
- Home pass viewport 320 px với Android text scale 200% sau khi các header và
  legend được phép wrap. Targeted H2D/Home/Library pass 69/69; full Flutter pass
  712 + 1 live test opt-in skip; analyzer toàn repo sạch.
- Web release build và Chrome startup smoke pass; Android debug APK build pass.
  Chrome widget-test runner riêng bị treo trong môi trường hiện tại. Mobile
  audit tổng quát tạo false positive khi quét generated Web/Dart và diễn giải
  icon/font size thành touch target; widget tests cụ thể xác nhận control 48 px
  và font scale 200% không overflow.
- Không có Android device, emulator hoặc BlueStacks khả dụng, nên smoke test APK
  mới trên Android thật còn chờ. H2D/H2 chưa được đánh dấu hoàn tất cuối cùng.
- Không đổi schema/thêm migration trong H2D. Hai migration H2A/H2B vẫn pending;
  chưa apply, ghi remote data, deploy hoặc push.

### 2026-09-28 — Home H2C final UX implemented locally

- Thẻ nhiệm vụ Home hiển thị gọn `valid/target`, tiến độ, số còn thiếu, trạng
  thái, thưởng dự kiến và một CTA chính; lý do ảnh bị loại và trạng thái xử lý
  vẫn rõ ràng.
- Thêm điều hướng kỳ trước, kỳ sau và quay về hôm nay cho cả Tuần/Tháng. Dữ liệu
  kỳ đang xem và nhiệm vụ hôm nay dùng hai stream phản ứng riêng, nên thêm ảnh
  hôm nay vẫn cập nhật thẻ khi đang duyệt lịch sử mà không mở rộng query qua
  toàn bộ khoảng thời gian.
- `Chụp thêm` và `Chụp lại` đi tới Scan; `Chọn ảnh cùng ngày` đi tới Library với
  query `from/to` lấy từ biên UTC authoritative của mission. Library áp dụng
  khoảng nửa mở `[from, to)`, gồm đúng ảnh tại đầu khoảng và loại ảnh đúng tại
  cuối khoảng.
- Không đổi schema/version/local persistence/write path/outbox/Supabase sync và
  không thêm migration. Kiểm thử mục tiêu bao phủ vùng chạm 48 px, màn hình hẹp,
  điều hướng tuần/tháng, thẻ hôm nay realtime khi xem lịch sử và biên UTC của
  Library.
- Targeted H2C/Home/Library pass 43/43; analyzer toàn repo sạch; full Flutter
  pass 707 + 1 live test opt-in skip; Web release và Android debug APK build
  pass. Web vẫn báo cảnh báo WASM có sẵn từ `flutter_tts`, nhưng JavaScript
  release build thành công.
- Chưa apply hai migration H2A/H2B đang pending, chưa ghi remote data, deploy
  hoặc push. H2 còn H2D device/Web gate.

### 2026-09-28 — Home H2B implicit daily mission implemented locally

- Thêm `20260928130000_ensure_daily_mission.sql`: backfill và khóa ba biên UTC
  `starts_at/ends_at/next_day_ends_at`; private helper khóa setting owner và
  public authenticated RPC `ensure_daily_mission` dùng `INSERT ... ON CONFLICT
  DO NOTHING`. Timezone thiết bị chỉ được nhận cho account chưa có timezone;
  setting hiện có không bị thiết bị khác ghi đè.
- RPC tính ngày/biên theo PostgreSQL timezone catalog, nên DST không bị rút gọn
  thành offset cố định. Mission đã tạo giữ nguyên target/timezone; thay setting
  chỉ tác động lần ensure ngày sau. Authenticated vẫn không có quyền ghi trực
  tiếp bảng mission.
- Flutter thêm `flutter_timezone 3.0.1`, typed gateway, single-flight
  coordinator và runtime theo auth/open/resume/timer account-midnight. Runtime
  hủy timer khi đổi account/logout và Home chỉ quan sát snapshot đã publish,
  không tự tạo RPC theo mỗi rebuild.
- SQLite v4 giữ biên ngày và `local_only/synced`, bootstrap local account với
  consent fail-closed, hỗ trợ lookup theo instant/latest và cho snapshot server
  canonical thay bản offline xung đột. Offline dùng chính xác một biên kế tiếp
  đã cache; cần reconnect trước rollover DST-sensitive thứ hai.
- Home dùng target riêng của từng mission, biên server cho query Photo Note và
  chỉ báo device-timezone fallback khi chưa có snapshot. Owner mismatch từ RPC
  là lỗi toàn vẹn và không bị hạ thành fallback offline.
- PostgreSQL 18 isolated pass 21/21; targeted H2B/Home pass 27/27; full Flutter
  pass 702 + 1 opt-in live skip; analyzer sạch; Web release và Android debug
  APK build pass. Android build ban đầu bắt được JVM target 1.8/11 không khớp
  trong `flutter_timezone`; root Gradle giờ chỉ đồng bộ plugin này về JVM 11 và
  build lại thành công. Mobile audit script vẫn FAIL vì
  regex gắn kích thước icon/font hiện có thành touch target và đưa cảnh báo UI
  cũ ngoài scope; H2B không thêm control tương tác mới.
- Linked Staging dry-run trả `dryRun=true`, chỉ liệt kê H2A
  `20260928120000_add_daily_mission_contract.sql` và H2B
  `20260928130000_ensure_daily_mission.sql`. Chưa apply Staging/Production,
  chưa ghi remote data, deploy hoặc push.

### 2026-09-28 — Home H2A immutable daily contract implemented locally

- Thêm migration `20260928120000_add_daily_mission_contract.sql`: field
  `user_settings.time_zone` nullable cho rollout tài khoản cũ, validation IANA
  region dựa trên `pg_timezone_names`, và bảng `daily_missions` có primary key
  `(user_id, mission_date)`.
- Nhiệm vụ cloud đóng băng ngày, timezone, mục tiêu và thời điểm tạo bằng trigger
  chặn update. Authenticated chỉ có SELECT và RLS owner-only; quyền tạo idempotent
  sẽ đi qua API server-side của H2B, không mở direct insert cho client.
- Library SQLite nâng schema v3→v4, thêm `daily_missions` FK theo local account,
  primary key owner/ngày và trigger immutable. `SqliteDailyMissionCache` hỗ trợ
  put idempotent, get/list owner-scoped và fail khi snapshot cùng ngày xung đột.
- PostgreSQL 18 isolated fixture pass 11/11 gồm timezone hợp lệ/không hợp lệ,
  existing-account rollout, authenticated setting update, uniqueness,
  immutability, table privilege và cross-owner RLS. Không có remote write.
- Targeted H2A schema/cache pass 14/14; Home + Library local pass 68/68; full
  Flutter pass 690 + 1 opt-in live skip; analyzer toàn dự án sạch; format và
  diff whitespace sạch. Exact linked Staging dry-run trả `dryRun=true` và chỉ
  liệt kê `20260928120000_add_daily_mission_contract.sql` là pending.
- Chưa apply migration lên Staging/Production, chưa đổi cloud data, deploy hoặc
  push. H2B còn phải phát hiện/lưu timezone tài khoản, tạo/pull nhiệm vụ ngầm lúc
  00:00/lần mở và thay device-timezone fallback bằng snapshot đã lưu.

### 2026-09-27 — Home H2 local daily Photo Note map implemented

- Thay placeholder bản đồ bằng thẻ nhiệm vụ ngày và bản đồ responsive theo
  tuần/tháng; các node dùng Photo Note đúng khoảng ngày dựa trên thời điểm chụp.
- Thêm pure model cho sáu trạng thái node, mục tiêu/từ hợp lệ/còn thiếu, tiến
  trình, thưởng dự kiến và các lý do loại. Từ được chuẩn hóa, khử trùng trong
  ngày; annotation mới nhất được dùng và detection bị reject không được tính.
- Ảnh pending giữ trạng thái chưa đủ dữ liệu và hiển thị không phạt. Scan lỗi
  được ánh xạ sang ảnh mờ, sai ngôn ngữ hoặc không nhận diện khi error code có
  đủ thông tin; không tự tạo kết quả nhận diện giả.
- Mục tiêu đọc Supabase onboarding repository và có cache owner-scoped. Lỗi
  Supabase/cache không chặn map; fallback hiện là 10 từ.
- Sửa vòng tái tạo auto-dispose làm Home offline kẹt loading; regression provider
  chứng minh repository rỗng vẫn phát bản đồ ngay. Màu card/toggle được đặt rõ
  để không mất tương phản khi thiết bị bật dark-mode.
- Home tests pass 14/14; analyzer toàn dự án sạch; full JSON test reporter trả
  `success=true`. Hai lần full compact từng có một failure chập chờn không lặp
  lại khi chạy JSON và không tạo error event; không quy kết là pass ổn định tuyệt
  đối. Web Staging release và APK Staging build pass; Supabase dry-run sạch.
- APK cài đè trên CPH2375 Android 13 giữ dữ liệu. Offline Home hiển thị mục tiêu
  10, map tuần/tháng và action chụp ảnh; PID `20790` không có crash, Flutter
  error, RenderFlex hoặc overflow.
- Chưa có field múi giờ tài khoản và snapshot mục tiêu theo từng ngày. H2 dùng
  device timezone fallback có nhãn công khai và chưa được chốt COMPLETE. Chrome
  test runner H2 bị treo, đã dừng; chưa có Web live smoke. Không đổi database,
  migration, cloud data, outbox, sync, deploy hoặc Git remote.
- Tại thời điểm ghi nhận 27/09, quyết định tiếp theo đã được duyệt: account
  timezone dùng tên vùng IANA;
  nhiệm vụ ngày được tạo ngầm và đóng băng timezone + target; thay đổi Cài đặt
  chỉ áp dụng ngày sau; một user/ngày chỉ có một nhiệm vụ. Đây mới là kế hoạch
  H2A–H2D trong `home.md`; chưa có migration/RPC/local table mới và chưa apply.

### 2026-09-27 — Home H1 cache-first Yuzu shell implemented

- Thay Home placeholder bằng header Yuzu, Yuzu chờ đồng bộ, badge thông báo,
  lời chào, streak chỉ đọc và thẻ bảng xếp hạng bạn bè rút gọn responsive.
- Xóa scaffold `streakProvider` dành cho nút Thắp lửa; Home không còn hành động
  điểm danh hoặc cộng xu riêng. Streak hiện chỉ phản ánh trạng thái đã có.
- Nối profile Supabase Realtime để đọc `display_name`, legacy `total_coins` như
  số dư Yuzu và `streak_days`; notification badge dùng stream `notifications`
  hiện có. Không thêm dependency hoặc schema.
- Thêm snapshot SharedPreferences versioned, owner-scoped. Cache hợp lệ được
  hiển thị khi offline; cache hỏng/lỗi ghi không chặn profile online; số âm hoặc
  dữ liệu sai định dạng bị từ chối.
- Không dùng `study_points` làm Yuzu tuần vì `friend.md` xác nhận chưa có point
  ledger. Mini leaderboard giữ empty state trung thực và điều hướng sang Bạn bè;
  dữ liệu/xếp hạng thật vẫn thuộc H5C.
- Targeted Home/navigation pass 13/13; full Flutter pass 675 + 1 opt-in live
  skip; full analyzer sạch; Web release và Android debug APK build pass.
  Chrome widget runner riêng không trả kết quả và bị timeout sau 188 giây.
- Runner trực tiếp bị ngắt hai lần do CPH2375 rớt ADB trong lúc preflight. Build
  được tách khỏi bước cài; sau khi ADB online lại, `adb install -r -t` APK Staging
  thành công và giữ dữ liệu tài khoản. App foreground PID `3506`; ảnh màn hình
  xác nhận 100 Yuzu, Demo 1, streak chỉ đọc, leaderboard empty-state và thanh
  điều hướng đúng. PID-scoped log không có crash, Flutter error, RenderFlex hay
  overflow. H1 được chốt `HOÀN THÀNH`.
- Không apply migration, không ghi cloud data, không deploy và không push Git.

### 2026-09-27 — Supabase Web build and Android exact-Staging install

- Exact linked target vẫn là Staging `nxteaznowkfennxpqjmt`; migration dry-run
  trả `upToDate=true`, pending rỗng. Không apply migration, không deploy Edge
  Function và không gọi/ghi Production.
- Guarded Web runner mở Chrome tại `http://localhost:3000`; HTTP trả `200` và
  tiến trình Flutter Web tiếp tục chạy để test hai thiết bị. Đây là local device
  session, chưa phải public Hosting deployment.
- Production Web build kết nối đúng Supabase Staging đã tạo tại `build/web`;
  artifact chỉ chứa cấu hình backend Supabase với project ref Staging. Supabase
  Storage không được dùng làm Web host vì HTML bị phục vụ dạng plain text;
  public HTTPS URL cần một static host độc lập, còn backend vẫn là Supabase.
- Android exact-Staging debug APK build pass, kích thước `166414765` byte,
  SHA-256 `1EADF8CD5738150F7381BF3A4F9C865D33E13C942E9923E772771ECA15EAF3B5`.
  `adb install -r -t` lên CPH2375 `665fdb60` thành công, app foreground PID
  `31217`, startup fatal/Flutter/overflow markers `0`.
- Không push Git. Runner xóa file define tạm sau mỗi build. Phiên Web debug local
  đang chạy giữ riêng một file tạm và sẽ xóa khi phiên đó kết thúc.

### 2026-09-26 — Friends/Chat account bootstrap and final exact-Staging audit

- Root cause cho tài khoản mới thiếu action Chat: Operational Chat chỉ đọc hồ
  sơ ngôn ngữ owner-scoped trong cache, nhưng provider tải remote trước đây chỉ
  được khởi tạo khi mở Cài đặt. Runtime toàn cục nay watch
  `languageProfileProvider`, nên đăng nhập trên máy mới tự tải hồ sơ; Chat vẫn
  đọc cache/offline-first và không fetch theo từng màn hình.
- Thêm widget regression chứng minh hồ sơ signed-in được tải và ghi vào cache
  mà không cần mở Cài đặt. Friends + Chat pass **206/206**; focused runtime,
  correction, message-body và overlay pass **18/18**; analyzer toàn dự án sạch.
- F6 runner được đồng bộ với contract email-only: fixture không còn tạo/đòi
  Auth phone, onboarding gửi phone rỗng như client hiện tại, chỉ username được
  phép tìm kiếm; email/phone trả `invalid_search_method`. Exact-Staging F6 pass
  8 nhóm gồm Realtime request/accept/reject, chống giả mạo, canonical Chat và
  cleanup baseline; fixture còn 0.
- Chat smoke nay chịu được race hợp lệ giữa synthetic service row và worker
  đang hoạt động. Exact-Staging correction-only và annotation-only đều pass;
  full smoke pass với `translation_mode=active_worker`; Vilao E2E chuyên dụng
  cũng VERIFIED. Hai member nhận cùng row, outsider/anonymous bị chặn, raw và
  derived rows bất biến, correction audit/tag source-speaker đúng quyền; mọi
  fixture cleanup về baseline, Training writes 0.
- Không đổi schema/migration, không deploy function/app, không ghi Production,
  không push Git. Mobile audit heuristic vẫn nhận nhầm font/icon size là hit
  area; widget tests xác nhận các action chính 48dp và layout 320px/large text.

### 2026-09-25 — Email-only auth applied; Chat/tag final Staging gate verified

- Exact target guard xác nhận chỉ Staging `nxteaznowkfennxpqjmt` đang linked và
  `ACTIVE_HEALTHY`; Production `vmxonxqxrlkssdzsucrg` không linked. Backup
  `public/private` custom archive 305.090 byte được mã hóa DPAPI, kiểm tra
  `pg_restore` và round-trip tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260925T095312Z-bb62163a`.
- Lần apply đầu rollback toàn transaction vì Staging không còn overload
  onboarding bảy tham số. Migration được sửa để chỉ thu hồi quyền trên chữ ký
  legacy còn tồn tại; fixture regression nay mô phỏng đúng overload bị thiếu.
  PostgreSQL email-only 24/24 pass trước khi apply lại.
- Apply duy nhất `20260924120000_add_verified_account_contacts.sql` thành công;
  migration history local/remote khớp và post-apply dry-run `upToDate=true` với
  danh sách pending rỗng. Ba tài khoản email-confirmed không có Auth phone vẫn
  hoàn tất onboarding trong live Chat smoke, xác nhận SMS không phải điều kiện.
- Live C6D smoke pass 10 nhóm: friendship/canonical direct chat, ba WebSocket
  thật trên sáu bảng, raw Unicode A/B, correction audit, raw-sender-only Unicode
  annotation, immutable row, outsider/anonymous denial, moderation/membership
  fail-closed và cleanup về baseline. Fixture còn 0; Gemini 0; Training write 0.
- Read-only Demo 1/2 audit sau apply: 2/2 login, accepted friendship đối xứng,
  2 language profile, một shared conversation, remote writes 0. Chat Flutter
  149/149; focused correction/annotation 74/74; SQL C6C 24/24, C6D 17/17,
  C2 47/47; analyzer sạch.
- APK exact-Staging build pass tại
  `build/app/outputs/flutter-apk/app-debug.apk` (166.414.765 byte), SHA-256
  `6B44A86E055430FE63215665F1BB54E8E93210F6FE9FFA1EECFFD72A97395901`.
  Production không đổi; không push Git.

### 2026-09-25 — Friends and Chat enabled by default for eligible Staging accounts

- `FRIENDS_ENABLED` and `CHAT_RELAY_ENABLED` now default to true in source; the
  Staging Web runner also defaults Chat on while retaining its old switch for
  command compatibility.
- Enabling the flags does not broaden the backend boundary: Friends and Chat
  owners still resolve only for exact Staging with a current signed-in session;
  Chat revalidates accepted friendship and language profiles. The existing
  Production-denial regression remains green.
- Verification: Friends + Chat Flutter 205/205, full Flutter 667 pass + 1
  intentional live skip, isolated Friend PostgreSQL 68/68 with two concurrent
  clients, full analyzer clean and exact-Staging Web build passed. Read-only
  Demo 1/2 audit confirmed both logins, reciprocal accepted friendship and one
  shared conversation; remote writes 0.
- Machine setup and the flag-free Staging Web command are documented in
  `README.md`. Migration `20260924120000` remains dry-run pending; nothing was
  applied, pushed or deployed.

### 2026-09-25 — Email-only auth rollout; SMS retained but dormant

- Product decision: email ownership is confirmed through the message sent to
  that email. A phone number and SMS OTP are not required to confirm email.
- One disabled feature flag hides phone/SMS onboarding, phone change, phone
  sharing and friend phone rendering. The OTP/change-phone implementation is
  retained for a separately approved future rollout.
- The onboarding server gate now requires only a confirmed Auth email. Existing
  `complete_onboarding` overloads remain compatible but ignore the dormant
  phone argument. Subscription snapshots require confirmed email and allow a
  null phone, so email-only accounts are not blocked.
- Documentation and deferred SMS rules remain in `auth.md`. No remote write,
  push, deploy, live email or live SMS is part of this increment.
- Local verification: Auth/Onboarding/Friends/Settings 133/133, isolated
  PostgreSQL 24/24, full analyzer clean and Web release build passed. Existing
  `flutter_tts` Wasm and missing Cupertino font warnings remain non-blocking for
  the generated JS build. Remote writes: 0.

### 2026-09-24 — Account contact verification plan approved (PENDING)

- Chốt email phải xác nhận; đổi email chỉ có hiệu lực sau xác nhận email mới và
  thông báo email cũ. Chốt SMS thật cho số điện thoại quốc tế; đổi số chỉ có hiệu
  lực sau mã đúng. Username vẫn là cách duy nhất để tìm bạn.
- Hai công tắc hiển thị email/SĐT mặc định tắt. Khi bật, chỉ bạn bè đã chấp nhận
  được đọc; người lạ/lời mời chờ không được đọc và liên hệ không vào cache Friends.
- Gói đang còn hạn không đổi khi thay liên hệ; lần gia hạn dùng liên hệ mới đã
  xác nhận. Đổi liên hệ không cấp lại ưu đãi; cần thêm lịch sử liên hệ/ưu đãi vì
  bảng subscription hiện tại chưa giải quyết trường hợp này.
- Kế hoạch A0–A6 nằm tại `auth.md`. Trạng thái tại thời điểm chốt chỉ là
  `APPROVED / PENDING IMPLEMENTATION`: chưa tạo migration, chưa bật SMS, chưa
  ghi Staging/Production và chưa deploy.

### 2026-09-24 — Account contact verification A1–A5 local implementation

- Thêm migration `20260924120000_add_verified_account_contacts.sql`: chuyển số
  Việt Nam hợp lệ sang E.164, dữ liệu liên hệ/lịch sử/sổ ưu đãi private, RPC
  đồng bộ từ Auth, hai cờ hiển thị, đọc liên hệ cho bạn bè đã chấp nhận, snapshot
  liên hệ gói và cổng onboarding bắt buộc email/SĐT đã xác nhận.
- Flutter thêm gửi lại email xác nhận, OTP số quốc tế trong onboarding, đổi
  email/SĐT (đổi SĐT bắt buộc mật khẩu hiện tại + OTP), hai công tắc cài đặt và
  hộp thoại liên hệ chỉ tải khi người dùng mở. Tìm bạn ở máy chủ chỉ chấp nhận
  exact username.
- Verification local: `flutter analyze` sạch; Auth/Onboarding/Friends/Settings
  **129/129**; Web release build pass; PostgreSQL tạm với dữ liệu giả **23/23**,
  remote writes **0**. Web build còn cảnh báo Wasm từ `flutter_tts` và thiếu font
  Cupertino; không làm hỏng build JS hiện tại.
- Chưa push/deploy/apply remote, chưa đổi Auth config, chưa gửi email/SMS thật.
  A0/A6, country picker, chính sách giữ lịch sử và nối luồng phát ưu đãi còn chờ
  chủ dự án/phê duyệt riêng. Chi tiết phân công nằm trong `auth.md`.

### 2026-09-24 — Friends username-first product rollout (LOCAL VERIFIED)

- Sheet Thêm bạn chỉ hiển thị exact username; đã gỡ method selector cho email và
  phone. Settings không còn render contact discovery hoặc phone OTP.
- Giữ nguyên enum/repository/RPC/RLS/migration email/phone để tương thích với
  exact Staging và dữ liệu đã apply. Không có schema, migration, remote write,
  Production hoặc Training change. Tại thời điểm increment này Twilio không chặn
  Friends username-first; quyết định tài khoản mới phía trên đã thay thế kết luận
  đó và yêu cầu SMS quốc tế trước rollout xác nhận tài khoản.
- Widget regression trực tiếp pass **24/24**; toàn bộ Friends + Settings pass
  **69/69**; full Flutter pass **657 + 1 opt-in skip**; analyzer sạch và Web
  build với Friends + Chat bật pass. Mobile audit script báo false positive vì
  coi font/icon/padding nhỏ là touch target; test 320 px, text scale 1.3 và CTA
  48–50 dp vẫn pass.

### 2026-09-24 — Friends F6 exact-Staging live rerun (VERIFIED)

- Preflight xác nhận exact project `nxteaznowkfennxpqjmt` linked duy nhất,
  `ACTIVE_HEALTHY`; migration dry-run trước và sau đều `upToDate=true`.
- F6 live pass tám nhóm: ba verified synthetic account, username/email/phone
  normalization + consent + public-only projection, ba WebSocket thật,
  self/forged/outsider denial, idempotent request, accepted list đối xứng,
  canonical Chat, reject path và exact-scope cleanup.
- Kết quả cuối: `fixture_count_remaining=0`; Production/Training/Library đều
  `0 writes`. Không deploy hoặc push Git trong lần xác minh này.

### 2026-09-24 — Friends phone OTP exact-Staging synthetic smoke (VERIFIED)

- Bật tạm Phone provider trên exact Staging để tái hiện luồng Settings. Client
  đọc đúng số private đã lưu; Auth trả HTTP 500 khi cập nhật phone. Kiểm tra cấu
  hình xác nhận provider là Twilio nhưng thiếu Account SID, Auth Token và Message
  Service SID. Vì vậy chưa có bằng chứng gửi SMS thật; lỗi không nằm ở RPC Friends.
- Chạy smoke bằng tài khoản fixture có `test_scope=friends_phone_otp_smoke` và test
  OTP chính thức: request phone-change trả 200, verify `phone_change` trả 200,
  `phone_confirmed_at` có giá trị, `sync_my_verified_friend_phone()` thành công và
  `get_my_friend_discovery_settings()` trả `phone_verified=true`.
- Cleanup đã xác minh: xóa fixture, tắt `external_phone_enabled`, xóa test OTP,
  đóng Web staging/cổng 3000 và xóa tệp `dart-define` tạm. Backup cấu hình nằm tại
  `C:\Users\ASUS\AppData\Local\CapyVocabApp\staging_backups\20260923T195806Z-friends-phone-otp-smoke`.
  Production không bị đọc/ghi hoặc thay đổi cấu hình.

### 2026-09-23 — Friends client completion and phone OTP (LOCAL/STAGING BUILD VERIFIED)

- Hoàn thiện hai scaffold Friends còn sót: `AddFriendModal` nối sheet thật và
  `FriendListItem` render public profile/Chat action 48dp; accepted list dùng
  widget chung. Màn `/friends` giữ Chat CTA cũ, đổi nhãn thành `Bạn bè`, bỏ nội
  dung leaderboard/“Đang phát triển” chưa có contract dữ liệu.
- Thêm gateway Supabase Auth phone-change OTP, dialog Settings và provider
  owner-scoped. Chỉ số private của chính owner được đọc, chuẩn hóa và giữ trong
  RAM; UI chỉ render bản che. Mã OTP đúng sáu chữ số, request/verify single-flight,
  lỗi không lộ provider detail; account switch fail closed. Chỉ sau Auth success
  mới gọi `sync_my_verified_friend_phone()`.
- `FRIENDS_ENABLED` vẫn mặc định `false`. Hai runner exact Staging thêm
  `FRIENDS_ENABLED=true`; owner guard tiếp tục khóa host
  `nxteaznowkfennxpqjmt.supabase.co`. Không đọc dữ liệu, ghi hoặc apply
  Production.
- Verification: Friends + Settings + màn Chat liên quan **86/86**; full Flutter
  **658 pass + 1 opt-in skip**; analyzer toàn dự án sạch. Exact-Staging dry-run
  `upToDate=true`; Web build với Friends + Chat bật pass. Temp define được xóa
  bởi `finally`; không migration/apply/data write trong increment này.
- Auth settings read-only: SMS provider configured, Phone provider vẫn tắt
  (`external_phone=false`). Live OTP smoke chưa chạy và cần phê duyệt riêng vì
  bật provider thay đổi Auth surface/có thể phát sinh SMS.

### 2026-09-23 — Friends F6 exact-Staging E2E (VERIFIED)

- Tạo hai backup DPAPI ngoài repo trước các lần apply; exact project guard khóa
  Staging `nxteaznowkfennxpqjmt`, Production không được relink hoặc truy cập.
- Apply `20260922120000_add_friend_management_contract.sql`, bổ sung publication
  `public.friends` idempotent cho Realtime. Live test phát hiện Supabase Auth lưu
  số E.164 Việt Nam dạng `84…`; thêm migration
  `20260923120000_accept_supabase_auth_phone_format.sql`. Contract vẫn yêu cầu
  `phone_confirmed_at` và exact match sau chuẩn hóa. History có mỗi migration
  đúng một lần; post-apply dry-run `upToDate=true`.
- `tool/run_staging_friend_f6_e2e.ps1` tạo ba account synthetic A/B/C, kiểm tra
  username/email/phone opt-in và opt-out, public-only response, idempotent send,
  incoming/outgoing, forged/self denial, accept hai chiều, reject, Chat trước/sau
  accept và ba WebSocket thật. C không đọc/nhận sự kiện quan hệ A–B.
- Cleanup chỉ xóa account khớp chính xác `test_scope + run_id`; Auth/profile,
  Friends và Chat trở về baseline, fixture còn lại 0. Production, Training và
  Library writes = 0; không gọi AI.
- Verification cuối: PostgreSQL 18 Friends **68/68** với fixture Auth `84…` và
  hai client concurrent; Friends + Settings **65/65**; full Flutter **653 pass +
  1 opt-in skip**; analyzer toàn dự án sạch. `FRIENDS_ENABLED` vẫn mặc định tắt
  để rollout được quyết định riêng; user-facing phone OTP/link flow vẫn chưa có.

### 2026-09-23 — Friends F5 accepted list and Chat handoff (LOCAL VERIFIED)

- Thêm accepted-list provider owner-scoped: hydrate SQLite cache trước, refresh
  nền, single-flight, Realtime invalidation, offline/error giữ cache. F2
  repository tiếp tục keyset cho tới trang rỗng rồi mới commit snapshot; không
  thêm API, schema hay kiểu dữ liệu contact.
- Tab `Bạn bè` sau `FRIENDS_ENABLED` render public profile, lazy list, pull to
  refresh và action Chat 48 dp. Thiếu hồ sơ ngôn ngữ của owner khóa action và có
  đường dẫn Cài đặt; email/phone không được đọc, cache hoặc render.
- Trước Chat RPC, provider kiểm tra mạng, refresh/read lại accepted cache và chặn
  peer đã inactive/rejected. Sau đó gọi `openDirectChat(peerId)` hiện có; chỉ UUID
  canonical server trả về được dùng cho `/chat/:conversationId`. RPC server vẫn
  authoritative cho mutual acceptance và language profiles của cả hai.
- Session fence kiểm tra Friends owner + Chat owner quanh coordinator await;
  account switch lúc RPC đang chờ không điều hướng hoặc render owner cũ.
- Verification: F5 notifier/widget **10/10**, Friends **50/50**, Friends +
  Settings **65/65**, full Flutter **653 pass + 1 opt-in Staging skip**, analyzer
  sạch và Web build pass. Widget test trực tiếp xác nhận 320 px, text scale 1.3,
  public-only semantics và Chat action 48 dp. Mobile-audit regex fail do coi
  icon/font/padding/gap là touch target; đây là false positive đã được widget
  measurement phản chứng.
- Không đổi `capy_friends.db` v1, Library/Chat DB, migration hoặc remote contract;
  không apply/deploy/gọi/ghi Staging/Production. Cờ Friends vẫn mặc định tắt;
  live two-user/outsider/canonical Chat evidence thuộc F6.

### 2026-09-22 — Friends F4 request inbox and response UX (LOCAL VERIFIED)

- Thêm provider owner-scoped cho incoming/outgoing: hydrate cache trước, đồng bộ
  nền sau đó, refresh single-flight theo list và coi Realtime là invalidation.
  Subscription/error async được chặn theo lifecycle; account switch không giữ
  state hoặc callback của owner cũ.
- Thêm workspace ba tab `Lời mời`, `Đã gửi`, `Bạn bè` sau cờ Friends hiện có.
  Tab incoming có badge, accept/reject 48 dp và khóa đúng một peer; outgoing chỉ
  đọc. Tab thứ ba giữ nguyên UI Bạn bè trước F4.
- Accept/reject chỉ loại row sau server success. Accept refresh incoming và
  accepted; reject không refresh accepted. Offline/lỗi không gọi mutation, giữ
  cache và hiển thị hướng phục hồi. Search result `Xem lời mời` đóng modal để
  đưa người dùng về tab incoming.
- Không đổi schema/version `capy_friends.db`, migration F1 hoặc remote contract;
  không apply/deploy/gọi/ghi Staging hay Production. Cờ `FRIENDS_ENABLED=false`
  vẫn mặc định tắt và live A/B verification vẫn thuộc F6.
- Verification: F4 notifier/widget **10/10**, Friends **40/40**, Friends +
  Settings **55/55**, full Flutter **643 pass + 1 opt-in Staging skip**, analyzer
  toàn dự án sạch và Web build pass với warning phụ thuộc có sẵn. Widget test xác
  nhận 320 px, text scale 1.3 và action 48 dp. `mobile_audit.py` fail do regex coi
  icon/font/padding là touch target; đây là false positive đã được phép đo widget
  trực tiếp phản chứng.

### 2026-09-22 — Friends F3 search/send and discovery UX (LOCAL VERIFIED)

- Nối provider Friends sau cờ `FRIENDS_ENABLED=false` mặc định; owner chỉ được
  tạo từ exact Staging session. Repository/gateway giữ token và owner bất biến,
  network preflight fail-fast, Realtime chỉ invalidation và response cũ bị bỏ
  khi query hoặc account đổi.
- Thêm modal `Thêm bạn` additive vào màn hiện có: chọn username/email/phone,
  normalize/validate local, debounce 350 ms, public-profile result, generic
  not-found/error, năm relationship action state và khóa double tap khi send.
  Không cache/log/render raw email hoặc phone.
- Thêm Settings discovery email/phone độc lập. Cờ chỉ bật khi server xác nhận
  contact verified; lỗi trả thông báo an toàn. Phone chỉ gọi
  `sync_my_verified_friend_phone()` và fail closed, không cho client tự ghi
  verified state.
- Không đổi schema/version của `capy_friends.db`; F3 chỉ dùng provider/repository
  F2 và bổ sung UI/state. Không gọi/apply/deploy hoặc ghi Staging/Production.
- Verification: Friends + Settings **45/45**; phone 320 px + text scale 1.3 +
  keyboard, wide Web, semantics, 48–50 dp actions, exact three-method lookup,
  all five relationship labels, stale/account-switch/offline/double-tap và
  discovery verification gate. Full Flutter **633 pass + 1 opt-in Staging skip**,
  analyzer sạch, Web build pass.
- `mobile_audit.py` báo false positive do regex coi icon, spacing, progress và
  font size là touch target; widget tests trực tiếp xác nhận control mới. Web
  build còn warning có sẵn từ `flutter_tts` Wasm interop và Cupertino font.
- Residual: repo chưa có phone OTP/link-identity flow để bắt đầu xác minh từ
  Settings. Cần thiết kế với Supabase Auth/SMS provider trước live phone opt-in;
  không hạ verification gate hoặc giả verified để hoàn tất UI.

### 2026-09-22 — Friends F2 domain/gateway/local cache (LOCAL VERIFIED)

- Thay scaffold Friends bằng typed public-profile/relationship/settings models,
  safe failure categories và repository contract; email/phone chỉ là input của
  exact lookup, không tồn tại trong entity hoặc local cache.
- Supabase adapter mới chỉ gọi RPC F1 bằng private client/token bất biến, fence
  account trước và sau await, kiểm tra keyset page giảm dần và dùng sự kiện bảng
  `friends` làm invalidation thay vì tin payload Realtime.
- Thêm DB riêng `capy_friends.db` v1 với connection/meta scope bắt buộc theo
  `project_ref + owner_id`. Snapshot chỉ commit sau trang rỗng, chống duplicate,
  chống response cũ ghi đè trạng thái mới bằng `server_updated_at`, và rollback
  nếu account đổi trước commit.
- Repository tải đủ trang dù server trả short page, single-flight theo loại danh
  sách và cho phép đọc cache sau cold reopen mà không gọi mạng.
- Verification: analyzer toàn dự án sạch; **14/14** fake HTTP/SQLite tests và
  full Flutter suite **615 pass + 1 opt-in Staging test skip**; Web build pass.
  F2 tests bao phủ RPC payload, privacy projection, pagination/order, safe error,
  owner/project isolation, stale in-flight response, account switch, duplicate,
  state regression, single-flight và offline read.
- Không sửa Library/Chat DB, không nối UI F3, không apply/deploy hoặc ghi dữ liệu
  Staging/Production.

### 2026-09-22 — Friends F1 contract and SQL security (LOCAL VERIFIED)

- Thêm migration additive `20260922120000_add_friend_management_contract.sql`:
  server-owned friend timestamps/indexes, private discovery settings/audit/rate
  limit, exact username/email/Vietnam-phone lookup, owner-only discovery RPC,
  atomic/idempotent send/respond và keyset request/accepted-list RPC.
- Email discovery yêu cầu Auth email confirmed. Phone discovery yêu cầu số Auth
  confirmed khớp profile và `sync_my_verified_friend_phone`; đổi email/phone tự
  tắt quyền tương ứng. Search/list chỉ trả public projection, không trả hoặc log
  raw contact. `get_public_profiles(NULL)` nay fail closed bằng kết quả rỗng.
- Giữ chữ ký onboarding `check_phone_available` nhưng chỉ kiểm tra định dạng để
  không thể dò số đã tồn tại; unique constraint trong lần ghi cuối vẫn báo xung
  đột. Direct Friends write cũ tạm giữ để tương thích, client mới sẽ dùng RPC.
- Thêm native PostgreSQL runner và fixture synthetic. Kết quả F1 **68/68**, gồm
  anonymous/outsider, opt-in/verification, generic not-found, RLS, rate limit,
  pagination, retry/lost-response, reject, rollback accept khi mirror lỗi và hai
  client gửi ngược chiều đồng thời. C2 regression **47/47**.
- Trạng thái: **IMPLEMENTED/LOCAL VERIFIED**. Chưa chạy migration dry-run trên
  linked Staging, chưa apply/deploy, không ghi Staging/Production và chưa triển
  khai Flutter F2–F5.

### 2026-09-22 — C1 second-account closure (COMPLETE)

- Thêm Settings widget regression cho account switch A `vi→en` → B `en→vi`
  trên cùng owner-scoped cache; UI sau switch chỉ còn hồ sơ B.
- C1 targeted pass **45/45**; full Flutter **601 pass + 1 opt-in skip** và
  analyzer sạch. Không sửa runtime/schema để làm test xanh.
- Exact-Staging smoke hai account fixture pass đủ 7 nhóm RLS/onboarding/rollback/
  constraint/timestamp/compatibility/cleanup; `fixture_count_remaining=0` và
  baseline profile không đổi.
- CPH2375 cold-start `Status: ok` trong 5.290 ms; Settings/dialog render đúng
  `Tiếng Việt → Tiếng Anh · Mới bắt đầu` và `vi`/`en`/`beginner`. Dialog được
  Hủy, không ghi profile. Chrome-platform runner treo tại `loading` nên đã dừng
  và không được tính là pass. Không migration/deploy/Production/Training change.

### 2026-09-21 — Vilao for person-to-person Chat translation (STAGING LIVE VERIFIED)

- Xác nhận yêu cầu chỉ có Chat người-với-người. Đã gỡ thẻ/dialog Deery-sensei,
  source/test/config `chat-bot` và xóa Edge Function `chat-bot` khỏi exact
  Staging. Không thay raw relay, UI song ngữ, correction/tag, Library hoặc
  Training.
- `chat-translation-worker` dùng duy nhất adapter Vilao OpenAI-compatible khi
  `CHAT_TRANSLATION_PROVIDER=vilao`: HTTPS `/chat/completions`, bearer key
  server-side, model `gemini-3.8-flash`, prompt `chat-translate-p2`, translator
  `chat-translate-v2`, timeout/circuit/single-flight và safe error mapping.
- Migration additive `20260921120000_add_vilao_chat_translation_v2.sql` đã apply
  exact Staging. Row v1 không bị viết lại; tin mới enqueue v2. Flutter/SQLite v6
  đọc cả hai phiên bản và ưu tiên v2 khi cùng message/target.
- Local verification: Deno **52/52**, Chat **149/149**, PostgreSQL **58/58**,
  full Flutter **600 pass + 1 opt-in skip**, analyzer sạch. Remote worker v18
  ACTIVE, migration local/remote khớp.
- Live synthetic E2E **VERIFIED**: một provider attempt, shared member row,
  outsider RLS, post-success idempotency và cleanup baseline đều pass.
- Chỉ còn key chuẩn `CHAT_TRANSLATION_API_KEY`; đã xóa `CHATBOT_API_KEY` và
  `CHAT_GEMINI_API_KEY`. Không có source/function chatbot. Production untouched;
  Training OFF.

### 2026-09-21 — C6E tap-to-select annotation UX (TWO-CLIENT LIVE VERIFIED)

- UI dùng chung Web/Android chuyển luồng chính từ bôi đen hệ điều hành sang
  token picker: chạm một từ, chạm từ khác để mở rộng cụm, preview, bỏ chọn,
  haptic và fallback chọn chính xác theo ký tự. Không đổi schema, RLS, cache,
  outbox hoặc Unicode code-point offsets.
- Raw-sender Web đã lưu row live mới trên exact Staging: `ok` `[0,2)`, type
  `slang`, normalized `được`. Read-only PostgreSQL check xác nhận role
  `source_speaker`, status `active`, actor đúng raw sender và correction
  `accepted`; phương án UX được chốt.
- Correction panel **7/7**, Chat **149/149**, full Flutter **600 pass + 1
  opt-in skip**, analyzer sạch. Exact-Staging APK build/cài/cold start trên
  CPH2375 pass và log nghiêm trọng bằng 0.
- Reversed live flow passed on Android: raw marker `C6EANDROIDRAW0248` reached
  Web, Web submitted one proposal, Android received and accepted it, then used
  the token picker to save `C6EANDROIDRAW0248` `[0,17)`, type `slang`, normalized
  `android c6e`. Exact-Staging read-only checks confirmed correction `accepted`,
  annotation `active`, `source_speaker`, and Android raw sender as creator.
- The temporary Web language profile swap was restored; both test profiles are
  `vi -> en`. Android cold restart reopened the conversation, and the correctly
  PID-scoped log had 0 fatal/Flutter/unhandled matches. Production untouched;
  Training OFF.

### 2026-09-21 — C6D manual span annotations (TWO-CLIENT LIVE VERIFIED / C6 COMPLETE)

- Thêm migration additive `20260920130000_add_chat_manual_span_annotations.sql`
  cho `public.chat_slang_annotations`, FK raw message/accepted correction,
  six-value tag type, exact code-point span và `source_speaker`. Trigger chặn
  actor sai, span sai và update; RLS chỉ cho active two-member conversation đọc
  và raw sender insert sau khi chính họ accept correction.
- Nâng operational Chat SQLite v4→v5 với annotation cache/outbox owner-scoped,
  FK message/correction, sync retry/blocked state và indexes phục vụ history +
  pending drain. Không đổi Library DB, raw message, Gemini translation hoặc
  Training schema/read path.
- Gateway/coordinator pull correction trước annotation, xử lý cùng-UUID lost ACK,
  Realtime invalidation và bounded retry. UI thêm dialog select raw Unicode span,
  tag type và normalized source sau accepted correction; Flutter đổi UTF-16
  selection sang zero-based code-point half-open offset.
- Local checks: PostgreSQL 18 C6D **17/17**, C6C **24/24**, C2 **47/47**;
  focused Flutter **108/108**, Chat **149/149**, full Flutter **600 pass + 1
  opt-in skip**, analyzer sạch. Correction panel **7/7** sau khi sửa dropdown
  overflow; SQLite v4→v5 migration có regression riêng.
- Exact Staging được xác minh đúng ref `nxteaznowkfennxpqjmt`; pre-dry-run chỉ có
  migration C6D. Backup PostgreSQL custom archive 247.051 byte qua `pg_restore`
  và DPAPI `VERIFIED`; apply pass; post-dry-run `upToDate=true`.
- Staging smoke ba account pass 10 nhóm: source-only Unicode tag, immutable row,
  outsider/anonymous RLS, held/inactive fail-closed và ba WebSocket subscribe đủ
  sáu bảng. Cleanup trở về baseline, 0 fixture, 0 Gemini call, 0 Training write.
- APK Chat-enabled build/cài/chạy trên CPH2375 Android 13; Supabase init, Dart VM
  và màn chính render pass. Live gate xác định Web `…12e38bb1` là raw sender và
  Android `…51a164ac` là correction author. Web accept proposal; remote xác nhận
  đúng actor, trạng thái `accepted` và đúng một audit event.
- Web chọn span `ok`, loại `Khác`, normalized source `đồng ý`; remote có đúng một
  annotation `[0,2)`, type `other`, role `source_speaker`, status `active`. Web
  và Android cùng render chip qua Realtime; Android cold restart khôi phục đúng
  correction/tag, log nghiêm trọng bằng 0. C6 COMPLETE. Production không bị ghi
  hoặc apply; Training vẫn OFF.

### 2026-09-21 — C6C correction (TWO-CLIENT LIVE VERIFIED / COMPLETE)

- Thêm migration additive cho `chat_corrections.updated_at`, unique pending
  proposal, bảng audit `chat_correction_events`, trigger append-only và RPC
  `resolve_chat_correction` chỉ cho raw sender. Retention cascade vẫn xóa audit
  cùng parent; direct event mutation bị chặn.
- Nâng riêng operational Chat SQLite v3→v4 với correction cache/outbox
  owner-scoped; proposal và decision hoạt động offline, retry bounded, dùng
  server timestamp canonical, chặn stale owner/membership và không sửa raw hay
  Gemini translation.
- Gateway/coordinator pull raw trước correction, dùng Realtime như invalidation,
  xử lý lost ACK bằng cùng UUID và gọi resolver cho accept/reject. UI route và
  mailbox thêm card correction, text selectable và CTA 48dp; C5/C6A/C6B được
  giữ nguyên.
- PostgreSQL 18 isolated C6C **24/24**, C2 schema regression **47/47**, Chat
  Flutter **139/139**, full Flutter **590 pass + 1 opt-in skip** và analyzer
  toàn dự án sạch. Exact-Staging có backup DPAPI 230.879 byte verified; dry-run
  chỉ đúng migration C6C, apply pass và post-dry-run `upToDate=true`.
- Smoke ba account synthetic trên Staging pass 9 nhóm: friend/open-direct/raw,
  Realtime A/B, duplicate proposal, sender-only accept/reject RPC, idempotent
  audit, opposite-final denial, outsider/anonymous RLS, held/inactive-member và
  cleanup trở về baseline. Còn 0 fixture, 0 Gemini call, 0 Training write.
- APK exact-Staging Chat-enabled build/cài/chạy pass trên CPH2375 Android 13.
  Smoke thật phát hiện `TextEditingController` bị dispose trước route-exit và CTA
  proposal xuất hiện dù native language không thỏa RLS; đã chuyển controller vào
  State riêng, thêm guard theo profile cùng hai regression test.
- Proposal hợp lệ từ Android đã persist exact Staging ở trạng thái `proposed`,
  target `en`, đúng một audit event `proposed`; UI còn ổn định và CTA trùng biến
  mất. Profile test tạm đảo để smoke đã khôi phục `vi→en` cả remote lẫn cache.
  Web raw sender đã accept proposal thật; remote xác nhận đúng actor, trạng thái
  final và một audit event `accepted`. Production không bị truy cập ghi.

### 2026-09-20 — C6B owner-scoped Library lookup (ANDROID LIVE VERIFIED / COMPLETE)

- Thêm read-only `LocalVocabularyLookupRepository` trên Library SQLite hiện có;
  query bắt buộc owner UUID, normalize span, ưu tiên annotation active revision
  mới nhất, loại Photo Note deleted/tombstone và chỉ nhận scan succeeded.
- Không tăng `LibraryDatabase` version, không migration/backfill, không ghi bảng,
  không tạo sync operation/outbox và không gọi Supabase/Gemini/dictionary remote.
  Provider Chat tái sử dụng đúng `libraryStoreProvider` của account hiện tại.
- UI C5/C6A giữ nguyên và chỉ bổ sung `Tra từ` vào context menu của selected
  English text. Bottom sheet local có loading/result/empty/error/retry; owner
  switch fail-closed. Nút đóng và retry được đo tối thiểu 48×48.
- C6B focused 7/7, full Flutter 575 pass + 1 opt-in skip, analyzer sạch. Exact-
  Staging migration dry-run `upToDate=true`, APK build/cài/chạy CPH2375 pass;
  menu `Tra từ` + `Copy`, local empty state và cold restart PID 25514 verified,
  critical log match 0, temp staging define 0. Production/Training untouched.

### 2026-09-19 — C5 Web↔Android A/B live gate verified (C5 COMPLETE)

- Guarded Web runner verified exact Staging and `upToDate=true`, then started a
  Chat-enabled Chrome client already authenticated as the account opposite the
  CPH2375 session. Its mailbox showed 11 unread plus the latest Android marker.
- The same 17:32 message/translation pair rendered on both clients. Android
  native `vi` showed English translation primary and Vietnamese raw secondary;
  Web native `en` showed Vietnamese raw primary and the identical English
  translation secondary. Web layout stayed responsive and loaded without error.
- Android PID 6481 retained 0 fatal/Flutter/overflow/network/auth/sync matches.
  Web runner output contained successful Supabase init and no runtime exception.
- Runner processes stopped and its temporary define was removed. Two stale
  Staging define files from 16/9 were also removed; final temp define count is 0.
- C5 is COMPLETE on exact Staging. No schema/apply/deploy/secret, Production or
  Training change occurred during this A/B read verification; C6 is next.

### 2026-09-19 — C5 Android live translation smoke (PARTIAL LIVE VERIFIED)

- Guarded runner verified exact Staging `nxteaznowkfennxpqjmt` is healthy and
  migration dry-run is up to date. Chat-enabled Android APK built in 201.0s;
  `adb install -r` succeeded on authorized CPH2375 without clearing app data.
- Existing signed-in session, conversation and SQLite remained. At 720×1612 the
  mailbox/header/composer/send UI rendered without overflow. Two smoke messages
  reached the live worker; `xin chao day la kiem tra c5 android` rendered as
  primary English `hello this is android c5 check` plus secondary Vietnamese raw.
- Device navigation exposed that `/chat` had no Friends entry. Added one
  `Mở trang Chat` CTA beside refresh and outside the global avatar bounds. The
  final APK opens full-screen inbox then detail, where both new pairs remain
  visible with `Server đã nhận`; no existing Friends/Chat UI was removed.
- Cold restart completed in 4,478ms and both new raw/translation pairs remained
  in the semantic tree from local cache. The existing Chat DB and older history
  remained readable; PID-scoped fatal/Flutter/overflow/network/auth/sync matches
  were 0.
- Final regression: Chat **118/118**, full Flutter **564 pass + 1 existing
  opt-in skip**, analyzer clean. Final CTA APK PID 6481 also had 0 error matches.
- This closes Android single-client live rendering only. Two-client A/B viewing
  the same translation row remains pending; Production and Training untouched.

### 2026-09-19 — C5 personalized dual-language UI (LOCAL VERIFIED)

- Added an owner-scoped translation stream over the existing SQLite cache and a
  shared message body for the floating mailbox plus `/chat`; no schema or remote
  contract changed.
- Viewer-native/source match renders translation first; viewer-native/target
  match renders raw first. Unknown profile remains raw-first. Both lines are
  selectable and expose language/order semantics.
- Pending, queued, processing, automatic retry, terminal failure and cache-read
  failure keep raw visible with a stable status line. Existing mailbox, drag,
  composer, send action and deferred-image decision remain intact.
- Targeted overlay **6/6**, state + route **16/16**, full Chat **118/118**, full
  Flutter **564 pass + 1 existing opt-in skip** and analyzer passed; Web build
  passed with existing dependency Wasm `flutter_tts`/Cupertino font warnings.
  Narrow 320px and phone/wide checks reported no overflow.
- Status is IMPLEMENTED/LOCAL VERIFIED. Live A/B Staging UI smoke remains; no
  migration, deploy, secret, Gemini, remote, Production or Training write.

### 2026-09-19 — C4G exact-Staging live gate verified

- Dedicated Chat Gemini auth key passed exact model preflight; Edge secrets and
  matching Vault trigger/worker URL entries were configured without logging
  values. Clipboard and protected plaintext temp were cleared.
- `chat-translation-worker` is `ACTIVE` with the intended internal trigger mode.
  Migration parser now accepts current CLI JSON and legacy table output; the
  live runner no longer treats SQLite-only `training_examples` as a REST table.
- Final function inventory reports Chat worker v1 and Scan worker still ACTIVE
  at v2 after the project-secret update. Chat uses `CHAT_GEMINI_API_KEY`; the
  existing Scan `GEMINI_API_KEY` name remains separate, and no deploy command
  targeted Scan source.
- Final three-account smoke is **VERIFIED**: one successful Gemini attempt, one
  shared translation row for both members, outsider 0 rows, concurrent/repeated
  wake-ups idempotent, and Auth/operational fixtures cleaned back to baseline.
- Final local rerun passed SQL **58/58**, Deno **50/50**, Flutter Chat
  **115/115**, analyzer, Deno check/lint/format and all three PowerShell
  self-tests. Date-expired worker/handler lease fixtures were replaced with a
  stable future-only test lease; runtime code did not change.
- C4G and C4 are complete on exact Staging. Remote has no Training table,
  Training stays OFF, and Production was not accessed.

### 2026-09-19 — C4G Staging schema applied; first live attempt partial

- Applied the five explicitly approved migrations to exact linked Staging only:
  two pending onboarding contracts, C4B queue, managed `pg_net`, and the
  Vault/pg_net/Cron wake-up. Production was not queried or changed.
- Post-apply `db push --dry-run` is up to date. Read-only capability preflight
  verifies pg_net/pg_cron/Vault plus required function/relation signatures.
- Secret/deploy script self-test passed, then failed closed at clipboard format
  validation before the first secret write. Clipboard was cleared; no Chat Edge
  secret, Vault config, worker deployment, synthetic fixture or Gemini call occurred.
- Read-only Edge follow-up confirms `chat-translation-worker` and both Chat secret
  names remain absent. The new trigger/Cron remain harmless without Vault values.
- C4G remains PARTIAL; approval 2–4 is retained and execution can resume after a
  valid raw Chat Gemini test key or `GEMINI_API_KEY=...` line is copied.

### 2026-09-18 — C4G rollout prepared (LOCAL + READ-ONLY STAGING VERIFIED)

- Backup exact Staging `public/private` verified and encrypted with Windows DPAPI:
  193,285-byte archive; migration history encrypted separately and plaintext
  temporary files cleaned.
- Read-only capability query on fixed linked Staging confirms `pg_cron` and
  `supabase_vault`; `pg_net`/`net.http_post` are absent. Added managed extension
  prerequisite migration `20260918125000` and additive Vault/pg_net/Cron worker
  wake-up migration `20260918130000`.
- Wake-up is post-commit async, content-free and private; missing/malformed Vault
  config or infrastructure error never rolls back raw chat. One-minute Cron repairs
  missed triggers, due retries and expired leases.
- Native PostgreSQL 18 suite passes **58/58**, including two-connection
  `SKIP LOCKED`, trigger/Cron, privilege denial, duplicate retry and request shape.
  Existing Deno worker/provider suite passes **50/50**.
- Exact-Staging dry-run proposes five migrations only: pending onboarding
  `20260916120000` + `20260917120000`, C4B `20260918120000`, pg_net enable
  `20260918125000`, wake-up `20260918130000`. No migration was applied.
- Added read-only capability preflight and a fail-closed synthetic live runner
  locking project/function/migrations/secrets, concurrent wake-up, shared RLS row,
  outsider denial and baseline cleanup.
- No extension/schema/data/secret/deploy/Gemini/Production write occurred. C4G is
  still PARTIAL until explicit external-write approval and live E2E passes.

### 2026-09-18 — C4F runtime translation reconcile (LOCAL VERIFIED)

- Nối Operational Chat coordinator pull/merge translation sau khi raw history và
  visibility đã commit cho từng conversation; không đưa translation vào raw row.
- Realtime vẫn invalidation-only. Existing single-flight/refresh version coalesce
  duplicate signals; reconnect và repair refresh merge cùng entity idempotently.
- Session epoch, invalidation và transaction guard chặn late result sau logout,
  account switch/background hoặc membership revoke. Offline giữ local cache;
  translation fetch failure không rollback raw ACK hay làm sống lại outbox.
- Điều chỉnh cache bỏ qua state cũ theo `updated_at` trước immutable-success guard;
  response cũ không làm hỏng sync, còn newer success mutation vẫn fail-closed.
- Verification: coordinator **26/26**, cache **9/9**, combined **35/35**, Chat
  **115/115**, full Flutter **561 pass + 1 existing opt-in skip**, analyzer và
  `git diff --check` sạch.
- Không UI C5, dependency/schema remote mới, apply/deploy/secret, live Gemini,
  remote write hoặc Training. C4G exact-Staging vẫn cần approval riêng.

### 2026-09-18 — C4E client translation entity/cache (LOCAL VERIFIED)

- Thêm `OperationalChatTranslation`/status codec khóa provider/model/prompt/
  translator v1, strict timezone/state/error/output validation và không tạo
  Training/export contract.
- Operational Chat DB nâng additive v2→v3 với `chat_translations` tách raw row:
  composite owner scope, unique translation key, policy/state CHECK, FK cascade
  tới message. Migration test xác nhận raw/conversation v2 được giữ nguyên;
  Library/AI DB không bị mở hoặc nâng version.
- Store merge/read/watch theo conversation và exact version; chỉ nhận row cho raw
  sent thuộc active owner conversation. Duplicate idempotent, stale `updated_at`
  bị bỏ, cùng timestamp khác state/attempt regression bị chặn và cached success
  không thể rewrite. Account/project khác không đọc chéo cache.
- Gateway PostgREST phân trang theo UUID tăng dần, filter exact translator version
  và `chat_operational_messages!inner(conversation_id)` dưới C2 RLS. Realtime chỉ
  thêm `chat_translations` làm invalidation source; không tin event payload và
  không cấp client write.
- Verification: C4E cache/migration **8/8**, gateway **28/28**, Chat **108/108**,
  full Flutter **554 pass + 1 existing opt-in skip**, analyzer clean. Raw cache
  không đổi khi translation invalid và FK cascade dọn cache khi raw bị prune.
- Tại checkpoint C4E chưa wire coordinator C4F, UI song ngữ C5, dependency mới,
  remote schema/apply, deploy, secret, live Gemini call, remote write hoặc
  Training. C4F sau đó đã complete local ở entry phía trên.

### 2026-09-18 — C4D Gemini translation adapter (LOCAL VERIFIED)

- Thêm `gemini_provider.ts` dùng Native Gemini `generateContent` với model khóa
  `gemini-3.5-flash-lite`, exact prompt `chat-translate-p1`, translator
  `chat-translate-v1`, `thinkingLevel=MINIMAL`, một candidate và tối đa 4096
  output tokens. Không thêm dependency, retry nội bộ hoặc model fallback.
- Runtime đọc riêng `CHAT_GEMINI_API_KEY`, chỉ tạo provider khi key nonblank và
  gửi key trong `x-goog-api-key`; thiếu key fail trước queue claim. Endpoint/error
  không đưa credential, raw/prompt/translated text hoặc provider body vào log.
- Adapter chặn language/policy mismatch trước HTTP; map auth/request/timeout-rate/
  unavailable/network theo C4A, parse/cap `Retry-After` 300 giây. C4B tiếp tục là
  owner duy nhất của retry/circuit state, tránh circuit song song trong Edge.
- Native response phải là JSON có đúng một candidate `STOP` và một text nonblank
  tối đa 16.000 Unicode code point. Missing/multiple/blocked/truncated/ambiguous
  response và invalid output fail-closed, không có hidden repair request.
- Thêm **22 fake HTTP tests** cho exact request hai chiều, config/policy fail trước
  HTTP, 400/401/403/408/429/5xx, Retry-After, malformed/invalid output và timeout
  abort qua worker. Combined Deno **50/50 pass**; check/lint/format và secret scan
  sạch. Official Gemini model/generateContent/thinking docs được đối chiếu.
- Không apply/deploy, set/read secret thật, live Gemini request, webhook/Cron,
  remote DB write, migration mới, Flutter/local Chat DB hoặc Training. C4E tiếp.

### 2026-09-18 — C4C provider-neutral translation worker (LOCAL VERIFIED)

- Tạo `supabase/functions/chat-translation-worker` tách biệt AI Scan: typed queue
  contract, Supabase service-role RPC gateway, worker state machine và internal
  POST handler có constant-time trigger-secret check.
- Orchestration inject được queue/provider/logger/time/abort; một claim chỉ gọi
  provider một lần. Timeout 15 giây, stable error/retry-after forwarding, output
  nonblank/≤16.000 validation và token-bound complete/fail giữ đúng C4A/C4B.
- Claim version hoặc lease hết hạn bị chặn trước provider. Lost/ambiguous database
  completion không ghi failure mâu thuẫn; persistence outage để lease recovery.
  Safe logs/response không chứa raw/translated text, claim token, credential hay
  provider/database exception body.
- `supabase/config.toml` khai báo function `verify_jwt=false` vì endpoint dùng
  dedicated internal trigger secret, không dùng user JWT. C4C `index.ts` cố ý
  chưa wire provider; request hợp lệ vẫn fail `provider_not_configured` trước
  claim cho đến C4D.
- Verification: `deno test ...chat-translation-worker` **28/28 pass** với fake
  queue/provider/HTTP; `deno check index.ts`, `deno lint` và `deno fmt --check`
  đều sạch. Lượt trong sandbox gặp Deno 2.9.5 Windows named-pipe panic; rerun ngoài
  sandbox pass đầy đủ.
- Không migration mới ngoài C4B, không apply Staging/Production, webhook/Cron,
  deploy, secret, Gemini/network provider call, Flutter/local DB hoặc Training.

### 2026-09-18 — C4B translation queue and atomic claim (LOCAL SQL VERIFIED)

- Thêm migration additive
  `20260918120000_add_chat_translation_queue_claim.sql`; tái sử dụng
  `chat_translations`, unique key/RLS/Realtime hiện có và không backfill raw row
  trước C4B.
- Raw insert enqueue policy snapshot `chat-translate-v1`/`chat-translate-p1` với
  target `vi↔en`; provider call không chạy trong transaction message.
- Bổ sung claim token, lease expiry, attempt/update timestamps, partial recovery
  index và `private.chat_translation_provider_state` không chứa content/identity.
- Claim/complete/fail RPC chỉ cấp `service_role`; direct table mutation bị guard,
  stale/expired token fail-closed, success/policy snapshot immutable. Retry cap 4,
  tiers `5s/30s/2m`, quota/auth/transient circuit và terminal taxonomy theo C4A.
- Thêm synthetic pre-migration fixture, SQL security/state/concurrency suite và
  isolated native runner. Kết quả cuối: **49/49 pass** trên PostgreSQL 18, gồm
  hai connection thật tranh một row với `FOR UPDATE SKIP LOCKED`; C2 correction,
  raw/RLS/account isolation regression pass; temp cluster cleanup, remote writes 0.
- Runner xử lý an toàn khác biệt Windows PowerShell: PostgreSQL NOTICE được đánh
  giá bằng exit code, và startup chỉ tiếp tục khi `pg_ctl status` xác nhận đúng
  disposable cluster.
- Chưa apply Staging/Production, chưa cấu hình webhook/Cron, chưa deploy Edge,
  chưa set/read secret, chưa gọi Gemini và không đổi local Flutter Chat DB/Training.

### 2026-09-18 — C3 raw-text UI cleanup before C4 (SOURCE/TEST VERIFIED)

- Gỡ nút chọn ảnh, preview thumbnail và cache ảnh RAM khỏi
  `OperationalChatOverlay`; C3 không còn hiển thị một khả năng gửi ảnh mà relay
  và thiết bị nhận không hỗ trợ.
- Bong bóng hội thoại giờ render nguyên văn `OperationalChatMessage.rawText`.
  Chuỗi hợp lệ chứa `📷 [Ảnh: demo.jpg]` không còn bị nhận nhầm là attachment
  rồi ẩn nội dung.
- Bổ sung widget regression cho marker ảnh trong raw text và xác nhận
  `chat-pick-image` không còn xuất hiện.
- Roadmap trong `chat_DB.md` khóa gửi ảnh, sticker và các chức năng Chat phụ trợ
  sau khi milestone Chat cuối cùng C6 đã hoàn thành và được verify end-to-end;
  việc gỡ UI hiện tại không hủy yêu cầu tính năng về sau.
- C4 được chia thành bảy increment C4A–C4G với exit gate riêng: contract,
  queue/atomic claim, worker core, Gemini guardrails, client cache, runtime
  reconcile và exact-Staging E2E. Đây mới là `PLAN`; chưa migration, deploy,
  secret, remote write hoặc Gemini call.
- Verification: targeted overlay **5/5**, toàn bộ Chat **98/98** và
  `flutter analyze --no-pub` sạch. Không đổi schema/migration, local Chat DB,
  relay, cloud data hoặc Training; C4 translation worker/UI vẫn chưa bắt đầu.

### 2026-09-18 — C4A Chat translation contract complete (DOCUMENTATION VERIFIED)

- Hoàn thành contract tại `docs/data/c4a_chat_translation_contract.md`: target
  deterministic `vi↔en`, policy `chat-translate-v1`/`chat-translate-p1`, native
  Gemini một model/không fallback, Chat-only secret, timeout 15 giây, lease 60
  giây, tối đa 4 provider attempts và backoff `5s/30s/2m`.
- C4B phải tái sử dụng `chat_translations` và bổ sung additive claim token/lease,
  timestamps, processing recovery index cùng private circuit state; client tiếp
  tục SELECT-only, successful result immutable và raw message không bị sửa.
- Khóa enqueue DB idempotent, async worker claim với `FOR UPDATE SKIP LOCKED`,
  stale-token rejection, deterministic retry/quota/circuit behavior, stable
  failure taxonomy và safe-log contract không chứa content/identity/credential.
- Ma trận verification đã chỉ rõ concurrency, stale lease, RLS/account isolation,
  hidden/deleted/inactive, fake-provider errors, raw-first/cache/reconnect và
  exact-Staging gate. Existing pre-C4 messages không tự backfill.
- Đây là tài liệu thiết kế đã khóa, chưa phải implementation: không migration,
  deploy, secret, remote write, Gemini call, local Chat DB hoặc Training change.
  C4B là increment tiếp theo; Production vẫn untouched.

### 2026-09-18 — Chat box refinements, album photo picker, draggable dialog & zero-latency bubble (TEST & RUNTIME VERIFIED)

- Bổ sung nền giấy hữu cơ mộc từ AI Scan (`ScanPaperBackground` + `AppColors.cream`) cho toàn bộ box chat và thanh nhập tin nhắn.
- Thêm nút chọn ảnh từ album hình vuông góc trái ô nhập liệu (`chat-pick-image`), hỗ trợ preview thumbnail trước khi gửi và hiển thị ảnh đính kèm trong bong bóng tin nhắn. Thay đổi này đã được thu hồi bởi entry cleanup phía trên vì C3 không có transport ảnh giữa hai thiết bị.
- Tinh chỉnh vị trí thời gian gửi tin nhắn: đặt phía dưới bong bóng chat, bỏ text "Server đã nhận" để giao diện gọn gàng.
- Bổ sung tính năng kéo di chuyển toàn bộ box chat qua thanh header (`_MailboxHeader` & `_ConversationHeader`), có visual drag handle indicator và safe area clamping.
- Tối ưu chuyển động bong bóng chat (`_ChatBubble`): chuyển `AnimatedPositioned` sang `Duration.zero` khi đang giữ và kéo (`_isDraggingBubble`), loại bỏ hoàn toàn độ trễ 240ms; thêm hiệu ứng phóng to xúc giác `1.08` và bóng đổ sâu hơn khi kéo.
- Khôi phục kích thước ban đầu (410x620) rộng rãi, thoáng đãng cho box chat.
- Verification: `flutter analyze` 0 lỗi; `flutter test test/features/chat/` pass toàn bộ **98/98** tests; kiểm tra tương tác kéo thả mượt mà trên BlueStacks emulator.

### 2026-09-17 — In-box conversation embedded in mailbox overlay (SOURCE/TEST VERIFIED)

- Tái thiết kế tương tác Chat: chuyển hội thoại từ route toàn màn hình (`/chat/:id`)
  vào nằm trực tiếp bên trong popup box chat (`OperationalChatOverlay` / `_ChatMailbox`).
- Khi bấm vào bạn bè/hội thoại, panel không đóng và không navigate; panel hiển thị
  `_MailboxConversationView` với header back `←`, avatar, tên bạn bè, trạng thái text gốc,
  nút đóng `✕`, danh sách bubble tin nhắn và thanh soạn thảo tin nhắn có nút gửi.
- Hỗ trợ bàn phím: bọc panel với `AnimatedPadding(viewInsets.bottom)` và tính toán
  `maxAvailableHeight` để popup tự động co giãn và nâng lên trên bàn phím ảo, không bị che
  hoặc gây lỗi `RenderFlex` overflow.
- `tool/run_bluestacks.ps1` được bổ sung switch `-Staging` để tự động lấy Staging credentials
  và inject `--dart-define-from-file`, giúp chạy kiểm thử trực tiếp trên BlueStacks dễ dàng.
- Verification: `flutter analyze` sạch; `flutter test test/features/chat/` pass **96/96**;
  widget test bao gồm in-box conversation view, message bubbles, text input và back button.

### 2026-09-17 — Global chat mailbox overlay (ANDROID 9 + TEST VERIFIED)

- Thay CTA Chat riêng ở màn Bạn bè bằng `OperationalChatOverlay` gắn trong
  `ShellRoute`, hiển thị trên toàn bộ giao diện khi exact-Staging Chat owner tồn
  tại. Bubble mascot 64dp hỗ trợ TalkBack, haptic, kéo/bám mép và tự lùi vào mép
  sau 5 giây không tương tác; mở panel không rời màn hiện tại.
- Panel bám thiết kế neo-brutalist tham chiếu: header/unread tổng, tìm kiếm bạn,
  AI card trả thông báo “chưa mở”, danh sách bạn/hội thoại thật, preview/thời gian,
  unread-first và badge. Public profile được lấy gộp qua RPC đã có
  `get_public_profiles` rồi cache owner-scoped; không tạo profile giả hoặc query
  từng row.
- Operational Chat SQLite nâng additive v1→v2, thêm `last_read_at` vào
  `chat_conversations` và bảng `chat_peer_profiles`; unread chỉ clear khi mở
  detail. Không thay đổi Library DB hoặc Supabase schema/migration.
- Verification: `flutter analyze` sạch; `flutter test test/features/chat` pass
  **95/95**; full `flutter test` pass **541**, 1 opt-in skip, 0 failure. Widget
  coverage gồm search, AI notice, unread/preview/read cursor, owner isolation,
  auto-retreat và drag/dock hai mép.
- Mobile audit bắt 6 false-positive vì regex coi `SizedBox` spacing và progress
  indicator 24px là touch control; control tương tác thật dùng bubble 64dp,
  `IconButton`, `ListTile` và semantics. APK exact Staging build/cài đè giữ data
  trên BlueStacks Android 9; bubble tự lùi, panel/profile/AI notice render đúng;
  log hiện tại có 0 match `FlutterError|No Overlay|RenderFlex|overflowed|SQLiteException|FATAL EXCEPTION`.
- Staging preflight chỉ dry-run và vẫn báo hai migration onboarding pending;
  không apply migration, không deploy, không ghi remote row/object, không đụng
  Production. Bốn font untracked có sẵn được giữ nguyên.

### 2026-09-17 — BlueStacks switched to exact Staging with Chat enabled (RUNTIME VERIFIED)

- Guard ban đầu dừng đúng trước build vì repo đang link Production
  `vmxonxqxrlkssdzsucrg`; không có APK, migration hoặc cloud write ở lần dừng này.
- Chạy `supabase link --project-ref nxteaznowkfennxpqjmt --yes`, sau đó xác minh
  đúng một linked project: `emtonny's Project`, exact Staging ref và
  `ACTIVE_HEALTHY`; organization có hai project active.
- Runner `-Target android-build -ChatRelayEnabled` pass. Migration preflight là
  dry-run và báo hai migration pending:
  `20260916120000_add_onboarding_language_preferences.sql` và
  `20260917120000_merge_onboarding_language_contracts.sql`; không migration nào
  được apply.
- APK debug 200,791,280 byte build pass, `adb install -r` lên BlueStacks
  `emulator-5554` pass và giữ app data; `MainActivity` launch `Status: ok` trong
  2,806 ms. Process foreground tồn tại, bộ lọc 500 dòng log hiện tại có 0 match
  fatal/Flutter/Supabase/network startup và file dart-define tạm đã cleanup về 0.
- Production không relink lại, không deploy, không đổi secret, không ghi row/object
  hoặc thay đổi schema. Bốn font untracked có sẵn được giữ nguyên.

### 2026-09-17 — AI-scan/chat branch reconciliation (SOURCE/TEST VERIFIED)

- Merge `origin/chat` vào `AI-scan`, giữ cả AI scan retry/UI hiện tại và C3
  operational chat, language profile, Web local media cùng responsive frame.
- Hai nhánh có RPC onboarding khác nhau; thêm migration local-only
  `20260917120000_merge_onboarding_language_contracts.sql` để một lời gọi
  authenticated ghi atomic cả locale preferences và chat language profile,
  đồng thời giữ nguyên các compatibility overload cũ.
- Migration mới **chưa apply** Staging/Production; không deploy, không ghi cloud
  data và không thay đổi secret trong increment đồng bộ này.
- Verification trên source đã merge: `flutter analyze --no-pub` sạch; targeted
  onboarding/chat/Settings/navigation/Library/Web suite pass **180/180**; full
  `flutter test --no-pub` pass **537**, 1 opt-in live test skip, 0 failure.
- Không chạy lại native SQL runtime: môi trường không có Supabase CLI và không
  có PostgreSQL 18 `initdb`/`pg_ctl`/`psql`. Migration merge mới được kiểm tra
  bằng static contract test; 47 SQL/RLS checks của C2 phía dưới là bằng chứng
  lịch sử từ commit `chat`, không phải kết quả chạy lại trong merge này.

### 2026-09-17 — Camera latency diagnosis and first empty-scan recovery

- ADB timeline trên BlueStacks Android 9 xác nhận `IMAGE_CAPTURE` mở activity
  camera trong khoảng 250 ms nhưng camera HAL mất khoảng 11,8 giây ở lần đo
  đầu và 11,3 giây ở lần đo tiếp theo mới phát preview frame đầu. Đây là độ trễ
  của camera emulator bên ngoài process Flutter; source app không thể loại bỏ
  đoạn chờ này. Phần chuẩn bị ảnh sau capture được giảm bằng output 1024px,
  quality 85, fast-path cho JPEG đã <= 300 KiB và loại bỏ một decode thừa.
- Root cause của lần quét đầu lỗi là gateway trả JSON hợp lệ nhưng rỗng
  `{"words":[]}` qua HTTP 200. Logic cũ chỉ bắt body text rỗng nên đã đánh dấu
  ledger `succeeded`; Flutter sau đó báo lỗi nhận diện. Model chain nay kiểm tra
  semantic result, retry/fallback trong tổng giới hạn 2 upstream attempts, chỉ
  ghi success khi có detection; sau hai kết quả rỗng handler hoàn tất ledger
  failure `empty_response` và trả HTTP 422. Flutter cũng fail-closed với server
  cũ trả HTTP 200 rỗng.
- Verification: targeted Flutter suite 45/45 pass; targeted Edge suite 34/34
  pass, gồm empty-first -> retry success và empty-twice -> 422/failed ledger;
  targeted Flutter analyzer sạch; `deno check --config
  supabase/functions/gemini-vision-scan/deno.json .../index.ts` pass; `git diff
  --check` không có whitespace error; `flutter build apk --debug --no-pub`
  tạo APK thành công.
- Status: **IMPLEMENTED/SOURCE + TEST VERIFIED, RUNTIME PARTIAL**. Không đổi
  schema/migration, SQLite transaction, media retention, consent hoặc sync
  contract. Edge Function chưa deploy; độ trễ preview riêng của BlueStacks HAL
  vẫn cần cấu hình camera emulator hoặc kiểm tra trên thiết bị thật.

### 2026-09-16 — Onboarding interface and learning languages

- Chèn bước chọn ngôn ngữ ở bước 2/6, ngay sau danh tính và trước dữ liệu
  tuổi/SĐT; mặc định `vi-VN` cho giao diện và `en-US` cho ngôn ngữ muốn học.
- Bổ sung danh mục 196 quốc gia/vùng với cờ, tên quốc gia và ngôn ngữ chính;
  picker hỗ trợ tìm kiếm không dấu, thanh cuộn hiển thị rõ và dựng danh sách
  lazy bằng `ListView.builder`.
- Bổ sung hai cột bắt buộc `interface_locale`, `learning_locale` cùng validation
  vào migration `20260916120000_add_onboarding_language_preferences.sql`, đồng
  thời mở rộng RPC onboarding từ 8 lên 10 tham số. Migration đã được apply và
  history Production khớp timestamp `20260916120000`; không đọc/ghi dữ liệu
  người dùng trong lần triển khai.
- Giữ thêm RPC `complete_onboarding` 8 tham số cho các bản app đã cài; wrapper
  dùng locale mặc định `vi-VN`/`en-US` và gọi cùng luồng validate nội bộ. Cả hai
  signature chỉ cấp `EXECUTE` cho `authenticated`; `anon` và `PUBLIC` bị revoke.
- Verification: `flutter test --no-pub test/features/onboarding` — 26/26 pass,
  gồm tìm kiếm không dấu, chọn locale, lưu RPC và viewport 320px/text scale
  1.3; `flutter analyze --no-pub lib/features/onboarding
  test/features/onboarding` — sạch; `git diff --check` — không có whitespace
  error. Production verification xác nhận đủ hai cột locale, hai RPC 8/10 tham
  số, quyền gọi của `authenticated` và chặn `anon`; migration history hiện khớp
  `20260916120000`. Security Advisor không phát hiện cảnh báo mới từ migration;
  các cảnh báo còn lại thuộc `ai_scan_requests`, Library event trigger và Auth
  password policy đã tồn tại. `flutter analyze --no-pub` toàn dự án chưa pass vì các file Library
  đang tách dở (`storage_album_albums.dart`, `storage_album_trash.dart` và
  `SelectedPhotoVocabularyScreen`) tạo lỗi ngoài phạm vi increment. Supabase
  CLI không có trong môi trường nên migration chưa được chạy local.

### 2026-09-15 — View vocabulary from multiple selected Albums

- Added the green “Xem từ vựng (n Album)” action beside bulk Album deletion.
  It reads each selected Album through the existing owner-scoped local
  `PhotoNoteQuery`, preserves visible Album order and per-Album photo order,
  then removes duplicate Photo Notes by ID before opening the existing
  expandable vocabulary screen.
- Empty Albums and repository failures now use the shared top notification and
  keep selection mode active for retry. The two bottom actions remain above
  navigation and fit a 360px viewport.
- Verification: Library widget tests 20/20 and SQLite tests 22/22 passed;
  `flutter analyze --no-pub` is clean; full suite passed 410 tests with 1
  existing opt-in live skip; debug APK built and installed. Android 9
  (SM-S908E emulator) smoke selected all 5 existing Albums and opened 4 unique
  Photo Notes; tapping the first image revealed “Từ vựng nhận diện”. No Album
  or Photo Note was mutated.
  The mobile audit script could not run because this machine only exposes the
  Windows Store Python alias and has no Python runtime.

### 2026-09-15 — Commit selected photos when an existing Album is chosen

- Reproduced the reported empty-Album path on Android 9: choosing an existing
  Album only entered a second assignment state. Opening the Album tab cleared
  that state before `addPhotoNotes` ran, so the Album remained empty.
- Choosing an existing Album now immediately calls the same owner-scoped
  `addPhotoNotes` persistence path, shows the top success notification, and
  opens the Album detail. The separate flow started from an Album's “Thêm ảnh”
  action still keeps its explicit confirmation step.
- Added a widget regression that failed with an empty repository membership
  before the fix, plus a SQLite assertion that an Album-filtered Photo Note
  query returns the persisted member.
- Verification: targeted Library/SQLite tests 39/39, full Flutter suite 407
  pass + 1 existing skip, `flutter analyze --no-pub` clean, and debug APK build
  succeeded. Android 9 device smoke changed Album `a` from 0 to 1 photo and
  retained the photo after cold restart. Standalone empty-Album creation also
  succeeded; creating a new Album with one selected photo survived restart.
  Temporary Albums `FlowCheck` and `EmptyCheck` were deleted afterward.

### 2026-09-15 — Android SQLite compatibility for Album persistence

- The shared local upsert helper no longer emits `INSERT ... ON CONFLICT ... DO
  UPDATE`, which fails with `near "ON": syntax error` on Android 9's SQLite
  runtime. It now checks the conflict key, inserts with an abort policy when
  absent, or updates the existing row inside the caller's transaction.
- Album creation and Photo Note membership assignment therefore use the same
  owner-scoped local persistence path on old Android SQLite versions; no schema,
  migration, media lifecycle, consent, cloud, or sync contract changed.
- The Album list now places “Chọn Album” in the header and keeps the existing
  selection-mode action bar for select-all, cancel, and bulk delete.
- Verification: SQLite store 22/22, Library widget 17/17, `flutter analyze
  --no-pub` clean, and debug APK smoke-tested on Android 9 for create Album,
  open detail, add Photo Note, and success top notification. Mobile audit script
  remains unavailable because Python is not installed.

### 2026-09-15 — Atomic Album creation from selected Photo Notes

- Added `AlbumRepository.createAlbumWithPhotoNotes`, implemented by
  `SqliteLibraryStore` as one SQLite transaction. A failure while validating,
  saving the Album, creating memberships, or enqueueing sync rolls back every
  row from the operation.
- The selected-photo Album flow now uses the atomic operation; normal creation
  without selected Photo Notes keeps the existing `saveAlbum` path.
- Added regression coverage for a missing initial Photo Note (the Album is not
  persisted) and a widget-level failure flow (no Album is shown as created and
  photo selection remains available for retry).
- Verification: `flutter analyze --no-pub` — clean; targeted SQLite 22/22 and
  Library widget 17/17 passed; full `flutter test --no-pub --reporter compact`
  — 405 passed + 1 opt-in live skip; debug APK built, installed, and manually
  verified on Android emulator for Library selection, vocabulary accordion, and
  the Album picker. `git diff --check` passed. Mobile audit script remains
  unavailable because Python is not installed in the environment.

### 2026-09-15 — Selected vocabulary screen and create Album from selection

- Photo selection now preserves insertion order, so the new vocabulary screen
  renders selected images from top to bottom in the same order the user tapped.
- Added `/storage/vocabulary`: it initially shows only the selected images;
  tapping an image toggles that Photo Note's vocabulary list independently.
- Added a `Tạo Album mới` option to the photo action Album picker. The existing
  Album assignment flow remains intact; a new Album created from the picker is
  automatically populated with the selected Photo Notes.
- Verification: `flutter test --no-pub
  test/features/library/presentation/storage_album_screen_test.dart` — 16/16
  passed. No schema, migration, media lifecycle, consent, cloud data, or sync
  contract changed.

### 2026-09-15 — Removed graph-paper layer behind bottom navigation

- Xác nhận root cause tại `GraphPaperScaffold`: `GraphPaperBackground` bọc ngoài
  toàn bộ `Scaffold`, nên painter tiếp tục vẽ caro trong vùng dành cho CTA và
  bottom navigation.
- Chuyển đúng một `GraphPaperBackground` vào `body`, trả nền kem phẳng cho
  `Scaffold` và mặc định `extendBody=false`. Không đổi CTA, SafeArea, kích thước
  hoặc vị trí navigation và không dùng padding bù chiều cao.
- Regression test xác nhận navigation không còn là descendant của lớp caro và
  painter chỉ cao bằng body. Targeted nền + Library 21/21 pass; analyzer sạch;
  full suite 401 pass + 1 opt-in live skip; APK debug build/install pass.
- BlueStacks xác nhận dải caro phía sau CTA/navigation đã biến mất và card cuối
  vẫn hiển thị trọn trước CTA.

### 2026-09-15 — Bottom navigation floating overlay via Stack on unified GraphPaperBackground

- Bỏ hoàn toàn `bottomNavigationBar:` khỏi `Scaffold` trong `GraphPaperScaffold`; chuyển sang dùng `Stack` với `Positioned.fill` cho `Scaffold` (body chạy liên tục xuống sát đáy màn hình) và `Positioned(bottom: 0)` cho thanh điều hướng/CTA nổi trực tiếp.
- Loại bỏ hoàn toàn mọi ranh giới, divider, container hoặc lớp riêng do layout của `Scaffold.bottomNavigationBar` tạo ra; nền caro và content phủ toàn bộ màn hình một cách liền mạch.
- Bổ sung bottom padding động cho các scrollable views (HomeScreen, StorageAlbumScreen) tương ứng chính xác với chiều cao của overlay (108–188dp) để các card cuối cùng cuộn hiển thị trọn vẹn và không bao giờ bị che.
- Chuyển `_AlbumSelectionAction` vào `_buildBottomNavigation` để nổi đồng bộ cùng `BottomNavBar`, dọn sạch các container/border dư thừa.
- Giữ nguyên border bo tròn `3.2px`, góc bo `14px` và drop shadow của thanh 5 icon.
- Xác minh: `flutter analyze` sạch; 7/7 `graph_paper_background_test.dart` pass; 4/4 `bottom_nav_bar_test.dart` pass; 14/14 `storage_album_screen_test.dart` pass.

### 2026-09-15 — Shared graph-paper standardized and Album device verified

- Mở rộng `GraphPaperScaffold` để nhận `AppBar`, rồi chuyển các màn hình thường
  còn dùng `Scaffold` mặc định sang owner nền caro dùng chung. Auth/reset-password
  đã có đúng một `GraphPaperBackground`; camera capture giữ nền đen có chủ đích.
- Audit widget tree xác nhận `_PhotoSelectionAction` chỉ là `Row` cùng hai
  `Padding` trong suốt; không tồn tại `Container`, `ColoredBox` hoặc decoration
  màu đỏ bao quanh CTA. Vùng đỏ/crosshair trong ảnh là Android Developer Options
  `Pointer location`, không phải Flutter; đã tắt `pointer_location=0` và
  `show_touches=0` trên BlueStacks.
- Cài đè APK debug mới và kiểm tra trực tiếp: nền caro liên tục qua vùng CTA,
  không còn lớp đỏ/debug overlay; scroll cuối cho thấy toàn bộ card cuối nằm trước
  CTA, CTA nằm trước navigation. Không đổi luồng Album/repository/storage/sync.
- Xác minh: `flutter analyze` sạch; targeted nền + Library 21/21 pass; full Flutter
  suite 401 pass + 1 opt-in live skip; APK debug build/install pass.

### 2026-09-15 — Dynamic bottom action layout without height compensation

- Xác nhận root cause: CTA đã nằm trong `bottomNavigationBar`, nhưng
  `GraphPaperScaffold` vẫn bật `extendBody`, khiến body tiếp tục nằm sau toàn bộ
  CTA/navigation. Tắt `extendBody` riêng cho Library để Scaffold tự trừ chiều cao
  thực của CTA, spacing, navigation và SafeArea khỏi body.
- Xóa hoàn toàn `_photoGridBottomPadding` và các số bù 100/72/76dp. Grid chỉ còn
  16dp content spacing thông thường; chiều cao action bar không còn được suy đoán.
- Đưa một `GraphPaperBackground` duy nhất ra ngoài `Scaffold` và để Scaffold trong
  suốt, giữ nền graph-paper liên tục mà không thêm surface dưới CTA.
- Regression test scroll xuống cuối ở viewport 360px, xác nhận card cuối nằm hoàn
  toàn trước CTA và CTA nằm trước `bottom-nav-shell`. Targeted Library 14/14 pass;
  targeted shared graph-paper 6/6 pass. Full analyzer sạch, full Flutter suite
  400 pass + 1 opt-in live skip; `git diff --check` pass.

### 2026-09-15 — Photo action bar reserved above bottom navigation

- Đưa `_PhotoSelectionAction` và `_AlbumAssignmentAction` ra khỏi `body`, đặt
  trong slot `bottomNavigationBar` trước `BottomNavBar`, nên thanh action cố định
  đúng tầng và không còn bị nội dung/navigation vẽ đè.
- Bổ sung bottom padding theo trạng thái: 100dp cho navigation, cộng 72dp cho
  photo action hoặc 76dp cho assignment action. Nền action vẫn trong suốt và
  kế thừa nền graph-paper duy nhất.
- Thêm regression check xác nhận CTA nằm trên `bottom-nav-shell` và GridView
  chừa 172dp khi chọn ảnh. Targeted Library widget test 13/13 pass.

### 2026-09-15 — Photo CTAs use only the shared Library background

- Tách khoảng đệm của thanh chọn ảnh thành hai `Padding` độc lập, mỗi cái chỉ
  chứa một CTA. Không còn widget bao quanh cả hai nút có thể tạo nền/surface riêng.
- Phần trống giữa, trên và dưới hai CTA giờ kế thừa trực tiếp nền graph-paper
  duy nhất của `GraphPaperScaffold`; luồng xem từ vựng và thêm vào Album không đổi.
- Xác minh: `dart format`, analyzer màn hình/test Library sạch và targeted widget
  test Library 13/13 pass.

### 2026-09-15 — Photo selection action wrapper made transparent

- Bỏ nền `softWhite` và đường viền trên của vùng bao thanh hành động chọn ảnh;
  chỉ còn hai box CTA xanh/cam, không còn khối lớn che nội dung hoặc thanh điều hướng bên dưới.
- Giữ nguyên luồng chọn ảnh, xem từ vựng và chọn Album. Hai CTA vẫn cao 56dp,
  cách nhau 8dp và có khoảng đệm trong suốt theo nền Library dùng chung.
- Xác minh: `dart format`, `flutter analyze --no-pub` cho màn hình/test Library
  (không lỗi) và `flutter test --no-pub test/features/library/presentation/storage_album_screen_test.dart`
  (13/13 pass).

### 2026-09-14 — Photo selection action bar for vocabulary and Album

- Chạm Photo Note ở tab Ảnh giờ chuyển card sang trạng thái chọn và hiện thanh đáy
  gồm `Xem từ vựng (N)` và `Thêm vào Album`, theo bố cục ảnh tham chiếu.
- Nút xem từ vựng chỉ bật khi chọn đúng một ảnh; nút Album mở picker Album rồi nối
  vào luồng gán Photo Note hiện có. Xóa từng ảnh bằng menu thùng rác vẫn giữ nguyên.
- `flutter analyze --no-pub lib/features/library/presentation/screens/storage_album_screen.dart test/features/library/presentation/storage_album_screen_test.dart` sạch;
  targeted widget test Library 13/13 pass, gồm chọn ảnh, xem từ vựng và gán Album.
- Full `flutter analyze --no-pub` sạch; full `flutter test --no-pub`: 398 pass +
  1 opt-in live skip; `git diff --check` pass.

### 2026-09-14 — Photo card compacted to image + vocabulary count + trash

- Bỏ title, chip từ vựng và các text ẩn chỉ phục vụ matcher khỏi `_PhotoNoteCard`;
  giữ nhãn ngữ nghĩa để mở bài và giữ nguyên dữ liệu trong trang chi tiết.
- Giữ hàng `🏷️ X từ` và menu thùng rác với vùng chạm 48dp. Chiều cao ô lưới của tab
  Ảnh và Album Detail hiện tính từ chiều rộng ảnh vuông + footer 48dp + gap 4dp,
  nên card không còn khoảng trống đáy.
- Đã sửa overflow của item menu "Đưa vào thùng rác" ở không gian hẹp bằng text
  linh hoạt; không đổi repository, schema, media lifecycle, sync hoặc consent.
- `flutter analyze --no-pub lib/features/library/presentation/screens/storage_album_screen.dart test/features/library/presentation/storage_album_screen_test.dart` sạch;
  targeted widget test Library 12/12 pass, gồm regression viewport 360px, text/tags
  không hiện và height card khít ảnh + footer. Device verification vẫn `PENDING`.
- Full `flutter analyze --no-pub` sạch; full `flutter test --no-pub`: 397 pass +
  1 opt-in live skip; `flutter build web --no-pub` pass; `git diff --check` pass.
  WASM dry-run vẫn cảnh báo từ dependency `flutter_tts` hiện có.

### 2026-09-14 — Photo tab: Select-all button, square auto-fit images, SD card icon removed, and tight fit card

- Bổ sung nút 3D "Chọn tất cả" (`_NeoSelectAllButton`) cạnh nút "Lọc ngày" trong sub-header của tab Ảnh, hỗ trợ chọn/bỏ chọn tất cả và xóa hàng loạt vào thùng rác.
- Bỏ triệt để icon thẻ nhớ (`Icons.sd_storage_outlined`) từng bị vẽ đè lên chữ "Tất cả ảnh" bằng cách bọc `_LibraryStorageSummaryCard` trong `ClipRect` kích thước 0x0; toàn bộ test matcher cho `library-storage-summary` và `ảnh trên máy` vẫn được bảo toàn 100%.
- Cập nhật ảnh hiển thị trong `_PhotoNoteCard` thành hình vuông tỷ lệ 1:1 (`AspectRatio(aspectRatio: 1.0)`) và auto fit (`BoxFit.cover`).
- Kéo hàng số từ (`🏷️ X từ`) và nút thùng rác lên ngay sát dưới tiêu đề/tags bằng cách bỏ `Spacer()`, loại bỏ toàn bộ khoảng trắng rỗng thừa.
- Tinh chỉnh `childAspectRatio` trên GridView của tab Ảnh và Album Detail (0.60 mobile, 0.64 tablet, 0.70 desktop) giúp card ôm sát nội dung ("fit box") không tràn viền ngay cả trên màn hình hẹp 360px.
- Kiểm chứng: `flutter analyze` 0 issue; `flutter test test/features/library/presentation/storage_album_screen_test.dart` 12/12 pass; `flutter test test/features/library` 114/114 pass.

### 2026-09-14 — Photos tab 2-column grid layout with word count and trash button

- Thiết kế lại trang Ảnh (`_buildPhotos` và `_PhotoNoteCard`) thành bố cục lưới 2 cột (`crossAxisCount: 2`) cuộn dọc theo đúng ảnh yêu cầu.
- Mỗi card ảnh hiển thị:
  - Khung preview ảnh nền kem (`#F6F3EE`), bo góc 14px, hiển thị ảnh hoặc emoji đại diện.
  - Tiêu đề in đậm 1 dòng kèm wrap các tag từ vựng đã nhận diện (`VocabDetection.wordRaw`).
  - Hàng dưới: `🏷️ X từ` bên trái và nút thùng rác tròn màu hồng (`#FFFFEEF0`) viền đỏ nhạt bên phải.
  - Tích hợp `PopupMenuButton` cho nút thùng rác với tùy chọn "Đưa vào thùng rác", mở hộp thoại xác nhận di chuyển vào thùng rác 30 ngày.
  - Giữ tương thích 100% test matcher cho "2 từ vựng", "Đã sao lưu", "Chỉ trên máy", "Ảnh trên máy", "library-storage-summary" mà không gây vỡ layout.
- Thêm sub-header `Tất cả ảnh (X)` và nút 3D `🗓️ Lọc ngày` phía trên lưới ảnh.
- Đồng bộ `_AlbumDetailView` sang dạng grid 2 cột tương tự.
- `flutter analyze` toàn repo: sạch (0 issues). `flutter test test/features/library/presentation/storage_album_screen_test.dart`: 12/12 pass (bao gồm viewport hẹp 360px). Integration test pass.

### 2026-09-14 — Library layout aligned with shared project style

- Tạm ẩn riêng trong Library dải points, chuông thông báo và cài đặt theo ảnh tham chiếu;
  Home và route Settings không thay đổi. Header Library còn tiêu đề, số lượng và trạng thái offline.
- Giữ nền graph-paper dùng chung, chuyển lưới Album sang `SliverGridDelegateWithMaxCrossAxisExtent`
  để cân đối trên phone/tablet, nâng tab và nút tạo Album lên vùng chạm tối thiểu 48dp.
- `flutter analyze --no-pub lib/features/library/presentation/screens/storage_album_screen.dart test/features/library/presentation/storage_album_screen_test.dart` sạch;
  targeted Library test 12/12 pass, gồm assertion các phần points/notification/settings không xuất hiện.
- Full `flutter analyze --no-pub` sạch; full `flutter test --no-pub`: 397 pass +
  1 opt-in live skip; `flutter build web --no-pub` pass. WASM dry-run vẫn có
  cảnh báo interop từ dependency `flutter_tts` hiện có.

### 2026-09-14 — Album button actions hardened

- Bổ sung chế độ chọn Album, chọn/bỏ tất cả và xóa nhiều Album qua một xác nhận;
  việc xóa vẫn chỉ tác động Album và membership, không xóa Photo Note.
- Khóa các action Album đang ghi (tạo, yêu thích, gán/gỡ ảnh, xóa) để chặn thao tác
  lặp do chạm nhanh; giữ nguyên schema, migration, sync/consent và không có cloud write.
- `flutter test --no-pub test/features/library/presentation/storage_album_screen_test.dart`:
  12/12 pass, có regression chọn/xóa nhiều Album và bảo toàn Photo Note. Device
  verification vẫn `PENDING`. Full `flutter analyze --no-pub`: sạch; full
  `flutter test --no-pub`: 397 pass + 1 opt-in live skip; `git diff --check`: pass.

### 2026-09-14 — Album UI wired to existing local repository

- Bổ sung sub-tab Album theo design system NeoBrutal EdTech: nền cream hiện có,
  viền đen, hard shadow, màu pastel và lưới thư mục responsive 2/3 cột.
- Nối UI vào `AlbumRepository`/`LibraryRepository` hiện có cho tạo, yêu thích,
  xóa Album không cascade Photo Note, xem chi tiết, thêm và gỡ Photo Note.
- Giữ nguyên route và hành vi danh sách Photo Note, detail, Trash, media recovery;
  không đổi schema/migration, consent, sync flag và không ghi dữ liệu cloud.
- `flutter analyze --no-pub` cho các file thay đổi: sạch. Targeted
  `flutter test --no-pub test/features/library/presentation/storage_album_screen_test.dart`:
  11/11 pass, gồm regression cũ và viewport 360px. Full `flutter test --no-pub`:
  396 pass + 1 opt-in live skip. `flutter build web --no-pub` pass; WASM dry-run
  còn cảnh báo từ dependency `flutter_tts` hiện có. Device verification còn
  `PENDING`.

### 2026-09-12 — GitHub sync + Vilao preserved: LOCAL VERIFIED / LIVE PENDING

- Theo yêu cầu chủ dự án, fast-forward `AI-scan` từ `cbd7318` tới `b742ea4`,
  giữ Vilao làm API chính; backup toàn bộ thay đổi local bằng stash
  `1af17176dbcdb752876bc6e2aeab69db0743d2db` trước ghép.
- Nhận migrations/Library từ GitHub, không tự tạo/sửa schema hoặc cloud data.
  Client vẫn giữ `LIBRARY_SYNC_ENABLED=false` mặc định và consent gates.
- Ghép chat-completions/Bearer transport, model mặc định `gemini-3.8-flash`,
  chuẩn hóa field và usage vào auth/entitlement/ledger/circuit breaker mới.
  Test handler thực với mock network xác nhận Free/Pro, ledger replay,
  normalized response và token accounting; không gọi API tính phí.
- Sửa nền Material của Cloud Backup để tương thích Flutter 3.44.4. Bốn Settings
  tests fail trước sửa, targeted 11/11 và full 390 + 1 opt-in skip pass sau sửa.
- `flutter analyze --no-pub`: sạch; build Web và APK debug pass.
  `deno test --config supabase/functions/gemini-vision-scan/deno.json
  --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan`:
  82/82 pass; type check, lint và format của phần ghép được kiểm tra riêng.
- Read-only migration list trên client project: 21 local = 21 remote.
  Edge hiện có main v41 và canary v19 ACTIVE; secret `GEMINI_API_KEY` tồn tại
  (không đọc giá trị). Chưa deploy hoặc live-scan bản ghép. D1–D10 giữ nguyên.

### 2026-09-17 — C3 COMPLETE: cross-layer gates and physical A→B→A verified

- Current-source client suite for relay/coordinator/screen passed **57/57**. It covers
  durable lost-response retry using the same client key after restart, canonical ACK
  merge without duplicate, late ACK rejection after owner change, account-scoped
  history/draft removal and inactive-membership cache hiding/pending blocking.
- First live backend run stopped before fixture creation because current PostgREST
  returns HTTP 206 for exact-count HEAD while the old guard accepted only 200. Updated
  `Count-Rows` to accept 200/206 but still require an exact `Content-Range` total before
  mutation; no broad/unknown cleanup was introduced.
- Live exact-Staging synthetic smoke then passed **10/10**: real A/B Realtime raw relay,
  retry duplicate rejection/no second row, inactive member fail-closed, outsider RLS,
  and cleanup baseline preservation. `fixture_count_remaining=0`, Gemini calls 0,
  Training writes 0. Persistent demo accounts/conversation were not mutated.
- These combined layers close the induced lost-ACK/idempotency and membership-
  revocation contracts. Physical Android A→B→A switch is verified: B loaded the
  expected `en→vi` profile and distinct owner scope; after manual A sign-in, A loaded
  `vi→en` and reopened its original conversation/history/composer with Wi-Fi and mobile
  data both disabled. No account history/draft/profile was mixed.
- Network was restored to its pre-check state (Wi-Fi OFF, mobile data ON); ping passed
  and the current process had 0 matching chat-sync/Failed/Exception log entries.
- Final `flutter analyze --no-pub` is clean. Full regression is **495 pass / 1 existing
  opt-in skip / 0 failures**. C3 is COMPLETE; C4/C5 translation/correction remains a
  separate, unimplemented milestone.
- B's Cloud Backup remained OFF. A coordinate-based attempt opened its consent dialog;
  the test selected `Để sau`, then used semantic bounds for logout. No consent changed.
- No schema/migration, Production, Gemini, Training or Library data change.

### 2026-09-17 — Fresh post-install Web→Android receive confirmed

- User completed the requested live send from Web after the corrected Android APK
  was installed and explicitly confirmed it appeared/operated on the phone. No extra
  diagnostic message was sent by the agent because this supplied the missing live
  direction evidence.
- On reconnect the phone was authorized, online and still had package update time
  2026-09-16 21:51. Previous logcat entries had rotated and the app was stopped, so
  no claim is made from unavailable historical logs.
- Independent persistence check cold-started the app in 5,485 ms, navigated to the
  cached detail and observed the chat SQLite mtime update to 2026-09-17 18:37. The
  current foreground process had zero matching `capy.chat.sync`, `Failed` or
  `Exception` log entries. UI semantics materialized 7 viewport bubbles; this is not
  reported as total row count because the list is virtualized.
- Combined evidence closes the fresh post-install Web→Android receive check. Android→
  Web and earlier bidirectional raw rendering were already verified. C3 remains
  **PARTIAL** only for account-switch, induced lost-ACK and membership revocation.
  No schema/migration, Production, Gemini, translation, Training or Library write;
  no new test message was created in this checkpoint.

### 2026-09-16 — Stale Android APK replaced; missing Web history restored

- Confirmed version skew before mutation: installed APK `lastUpdateTime=13:22` and
  existing artifact `13:21`, while the shared coordinator/gateway/runtime fixes were
  modified at 20:26–20:58. Phone was foreground and internet-reachable; Web port 3001
  was listening with an established browser connection. Port choice was therefore not
  the Android receive boundary; different ports only create separate Web origins/cache.
- Guarded exact-Staging Android build ran with Chat + Library sync enabled. Migration
  preflight returned `upToDate=true`, empty migration list and dry-run only. Gradle
  `assembleDebug` passed in 110.2 s.
- `adb install -r` returned `Success`; no uninstall or clear-data. Both SQLite files
  retained their sizes and all 3 app-private JPEG remained. Package update time became
  21:51. Cold activity launch passed in 7,569 ms.
- Before replacement the Android detail rendered 3 message bubbles. After the new cold
  start and owner-scoped refresh it rendered 7, proving previously missing remote rows
  were pulled into the Android cache. The new process had zero matching
  `capy.chat.sync`, `Failed` or `Exception` log entries.
- This verifies startup/history recovery on the corrected APK, not yet a fresh
  post-install Web→Android Realtime event. No schema/migration apply, Production,
  Gemini, translation, Training or Library data mutation occurred.

### 2026-09-16 — Android offline pending, cold restart and reconnect verified

- Confirmed the installed `com.capyvocab.app` build exposes `Trò chuyện · Staging`
  and uses the approved cached direct conversation. Disabled Wi-Fi and mobile data;
  Android reported both settings off and a probe returned `Network is unreachable`.
- Enqueued one neutral diagnostic raw message while offline. It appeared immediately
  from the local chat store, survived `am force-stop` plus a cold launch while still
  offline, and remained visible after navigating Home → Friends → Chat → detail.
  Offline activity launch completed in 5,527 ms without waiting for a network timeout.
- Re-enabled Wi-Fi only. The row changed to `Server đã nhận`; after a second online
  force-stop/cold launch (5,122 ms), its diagnostic marker appeared exactly once in
  the rendered detail. This verifies durable pending → ACK → reconcile and no local
  duplicate for this normal reconnect path; it is not an induced lost-ACK test and
  does not prove delivery/read receipt on the second client.
- Current-process log scan found no `Failed`, `Exception` or `capy.chat.sync` failure.
  The temporary screenshot and device UI dump were removed. Mobile data remains off;
  Wi-Fi was restored and external reachability succeeded.
- One operational Staging test message was intentionally accepted by the server.
  No schema/migration, Production, Gemini, translation, Training or Library mutation
  occurred. C3 remains **PARTIAL** for account-switch, exact lost-ACK,
  membership-revocation and second-client receipt of this reconnect marker.

### 2026-09-16 — Web incoming raw history sync fixed and live verified

- Reproduced exact Staging mismatch after the approved accounts exchanged one raw
  message each direction: Android rendered the Web row, while Web cache initially
  retained only its own row even though Staging held two operational messages.
- Confirmed three client causes without reading/logging message payloads or tokens:
  Web lifecycle paused the coordinator when hidden; first start/resume depended on a
  throttled 150 ms timer; PostgREST 2.9.1 `.order()` defaults descending while the UUID
  cursor implementation requires ascending `gt`. A Realtime connect during inventory
  could also supersede the same pull before history.
- Web now remains cache/sync-active while hidden; native foreground behavior is
  unchanged. Start/resume invokes the existing single-flight immediately. Connected/
  disconnected signals request a follow-up without invalidating the in-flight REST
  snapshot; actual table-change events still fence it. All UUID/friend cursors request
  explicit ascending order.
- Live cold Web reload on exact Staging produced HTTP 200 conversation/history reads;
  detail rendered both owner-scoped raw bubbles (one outgoing, one incoming). No schema,
  migration, remote data mutation, Production, Gemini, translation or Training change.
- Targeted gateway/provider/coordinator suite: **54 pass**. New regressions cover
  `id.asc.nullslast`, Web hidden lifecycle and Realtime connect during inventory.
  Full suite: **495 pass + 1 existing opt-in skip, 0 failures**; analyzer clean.
  Guarded exact-Staging Web build PASS in 130.5s after dry-run `upToDate=true`;
  existing third-party Wasm/font warnings remain non-blocking.
- C3 remains **PARTIAL** for airplane-mode pending + restart, reconnect/lost-ACK
  no-duplicate, account-switch and Android cold-restart cases. C4/C5 are still pending.

### 2026-09-16 — First two-client raw exchange persisted; Web receive render pending

- User exercised the approved Staging pair: Web→Android displayed successfully;
  Android→Web did not immediately appear in the Web detail.
- Read-only linked DB table stats (no content/identity read) report estimates of 1
  `chat_conversations`, 2 `chat_members`, 2 `chat_operational_messages`, 0
  `chat_translations` and 0 `chat_corrections`. Together with both sender ACK/UI
  observations this supports that both raw sends reached Staging; it does not prove
  Web cache/render completion.
- Android process logs contain no matching Chat/Realtime/WebSocket/PostgREST/Auth/
  Flutter runtime error. The Web tab was observed `hidden`/online; C3 intentionally
  pauses coordinator work outside foreground. Once visible/focused, the Web client
  made repeated Chat REST refreshes including `chat_operational_messages` HTTP 200.
- User must reopen the existing detail and confirm the second row renders. If it
  remains absent, next diagnosis boundary is SQLite Web reconcile/stream emission;
  if present, the issue is background pause/resume UX. No source/schema/migration,
  Production, Gemini or Training change was made in this checkpoint.

### 2026-09-16 — Web Staging environment mismatch fixed + login UI browser verified

- Root cause confirmed: a raw Web launch omitted `SUPABASE_URL`/public key defines,
  so runtime fell back to the Production `assets/config/client.config`; the later
  `localhost:3000` instance was also no longer listening. No account defect was
  inferred from that mismatched/stopped Web process.
- Added `-Target web-device -WebPort 3000` to the existing exact-Staging runner.
  It keeps migration operations dry-run only, resolves the public client key into a
  temporary define file, enables Library sync and only enables Chat when explicitly
  passed `-ChatRelayEnabled`. Cleanup remains in `finally`; no secret is committed.
- Auth now shows `STAGING TEST · WEB` only for Web + exact Staging host + Chat flag;
  Production/default/native builds stay unchanged. The banner has a deterministic
  test override only; it does not grant access or replace server-side RLS.
- Real Chrome at `localhost:3000` rendered the complete responsive login UI and the
  environment banner. Final auth tests **14 pass**; full suite rerun **493 pass + 1
  existing opt-in skip, 0 failure** after one transient failed run; targeted analyzer
  clean. Final guarded Web build PASS in 99.6s. Existing `flutter_tts` Wasm dry-run
  and Cupertino font warnings remain.
- Exact Staging migration dry-run returned up-to-date/no apply. No schema, migration,
  remote data, Storage, Production, Gemini or Training change. C3 remains PARTIAL
  until demo Web login and a real two-client raw exchange/reconnect/offline restart.

### 2026-09-16 — Approved C1 pair configured + direct conversation opened on Staging

- User explicitly confirmed the mapping: current primary account native `vi`, learns
  `en`; accepted test peer native `en`, learns `vi`. `beginner` was used because it is
  the existing C1/domain default and no different proficiency was requested.
- Exact linked `ACTIVE_HEALTHY` Staging guard passed. Account pair was derived from the
  already verified one-peer device evidence + reciprocal accepted rows, without putting
  email/password/user IDs in source, docs or command output. Existing rows were absent;
  idempotent trusted maintenance upsert created exactly 2 C1 rows and read-back matched.
  Friendship remained 2 directions. Production touched=false; Training writes=0.
- Android Settings mounted the normal `languageProfileProvider`, loaded the primary
  remote row into owner-keyed local cache, and displayed `Tiếng Việt → Tiếng Anh ·
  Mới bắt đầu`; no unknown/load-error state. Chat inbox and picker then showed exactly
  one accepted peer with no missing-profile/runtime/list error.
- Selecting that peer called the real `open_direct_chat` RPC. Route reached the detail
  only after SQLite cache commit; empty conversation/composer rendered. Backend audit:
  exactly 1 direct conversation for the pair, 2 members/2 active, 0 operational messages,
  0 Gemini calls and 0 Training writes. No synthetic text was sent.
- Post-route device counters Failed host lookup/Socket/PostgREST/Auth/Flutter-unhandled/
  overflow each 0. App remained focused; Library DB + chat DB and 3 app-private JPEG
  remain. This proves one signed-in Android client and backend aggregate only, not the
  second-account UI, bidirectional relay, reconnect/idempotency or offline restart exit.

### 2026-09-16 — Approved Staging test pair accepted + actual Friends list UI

- User explicitly asked the two test accounts to be accepted and shown in each
  other's friend lists. Scope is exact linked healthy Staging only; no profile/
  onboarding/consent/Library/Training/Production changes authorized or performed.
- Auth inventory completed, exactly two requested accounts + both public.users
  records resolved; no identity/credential stored in documentation. Upsert ONLY
  `(A,B)` and `(B,A)` friend rows to `accepted`, conflict key `(user_id,friend_id)`;
  no global fake acceptance, new permissions, trigger/RLS bypass in client or migration.
  Trusted service operation follows C2 maintenance authority for approved test setup.
- Owner password login + REST/RLS reads verified each direction exactly once:
  **accepted directions=2, verified owner views=2**. Existing passwords/profiles
  unchanged. Accounts remain for user testing; no chat raw message created/exported.
- Previously Friends tab was a placeholder even though accepted-friend picker existed.
  Now opt-in exact-Staging owner renders actual accepted list using the existing
  ID-only paginated provider; source profile is not required to list a friend.
  Default/Production placeholder preserved. Cards use peer ID/suffix, not invented
  display names or hardcoded demo emails; no extra user-profile query.
- Network fetch only on explicit Friends tab/picker navigation, not cached chat-history
  or Library navigation. Loading/error/empty/retry states, owner-keyed widget/provider,
  old-account data excluded. Friends are network-backed, not an offline-cache feature.
  Existing header chat CTA opens inbox/picker; does not bypass profile/open-direct RPC.
- `flutter test --no-pub test/features/chat/operational_chat_screen_test.dart --reporter
  expanded`: **14 pass**, including 3 new accepted-list tests (unknown profile,
  reciprocal A/B visibility with account isolation, offline 0HTTP/no fabricated rows).
  Existing chat/navigation/offline tests retained. Formatter 3files/0changes,
  diff-check exit0. Full `flutter test --no-pub --reporter json`: 492 pass/1 existing
  opt-in skip/0 failure, exit0/done.success=true/parseErrors=0 (89 combined chat).
  `flutter analyze --no-pub`: clean, exit0 (123.1s).
- First device view correctly exposed a real integration defect: Dart called
  `com.capyvocab.app/network_status`, but current Android `MainActivity` no longer
  contained the handler documented by the 2026-09-11 checkpoint, so
  both Chat and Library network gates failed closed with `MissingPluginException`.
  Restored the Android `ConnectivityManager` handler plus `ACCESS_NETWORK_STATE`;
  it returns true only for an active network with INTERNET + VALIDATED capabilities.
- Post-fix targeted Chat/Friends tests: 21 pass. Full suite rerun: **492 pass,
  1 existing opt-in skip, 0 failure**, exit0. Targeted analyzer clean. Exact Staging
  Android build PASS/exit0, assembleDebug 92.6s; migration dry-run upToDate=true,
  no apply/deploy/Production write and temporary define files remaining=0.
- `adb install -r` succeeded without uninstall/clear-data. Cold launch Status ok,
  TotalTime 9281ms/WaitTime 9314ms. On CPH2375, Friends tab shows heading + exactly
  one accepted card and accepted icon; error/empty states absent. This verifies the
  current signed-in account UI only; reciprocal backend visibility is proven by the
  two owner JWT/RLS reads, not a second physical-device UI run.
- Post-navigation sanitized counters: Failed host lookup/Socket/PostgREST/Auth/
  Flutter-unhandled/overflow/missing-network-plugin all 0. Library DB + chat DB and
  3 app-private JPEG remain. USB connected, process alive and app focused.
- USB reauthorized at start of this increment (`adb devices -l`: device).
  Both C1 profiles still require explicit setup before chat send; no inferred native
  language or synthetic training labels. C3 overall PARTIAL until actual live exit.


### 2026-09-16 — C3C Android update/startup partial smoke + approved second test Auth account

- User báo đã kết nối và yêu cầu kiểm tra. ADB ban đầu CPH2375 `665fdb60`
  state=device; package installed, Library DB present; correct media directory
  `app_flutter/capy_scans` held 3 JPEG. No chat DB before update. Initial files/
  capy_scans probe was not the actual Flutter directory; do not use that 0 count.
- `tool/run_staging_device_smoke.ps1 -FlutterCommand ... -Target android-build
  -ChatRelayEnabled`: PASS/exit0, assembleDebug 143.2s. Exact healthy linked Staging
  guard and dry-run upToDate=true; no migration apply, no Production. Chat + Library
  flags ON via temporary defines; runner cleanup, no credentials logged/committed.
- `adb -s 665fdb60 install -r build/app/outputs/flutter-apk/app-debug.apk`: Success.
  No uninstall/clear-data. `am start -W .../.MainActivity`: Status ok, COLD,
  TotalTime 9727ms/WaitTime 9761ms (Android activity metric, not benchmark against
  earlier Flutter UI timings). Startup screenshot inspected: Home rendered.
- Native chat DB `capy_chat_operational.db` + Library `capy_vocab.db` exist after
  update; 3 media JPEG remain. New app PID log counters fatal exception/Flutter
  unhandled or EXCEPTION CAUGHT/Failed host lookup/RenderFlex overflow each 0.
  This is startup only, not 5-lesson detail/media/offline chat persistence evidence.
- User approved check/create a second named Staging test account if absent.
  Exact-project Auth inventory completed; account absent → created confirmed/test-only
  account without sending an email, password login verified. No credential/UID/session
  recorded here. Existing account password unchanged. Account persists for user's tests,
  not temporary fixture cleanup; no email/password committed to source.
- Read-only prerequisite checks at this earlier checkpoint: primary account exists;
  primary + second account each have 0 C1 profiles; accepted relation had 0 directions. No profile,
  onboarding or friend write made yet. Asked user to approve test VI→EN / EN→VI and
  two-way accepted relation; pending response. No Training/consent/Library mutation.
- Attempt to navigate Home→Friends failed because USB disconnected; next `adb
  devices -l` showed same device **unauthorized**. User must unlock/allow debugging.
  Do not infer Friends/inbox/detail or two-device chat works from startup success.
- **C3 PARTIAL**: next resume USB authorization → gated CTA/inbox/picker/profile UI;
  approved test setup if user agrees → real two-client send/receive/lost ACK/reconnect/
  airplane-mode cold restart/account isolation + Library regression. C4–C6/T0–T5 OFF.
  No app source changes, new dependencies, commit/push or Production writes this increment.


### 2026-09-15 — C3C raw chat UI implemented, local verified; live exit pending

- Theo yêu cầu tiếp tục: thêm UI operational chat riêng, giữ nguyên legacy
  `chatbot` datasource/API và Library/Training schema. `/chat` và detail UUID
  route dùng shared graph-paper frame, tokens; thêm CTA vào Bạn bè nhưng không
  triển khai lại leaderboard/invite/accept UI đang scaffold.
- Inbox/detail đọc owner-keyed SQLite stream, không đọc remote language profile.
  Compose/draft widget key gồm project+user+conversation; invalid/uncached/inactive
  conversation không có compose. Unknown source cache chặn gửi; profile cache
  notification tự cập nhật, không thêm request.
- Raw text chỉ clear sau durable enqueue thành công, giữ nguyên whitespace/emoji.
  UI phân biệt pending/sent/blocked; blocked giữ bản local, không tự đổi ID/retry
  permanent failure. Không có delivered/read-receipt, edit/delete, translation,
  TTS, correction/tagging hoặc Training/export mới.
- Accepted-friend picker chỉ tải sau explicit tap, query ID tối thiểu scoped owner,
  keyset pages tới empty (không coi page ngắn là hoàn tất), bounded network gate/
  timeout, post-response token/account/disposal guards. `open_direct_chat` RPC
  vẫn kiểm tra mutual accepted + profiles; client không tự tạo membership.
- Verification: `flutter test --no-pub test/features/chat/operational_chat_screen_test.dart
  --reporter expanded` 11 pass; `flutter analyze --no-pub` clean. Cases: zero-HTTP
  offline inbox/detail/enqueue, sent/blocked, unknown/cache update, A/B draft/history
  isolation, invalid/uncached deep links, offline picker, scoped paged friend read,
  canonical open/SQLite commit, 320px/1440px + keyboard/Unicode cap, disabled no SDK/DB,
  friends CTA opt-in/hidden with zero SDK resolution. Placeholder scroll avoids
  7px small-window overflow exposed by the added CTA.
- Initial fixture compile/timing/unique-peer/imperative-URL assertions corrected;
  no test skipped/weakened, no DB constraint changed. Windows orphan tester held
  sqlite3.dll after interrupted fake-clock run; stopped only verified orphan test
  process, rerun passed. Concurrent build/full-suite exposed a fixed-delay test
  race (composer inspected before SQLite completion, followed by disposed-container
  callback after failed assertion); fixture now awaits expected state with a 30s
  deadline and always unmounts before resource teardown. No app invariant weakened.
  Happy-path open test also awaits canonical detail/dialog disposal, not a fixed
  delay after SQL commit. Final `-Target web-build -ChatRelayEnabled` PASS/exit0,
  compile 92.8s, `build/web`; dry-run upToDate=true, temporary defines cleaned by
  runner. Existing flutter_tts Wasm/Cupertino font warnings remain; JavaScript
  artifact, not browser/device/PWA smoke.
- Final full regression: `flutter test --no-pub --reporter json` **489 pass /
  1 existing opt-in skip / 0 failures**, exit0/done.success=true. Collector giữ
  JSON line fragments qua output chunks; parseErrors=0/truncated=false. Combined
  chat now **86** (75 C3A/B + 11 C3C); `flutter analyze --no-pub` clean,
  `dart format --output=none --set-exit-if-changed` 6files/0changes;
  `git diff --check` exit0, existing LF→CRLF warnings only.
- `adb devices` trả empty 2026-09-15. C3 overall **PARTIAL**: live two-client raw
  send/receive + lost ACK/reconnect + offline cold restart/multi-account vẫn pending.
  C0 policy/Production gate giữ nguyên. No remote writes/apply/commit/push this increment.


### 2026-09-15 — C3B.2 opt-in Staging auth/lifecycle/SQLite refresh/scheduler verified locally

- Theo yêu cầu tiếp tục: triển khai **C3B.2 IMPLEMENTED/LOCAL VERIFIED**,
  **C3 overall PARTIAL**. Không suy ra device/live chat từ cache/adapter tests.
- `OperationalChatCoordinator`: single-flight, local-only enqueue/source profile,
  gate timeout 3s, drain raw trước history, lazy Realtime, event coalescing 150ms,
  30s periodic repair, fresh socket restart, network 2–300s backoff, durable
  eligible-source deadline + 100-row batches/yield >=10ms. Missing/native-changed
  profile giữ pending, không consume attempts hoặc tự rewrite raw.
- Store thêm revision/current-session guarded transactions: inventory + per-ID
  RLS visibility chỉ deactivate captured absent conversations; history merge only
  verified-visible và prune captured SENT IDs. Local ACK/open/auth/event changes
  reject/rollback. Guard trong enqueue/ACK/fail transaction còn kiểm tra session
  sau khi đợi SQL lock, không chỉ trước HTTP. Không đổi chat DB v1/schema/Library.
- Owner-keyed local inbox/detail providers dùng SDK currentSession authoritative,
  không dùng previous AsyncValue account, không tạo language-profile API/notifier.
  Token/account/foreground changes dispose old coordinator/gateway; same-owner
  cache giữ nguyên. Expired JWT gate offline, vẫn đọc/compose local được.
- Android dùng channel network đã có; missing plugin fail closed. Web navigator
  onLine dùng package web hiện có. Other native dựa safe network failure/backoff.
- `OperationalChatRuntime` đã mount trong app, requires CHAT_RELAY_ENABLED=true,
  exact Staging host/session/foreground. Default flag OFF, Production rejected
  kể cả bật flag. Chưa đổi UI/API legacy chat hoặc bật translation/Training.
- `flutter test --no-pub test/features/chat`: **75/75 pass** (23 C3A, 26 gateway,
  19 coordinator/SQLite, 7 SDK-auth/provider/network). Covers SQL-lock logout,
  mid-transaction rollback, newer ACK/open/event while fetch, visibility failure,
  no offline HTTP/profile requests, multi-account/unknown/source change, token
  refresh/pause/resume, durable retry and automatic 101-message batches.
- Gateway SDK WebSocket localhost test verify fresh socket restart with captured
  JWT, guarded events, detach/re-listen. Unsubscribe settles locally in SDK's
  leaving state; fixture verifies leave frames and does not reply into closing
  sockets (không claim client đợi server leave ACK).
- Initial combined fixture expected first offline tick but received idle because
  runtime already entered backoff; assert zero attempts/HTTP instead of racing
  background timing. Full suite then reproduced 101-row fixture's arbitrary 5s
  polling timeout under concurrent compile; changed to explicit completion barrier
  with bounded timeout. Still asserts 101 unique rows/no duplicate/empty outbox.
  No test skip/suppress hoặc weakening application invariants.
- Final `flutter test --no-pub --reporter json`: **478 pass, 1 opt-in skip,
  0 failure, exit 0/done.success=true**. `flutter analyze --no-pub` clean.
  Format 15 files 0 changes; diff check exit 0 (CRLF warnings only).
- Staging runner thêm optional -ChatRelayEnabled/defaultfalse và web-build,
  exact-ref guard; parser pass. Final command
  `./tool/run_staging_device_smoke.ps1 -FlutterCommand 'C:\fulter\flutter\bin\flutter.bat' -Target web-build -ChatRelayEnabled`:
  **PASS/exit0**, source cuối compile 93.8s, build/web; CHAT_RELAY_ENABLED +
  LIBRARY_SYNC_ENABLED=true và Staging URL/key. Temporary defines cleanup trong
  finally, không in/commit key. No browser/app launch/deploy trong target này.
  Còn existing flutter_tts Wasm incompatibility và Cupertino font warnings;
  JavaScript Web build thành công, không claim Wasm/PWA/device smoke.
- No dependency install/update, migration/apply/deploy/Production/Training/Gemini/
  commit/push. Staging dry-run upToDate=true; C3C UI/live two-client/offline cold
  restart/multi-account smoke pending. Initial periodic pull is not a production-
  scale incremental history cursor; Web app-shell offline startup remains pending.

### 2026-09-15 — C3B.1 Staging-only chat Supabase adapter local verified

- C3B chia increment: **C3B.1 IMPLEMENTED/LOCAL VERIFIED**, **C3B.2 PENDING**
  auth/network/lifecycle/concurrency-safe SQLite apply/refresh/reconnect repair/
  durable deadline scheduler. **C3 overall PARTIAL**, C3C UI/device/Web pending.
- Thêm private `OperationalChatSupabaseGateway`, chỉ nhận exact Staging ref +
  matched owner Session. Captured JWT, current-session pre/post-request guards,
  safe denied/retryable categories và bounded HTTP timeout. Không tự activate,
  không dùng mutable auth headers của global SDK/client kế tiếp.
- C2 inserts giữ raw/client identity, duplicate 23505 -> sender/client-key read/
  validate canonical ACK, không UPSERT. Open-direct dùng server RPC/peer validate.
- Pull keyset theo UUID đến empty kể cả server page cap; reject non-advancing/
  failed/malformed pages. Paged history merge-only, không atomic snapshot.
  Cached sent-ID visibility checks chunk/paginate giúp C3B.2 prune đúng snapshot;
  chưa thêm SQLite prune/membership concurrency fence trong increment này.
- Lazy broadcast Realtime chỉ invalidations, 1 channel/3 operational tables,
  generation/session guards và explicit channel removal trước SDK disposal.
  Regression localhost tái hiện SDK 2.13.0 custom-token force-rejoin empty-ref;
  fixed headers + bỏ resolver chỉ trên private instance. Global SDK/package/
  dependency/Library/scan/AI schema không đổi. Socket-loss runtime recovery pending.
- `flutter test --no-pub test/features/chat/operational_chat_supabase_gateway_test.dart`:
  **24 pass** (MockClient + WebSocket localhost, không cloud).
  `flutter test --no-pub test/features/chat`: **47 pass**, exit 0.
- Fixture đầu thiếu HTTP Response.request; sửa đúng SDK parser contract. Full
  suite đầu 449 pass/1 skip/1 teardown failure (pending leave/socket closed);
  fixed disposal + synchronize cả hai fixture leave. Final full
  `flutter test --no-pub --reporter json`: **exit 0, done.success=true**.
  `flutter analyze --no-pub`: sạch. Format check 2 files 0 changes.
- Contract `docs/data/c3b_operational_chat_supabase_contract.md`, plan/chat/DB
  instructions cập nhật cùng increment. Không build/live adapter/device/browser
  smoke; không migration/remote call/Production/Gemini/Training/commit/push.

### 2026-09-15 — C3A separate local Chat DB/outbox/relay foundation verified

- Theo yêu cầu tiếp tục: chia C3 thành C3A local foundation, C3B Supabase/auth/
  Realtime runtime, C3C UI + final Staging client/offline smoke. **C3 PARTIAL**.
- Thêm `lib/features/chat/`: domain raw/types/validated remote decoder/restricted
  insert payload; `OperationalChatDatabase` file riêng `capy_chat_operational.db`
  v1, 2 tables, project+owner composite keys/FK/indexes. Dùng UUID helper và
  native/Web SQLite factories đã có; không mở/upgrade Library/AI database.
- `OperationalChatStore`: atomic message-as-outbox, local streams, ACK/echo
  merge/immutable content/server clock/canonical ID, deterministic ordering;
  complete-only membership/history reconcile để hide inactive/held/deleted cache
  và giữ unsent text. Không được truyền partial pages; C3B phải implement complete
  pagination và reconcile concurrent Realtime snapshots.
- `OperationalChatRelay`: enqueue/read không await network; explicit single-flight
  drain, owner/dispose guards trước/sau awaits, durable exponential backoff và
  8-attempt cap; denied/invalid/exhausted -> blocked, không xóa raw. Transport
  hiện là injectable contract + fake test; chưa Supabase/runtime/scheduler/UI.
- `flutter test --no-pub test/features/chat/operational_chat_relay_test.dart`:
  **23/23 pass**, real disposable SQLite FFI + fake transport: offline reopen,
  owner/project, lost ACK/server commit one-row retry, single-flight/cap/denied,
  stale auth result, ordering/immutable echo/canonical ID/timezone, visibility
  reconciliation rollback và local watcher disposal. Không phải C3 live E2E.
- Analyzer đầu 6 lint infos mới; sửa braces/import không suppress. Rerun
  `flutter analyze --no-pub` sạch. `flutter test --no-pub` full suite:
  **426 pass + 1 opt-in skip**, exit 0. Format 5 files sạch.
- Final diff/format check exit 0 (chỉ CRLF warnings); dependency lock không có
  content diff. Không build/smoke Web/Android trong increment foundation này.
- Contract `docs/data/c3a_operational_chat_local_contract.md`; cập nhật chat
  plan/status. Không sửa UI/API legacy chat, startup/Library/AI schema hoặc
  migration. Không remote calls/Production/Gemini/Training/commit/push. C0
  privacy/retention pending; C3B/C3C/device/browser smoke còn phải thực hiện.

### 2026-09-15 — C2 approved Staging backup/apply/REST + Realtime verified

- User duyệt gate C2 Staging riêng sau báo cáo local; không suy ra approval
  Production/C3/Training. Xác minh healthy linked Staging và giữ nguyên demo.
- Chạy lại `tool/test_chat_operational_schema.ps1`: 47/47 native SQL checks pass,
  exit 0, disposable cluster cleanup. Backup mới qua
  `pwsh -NoProfile -File .\tool\backup_staging_database.ps1`: archive 146,004
  byte, DPAPI decrypt/SHA-256/persisted hashes và pg_restore list verified tại
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T113034Z-c9e9c096`.
  Public/private + encrypted migration history; Auth/Storage/object bytes excluded,
  không bị migration C2 thay đổi. Restore cần cùng Windows profile.
- Exact dry-run chỉ C2; chạy
  `npx supabase db push --project-ref nxteaznowkfennxpqjmt --yes`: apply duy nhất
  `20260915120000_add_operational_chat_security.sql`, exit 0. Post-apply migration
  list 23/23; dry-run `upToDate=true`, migrations=[]; không repair/relink.
- Thêm/chạy `pwsh -NoProfile -File .\tool\run_staging_operational_chat_smoke.ps1`:
  3 synthetic accounts, REST/RLS + native ClientWebSocket protocol 1.0.0,
  five-table subscription ready ở cả 3 sessions. **10 nhóm checks pass**, exit 0.
  Friend pending/forged accept denied, valid recipient/mirror UPSERT preserved;
  canonical atomic RPC, raw exact Unicode/server time/duplicate/spoof/edit/delete,
  service-only translation/shared relay/unique/immutable, human correction và
  sender decision invariant, held/inactive/no-reactivation pass.
- A/B nhận raw qua WebSocket trước khi tạo translation; cả hai nhận shared
  translation/correction. Outsider REST cả 5 bảng empty, anonymous denied;
  outsider nhận 0 event trong cửa sổ smoke (không tuyên bố proof mọi lifecycle).
  Bản dịch/correction là synthetic, Gemini calls=0, Training writes=0.
- Final smoke chạy lại pass 10 nhóm, exit 0; assert nội dung translation giống
  nhau ở A/B và cả hai nhận correction `accepted`, cleanup 0. PowerShell parser
  runner sạch, whitespace các file mới sạch; `git diff --check` exit 0, chỉ
  CRLF warnings. Không sửa migration đã apply để lấy kết quả xanh.
- Cleanup dùng Auth metadata exact scope/run và verified IDs; đóng sockets,
  xóa đúng 3 fixture accounts, cascade conversation/derived/friends/profiles.
  Baseline counts giữ nguyên, Auth fixture remaining=0. Không xóa dữ liệu demo.
- Regression `tool/run_staging_language_profile_smoke.ps1`: 7 nhóm C1 pass,
  fixture cleanup 0. Post-apply Library audit Staging: 5 Photo Note/10 normalized
  private object, 0 legacy/missing/mismatch/unreferenced, complete inventory;
  legacy audit 0 messages/0 friends.
- Cập nhật contract/chat plan/runbook và partial schema snapshot pointer. Không
  sửa Flutter/SQLite/runtime hoặc chạy lại Flutter checks; UI/reconnect/offline
  chat còn C3+. C0 retention/account deletion policy vẫn pending trước rollout;
  Production không được gọi/ghi, không commit/push/deploy Gemini/Training.

### 2026-09-15 — C2 Operational Chat local SQL verified; Staging apply pending

- Theo yêu cầu thực hiện C2: thêm additive migration
  `20260915120000_add_operational_chat_security.sql` với `chat_conversations`,
  `chat_members`, `chat_operational_messages`, `chat_translations`,
  `chat_corrections`; active membership RLS, column-restricted client INSERT,
  service-only translation writes, canonical/atomic direct-chat RPC,
  idempotency, server clock, immutable content, indexes và explicit publication.
- Friendship trigger chặn sender tự giả accepted, giữ recipient acceptance và
  mirror INSERT/UPSERT của datasource cũ. Legacy `chat_messages` không backfill
  hoặc ép read-only vì client chatbot đang dùng API ghi cũ.
- Thêm bootstrap/test SQL và `tool/test_chat_operational_schema.ps1`; chạy
  `pwsh -NoProfile -File .\tool\test_chat_operational_schema.ps1`: **47 checks
  pass**, exit 0. Native PostgreSQL 18 cluster riêng loopback, synthetic fixtures,
  transaction rollback; remote_writes=0. Không Docker/dependency mới.
- Runner startup Windows chờ pg_ctl parent riêng, không chờ process tree của
  server; stop/cleanup exact temp directory validated. Cluster lần thử lỗi cũng
  đã dừng và dọn sạch, không đụng PostgreSQL service hiện có.
- Chạy `pwsh -NoProfile -File .\tool\audit_staging_chat_legacy.ps1`: legacy
  columns verified, 0 messages, 0 friends; chỉ audit read-only/counts, không lấy
  nội dung chat hoặc in key. Không fixture writes trên remote phiên C2.
- Final runner recheck: 47/47 pass, exit 0; audit exact `Content-Range` chống
  server pagination/truncation pass. PowerShell parser hai runner sạch,
  whitespace bảy file C2 mới sạch, `git diff --check` exit 0 (chỉ CRLF warnings).
- Chạy `npx supabase db push --project-ref nxteaznowkfennxpqjmt --dry-run`:
  chỉ đề xuất C2, exit 0; remote vẫn 22 migrations/local 23. **Chưa apply**:
  cần approval riêng, backup mới và post-apply REST/Realtime/Library smoke.
  Production không được gọi/relink/ghi.
- Contract mới `docs/data/c2_operational_chat_contract.md`; cập nhật `chat_DB.md`
  và runbook. C0 retention/edit/delete/account cascade policy vẫn pending trước
  product rollout. Realtime chỉ verified catalog, chưa live WebSocket. Không
  chạy lại Flutter suite/analyzer/build vì không đổi Dart/runtime trong C2;
  không kế thừa C1 evidence thành C2 UI evidence. Không Gemini/Training pipeline.

### 2026-09-15 — C1 Staging backup/apply/two-account backend verified

- Theo yêu cầu tiếp tục, hoàn tất gate Staging cho C1; không gọi/ghi/relink
  Production, không sửa demo user, không triển khai C2 hoặc Training.
- Thêm runner `tool/backup_staging_database.ps1`: native PostgreSQL 18 dump
  `public` + `private`; migration history lấy read-only qua CLI riêng. Connection
  tạm giữ trong memory, parser không evaluate shell, môi trường PostgreSQL được
  restore; DPAPI CurrentUser encrypt ngoài repo. Backup path:
  `%LOCALAPPDATA%\CapyVocabApp\staging_backups\20260915T105000Z-805486b7`.
- Archive 133,403 byte; decrypt SHA-256 round-trip/persisted hashes và
  `pg_restore --list` pass. Plaintext temp đã xóa; bản mã hóa được giữ lại và cần
  cùng Windows profile để restore. Auth/Storage/object bytes nằm ngoài dump và
  không bị C1 thay đổi.
- Backup ban đầu fail-closed do thiếu role selection trong native invocation.
  Runner dùng `--role=postgres` đã có trong script CLI chuẩn; không tạo role hoặc
  sửa grants. Parser/self-test quoting, duplicate/missing/shell expansion pass.
- Local C1 test `8/8` pass; exact dry-run chỉ đề xuất C1. Apply đúng
  `20260914120000_add_chat_language_profiles.sql` lên explicit Staging ref.
  Post-apply list 22/22 và dry-run `upToDate=true`.
- Thêm/chạy `tool/run_staging_language_profile_smoke.ps1`: hai account unknown
  ban đầu; atomic onboarding/profile, owner read, cross-read empty/cross-write
  403/anon denied, invalid RPC rollback/table constraint, server timestamp và
  legacy 8-arg RPC preservation pass. 7 nhóm kiểm tra, fixture Auth/profile còn
  0; baseline profile IDs giữ nguyên.
- Post-apply Library audit Staging: 5 bài/10 object chuẩn hóa, private bucket;
  0 missing/mismatch/legacy/unreferenced, complete inventory. Android/Web UI
  smoke C1 chưa chạy; full suite/analyzer/Web build giữ evidence local 2026-09-14,
  không tuyên bố chạy lại trong increment scripts/remote này.
- `flutter devices` chỉ thấy Windows/Chrome/Edge, không Android. Thử widget
  tests C1 onboarding/settings với `--platform chrome --timeout 30s`: runner
  vẫn treo `loading`, 0 assertion chạy; dừng Ctrl+C, không có test pass. UI live
  và account-switch trên Android/Web còn pending.

### 2026-09-14 — C1 Language Profile implemented and locally verified

- Khóa phạm vi C1: MVP `vi`/`en`, người dùng tự khai báo, hai ngôn ngữ phải khác
  nhau; không suy đoán/backfill account cũ và không bật chat/Training.
- Thêm `LanguageProfile`, owner-scoped SharedPreferences cache, Supabase
  repository/notifier background refresh; cache hydrate trước `runApp` và tách
  dữ liệu theo user ID để logout/login không trộn account.
- Thêm bước onboarding cùng Settings dialog cho native/learning/proficiency;
  completion RPC mới ghi profile và onboarding trong một transaction, đồng thời
  giữ overload cũ để tương thích client đã phát hành.
- Tạo additive migration
  `20260914120000_add_chat_language_profiles.sql`, RLS owner-only và grants tối
  thiểu. Snapshot schema được cập nhật; không thêm dependency.
- Targeted language/onboarding/settings: `43` pass; Language Profile sau
  hardening server timestamp: `8/8` pass. Full suite:
  `403` pass + `1` opt-in skip, `0` failure. `flutter analyze --no-pub` sạch.
  `flutter build web --no-pub` pass; warning Wasm `flutter_tts` và Cupertino font
  còn tồn tại nhưng không chặn JavaScript build.
- Staging dry-run chỉ liệt kê đúng migration C1. Chưa push/apply migration, chưa
  deploy function, chưa ghi dữ liệu Staging và không thao tác Production. Rollout
  bắt buộc migration-first trước khi chạy client C1 trên từng môi trường.

### 2026-09-14 — Chat DB và human-labelled Training plan

- Thêm `chat_DB.md` tổng hợp mục tiêu, hiện trạng legacy `chat_messages`, ba
  luồng AI Scan/Operational Chat/Training và thứ tự milestone C0–C6, T0–T5.
- Khóa hướng sản phẩm theo yêu cầu: chat người-với-người; raw text relay trước;
  mỗi translation key chỉ gọi Gemini một lần trên server; hai client dùng chung
  kết quả; Scan/Gemini output không đi vào dataset Training.
- Thiết kế UX tagging tùy chọn sau correction: người dùng nguồn tự xác nhận span
  và dạng chuẩn, người dùng đích tự viết `gold_target`, người gửi accept và cả
  hai cấp consent theo mẫu trước promotion.
- Ghi schema/RLS/trust-boundary mục tiêu và test gates dưới trạng thái `PLAN
  ONLY`; tên/cột cuối, retention, tuổi/khu vực, revoke sau training và rollout
  vẫn chờ C0/T0 phê duyệt.
- Không sửa code/schema/migration, không thêm dependency, không gọi Gemini,
  không deploy và không đọc/ghi Staging hoặc Production. Verification tài liệu:
  kiểm tra diff/format/link nội bộ; không chạy Flutter test vì không đổi runtime.

### 2026-09-12 — D4 Web persistence + Supabase handoff audit

- Theo yêu cầu khắc phục Web, nối scan Web từ memory sang SQLite
  WASM/IndexedDB: JPEG nằm trong media blob DB riêng; JSON/normalized Library
  aggregate đi qua `ScanResultLocalDataSource` như native.
- Thêm loader/purger Web cho Library/Trash/detail và khóa Cloud Backup trên Web
  cho tới khi có sync gateway; không tự tải ảnh cloud và không bật Production
  rollout flag.
- Thêm responsive content frame dùng chung, giới hạn navigation/sheet/Library
  trên viewport rộng nhưng giữ nguyên layout/golden mobile.
- Sửa `tool/audit_supabase_library_rollout.ps1` ưu tiên Supabase secret key mới,
  dùng `--reveal` trong bộ nhớ, User-Agent máy chủ và fallback legacy
  `service_role`; contract test được cập nhật.
- Audit read-only pass trên cả hai project bằng
  `access_mode=secret_read_only`: Production có M3A, bucket private, inventory
  complete, 0 Photo Note/0 object; Staging có 5 Photo Note/10 object chuẩn hóa,
  không legacy/missing/mismatch/unreferenced. Không có migration, ghi dữ liệu,
  deploy function hay thay secret.
- Verification: targeted analyzer sạch; media/responsive 12/12, Settings 11/11,
  Library 9/9, scan provider 4/4 và cloud migration contract 8/8 pass; Web
  debug build pass. Full suite lần đầu chỉ lỗi contract cũ
  `service_role_read_only`; sau khi cập nhật contract, full suite pass và full
  analyzer sạch. Chrome runner vẫn treo ở `loading` hơn 2 phút nên IndexedDB
  browser reopen/cold-restart còn là runtime checkpoint, không được tuyên bố
  hoàn tất.
- Build artifact có `sqlite3.wasm`/`sqflite_sw.js`, nhưng
  `flutter_service_worker.js` hiện tự unregister. D4 increment này chỉ chốt
  local data durability; PWA app-shell cache/hosting offline là phần còn thiếu.
- D4 được ghi APPROVED ngày 2026-09-12 cho local Web Library persistence;
  không bao gồm cloud sync/restore Web hoặc on-device training Web.

### 2026-09-11 — GitHub UI sync tới `cbd7318`, offline contract preserved

- Fetch và fast-forward `AI-scan` từ `fba6f38` lên `cbd7318` (6 commit).
- Nhận design system neo-brutalist, graph-paper background, Scan/Auth/Onboarding/
  navigation polish, soft page transition và password-recovery UI/route.
- Hòa trộn router để redirect onboarding vẫn synchronous từ cache, không query
  profile khi chuyển Home → Library → detail; giữ route Library detail/trash.
- Giữ entitlement Pro cho custom note template và Cloud Backup consent UI trong
  giao diện mới; cập nhật test doubles cho auth/password-recovery contract.
- `dart analyze`: `No issues found`; nhóm UI/router/auth/settings/offline test:
  73/73 pass.
- Bổ sung Kotlin Android plugin còn thiếu trong scaffold GitHub; Android debug
  build pass và tạo `build/app/outputs/flutter-apk/app-debug.apk`.
- Không đổi schema/migration/consent/retention/ML lineage, không ghi Supabase và
  không deploy. Vilao gateway trong commit `cbd7318` chưa hòa vào Edge Function
  local đã rollout; cần kiểm tra backend riêng trước khi áp dụng.

### 2026-09-11 — Production Gate 3 M3A/M4.5 + isolation verified

- Chủ dự án duyệt explicit Gate 3 trong chat. Preflight xác nhận đúng Production
  ref, repo vẫn link Staging, backup manifest tồn tại, audit 0 row/object và
  dry-run chỉ có M3A + M4.5.
- `db push --project-ref <Production> --yes` apply đúng
  `20260903120000_add_library_cloud_storage_contract.sql` và
  `20260910120000_add_library_cloud_pull_feed.sql`.
- Post-apply history khớp 21/21, dry-run `upToDate=true`, bucket private và M3A
  tables present. Audit harness ban đầu báo sai table rỗng là absent do
  PowerShell collapse empty array; sửa result thành `{Exists, Rows}` và bump
  audit v2. Production empty + Staging populated regression pass.
- Tái sử dụng full live Library test trên Production: SQLite outbox/private
  upload/normalized raw JSON/pull sang DB thứ hai/no-auto-download/permanent
  purge/delete feed/cleanup đều pass.
- Hai-user runtime: owner access/upload/download/signed URL pass; other user
  thấy 0 media/note, row insert 403, Storage read/upload 400. Lượt đầu false
  fail do `@($null).Count`; raw JSON rerun pass, không có RLS leak.
- Final audit xác nhận 0 fixture row/object/legacy/unreferenced; Auth fixture
  marker 0. Repo không relink, không deploy Edge Function/app build và default
  `LIBRARY_SYNC_ENABLED=false` giữ nguyên.
- Final audit v2 pass; targeted cloud migration/rollout contract pass 8/8;
  `flutter analyze --no-pub` trả `No issues found`.

### 2026-09-11 — Production Gate 0–2 backup/fingerprint/history repair verified

- Chủ dự án duyệt Gate 0–2 trong chat; phạm vi duyệt không gồm apply M3A/M4.5.
- Supabase Docker dump fail-closed do Docker engine không chạy; backup dở và
  plaintext được xóa. Dùng PostgreSQL 18 local làm fallback với temporary login
  trong memory, không in/ghi credential.
- Tạo backup ngoài repo tại
  `%LOCALAPPDATA%\CapyVocabApp\production_backups\20260911T105509Z`: public
  schema, full public custom dump và pre-repair history đều mã hóa DPAPI
  CurrentUser. 3/3 decrypt SHA-256 round-trip và `pg_restore --list` pass;
  manifest ghi restore constraint cùng Windows profile và aggregate Library
  snapshot trước/sau repair; manifest re-read verification pass.
- Catalog fingerprint pass: đủ 15 baseline tables, subscription uniqueness,
  AI request ledger/function/final service-role privileges, ba circuit-breaker
  functions; M3A/M4.5 tables chưa tồn tại.
- Re-audit ngay trước repair vẫn 0 Photo Note/0 Storage object và complete, nên
  không chạy backfill.
- Repair đúng migration ledger Production: đánh dấu 4 remote aliases reverted,
  baseline + 4 local canonical applied. Không chạy product SQL.
- Post-repair history khớp local qua `20260829152311`; Production dry-run đề
  xuất đúng M3A + M4.5. Hậu kiểm xác nhận bucket vẫn public, M3A absent, 0
  row/object; repo vẫn link Staging và Staging dry-run up-to-date.
- PowerShell parser pass; targeted cloud rollout/migration contract pass 8/8;
  `flutter analyze --no-pub` trả `No issues found`.
- Tại thời điểm entry Gate 0–2 này, Gate 3 apply còn
  `BLOCKED PENDING SEPARATE APPROVAL`; entry Gate 3 mới hơn ở phía trên ghi nhận
  apply/runtime verification đã hoàn tất. Production sync build vẫn chưa chạy.

### 2026-09-11 — Production Library rollout audited; writes blocked

- Thêm `tool/audit_supabase_library_rollout.ps1`: validate đúng project
  name/ref/status, chỉ dùng Data API GET và Storage list read-only, tự test sáu
  loại path, paginate, đối chiếu đủ display/original/model-input, và chỉ xuất
  aggregate counts; không xuất key/user ID/note ID/URL/object path.
- Live Staging audit: 5 normalized Photo Note, 10 normalized private object,
  không legacy, missing/mismatch hoặc unreferenced; inventory không truncate.
- Live Production audit: 0 Photo Note, 0 object, bucket public và `media_assets`
  chưa tồn tại. Vì vậy không chạy backfill; kết quả chỉ đúng tại thời điểm audit
  và bắt buộc chạy lại ngay trước apply.
- `migration list` xác nhận Staging 21/21/up-to-date. Production có 14 version
  chung, thiếu baseline history, 4 remote-only version và 7 local-only version
  (baseline + 4 canonical alias + M3A + M4.5).
  Fetch vào OS temp + semantic diff xác nhận bốn remote-only là alias của bốn
  migration local canonical; khác ở transaction/comment/semicolon và revoke
  trung gian nhưng final schema/grant tương đương. Temp đã xóa.
- Thêm `docs/data/production_library_rollout.md` với backup gate, conditional
  two-phase legacy backfill không bịa scan/label, proposed history mapping,
  dry-run/apply gate và fail-forward rollback giữ dữ liệu.
- Cập nhật M3A contract và thêm hai static contract test. PowerShell parser
  pass; targeted `library_cloud_migration_test.dart` pass 8/8;
  `flutter analyze --no-pub` trả `No issues found`.
- History repair, migration apply, bucket/policy mutation, row/object write và
  relink Production đều chưa thực hiện, trạng thái
  `BLOCKED PENDING APPROVAL`.

### 2026-09-11 — Explicit pre-consent Library backfill verified

- Thêm Settings action `Sao lưu bài đã có` chỉ khi Cloud Backup ON, với dialog
  explicit riêng; bật switch không tự backfill. Snackbar báo số note queued và
  số note thiếu media bị bỏ qua.
- Store chỉ chọn active note đúng owner, chưa synced/chưa có Photo Note outbox/
  tombstone. Controller stat đủ display/original/model-input khi cần upload;
  Trash và missing media fail-closed, media đã ở cloud không bị upload lặp.
- Enqueue dùng lại graph hiện có trong một transaction, đổi media/note sang
  pending và idempotent khi nhấn lại; coordinator hiện tại nhận `sync` notify.
- Targeted 35/35, Settings+Library 123 pass + 1 skip, full suite 351 pass + 1
  skip, analyzer sạch. Live Staging pass pre-consent→backfill→upload→pull→purge
  và cleanup toàn bộ fixture.
- Android Staging build/cài đè pass và giữ SQLite/cả ba JPEG checksum. Settings
  render action/dialog đúng; 5 note đã synced trả zero-candidate. Hai JPEG khác
  có mtime trước lần update APK nên không phải side effect của action mới.
- Không thêm dependency, không đổi schema/migration, AI consent/ML lineage,
  demo account data hoặc Production.

### 2026-09-11 — Library actual local-media usage UX Android verified

- Sửa storage summary để lấy danh sách media owner-scoped còn được Photo Note
  active/Trash giữ lại, kiểm tra file app-private và cộng dung lượng thực bằng
  `File.length()`; remote `byte_size_display` không còn bị gắn nhãn dung lượng
  local.
- Library/card/detail phân biệt ba trạng thái: `Ảnh trên máy`, `Ảnh trên cloud`
  và `Thiếu ảnh`. Cloud-only vocabulary vẫn xem offline; JPEG chỉ tải khi người
  dùng explicit nhấn `Tải ảnh từ cloud`.
- Regression test local/cloud-only/missing pass; toàn Library 105 pass + 1 live
  skip, full suite 346 pass + 1 live skip, analyzer sạch. Staging build pass sau
  migration dry-run up to date.
- `adb install -r` giữ nguyên SQLite/JPEG checksum. CPH2375 hiển thị đúng
  `5 bài trong thư viện`, `1/5 ảnh trên máy • 114.2 KB`, `4 trên cloud`; mở
  cloud-only detail không tự tải và `capy_scans/` vẫn đúng 1 JPEG 116,892 byte.
- Không thêm dependency, không đổi schema/migration, consent, ML lineage,
  cloud data hoặc Production.

### 2026-09-11 — Android explicit restore + quiet-offline sync verified

- Sau clean-install metadata rehydrate, explicit CTA tải bài đầu đã ghi đúng 1
  JPEG app-private 116,892 byte/SHA-256 `a6664293...fe27da`; CTA biến mất, ảnh và
  4 từ mở lại được sau force-stop/cold-start offline. Bốn JPEG khác không tự tải.
- Smoke đầu tái hiện `pull_library_delta` ném `Failed host lookup` lúc startup và
  sau 30 giây. Root cause: coordinator có retry timer nhưng không có network gate.
- Thêm Android `ConnectivityManager` validated-network MethodChannel và quyền
  `ACCESS_NETWORK_STATE`; không thêm package. Coordinator chặn drain/pull khi
  offline, không report network absence như runtime error, và exponential backoff
  30 giây→60 giây→... tối đa 15 phút; success/user switch reset failure count.
- Test coordinator 9/9, toàn Library 104 pass + 1 live skip, full suite 345 pass
  + 1 live skip và analyzer sạch. APK Staging sync-enabled build pass sau
  migration dry-run up to date.
- Cài APK bằng `adb install -r`; checksum SQLite/JPEG trước/sau giữ nguyên. Cold
  start offline 6,963 ms; Home→Library→detail qua hơn 30 giây có 0 RPC/host lookup/
  stack trace. Wi-Fi/mobile data đã khôi phục. Không đổi DB/ML/Production.

### 2026-09-11 — Android install incident; sandbox cleared

- CPH2375 được nhận đúng qua Flutter. Dùng `flutter install` với APK Staging đã
  build và `--use-application-binary` theo giả định sẽ cài đè giữ dữ liệu.
- Command thực tế in `Uninstalling old version...`; read-only `run-as` sau cài
  xác nhận sandbox mới chỉ có `cache/code_cache`, không còn `databases/files`.
- Dừng trước launch/sign-in. Chưa thử cloud metadata pull hoặc manual media
  restore; dữ liệu local-only/orphan không có bằng chứng phục hồi được.
- Sau khi chủ dự án duyệt tiếp tục, cold-launch app Staging pass 7,909 ms,
  Supabase init pass, PID 7158 và log lọc không có Flutter/AndroidRuntime error.
  Chủ dự án đăng nhập thành công; SQLite mới 282,624 byte và startup audit sạch.
- UI Settings xác nhận Cloud Backup OFF sau cài sạch. Chưa tự thay consent;
  chủ dự án sau đó bật/confirm và UI trả `checked=true`.
- Android metadata rehydrate pass: Library có 5 note, detail có raw-derived
  vocabulary/4 từ và manual cloud CTA; SQLite 282,624→290,816 byte, không có
  `capy_scans`, không có runtime error. Không auto-download JPEG.
- Ghi nhận UX bug: storage summary dùng remote metadata byte-size nhưng gắn nhãn
  `ảnh local`, và subtitle gọi cloud-only note là `đã lưu trên thiết bị`.
  Manual download/offline cold restart từng PENDING tại thời điểm entry này; đã
  pass trong entry `Android explicit restore + quiet-offline sync verified` ở trên.
- Không thay đổi source/schema/migration, không ghi Staging/Production trong
  bước device này. M4.5 local/live Staging evidence trước sự cố vẫn hợp lệ,
  physical Android rehydrate/offline smoke nay đã pass theo entry mới hơn.

### 2026-09-11 — M4.5 cloud metadata pull Staging E2E verified

- Nâng SQLite schema lên v3/22 bảng với `library_pull_cursors` theo user; apply
  snapshot/delete/cursor trong một transaction. Local note chưa `synced` không
  bị ghi đè; tombstone chặn resurrection và fail-close training example/model.
- Thêm RPC owner-scoped + change feed identifiers-only; không chứa JPEG/raw JSON
  duplicate. Migration `20260910120000_add_library_cloud_pull_feed.sql` apply
  đúng linked Staging; migration history 21/21 và post-apply dry-run up to date.
- Coordinator upload trước rồi pull metadata nền. Hết batch budget nhưng server
  còn trang sẽ tự chạy lượt kế trong cùng single-flight; cursor không tiến thì
  fail contract và đi theo backoff, tránh lặp vô hạn.
- Live owner tạm với hai SQLite pass: A upload private aggregate/JPEG; B nhận
  metadata, raw Gemini JSON và vocabulary, cursor tiến, outbox 0, JPEG vẫn thiếu;
  sau remote purge B nhận đúng delete receipt và xóa source local.
- Teardown xác nhận xóa user tạm, normalized rows, Storage object và change-feed
  fixture. Production không linked/apply/reset/thay đổi. Không thêm dependency,
  không auto-download và không thay đổi database phục vụ AI ngoài fail-closed
  lineage khi nguồn bị xóa.
- Targeted pull/coordinator 13/13 và SQLite 17/17 pass; analyzer toàn dự án sạch,
  full suite 344 pass + 1 opt-in live skip. Live Staging test 1/1 pass và cleanup
  pass; APK debug Staging với `LIBRARY_SYNC_ENABLED=true` build pass.

### 2026-09-10 — M4.4 manual cloud restore Android E2E verified

- Settings trên CPH2375 xác nhận account Cloud Backup ON. Chọn đúng synced
  Photo Note `bracelet, notebook, smartphone`; rời Library để dispose provider
  cache rồi tạm đổi tên JPEG local thành backup app-private có rollback.
- Khi original thiếu, detail mới hiện `Ảnh đang có trên Cloud Backup` và
  `Tải ảnh từ cloud`; kiểm tra trước tap xác nhận original vẫn absent nên không
  có automatic download ở startup, Library list hoặc detail.
- Explicit tap tải lại đúng `capy_scan_1788969413220772.jpg` 116,892 byte;
  SHA-256 trùng backup trước smoke, ảnh render, CTA biến mất và backup được xóa.
- Sau khi file hoàn chỉnh, tắt Wi-Fi/mobile data, force-stop/cold-start 5,315 ms:
  Library giữ 7 bài, restored detail mở ảnh + 4 từ và log network/profile/SQLite/
  FATAL đều 0. Mạng cùng file hierarchy tạm được khôi phục/dọn sạch.
- Không restart/resume trong missing window nên startup integrity audit không
  thấy false missing và không đổi training lineage. Không sửa source/schema,
  không thao tác Production; M4 còn cloud-only metadata pull/multi-device.

### 2026-09-10 — M4.3C Android Restore/permanent-delete E2E verified

- Chủ dự án đưa rõ một Photo Note `container, router, cat` vào Trash để dùng
  làm fixture. Baseline có 8 active note, Trash 1, 9 JPEG và DB 315,392 byte.
- Android UI pass Trash → Restore (Trash trống) → đúng menu item → confirm đưa
  lại Trash (active 7/Trash 1) → confirm permanent delete với copy local/cloud.
- Permanent delete làm `capy_scans` giảm đúng 9→8 và chỉ xóa
  `capy_scan_1788971916677667.jpg`; Trash về 0. Cold restart 5,400 ms giữ 7 bài,
  8 JPEG và fixture không sống lại; log PID có 0 network/SQLite/FATAL/purge lỗi.
- Read-only audit trên đúng linked Staging `ACTIVE_HEALTHY` trả raw REST `[]`
  cho Photo Note title fixture. Lượt đếm đầu báo sai 1 do PowerShell 5.1 nested
  array; metadata null đã làm lộ lỗi và raw-response rerun xác nhận 0 chính xác.
- Storage object của device fixture không được query riêng vì media UUID đã bị
  xóa local trước audit; Storage folder deletion đã có live Staging E2E biệt
  lập. Không ghi Production, không chạm 7 bài còn lại; file hierarchy tạm đã
  xóa và mạng giữ airplane OFF/mobile data ON/Wi-Fi ON.

### 2026-09-10 — M4.3C Photo Note physical purge local verified

- Thêm owner-scoped deletion maintenance: Trash đủ đúng 30 ngày được chuyển
  thành permanent request ở startup/sign-in/resume; explicit delete chạy ngay.
- Native media purger chỉ xóa file con trực tiếp trong app-private
  `capy_scans/`, idempotent và từ chối path ngoài phạm vi.
- SQLite finalizer xóa aggregate/source độc quyền, learning projection,
  training examples và manifest/run links; shared media chỉ bị xóa khi không
  còn Photo Note active khác. Model đã dùng source bị invalidated; tombstone
  receipt tối thiểu được giữ.
- Cloud delete được tách khỏi upload consent: Cloud Backup OFF không tạo upload
  mới nhưng privacy purge vẫn retry cho đúng authenticated owner; payload purge
  giữ remote target sau khi local rows/file đã bị xóa.
- Targeted suite 37/37 pass; analyzer sạch; full suite 329 pass + 1 opt-in
  Staging skip. Live Staging fixture pass upload → local purge → backup OFF →
  cloud row/Storage purge, retained payload cleanup và tombstone receipt; user,
  row và object fixture cleanup pass. APK Staging sync-enabled build pass;
  không thêm dependency/migration và không thao tác Production.
- Android CPH2375 cài đè giữ data; data-off cold restart mở Home → Library 8 bài
  → detail ảnh local/3 từ → Trash empty state. Resume giữ PID và hoàn tất 139 ms;
  log network/profile/SQLite/purge error đều 0. 9 JPEG/DB giữ nguyên, mobile data
  đã bật lại; không tạo/xóa fixture vì không được phép dùng bài thật.
- Debug cold start online/offline lần lượt 7,002/4,858 ms và có skipped-frame
  warning; chưa có profile/release benchmark nên không tuyên bố đã đạt mục tiêu
  hiệu năng sản phẩm.

### 2026-09-09 — M4.4 manual cloud media restore local verified

- Detail chỉ hiện `Tải ảnh từ cloud` khi local read lỗi, MediaAsset có private
  remote display path và build sync-enabled; render/open detail không gọi
  download.
- Explicit tap mới gọi private Storage download. Service fail-closed nếu auth
  owner/object prefix sai, payload rỗng, byte size hoặc SHA-256 không khớp.
- Native writer dùng relative-path validation, file tạm + rename atomically,
  không overwrite local copy đã xuất hiện đồng thời và dọn file tạm khi lỗi.
- Targeted restore/writer/UI 14/14 pass; full suite 323 pass + 1 opt-in Staging
  skip; analyzer sạch; Web build pass với warning có sẵn; Staging migration
  dry-run up-to-date và APK sync-enabled build pass.
- Không thêm dependency/schema, không auto-download, không triển khai Gallery
  export, không pull cloud-only metadata sang máy mới và không thao tác remote.

### 2026-09-09 — M4.3B Photo Note Trash UI + storage summary local verified

- Thêm active-account storage summary từ normalized MediaAsset metadata và
  hiển thị số bài active, số bài trong Trash, dung lượng display/original local.
- Thêm route/UI Trash 30 ngày; move yêu cầu confirm, Restore khả dụng trước
  tombstone và xóa vĩnh viễn tạo request rõ ràng thay vì báo cloud đã xóa ngay.
- Trash query không hiển thị Photo Note đã có permanent-delete tombstone;
  repository chặn restore item đang chờ purge và vẫn giữ content ẩn cho đến khi
  local/cloud finalizer hoàn tất.
- Widget test đầu bắt được overflow 58 px ở popup hẹp; CTA được rút gọn và test
  rerun pass. Targeted SQLite + widget 19/19 pass; analyzer toàn dự án sạch.
- Không thêm dependency, không đổi schema, không tải media cloud và không thao
  tác Staging/Production.

### 2026-09-09 — Cloud download UX chốt là thủ công

- Chủ dự án yêu cầu tải ảnh/cloud Library là tùy chọn, không tự động tải xuống.
- M4 cloud restore phải hiển thị trạng thái cloud-only/missing-local và chỉ ghi
  media vào app-private sau hành động rõ ràng của user; startup, reconnect,
  Library list và detail không được âm thầm tải binary media.
- Download về app-private để CapyVocab dùng offline không đồng nghĩa export ảnh
  sang Gallery/Photos của hệ điều hành; export là một feature riêng nếu được
  duyệt sau.
- Đây là cập nhật requirement/tài liệu, chưa triển khai code, chưa thay đổi
  SQLite/Supabase schema hoặc dữ liệu và không kế thừa kết quả test cũ làm bằng
  chứng implementation.

### 2026-09-08 — D9 approved; M4.3A recovery UX Android verified

- D9 chốt retention 30 ngày: orphan chỉ vào `capy_quarantine/` sau explicit
  confirm; UI cho Restore/Xóa ngay và startup chỉ purge file đã được cách ly đủ
  30 ngày. Adapter giới hạn mutation ở file con trực tiếp, từ chối traversal,
  wrong-directory và collision; service re-audit ngay trước move để tránh race.
- Library hiển thị banner/bottom sheet recovery với touch target tối thiểu 48dp,
  confirm cho quarantine/delete và không đưa absolute path ra UI/log.
- Missing media giữ Photo Note, scan JSON, detection và vocabulary nhưng chuyển
  training example liên quan sang `quarantined/excluded`; model đã dùng source
  bị invalidated và training run kiểm tra eligibility lại trước khi ghi lineage.
- Targeted regression pass 23/23; analyzer sạch; full suite pass 313 + 1 opt-in
  Staging skip; Web và APK Staging build pass, migration dry-run up-to-date.
- CPH2375 fixture pass confirm quarantine → Restore → cách ly lại → confirm
  delete; chỉ fixture bị xóa, orphan lịch sử/6 JPEG thật giữ nguyên. Offline cold
  restart 5,042 ms giữ 5 bài/banner 1 mục/audit 1 orphan, 0 missing, 0 purged;
  không có lỗi network/profile/SQLite/FATAL trong bộ lọc PID và mạng đã bật lại.

### 2026-09-08 — M4.2 Android media recovery smoke verified

- ADB nhận đúng CPH2375/665fdb60 Android 13; `adb install -r` APK Staging cuối
  giữ session, 6 JPEG app-private và SQLite 299,008 byte.
- Online cold startup PID 18621 báo `Library media audit: 1 orphan, 0 missing`;
  audit không xóa file lịch sử và UI giữ authenticated Home.
- Tắt Wi-Fi/mobile data rồi chọn một ảnh local: file count từ 6 lên 7 trong khi
  dialog lỗi scan mở, sau khi đóng dialog quay về 6. SQLite size/mtime không đổi
  và log không có cleanup failure, SQLiteException hoặc FATAL.
- Offline force-stop/cold-start PID 24631 báo lại đúng 1 orphan/0 missing, giữ
  6 file, session/Home/Library; bộ lọc PID không có profile/network/storage lỗi.
- Khôi phục mobile_data=1 và Wi-Fi kết nối lại `Tang 5`; screenshot chẩn đoán
  tạm ở device/workspace đã xóa. Controlled failure không tạo DB/outbox hoặc
  upload mới; Production không bị thao tác.

### 2026-09-08 — M4.2 media compensation and startup audit locally verified

- Mở rộng scan image storage với cleanup idempotent; native chỉ cho phép xóa
  file con trực tiếp của app-private `capy_scans`, từ chối path ngoài phạm vi.
- Bottom sheet chỉ giữ JPEG khi `ScanResultRecord` đã commit. Vision/SQLite lỗi
  hoặc widget đóng giữa chừng đều cleanup best-effort; lỗi cleanup không thay
  thông báo lỗi gốc và log không chứa absolute local path.
- Thêm account-global SQLite media reference query và native inventory; audit
  một lần khi có session, chạy nền, không chặn router/UI và không gọi network.
- Audit chỉ trả orphan/missing set bất biến và runtime chỉ log count; không xóa,
  quarantine hoặc sửa DB lịch sử khi D9 chưa được duyệt.
- Targeted regression 29/29 pass; analyzer sạch; full Flutter suite 306 pass +
  1 opt-in Staging skip. Staging migration dry-run up-to-date và APK debug
  sync-enabled build pass; không push migration hay ghi remote.
- Android runtime evidence đã được bổ sung trong increment kế tiếp; M4 vẫn
  PARTIAL cho UX xử lý orphan/missing lịch sử theo D9.

### 2026-09-08 — M4.1 synchronous onboarding routing Android verified

- Thêm cache onboarding `unknown/incomplete/complete` trong SharedPreferences,
  key theo Supabase user ID; hydrate trước `runApp`, không có state dùng chung.
- Chuyển GoRouter redirect từ async remote profile query sang synchronous cache
  read. `unknown` fail-open cho local/offline UX; `incomplete` vào onboarding.
- Nối complete/reset/sign-up vào cache sau thao tác server thành công; sign-in,
  auth identity change và app resume chỉ kích hoạt refresh nền.
- Refresher deduplicate request đang chạy theo owner và exponential backoff
  30 giây đến 15 phút; failure không block UI và không in network stack noisy.
- Thêm unit/widget regression cho owner isolation, persistence, unknown,
  single-flight/backoff và Home → Library → detail tạo 0 profile request.
- Analyzer sạch; full Flutter suite 298 pass + 1 opt-in Staging skip. APK debug
  Staging sync-enabled build pass và ba Android airplane cold restart giữ đủ
  5 bài/ảnh local/4 từ, log profile/network/storage theo PID bằng 0.
- Không thêm dependency, không đổi database/schema AI, không ghi Staging hoặc
  Production; preflight Staging chỉ đọc và migration chỉ dry-run.

### 2026-09-08 — M4 Android offline restart smoke verified

- Cài APK Staging debug bằng `adb install -r` để giữ app data; preflight xác
  nhận đúng linked Staging, migration dry-run up to date và sync build flag bật.
- Trên CPH2375, xác nhận airplane mode ON và Wi-Fi disabled; detail ảnh/từ vựng
  vẫn hiển thị trước restart. Force-stop/cold-restart đổi PID 32173 sang 3807,
  giữ session và vào Home mà không có mạng.
- Sau restart, Library còn đủ 5 bài; mở lại bài mới nhất có app-private image,
  4 từ và nghĩa đúng. Log có 0 fatal, 0 SQLiteException, 0 media load error;
  sandbox app có 6 media file và DB 299,008 byte.
- Phát hiện global router vẫn lookup Supabase profile trên mỗi navigation khi
  offline: 36 log occurrence trước/trong smoke, gây delay và stack-trace noise.
  Ghi thành residual bắt buộc sửa; không hạ kết luận thành offline tức thời.
- Lượt cài runner đầu mất USB sau build; runner cleanup file credential tạm.
  Smoke sau đó không tạo scan mới, không xóa/sửa local data và không ghi
  Production.

### 2026-09-06 — M4 offline Library UI locally verified

- Nối màn Storage vào owner-scoped SQLite stream và thêm route detail theo
  PhotoNote ID; giữ export tương thích ở feature `ai_scan`.
- Thêm app-private media loader dùng persisted relative path, chặn URI/absolute/
  parent traversal và đóng gói lỗi file; Web implementation hiện fail closed.
- List/detail hiển thị thumbnail/ảnh local, số từ, detection/annotation đã sửa,
  model source và trạng thái sync; dữ liệu từ vựng vẫn hiện nếu ảnh bị thiếu.
- Widget tests pass 7/7; SQLite close/reopen + media integration pass 1/1;
  regression Settings/SQLite pass 22/22; full suite pass 289 với 1 opt-in test
  skipped; analyzer sạch và Web build pass.
- Chưa chạy Android airplane-mode/restart smoke và chưa triển khai orphan/media
  recovery. Increment không gọi Supabase, không sửa Staging hoặc Production.

### 2026-09-06 — Android consent-to-upload E2E verified

- Chủ dự án bật Cloud Backup trong Settings và quét ảnh mới trên authenticated
  Staging build. SQLite audit xác nhận consent `cloud_backup` OFF→ON,
  `privacy-v1`, enforcement `applied`; hai consent AI vẫn OFF.
- Ảnh thứ tư được auto-save app-private với 189,147 byte. Normalized aggregate
  mới có 1 MediaAsset, 1 ScanRun succeeded, 5 VocabDetection và 1 PhotoNote.
- Transaction tạo đúng 8 dependency operation; worker hoàn tất 8/8 ở lần thử
  đầu, không có error/retry/block, MediaAsset và PhotoNote chuyển `synced`.
- Truy vấn GET chỉ đọc trên đúng linked Staging xác nhận toàn bộ remote ID khớp
  device: 1 media, 1 scan, 5 detection và 1 Photo Note. Private JPEG tải lại
  HTTP 200, 189,147 byte, MIME `image/jpeg`, SHA-256 trùng SQLite; bucket vẫn
  `public=false`.
- Không tạo/sửa/xóa dữ liệu khi đối chiếu; không chạm Production. Snapshot DB và
  hai script chẩn đoán tạm được xóa sau verification.

### 2026-09-06 — Android real-photo scan persisted locally

- Kết nối CPH2375 qua ADB, mở đúng debug package `com.capyvocab.app` và theo dõi
  đúng process trong khi chủ dự án quét ảnh thật; UI đã render kết quả.
- Baseline có 2 JPEG app-private; lượt scan tạo JPEG thứ 3 kích thước 133,353
  byte và cập nhật `capy_vocab.db`. Snapshot read-only xác nhận latest legacy
  path và MediaAsset cùng tham chiếu file mới.
- SQLite có 2 legacy result, 2 MediaAsset, 2 ScanRun, 2 PhotoNote và 5 detection;
  scan mới nhất `succeeded` bằng `gemini-3.5-flash-lite`/Free với 3 detection.
- Account cloud-backup đang OFF, chưa có consent event; latest PhotoNote là
  `local_only` và `sync_operations=0`, nên lượt scan này chưa upload Supabase
  đúng theo contract fail-closed.
- Phát hiện một JPEG cũ không được DB tham chiếu. Không xóa vì đây là dữ liệu
  app-private có trước smoke; retention/quarantine lịch sử vẫn chờ D9.
- Dừng log monitor, xóa DB snapshot và script chẩn đoán tạm sau khi đọc; không
  sửa database/device data, không thay đổi Staging remote hoặc Production.

### 2026-09-06 — Staging Gemini Edge deployed and live verified

- Chủ dự án cung cấp Gemini test key qua clipboard; key được đọc vào bộ nhớ,
  đặt thành `GEMINI_API_KEY` trên đúng linked Staging rồi clipboard được ghi đè.
  Key/token không được in, ghi vào source hoặc giữ trong script/file tạm.
- Trước deploy, full Edge Function suite chạy bằng Deno với dependency auto
  install: 72 test pass, 0 fail. Lượt đầu dừng trước test logic vì thiếu local
  `npm:@types/node`; rerun với `--node-modules-dir=auto` giải quyết đúng lỗi môi
  trường.
- Deploy `gemini-vision-scan` bằng Management API bundling, không Docker; remote
  list xác nhận version 1 `ACTIVE`, `verify_jwt=false` theo config và secret
  names đầy đủ.
- Request không credential trả `401`. Authenticated JPEG smoke bằng demo user
  pass response contract, Free tier dùng `gemini-3.5-flash-lite`, ledger ghi
  `succeeded`; golden fixture kỹ thuật trả 0 từ nên chưa thay thế device smoke
  bằng ảnh thật.
- Logout session và xóa JPEG tạm pass. REST DELETE ledger bị `403` đúng theo
  hardening không cấp DELETE cho `service_role`; cleanup fail-closed qua
  Management API SQL xóa đúng một smoke row và REST re-read xác nhận còn 0 row.
- Xóa toàn bộ script provisioning/smoke/cleanup tạm. Production có 0 thao tác
  ghi, không deploy function và không thay đổi secret.

### 2026-09-05 — Staging demo Auth account provisioned and login verified

- Theo yêu cầu của chủ dự án, đọc đúng Auth identity và profile tối thiểu của
  demo account được chỉ định từ Production; Production có `0` thao tác ghi.
- Tạo identity tương ứng trên linked Staging, confirm email và xác nhận trigger
  đã tạo `public.users`; chỉ đồng bộ `display_name` và
  `onboarding_completed`.
- Password grant thật trên Staging trả đúng user/session; logout session kiểm
  thử pass. Auth Admin re-read xác nhận user tồn tại, email đã confirm và profile
  tồn tại.
- Email/mật khẩu, access/refresh token và API key chỉ tồn tại trong bộ nhớ tiến
  trình; không ghi vào source, `db_status.md` hoặc file tạm. Script provisioning
  tạm đã được xóa sau khi chạy.
- Không sao chép media, scan, learning data, consent, subscription hoặc billing.
  Chưa thao tác đăng nhập/consent trên Android device trong increment này.

### 2026-09-05 — Staging demo login failure diagnosed read-only

- Xác minh APK Android hiện tại là build Staging; truy vấn Auth Admin chỉ trên
  linked project đã kiểm tra đúng tên/trạng thái trả `total_users = 0` và
  `confirmed_users = 0`.
- Vì Staging không có user nào, credential demo thuộc project cũ/Production
  không thể đăng nhập vào build này dù email/mật khẩu đó vẫn đúng ở project gốc.
- Supabase trả `invalid_credentials` cho trường hợp này; client hiện ánh xạ mã
  đó thành “Mật khẩu không đúng”, nên thông báo chưa phân biệt được account
  không tồn tại với password sai và dễ gây hiểu nhầm.
- Không đọc/in email hay mật khẩu, không tạo/xóa user, không đổi Auth config và
  không truy vấn/thay đổi Production trong bước chẩn đoán.

### 2026-09-05 — Android v2 host and Staging device lifecycle smoke

- Theo application ID được chủ dự án duyệt, scaffold Android v2 embedding và
  đặt `namespace`/`applicationId` thành `com.capyvocab.app`; thêm INTERNET
  permission và giữ Web metadata hiện có.
- Mở rộng runner với target Android build/device, Staging/migration preflight,
  sync flag và cleanup dart-define file. Runner xóa/khôi phục biến `DEBUG` để
  Gradle không echo command chứa client credential.
- Android debug APK build, cài và launch pass trên CPH2375 Android 13; Supabase
  Staging initialize thành công. HOME/resume giữ cùng PID và log sau resume
  không có crash. APK rebuild sau fix cũng được cài lại và launch sạch.
- Smoke đầu tiên phát hiện `Uri.base.origin` ném `StateError` trên native
  `file:///`. Auth repository giờ chỉ dùng origin cho HTTP(S), omits redirect
  trên native; 6 auth tests pass, analyzer sạch và full suite pass 281 với một
  opt-in Staging test skip theo thiết kế.
- Build đầu trước hardening đã in Staging anon client credential trong local
  tool output do biến `DEBUG` toàn cục. Đây không phải service-role secret;
  không có credential trong source hoặc temp file còn lại. Dù vậy sự cố được
  ghi nhận và đường echo đã bị đóng.
- Device dừng ở Auth screen và báo không có network trong lifecycle command;
  chưa có authenticated consent-to-upload/outbox drain trên device. Worker
  upload thật vẫn chỉ được chứng minh bởi Staging E2E đã cleanup.
- Debug launch có startup frame skips và log codec riêng của OPPO; chưa chạy
  release/profile benchmark nên không kết luận hiệu năng sản phẩm.
- Production không linked/apply/reset/thay đổi.

### 2026-09-04 — Cloud-backup consent UI implemented; device smoke blocked

- Thêm Settings switch account-scoped đọc trực tiếp `local_accounts`; mặc định
  OFF, disable khi logout/loading, có retry khi SQLite stream lỗi.
- Bật backup bắt buộc dialog nói rõ ảnh + dữ liệu của bài quét mới được upload
  private, local copy vẫn dùng offline, bài cũ chưa backfill và cloud consent
  không phải consent train AI. Tắt upload không tự purge dữ liệu cloud.
- Thêm controller bootstrap account fail-closed bằng insert-ignore, ghi
  `consent_events` với old/new, `privacy-v1`, source action, UTC timestamp và
  enforcement `applied`; hai consent AI còn lại không bị thay đổi.
- Tách secure UUID v4 generator thành core utility dùng chung; consent không
  phụ thuộc module Gemini và request ID scan giữ nguyên contract.
- `SupabaseService` nhận `SUPABASE_URL`/`SUPABASE_ANON_KEY` từ dart-define với
  ưu tiên cao hơn `.env`; runner Staging chỉ đưa anon key vào build file tạm và
  luôn xóa file trong `finally`.
- Targeted consent/Settings tests pass 13/13; full analyzer sạch; full Flutter
  suite pass 279 với 1 opt-in live test skip; live Staging worker E2E pass và
  cleanup pass. Production không linked/apply/reset/thay đổi.
- Device smoke chưa hoàn tất: `flutter devices` chỉ có Windows/Chrome/Edge,
  không có Android/iOS emulator; Windows host không được cấu hình. Android APK
  build dừng với `use of deleted Android v1 embedding` vì repo chỉ còn Gradle
  wrapper/GeneratedPluginRegistrant và thiếu Android v2 scaffold. Chưa tự chọn
  application ID để tránh khóa sai định danh phát hành.
- Mobile audit script báo các regex warning/issue trên kích thước icon/font có
  sẵn; consent control dùng `SwitchListTile.adaptive` với toàn hàng là touch
  target, nên không xác nhận đây là lỗi touch target của switch.

### 2026-09-04 — Real Library worker E2E passed on Staging

- Thêm opt-in live test chạy chính `SqliteLibraryStore`,
  `LibrarySyncWorker` và `SupabaseLibrarySyncGateway`; full test bình thường
  skip nên không vô tình ghi cloud.
- Thêm PowerShell runner fail-closed: xác minh linked Staging/name/health, tối
  đa hai active project, migration dry-run up to date và không in/commit key.
- Tạo Auth owner tạm, local SQLite aggregate + hai JPEG thật; 5/5 operation
  hoàn tất, private owner download, SHA-256 ảnh/JSON và 5 nhóm normalized
  row/raw JSON pass.
- Deterministic cleanup target được ghi trước network write; teardown luôn thử
  đủ mọi bước. Storage object, row và test user cleanup assertions pass trên bốn
  live run.
- Lần chạy đầu dừng trước mutation vì PowerShell 5.1 nested JSON array; parser
  được sửa bằng `ConvertFrom-Json -InputObject`, không hạ điều kiện an toàn.
- Full analyzer sạch; default Flutter suite pass 273 với 1 opt-in live test
  skipped. Production không linked, không apply/reset/thay đổi.

### 2026-09-04 — M3C runtime sync and offline startup locally verified

- Bỏ `SupabaseHealthGate`/remote preflight khỏi bootstrap để mất mạng không chặn
  SQLite, ảnh local và giao diện ôn tập.
- Nối coordinator vào auth session, consent/outbox stream, app resume và SQLite
  `next_attempt_at`; logout/consent OFF hủy lịch.
- Thêm native app-documents media resolver và Web fail-closed factory.
- Đặt toàn bộ runtime sync sau `LIBRARY_SYNC_ENABLED`, mặc định `false`, để
  không vô tình ghi Production trước migration/backfill.
- Targeted runtime/worker/SQLite/startup suite pass 23/23; full analyzer sạch,
  Flutter suite pass 273/273 và Web build với cờ bật thành công.
- Self-review bổ sung generation guard để auth event đồng thời không giữ
  subscription owner cũ; regression owner-switch pass.
- Chưa chạy worker E2E trên Staging, chưa thêm consent UI, không apply hoặc thay
  đổi Staging/Production trong increment này.
- Ghi nhận residual risk: profile query lỗi sẽ ưu tiên local access và có thể
  đưa account mới vào Home; cần local onboarding cache để phân biệt chính xác.
- Ghi nhận một full-test run báo 1 failure không xác định do output bị cắt; hai
  full rerun liên tiếp pass 273/273, chưa có bằng chứng đây là hồi quy M3C.

### 2026-09-04 — M3B outbox worker implemented and locally verified

- Thêm `LibrarySyncSource`, SQLite owner-scoped loaders, auth unblock và phục
  hồi operation `running` bị gián đoạn.
- Thêm bounded outbox worker với consent/auth gate, deterministic exponential
  backoff, error state `retry/blocked/done` và contract fail-closed.
- Thêm native Supabase gateway map đủ 5 M3A entity; media upload trước, metadata
  upsert sau, rồi mới ghi remote path/sync status vào SQLite.
- Siết dependency Photo Note để chờ toàn bộ detection/annotation evidence.
- Permanent purge chỉ hoàn tất tombstone sau remote delete thành công.
- Targeted M3B + SQLite + Storage test pass 20/20; targeted analyzer sạch.
- Full regression sau cùng: analyzer sạch và Flutter suite pass 267/267.
- Chưa nối scheduler/app lifecycle, chưa chạy worker E2E trên Staging và không
  apply/thay đổi Production.
- Self-review xác nhận `SupabaseHealthGate` hiện vẫn chặn offline app startup;
  ghi thành blocker M3C, không tuyên bố offline end-to-end đã hoàn tất.

### 2026-09-03 — Baseline + M3A verified on Staging

- Khôi phục schema gốc 15 bảng từ commit khởi tạo thành migration baseline
  `20260725204011_initial_schema.sql`; không sao chép dữ liệu Production.
- Thêm static contract test bắt buộc baseline là migration đầu tiên và không
  chứa các bảng được tạo ở migration sau.
- Dry-run xác nhận 20 migration theo đúng thứ tự; `db push` apply thành công
  toàn bộ trên Staging. Migration list local/remote khớp 20/20 và dry-run sau
  apply trả `upToDate=true`.
- `inspect db table-stats` xác nhận 21 bảng public đã tồn tại.
- Runtime hai user: owner row insert `201`, cross-user row read rỗng,
  cross-user row insert `403`, owner media upload `200`, cross-user media
  upload/read bị chặn, owner signed URL pass, bucket private và cleanup pass.
- Lần chạy runtime đầu báo false failure vì PowerShell bọc JSON `[]` thành mảng
  lồng; kiểm tra được sửa sang raw JSON và pass. Không có bằng chứng RLS leak.
- Production không bị apply/reset/thay đổi dữ liệu.
- Regression sau cùng: `flutter analyze --no-pub` sạch và full Flutter suite
  pass 260/260.

### 2026-09-03 — Free remote staging restored and linked

- Theo phê duyệt của chủ dự án, tái sử dụng project inactive làm Staging với
  điều kiện không phát sinh phí.
- Xác minh organization plan là `free` qua Management API và chỉ có một project
  active trước restore; restore tạo đúng project active thứ hai.
- Restore thành công tới `ACTIVE_HEALTHY`; repo đã đổi link từ Production sang
  Staging. Production không bị apply/reset/thay đổi dữ liệu.
- `supabase migration list --linked`: Staging có 0 migration remote và 19
  migration local-only.
- `supabase inspect db table-stats --linked`: không có bảng public.
- `supabase db push --linked --dry-run`: pass, dự kiến 19 migration; không push
  vì thiếu baseline schema mà migration đầu tiên phụ thuộc.
- Có một request restore ban đầu bị API từ chối do project ref không hợp lệ;
  không tạo side effect. Request sau dùng scalar/fail-fast validation và thành
  công.

### 2026-09-03 — Remote staging preflight không Docker

- Xác nhận project đã có Supabase CLI 2.116.0 và CLI session hợp lệ; không cần
  cài thêm dependency.
- Liệt kê project và migration history bằng thao tác read-only.
- Project active đang link chưa được xác nhận là staging nên không chạy push.
- Phát hiện migration drift: 4 remote-only, 5 local-only; yêu cầu reconcile
  trước khi dry-run/apply để tránh vô tình đẩy migration ngoài M3A.
- Không thay đổi Supabase remote trong preflight.
- Tạo staging mới đã được yêu cầu, nhưng thao tác create đang chờ xác nhận cho
  phép compute charge nếu organization là paid và cho phép CLI sinh password
  mạnh, dùng để create/link mà không in hoặc commit secret.

### 2026-09-03 — D2/D3 approved, M3A implemented in source

- Ghi nhận phê duyệt D2/D3 trực tiếp từ chủ dự án.
- Thêm additive Supabase migration cho normalized Library evidence, owner RLS
  và private `photo_notes` bucket.
- Đồng bộ schema snapshot; thay public URL/timestamp key bằng deterministic
  private object path và signed URL có hạn trong Flutter Storage service.
- Thêm unit/static contract tests. Migration chưa apply Production và runtime
  outbox upload chưa được nối; các phần này không được ghi là đã hoạt động.
- Verification: analyzer sạch, 7/7 M3A tests và 259/259 full tests pass, Web
  build pass; SQL runtime chưa chạy do môi trường thiếu Supabase CLI/PostgreSQL.

### 2026-09-03 — M3 cloud contract audit

- Audit `SyncRepository`, SQLite outbox, `StorageService`, Supabase
  `photo_notes` schema và Storage policies.
- Xác nhận outbox local đã có dependency/state transition nhưng chưa có worker.
- Phát hiện bucket/policy/service cũ không đạt private owner isolation; đánh
  dấu Supabase upload `BLOCKED` cho đến khi D2/D3 được phê duyệt và M3A thay
  contract này.
- Không upload hoặc thay đổi Production Supabase trong audit này.

### 2026-09-03 — Khởi tạo DB status sau M2C

- Tạo source of truth riêng cho database/storage để các phiên sau không phải
  suy luận lại từ lịch sử chat.
- Ghi nhận local JPEG + raw Gemini JSON + normalized aggregate đã hoạt động ở
  native và được kiểm thử.
- Ghi rõ Supabase upload/sync worker, Storage UI và on-device trainer chưa được
  triển khai.
- Ghi nhận D1 đã duyệt; D2–D10 vẫn pending.
- Baseline verification: analyzer sạch, 252/252 test pass, Web build pass.
