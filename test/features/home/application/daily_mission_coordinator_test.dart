import 'dart:async';

import 'package:capy_vocab/features/home/application/daily_mission_coordinator.dart';
import 'package:capy_vocab/features/home/data/remote/supabase_daily_mission_gateway.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '20000000-0000-0000-0000-000000000001';
const _otherUserId = '20000000-0000-0000-0000-000000000002';

void main() {
  test('stores the canonical remote mission as synced', () async {
    final cache = _MemoryCache();
    final remote = _mission();
    final coordinator = DailyMissionCoordinator(
      cache: cache,
      gateway: _Gateway.result(remote),
      loadDeviceTimeZone: () async => 'Asia/Bangkok',
      loadDailyTarget: (_) async => 20,
    );

    expect(await coordinator.ensureCurrent(_userId), same(remote));
    expect(cache.remoteWrites, 1);
    expect(cache.items.single.syncState, DailyMissionSyncState.synced);
  });

  test('does not downgrade an owner-integrity failure to offline mode',
      () async {
    final coordinator = DailyMissionCoordinator(
      cache: _MemoryCache(),
      gateway: _Gateway.result(_mission(userId: _otherUserId)),
      loadDeviceTimeZone: () async => 'Asia/Bangkok',
      loadDailyTarget: (_) async => 10,
    );

    await expectLater(
      coordinator.ensureCurrent(_userId),
      throwsA(isA<StateError>()),
    );
  });

  test('creates a local-only mission when the server is unavailable', () async {
    final now = DateTime.utc(2026, 9, 28, 8);
    final cache = _MemoryCache();
    final coordinator = DailyMissionCoordinator(
      cache: cache,
      gateway: _Gateway.error(StateError('offline')),
      loadDeviceTimeZone: () async => 'Etc/UTC',
      loadDailyTarget: (_) async => 15,
      clock: () => now,
    );

    final mission = await coordinator.ensureCurrent(_userId);

    expect(mission, isNotNull);
    expect(mission!.syncState, DailyMissionSyncState.localOnly);
    expect(mission.targetWords, 15);
    expect(mission.contains(now), isTrue);
    expect(cache.localWrites, 1);
  });

  test('uses cached exact next boundary and frozen target for one rollover',
      () async {
    final cache = _MemoryCache()
      ..items.add(
        _mission(
          day: DateTime.utc(2026, 11, 1),
          startsAt: DateTime.utc(2026, 11, 1, 4),
          endsAt: DateTime.utc(2026, 11, 2, 5),
          nextDayEndsAt: DateTime.utc(2026, 11, 3, 5),
          targetWords: 22,
        ),
      );
    final coordinator = DailyMissionCoordinator(
      cache: cache,
      gateway: _Gateway.error(StateError('offline')),
      loadDeviceTimeZone: () async => throw StateError('timezone unavailable'),
      loadDailyTarget: (_) async => throw StateError('offline'),
      clock: () => DateTime.utc(2026, 11, 2, 12),
    );

    final mission = await coordinator.ensureCurrent(_userId);

    expect(mission!.day, DateTime.utc(2026, 11, 2));
    expect(mission.startsAt, DateTime.utc(2026, 11, 2, 5));
    expect(mission.endsAt, DateTime.utc(2026, 11, 3, 5));
    expect(mission.targetWords, 22);
  });

  test('keeps the current frozen target after settings change offline',
      () async {
    final now = DateTime.utc(2026, 9, 28, 12);
    final current = _mission(targetWords: 10);
    final cache = _MemoryCache()..items.add(current);
    final coordinator = DailyMissionCoordinator(
      cache: cache,
      gateway: _Gateway.error(StateError('offline')),
      loadDeviceTimeZone: () async => 'Asia/Bangkok',
      loadDailyTarget: (_) async => 30,
      clock: () => now,
    );

    final mission = await coordinator.ensureCurrent(_userId);

    expect(mission, same(current));
    expect(mission?.targetWords, 10);
    expect(cache.localWrites, 0);
  });

  test('cached account timezone wins after device timezone changes offline',
      () async {
    final cache = _MemoryCache()
      ..items.add(
        _mission(
          day: DateTime.utc(2026, 11, 1),
          startsAt: DateTime.utc(2026, 11, 1, 4),
          endsAt: DateTime.utc(2026, 11, 2, 5),
          nextDayEndsAt: DateTime.utc(2026, 11, 3, 5),
          targetWords: 22,
        ),
      );
    final coordinator = DailyMissionCoordinator(
      cache: cache,
      gateway: _Gateway.error(StateError('offline')),
      loadDeviceTimeZone: () async => 'America/Los_Angeles',
      loadDailyTarget: (_) async => 30,
      clock: () => DateTime.utc(2026, 11, 2, 12),
    );

    final mission = await coordinator.ensureCurrent(_userId);

    expect(mission?.day, DateTime.utc(2026, 11, 2));
    expect(mission?.timeZone, 'America/New_York');
    expect(mission?.startsAt, DateTime.utc(2026, 11, 2, 5));
    expect(mission?.endsAt, DateTime.utc(2026, 11, 3, 5));
    expect(mission?.targetWords, 30);
  });

  test('coalesces concurrent ensure calls for the same account', () async {
    final completer = Completer<DailyMission>();
    final gateway = _Gateway.future(completer.future);
    final coordinator = DailyMissionCoordinator(
      cache: _MemoryCache(),
      gateway: gateway,
      loadDeviceTimeZone: () async => 'Asia/Bangkok',
      loadDailyTarget: (_) async => 10,
    );

    final first = coordinator.ensureCurrent(_userId);
    final second = coordinator.ensureCurrent(_userId);
    completer.complete(_mission());

    await Future.wait([first, second]);
    expect(gateway.calls, 1);
  });
}

