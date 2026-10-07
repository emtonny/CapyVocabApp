import '../data/remote/supabase_daily_mission_gateway.dart';
import '../domain/daily_mission.dart';

typedef DailyMissionClock = DateTime Function();
typedef DeviceTimeZoneLoader = Future<String?> Function();
typedef DailyTargetLoader = Future<int> Function(String userId);

final class DailyMissionCoordinator {
  DailyMissionCoordinator({
    required DailyMissionCache cache,
    required DailyMissionGateway gateway,
    required DeviceTimeZoneLoader loadDeviceTimeZone,
    required DailyTargetLoader loadDailyTarget,
    DailyMissionClock? clock,
  })  : _cache = cache,
        _gateway = gateway,
        _loadDeviceTimeZone = loadDeviceTimeZone,
        _loadDailyTarget = loadDailyTarget,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final DailyMissionCache _cache;
  final DailyMissionGateway _gateway;
  final DeviceTimeZoneLoader _loadDeviceTimeZone;
  final DailyTargetLoader _loadDailyTarget;
  final DailyMissionClock _clock;
  final Map<String, Future<DailyMission?>> _inFlight = {};

  Future<DailyMission?> ensureCurrent(String userId) {
    return _inFlight.putIfAbsent(userId, () async {
      try {
        return await _ensureCurrent(userId);
      } finally {
        _inFlight.remove(userId);
      }
    });
  }

  Future<DailyMission?> _ensureCurrent(String userId) async {
    String? detectedTimeZone;
    try {
      detectedTimeZone = await _loadDeviceTimeZone();
    } catch (_) {
      // Existing account timezone is sufficient for the server call.
    }

    late final DailyMission remote;
    try {
      remote = await _gateway.ensureCurrent(
        detectedTimeZone: detectedTimeZone,
      );
    } catch (_) {
      return _ensureOffline(userId, detectedTimeZone);
    }
    if (remote.userId != userId) {
      throw StateError('Daily mission RPC returned another owner');
    }
    await _cache.putRemote(remote);
    return remote;
  }

  Future<DailyMission?> _ensureOffline(
    String userId,
    String? detectedTimeZone,
  ) async {
    final now = _clock();
    if (!now.isUtc) throw StateError('Daily mission clock must return UTC');
    final current = await _cache.findAt(userId: userId, instant: now);
    if (current != null) return current;

    final latest = await _cache.latest(userId);
    final target = await _offlineTarget(userId, latest);
    late final DateTime day;
    late final String timeZone;
    late final DateTime startsAt;
    late final DateTime endsAt;
    late final DateTime nextDayEndsAt;

    if (latest != null &&
        !now.isBefore(latest.endsAt) &&
        now.isBefore(latest.nextDayEndsAt)) {
      day = latest.day.add(const Duration(days: 1));
      timeZone = latest.timeZone;
      startsAt = latest.endsAt;
      endsAt = latest.nextDayEndsAt;
      // ponytail: exact one-day offline rollover is cached by the server;
      // refresh online before a second DST-sensitive account-day boundary.
      nextDayEndsAt = endsAt.add(const Duration(days: 1));
    } else {
      if (detectedTimeZone == null) return null;
      final localNow = now.toLocal();
      day = DateTime.utc(localNow.year, localNow.month, localNow.day);
      timeZone = detectedTimeZone;
      startsAt = DateTime(localNow.year, localNow.month, localNow.day).toUtc();
      endsAt =
          DateTime(localNow.year, localNow.month, localNow.day + 1).toUtc();
      nextDayEndsAt =
          DateTime(localNow.year, localNow.month, localNow.day + 2).toUtc();
    }

    final mission = DailyMission(
      userId: userId,
      day: day,
      timeZone: timeZone,
      targetWords: target,
      createdAt: now,
      startsAt: startsAt,
      endsAt: endsAt,
      nextDayEndsAt: nextDayEndsAt,
      syncState: DailyMissionSyncState.localOnly,
    );
    await _cache.put(mission);
    return mission;
  }

  Future<int> _offlineTarget(String userId, DailyMission? latest) async {
    try {
      final target = await _loadDailyTarget(userId);
      if (target > 0) return target;
    } catch (_) {
      // Use the latest frozen target or the onboarding default below.
    }
    return latest?.targetWords ?? 10;
  }
}
