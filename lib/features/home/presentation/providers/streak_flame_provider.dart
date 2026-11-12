import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/streak_flame_gateway.dart';
import 'home_provider.dart';

final streakFlameGatewayProvider = Provider<StreakFlameGateway>(
  (_) => SupabaseStreakFlameGateway(),
);

final streakFlameProvider = AsyncNotifierProvider.autoDispose<
    StreakFlameController, StreakFlameResult?>(StreakFlameController.new);

class StreakFlameController
    extends AutoDisposeAsyncNotifier<StreakFlameResult?> {
  @override
  StreakFlameResult? build() => null;

  Future<StreakFlameResult?> light() async {
    if (state.isLoading) return null;
    final home = ref.read(homeProvider).asData?.value;
    if (home == null) throw StateError('Home profile is unavailable');
    final lease = ref.keepAlive();
    final previous = state;
    state = const AsyncLoading<StreakFlameResult?>().copyWithPrevious(previous);
    try {
      final result = await ref
          .read(streakFlameGatewayProvider)
          .light(ownerId: home.userId);
      final latest = ref.read(homeProvider).asData?.value;
      if (latest?.userId != home.userId) {
        state = const AsyncData(null);
        return null;
      }
      state = AsyncData(result);
      try {
        if (!result.updatedAt.isBefore(latest!.updatedAt)) {
          await ref.read(homeSummaryCacheProvider).write(latest.copyWith(
                streakDays: result.streakDays,
                updatedAt: result.updatedAt,
              ));
        }
      } catch (_) {
        // The confirmed server count remains valid if caching is unavailable.
      }
      return result;
    } catch (error, stackTrace) {
      if (ref.read(homeProvider).asData?.value.userId != home.userId) {
        state = const AsyncData(null);
        return null;
      }
      state = AsyncError<StreakFlameResult?>(error, stackTrace)
          .copyWithPrevious(previous);
      rethrow;
    } finally {
      lease.close();
    }
  }
}
