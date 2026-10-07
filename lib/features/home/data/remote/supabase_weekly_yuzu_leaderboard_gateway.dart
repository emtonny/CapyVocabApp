import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/weekly_yuzu_leaderboard.dart';

abstract interface class WeeklyYuzuLeaderboardGateway {
  Future<WeeklyYuzuLeaderboard> fetchCurrent({required String ownerId});
}

final class SupabaseWeeklyYuzuLeaderboardGateway
    implements WeeklyYuzuLeaderboardGateway {
  SupabaseWeeklyYuzuLeaderboardGateway({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<WeeklyYuzuLeaderboard> fetchCurrent({required String ownerId}) async {
    final response = await _client.rpc('list_weekly_yuzu_leaderboard');
    return weeklyYuzuLeaderboardFromRpc(
      response,
      ownerId: ownerId,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

WeeklyYuzuLeaderboard weeklyYuzuLeaderboardFromRpc(
  Object? response, {
  required String ownerId,
  required DateTime updatedAt,
}) {
  if (response is! List || response.isEmpty) {
    throw const FormatException('Invalid weekly leaderboard RPC response');
  }
  final entries = <WeeklyYuzuLeaderboardEntry>[];
  DateTime? weekStart;
  for (final raw in response) {
    if (raw is! Map) {
      throw const FormatException('Invalid weekly leaderboard row');
    }
    final row = Map<String, Object?>.from(raw);
    final entry = WeeklyYuzuLeaderboardEntry.fromJson(row);
    final rowWeek = DateTime.tryParse('${row['week_start']}T00:00:00.000Z');
    if (entry == null || rowWeek == null) {
      throw const FormatException('Invalid weekly leaderboard row');
    }
    weekStart ??= rowWeek;
    if (weekStart != rowWeek) {
      throw const FormatException('Mixed leaderboard week boundaries');
    }
    entries.add(entry);
  }
  try {
    return WeeklyYuzuLeaderboard(
      ownerId: ownerId,
      weekStart: weekStart!,
      entries: entries,
      updatedAt: updatedAt,
    );
  } on ArgumentError catch (error) {
    throw FormatException('Invalid weekly leaderboard response: $error');
  }
}
