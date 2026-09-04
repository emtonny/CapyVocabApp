import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const rememberedEmailKey = 'remembered_auth_email';

  static Future<String?> getRememberedEmail() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(rememberedEmailKey);
  }

  static Future<void> setRememberedEmail(String? email) async {
    final preferences = await SharedPreferences.getInstance();
    final normalizedEmail = email?.trim();

    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      await preferences.remove(rememberedEmailKey);
      return;
    }

    await preferences.setString(rememberedEmailKey, normalizedEmail);
  }
}
