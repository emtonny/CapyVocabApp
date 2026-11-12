# Hướng Dẫn Cấu Hình API Key (Vilao Scan & Gemini Chat Translation)
**Dự án:** CapyVocabApp
**Ngày lập:** 19/09/2026
**Cập nhật triển khai:** 26/10/2026

---

## 📌 1. Nguyên Tắc Bảo Mật & Kiến Trúc Dự Án

Trong CapyVocabApp:
1. **Client Flutter tuyệt đối không chứa Secret API Key:**
   Code Flutter (`lib/main.dart`) chỉ nạp file cấu hình công khai `assets/config/client.config` (chỉ gồm `SUPABASE_URL` và `SUPABASE_ANON_KEY`). Không nhúng key AI trực tiếp vào source code hay assets để tránh nguy cơ bị trích xuất khi dịch ngược file APK/Web bundle.
2. **AI Proxy qua Supabase Edge Function:**
   Mọi request gọi AI (Vision Scan, dịch Chat người-với-người) đều gửi từ Flutter lên Supabase Edge Function có chứng thực token đăng nhập (JWT). Edge Function trên server sẽ đọc Secret Key an toàn rồi mới gọi ra bên ngoài (Vilao, OpenAI, Gemini, v.v.).
3. **Môi trường Supabase trong dự án:**
   - **Staging** (đang link trực tiếp với repo): Project Ref `nxteaznowkfennxpqjmt`
   - **Production**: Project Ref `vmxonxqxrlkssdzsucrg`

---

## 📷 2. Cập Nhật / Đổi Key API Vilao (Tính Năng AI Vision Scan)

Tính năng **AI Scan** sử dụng gateway tương thích OpenAI của **Vilao** (`https://api.vilao.ai/v1`) thông qua Supabase Edge Function `gemini-vision-scan`.

> [!NOTE]
> Do quy ước gateway kế thừa từ upstream, tên biến secret trên Supabase Edge Function đại diện cho consumer key của Vilao là **`GEMINI_API_KEY`**.
> - `GEMINI_BASE_URL`: mặc định là `https://api.vilao.ai/v1`
> - `GEMINI_MODEL`: mặc định là `gemini-3.8-flash`

### Cách 1: Qua Supabase CLI (Khuyến nghị)

Mở terminal PowerShell tại thư mục gốc của repo:

1. **Set Secret mới:**
   - Cho môi trường **Staging**:
     ```powershell
     npx supabase secrets set GEMINI_API_KEY="<key_vilao_moi_cua_ban>" --project-ref nxteaznowkfennxpqjmt
     ```
   - Cho môi trường **Production** *(cần phê duyệt trước khi thao tác)*:
     ```powershell
     npx supabase secrets set GEMINI_API_KEY="<key_vilao_moi_cua_ban>" --project-ref vmxonxqxrlkssdzsucrg
     ```

2. **Kiểm tra secret đã ghi nhận:**
   ```powershell
   npx supabase secrets list --project-ref nxteaznowkfennxpqjmt --output json
   ```
   *(Đảm bảo thấy `GEMINI_API_KEY` có trong danh sách).*

### Cách 2: Qua Supabase Web Dashboard

1. Đăng nhập [Supabase Dashboard](https://supabase.com/dashboard) và chọn đúng Project (**Staging** hoặc **Production**).
2. Vào **Project Settings** (biểu tượng bánh răng ở thanh điều hướng bên trái).
3. Chọn mục **Edge Functions** (hoặc tab **Secrets**).
4. Tìm secret `GEMINI_API_KEY`:
   - Bấm **Edit** (hoặc bấm **Add New Secret** nếu chưa có).
   - Tên: `GEMINI_API_KEY`
   - Giá trị: `<key_vilao_moi_cua_ban>`
   - Bấm **Save**.

*Lưu ý: Edge Function tự động nạp secret mới ở request tiếp theo, **không cần re-deploy** lại function.*

---

## 💬 3. Key Gemini Cho Dịch Chat Người-Với-Người

Dự án **không có chatbot riêng**. Key này chỉ được dùng trong Edge Function
`chat-translation-worker` để dịch tin nhắn giữa hai người dùng theo hồ sơ ngôn
ngữ. Tin nhắn thô vẫn được chuyển trước; lỗi dịch không được chặn Chat.

Chat translation v3 gọi native Gemini bằng model `gemini-3-flash-preview`.
Secret này độc lập với key Vilao của AI Scan.

### Bước 1: Lưu key Gemini bằng tên riêng cho Chat translation

```powershell
npx supabase secrets set CHAT_TRANSLATION_API_KEY="<key_gemini_chat>" CHAT_TRANSLATION_PROVIDER="gemini" --project-ref nxteaznowkfennxpqjmt
```

- Không dùng `GEMINI_API_KEY` của AI Scan.
- Không ghi key vào `.env`, Flutter, assets, tài liệu hoặc lịch sử Git.
- Sau khi set, chỉ kiểm tra **tên** secret bằng `supabase secrets list`; không in
  hoặc sao chép lại giá trị.
- Xóa clipboard và mọi file tạm ngay sau thao tác.

### Bước 2: Deploy worker dịch Chat

```powershell
npx supabase functions deploy chat-translation-worker --project-ref nxteaznowkfennxpqjmt --no-verify-jwt --use-api
```

Worker gọi native Gemini bằng key ở server, giữ contract queue/single-flight,
circuit breaker và safe error hiện có. Client Flutter không gọi provider trực
tiếp và không nhận được key.

### Bước 3: Xác minh

1. Chạy Deno test và type-check của `chat-translation-worker`.
2. Chạy smoke bằng dữ liệu tổng hợp trên exact Staging; xác nhận raw message,
   một translation dùng chung, RLS hai tài khoản và cleanup fixture.
3. Kiểm tra Production không đổi và Training không nhận bản dịch/provider output.

Không đổi `CHAT_TRANSLATION_PROVIDER` sang giá trị khác: worker v3 fail-closed
nếu mode không phải `gemini`. Khi cần rollback, dùng rollout đã được xác minh;
các row v1/v2 vẫn được giữ và client tiếp tục đọc được.

---
## 🛠️ 4. Bảng Tra Cứu Lệnh Thường Dùng

| Mục tiêu | Lệnh PowerShell |
|---|---|
| **Xem danh sách secret Staging** | `npx supabase secrets list --project-ref nxteaznowkfennxpqjmt --output json` |
| **Set key Vilao AI Scan (Staging)** | `npx supabase secrets set GEMINI_API_KEY="<key>" --project-ref nxteaznowkfennxpqjmt` |
| **Set key dịch Chat (Staging)** | `npx supabase secrets set CHAT_TRANSLATION_API_KEY="<key>" CHAT_TRANSLATION_PROVIDER="gemini" --project-ref nxteaznowkfennxpqjmt` |
| **Deploy function AI Scan** | `npx supabase functions deploy gemini-vision-scan --project-ref nxteaznowkfennxpqjmt` |
| **Deploy worker dịch Chat** | `npx supabase functions deploy chat-translation-worker --project-ref nxteaznowkfennxpqjmt --no-verify-jwt --use-api` |
| **Test Deno function local** | `deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan` |
