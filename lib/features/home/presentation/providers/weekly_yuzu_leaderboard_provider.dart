import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/local/weekly_yuzu_leaderboard_cache.dart';
import '../../data/remote/supabase_weekly_yuzu_leaderboard_gateway.dart';
import '../../domain/weekly_yuzu_leaderboard.dart';
import 'daily_mission_provider.dart';
import 'home_provider.dart';

final weeklyYuzuLeaderboardGatewayProvider =
    Provider<WeeklyYuzuLeaderboardGateway>(
  (_) => SupabaseWeeklyYuzuLeaderboardGateway(),
);

final weeklyYuzuLeaderboardCacheProvider = Provider<WeeklyYuzuLeaderboardCache>(
  (_) => SharedPreferencesWeeklyYuzuLeaderboardCache(),
);

final weeklyYuzuLeaderboardProvider =
    StreamProvider.autoDispose<WeeklyYuzuLeaderboard>((ref) async* {
  final session = ref.watch(authProvider).asData?.value;
  if (session == null) {
    throw StateError('Bạn cần đăng nhập để xem bảng xếp hạng.');
  }

  // A confirmed wallet update can contain a new H5 settlement; refresh H5C.
  ref.watch(homeProvider.select((state) => state.asData?.value.updatedAt));

  final ownerId = session.user.id;
  final cache = ref.watch(weeklyYuzuLeaderboardCacheProvider);
  final mission = ref.watch(currentDailyMissionProvider);
  WeeklyYuzuLeaderboard? cached;
  try {
    cached = await cache.read(ownerId);
    if (cached != null &&
        mission != null &&
        cached.weekStart != weekStartForDay(mission.day)) {
      cached = null;
    }
  } catch (_) {
    // Corrupt/unavailable local persistence must not block a fresh RPC.
  }
  if (cached != null) yield cached.copyWith(isOffline: true);

  try {
    final fresh = await ref
        .watch(weeklyYuzuLeaderboardGatewayProvider)
        .fetchCurrent(ownerId: ownerId);
    try {
      await cache.write(fresh);
    } catch (_) {
      // The verified server response is still safe to display.
    }
    yield fresh;
  } catch (error, stackTrace) {
    if (cached == null) Error.throwWithStackTrace(error, stackTrace);
  }
});
