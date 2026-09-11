# Hướng dẫn đồng bộ Supabase — Staging vs Production

> **Mục đích:** Tài liệu này dành cho **cả hai bên** — người phát triển tính năng (staging)
> và người thiết kế/quản lý production — để hiểu rõ sự khác biệt giữa hai môi trường
> và các bước cần thực hiện khi muốn đưa thay đổi từ staging lên production.
>
> Cập nhật lần cuối: **2026-09-11**
> Người viết: Dev (AI-scan branch)

---

## 1. Hai môi trường hoàn toàn độc lập

| Thuộc tính | Staging (của mình) | Production (của bạn) |
|---|---|---|
| **Supabase Project URL** | `https://vmxonxqxrlkssdzsucrg.supabase.co` | Project riêng — URL khác |
| **Database** | Instance riêng | Instance riêng |
| **Storage bucket** | `photo_notes` — **private** | `photo_notes` — đã đổi private (Gate 3) |
| **Edge Functions** | Deployed trên Staging | Cần deploy riêng |
| **Migrations đã apply** | **21/21** | **21/21** (sau Gate 3 ngày 11/9) |
| **Dữ liệu** | Data demo/test | Data người dùng thật |

> Hai project Supabase hoàn toàn độc lập. Code trong repo không tự apply lên production.
> Muốn apply phải chạy lệnh tường minh với `--project-ref <production-ref>`.

---

## 2. Tổng quan 21 migration files

### Nhóm A — Schema gốc và Auth (tháng 7/2026)

| File | Nội dung |
|---|---|
| `20260725204011_initial_schema.sql` | Schema ban đầu — bảng vocabularies, users, photo_notes |
| `20260729065229_add_auto_create_public_user_trigger.sql` | Trigger tự tạo profile public khi user đăng ký |
| `20260729065255_restrict_photo_notes_bucket_listing.sql` | Giới hạn listing trên bucket photo_notes |
| `20260729074440_harden_users_arena_and_photo_notes_rls.sql` | Tăng cường RLS cho bảng users và photo_notes |
| `20260730074054_add_onboarding_fields_to_users.sql` | Thêm trường onboarding vào bảng users |
| `20260730074241_add_onboarding_fields_to_users.sql` | Bổ sung thêm trường onboarding (patch) |
| `20260730091212_complete_onboarding_rpc.sql` | RPC complete_onboarding |
| `20260730145012_secure_public_profile_projection.sql` | Giới hạn data public trả về từ profile |
| `20260730151830_harden_onboarding_security.sql` | Siết chặt toàn bộ policy onboarding |

### Nhóm B — Tính năng bổ sung Auth/User (8 đầu/2026)

| File | Nội dung |
|---|---|
| `20260801070841_clear_duplicate_test_phone_and_add_unique.sql` | Xóa duplicate, thêm unique constraint phone |
| `20260801072258_add_username_phone_availability_rpc.sql` | RPC kiểm tra username/phone đã tồn tại |
| `20260804065808_add_reset_my_onboarding_debug_rpc.sql` | RPC debug reset onboarding (chỉ dùng khi test) |
| `20260806080704_add_study_end_time_and_update_onboarding_rpc.sql` | Thêm trường giờ học kết thúc |
| `20260806081825_allow_overnight_study_time_range.sql` | Cho phép khoảng giờ học qua nửa đêm |

### Nhóm C — AI Scan Infrastructure (8 giữa/2026)

| File | Nội dung |
|---|---|
| `20260815141623_add_gemini_model_health.sql` | Bảng gemini_model_health — theo dõi trạng thái model |
| `20260827203358_harden_subscription_entitlements.sql` | Tiers phân quyền subscription free/pro |
| `20260828173421_add_ai_scan_request_ledger.sql` | Bảng ai_scan_request_ledger — quota tracking |
| `20260828174457_restrict_ai_scan_ledger_service_role.sql` | RLS — chỉ service_role ghi vào ledger |
| `20260829152311_add_gemini_model_circuit_breaker.sql` | Circuit breaker — tắt model khi lỗi liên tiếp |

### Nhóm D — Library Cloud Storage (9/2026) ⭐ MỚI NHẤT

| File | Nội dung |
|---|---|
| `20260903120000_add_library_cloud_storage_contract.sql` | **M3A** — media_assets, photo_notes normalized, library_change_events, private bucket, owner RLS |
| `20260910120000_add_library_cloud_pull_feed.sql` | **M4.5** — library_pull_cursors cho sync delta pull |

---

## 3. Trạng thái đồng bộ hiện tại (sau Gate 3 ngày 11/9)

```
Staging  — local: 21 | remote: 21 | upToDate: true ✅
Production — local: 21 | remote: 21 | upToDate: true ✅
```

Cả hai môi trường đã đồng bộ đầy đủ 21 migrations.

---

## 4. Khác biệt quan trọng: Storage bucket

**CẢNH BÁO — đây là điểm quan trọng nhất:**

