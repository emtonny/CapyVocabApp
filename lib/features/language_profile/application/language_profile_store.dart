import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/language_profile.dart';

abstract class LanguageProfileStore extends ChangeNotifier {
  LanguageProfile? profileFor(String userId);

  Future<void> setProfile(LanguageProfile profile);

  Future<void> removeProfile(String userId);
}

class MemoryLanguageProfileStore extends LanguageProfileStore {
  final Map<String, LanguageProfile> _profiles = {};

  @override
  LanguageProfile? profileFor(String userId) => _profiles[userId];

  @override
  Future<void> setProfile(LanguageProfile profile) async {
    if (!profile.isValid) {
      throw ArgumentError.value(profile, 'profile', 'Invalid language profile');
    }
    _profiles[profile.userId] = profile;
    notifyListeners();
  }

  @override
  Future<void> removeProfile(String userId) async {
    if (_profiles.remove(userId) != null) notifyListeners();
  }
}

class SharedPreferencesLanguageProfileStore extends LanguageProfileStore {
  SharedPreferencesLanguageProfileStore._(this._preferences);

  static const _keyPrefix = 'language_profile_v1.';

  final SharedPreferences _preferences;
  final Map<String, LanguageProfile> _profiles = {};

  static Future<SharedPreferencesLanguageProfileStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesLanguageProfileStore._(preferences);
    store._hydrate();
    return store;
  }

  void _hydrate() {
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      try {
        final raw = _preferences.getString(key);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final profile = LanguageProfile.tryFromJson(
          decoded.cast<String, Object?>(),
        );
        if (profile == null || key != '$_keyPrefix${profile.userId}') continue;
        _profiles[profile.userId] = profile;
      } catch (_) {
        // Corrupt cache entries fail closed and are ignored.
      }
    }
  }

  @override
  LanguageProfile? profileFor(String userId) => _profiles[userId];

  @override
  Future<void> setProfile(LanguageProfile profile) async {
    if (!profile.isValid) {
      throw ArgumentError.value(profile, 'profile', 'Invalid language profile');
    }
    _profiles[profile.userId] = profile;
    notifyListeners();
    try {
      await _preferences.setString(
        '$_keyPrefix${profile.userId}',
        jsonEncode(profile.toJson()),
      );
    } catch (_) {
      debugPrint('Unable to persist language profile cache.');
    }
  }

  @override
  Future<void> removeProfile(String userId) async {
    final existed = _profiles.remove(userId) != null;
    if (existed) notifyListeners();
    try {
      await _preferences.remove('$_keyPrefix$userId');
    } catch (_) {
      debugPrint('Unable to remove language profile cache.');
    }
  }
}
