import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  /// Stream trạng thái đăng nhập của User (Supabase AuthState / User)
  Stream<User?> get authStateChanges;

  /// User hiện tại
  User? get currentUser;

  /// Đăng nhập bằng Email & Mật khẩu
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Đăng nhập bằng OAuth (Google hoặc Facebook)
  Future<bool> signInWithOAuth(OAuthProvider provider);

  /// Đăng xuất
  Future<void> signOut();

  /// Gửi email khôi phục mật khẩu
  Future<void> sendPasswordResetEmail(String email);
}
