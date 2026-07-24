import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  /// Stream trạng thái đăng nhập của User
  Stream<User?> get authStateChanges;

  /// User hiện tại
  User? get currentUser;

  /// Đăng nhập bằng Email & Mật khẩu
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle();

  /// Đăng xuất
  Future<void> signOut();

  /// Gửi email khôi phục mật khẩu
  Future<void> sendPasswordResetEmail(String email);
}

