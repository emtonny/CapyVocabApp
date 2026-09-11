import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/repositories/auth_repository.dart';

String? defaultEmailRedirectTo(Uri baseUri) {
  if (baseUri.scheme != 'http' && baseUri.scheme != 'https') return null;
  return baseUri.origin;
}

class AuthRepositoryImpl implements AuthRepository {
  static const mobileLoginRedirectUrl = 'capyvocab://login-callback/';
  static const mobileResetRedirectUrl = 'capyvocab://reset-password/';

  final SupabaseClient _supabaseClient;
  final String _emailRedirectTo;
  final String _passwordResetRedirectTo;

  AuthRepositoryImpl({
    SupabaseClient? supabaseClient,
    String? emailRedirectTo,
    String? passwordResetRedirectTo,
  })  : _supabaseClient = supabaseClient ?? SupabaseService.client,
        _emailRedirectTo = emailRedirectTo ??
            (kIsWeb ? Uri.base.origin : mobileLoginRedirectUrl),
        _passwordResetRedirectTo = passwordResetRedirectTo ??
            (kIsWeb
                ? '${Uri.base.origin}/reset-password'
                : mobileResetRedirectUrl);

  @override
  Stream<User?> get authStateChanges {
    return _supabaseClient.auth.onAuthStateChange.map(
      (data) => data.session?.user,
    );
  }

  @override
  User? get currentUser => _supabaseClient.auth.currentUser;

  @override
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _emailRedirectTo,
        data: {'display_name': displayName},
      );

      if (response.user?.identities?.isEmpty == true) {
        throw const AuthException(
          'Email already registered.',
          code: 'user_already_exists',
        );
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    try {
      return await _supabaseClient.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : mobileLoginRedirectUrl,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabaseClient.auth.resetPasswordForEmail(
      email,
      redirectTo: _passwordResetRedirectTo,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _supabaseClient.auth.updateUser(
      UserAttributes(password: password),
    );
  }
}
