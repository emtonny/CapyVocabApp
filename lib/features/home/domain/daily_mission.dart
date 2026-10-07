final RegExp _ianaRegionPattern = RegExp(
  r'^[A-Za-z][A-Za-z0-9._+-]*/[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)*$',
);

enum DailyMissionSyncState { localOnly, synced }

final class DailyMissionKey {
  DailyMissionKey({required String userId, required DateTime day})
      : userId = _requireUuid(userId),
        day = _requireDay(day);

  final String userId;
  final DateTime day;
}

final class DailyMission {
  DailyMission({
    required String userId,
    required DateTime day,
    required String timeZone,
    required int targetWords,
    required DateTime createdAt,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime nextDayEndsAt,
    this.syncState = DailyMissionSyncState.synced,
  })  : userId = _requireUuid(userId),
        day = _requireDay(day),
        timeZone = _requireIanaRegion(timeZone),
        targetWords = _requirePositive(targetWords),
        createdAt = _requireUtc(createdAt),
        startsAt = _requireUtc(startsAt),
        endsAt = _requireUtc(endsAt),
        nextDayEndsAt = _requireUtc(nextDayEndsAt) {
    if (!this.startsAt.isBefore(this.endsAt) ||
        !this.endsAt.isBefore(this.nextDayEndsAt)) {
      throw ArgumentError('Daily mission boundaries must be strictly ordered');
    }
  }

  final String userId;
  final DateTime day;
  final String timeZone;
  final int targetWords;
  final DateTime createdAt;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime nextDayEndsAt;
  final DailyMissionSyncState syncState;

  bool contains(DateTime instant) {
    final utc = _requireUtc(instant);
    return !utc.isBefore(startsAt) && utc.isBefore(endsAt);
  }

  DailyMission asSynced() => DailyMission(
        userId: userId,
        day: day,
        timeZone: timeZone,
        targetWords: targetWords,
        createdAt: createdAt,
        startsAt: startsAt,
        endsAt: endsAt,
        nextDayEndsAt: nextDayEndsAt,
      );
}

abstract interface class DailyMissionCache {
  Future<void> put(DailyMission mission);

  Future<void> putRemote(DailyMission mission);

  Future<DailyMission?> get({
    required String userId,
    required DateTime day,
  });

  Future<List<DailyMission>> list({
    required String userId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  });

  Future<DailyMission?> findAt({
    required String userId,
    required DateTime instant,
  });

  Future<DailyMission?> latest(String userId);
}

String _requireUuid(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw ArgumentError.value(value, 'userId', 'must be a UUID');
  }
  return normalized;
}

DateTime _requireDay(DateTime value) {
  if (!value.isUtc ||
      value != DateTime.utc(value.year, value.month, value.day)) {
    throw ArgumentError.value(value, 'day', 'must be a UTC calendar date');
  }
  return value;
}

String _requireIanaRegion(String value) {
  final normalized = value.trim();
  if (!_ianaRegionPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'timeZone',
      'must be an IANA region identifier',
    );
  }
  return normalized;
}

int _requirePositive(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'targetWords', 'must be positive');
  }
  return value;
}

DateTime _requireUtc(DateTime value) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, 'createdAt', 'must be UTC');
  }
  return value;
}
