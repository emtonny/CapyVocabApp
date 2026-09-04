import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthFailureType {
  wrongPassword,
  emailAlreadyExists,
  emailNotConfirmed,
  rateLimited,
  weakPassword,
  samePassword,
  invalidRecovery,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.type, this.message);

  factory AuthFailure.from(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return const AuthFailure(
            AuthFailureType.wrongPassword,
            'Mật khẩu không đúng.',
          );
        case 'email_exists':
        case 'user_already_exists':
          return const AuthFailure(
            AuthFailureType.emailAlreadyExists,
            'Email này đã được đăng ký.',
          );
        case 'email_not_confirmed':
          return const AuthFailure(
            AuthFailureType.emailNotConfirmed,
            'Email chưa được xác nhận.',
          );
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
          return const AuthFailure(
            AuthFailureType.rateLimited,
            'Bạn thao tác quá nhanh. Vui lòng chờ một phút rồi thử lại.',
          );
        case 'weak_password':
          return const AuthFailure(
            AuthFailureType.weakPassword,
            'Mật khẩu chưa đáp ứng yêu cầu bảo mật.',
          );
        case 'same_password':
          return const AuthFailure(
            AuthFailureType.samePassword,
            'Mật khẩu mới phải khác mật khẩu hiện tại.',
          );
        case 'otp_expired':
        case 'flow_state_expired':
        case 'bad_code_verifier':
        case 'pkce_verification_failed':
          return const AuthFailure(
            AuthFailureType.invalidRecovery,
            'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.',
          );
      }

      if (error.statusCode == '429') {
        return const AuthFailure(
          AuthFailureType.rateLimited,
          'Bạn thao tác quá nhanh. Vui lòng chờ một phút rồi thử lại.',
        );
      }
    }

    return const AuthFailure(
      AuthFailureType.unknown,
      'Đã xảy ra lỗi xác thực. Vui lòng thử lại.',
    );
  }

  final AuthFailureType type;
  final String message;

  @override
  String toString() => message;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(),
);

class AuthNotifier extends StateNotifier<AsyncValue<Session?>> {
  AuthNotifier({
    required AuthRepository repository,
    required Session? initialSession,
  })  : _repository = repository,
        super(AsyncData(initialSession));

  final AuthRepository _repository;

  Future<Session?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();

    try {
      final response = await _repository.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      state = AsyncData(response.session);
      return response.session;
    } catch (error, stackTrace) {
      state = AsyncError(AuthFailure.from(error), stackTrace);
      return null;
    }
  }

  Future<Session?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();

    try {
      final response = await _repository.signUpWithEmailAndPassword(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      );
      state = AsyncData(response.session);
      return response.session;
    } catch (error, stackTrace) {
      state = AsyncError(AuthFailure.from(error), stackTrace);
      return null;
    }
  }

  Future<void> signOut() async {
    if (state.isLoading) return;
    state = const AsyncLoading();

    try {
      await _repository.signOut();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(AuthFailure.from(error), stackTrace);
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<Session?>>((ref) {
  return AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
    initialSession: SupabaseService.auth.currentSession,
  );
});

class PasswordRecoveryNotifier extends StateNotifier<AsyncValue<void>> {
  PasswordRecoveryNotifier(this._repository) : super(const AsyncData(null));

  final AuthRepository _repository;

  Future<bool> sendResetEmail(String email) => _run(
        () => _repository.sendPasswordResetEmail(email.trim()),
      );

  Future<bool> updatePassword(String password) => _run(
        () => _repository.updatePassword(password),
      );

  void clear() => state = const AsyncData(null);

  Future<bool> _run(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();

    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(AuthFailure.from(error), stackTrace);
      return false;
    }
  }
}

final passwordRecoveryProvider =
    StateNotifierProvider<PasswordRecoveryNotifier, AsyncValue<void>>((ref) {
  return PasswordRecoveryNotifier(ref.watch(authRepositoryProvider));
});
