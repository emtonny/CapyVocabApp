import 'package:capy_vocab/features/home/data/remote/supabase_daily_mission_gateway.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final response = {
    'user_id': '20000000-0000-0000-0000-000000000001',
    'mission_date': '2026-11-01',
    'time_zone': 'America/New_York',
    'target_words': 20,
    'created_at': '2026-11-01T04:00:00Z',
    'starts_at': '2026-11-01T04:00:00Z',
    'ends_at': '2026-11-02T05:00:00Z',
    'next_day_ends_at': '2026-11-03T05:00:00Z',
  };

  test('decodes the canonical RPC snapshot and server boundaries', () {
    final mission = dailyMissionFromRpcResponse(response);

    expect(mission.day, DateTime.utc(2026, 11, 1));
    expect(mission.targetWords, 20);
    expect(
      mission.endsAt.difference(mission.startsAt),
      const Duration(hours: 25),
    );
    expect(mission.syncState, DailyMissionSyncState.synced);
  });

  test('accepts the one-row list shape returned by table-valued RPCs', () {
    expect(dailyMissionFromRpcResponse([response]).targetWords, 20);
    expect(() => dailyMissionFromRpcResponse([]), throwsFormatException);
  });

  test('rejects a response without a numeric target', () {
    expect(
      () => dailyMissionFromRemoteMap({
        'user_id': '20000000-0000-0000-0000-000000000001',
        'mission_date': '2026-09-28',
        'time_zone': 'Asia/Bangkok',
        'target_words': '10',
        'created_at': '2026-09-27T17:00:00Z',
        'starts_at': '2026-09-27T17:00:00Z',
        'ends_at': '2026-09-28T17:00:00Z',
        'next_day_ends_at': '2026-09-29T17:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
