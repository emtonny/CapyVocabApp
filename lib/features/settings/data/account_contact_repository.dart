import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/data/repositories/auth_repository_impl.dart';
import '../domain/account_contact_settings.dart';

class AccountContactException implements Exception {
  const AccountContactException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AccountContactRepository {
  Future<AccountContactSettings> load();

  Future<void> requestEmailChange({
    required String email,
    required String currentPassword,
  });

  Future<AccountContactSettings> updateVisibility({
    required bool showEmail,
    required bool showPhone,
  });
}

class SupabaseAccountContactRepository implements AccountContactRepository {
  SupabaseAccountContactRepository({
    SupabaseClient? client,
    String? emailRedirectTo,
  })  : _client = client ?? SupabaseService.client,
        _emailRedirectTo = emailRedirectTo ??
            (kIsWeb
                ? Uri.base.origin
                : AuthRepositoryImpl.mobileLoginRedirectUrl);

  final SupabaseClient _client;
  final String _emailRedirectTo;

  @override
  Future<AccountContactSettings> load() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser?.emailConfirmedAt != null) {
        await _client.rpc('sync_my_verified_email');
      }
      final response = await _client.rpc('get_my_account_contact_settings');
      final row = _singleRow(response);
      return AccountContactSettings.fromJson(row);
    } catch (error) {
      throw AccountContactException(_messageFor(error));
    }
  }

  @override
  Future<void> requestEmailChange({
    required String email,
    required String currentPassword,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const AccountContactException('Email chưa đúng định dạng.');
    }
    if (currentPassword.isEmpty) {
      throw const AccountContactException('Vui lòng nhập mật khẩu hiện tại.');
    }
    try {
      await _client.auth.updateUser(
        UserAttributes(email: normalized, currentPassword: currentPassword),
        emailRedirectTo: _emailRedirectTo,
      );
    } catch (error) {
      throw AccountContactException(_messageFor(error));
    }
  }

  @override
  Future<AccountContactSettings> updateVisibility({
    required bool showEmail,
    required bool showPhone,
  }) async {
    try {
      final response = await _client.rpc(
        'update_my_account_contact_visibility',
        params: {
          'p_show_email': showEmail,
          'p_show_phone': showPhone,
        },
      );
      return AccountContactSettings.fromJson(_singleRow(response));
    } catch (error) {
      throw AccountContactException(_messageFor(error));
    }
  }

  Map<String, dynamic> _singleRow(Object? response) {
    if (response is List && response.length == 1 && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const AccountContactException(
      'Máy chủ trả về trạng thái liên hệ không hợp lệ.',
    );
  }

  String _messageFor(Object error) {
    if (error is AccountContactException) return error.message;
    if (error is AuthException && error.code == 'invalid_credentials') {
      return 'Mật khẩu hiện tại không đúng.';
    }
    if (error is PostgrestException &&
        error.message.contains('contact_not_verified')) {
      return 'Liên hệ phải được xác nhận trước khi cho bạn bè xem.';
    }
    return 'Không thể cập nhật thông tin liên hệ. Vui lòng thử lại.';
  }
}

final accountContactRepositoryProvider = Provider<AccountContactRepository>(
  (ref) => SupabaseAccountContactRepository(),
);
