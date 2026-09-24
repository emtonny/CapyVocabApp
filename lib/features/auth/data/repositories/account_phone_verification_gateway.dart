import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/account_phone.dart';

class AccountPhoneVerificationException implements Exception {
  const AccountPhoneVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AccountPhoneVerificationGateway {
  String? get verifiedPhone;

  Future<void> requestCode(String phone, {String? currentPassword});

  Future<void> verifyCode({required String phone, required String code});
}

class SupabaseAccountPhoneVerificationGateway
    implements AccountPhoneVerificationGateway {
  SupabaseAccountPhoneVerificationGateway({SupabaseClient? client})
      : _providedClient = client;

  final SupabaseClient? _providedClient;

  SupabaseClient get _client => _providedClient ?? SupabaseService.client;

  @override
  String? get verifiedPhone {
    try {
      final user = _client.auth.currentUser;
      if (user?.phoneConfirmedAt == null) return null;
      return normalizeAccountPhone(user?.phone == null
          ? null
          : '+${user!.phone!.replaceFirst(RegExp(r'^\+'), '')}');
    } on AssertionError {
      // Widget tests can build onboarding without a global Supabase singleton.
      return null;
    }
  }

  @override
  Future<void> requestCode(String phone, {String? currentPassword}) async {
    final normalized = normalizeAccountPhone(phone);
    final ownerId = _client.auth.currentUser?.id;
    if (normalized == null) {
      throw const AccountPhoneVerificationException(
        'Số điện thoại phải có mã quốc gia, ví dụ +84987654321.',
      );
    }
    if (ownerId == null) {
      throw const AccountPhoneVerificationException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (verifiedPhone == normalized) return;
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          phone: normalized,
          currentPassword:
              currentPassword?.trim().isEmpty == true ? null : currentPassword,
        ),
      );
      if (_client.auth.currentUser?.id != ownerId ||
          response.user?.id != ownerId) {
        throw const AccountPhoneVerificationException(
          'Tài khoản đã thay đổi. Vui lòng thực hiện lại.',
        );
      }
    } on AccountPhoneVerificationException {
      rethrow;
    } on AuthException catch (error) {
      throw AccountPhoneVerificationException(_messageFor(error));
    } catch (_) {
      throw const AccountPhoneVerificationException(
        'Không thể gửi mã SMS lúc này. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<void> verifyCode({required String phone, required String code}) async {
    final normalized = normalizeAccountPhone(phone);
    final token = code.trim();
    final ownerId = _client.auth.currentUser?.id;
    if (normalized == null || !RegExp(r'^\d{6}$').hasMatch(token)) {
      throw const AccountPhoneVerificationException(
        'Mã xác nhận phải gồm đúng 6 số.',
      );
    }
    if (ownerId == null) {
      throw const AccountPhoneVerificationException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    try {
      final response = await _client.auth.verifyOTP(
        phone: normalized,
        token: token,
        type: OtpType.phoneChange,
      );
      final user = response.user;
      final responsePhone = user?.phone == null
          ? null
          : normalizeAccountPhone(
              '+${user!.phone!.replaceFirst(RegExp(r'^\+'), '')}',
            );
      if (_client.auth.currentUser?.id != ownerId ||
          user?.id != ownerId ||
          user?.phoneConfirmedAt == null ||
          responsePhone != normalized) {
        throw const AccountPhoneVerificationException(
          'Máy chủ chưa xác nhận số điện thoại này.',
        );
      }
      await _client.rpc('sync_my_verified_phone');
    } on AccountPhoneVerificationException {
      rethrow;
    } on AuthException catch (error) {
      throw AccountPhoneVerificationException(_messageFor(error));
    } catch (_) {
      throw const AccountPhoneVerificationException(
        'Mã xác nhận không đúng hoặc đã hết hạn.',
      );
    }
  }

  String _messageFor(AuthException error) {
    if (error.statusCode == '429' ||
        error.code == 'over_request_rate_limit' ||
        error.code == 'over_sms_send_rate_limit') {
      return 'Bạn thao tác quá nhanh. Vui lòng chờ rồi thử lại.';
    }
    if (error.code == 'otp_expired') {
      return 'Mã xác nhận không đúng hoặc đã hết hạn.';
    }
    return 'Không thể xác nhận số điện thoại lúc này. Vui lòng thử lại.';
  }
}

final accountPhoneVerificationGatewayProvider =
    Provider<AccountPhoneVerificationGateway>(
  (ref) => SupabaseAccountPhoneVerificationGateway(),
);
