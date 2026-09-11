import 'dart:io';

import 'package:capy_vocab/features/library/application/library_sync_gateway.dart';
import 'package:capy_vocab/features/library/application/library_sync_worker.dart';
import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/sqlite_library_store.dart';
import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _sha = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
final _baseTime = DateTime.utc(2026, 9, 4, 8);

void main() {
  late Directory temporaryDirectory;
  late LibraryDatabase libraryDatabase;
  late Database database;
  late SqliteLibraryStore store;
  late _Ids ids;
  late DateTime now;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('library_m3b_');
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: '${temporaryDirectory.path}${Platform.pathSeparator}store.db',
    );
    database = await libraryDatabase.open();
    ids = _Ids();
    now = _baseTime;
    store = SqliteLibraryStore(
      database: database,
      idGenerator: ids.next,
      clock: () => now,
    );
  });

  tearDown(() async {
    await store.dispose();
    await libraryDatabase.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('drains the complete dependency chain and persists remote paths',
      () async {
    final userId = ids.next();
    final snapshot = _snapshot(ids, userId);
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(snapshot);
    final remote = _FakeGateway(authenticatedUserId: userId);

    final result = await _worker(store, remote, () => now).drainOnce(
      userId: userId,
    );

    expect(result.completed, 5);
    expect(result.retried, 0);
    expect(result.blocked, 0);
    expect(remote.calls, [
      'upload:${snapshot.mediaAsset.id}',
      'media:${snapshot.mediaAsset.id}',
      'scan:${snapshot.primaryScanRun!.id}',
      'detection:${snapshot.detections.single.id}',
      'annotation:${snapshot.annotations.single.id}',
      'photo:${snapshot.photoNote.id}',
    ]);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        "SELECT COUNT(*) FROM sync_operations WHERE state = 'done'",
      )),
      5,
    );
    final restored = await store.getPhotoNoteSnapshot(
      userId: userId,
      photoNoteId: snapshot.photoNote.id,
    );
    expect(restored!.mediaAsset.remoteDisplayPath,
        '$userId/${snapshot.mediaAsset.id}/display.jpg');
    expect(restored.photoNote.syncStatus, SyncStatus.synced);
  });

  test('backs off a transient failure and safely retries deterministic upload',
      () async {
    final userId = ids.next();
    final snapshot = _snapshot(ids, userId);
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(snapshot);
    final remote = _FakeGateway(
      authenticatedUserId: userId,
      remainingUploadFailures: 1,
    );
    final worker = _worker(store, remote, () => now);

    final first = await worker.drainOnce(userId: userId);
    final retryRow = (await database.query(
      'sync_operations',
      where: 'entity_type = ?',
      whereArgs: ['media_asset'],
    ))
        .single;
    expect(first.retried, 1);
    expect(retryRow['state'], 'retry');
    expect(retryRow['attempt_count'], 1);
    expect(retryRow['last_error_code'], 'network_unavailable');
    expect(retryRow['next_attempt_at'],
        _baseTime.add(const Duration(seconds: 5)).toIso8601String());
    expect(
      await store.getNextRetryAt(userId: userId),
      _baseTime.add(const Duration(seconds: 5)),
    );

    now = now.add(const Duration(seconds: 5));
    final second = await worker.drainOnce(userId: userId);

    expect(second.completed, 5);
    expect(remote.uploadAttempts, 2);
    expect(await store.getNextRetryAt(userId: userId), isNull);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        "SELECT COUNT(*) FROM sync_operations WHERE state = 'done'",
      )),
      5,
    );
  });

  test('replays the same media key when metadata commit fails after upload',
      () async {
    final userId = ids.next();
    final snapshot = _snapshot(ids, userId);
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(snapshot);
    final remote = _FakeGateway(
      authenticatedUserId: userId,
      remainingMediaUpsertFailures: 1,
    );
    final worker = _worker(store, remote, () => now);

    final first = await worker.drainOnce(userId: userId);
    expect(first.retried, 1);
    expect(remote.uploadedDisplayPaths, [
      '$userId/${snapshot.mediaAsset.id}/display.jpg',
    ]);

    now = now.add(const Duration(seconds: 5));
    final second = await worker.drainOnce(userId: userId);

    expect(second.completed, 5);
    expect(remote.uploadedDisplayPaths, [
      '$userId/${snapshot.mediaAsset.id}/display.jpg',
      '$userId/${snapshot.mediaAsset.id}/display.jpg',
    ]);
  });

  test('recovers a stale running operation after app restart', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(_snapshot(ids, userId));
    final pending = (await store.getReadyOperations(
      userId: userId,
      now: now,
    ))
        .single;
    await store.updateOperation(_copyOperation(
      pending,
      state: SyncOperationState.running,
      attemptCount: 1,
      updatedAt: now,
    ));
    now = now.add(const Duration(minutes: 20));

    final result = await _worker(
      store,
      _FakeGateway(authenticatedUserId: userId),
      () => now,
    ).drainOnce(userId: userId);

    expect(result.recovered, 1);
    expect(result.completed, 5);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        "SELECT COUNT(*) FROM sync_operations WHERE state = 'done'",
      )),
      5,
    );
  });

  test('does not touch pending operations while cloud consent is off',
      () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(_snapshot(ids, userId));
    now = now.add(const Duration(minutes: 1));
    await store.recordChange(_cloudConsent(
      id: ids.next(),
      userId: userId,
      oldValue: true,
      newValue: false,
      at: now,
    ));
    final remote = _FakeGateway(authenticatedUserId: userId);
    final worker = _worker(store, remote, () => now);

    final skipped = await worker.drainOnce(userId: userId);

    expect(skipped.skippedForConsent, isTrue);
    expect(remote.calls, isEmpty);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        "SELECT COUNT(*) FROM sync_operations WHERE state = 'pending'",
      )),
      5,
    );

    now = now.add(const Duration(minutes: 1));
    await store.recordChange(_cloudConsent(
      id: ids.next(),
      userId: userId,
      oldValue: false,
      newValue: true,
      at: now,
    ));
    final resumed = await worker.drainOnce(userId: userId);
    expect(resumed.completed, 5);
  });

  test('auth block is released after the same owner signs in again', () async {
    final userId = ids.next();
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(_snapshot(ids, userId));
    final remote = _FakeGateway();
    final worker = _worker(store, remote, () => now);

    final blocked = await worker.drainOnce(userId: userId);
    expect(blocked.blocked, 1);
    expect((await database.query('sync_operations')).first['last_error_code'],
        'auth_required');

    now = now.add(const Duration(minutes: 1));
    remote.authenticatedUserId = userId;
    final resumed = await worker.drainOnce(userId: userId);
    expect(resumed.completed, 5);
    expect(
      Sqflite.firstIntValue(await database.rawQuery(
        "SELECT COUNT(*) FROM sync_operations WHERE state = 'done'",
      )),
      5,
    );
  });

  test('remote purge completes the matching local tombstone', () async {
    final userId = ids.next();
    final snapshot = _snapshot(ids, userId);
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(snapshot);
    final remote = _FakeGateway(authenticatedUserId: userId);
    final worker = _worker(store, remote, () => now);
    await worker.drainOnce(userId: userId);
    remote.calls.clear();
    now = now.add(const Duration(days: 1));
    await store.requestPermanentDeletion(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      requestedAt: now,
    );

    final result = await worker.drainOnce(userId: userId);

    expect(result.completed, 1);
    expect(remote.calls, ['delete:${snapshot.photoNote.id}']);
    expect(await store.getPendingTombstones(userId: userId), isEmpty);
  });

  test('cloud deletion still drains after backup consent is disabled',
      () async {
    final userId = ids.next();
    final snapshot = _snapshot(ids, userId);
    await store.saveLocalAccount(_account(userId, cloudBackup: true));
    await store.saveCapturedPhotoNote(snapshot);
    final remote = _FakeGateway(authenticatedUserId: userId);
    final worker = _worker(store, remote, () => now);
    await worker.drainOnce(userId: userId);
    remote.calls.clear();

    now = now.add(const Duration(days: 1));
    await store.recordChange(_cloudConsent(
      id: ids.next(),
      userId: userId,
      oldValue: true,
      newValue: false,
      at: now,
    ));
    await store.requestPermanentDeletion(
      userId: userId,
      photoNoteIds: [snapshot.photoNote.id],
      requestedAt: now,
    );
    final target =
        (await store.getPhotoNotePurgeTargets(userId: userId)).single;
    await store.finalizePhotoNoteLocalPurge(target);
    expect(
      await store.getPhotoNoteSnapshot(
        userId: userId,
        photoNoteId: snapshot.photoNote.id,
      ),
      isNull,
    );

    final result = await worker.drainOnce(userId: userId);

    expect(result.skippedForConsent, isTrue);
    expect(result.completed, 1);
    expect(remote.calls, ['delete:${snapshot.photoNote.id}']);
    expect(await store.getPendingTombstones(userId: userId), isEmpty);
  });
}

