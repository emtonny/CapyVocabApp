// FR-FRND-02, UC-AUTH-01: validate input rỗng, định dạng email/SĐT/username
class Validators {
  Validators._();

  static const minimumPasswordLength = 6;

  static bool isNotEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool isEmail(String value) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(value);
  }

  static bool isValidPassword(String? value) =>
      value != null && value.length >= minimumPasswordLength;
}
