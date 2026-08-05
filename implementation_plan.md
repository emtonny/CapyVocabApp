# Kế hoạch xử lý lỗi Đăng nhập không chuyển tới màn hình Onboarding (5 bước)

## Phân tích nguyên nhân gốc rễ (Root Cause Analysis)

Dựa trên hình ảnh bảng `public.users` trong Supabase bạn cung cấp:
- Hàng 1 (Tài khoản mới): `username` = `NULL`, `age` = `NULL`, `phone` = `NULL`, `onboarding_completed` = `FALSE`.
- Hàng 2 (Tài khoản `taideptrai`): đã hoàn tất onboarding trước đó (`onboarding_completed` = `TRUE`).

Khi đăng nhập bằng Tài khoản mới (Hàng 1), mặc dù `onboarding_completed` là `FALSE`, ứng dụng vẫn nhảy thẳng vào `/home` là do:

1. **Chuyển trang cứng tại [auth_screen.dart](file:///d:/CapyVocabApp/lib/features/auth/presentation/screens/auth_screen.dart#L64-L67):**
   Trong hàm `_submit()`, sau khi `signInWithPassword` hoặc `signUp` trả về `session != null`, code đang gọi thẳng:
   ```dart
   if (session != null) {
     context.go('/home'); // <-- Đang gọi cứng điều hướng sang /home
     return;
   }
   ```
   Lệnh `context.go('/home')` cưỡng ép `GoRouter` chuyển ngay sang `/home`, đè lên luồng kiểm tra tự động của Router.

2. **Xung đột giữa lệnh gọi thủ công và `AppRouter.redirect`:**
   `AppRouter` đã có sẵn cơ chế `_authRefreshListenable` lắng nghe `onAuthStateChange`. Đúng ra, khi có `session`, `AppRouter` sẽ tự động truy vấn `onboarding_completed` từ Supabase:
   - Nếu `false` -> chuyển hướng tới `/onboarding`.
   - Nếu `true` -> chuyển hướng tới `/home`.
   
   Do `AuthScreen` gọi `context.go('/home')` thủ công, luồng tự động này bị can thiệp bất hợp lý.

---

## Các thay đổi đề xuất (Proposed Changes)

### 1. Sửa màn hình Auth ([auth_screen.dart](file:///d:/CapyVocabApp/lib/features/auth/presentation/screens/auth_screen.dart))

#### [MODIFY] [auth_screen.dart](file:///d:/CapyVocabApp/lib/features/auth/presentation/screens/auth_screen.dart)
- Bỏ lệnh gọi cứng `context.go('/home')` sau khi đăng nhập/đăng ký thành công.
- Để `GoRouter` và `AppRouter.redirect` tự động quyết định chuyển sang `/onboarding` hay `/home` dựa theo giá trị `onboarding_completed` thực tế trong database.

### 2. Kiểm tra bộ điều hướng ([app_router.dart](file:///d:/CapyVocabApp/lib/core/routes/app_router.dart))

#### [MODIFY] [app_router.dart](file:///d:/CapyVocabApp/lib/core/routes/app_router.dart)
- Rà soát đảm bảo hàm `redirect` xử lý an toàn mọi trường hợp: nếu tài khoản chưa có cột `onboarding_completed` hoặc giá trị là `false`, ứng dụng chắc chắn chuyển về `/onboarding`.

---

## Kế hoạch kiểm thử (Verification Plan)

### Automated Tests
- Chạy toàn bộ test tự động của dự án:
  ```bash
  flutter test
  ```

### Manual Verification
1. Đăng nhập bằng tài khoản chưa làm onboarding (`onboarding_completed = FALSE`) -> Xác nhận ứng dụng tự động mở màn hình 5 bước `/onboarding`.
2. Đăng nhập bằng tài khoản đã hoàn thành onboarding (ví dụ: `taideptrai` với `onboarding_completed = TRUE`) -> Xác nhận ứng dụng tự động vào `/home`.
