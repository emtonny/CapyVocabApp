import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/daily_mission.dart';

abstract interface class DailyMissionGateway {
  Future<DailyMission> ensureCurrent({String? detectedTimeZone});
}

final class SupabaseDailyMissionGateway implements DailyMissionGateway {
  SupabaseDailyMissionGateway({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<DailyMission> ensureCurrent({String? detectedTimeZone}) async {
    final response = await _client.rpc(
      'ensure_daily_mission',
      params: {'p_detected_time_zone': detectedTimeZone},
    );
    return dailyMissionFromRpcResponse(response);
  }
}

DailyMission dailyMissionFromRpcResponse(Object? response) {
  final Object? row = switch (response) {
    Map() => response,
    List(length: 1) => response.single,
    _ => null,
  };
  if (row is! Map) {
    throw const FormatException('Invalid daily mission RPC response');
  }
  return dailyMissionFromRemoteMap(Map<String, Object?>.from(row));
}

DailyMission dailyMissionFromRemoteMap(Map<String, Object?> row) {
  final target = row['target_words'];
  if (target is! num) {
    throw const FormatException('Daily mission target is missing');
  }
  return DailyMission(
    userId: row['user_id']! as String,
    day: DateTime.parse('${row['mission_date']}T00:00:00.000Z'),
    timeZone: row['time_zone']! as String,
    targetWords: target.toInt(),
    createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
    startsAt: DateTime.parse(row['starts_at']! as String).toUtc(),
    endsAt: DateTime.parse(row['ends_at']! as String).toUtc(),
    nextDayEndsAt: DateTime.parse(row['next_day_ends_at']! as String).toUtc(),
  );
}
