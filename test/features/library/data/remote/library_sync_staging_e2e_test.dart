import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:capy_vocab/features/library/application/library_sync_gateway.dart';
import 'package:capy_vocab/features/library/application/library_sync_worker.dart';
import 'package:capy_vocab/features/library/application/library_photo_note_deletion_service.dart';
import 'package:capy_vocab/features/library/application/library_cloud_pull_worker.dart';
import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/library_managed_media_purger_factory_io.dart';
import 'package:capy_vocab/features/library/data/local/sqlite_library_store.dart';
import 'package:capy_vocab/features/library/data/remote/supabase_library_sync_gateway.dart';
import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _enabledEnvironmentKey = 'CAPY_RUN_STAGING_SYNC_E2E';
const _urlEnvironmentKey = 'CAPY_STAGING_SUPABASE_URL';
const _anonEnvironmentKey = 'CAPY_STAGING_ANON_KEY';
const _serviceEnvironmentKey = 'CAPY_STAGING_SERVICE_ROLE_KEY';
const _bucket = 'photo_notes';

void main() {
  final enabled = Platform.environment[_enabledEnvironmentKey] == '1';

  test(
    'explicit pre-consent backfill uploads then permanently purges Staging data',
    () async {
      sqfliteFfiInit();
      final url = _requiredEnvironment(_urlEnvironmentKey);
      final anonKey = _requiredEnvironment(_anonEnvironmentKey);
      final serviceRoleKey = _requiredEnvironment(_serviceEnvironmentKey);
      final admin = SupabaseClient(url, serviceRoleKey);
      final owner = SupabaseClient(url, anonKey);
      final random = Random.secure();
      final runToken = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final password = 'Capy!${_randomHex(random, 24)}aA9';
      final email = 'capy-library-e2e-$runToken@example.com';
      final temporaryDirectory =
          await Directory.systemTemp.createTemp('capy_staging_sync_e2e_');
      final libraryDatabase = LibraryDatabase(
        factory: databaseFactoryFfi,
        path: '${temporaryDirectory.path}${Platform.pathSeparator}library.db',
      );
      final database = await libraryDatabase.open();
      final receiverDatabaseManager = LibraryDatabase(
        factory: databaseFactoryFfi,
        path: '${temporaryDirectory.path}${Platform.pathSeparator}receiver.db',
      );
      final receiverDatabase = await receiverDatabaseManager.open();
      final ids = _Ids(random);
      final now = DateTime.now().toUtc();
      final store = SqliteLibraryStore(
        database: database,
        idGenerator: ids.next,
        clock: () => now,
      );
      final receiverStore = SqliteLibraryStore(
        database: receiverDatabase,
        idGenerator: ids.next,
        clock: () => now,
      );
      String? userId;
      PhotoNoteSnapshot? snapshot;
      MediaRemotePaths? remotePaths;

      addTearDown(() async {
        final failures = <String>[];
        Future<void> attempt(
          String label,
          Future<void> Function() action,
        ) async {
          try {
            await action();
          } catch (error) {
            failures.add('$label (${error.runtimeType})');
          }
        }

        final cleanupUserId = userId;
        if (cleanupUserId != null) {
          final paths = <String>[
            if (remotePaths?.display case final path?) path,
            if (remotePaths?.modelInput case final path?) path,
            if (remotePaths?.original case final path?) path,
          ];
          if (paths.isNotEmpty) {
            await attempt('Storage remove', () async {
              await admin.storage.from(_bucket).remove(paths);
            });
          }
          for (final table in const [
            'vocab_annotations',
            'vocab_detections',
            'photo_notes',
            'scan_runs',
            'media_assets',
          ]) {
            await attempt('$table cleanup', () async {
              await admin.from(table).delete().eq('user_id', cleanupUserId);
              final remaining = await admin
                  .from(table)
                  .select('id')
                  .eq('user_id', cleanupUserId);
              expect(remaining, isEmpty, reason: 'cleanup failed for $table');
            });
          }
          await attempt('library_change_events cleanup', () async {
            await admin
                .from('library_change_events')
                .delete()
                .eq('user_id', cleanupUserId);
            final remaining = await admin
                .from('library_change_events')
                .select('sequence')
                .eq('user_id', cleanupUserId);
            expect(remaining, isEmpty,
                reason: 'cleanup failed for library_change_events');
          });
          final cleanupSnapshot = snapshot;
          if (cleanupSnapshot != null) {
            await attempt('Storage absence check', () async {
              final remainingObjects = await admin.storage.from(_bucket).list(
                    path: '$cleanupUserId/${cleanupSnapshot.mediaAsset.id}',
                  );
              expect(remainingObjects, isEmpty,
                  reason: 'cleanup failed for Storage objects');
            });
          }
          await attempt('Auth user delete', () async {
            await admin.auth.admin.deleteUser(cleanupUserId);
          });
        }
        await attempt('owner client dispose', owner.dispose);
        await attempt('admin client dispose', admin.dispose);
        await attempt('receiver local store dispose', receiverStore.dispose);
        await attempt('local store dispose', store.dispose);
        await attempt(
            'receiver local database close', receiverDatabaseManager.close);
        await attempt('local database close', libraryDatabase.close);
        await attempt('temporary directory delete', () async {
          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        });
        if (failures.isNotEmpty) {
          throw StateError('E2E cleanup failures: ${failures.join(', ')}');
        }
      });

      final created = await admin.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
          userMetadata: const {'test_scope': 'library_sync_staging_e2e'},
        ),
      );
      final createdUserId = created.user?.id;
      expect(createdUserId, isNotNull);
      if (createdUserId == null) {
        throw StateError('Staging admin API returned no created user.');
      }
      userId = createdUserId;

      final signedIn = await owner.auth.signInWithPassword(
        email: email,
        password: password,
      );
      expect(signedIn.user?.id, createdUserId);

      final mediaDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}capy_scans',
      );
      await mediaDirectory.create(recursive: true);
      final displayFile = File(
        '${mediaDirectory.path}${Platform.pathSeparator}display.jpg',
      );
      final modelFile = File(
        '${mediaDirectory.path}${Platform.pathSeparator}model.jpg',
      );
      final jpegBytes = base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==',
      );
      await displayFile.writeAsBytes(jpegBytes, flush: true);
      await modelFile.writeAsBytes(jpegBytes, flush: true);

      final capturedSnapshot = _snapshot(
        ids: ids,
        userId: createdUserId,
        now: now,
        byteSize: jpegBytes.length,
        contentHashSha256: sha256.convert(jpegBytes).toString(),
      );
      snapshot = capturedSnapshot;
      final uploadedPaths = MediaRemotePaths(
        display: '$createdUserId/${capturedSnapshot.mediaAsset.id}/display.jpg',
        modelInput:
            '$createdUserId/${capturedSnapshot.mediaAsset.id}/model_input.jpg',
      );
      // Set deterministic cleanup targets before the first network write so a
      // failed two-phase upload cannot leave a test object behind.
      remotePaths = uploadedPaths;
      await store.saveLocalAccount(
        _account(createdUserId, now, cloudBackup: false),
      );
      await store.saveCapturedPhotoNote(capturedSnapshot);
      expect(
        Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM sync_operations'),
        ),
        0,
      );
      await store.saveLocalAccount(_account(createdUserId, now));
      final candidates =
          await store.getCloudBackfillCandidates(userId: createdUserId);
      expect(candidates.map((item) => item.photoNoteId), [
        capturedSnapshot.photoNote.id,
      ]);
      expect(
        await store.enqueueCloudBackfill(
          userId: createdUserId,
          photoNoteIds: candidates.map((item) => item.photoNoteId),
        ),
        1,
      );

      final gateway = SupabaseLibrarySyncGateway(
        client: owner,
        resolveLocalMedia: (relativePath) async => File(
          '${temporaryDirectory.path}${Platform.pathSeparator}'
          '${relativePath.replaceAll('/', Platform.pathSeparator)}',
        ),
      );
      final result = await LibrarySyncWorker(
        operations: store,
        local: store,
        remote: gateway,
        clock: () => now,
      ).drainOnce(userId: createdUserId);

      expect(result.completed, 5);
      expect(result.retried, 0);
      expect(result.blocked, 0);
      expect(
        Sqflite.firstIntValue(await database.rawQuery(
          "SELECT COUNT(*) FROM sync_operations WHERE state = 'done'",
        )),
        5,
      );

      final localSnapshot = await store.getPhotoNoteSnapshot(
        userId: createdUserId,
        photoNoteId: capturedSnapshot.photoNote.id,
      );
      expect(localSnapshot, isNotNull);
      if (localSnapshot?.mediaAsset.remoteDisplayPath == null) {
        throw StateError('Worker did not persist the remote display path.');
      }
      expect(
          localSnapshot!.mediaAsset.remoteDisplayPath, uploadedPaths.display);

      final mediaRows = await owner
          .from('media_assets')
          .select()
          .eq('id', capturedSnapshot.mediaAsset.id);
      final scanRows = await owner
          .from('scan_runs')
          .select()
          .eq('id', capturedSnapshot.primaryScanRun!.id);
      final detectionRows = await owner
          .from('vocab_detections')
          .select()
          .eq('id', capturedSnapshot.detections.single.id);
      final annotationRows = await owner
          .from('vocab_annotations')
          .select()
          .eq('id', capturedSnapshot.annotations.single.id);
      final noteRows = await owner
          .from('photo_notes')
          .select()
          .eq('id', capturedSnapshot.photoNote.id);

      expect(mediaRows, hasLength(1));
      expect(scanRows, hasLength(1));
      expect(detectionRows, hasLength(1));
      expect(annotationRows, hasLength(1));
      expect(noteRows, hasLength(1));
      expect(
        mediaRows.single['content_hash_sha256'],
        capturedSnapshot.mediaAsset.contentHashSha256,
      );
      expect(
        scanRows.single['raw_response_json'],
        containsPair('e2e_marker', 'library-sync-staging'),
      );
      expect(
        scanRows.single['response_hash_sha256'],
        capturedSnapshot.primaryScanRun!.responseHashSha256,
      );
      expect(noteRows.single['image_path'], uploadedPaths.display);
      expect(
        mediaRows.single['model_input_object_path'],
        uploadedPaths.modelInput,
      );

      final downloaded =
          await owner.storage.from(_bucket).download(uploadedPaths.display);
      expect(downloaded, jpegBytes);
      final modelDownloaded =
          await owner.storage.from(_bucket).download(uploadedPaths.modelInput!);
      expect(modelDownloaded, jpegBytes);

      await receiverStore.saveLocalAccount(_account(createdUserId, now));
      final receiverPull = await LibraryCloudPullWorker(
        local: receiverStore,
        remote: gateway,
      ).pull(userId: createdUserId);
      expect(receiverPull.snapshots, 1);
      expect(receiverPull.deletions, 0);
      expect(receiverPull.hasMore, isFalse);
      final receiverSnapshot = await receiverStore.getPhotoNoteSnapshot(
        userId: createdUserId,
        photoNoteId: capturedSnapshot.photoNote.id,
      );
      expect(receiverSnapshot, isNotNull);
      expect(
        receiverSnapshot!.primaryScanRun!.rawResponseJson,
        containsPair('e2e_marker', 'library-sync-staging'),
      );
      expect(
          receiverSnapshot.mediaAsset.remoteDisplayPath, uploadedPaths.display);
      final receiverMediaFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}'
        '${receiverSnapshot.mediaAsset.displayRelativePath.replaceAll('/', Platform.pathSeparator)}',
      );
      expect(await receiverMediaFile.exists(), isFalse,
          reason: 'metadata pull must not download private image bytes');
      expect(
        Sqflite.firstIntValue(await receiverDatabase.rawQuery(
          'SELECT COUNT(*) FROM sync_operations',
        )),
        0,
        reason: 'a receiving device must not echo cloud rows to its outbox',
      );
      final receiverCursorBeforeDelete =
          await receiverStore.getLibraryPullCursor(userId: createdUserId);
      expect(receiverCursorBeforeDelete, greaterThan(0));

      final deletionRequestedAt = now.add(const Duration(minutes: 1));
      await store.requestPermanentDeletion(
        userId: createdUserId,
        photoNoteIds: [capturedSnapshot.photoNote.id],
        requestedAt: deletionRequestedAt,
      );
      final deletionService = LibraryPhotoNoteDeletionService(
        repository: store,
        mediaPurger: IoLibraryManagedMediaPurger(
          documentsDirectory: () async => temporaryDirectory,
        ),
      );
      final localPurge = await deletionService.maintain(
        userId: createdUserId,
        now: deletionRequestedAt,
      );
      expect(localPurge.localPurged, 1);
      expect(await displayFile.exists(), isFalse);
      expect(await modelFile.exists(), isFalse);
      expect(
        await store.getPhotoNoteSnapshot(
          userId: createdUserId,
          photoNoteId: capturedSnapshot.photoNote.id,
        ),
        isNull,
      );

      await store.saveLocalAccount(LocalAccount(
        userId: createdUserId,
        accountState: AccountState.active,
        cloudBackupEnabled: false,
        localPersonalizationEnabled: false,
        federatedContributionEnabled: false,
        createdAt: now,
        updatedAt: deletionRequestedAt,
      ));
      final remotePurge = await LibrarySyncWorker(
        operations: store,
        local: store,
        remote: gateway,
        clock: () => deletionRequestedAt,
      ).drainOnce(userId: createdUserId);
      expect(remotePurge.skippedForConsent, isTrue);
      expect(remotePurge.completed, 1);

      for (final table in const [
        'vocab_annotations',
        'vocab_detections',
        'photo_notes',
        'scan_runs',
        'media_assets',
      ]) {
        final remaining =
            await owner.from(table).select('id').eq('user_id', createdUserId);
        expect(remaining, isEmpty, reason: '$table survived privacy purge');
      }
      final remainingObjects = await owner.storage.from(_bucket).list(
            path: '$createdUserId/${capturedSnapshot.mediaAsset.id}',
          );
      expect(remainingObjects, isEmpty);

      final receiverDeletePull = await LibraryCloudPullWorker(
        local: receiverStore,
        remote: gateway,
      ).pull(userId: createdUserId);
      expect(receiverDeletePull.deletions, 1);
      expect(
        await receiverStore.getLibraryPullCursor(userId: createdUserId),
        greaterThan(receiverCursorBeforeDelete),
      );
      final receiverDeletionService = LibraryPhotoNoteDeletionService(
        repository: receiverStore,
        mediaPurger: IoLibraryManagedMediaPurger(
          documentsDirectory: () async => temporaryDirectory,
        ),
      );
      final receiverPurge = await receiverDeletionService.maintain(
        userId: createdUserId,
        now: deletionRequestedAt,
      );
      expect(receiverPurge.localPurged, 1);
      expect(
        await receiverStore.getPhotoNoteSnapshot(
          userId: createdUserId,
          photoNoteId: capturedSnapshot.photoNote.id,
        ),
        isNull,
      );

      await deletionService.maintain(
        userId: createdUserId,
        now: deletionRequestedAt,
      );
      expect(
        Sqflite.firstIntValue(await database.rawQuery(
          '''SELECT COUNT(*) FROM sync_operations
             WHERE operation_type = 'purge' ''',
        )),
        0,
      );
      expect(
        Sqflite.firstIntValue(await database.rawQuery(
          '''SELECT COUNT(*) FROM sync_tombstones
             WHERE entity_type = 'photo_note'
               AND remote_purge_completed = 1''',
        )),
        1,
      );
    },
    skip: enabled
        ? false
        : 'Run through tool/run_staging_library_sync_e2e.ps1 only.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

