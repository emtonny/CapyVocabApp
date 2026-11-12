import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/weekly_yuzu_leaderboard.dart';
import '../../domain/yuzu_leaderboard_period.dart';

class SupabasePeriodYuzuLeaderboardGateway {
  SupabasePeriodYuzuLeaderboardGateway({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<PeriodYuzuLeaderboard> fetchCurrent({
    required String ownerId,
    required YuzuLeaderboardPeriod period,
  }) async {
    final response = await _client
        .rpc('list_period_yuzu_leaderboard', params: {'p_period': period.name});
    return periodYuzuLeaderboardFromRpc(response,
        ownerId: ownerId, updatedAt: DateTime.now().toUtc());
  }
}

PeriodYuzuLeaderboard periodYuzuLeaderboardFromRpc(
  Object? response, {
  required String ownerId,
  required DateTime updatedAt,
}) {
  if (response is! List || response.isEmpty) {
    throw const FormatException('Invalid period leaderboard response');
  }
  final entries = <WeeklyYuzuLeaderboardEntry>[];
  final ids = <String>{};
  for (final raw in response) {
    if (raw is! Map) {
      throw const FormatException('Invalid period leaderboard row');
    }
    final row = Map<String, Object?>.from(raw);
    final entry = WeeklyYuzuLeaderboardEntry.fromJson({
      ...row,
      'weekly_yuzu': row['period_yuzu'],
    });
    if (entry == null || !ids.add(entry.userId)) {
      throw const FormatException('Invalid period leaderboard entry');
    }
    entries.add(entry);
  }
  if (!ids.contains(ownerId)) {
    throw const FormatException('Leaderboard owner is missing');
  }
  return PeriodYuzuLeaderboard(
    entries: List.unmodifiable(entries),
    updatedAt: updatedAt,
  );
}