DailyMission _mission({
  String userId = _userId,
  DateTime? day,
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? nextDayEndsAt,
  int targetWords = 10,
}) {
  final start = startsAt ?? DateTime.utc(2026, 9, 27, 17);
  return DailyMission(
    userId: userId,
    day: day ?? DateTime.utc(2026, 9, 28),
    timeZone: day?.month == 11 ? 'America/New_York' : 'Asia/Bangkok',
    targetWords: targetWords,
    createdAt: start,
    startsAt: start,
    endsAt: endsAt ?? start.add(const Duration(days: 1)),
    nextDayEndsAt: nextDayEndsAt ?? start.add(const Duration(days: 2)),
  );
}

final class _Gateway implements DailyMissionGateway {
  _Gateway.future(Future<DailyMission> result) : _load = (() => result);

  factory _Gateway.result(DailyMission mission) =>
      _Gateway.future(Future.value(mission));

  _Gateway.error(Object error) : _load = (() => Future.error(error));

  final Future<DailyMission> Function() _load;
  int calls = 0;

  @override
  Future<DailyMission> ensureCurrent({String? detectedTimeZone}) {
    calls++;
    return _load();
  }
}

final class _MemoryCache implements DailyMissionCache {
  final List<DailyMission> items = [];
  int localWrites = 0;
  int remoteWrites = 0;

  @override
  Future<DailyMission?> findAt({
    required String userId,
    required DateTime instant,
  }) async {
    for (final mission in items.reversed) {
      if (mission.userId == userId && mission.contains(instant)) return mission;
    }
    return null;
  }

  @override
  Future<DailyMission?> get({
    required String userId,
    required DateTime day,
  }) async {
    for (final mission in items) {
      if (mission.userId == userId && mission.day == day) return mission;
    }
    return null;
  }

  @override
  Future<DailyMission?> latest(String userId) async {
    final owned = items.where((item) => item.userId == userId).toList()
      ..sort((left, right) => left.day.compareTo(right.day));
    return owned.isEmpty ? null : owned.last;
  }

  @override
  Future<List<DailyMission>> list({
    required String userId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async =>
      items
          .where(
            (item) =>
                item.userId == userId &&
                !item.day.isBefore(fromInclusive) &&
                item.day.isBefore(toExclusive),
          )
          .toList();

  @override
  Future<void> put(DailyMission mission) async {
    localWrites++;
    items.add(mission);
  }

  @override
  Future<void> putRemote(DailyMission mission) async {
    remoteWrites++;
    items.add(mission.asSynced());
  }
}
