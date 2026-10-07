import 'dart:async';

import 'package:capy_vocab/features/home/application/daily_mission_coordinator.dart';
import 'package:capy_vocab/features/home/data/remote/supabase_daily_mission_gateway.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:capy_vocab/features/home/presentation/providers/daily_mission_provider.dart';
import 'package:capy_vocab/features/home/presentation/widgets/daily_mission_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '20000000-0000-0000-0000-000000000001';

void main() {
  testWidgets('publishes the mission on app open and clears it on sign-out',
      (tester) async {
    final authUserIds = StreamController<String?>();
    addTearDown(authUserIds.close);
    final now = DateTime.now().toUtc();
    final mission = DailyMission(
      userId: _userId,
      day: DateTime.utc(now.year, now.month, now.day),
      timeZone: 'Etc/UTC',
      targetWords: 12,
      createdAt: now,
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 1)),
      nextDayEndsAt: now.add(const Duration(hours: 25)),
    );
    final gateway = _Gateway(mission);
    final coordinator = DailyMissionCoordinator(
      cache: _Cache(),
      gateway: gateway,
      loadDeviceTimeZone: () async => 'Etc/UTC',
      loadDailyTarget: (_) async => 10,
    );
    final container = ProviderContainer(
      overrides: [
        dailyMissionCoordinatorProvider.overrideWith(
          (ref) async => coordinator,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: DailyMissionRuntime(
          currentUserId: () => _userId,
          authUserIds: authUserIds.stream,
          child: const MaterialApp(home: Text('home')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(container.read(currentDailyMissionProvider), same(mission));
    expect(gateway.calls, 1);

    authUserIds.add(null);
    await tester.pump();
    expect(container.read(currentDailyMissionProvider), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refreshes the mission when the app resumes', (tester) async {
    final authUserIds = StreamController<String?>();
    addTearDown(authUserIds.close);
    final now = DateTime.now().toUtc();
    final first = _mission(
      day: DateTime.utc(now.year, now.month, now.day),
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 1)),
    );
    final refreshed = _mission(
      day: first.day,
      startsAt: first.startsAt,
      endsAt: first.endsAt,
      targetWords: 20,
    );
    final gateway = _SequenceGateway([first, refreshed]);
    final container = ProviderContainer(
      overrides: [
        dailyMissionCoordinatorProvider.overrideWith(
          (ref) async => DailyMissionCoordinator(
            cache: _Cache(),
            gateway: gateway,
            loadDeviceTimeZone: () async => 'Etc/UTC',
            loadDailyTarget: (_) async => 10,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: DailyMissionRuntime(
          currentUserId: () => _userId,
          authUserIds: authUserIds.stream,
          child: const MaterialApp(home: Text('home')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(container.read(currentDailyMissionProvider), same(first));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(gateway.calls, 2);
    expect(container.read(currentDailyMissionProvider), same(refreshed));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refreshes automatically at the cached account-day boundary',
      (tester) async {
    final authUserIds = StreamController<String?>();
    addTearDown(authUserIds.close);
    final now = DateTime.now().toUtc();
    final boundary = now.add(const Duration(seconds: 1));
    final first = _mission(
      day: DateTime.utc(now.year, now.month, now.day),
      startsAt: now.subtract(const Duration(hours: 1)),
      endsAt: boundary,
    );
    final next = _mission(
      day: first.day.add(const Duration(days: 1)),
      startsAt: boundary,
      endsAt: boundary.add(const Duration(days: 1)),
      targetWords: 20,
    );
    final gateway = _SequenceGateway([first, next]);
    final container = ProviderContainer(
      overrides: [
        dailyMissionCoordinatorProvider.overrideWith(
          (ref) async => DailyMissionCoordinator(
            cache: _Cache(),
            gateway: gateway,
            loadDeviceTimeZone: () async => 'Etc/UTC',
            loadDailyTarget: (_) async => 10,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: DailyMissionRuntime(
          currentUserId: () => _userId,
          authUserIds: authUserIds.stream,
          child: const MaterialApp(home: Text('home')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(container.read(currentDailyMissionProvider), same(first));

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(gateway.calls, 2);
    expect(container.read(currentDailyMissionProvider), same(next));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

DailyMission _mission({
  required DateTime day,
  required DateTime startsAt,
  required DateTime endsAt,
  int targetWords = 12,
}) =>
    DailyMission(
      userId: _userId,
      day: day,
      timeZone: 'Etc/UTC',
      targetWords: targetWords,
      createdAt: startsAt,
      startsAt: startsAt,
      endsAt: endsAt,
      nextDayEndsAt: endsAt.add(const Duration(days: 1)),
    );

final class _Gateway implements DailyMissionGateway {
  _Gateway(this.mission);

  final DailyMission mission;
  int calls = 0;

  @override
  Future<DailyMission> ensureCurrent({String? detectedTimeZone}) async {
    calls++;
    return mission;
  }
}

final class _SequenceGateway implements DailyMissionGateway {
  _SequenceGateway(this.missions);

  final List<DailyMission> missions;
  int calls = 0;

  @override
  Future<DailyMission> ensureCurrent({String? detectedTimeZone}) async {
    final index = calls.clamp(0, missions.length - 1);
    calls++;
    return missions[index];
  }
}

final class _Cache implements DailyMissionCache {
  DailyMission? value;

  @override
  Future<DailyMission?> findAt({
    required String userId,
    required DateTime instant,
  }) async =>
      value?.contains(instant) == true ? value : null;

  @override
  Future<DailyMission?> get({
    required String userId,
    required DateTime day,
  }) async =>
      value?.day == day ? value : null;

  @override
  Future<DailyMission?> latest(String userId) async => value;

  @override
  Future<List<DailyMission>> list({
    required String userId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async =>
      value == null ? const [] : [value!];

  @override
  Future<void> put(DailyMission mission) async => value = mission;

  @override
  Future<void> putRemote(DailyMission mission) async {
    value = mission.asSynced();
  }
}
