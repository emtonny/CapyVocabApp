# Hướng Dẫn Cấu Hình và Thêm API Key (Vilao & AI Chatbot)
**Dự án:** CapyVocabApp  
**Ngày lập:** 19/09/2026  

---

## 📌 1. Nguyên Tắc Bảo Mật & Kiến Trúc Dự Án

Trong CapyVocabApp:
1. **Client Flutter tuyệt đối không chứa Secret API Key:**  
   Code Flutter (`lib/main.dart`) chỉ nạp file cấu hình công khai `assets/config/client.config` (chỉ gồm `SUPABASE_URL` và `SUPABASE_ANON_KEY`). Không nhúng key AI trực tiếp vào source code hay assets để tránh nguy cơ bị trích xuất khi dịch ngược file APK/Web bundle.
2. **AI Proxy qua Supabase Edge Function:**  
   Mọi request gọi AI (Vision Scan, Chatbot) đều gửi từ Flutter lên Supabase Edge Function có chứng thực token đăng nhập (JWT). Edge Function trên server sẽ đọc Secret Key an toàn rồi mới gọi ra bên ngoài (Vilao, OpenAI, Gemini, v.v.).
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

## 💬 3. Thêm Key API Mới Cho Tính Năng Chat Với Bot (AI Chatbot)

Khi thêm một dịch vụ AI khác (hoặc key Vilao/OpenAI/Gemini/DeepSeek riêng) để làm Chatbot, bạn có 2 cách thực hiện:

### Phương Án A: Chuẩn Kiến Trúc Dự Án (Server-side Edge Function — Khuyên dùng)

#### Bước 1: Lưu Secret lên Supabase
1. Đặt tên biến riêng biệt, ví dụ: `CHATBOT_API_KEY` (và nếu cần endpoint riêng: `CHATBOT_BASE_URL`).
2. Chạy lệnh set secret:
   ```powershell
   npx supabase secrets set CHATBOT_API_KEY="<key_bot_cua_ban>" CHATBOT_BASE_URL="https://api.vilao.ai/v1" --project-ref nxteaznowkfennxpqjmt
   ```
   *(Hoặc thêm trong Supabase Dashboard -> Project Settings -> Edge Functions -> Secrets).*
3. Ghi chú lại vào file `.env` local của bạn để theo dõi dev:
   ```env
   CHATBOT_API_KEY=<key_bot_cua_ban>
   CHATBOT_BASE_URL=https://api.vilao.ai/v1
   ```

#### Bước 2: Tạo Edge Function `chat-bot` trên Supabase
Tạo file `supabase/functions/chat-bot/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CHATBOT_API_KEY = Deno.env.get("CHATBOT_API_KEY");
const CHATBOT_BASE_URL = Deno.env.get("CHATBOT_BASE_URL") || "https://api.vilao.ai/v1";

serve(async (req) => {
  // CORS header
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { message } = await req.json();
    if (!message) {
      return new Response(JSON.stringify({ error: "Missing message" }), { status: 400 });
    }

    // Gọi AI Gateway
    const response = await fetch(`${CHATBOT_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${CHATBOT_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gemini-3.8-flash",
        messages: [
          { role: "system", content: "You are Capy, a chill and helpful English vocabulary learning assistant." },
          { role: "user", content: message },
        ],
        temperature: 0.7,
      }),
    });

    const data = await response.json();
    const reply = data.choices?.[0]?.message?.content ?? "";

    return new Response(JSON.stringify({ reply }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
```

Deploy function lên Staging:
```powershell
npx supabase functions deploy chat-bot --project-ref nxteaznowkfennxpqjmt
```

#### Bước 3: Gọi từ Flutter Client
Trong code Flutter (`lib/features/chatbot/data/datasources/chat_supabase_datasource.dart`), gọi trực tiếp qua Supabase SDK mà không cần cầm API key:
```dart
final response = await Supabase.instance.client.functions.invoke(
  'chat-bot',
  body: {'message': userMessageText},
);

final replyText = response.data['reply'] as String;
```

---

### Phương Án B: Gọi Trực Tiếp Từ Flutter (Chỉ Dùng Test Nhanh / Prototype Nội Bộ)

Nếu bạn chỉ muốn thử nghiệm cục bộ trên máy mà chưa dựng Edge Function:

#### Bước 1: Khai báo Key trong file `.env`
Mở file `.env` ở thư mục gốc dự án:
```env
CHATBOT_API_KEY=your_key_here
CHATBOT_BASE_URL=https://api.vilao.ai/v1
```

#### Bước 2: Nạp `.env` vào Flutter
1. Mở `pubspec.yaml`, thêm `.env` vào danh sách `assets`:
   ```yaml
   flutter:
     assets:
       - .env
       - assets/config/client.config
   ```
2. Trong `lib/main.dart`, nạp file `.env`:
   ```dart
   await dotenv.load(fileName: '.env');
   ```

#### Bước 3: Gửi HTTP Request từ Flutter
```dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<String> sendChatMessage(String prompt) async {
  final apiKey = dotenv.env['CHATBOT_API_KEY'];
  final baseUrl = dotenv.env['CHATBOT_BASE_URL'] ?? 'https://api.vilao.ai/v1';

  final response = await http.post(
    Uri.parse('$baseUrl/chat/completions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      'model': 'gemini-3.8-flash',
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  } else {
    throw Exception('Failed to chat: ${response.body}');
  }
}
```

> [!WARNING]
> Nếu build release APK hoặc Web với Phương án B, file `.env` sẽ nằm trần trong file APK/Web bundle, bất kỳ ai cũng có thể mở ra xem và lấy cắp API key. Khi triển khai chính thức, bắt buộc dùng **Phương Án A**.

---

## 🛠️ 4. Bảng Tra Cứu Lệnh Thường Dùng

| Mục tiêu | Lệnh PowerShell |
|---|---|
| **Xem danh sách secret Staging** | `npx supabase secrets list --project-ref nxteaznowkfennxpqjmt --output json` |
| **Set key Vilao AI Scan (Staging)** | `npx supabase secrets set GEMINI_API_KEY="<key>" --project-ref nxteaznowkfennxpqjmt` |
| **Set key Chatbot (Staging)** | `npx supabase secrets set CHATBOT_API_KEY="<key>" --project-ref nxteaznowkfennxpqjmt` |
| **Deploy function AI Scan** | `npx supabase functions deploy gemini-vision-scan --project-ref nxteaznowkfennxpqjmt` |
| **Deploy function Chatbot** | `npx supabase functions deploy chat-bot --project-ref nxteaznowkfennxpqjmt` |
| **Test Deno function local** | `deno test --config supabase/functions/gemini-vision-scan/deno.json --node-modules-dir=auto --allow-env supabase/functions/gemini-vision-scan` |
