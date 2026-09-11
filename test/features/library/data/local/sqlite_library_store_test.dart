import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart' as gemini;
import 'package:capy_vocab/features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_picker.dart';
import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/legacy_scan_import_queue.dart';
import 'package:capy_vocab/features/library/data/local/sqlite_library_store.dart';
import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:capy_vocab/features/settings/presentation/providers/cloud_backup_consent_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _sha = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
final _time = DateTime.utc(2026, 9, 2, 8);

void main() {
  late Directory temporaryDirectory;
  late LibraryDatabase libraryDatabase;
  late Database database;
  late SqliteLibraryStore store;
  late _Ids ids;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('library_m2b_');
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: '${temporaryDirectory.path}${Platform.pathSeparator}store.db',
    );
    database = await libraryDatabase.open();
    ids = _Ids();
    store = SqliteLibraryStore(
      database: database,
      idGenerator: ids.next,
      clock: () => _time,
    );
  });

  tearDown(() async {
    await store.dispose();
    await libraryDatabase.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('round-trips an owner-scoped offline snapshot without cloud outbox',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);

    await store.saveCapturedPhotoNote(snapshot);

    final restored = await store.getPhotoNoteSnapshot(
      userId: userId,
      photoNoteId: snapshot.photoNote.id,
    );
    final notes =
        await store.watchPhotoNotes(PhotoNoteQuery(userId: userId)).first;
    final operationCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM sync_operations'),
    );

    expect(restored, isNotNull);
    expect(restored!.photoNote.title, 'Kitchen');
    expect(restored.mediaAsset.displayRelativePath,
        'accounts/$userId/media/display.jpg');
    expect(restored.primaryScanRun!.rawResponseJson, {
      'words': [
        {'word': 'Cup'}
      ]
    });
    expect(restored.detections.single.wordNormalized, 'cup');
    expect(
        restored.annotations.single.detectionId, restored.detections.single.id);
    expect(notes.map((note) => note.id), [snapshot.photoNote.id]);
    expect(operationCount, 0,
        reason: 'cloud backup is explicit consent and defaults to off');
  });

  test('cloud delta commits metadata and owner cursor without media or outbox',
      () async {
    final userId = ids.next();
    final otherUserId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveLocalAccount(_account(otherUserId, cloudBackup: true));
    final cloud = _asCloudSnapshot(_snapshot(ids, userId));

    await store.applyLibraryCloudDelta(LibraryCloudDelta(
      userId: userId,
      previousCursor: 0,
      nextCursor: 7,
      hasMore: false,
      snapshots: [cloud],
      deletions: const [],
    ));

    final restored = await store.getPhotoNoteSnapshot(
      userId: userId,
      photoNoteId: cloud.photoNote.id,
    );
    expect(restored, isNotNull);
    expect(restored!.primaryScanRun!.rawResponseJson,
        cloud.primaryScanRun!.rawResponseJson);
    expect(restored.detections.single.wordNormalized, 'cup');
    expect(restored.mediaAsset.remoteDisplayPath,
        '$userId/${cloud.mediaAsset.id}/display.jpg');
    expect(restored.mediaAsset.displayRelativePath, startsWith('capy_scans/'));
    expect(await store.getLibraryPullCursor(userId: userId), 7);
    expect(await store.getLibraryPullCursor(userId: otherUserId), 0);
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM sync_operations'),
      ),
      0,
      reason: 'a pull must never echo cloud metadata into the upload outbox',
    );
  });

  test(
      'cloud pull advances its cursor without overwriting a pending local note',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    final local = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(local);
    final cloudBase = _asCloudSnapshot(local);
    final cloud = PhotoNoteSnapshot(
      mediaAsset: cloudBase.mediaAsset,
      primaryScanRun: cloudBase.primaryScanRun,
      photoNote: PhotoNote(
        id: cloudBase.photoNote.id,
        userId: userId,
        mediaAssetId: cloudBase.photoNote.mediaAssetId,
        primaryScanRunId: cloudBase.photoNote.primaryScanRunId,
        title: 'Remote title must not win',
        emoji: cloudBase.photoNote.emoji,
        templateId: cloudBase.photoNote.templateId,
        createdAt: cloudBase.photoNote.createdAt,
        updatedAt: cloudBase.photoNote.updatedAt.add(const Duration(hours: 1)),
        syncStatus: SyncStatus.synced,
      ),
      detections: cloudBase.detections,
      annotations: cloudBase.annotations,
    );

    await store.applyLibraryCloudDelta(LibraryCloudDelta(
      userId: userId,
      previousCursor: 0,
      nextCursor: 5,
      hasMore: false,
      snapshots: [cloud],
      deletions: const [],
    ));

    final preserved = await store.getPhotoNoteSnapshot(
      userId: userId,
      photoNoteId: local.photoNote.id,
    );
    expect(preserved!.photoNote.title, 'Kitchen');
    expect(preserved.photoNote.syncStatus, SyncStatus.localOnly);
    expect(await store.getLibraryPullCursor(userId: userId), 5);
  });

  test('cloud tombstone wins and cursor rollback is atomic', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    final cloud = _asCloudSnapshot(_snapshot(ids, userId));
    await store.applyLibraryCloudDelta(LibraryCloudDelta(
      userId: userId,
      previousCursor: 0,
      nextCursor: 3,
      hasMore: false,
      snapshots: [cloud],
      deletions: const [],
    ));
    await _seedActiveTrainingLineage(
      store: store,
      ids: ids,
      userId: userId,
      snapshot: cloud,
    );
    final deletedAt = _time.add(const Duration(days: 1));
    await store.applyLibraryCloudDelta(LibraryCloudDelta(
      userId: userId,
      previousCursor: 3,
      nextCursor: 9,
      hasMore: false,
      snapshots: [cloud],
      deletions: [
        LibraryCloudDeletion(
          userId: userId,
          photoNoteId: cloud.photoNote.id,
          sequence: 9,
          deletedAt: deletedAt,
        ),
      ],
    ));

    expect(await store.watchPhotoNotes(PhotoNoteQuery(userId: userId)).first,
        isEmpty);
    final target =
        (await store.getPhotoNotePurgeTargets(userId: userId)).single;
    expect(target.remotePurgeCompleted, isTrue);
    expect(
      await store.getEligibleExamples(
        userId: userId,
        taskType: TrainingTaskType.visionClassification,
      ),
      isEmpty,
    );
    expect(
      await store.getActiveModel(
        userId: userId,
        taskType: TrainingTaskType.visionClassification,
      ),
      isNull,
    );
    expect(await store.getLibraryPullCursor(userId: userId), 9);

    await expectLater(
      store.applyLibraryCloudDelta(LibraryCloudDelta(
        userId: userId,
        previousCursor: 3,
        nextCursor: 10,
        hasMore: false,
        snapshots: const [],
        deletions: const [],
      )),
      throwsStateError,
    );
    expect(await store.getLibraryPullCursor(userId: userId), 9);
  });

  test('lists deduplicated media references across every local owner',
      () async {
    final firstUserId = ids.next();
    final secondUserId = ids.next();
    await store.saveLocalAccount(_account(firstUserId));
    await store.saveLocalAccount(_account(secondUserId));
    await store.saveCapturedPhotoNote(_snapshot(ids, firstUserId));
    await store.saveCapturedPhotoNote(_snapshot(ids, secondUserId));

    final paths = await store.listReferencedMediaPaths();

    expect(paths, {
      'accounts/$firstUserId/media/display.jpg',
      'accounts/$firstUserId/media/model.jpg',
      'accounts/$secondUserId/media/display.jpg',
      'accounts/$secondUserId/media/model.jpg',
    });
  });

  test('Trash is owner-scoped and hides notes after permanent delete request',
      () async {
    final userId = ids.next();
    final otherUserId = ids.next();
    await store.saveLocalAccount(_account(userId));
    await store.saveLocalAccount(_account(otherUserId));
    final snapshot = _snapshot(ids, userId);
    final otherSnapshot = _snapshot(ids, otherUserId);
    await store.saveCapturedPhotoNote(snapshot);
    await store.saveCapturedPhotoNote(otherSnapshot);

    final initialSummary =
        await store.watchStorageSummary(userId: userId).first;
    expect(initialSummary.activeCount, 1);
    expect(initialSummary.trashCount, 0);
    expect(initialSummary.localMediaBytes, 1024);
    expect(
      (await store.getStorageMediaAssets(userId: userId)).single.id,
      snapshot.mediaAsset.id,
    );

    final deletedAt = _time.add(const Duration(days: 1));
    await store.movePhotoNotesToTrash(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      deletedAt: deletedAt,
    );

    expect(
      await store.watchPhotoNotes(PhotoNoteQuery(userId: userId)).first,
      isEmpty,
    );
    expect(
      await store
          .watchPhotoNotes(PhotoNoteQuery(
            userId: userId,
            visibility: PhotoNoteVisibility.trash,
          ))
          .first,
      hasLength(1),
    );
    expect(
      await store
          .watchPhotoNotes(PhotoNoteQuery(
            userId: otherUserId,
            visibility: PhotoNoteVisibility.trash,
          ))
          .first,
      isEmpty,
    );

    await store.restorePhotoNotes(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      restoredAt: deletedAt.add(const Duration(hours: 1)),
    );
    expect(
      await store.watchPhotoNotes(PhotoNoteQuery(userId: userId)).first,
      hasLength(1),
    );

    await store.movePhotoNotesToTrash(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      deletedAt: deletedAt.add(const Duration(hours: 2)),
    );
    await store.requestPermanentDeletion(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      requestedAt: deletedAt.add(const Duration(hours: 3)),
    );

    expect(
      await store
          .watchPhotoNotes(PhotoNoteQuery(
            userId: userId,
            visibility: PhotoNoteVisibility.trash,
          ))
          .first,
      isEmpty,
    );
    await expectLater(
      store.restorePhotoNotes(
        userId: userId,
        photoNoteIds: [snapshot.photoNote.id],
        restoredAt: deletedAt.add(const Duration(hours: 4)),
      ),
      throwsStateError,
    );
    expect(
      await store.getPhotoNoteSnapshot(
        userId: userId,
        photoNoteId: snapshot.photoNote.id,
      ),
      isNotNull,
      reason: 'content stays hidden while tombstone/cloud purge is pending',
    );
    final pendingPurgeSummary =
        await store.watchStorageSummary(userId: userId).first;
    expect(pendingPurgeSummary.activeCount, 0);
    expect(pendingPurgeSummary.trashCount, 0);
    expect(pendingPurgeSummary.localMediaBytes, 0);
    expect(await store.getStorageMediaAssets(userId: userId), isEmpty);
  });

  test('rolls back the complete aggregate when a generated outbox row fails',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    final snapshot = _snapshot(ids, userId);
    const collidingId = 'f0000000-0000-0000-0000-000000000001';
    await store.enqueue(SyncOperation(
      operationId: collidingId,
      userId: userId,
      entityType: SyncEntityType.photoNote,
      entityId: snapshot.photoNote.id,
      operationType: SyncOperationType.update,
      payloadJson: const {},
      dependencyIds: const [],
      state: SyncOperationState.done,
      attemptCount: 0,
      createdAt: _time,
      updatedAt: _time,
    ));
    await store.dispose();
    store = SqliteLibraryStore(
      database: database,
      idGenerator: () => collidingId,
      clock: () => _time,
    );

    await expectLater(
      store.saveCapturedPhotoNote(snapshot),
      throwsA(isA<DatabaseException>()),
    );

    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM media_assets'),
      ),
      0,
    );
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM photo_notes'),
      ),
      0,
    );
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM sync_operations'),
      ),
      1,
      reason: 'the pre-existing collision row remains, but no new row commits',
    );
  });

  test('M2C rolls back account, legacy row and aggregate together', () async {
    final userId = ids.next();
    final snapshot = _snapshot(ids, userId);
    await store.dispose();
    const collidingId = 'f1000000-0000-0000-0000-000000000001';
    store = SqliteLibraryStore(
      database: database,
      idGenerator: () => collidingId,
      clock: () => _time,
    );

    await expectLater(
      store.saveCapturedPhotoNoteWithLegacy(
        accountIfMissing: _account(userId, cloudBackup: true),
        snapshot: snapshot,
        legacyLocalPath: r'C:\app\Documents\capy_scans\scan.jpg',
        legacyVocabJson: '{"schema_version":2,"words":[]}',
      ),
      throwsArgumentError,
    );

    for (final table in [
      'local_accounts',
      'scan_results',
      'legacy_scan_import_queue',
      'media_assets',
      'scan_runs',
      'photo_notes',
      'sync_operations',
    ]) {
      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM $table'),
        ),
        0,
        reason: '$table must participate in the same transaction',
      );
    }
  });

  test('creates dependency-ordered outbox rows only after consent', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    final snapshot = _snapshot(ids, userId);

    await store.saveCapturedPhotoNote(snapshot);

    final operations = await database.query(
      'sync_operations',
      orderBy: 'created_at, rowid',
    );
    expect(operations, hasLength(5));
    expect(operations.map((row) => row['entity_type']), [
      'media_asset',
      'scan_run',
      'vocab_detection',
      'vocab_annotation',
      'photo_note',
    ]);
    expect(operations[0]['dependency_ids_json'], '[]');
    expect(operations[1]['dependency_ids_json'],
        '["${operations[0]['operation_id']}"]');
    expect(operations[2]['dependency_ids_json'],
        '["${operations[1]['operation_id']}"]');
    expect(operations[3]['dependency_ids_json'],
        '["${operations[2]['operation_id']}"]');
    expect(operations[4]['dependency_ids_json'],
        '["${operations[0]['operation_id']}","${operations[1]['operation_id']}","${operations[2]['operation_id']}","${operations[3]['operation_id']}"]');

    final ready = await store.getReadyOperations(userId: userId, now: _time);
    expect(ready.map((operation) => operation.entityType),
        [SyncEntityType.mediaAsset]);
  });

  test('explicit backfill queues a pre-consent aggregate once and by owner',
      () async {
    final userId = ids.next();
    final otherUserId = ids.next();
    await store.saveLocalAccount(_account(userId));
    await store.saveLocalAccount(_account(otherUserId));
    final snapshot = _snapshot(ids, userId);
    final otherSnapshot = _snapshot(ids, otherUserId);
    await store.saveCapturedPhotoNote(snapshot);
    await store.saveCapturedPhotoNote(otherSnapshot);
    await store.saveLocalAccount(_account(userId, cloudBackup: true));

    final controller = CloudBackupConsentController(
      userId: userId,
      store: store,
      mediaLoader: const _AvailableMediaLoader(),
      idGenerator: ids.next,
      clock: () => _time,
    );
    final first = await controller.backfillExistingPhotoNotes();
    final second = await controller.backfillExistingPhotoNotes();

    expect(first, (queuedCount: 1, missingMediaCount: 0));
    expect(second, (queuedCount: 0, missingMediaCount: 0));
    final operations = await database.query(
      'sync_operations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at, rowid',
    );
    expect(operations.map((row) => row['entity_type']), [
      'media_asset',
      'scan_run',
      'vocab_detection',
      'vocab_annotation',
      'photo_note',
    ]);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        'SELECT COUNT(*) FROM sync_operations WHERE user_id = ?',
        [otherUserId],
      )),
      0,
    );
    expect(
      (await database.query(
        'photo_notes',
        columns: ['sync_status'],
        where: 'id = ?',
        whereArgs: [snapshot.photoNote.id],
      ))
          .single['sync_status'],
      'pending',
    );
  });

  test('explicit backfill skips a note whose local image is missing', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    await store.saveCapturedPhotoNote(_snapshot(ids, userId));
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    final controller = CloudBackupConsentController(
      userId: userId,
      store: store,
      mediaLoader: const _MissingMediaLoader(),
      idGenerator: ids.next,
      clock: () => _time,
    );

    final result = await controller.backfillExistingPhotoNotes();

    expect(result, (queuedCount: 0, missingMediaCount: 1));
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM sync_operations'),
      ),
      0,
    );
  });

  test('explicit backfill refuses consent off and excludes Trash', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(snapshot);
    final controller = CloudBackupConsentController(
      userId: userId,
      store: store,
      mediaLoader: const _AvailableMediaLoader(),
      idGenerator: ids.next,
      clock: () => _time,
    );

    await expectLater(
      controller.backfillExistingPhotoNotes(),
      throwsStateError,
    );
    await store.movePhotoNotesToTrash(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      deletedAt: _time.add(const Duration(minutes: 1)),
    );
    await store.saveLocalAccount(_account(userId, cloudBackup: true));

    expect(
      await controller.backfillExistingPhotoNotes(),
      (queuedCount: 0, missingMediaCount: 0),
    );
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM sync_operations'),
      ),
      0,
    );
  });

  test('explicit backfill does not upload media already present on cloud',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final local = _snapshot(ids, userId);
    final cloud = _asCloudSnapshot(local);
    await store.saveCapturedPhotoNote(PhotoNoteSnapshot(
      mediaAsset: cloud.mediaAsset,
      primaryScanRun: local.primaryScanRun,
      photoNote: local.photoNote,
      detections: local.detections,
      annotations: local.annotations,
    ));
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    final controller = CloudBackupConsentController(
      userId: userId,
      store: store,
      mediaLoader: const _MissingMediaLoader(),
      idGenerator: ids.next,
      clock: () => _time,
    );

    expect(
      await controller.backfillExistingPhotoNotes(),
      (queuedCount: 1, missingMediaCount: 0),
    );
    final operations = await database.query(
      'sync_operations',
      columns: ['entity_type'],
      orderBy: 'created_at, rowid',
    );
    expect(operations.map((row) => row['entity_type']), [
      'scan_run',
      'vocab_detection',
      'vocab_annotation',
      'photo_note',
    ]);
  });

  test('keeps album membership and deletion owner-scoped', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(snapshot);
    final album = Album(
      id: ids.next(),
      userId: userId,
      name: 'Kitchen words',
      icon: '🍵',
      isFavorite: false,
      createdAt: _time,
      updatedAt: _time,
      syncStatus: SyncStatus.localOnly,
    );
    await store.saveAlbum(album);
    await store.addPhotoNotes(
      userId: userId,
      albumId: album.id,
      photoNoteIds: [snapshot.photoNote.id],
      addedAt: _time,
      operationId: ids.next(),
    );

    expect(
      await store.watchMemberships(userId: userId, albumId: album.id).first,
      hasLength(1),
    );
    await store.deleteAlbums(
      userId: userId,
      albumIds: [album.id],
      deletedAt: _time.add(const Duration(minutes: 1)),
    );
    expect(await store.watchAlbums(userId: userId).first, isEmpty);
    expect(
      await store.getPhotoNoteSnapshot(
        userId: userId,
        photoNoteId: snapshot.photoNote.id,
      ),
      isNotNull,
      reason: 'deleting an album must never delete its Photo Notes',
    );
  });

  test('records consent with optimistic old-value enforcement', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final accepted = ConsentEvent(
      id: ids.next(),
      userId: userId,
      consentType: ConsentType.localPersonalization,
      oldValue: false,
      newValue: true,
      policyVersion: 'privacy-v1',
      sourceAction: 'settings_toggle',
      enforcementState: ConsentEnforcementState.pending,
      occurredAt: _time.add(const Duration(minutes: 1)),
    );

    await store.recordChange(accepted);
    final account = await store.watchLocalAccount(userId: userId).first;
    expect(account!.localPersonalizationEnabled, isTrue);
    final pending = await store.getPendingEnforcement(userId: userId);
    expect(pending, hasLength(1));
    expect(pending.single.id, accepted.id);
    expect(pending.single.newValue, isTrue);

    final stale = ConsentEvent(
      id: ids.next(),
      userId: userId,
      consentType: ConsentType.localPersonalization,
      oldValue: false,
      newValue: true,
      policyVersion: 'privacy-v1',
      sourceAction: 'stale_settings_screen',
      enforcementState: ConsentEnforcementState.pending,
      occurredAt: _time.add(const Duration(minutes: 2)),
    );
    await expectLater(store.recordChange(stale), throwsStateError);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        'SELECT COUNT(*) FROM consent_events WHERE user_id = ?',
        [userId],
      )),
      1,
    );
  });

  test('keeps learning events append-only and releases sync dependencies',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(snapshot);
    final event = LearningEvent(
      id: ids.next(),
      userId: userId,
      detectionId: snapshot.detections.single.id,
      photoNoteId: snapshot.photoNote.id,
      sessionId: ids.next(),
      eventType: LearningEventType.answered,
      answerNormalized: 'cup',
      isCorrect: true,
      responseTimeMs: 350,
      hintCount: 0,
      attemptNumber: 1,
      schedulerVersion: 'srs-v1',
      occurredAt: _time,
      recordedAt: _time,
    );
    await store.appendEvent(event);
    await expectLater(
        store.appendEvent(event), throwsA(isA<DatabaseException>()));
    expect(await store.getEvents(LearningEventQuery(userId: userId)),
        hasLength(1));

    final progress = SrsProgress(
      userId: userId,
      vocabKey: 'cup',
      masteryLevel: 0.4,
      reviewCount: 1,
      lastReviewedAt: _time,
      nextReviewAt: _time.add(const Duration(days: 1)),
      schedulerVersion: 'srs-v1',
      updatedAt: _time,
    );
    await store.saveSrsProgress(progress);
    expect(
      (await store.getSrsProgress(userId: userId, vocabKey: 'cup'))!
          .reviewCount,
      1,
    );

    final dependencyId = ids.next();
    final childId = ids.next();
    final dependency = _operation(
      operationId: dependencyId,
      userId: userId,
      entityId: snapshot.mediaAsset.id,
    );
    final child = _operation(
      operationId: childId,
      userId: userId,
      entityId: snapshot.photoNote.id,
      dependencyIds: [dependencyId],
    );
    await store.enqueue(dependency);
    await store.enqueue(child);
    expect(
      (await store.getReadyOperations(userId: userId, now: _time))
          .map((item) => item.operationId),
      [dependencyId],
    );
    await store.updateOperation(_operation(
      operationId: dependencyId,
      userId: userId,
      entityId: snapshot.mediaAsset.id,
      state: SyncOperationState.running,
    ));
    await store.updateOperation(_operation(
      operationId: dependencyId,
      userId: userId,
      entityId: snapshot.mediaAsset.id,
      state: SyncOperationState.done,
    ));
    expect(
      (await store.getReadyOperations(userId: userId, now: _time))
          .map((item) => item.operationId),
      [childId],
    );
  });

  test('persists training lineage and invalidates a model by source', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(snapshot);
    final example = TrainingExample(
      id: ids.next(),
      userId: userId,
      taskType: TrainingTaskType.visionClassification,
      mediaAssetId: snapshot.mediaAsset.id,
      sourceDetectionId: snapshot.detections.single.id,
      sourceAnnotationId: snapshot.annotations.single.id,
      featureSchemaVersion: 'vision-features-v1',
      labelSchemaVersion: 'vocab-label-v1',
      builderVersion: 'builder-v1',
      featuresJson: const {
        'embedding': [0.1, 0.2]
      },
      targetJson: const {'class': 'cup'},
      eligibilityStatus: TrainingEligibilityStatus.eligible,
      qualityScore: 0.95,
      split: DatasetSplit.train,
      splitSeedVersion: 'split-v1',
      createdAt: _time,
    );
    await store.saveExample(example);
    final manifest = DatasetManifest(
      id: ids.next(),
      userId: userId,
      taskType: example.taskType,
      builderVersion: 'builder-v1',
      featureSchemaVersion: example.featureSchemaVersion,
      labelSchemaVersion: example.labelSchemaVersion,
      splitSeedVersion: example.splitSeedVersion,
      sourceWatermark: 'event:1',
      splitCounts: const {'train': 1},
      consentSnapshot: const {'local_personalization': true},
      qualityReport: const {'accepted': 1},
      manifestHashSha256: _sha,
      createdAt: _time,
    );
    await store.saveDatasetManifest(
      manifest: manifest,
      trainingExampleIds: [example.id],
    );
    final model = ModelVersion(
      id: ids.next(),
      userId: userId,
      taskType: example.taskType,
      baseModelVersion: 'vision-base-v1',
      featureSchemaVersion: example.featureSchemaVersion,
      labelSchemaVersion: example.labelSchemaVersion,
      activationStatus: ModelActivationStatus.active,
      baselineMetrics: const {'accuracy': 0.7},
      personalizedMetrics: const {'accuracy': 0.8},
      createdAt: _time,
    );
    await store.saveModelVersion(model);
    final run = TrainingRun(
      id: ids.next(),
      userId: userId,
      modelVersionId: model.id,
      datasetManifestId: manifest.id,
      status: TrainingRunStatus.succeeded,
      sampleCount: 1,
      trainingSteps: 10,
      metrics: const {'accuracy': 0.8},
      runtimeMetadata: const {'device': 'test'},
      startedAt: _time,
      completedAt: _time.add(const Duration(minutes: 1)),
    );
    await store.saveTrainingRun(
      run: run,
      examples: [
        TrainingRunExample(
          trainingRunId: run.id,
          trainingExampleId: example.id,
        ),
      ],
    );

    expect(
      await store.findModelsUsingSources(
        userId: userId,
        sourceIds: [snapshot.detections.single.id],
      ),
      hasLength(1),
    );
    await store.requestPermanentDeletion(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      requestedAt: _time.add(const Duration(days: 1)),
    );
    expect(
      await store.getEligibleExamples(
        userId: userId,
        taskType: example.taskType,
      ),
      isEmpty,
    );
    expect(
      await store.getActiveModel(userId: userId, taskType: example.taskType),
      isNull,
    );
    expect(await store.getPendingTombstones(userId: userId), isEmpty);
    final receipt = (await database.query(
      'sync_tombstones',
      where: 'user_id = ? AND entity_id = ?',
      whereArgs: [userId, snapshot.photoNote.id],
    ))
        .single;
    expect(receipt['remote_purge_completed'], 1);
  });

  test('promotes 30-day Trash and physically purges only the owning aggregate',
      () async {
    final userId = ids.next();
    final otherUserId = ids.next();
    await store.saveLocalAccount(_account(userId));
    await store.saveLocalAccount(_account(otherUserId));
    final snapshot = _snapshot(ids, userId);
    final otherSnapshot = _snapshot(ids, otherUserId);
    await store.saveCapturedPhotoNote(snapshot);
    await store.saveCapturedPhotoNote(otherSnapshot);
    await store.movePhotoNotesToTrash(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      deletedAt: _time,
    );

    expect(
      await store.requestExpiredPhotoNoteDeletions(
        userId: userId,
        now: _time.add(const Duration(days: 30)).subtract(
              const Duration(microseconds: 1),
            ),
        retention: const Duration(days: 30),
      ),
      0,
    );
    expect(
      await store.requestExpiredPhotoNoteDeletions(
        userId: userId,
        now: _time.add(const Duration(days: 30)),
        retention: const Duration(days: 30),
      ),
      1,
    );

    final target =
        (await store.getPhotoNotePurgeTargets(userId: userId)).single;
    expect(target.localContentPresent, isTrue);
    expect(target.remotePurgeCompleted, isTrue);
    expect(target.deleteMedia, isTrue);
    expect(await store.finalizePhotoNoteLocalPurge(target), isTrue);

    expect(
      await store.getPhotoNoteSnapshot(
        userId: userId,
        photoNoteId: snapshot.photoNote.id,
      ),
      isNull,
    );
    expect(
      await store.getPhotoNoteSnapshot(
        userId: otherUserId,
        photoNoteId: otherSnapshot.photoNote.id,
      ),
      isNotNull,
    );
    for (final table in [
      'media_assets',
      'scan_runs',
      'vocab_detections',
      'vocab_annotations',
    ]) {
      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM $table'),
        ),
        1,
        reason: '$table must retain only the other owner aggregate',
      );
    }
    final receipt = (await database.query(
      'sync_tombstones',
      where: 'user_id = ? AND entity_id = ?',
      whereArgs: [userId, snapshot.photoNote.id],
    ))
        .single;
    expect(receipt['remote_purge_completed'], 1);
    expect(
      await store.requestExpiredPhotoNoteDeletions(
        userId: userId,
        now: _time.add(const Duration(days: 60)),
        retention: const Duration(days: 30),
      ),
      0,
      reason: 'repeated maintenance is idempotent',
    );
  });

  test('shared media survives until its final Photo Note is purged', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(snapshot);
    final sharedNoteId = ids.next();
    await database.insert('photo_notes', {
      'id': sharedNoteId,
      'user_id': userId,
      'media_asset_id': snapshot.mediaAsset.id,
      'primary_scan_run_id': snapshot.primaryScanRun!.id,
      'title': 'Shared copy',
      'template_id': 'default-v1',
      'created_at': _time.toIso8601String(),
      'updated_at': _time.toIso8601String(),
      'sync_status': 'local_only',
    });

    final firstDeleteAt = _time.add(const Duration(days: 1));
    await store.requestPermanentDeletion(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      requestedAt: firstDeleteAt,
    );
    var targets = await store.getPhotoNotePurgeTargets(userId: userId);
    expect(targets.single.deleteMedia, isFalse);
    expect(targets.single.localRelativePaths, isEmpty);
    await store.finalizePhotoNoteLocalPurge(targets.single);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        'SELECT COUNT(*) FROM media_assets WHERE id = ?',
        [snapshot.mediaAsset.id],
      )),
      1,
    );

    await store.requestPermanentDeletion(
      userId: userId,
      photoNoteIds: [sharedNoteId],
      requestedAt: firstDeleteAt.add(const Duration(minutes: 1)),
    );
    targets = await store.getPhotoNotePurgeTargets(userId: userId);
    final finalTarget =
        targets.singleWhere((target) => target.photoNoteId == sharedNoteId);
    expect(finalTarget.deleteMedia, isTrue);
    expect(finalTarget.localRelativePaths, isNotEmpty);
    await store.finalizePhotoNoteLocalPurge(finalTarget);

    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        'SELECT COUNT(*) FROM media_assets WHERE id = ?',
        [snapshot.mediaAsset.id],
      )),
      0,
    );
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        'SELECT COUNT(*) FROM photo_notes WHERE user_id = ?',
        [userId],
      )),
      0,
    );
  });

  test(
      'missing media quarantines training lineage while preserving the Library aggregate',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId));
    final snapshot = _snapshot(ids, userId);
    await store.saveCapturedPhotoNote(snapshot);
    final example = TrainingExample(
      id: ids.next(),
      userId: userId,
      taskType: TrainingTaskType.visionClassification,
      mediaAssetId: snapshot.mediaAsset.id,
      sourceDetectionId: snapshot.detections.single.id,
      sourceAnnotationId: snapshot.annotations.single.id,
      featureSchemaVersion: 'vision-features-v1',
      labelSchemaVersion: 'vocab-label-v1',
      builderVersion: 'builder-v1',
      featuresJson: const {
        'embedding': [0.1, 0.2]
      },
      targetJson: const {'class': 'cup'},
      eligibilityStatus: TrainingEligibilityStatus.eligible,
      qualityScore: 0.95,
      split: DatasetSplit.train,
      splitSeedVersion: 'split-v1',
      createdAt: _time,
    );
    await store.saveExample(example);
    final manifest = DatasetManifest(
      id: ids.next(),
      userId: userId,
      taskType: example.taskType,
      builderVersion: example.builderVersion,
      featureSchemaVersion: example.featureSchemaVersion,
      labelSchemaVersion: example.labelSchemaVersion,
      splitSeedVersion: example.splitSeedVersion,
      sourceWatermark: 'event:1',
      splitCounts: const {'train': 1},
      consentSnapshot: const {'local_personalization': true},
      qualityReport: const {'accepted': 1},
      manifestHashSha256: _sha,
      createdAt: _time,
    );
    await store.saveDatasetManifest(
      manifest: manifest,
      trainingExampleIds: [example.id],
    );
    final model = ModelVersion(
      id: ids.next(),
      userId: userId,
      taskType: example.taskType,
      baseModelVersion: 'vision-base-v1',
      featureSchemaVersion: example.featureSchemaVersion,
      labelSchemaVersion: example.labelSchemaVersion,
      activationStatus: ModelActivationStatus.active,
      baselineMetrics: const {'accuracy': 0.7},
      personalizedMetrics: const {'accuracy': 0.8},
      createdAt: _time,
    );
    await store.saveModelVersion(model);
    final run = TrainingRun(
      id: ids.next(),
      userId: userId,
      modelVersionId: model.id,
      datasetManifestId: manifest.id,
      status: TrainingRunStatus.succeeded,
      sampleCount: 1,
      trainingSteps: 10,
      metrics: const {'accuracy': 0.8},
      runtimeMetadata: const {'device': 'test'},
      startedAt: _time,
      completedAt: _time.add(const Duration(minutes: 1)),
    );
    await store.saveTrainingRun(
      run: run,
      examples: [
        TrainingRunExample(
          trainingRunId: run.id,
          trainingExampleId: example.id,
        ),
      ],
    );

    await store.quarantineTrainingDataForMissingMediaPaths(
      [snapshot.mediaAsset.displayRelativePath],
      detectedAt: _time.add(const Duration(days: 1)),
    );

    expect(
      await store.getEligibleExamples(
        userId: userId,
        taskType: example.taskType,
      ),
      isEmpty,
    );
    expect(
      await store.getActiveModel(userId: userId, taskType: example.taskType),
      isNull,
    );
    final invalidatedAt = (await store.findModelsUsingSources(
      userId: userId,
      sourceIds: [snapshot.mediaAsset.id],
    ))
        .single
        .invalidatedAt;
    await store.quarantineTrainingDataForMissingMediaPaths(
      [snapshot.mediaAsset.displayRelativePath],
      detectedAt: _time.add(const Duration(days: 3)),
    );
    expect(
      (await store.findModelsUsingSources(
        userId: userId,
        sourceIds: [snapshot.mediaAsset.id],
      ))
          .single
          .invalidatedAt,
      invalidatedAt,
      reason: 'repeated startup audits must retain the first invalidation time',
    );
    final preserved = await store.getPhotoNoteSnapshot(
      userId: userId,
      photoNoteId: snapshot.photoNote.id,
    );
    expect(preserved?.detections.single.wordRaw,
        snapshot.detections.single.wordRaw);

    final secondRun = TrainingRun(
      id: ids.next(),
      userId: userId,
      modelVersionId: model.id,
      datasetManifestId: manifest.id,
      status: TrainingRunStatus.pending,
      sampleCount: 1,
      trainingSteps: 0,
      metrics: const {},
      runtimeMetadata: const {},
      startedAt: _time.add(const Duration(days: 2)),
    );
    await expectLater(
      store.saveTrainingRun(
        run: secondRun,
        examples: [
          TrainingRunExample(
            trainingRunId: secondRun.id,
            trainingExampleId: example.id,
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('M2C commits legacy and normalized scan in one owner-scoped transaction',
      () async {
    final userId = ids.next();
    final dataSource = ScanResultLocalDataSource(
      openLibraryStore: () async => store,
      currentUserId: () => userId,
      idGenerator: ids.next,
      readImageSize: (_) async => (640, 480),
    );
    final result = gemini.GeminiVisionResult.fromJson({
      'schema_version': 2,
      'scan_id': 'edge-scan-1',
      'service_tier': 'free',
      'model_used': 'gemini-flash',
      'words': [
        {
          'number': 1,
          'id': 'd1',
          'kind': 'object',
          'parent_id': null,
          'word': 'Cup',
          'phonetic': '/kʌp/',
          'meaning_vi': 'cái cốc',
          'box': {'x': 100, 'y': 200, 'w': 300, 'h': 400},
        },
      ],
    });
    final noteChanges = StreamIterator(
      store.watchPhotoNotes(PhotoNoteQuery(userId: userId)),
    );
    expect(await noteChanges.moveNext(), isTrue);
    expect(noteChanges.current, isEmpty);

    final nextNoteEmission = noteChanges.moveNext();
    final legacy = await dataSource.save(ScanSaveRequest(
      localPath: r'C:\app\Documents\capy_scans\scan.jpg',
      imageBytes: Uint8List.fromList([1, 2, 3, 4]),
      result: result,
      requestId: ids.next(),
      captureSource: ScanImageSource.camera,
      templateId: 'standard',
      startedAt: _time.subtract(const Duration(seconds: 1)),
      completedAt: _time,
    ));
    expect(await nextNoteEmission, isTrue);
    expect(noteChanges.current, hasLength(1));
    await noteChanges.cancel();
    final queue = LegacyScanImportQueue(database);
    final snapshot = await store.getPhotoNoteSnapshot(
      userId: userId,
      photoNoteId: legacy.normalizedPhotoNoteId!,
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.mediaAsset.displayRelativePath, 'capy_scans/scan.jpg');
    expect(snapshot.mediaAsset.width, 640);
    expect(snapshot.mediaAsset.height, 480);
    expect(snapshot.mediaAsset.contentHashSha256, hasLength(64));
    expect(snapshot.mediaAsset.captureSource, CaptureSource.camera);
    expect(snapshot.primaryScanRun!.requestId, isNotEmpty);
    expect(
        snapshot.primaryScanRun!.responseSchemaVersion, 'gemini-hierarchy-v2');
    expect(snapshot.primaryScanRun!.rawResponseJson!['schema_version'], 2);
    expect(
      (snapshot.primaryScanRun!.rawResponseJson!['words']! as List<Object?>)
          .single,
      containsPair('kind', 'object'),
    );
    expect(snapshot.detections.single.wordNormalized, 'cup');
    expect(snapshot.annotations, isEmpty,
        reason: 'raw AI predictions are not user-confirmed training labels');
    expect(await queue.getPending(), isEmpty);
    final row = (await database.query(
      'legacy_scan_import_queue',
      where: 'legacy_scan_result_id = ?',
      whereArgs: [legacy.id],
    ))
        .single;
    expect(row['migration_state'], 'imported');
    expect(row['imported_media_asset_id'], snapshot.mediaAsset.id);
    expect(
      Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM training_examples'),
      ),
      0,
    );
  });
}

LocalAccount _account(String userId, {bool cloudBackup = false}) {
  return LocalAccount(
    userId: userId,
    accountState: AccountState.active,
    cloudBackupEnabled: cloudBackup,
    localPersonalizationEnabled: false,
    federatedContributionEnabled: false,
    createdAt: _time,
    updatedAt: _time,
  );
}

SyncOperation _operation({
  required String operationId,
  required String userId,
  required String entityId,
  Iterable<String> dependencyIds = const [],
  SyncOperationState state = SyncOperationState.pending,
}) {
  return SyncOperation(
    operationId: operationId,
    userId: userId,
    entityType: SyncEntityType.photoNote,
    entityId: entityId,
    operationType: SyncOperationType.update,
    payloadJson: const {},
    dependencyIds: dependencyIds,
    state: state,
    attemptCount: 0,
    createdAt: _time,
    updatedAt: _time,
  );
}

Future<void> _seedActiveTrainingLineage({
  required SqliteLibraryStore store,
  required _Ids ids,
  required String userId,
  required PhotoNoteSnapshot snapshot,
}) async {
  final example = TrainingExample(
    id: ids.next(),
    userId: userId,
    taskType: TrainingTaskType.visionClassification,
    mediaAssetId: snapshot.mediaAsset.id,
    sourceDetectionId: snapshot.detections.single.id,
    sourceAnnotationId: snapshot.annotations.single.id,
    featureSchemaVersion: 'vision-features-v1',
    labelSchemaVersion: 'vocab-label-v1',
    builderVersion: 'builder-v1',
    featuresJson: const {
      'embedding': [0.1, 0.2],
    },
    targetJson: const {'class': 'cup'},
    eligibilityStatus: TrainingEligibilityStatus.eligible,
    qualityScore: 0.95,
    split: DatasetSplit.train,
    splitSeedVersion: 'split-v1',
    createdAt: _time,
  );
  await store.saveExample(example);
  final manifest = DatasetManifest(
    id: ids.next(),
    userId: userId,
    taskType: example.taskType,
    builderVersion: example.builderVersion,
    featureSchemaVersion: example.featureSchemaVersion,
    labelSchemaVersion: example.labelSchemaVersion,
    splitSeedVersion: example.splitSeedVersion,
    sourceWatermark: 'event:1',
    splitCounts: const {'train': 1},
    consentSnapshot: const {'local_personalization': true},
    qualityReport: const {'accepted': 1},
    manifestHashSha256: _sha,
    createdAt: _time,
  );
  await store.saveDatasetManifest(
    manifest: manifest,
    trainingExampleIds: [example.id],
  );
  final model = ModelVersion(
    id: ids.next(),
    userId: userId,
    taskType: example.taskType,
    baseModelVersion: 'vision-base-v1',
    featureSchemaVersion: example.featureSchemaVersion,
    labelSchemaVersion: example.labelSchemaVersion,
    activationStatus: ModelActivationStatus.active,
    baselineMetrics: const {'accuracy': 0.7},
    personalizedMetrics: const {'accuracy': 0.8},
    createdAt: _time,
  );
  await store.saveModelVersion(model);
  final run = TrainingRun(
    id: ids.next(),
    userId: userId,
    modelVersionId: model.id,
    datasetManifestId: manifest.id,
    status: TrainingRunStatus.succeeded,
    sampleCount: 1,
    trainingSteps: 10,
    metrics: const {'accuracy': 0.8},
    runtimeMetadata: const {'device': 'test'},
    startedAt: _time,
    completedAt: _time.add(const Duration(minutes: 1)),
  );
  await store.saveTrainingRun(
    run: run,
    examples: [
      TrainingRunExample(
        trainingRunId: run.id,
        trainingExampleId: example.id,
      ),
    ],
  );
}

PhotoNoteSnapshot _snapshot(_Ids ids, String userId) {
  final mediaId = ids.next();
  final scanId = ids.next();
  final noteId = ids.next();
  final detectionId = ids.next();
  return PhotoNoteSnapshot(
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: userId,
      contentHashSha256: _sha,
      displayRelativePath: 'accounts/$userId/media/display.jpg',
      modelInputRelativePath: 'accounts/$userId/media/model.jpg',
      mimeType: 'image/jpeg',
      width: 1080,
      height: 1920,
      orientation: 0,
      byteSizeDisplay: 1024,
      preprocessingVersion: 'vision-input-v1',
      captureSource: CaptureSource.camera,
      capturedAt: _time,
      createdAt: _time,
      syncStatus: SyncStatus.localOnly,
    ),
    primaryScanRun: ScanRun(
      id: scanId,
      userId: userId,
      mediaAssetId: mediaId,
      requestId: 'request-$scanId',
      provider: 'google_gemini',
      modelName: 'gemini-flash',
      promptVersion: 'prompt-v1',
      responseSchemaVersion: 'scan-response-v1',
      preprocessingVersion: 'vision-input-v1',
      rawResponseJson: const {
        'words': [
          {'word': 'Cup'}
        ]
      },
      responseHashSha256: _sha,
      status: ScanRunStatus.succeeded,
      startedAt: _time,
      completedAt: _time.add(const Duration(seconds: 1)),
    ),
    photoNote: PhotoNote(
      id: noteId,
      userId: userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: 'Kitchen',
      emoji: '🍵',
      templateId: 'default-v1',
      createdAt: _time,
      updatedAt: _time,
      syncStatus: SyncStatus.localOnly,
    ),
    detections: [
      VocabDetection(
        id: detectionId,
        scanRunId: scanId,
        wordRaw: 'Cup',
        wordNormalized: 'cup',
        meaningVi: 'cái cốc',
        boundingBox: NormalizedBoundingBox(
          x: 0.1,
          y: 0.1,
          width: 0.2,
          height: 0.2,
        ),
        confidence: 0.9,
        displayOrder: 0,
        createdAt: _time,
      ),
    ],
    annotations: [
      VocabAnnotation(
        id: ids.next(),
        userId: userId,
        detectionId: detectionId,
        source: AnnotationSource.userConfirmed,
        qualityStatus: AnnotationQualityStatus.accepted,
        revision: 1,
        createdAt: _time,
        updatedAt: _time,
      ),
    ],
  );
}

PhotoNoteSnapshot _asCloudSnapshot(PhotoNoteSnapshot source) {
  final media = source.mediaAsset;
  final note = source.photoNote;
  return PhotoNoteSnapshot(
    mediaAsset: MediaAsset(
      id: media.id,
      userId: media.userId,
      contentHashSha256: media.contentHashSha256,
      displayRelativePath: 'capy_scans/cloud_${media.id}.jpg',
      remoteDisplayPath: '${media.userId}/${media.id}/display.jpg',
      mimeType: media.mimeType,
      width: media.width,
      height: media.height,
      orientation: media.orientation,
      byteSizeDisplay: media.byteSizeDisplay,
      preprocessingVersion: media.preprocessingVersion,
      captureSource: media.captureSource,
      capturedAt: media.capturedAt,
      createdAt: media.createdAt,
      syncStatus: SyncStatus.synced,
    ),
    primaryScanRun: source.primaryScanRun,
    photoNote: PhotoNote(
      id: note.id,
      userId: note.userId,
      mediaAssetId: note.mediaAssetId,
      primaryScanRunId: note.primaryScanRunId,
      title: note.title,
      emoji: note.emoji,
      templateId: note.templateId,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deletedAt: note.deletedAt,
      syncStatus: SyncStatus.synced,
    ),
    detections: source.detections,
    annotations: source.annotations,
  );
}

final class _Ids {
  int _value = 1;

  String next() {
    final suffix = (_value++).toString().padLeft(12, '0');
    return 'e0000000-0000-0000-0000-$suffix';
  }
}

final class _AvailableMediaLoader implements LibraryMediaLoader {
  const _AvailableMediaLoader();

  @override
  Future<Uint8List> readBytes(String relativePath) async => Uint8List(1);

  @override
  Future<int> sizeBytes(String relativePath) async => 1;
}

final class _MissingMediaLoader implements LibraryMediaLoader {
  const _MissingMediaLoader();

  @override
  Future<Uint8List> readBytes(String relativePath) {
    throw const LibraryMediaLoadException('missing');
  }

  @override
  Future<int> sizeBytes(String relativePath) {
    throw const LibraryMediaLoadException('missing');
  }
}
