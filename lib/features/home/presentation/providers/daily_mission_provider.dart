import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../application/daily_mission_coordinator.dart';
import '../../data/local/daily_mission_cache_factory.dart';
import '../../data/remote/supabase_daily_mission_gateway.dart';
import '../../domain/daily_mission.dart';

final dailyMissionCacheProvider = FutureProvider<DailyMissionCache>((ref) {
  return createDefaultDailyMissionCache();
});

final dailyMissionGatewayProvider = Provider<DailyMissionGateway>((ref) {
  return SupabaseDailyMissionGateway();
});

final dailyMissionDeviceTimeZoneLoaderProvider =
    Provider<DeviceTimeZoneLoader>((ref) {
  return FlutterTimezone.getLocalTimezone;
});

final dailyMissionCoordinatorProvider =
    FutureProvider<DailyMissionCoordinator>((ref) async {
  final cache = await ref.watch(dailyMissionCacheProvider.future);
  final onboarding = ref.watch(onboardingRepositoryProvider);
  return DailyMissionCoordinator(
    cache: cache,
    gateway: ref.watch(dailyMissionGatewayProvider),
    loadDeviceTimeZone: ref.watch(dailyMissionDeviceTimeZoneLoaderProvider),
    loadDailyTarget: (userId) async {
      final target = (await onboarding.loadDraft()).dailyTargetWords ?? 10;
      return target > 0 ? target : 10;
    },
  );
});

/// The runtime is the only writer; Home consumes this without starting I/O.
final currentDailyMissionProvider = StateProvider<DailyMission?>((ref) => null);
