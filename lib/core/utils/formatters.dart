// UC-FRND-01: định dạng tên hiển thị bạn mới (Capy Bạn Mới (4 số cuối SĐT))
class Formatters {
  Formatters._();

  static String friendDisplayName(String input) {
    if (input.trim().startsWith('@')) return input.trim();
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
    return 'Capy Bạn Mới ($last4)';
  }
}
