import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/remote/supabase_period_yuzu_leaderboard_gateway.dart';
import '../../domain/yuzu_leaderboard_period.dart';
import 'home_provider.dart';

final selectedLeaderboardPeriodProvider =
    StateProvider.autoDispose((ref) => YuzuLeaderboardPeriod.total);

final periodYuzuLeaderboardGatewayProvider =
    Provider((ref) => SupabasePeriodYuzuLeaderboardGateway());

final periodYuzuLeaderboardProvider = FutureProvider.autoDispose
    .family<PeriodYuzuLeaderboard, YuzuLeaderboardPeriod>((ref, period) async {
  final session = ref.watch(authProvider).asData?.value;
  if (session == null) throw StateError('Authentication required');
  ref.watch(homeProvider.select((state) => state.asData?.value.updatedAt));
  return ref.watch(periodYuzuLeaderboardGatewayProvider).fetchCurrent(
        ownerId: session.user.id,
        period: period,
      );
});