LibrarySyncWorker _worker(
  SqliteLibraryStore store,
  LibrarySyncGateway remote,
  DateTime Function() clock,
) {
  return LibrarySyncWorker(
    operations: store,
    local: store,
    remote: remote,
    clock: clock,
  );
}

final class _FakeGateway implements LibrarySyncGateway {
  _FakeGateway({
    this.authenticatedUserId,
    this.remainingUploadFailures = 0,
    this.remainingMediaUpsertFailures = 0,
  });

  @override
  String? authenticatedUserId;
  int remainingUploadFailures;
  int remainingMediaUpsertFailures;
  int uploadAttempts = 0;
  final List<String> calls = [];
  final List<String> uploadedDisplayPaths = [];

  @override
  Future<MediaRemotePaths> uploadMedia(MediaAsset asset) async {
    uploadAttempts++;
    calls.add('upload:${asset.id}');
    if (remainingUploadFailures > 0) {
      remainingUploadFailures--;
      throw const LibrarySyncFailure.retry('network_unavailable');
    }
    final displayPath = '${asset.userId}/${asset.id}/display.jpg';
    uploadedDisplayPaths.add(displayPath);
    return MediaRemotePaths(
      display: displayPath,
      modelInput: '${asset.userId}/${asset.id}/model_input.jpg',
    );
  }

