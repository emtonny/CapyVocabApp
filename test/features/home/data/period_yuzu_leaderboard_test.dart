import 'package:capy_vocab/features/home/data/remote/supabase_period_yuzu_leaderboard_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final row = <String, Object?>{
    'user_id': 'owner',
    'display_name': 'Demo',
    'avatar_url': null,
    'period_yuzu': 123,
    'rank_position': 1,
  };
  test('decodes the period score instead of a weekly score', () {
    final result = periodYuzuLeaderboardFromRpc([
      {...row, 'weekly_yuzu': 999},
    ], ownerId: 'owner', updatedAt: DateTime.utc(2026, 10, 8));
    expect(result.entries.single.weeklyYuzu, 123);
  });
  test('rejects missing owner, duplicates and invalid scores', () {
    for (final response in [
      <Object?>[],
      [row, row],
      [
        {...row, 'period_yuzu': -1}
      ],
      [
        {...row, 'period_yuzu': 1.5}
      ],
      [
        {...row, 'user_id': 'other'}
      ],
    ]) {
      expect(
          () => periodYuzuLeaderboardFromRpc(response,
              ownerId: 'owner', updatedAt: DateTime.utc(2026, 10, 8)),
          throwsFormatException);
    }
  });
}
