import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';

class StreakFlameResult {
  const StreakFlameResult({
    required this.ownerId,
    required this.streakDays,
    required this.incremented,
    required this.updatedAt,
  });

  final String ownerId;
  final int streakDays;
  final bool incremented;
  final DateTime updatedAt;
}

abstract interface class StreakFlameGateway {
  Future<StreakFlameResult> light({required String ownerId});
}

class SupabaseStreakFlameGateway implements StreakFlameGateway {
  SupabaseStreakFlameGateway({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<StreakFlameResult> light({required String ownerId}) async {
    return streakFlameFromRpc(await _client.rpc('light_streak_flame'), ownerId);
  }
}

StreakFlameResult streakFlameFromRpc(Object? response, String ownerId) {
  if (response is! List || response.length != 1 || response.single is! Map) {
    throw const FormatException('Invalid flame response');
  }
  final row = Map<String, Object?>.from(response.single as Map);
  final count = row['streak_days'];
  final incremented = row['incremented'];
  final updatedAt = DateTime.tryParse('${row['updated_at']}');
  if (row['user_id'] != ownerId ||
      count is! num ||
      !count.isFinite ||
      count < 0 ||
      count != count.toInt() ||
      incremented is! bool ||
      updatedAt == null) {
    throw const FormatException('Invalid flame result');
  }
  return StreakFlameResult(
      ownerId: ownerId,
      streakDays: count.toInt(),
      incremented: incremented,
      updatedAt: updatedAt.toUtc());
}