  @override
  Future<void> upsertMediaAsset(
    MediaAsset asset,
    MediaRemotePaths remotePaths,
  ) async {
    calls.add('media:${asset.id}');
    if (remainingMediaUpsertFailures > 0) {
      remainingMediaUpsertFailures--;
      throw const LibrarySyncFailure.retry('metadata_commit_failed');
    }
  }

  @override
  Future<void> upsertScanRun(ScanRun scanRun) async {
    calls.add('scan:${scanRun.id}');
  }

  @override
  Future<void> upsertVocabDetection({
    required String userId,
    required VocabDetection detection,
  }) async {
    calls.add('detection:${detection.id}');
  }

  @override
  Future<void> upsertVocabAnnotation(VocabAnnotation annotation) async {
    calls.add('annotation:${annotation.id}');
  }

  @override
  Future<void> upsertPhotoNote({
    required PhotoNote photoNote,
    required String displayObjectPath,
  }) async {
    calls.add('photo:${photoNote.id}');
  }

  @override
  Future<void> purgePhotoNote(PhotoNotePurgeTarget target) async {
    calls.add('delete:${target.photoNoteId}');
  }
}

LocalAccount _account(String userId, {required bool cloudBackup}) {
  return LocalAccount(
    userId: userId,
    accountState: AccountState.active,
    cloudBackupEnabled: cloudBackup,
    localPersonalizationEnabled: false,
    federatedContributionEnabled: false,
    createdAt: _baseTime,
    updatedAt: _baseTime,
  );
}

ConsentEvent _cloudConsent({
  required String id,
  required String userId,
  required bool oldValue,
  required bool newValue,
  required DateTime at,
}) {
  return ConsentEvent(
    id: id,
    userId: userId,
    consentType: ConsentType.cloudBackup,
    oldValue: oldValue,
    newValue: newValue,
    policyVersion: 'privacy-v1',
    sourceAction: 'settings_toggle',
    enforcementState: ConsentEnforcementState.pending,
    occurredAt: at,
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
      displayRelativePath: 'capy_scans/display.jpg',
      modelInputRelativePath: 'capy_scans/model.jpg',
      mimeType: 'image/jpeg',
      width: 1080,
      height: 1920,
      orientation: 0,
      byteSizeDisplay: 1024,
      preprocessingVersion: 'vision-input-v1',
      captureSource: CaptureSource.camera,
      capturedAt: _baseTime,
      createdAt: _baseTime,
      syncStatus: SyncStatus.pending,
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
          {'word': 'Cup'},
        ],
      },
      responseHashSha256: _sha,
      status: ScanRunStatus.succeeded,
      startedAt: _baseTime,
      completedAt: _baseTime.add(const Duration(seconds: 1)),
    ),
    photoNote: PhotoNote(
      id: noteId,
      userId: userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: 'Kitchen',
      templateId: 'default-v1',
      createdAt: _baseTime,
      updatedAt: _baseTime,
      syncStatus: SyncStatus.pending,
    ),
    detections: [
      VocabDetection(
        id: detectionId,
        scanRunId: scanId,
        wordRaw: 'Cup',
        wordNormalized: 'cup',
        displayOrder: 0,
        createdAt: _baseTime,
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
        createdAt: _baseTime,
        updatedAt: _baseTime,
      ),
    ],
  );
}

SyncOperation _copyOperation(
  SyncOperation operation, {
  required SyncOperationState state,
  required int attemptCount,
  required DateTime updatedAt,
}) {
  return SyncOperation(
    operationId: operation.operationId,
    userId: operation.userId,
    entityType: operation.entityType,
    entityId: operation.entityId,
    operationType: operation.operationType,
    payloadJson: operation.payloadJson,
    dependencyIds: operation.dependencyIds,
    state: state,
    attemptCount: attemptCount,
    createdAt: operation.createdAt,
    updatedAt: updatedAt,
  );
}

final class _Ids {
  int _value = 1;

  String next() {
    final suffix = (_value++).toString().padLeft(12, '0');
    return 'a0000000-0000-0000-0000-$suffix';
  }
}
