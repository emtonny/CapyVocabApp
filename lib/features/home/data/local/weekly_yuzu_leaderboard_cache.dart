import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/weekly_yuzu_leaderboard.dart';

abstract interface class WeeklyYuzuLeaderboardCache {
  Future<WeeklyYuzuLeaderboard?> read(String ownerId);

  Future<void> write(WeeklyYuzuLeaderboard leaderboard);
}

final class SharedPreferencesWeeklyYuzuLeaderboardCache
    implements WeeklyYuzuLeaderboardCache {
  static const _keyPrefix = 'weekly_yuzu_leaderboard_v1_';

  @override
  Future<WeeklyYuzuLeaderboard?> read(String ownerId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_keyPrefix$ownerId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? WeeklyYuzuLeaderboard.fromJson(
              Map<String, Object?>.from(decoded),
              ownerId: ownerId,
            )
          : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(WeeklyYuzuLeaderboard leaderboard) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix${leaderboard.ownerId}',
      jsonEncode(leaderboard.toJson()),
    );
  }
}
