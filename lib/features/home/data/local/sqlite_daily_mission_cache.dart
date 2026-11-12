import 'package:sqflite/sqflite.dart';

import '../../domain/daily_mission.dart';

final class SqliteDailyMissionCache implements DailyMissionCache {
  const SqliteDailyMissionCache(this._database);

  final Database _database;

  @override
  Future<void> put(DailyMission mission) async {
    await _put(mission, remote: false);
  }

  @override
  Future<void> putRemote(DailyMission mission) async {
    await _put(mission.asSynced(), remote: true);
  }

  Future<void> _put(DailyMission mission, {required bool remote}) async {
    await _database.transaction((transaction) async {
      await transaction.insert(
        'local_accounts',
        {
          'user_id': mission.userId,
          'account_state': 'active',
          'last_authenticated_at': mission.createdAt.toIso8601String(),
          'cloud_backup_enabled': 0,
          'local_personalization_enabled': 0,
          'federated_contribution_enabled': 0,
          'created_at': mission.createdAt.toIso8601String(),
          'updated_at': mission.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final existing = await transaction.query(
        'daily_missions',
        where: 'user_id = ? AND mission_date = ?',
        whereArgs: [mission.userId, _encodeDay(mission.day)],
        limit: 1,
      );
      if (existing.isEmpty) {
        await transaction.insert('daily_missions', _toMap(mission));
        return;
      }
      final cached = _fromMap(existing.single);
      if (!_sameSnapshot(cached, mission)) {
        if (remote && cached.syncState == DailyMissionSyncState.localOnly) {
          await transaction.delete(
            'daily_missions',
            where: 'user_id = ? AND mission_date = ?',
            whereArgs: [mission.userId, _encodeDay(mission.day)],
          );
          await transaction.insert('daily_missions', _toMap(mission));
          return;
        }
        throw StateError(
          'Daily mission snapshot conflicts with the cached account day.',
        );
      }
      if (remote && cached.syncState != DailyMissionSyncState.synced) {
        await transaction.update(
          'daily_missions',
          {'sync_status': 'synced'},
          where: 'user_id = ? AND mission_date = ?',
          whereArgs: [mission.userId, _encodeDay(mission.day)],
        );
      }
    });
  }

  @override
  Future<DailyMission?> get({
    required String userId,
    required DateTime day,
  }) async {
    final key = DailyMissionKey(userId: userId, day: day);
    final rows = await _database.query(
      'daily_missions',
      where: 'user_id = ? AND mission_date = ?',
      whereArgs: [key.userId, _encodeDay(key.day)],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromMap(rows.single);
  }

  @override
  Future<List<DailyMission>> list({
    required String userId,
    required DateTime fromInclusive,
    required DateTime toExclusive,
  }) async {
    final from = DailyMissionKey(userId: userId, day: fromInclusive);
    final to = DailyMissionKey(userId: userId, day: toExclusive);
    if (!from.day.isBefore(to.day)) {
      throw ArgumentError('fromInclusive must be before toExclusive');
    }
    final rows = await _database.query(
      'daily_missions',
      where: 'user_id = ? AND mission_date >= ? AND mission_date < ?',
      whereArgs: [
        from.userId,
        _encodeDay(from.day),
        _encodeDay(to.day),
      ],
      orderBy: 'mission_date ASC',
    );
    return rows.map(_fromMap).toList(growable: false);
  }

  @override
  Future<DailyMission?> findAt({
    required String userId,
    required DateTime instant,
  }) async {
    final owner = DailyMissionKey(userId: userId, day: DateTime.utc(1970));
    if (!instant.isUtc) {
      throw ArgumentError.value(instant, 'instant', 'must be UTC');
    }
    final rows = await _database.query(
      'daily_missions',
      where: 'user_id = ? AND starts_at <= ? AND ends_at > ?',
      whereArgs: [
        owner.userId,
        instant.toIso8601String(),
        instant.toIso8601String(),
      ],
      orderBy: 'mission_date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _fromMap(rows.single);
  }

  @override
  Future<DailyMission?> latest(String userId) async {
    final owner = DailyMissionKey(userId: userId, day: DateTime.utc(1970));
    final rows = await _database.query(
      'daily_missions',
      where: 'user_id = ?',
      whereArgs: [owner.userId],
      orderBy: 'mission_date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _fromMap(rows.single);
  }

  static Map<String, Object?> _toMap(DailyMission mission) => {
        'user_id': mission.userId,
        'mission_date': _encodeDay(mission.day),
        'time_zone': mission.timeZone,
        'target_words': mission.targetWords,
        'created_at': mission.createdAt.toIso8601String(),
        'starts_at': mission.startsAt.toIso8601String(),
        'ends_at': mission.endsAt.toIso8601String(),
        'next_day_ends_at': mission.nextDayEndsAt.toIso8601String(),
        'sync_status': switch (mission.syncState) {
          DailyMissionSyncState.localOnly => 'local_only',
          DailyMissionSyncState.synced => 'synced',
        },
      };

  static DailyMission _fromMap(Map<String, Object?> row) => DailyMission(
        userId: row['user_id']! as String,
        day: DateTime.parse('${row['mission_date']}T00:00:00.000Z'),
        timeZone: row['time_zone']! as String,
        targetWords: row['target_words']! as int,
        createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
        startsAt: DateTime.parse(row['starts_at']! as String).toUtc(),
        endsAt: DateTime.parse(row['ends_at']! as String).toUtc(),
        nextDayEndsAt:
            DateTime.parse(row['next_day_ends_at']! as String).toUtc(),
        syncState: switch (row['sync_status']) {
          'local_only' => DailyMissionSyncState.localOnly,
          'synced' => DailyMissionSyncState.synced,
          final value => throw FormatException(
              'Unsupported daily mission sync status: $value',
            ),
        },
      );

  static bool _sameSnapshot(DailyMission left, DailyMission right) =>
      left.userId == right.userId &&
      left.day == right.day &&
      left.timeZone == right.timeZone &&
      left.targetWords == right.targetWords &&
      left.createdAt == right.createdAt &&
      left.startsAt == right.startsAt &&
      left.endsAt == right.endsAt &&
      left.nextDayEndsAt == right.nextDayEndsAt;

  static String _encodeDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
