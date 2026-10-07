import 'package:capy_vocab/features/home/data/local/weekly_yuzu_leaderboard_cache.dart';
import 'package:capy_vocab/features/home/data/remote/supabase_weekly_yuzu_leaderboard_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('decodes the owner-scoped ranked RPC response', () {
    final result = weeklyYuzuLeaderboardFromRpc(
      [
        {
          'user_id': 'owner-a',
          'display_name': 'An',
          'avatar_url': null,
          'weekly_yuzu': 230,
          'rank_position': 1,
          'week_start': '2026-10-05',
        },
        {
          'user_id': 'friend-b',
          'display_name': 'Bình',
          'avatar_url': 'https://example.invalid/avatar.png',
          'weekly_yuzu': 100,
          'rank_position': 2,
          'week_start': '2026-10-05',
        },
      ],
      ownerId: 'owner-a',
      updatedAt: DateTime.utc(2026, 10, 6, 1),
    );

    expect(result.ownerId, 'owner-a');
    expect(result.weekStart, DateTime.utc(2026, 10, 5));
    expect(result.entries.map((entry) => entry.weeklyYuzu), [230, 100]);
    expect(result.isOffline, isFalse);
  });

  test('rejects a response that does not contain the signed-in owner', () {
    expect(
      () => weeklyYuzuLeaderboardFromRpc(
        [
          {
            'user_id': 'friend-b',
            'display_name': 'Bình',
            'avatar_url': null,
            'weekly_yuzu': 100,
            'rank_position': 1,
            'week_start': '2026-10-05',
          },
        ],
        ownerId: 'owner-a',
        updatedAt: DateTime.utc(2026, 10, 6, 1),
      ),
      throwsFormatException,
    );
  });

  test('cache is isolated by account and restores an offline snapshot',
      () async {
    final source = weeklyYuzuLeaderboardFromRpc(
      [
        {
          'user_id': 'owner-a',
          'display_name': 'An',
          'avatar_url': null,
          'weekly_yuzu': 230,
          'rank_position': 1,
          'week_start': '2026-10-05',
        },
      ],
      ownerId: 'owner-a',
      updatedAt: DateTime.utc(2026, 10, 6, 1),
    );
    final cache = SharedPreferencesWeeklyYuzuLeaderboardCache();
    await cache.write(source);

    final restored = await cache.read('owner-a');
    expect(restored?.entries.single.weeklyYuzu, 230);
    expect(restored?.isOffline, isTrue);
    expect(await cache.read('owner-b'), isNull);
  });
}