String _requiredEnvironment(String key) {
  final value = Platform.environment[key]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('Missing required live-test environment: $key');
  }
  return value;
}

LocalAccount _account(
  String userId,
  DateTime now, {
  bool cloudBackup = true,
}) =>
    LocalAccount(
      userId: userId,
      accountState: AccountState.active,
      cloudBackupEnabled: cloudBackup,
      localPersonalizationEnabled: false,
      federatedContributionEnabled: false,
      createdAt: now,
      updatedAt: now,
    );

PhotoNoteSnapshot _snapshot({
  required _Ids ids,
  required String userId,
  required DateTime now,
  required int byteSize,
  required String contentHashSha256,
}) {
  final mediaId = ids.next();
  final scanId = ids.next();
  final noteId = ids.next();
  final detectionId = ids.next();
  const rawResponse = {
    'e2e_marker': 'library-sync-staging',
    'words': [
      {'word': 'cup', 'meaning': 'cốc'},
    ],
  };
  return PhotoNoteSnapshot(
    mediaAsset: MediaAsset(
      id: mediaId,
      userId: userId,
      contentHashSha256: contentHashSha256,
      displayRelativePath: 'capy_scans/display.jpg',
      modelInputRelativePath: 'capy_scans/model.jpg',
      mimeType: 'image/jpeg',
      width: 1,
      height: 1,
      orientation: 0,
      byteSizeDisplay: byteSize,
      preprocessingVersion: 'staging-e2e-v1',
      captureSource: CaptureSource.camera,
      capturedAt: now,
      createdAt: now,
      syncStatus: SyncStatus.localOnly,
    ),
    primaryScanRun: ScanRun(
      id: scanId,
      userId: userId,
      mediaAssetId: mediaId,
      requestId: 'staging-e2e-$scanId',
      provider: 'e2e_fixture',
      modelName: 'no-model-call',
      promptVersion: 'staging-e2e-v1',
      responseSchemaVersion: 'scan-response-v1',
      preprocessingVersion: 'staging-e2e-v1',
      rawResponseJson: rawResponse,
      responseHashSha256:
          sha256.convert(utf8.encode(jsonEncode(rawResponse))).toString(),
      status: ScanRunStatus.succeeded,
      startedAt: now,
      completedAt: now,
    ),
    photoNote: PhotoNote(
      id: noteId,
      userId: userId,
      mediaAssetId: mediaId,
      primaryScanRunId: scanId,
      title: 'Staging E2E fixture',
      templateId: 'default-v1',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.localOnly,
    ),
    detections: [
      VocabDetection(
        id: detectionId,
        scanRunId: scanId,
        wordRaw: 'Cup',
        wordNormalized: 'cup',
        meaningVi: 'cốc',
        displayOrder: 0,
        createdAt: now,
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
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}

String _randomHex(Random random, int length) => List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();

final class _Ids {
  _Ids(this._random);

  final Random _random;

  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