| | Staging | Production (sau Gate 3) |
|---|---|---|
| Bucket `photo_notes` | `public = false` ✅ | `public = false` ✅ |
| Object URL | Signed URL (có hạn) | Signed URL (có hạn) |
| Object key format | `{user_id}/{media_asset_id}` | `{user_id}/{media_asset_id}` |

> Bucket đã được đổi sang private sau khi apply M3A.
> Public URL cũ (nếu còn tồn tại trong client cũ) sẽ không hoạt động.
> Tất cả image request phải dùng signed URL từ Edge Function hoặc Supabase Storage API.

---

## 5. Edge Functions — trạng thái và cách deploy

### Danh sách module trong `gemini-vision-scan`

| Module | Vai trò |
|---|---|
| `index.ts` | Entry point — nhận request, gọi auth/entitlement/scan |
| `gemini_client.ts` | Gọi Gemini API và Vilao gateway |
| `gemini_model_health.ts` | Circuit breaker — kiểm tra model trước khi gọi |
| `scan_ledger.ts` | Ghi nhận mỗi lượt scan vào ledger |
| `scan_prompt.ts` | Tạo prompt cho Gemini |
| `model_policy.ts` | Policy chọn model theo tier |
| `image_payload.ts` | Xử lý và validate image payload |
| `detection_hierarchy.ts` | Phân cấp detection kết quả |
| `detection_ranking.ts` | Xếp hạng detection kết quả |
| `_shared/auth.ts` | Validate JWT token |
| `_shared/entitlements.ts` | Kiểm tra quyền scan theo subscription |

### Deploy lên production

```powershell
# Kiểm tra function đang chạy trên production
npx supabase functions list --project-ref <production-ref>

# Deploy (chỉ khi đã review code và set đủ secrets)
npx supabase functions deploy gemini-vision-scan --project-ref <production-ref>
```

---

## 6. Secrets cần cấu hình trên production

Vào Supabase Dashboard → Project Settings → Edge Functions → Secrets:

| Secret | Bắt buộc | Dùng cho |
|---|---|---|
| `GEMINI_API_KEY` | ✅ | Gọi Gemini API trực tiếp |
| `VILAO_API_KEY` | ✅ (mới từ commit cbd7318) | Vilao OpenAI-compatible gateway |
| `VILAO_BASE_URL` | ✅ (mới từ commit cbd7318) | URL của Vilao gateway |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ | Edge Function ghi vào ai_scan_request_ledger |

> **KHÔNG bao giờ commit secrets vào repo.**
> Nếu có secret nào bị lộ, rotate ngay trên Dashboard.

---

## 7. Feature flags trong Flutter app

Các tính năng sau mặc định **TẮT** — không tự kích hoạt:

| Flag | Mặc định | Khi nào bật |
|---|---|---|
| `LIBRARY_SYNC_ENABLED=true` | `false` | Build APK có cloud sync |
| Cloud Backup (Settings UI) | OFF | User tự bật |
| Federated AI contribution | OFF | User opt-in (chưa implement) |

```powershell
# Build APK với sync bật
flutter build apk --dart-define=LIBRARY_SYNC_ENABLED=true
```

---

## 8. Lưu ý bảo mật

### client.config chưa được gitignore

File `assets/config/client.config` chứa `SUPABASE_ANON_KEY` và **chưa có trong .gitignore** — đã được commit lên GitHub.

- **Anon key** theo thiết kế Supabase là *publishable* — được nhúng vào client app, không phải secret.
- **Service role key** tuyệt đối không được commit — kiểm tra lại toàn bộ repo nếu nghi ngờ.

Nếu muốn bảo vệ anon key (không bắt buộc, nhưng good practice):
1. Thêm `assets/config/client.config` vào `.gitignore`
2. Tạo `assets/config/client.config.example` với placeholder
3. Mỗi người setup local copy riêng

---

## 9. Checklist khi nhận code mới từ repo (dành cho bạn — production)

- [ ] `git pull origin AI-scan` để lấy code mới nhất
- [ ] Xem `supabase/migrations/` có file mới nào không
- [ ] Chạy `npx supabase migration list --project-ref <production-ref>` kiểm tra trạng thái
- [ ] Dry-run: `npx supabase db push --project-ref <production-ref> --dry-run`
- [ ] Review nội dung migration mới trước khi apply
- [ ] Backup: dump schema production nếu có migration lớn
- [ ] Apply: `npx supabase db push --project-ref <production-ref> --yes`
- [ ] Kiểm tra Edge Functions có thay đổi không → deploy nếu cần
- [ ] Kiểm tra Secrets dashboard đủ chưa
- [ ] Verify: `migration list` → `upToDate=true` ✅

---

## 10. Khi gặp sự cố

1. **Rollback ngay** — không tiếp tục thao tác thêm
2. Kiểm tra Supabase Dashboard → Logs → Postgres / Edge Functions
3. Báo lỗi kèm: tên migration đang apply, output `migration list`, log lỗi
4. Không tự sửa production trực tiếp mà không thống nhất trước

---

*Xem thêm chi tiết kỹ thuật đầy đủ tại [db_status.md](./db_status.md)*
