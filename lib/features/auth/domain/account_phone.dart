final RegExp _e164Pattern = RegExp(r'^\+[1-9][0-9]{6,14}$');

/// SMS verification is implemented but intentionally dormant while the
/// email-only rollout is active. Keep this in one place so re-enabling it does
/// not require rediscovering scattered UI branches.
const accountSmsVerificationEnabled = false;

/// Normalizes a user-entered international phone number to E.164.
///
/// Formatting characters are ignored, but a leading `+` and 7-15 digits are
/// required so the app never guesses a country code.
String? normalizeAccountPhone(String? input) {
  if (input == null) return null;
  final normalized = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  return _e164Pattern.hasMatch(normalized) ? normalized : null;
}

String maskAccountPhone(String phone) {
  final normalized = normalizeAccountPhone(phone);
  if (normalized == null) return '••••••••';
  final visibleDigits = normalized.length <= 6 ? 2 : 4;
  return '${normalized.substring(0, 3)} ••• ${normalized.substring(normalized.length - visibleDigits)}';
}
