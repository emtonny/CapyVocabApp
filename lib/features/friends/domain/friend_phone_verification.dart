/// In-memory proof that an OTP was requested for the owner's profile phone.
///
/// The full phone is never persisted or rendered. [maskedPhone] is safe for UI.
class FriendPhoneChallenge {
  const FriendPhoneChallenge({
    required this.phoneE164,
    required this.maskedPhone,
  });

  final String phoneE164;
  final String maskedPhone;
}

abstract interface class FriendPhoneVerificationGateway {
  /// Sends an OTP for the phone already stored in the owner's private profile.
  /// Returns `null` when Supabase Auth has already verified the same phone.
  Future<FriendPhoneChallenge?> requestVerification();

  /// Verifies the OTP for a challenge created by [requestVerification].
  Future<void> verify({
    required FriendPhoneChallenge challenge,
    required String token,
  });
}
