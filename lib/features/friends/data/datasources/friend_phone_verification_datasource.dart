import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/friend_entity.dart';
import '../../domain/friend_phone_verification.dart';

class FriendPhoneVerificationDataSource
    implements FriendPhoneVerificationGateway {
  FriendPhoneVerificationDataSource({
    required SupabaseClient client,
    required this.owner,
    required bool Function() isCurrentSession,
  })  : _client = client,
        _isCurrentSession = isCurrentSession;

  final SupabaseClient _client;
  final FriendOwner owner;
  final bool Function() _isCurrentSession;

  @override
  Future<FriendPhoneChallenge?> requestVerification() async {
    _assertCurrentSession();
    try {
      final response = await _client
          .from('users')
          .select('phone')
          .eq('id', owner.userId)
          .single();
      _assertCurrentSession();

      final localPhone = normalizeVietnameseFriendPhone(response['phone']);
      if (localPhone == null) {
        throw const FriendException(
          FriendFailureKind.invalidPhone,
          'The owner profile phone is missing or invalid.',
        );
      }
      final phoneE164 = vietnameseFriendPhoneToE164(localPhone);
      final authUser = _client.auth.currentUser;
      if (authUser == null || authUser.id != owner.userId) {
        throw const FriendRefreshSuperseded();
      }
      final authPhone = normalizeVietnameseFriendPhone(authUser.phone);
      if (authPhone == localPhone && authUser.phoneConfirmedAt != null) {
        return null;
      }
      if (authPhone != null && authPhone != localPhone) {
        throw const FriendException(
          FriendFailureKind.phoneConflict,
          'The Auth phone differs from the owner profile phone.',
        );
      }

      final update = await _client.auth.updateUser(
        UserAttributes(phone: phoneE164),
      );
      _assertCurrentSession();
      if (update.user?.id != owner.userId) {
        throw const FriendRefreshSuperseded();
      }
      return FriendPhoneChallenge(
        phoneE164: phoneE164,
        maskedPhone: maskVietnameseFriendPhone(localPhone),
      );
    } on FriendException {
      rethrow;
    } catch (_) {
      _assertCurrentSession();
      throw const FriendException(
        FriendFailureKind.unavailable,
        'Phone verification could not be started.',
      );
    }
  }

  @override
  Future<void> verify({
    required FriendPhoneChallenge challenge,
    required String token,
  }) async {
    _assertCurrentSession();
    final normalizedToken = token.trim();
    if (normalizeVietnameseFriendPhone(challenge.phoneE164) == null) {
      throw const FriendException(
        FriendFailureKind.invalidPhone,
        'The phone challenge is invalid.',
      );
    }
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedToken)) {
      throw const FriendException(
        FriendFailureKind.invalidInput,
        'The phone OTP must contain six digits.',
      );
    }
    try {
      final response = await _client.auth.verifyOTP(
        phone: challenge.phoneE164,
        token: normalizedToken,
        type: OtpType.phoneChange,
      );
      if (!_isCurrentSession() ||
          _client.auth.currentUser?.id != owner.userId ||
          response.user?.id != owner.userId) {
        throw const FriendRefreshSuperseded();
      }
      final verifiedUser = response.user!;
      final verifiedPhone = normalizeVietnameseFriendPhone(verifiedUser.phone);
      final expectedPhone = normalizeVietnameseFriendPhone(
        challenge.phoneE164,
      );
      if (verifiedPhone != expectedPhone ||
          verifiedUser.phoneConfirmedAt == null) {
        throw const FriendException(
          FriendFailureKind.contactNotVerified,
          'Supabase Auth did not confirm the requested phone.',
        );
      }
    } on FriendException {
      rethrow;
    } catch (_) {
      _assertCurrentSession();
      throw const FriendException(
        FriendFailureKind.contactNotVerified,
        'The phone OTP was rejected or expired.',
      );
    }
  }

  void _assertCurrentSession() {
    if (!_isCurrentSession() || _client.auth.currentUser?.id != owner.userId) {
      throw const FriendRefreshSuperseded();
    }
  }
}

String? normalizeVietnameseFriendPhone(Object? value) {
  if (value is! String) return null;
  var phone = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (phone.startsWith('+84')) {
    phone = '0${phone.substring(3)}';
  } else if (phone.startsWith('84') && phone.length == 11) {
    phone = '0${phone.substring(2)}';
  }
  return RegExp(r'^0\d{9}$').hasMatch(phone) ? phone : null;
}

String vietnameseFriendPhoneToE164(String localPhone) {
  final normalized = normalizeVietnameseFriendPhone(localPhone);
  if (normalized == null) {
    throw const FriendException(
      FriendFailureKind.invalidPhone,
      'The owner profile phone is invalid.',
    );
  }
  return '+84${normalized.substring(1)}';
}

String maskVietnameseFriendPhone(String localPhone) {
  final normalized = normalizeVietnameseFriendPhone(localPhone);
  if (normalized == null) return '••••••••••';
  return '${normalized.substring(0, 3)} ••• •• ${normalized.substring(8)}';
}
