import 'dart:io';

import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/library_database_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _userId = '20000000-0000-0000-0000-000000000001';
const _otherUserId = '20000000-0000-0000-0000-000000000002';
const _mediaId = '20000000-0000-0000-0000-000000000003';
const _scanRunId = '20000000-0000-0000-0000-000000000004';
const _detectionId = '20000000-0000-0000-0000-000000000005';
const _eventId = '20000000-0000-0000-0000-000000000006';
const _sha256 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _timestamp = '2026-09-02T02:00:00.000Z';

void main() {
  late Directory tempDirectory;
  late String databasePath;
  LibraryDatabase? libraryDatabase;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('capy_library_m2a_');
    databasePath =
        '${tempDirectory.path}${Platform.pathSeparator}library_test.db';
  });

  tearDown(() async {
    await libraryDatabase?.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    await tempDirectory.delete(recursive: true);
  });

  test('creates the complete v3 schema with foreign keys enabled', () async {
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final database = await libraryDatabase!.open();

    final tables = await database.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
    ''');
    final tableNames = tables.map((row) => row['name'] as String).toSet();
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');

    expect(await database.getVersion(), LibraryDatabaseSchema.version);
    expect(tableNames, containsAll(LibraryDatabaseSchema.tableNames));
    expect(foreignKeys.single.values.single, 1);
  });

  test('upgrades v1 without changing legacy rows and queues every row',
      () async {
    final legacyDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
          CREATE TABLE scan_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_path TEXT NOT NULL,
            vocab_json TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now'))
          )
        '''),
      ),
    );
    await legacyDatabase.insert('scan_results', {
      'local_path': 'scan_images/one.jpg',
      'vocab_json': '{"words":[{"word":"cup"}]}',
      'created_at': '2026-08-01T00:00:00.000Z',
    });
    await legacyDatabase.insert('scan_results', {
      'local_path': 'scan_images/broken.jpg',
      'vocab_json': '{invalid-json',
      'created_at': '2026-08-02T00:00:00.000Z',
    });
    final before = await legacyDatabase.query('scan_results', orderBy: 'id');
    await legacyDatabase.close();

    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    var database = await libraryDatabase!.open();

    expect(await database.getVersion(), 3);
    expect(await database.query('scan_results', orderBy: 'id'), before);
    expect(
      await database.query(
        'legacy_scan_import_queue',
        columns: ['legacy_scan_result_id', 'migration_state'],
        orderBy: 'legacy_scan_result_id',
      ),
      [
        {'legacy_scan_result_id': 1, 'migration_state': 'pending'},
        {'legacy_scan_result_id': 2, 'migration_state': 'pending'},
      ],
    );

    await libraryDatabase!.close();
    database = await libraryDatabase!.open();
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM legacy_scan_import_queue',
        ),
      ),
      2,
      reason: 'onOpen must be idempotent',
    );
  });

  test('upgrades v2 by adding only the owner-scoped pull cursor table',
      () async {
    final v2 = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE local_accounts (
              user_id TEXT PRIMARY KEY,
              account_state TEXT NOT NULL,
              cloud_backup_enabled INTEGER NOT NULL,
              local_personalization_enabled INTEGER NOT NULL,
              federated_contribution_enabled INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE TABLE scan_results (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              local_path TEXT NOT NULL,
              vocab_json TEXT NOT NULL,
              created_at TEXT
            )
          ''');
          await database.execute('''
            CREATE TABLE legacy_scan_import_queue (
              legacy_scan_result_id INTEGER PRIMARY KEY,
              migration_state TEXT NOT NULL,
              queued_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await v2.close();

    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final upgraded = await libraryDatabase!.open();
    expect(await upgraded.getVersion(), 3);
    final tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(tables.map((row) => row['name']), contains('library_pull_cursors'));
  });

  test('enforces tenant, evidence, event and transaction invariants', () async {
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final database = await libraryDatabase!.open();
    await _insertAccount(database, _userId);
    await _insertAccount(database, _otherUserId);
    await _insertMedia(database, id: _mediaId, userId: _userId);

    await expectLater(
      database.insert('photo_notes', {
        'id': '20000000-0000-0000-0000-000000000099',
        'user_id': _otherUserId,
        'media_asset_id': _mediaId,
        'title': 'Cross-account note',
        'template_id': 'default-v1',
        'created_at': _timestamp,
        'updated_at': _timestamp,
        'sync_status': 'local_only',
      }),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      _insertScanRun(database, rawResponseJson: null, responseHash: null),
      throwsA(isA<DatabaseException>()),
    );
    await _insertScanRun(
      database,
      rawResponseJson: '{"words":[{"word":"cup"}]}',
      responseHash: _sha256,
    );
    await expectLater(
      database.update(
        'scan_runs',
        {'raw_response_json': '{"words":[]}'},
        where: 'id = ?',
        whereArgs: [_scanRunId],
      ),
      throwsA(isA<DatabaseException>()),
    );

    await _insertDetection(database);
    await _insertLearningEvent(database);
    await expectLater(
      database.update(
        'learning_events',
        {'is_correct': 0},
        where: 'id = ?',
        whereArgs: [_eventId],
      ),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      database.transaction((transaction) async {
        const rolledBackMediaId = '20000000-0000-0000-0000-000000000010';
        await _insertMedia(
          transaction,
          id: rolledBackMediaId,
          userId: _userId,
        );
        await transaction.insert('photo_notes', {
          'id': '20000000-0000-0000-0000-000000000011',
          'user_id': _userId,
          'media_asset_id': rolledBackMediaId,
          'title': 'Must roll back',
          'template_id': 'default-v1',
          'created_at': _timestamp,
          'updated_at': _timestamp,
          'sync_status': 'local_only',
        });
        await transaction.insert('sync_operations', {
          'operation_id': '20000000-0000-0000-0000-000000000012',
          'user_id': _userId,
          'entity_type': 'photo_note',
          'entity_id': '20000000-0000-0000-0000-000000000011',
          'operation_type': 'create',
          'payload_json': '{}',
          'dependency_ids_json': '[]',
          'state': 'invalid-state',
          'attempt_count': 0,
          'created_at': _timestamp,
          'updated_at': _timestamp,
        });
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM media_assets WHERE id = ?',
          ['20000000-0000-0000-0000-000000000010'],
        ),
      ),
      0,
    );
  });

  test('measures a 200-aggregate transaction on desktop SQLite', () async {
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final database = await libraryDatabase!.open();
    await _insertAccount(database, _userId);

    final stopwatch = Stopwatch()..start();
    await database.transaction((transaction) async {
      for (var index = 1; index <= 200; index++) {
        final suffix = index.toString().padLeft(12, '0');
        final mediaId = '30000000-0000-0000-0000-$suffix';
        final noteId = '40000000-0000-0000-0000-$suffix';
        final operationId = '50000000-0000-0000-0000-$suffix';
        await _insertMedia(
          transaction,
          id: mediaId,
          userId: _userId,
        );
        await transaction.insert('photo_notes', {
          'id': noteId,
          'user_id': _userId,
          'media_asset_id': mediaId,
          'title': 'Benchmark $index',
          'template_id': 'default-v1',
          'created_at': _timestamp,
          'updated_at': _timestamp,
          'sync_status': 'local_only',
        });
        await transaction.insert('sync_operations', {
          'operation_id': operationId,
          'user_id': _userId,
          'entity_type': 'photo_note',
          'entity_id': noteId,
          'operation_type': 'create',
          'payload_json': '{}',
          'dependency_ids_json': '[]',
          'state': 'pending',
          'attempt_count': 0,
          'created_at': _timestamp,
          'updated_at': _timestamp,
        });
      }
    });
    stopwatch.stop();

    final count = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM photo_notes'),
    );
    // ignore: avoid_print
    print('M2A_SQLITE_200_AGGREGATES_MS=${stopwatch.elapsedMilliseconds}');
    expect(count, 200);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('enforces consent, training provenance and active model rules',
      () async {
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final database = await libraryDatabase!.open();
    await _insertAccount(database, _userId);

    await expectLater(
      database.insert('consent_events', {
        'id': '60000000-0000-0000-0000-000000000001',
        'user_id': _userId,
        'consent_type': 'local_personalization',
        'old_value': 0,
        'new_value': 0,
        'policy_version': 'privacy-v1',
        'source_action': 'settings_toggle',
        'enforcement_state': 'applied',
        'occurred_at': _timestamp,
      }),
      throwsA(isA<DatabaseException>()),
    );
    await database.insert('consent_events', {
      'id': '60000000-0000-0000-0000-000000000002',
      'user_id': _userId,
      'consent_type': 'local_personalization',
      'old_value': 0,
      'new_value': 1,
      'policy_version': 'privacy-v1',
      'source_action': 'settings_toggle',
      'enforcement_state': 'pending',
      'occurred_at': _timestamp,
    });
    await database.update(
      'consent_events',
      {'enforcement_state': 'applied'},
      where: 'id = ?',
      whereArgs: ['60000000-0000-0000-0000-000000000002'],
    );
    await expectLater(
      database.update(
        'consent_events',
        {'new_value': 0},
        where: 'id = ?',
        whereArgs: ['60000000-0000-0000-0000-000000000002'],
      ),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      database.insert('training_examples', {
        'id': '60000000-0000-0000-0000-000000000003',
        'user_id': _userId,
        'task_type': 'vision_classification',
        'feature_schema_version': 'vision-features-v1',
        'label_schema_version': 'vocab-label-v1',
        'builder_version': 'builder-v1',
        'features_json': '{}',
        'target_json': '{}',
        'eligibility_status': 'eligible',
        'split': 'train',
        'split_seed_version': 'split-v1',
        'created_at': _timestamp,
      }),
      throwsA(isA<DatabaseException>()),
    );

    await _insertModelVersion(
      database,
      id: '60000000-0000-0000-0000-000000000004',
    );
    await expectLater(
      _insertModelVersion(
        database,
        id: '60000000-0000-0000-0000-000000000005',
      ),
      throwsA(isA<DatabaseException>()),
    );
  });
}

Future<void> _insertAccount(DatabaseExecutor database, String userId) {
  return database.insert('local_accounts', {
    'user_id': userId,
    'account_state': 'active',
    'cloud_backup_enabled': 0,
    'local_personalization_enabled': 0,
    'federated_contribution_enabled': 0,
    'created_at': _timestamp,
    'updated_at': _timestamp,
  });
}

Future<void> _insertMedia(
  DatabaseExecutor database, {
  required String id,
  required String userId,
}) {
  return database.insert('media_assets', {
    'id': id,
    'user_id': userId,
    'content_hash_sha256': _sha256,
    'display_relative_path': 'accounts/$userId/media/$id.jpg',
    'mime_type': 'image/jpeg',
    'width': 1080,
    'height': 1920,
    'orientation': 0,
    'byte_size_display': 1024,
    'preprocessing_version': 'vision-input-v1',
    'capture_source': 'camera',
    'created_at': _timestamp,
    'sync_status': 'local_only',
  });
}

Future<void> _insertScanRun(
  DatabaseExecutor database, {
  required String? rawResponseJson,
  required String? responseHash,
}) {
  return database.insert('scan_runs', {
    'id': _scanRunId,
    'user_id': _userId,
    'media_asset_id': _mediaId,
    'request_id': 'm2a-request',
    'provider': 'google_gemini',
    'model_name': 'gemini-flash',
    'prompt_version': 'prompt-v1',
    'response_schema_version': 'scan-response-v1',
    'preprocessing_version': 'vision-input-v1',
    'raw_response_json': rawResponseJson,
    'response_hash_sha256': responseHash,
    'status': 'succeeded',
    'started_at': _timestamp,
    'completed_at': _timestamp,
  });
}

Future<void> _insertDetection(DatabaseExecutor database) {
  return database.insert('vocab_detections', {
    'id': _detectionId,
    'scan_run_id': _scanRunId,
    'word_raw': 'Cup',
    'word_normalized': 'cup',
    'bbox_x': 0.1,
    'bbox_y': 0.1,
    'bbox_width': 0.2,
    'bbox_height': 0.2,
    'confidence': 0.9,
    'display_order': 0,
    'created_at': _timestamp,
  });
}

Future<void> _insertLearningEvent(DatabaseExecutor database) {
  return database.insert('learning_events', {
    'id': _eventId,
    'user_id': _userId,
    'detection_id': _detectionId,
    'session_id': '20000000-0000-0000-0000-000000000007',
    'event_type': 'answered',
    'is_correct': 1,
    'response_time_ms': 250,
    'hint_count': 0,
    'attempt_number': 1,
    'scheduler_version': 'srs-v1',
    'occurred_at': _timestamp,
    'recorded_at': _timestamp,
  });
}

Future<void> _insertModelVersion(
  DatabaseExecutor database, {
  required String id,
}) {
  return database.insert('model_versions', {
    'id': id,
    'user_id': _userId,
    'task_type': 'srs_recall',
    'base_model_version': 'srs-base-v1',
    'feature_schema_version': 'srs-features-v1',
    'label_schema_version': 'recall-label-v1',
    'activation_status': 'active',
    'baseline_metrics_json': '{}',
    'personalized_metrics_json': '{}',
    'created_at': _timestamp,
  });
}
