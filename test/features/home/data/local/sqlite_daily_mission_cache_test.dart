import 'dart:io';

import 'package:capy_vocab/features/home/data/local/sqlite_daily_mission_cache.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '20000000-0000-0000-0000-000000000001';
const _otherUserId = '20000000-0000-0000-0000-000000000002';
final _day = DateTime.utc(2026, 9, 28);
final _createdAt = DateTime.utc(2026, 9, 27, 17);

void main() {
  late Directory tempDirectory;
  late LibraryDatabase libraryDatabase;
  late Database database;
  late SqliteDailyMissionCache cache;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('capy_h2a_');
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: '${tempDirectory.path}${Platform.pathSeparator}library.db',
    );
    database = await libraryDatabase.open();
    await _insertAccount(database, _userId);
    await _insertAccount(database, _otherUserId);
    cache = SqliteDailyMissionCache(database);
  });

  tearDown(() async {
    await libraryDatabase.close();
    await tempDirectory.delete(recursive: true);
  });

  test('stores one immutable mission per owner day idempotently', () async {
    final mission = _mission();

    await cache.put(mission);
    await cache.put(mission);

    final cached = await cache.get(userId: _userId, day: _day);
    expect(cached, isNotNull);
    expect(cached!.timeZone, 'Asia/Bangkok');
    expect(cached.targetWords, 10);
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM daily_missions'),
      ),
      1,
    );
  });

  test('isolates reads by owner and rejects a conflicting snapshot', () async {
    await cache.put(
      _mission(),
    );

    expect(await cache.get(userId: _otherUserId, day: _day), isNull);
    await expectLater(
      cache.put(
        _mission(targetWords: 20),
      ),
      throwsStateError,
    );
  });

  test('database rejects direct mutation and invalid timezone shapes',
      () async {
    await cache.put(
      _mission(),
    );

    await expectLater(
      database.update(
        'daily_missions',
        {'target_words': 20},
        where: 'user_id = ? AND mission_date = ?',
        whereArgs: [_userId, '2026-09-28'],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => DailyMission(
        userId: _userId,
        day: _day,
        timeZone: 'UTC+7',
        targetWords: 10,
        createdAt: _createdAt,
        startsAt: _createdAt,
        endsAt: _createdAt.add(const Duration(days: 1)),
        nextDayEndsAt: _createdAt.add(const Duration(days: 2)),
      ),
      throwsArgumentError,
    );
  });

  test('lists only the requested owner and half-open date range', () async {
    for (final day in [27, 28, 29]) {
      await cache.put(
        _mission(day: DateTime.utc(2026, 9, day), targetWords: day),
      );
    }
    await cache.put(
      _mission(
        userId: _otherUserId,
        timeZone: 'America/New_York',
        targetWords: 99,
      ),
    );

    final missions = await cache.list(
      userId: _userId,
      fromInclusive: DateTime.utc(2026, 9, 28),
      toExclusive: DateTime.utc(2026, 9, 30),
    );

    expect(missions.map((mission) => mission.day.day), [28, 29]);
    expect(missions.map((mission) => mission.targetWords), [28, 29]);
  });

  test('remote snapshot reconciles a conflicting local-only mission', () async {
    await cache.put(_mission(targetWords: 10));
    await cache.putRemote(
      _mission(
        targetWords: 20,
        syncState: DailyMissionSyncState.synced,
      ),
    );

    final cached = await cache.findAt(
      userId: _userId,
      instant: DateTime.utc(2026, 9, 28, 8),
    );
    expect(cached?.targetWords, 20);
    expect(cached?.syncState, DailyMissionSyncState.synced);
  });

  test('bootstraps a fail-closed local account before the first mission',
      () async {
    await database.delete(
      'local_accounts',
      where: 'user_id = ?',
      whereArgs: [_userId],
    );

    await cache.put(_mission());

    final accounts = await database.query(
      'local_accounts',
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    expect(accounts, hasLength(1));
    expect(accounts.single['cloud_backup_enabled'], 0);
    expect(accounts.single['local_personalization_enabled'], 0);
    expect(accounts.single['federated_contribution_enabled'], 0);
  });
}

DailyMission _mission({
  String userId = _userId,
  DateTime? day,
  String timeZone = 'Asia/Bangkok',
  int targetWords = 10,
  DailyMissionSyncState syncState = DailyMissionSyncState.localOnly,
}) {
  final missionDay = day ?? _day;
  final startsAt = DateTime.utc(
    missionDay.year,
    missionDay.month,
    missionDay.day - 1,
    17,
  );
  return DailyMission(
    userId: userId,
    day: missionDay,
    timeZone: timeZone,
    targetWords: targetWords,
    createdAt: _createdAt,
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(days: 1)),
    nextDayEndsAt: startsAt.add(const Duration(days: 2)),
    syncState: syncState,
  );
}

Future<void> _insertAccount(Database database, String userId) {
  return database.insert('local_accounts', {
    'user_id': userId,
    'account_state': 'active',
    'cloud_backup_enabled': 0,
    'local_personalization_enabled': 0,
    'federated_contribution_enabled': 0,
    'created_at': _createdAt.toIso8601String(),
    'updated_at': _createdAt.toIso8601String(),
  });
}
