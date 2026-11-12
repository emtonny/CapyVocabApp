import 'dart:async';

import 'package:capy_vocab/features/home/data/remote/streak_flame_gateway.dart';
import 'package:capy_vocab/features/home/presentation/providers/home_provider.dart';
import 'package:capy_vocab/features/home/presentation/providers/streak_flame_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HomeState _home(String id) => HomeState(
    userId: id,
    displayName: id,
    yuzuBalance: 100,
    pendingYuzu: 0,
    streakDays: 7,
    updatedAt: DateTime.utc(2026, 10, 8, 7));

class _DeferredGateway implements StreakFlameGateway {
  final result = Completer<StreakFlameResult>();
  int calls = 0;
  @override
  Future<StreakFlameResult> light({required String ownerId}) {
    calls++;
    return result.future;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('blocks in-flight duplicates and persists the confirmed count',
      () async {
    final gateway = _DeferredGateway();
    final cache = SharedPreferencesHomeSummaryCache();
    final container = ProviderContainer(overrides: [
      homeProvider.overrideWith((ref) => Stream.value(_home('owner'))),
      streakFlameGatewayProvider.overrideWithValue(gateway),
      homeSummaryCacheProvider.overrideWithValue(cache),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(streakFlameProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(homeProvider.future);
    await container.read(streakFlameProvider.future);
    final controller = container.read(streakFlameProvider.notifier);
    final first = controller.light();
    expect(await controller.light(), isNull);
    expect(gateway.calls, 1);
    gateway.result.complete(StreakFlameResult(
        ownerId: 'owner',
        streakDays: 8,
        incremented: true,
        updatedAt: DateTime.utc(2026, 10, 8, 8)));
    expect((await first)?.streakDays, 8);
    expect((await cache.read('owner'))?.streakDays, 8);
    expect(await cache.read('other'), isNull);
  });

  test('discards a response after switching accounts', () async {
    final homes = StreamController<HomeState>.broadcast();
    final gateway = _DeferredGateway();
    final container = ProviderContainer(overrides: [
      homeProvider.overrideWith((ref) => homes.stream),
      streakFlameGatewayProvider.overrideWithValue(gateway),
    ]);
    addTearDown(() async {
      container.dispose();
      await homes.close();
    });
    final subscription = container.listen(streakFlameProvider, (_, __) {});
    addTearDown(subscription.close);
    final initialHome = container.read(homeProvider.future);
    homes.add(_home('owner'));
    await initialHome;
    await container.read(streakFlameProvider.future);
    final first = container.read(streakFlameProvider.notifier).light();
    final changed = Completer<void>();
    final homeSubscription = container.listen(homeProvider, (_, next) {
      if (next.asData?.value.userId == 'other' && !changed.isCompleted) {
        changed.complete();
      }
    });
    addTearDown(homeSubscription.close);
    homes.add(_home('other'));
    await changed.future;
    gateway.result.complete(StreakFlameResult(
        ownerId: 'owner',
        streakDays: 8,
        incremented: true,
        updatedAt: DateTime.utc(2026, 10, 8, 8)));
    expect(await first, isNull);
    expect(container.read(streakFlameProvider).valueOrNull, isNull);
  });
}
