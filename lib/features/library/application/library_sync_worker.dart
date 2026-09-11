import '../domain/entities/library_enums.dart';
import '../domain/entities/sync_models.dart';
import '../domain/repositories/library_sync_source.dart';
import '../domain/repositories/sync_repository.dart';
import 'library_sync_gateway.dart';

typedef SyncClock = DateTime Function();

final class SyncDrainResult {
  const SyncDrainResult({
    required this.recovered,
    required this.completed,
    required this.retried,
    required this.blocked,
    required this.skippedForConsent,
  });

  final int recovered;
  final int completed;
  final int retried;
  final int blocked;
  final bool skippedForConsent;
}

/// Executes one bounded, dependency-aware pass over the local outbox.
final class LibrarySyncWorker {
  LibrarySyncWorker({
    required SyncRepository operations,
    required LibrarySyncSource local,
    required LibrarySyncGateway remote,
    SyncClock? clock,
    this.interruptedAfter = const Duration(minutes: 15),
  })  : _operations = operations,
        _local = local,
        _remote = remote,
        _clock = clock ?? (() => DateTime.now().toUtc()) {
    if (interruptedAfter <= Duration.zero) {
      throw ArgumentError.value(
        interruptedAfter,
        'interruptedAfter',
        'must be positive',
      );
    }
  }

  final SyncRepository _operations;
  final LibrarySyncSource _local;
  final LibrarySyncGateway _remote;
  final SyncClock _clock;
  final Duration interruptedAfter;

  Future<SyncDrainResult> drainOnce({
    required String userId,
    int limit = 100,
  }) async {
    if (limit <= 0 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 1000');
    }
    if (!await _local.isCloudBackupEnabled(userId: userId)) {
      final deleted =
          await _drainPendingDeletions(userId: userId, limit: limit);
      return SyncDrainResult(
        recovered: 0,
        completed: deleted,
        retried: 0,
        blocked: 0,
        skippedForConsent: true,
      );
    }

    final now = _clock().toUtc();
    final recovered = await _local.recoverInterruptedOperations(
      userId: userId,
      interruptedBefore: now.subtract(interruptedAfter),
      recoveredAt: now,
    );
    final authenticated = _remote.authenticatedUserId == userId;
    if (authenticated) {
      await _local.releaseAuthBlockedOperations(
        userId: userId,
        releasedAt: now,
      );
    }

    var completed = 0;
    var retried = 0;
    var blocked = 0;
    var processed = 0;
    var stoppedForConsent = false;

    drainLoop:
    while (processed < limit) {
      final ready = await _operations.getReadyOperations(
        userId: userId,
        now: now,
        limit: limit - processed,
      );
      if (ready.isEmpty) break;

      for (final operation in ready) {
        if (!await _local.isCloudBackupEnabled(userId: userId)) {
          stoppedForConsent = true;
          break drainLoop;
        }
        processed++;
        if (!authenticated) {
          await _operations.updateOperation(_withState(
            operation,
            state: SyncOperationState.blocked,
            updatedAt: now,
            lastErrorCode: 'auth_required',
          ));
          blocked++;
          continue;
        }

        final running = _withState(
          operation,
          state: SyncOperationState.running,
          attemptCount: operation.attemptCount + 1,
          updatedAt: now,
        );
        await _operations.updateOperation(running);
        try {
          await _execute(running);
          await _operations.updateOperation(_withState(
            running,
            state: SyncOperationState.done,
            updatedAt: now,
          ));
          completed++;
        } on LibrarySyncFailure catch (failure) {
          if (failure.disposition == SyncFailureDisposition.retry) {
            await _operations.updateOperation(_withState(
              running,
              state: SyncOperationState.retry,
              attemptCount: running.attemptCount,
              nextAttemptAt: now.add(_backoffFor(running.attemptCount)),
              lastErrorCode: failure.code,
              updatedAt: now,
            ));
            retried++;
          } else {
            await _operations.updateOperation(_withState(
              running,
              state: SyncOperationState.blocked,
              attemptCount: running.attemptCount,
              lastErrorCode: failure.code,
              updatedAt: now,
            ));
            blocked++;
          }
        } catch (_) {
          await _operations.updateOperation(_withState(
            running,
            state: SyncOperationState.retry,
            attemptCount: running.attemptCount,
            nextAttemptAt: now.add(_backoffFor(running.attemptCount)),
            lastErrorCode: 'transient_unknown',
            updatedAt: now,
          ));
          retried++;
        }
      }
    }

    return SyncDrainResult(
      recovered: recovered,
      completed: completed,
      retried: retried,
      blocked: blocked,
      skippedForConsent: stoppedForConsent,
    );
  }

  /// Deletion is a privacy obligation, not a Cloud Backup upload. It remains
  /// allowed after backup consent is disabled and is retried on app resume.
  Future<int> _drainPendingDeletions({
    required String userId,
    required int limit,
  }) async {
    if (_remote.authenticatedUserId != userId) return 0;
    var completed = 0;
    final tombstones = await _operations.getPendingTombstones(
      userId: userId,
      limit: limit,
    );
    for (final tombstone in tombstones) {
      if (tombstone.entityType != SyncEntityType.photoNote) continue;
      final target = await _local.getPhotoNotePurgeTarget(
        userId: userId,
        photoNoteId: tombstone.entityId,
      );
      if (target == null) continue;
      try {
        await _remote.purgePhotoNote(target);
        await _local.markTombstoneRemotePurgeCompleted(
          userId: userId,
          entityType: tombstone.entityType,
          entityId: tombstone.entityId,
        );
        completed++;
      } catch (_) {
        // Keep the tombstone pending. Startup/resume provides bounded retry
        // without re-enabling ordinary upload work after consent is off.
      }
    }
    return completed;
  }

  Future<void> _execute(SyncOperation operation) async {
    switch (operation.entityType) {
      case SyncEntityType.mediaAsset:
        if (operation.operationType != SyncOperationType.upload) {
          throw const LibrarySyncFailure.contract(
            'unsupported_media_operation',
          );
        }
        final asset = await _local.getMediaAssetForSync(
          userId: operation.userId,
          mediaAssetId: operation.entityId,
        );
        if (asset == null) {
          throw const LibrarySyncFailure.contract('local_entity_missing');
        }
        final paths = await _remote.uploadMedia(asset);
        await _remote.upsertMediaAsset(asset, paths);
        await _local.markMediaAssetSynced(
          userId: operation.userId,
          mediaAssetId: operation.entityId,
          remoteOriginalPath: paths.original,
          remoteDisplayPath: paths.display,
        );
        return;
      case SyncEntityType.scanRun:
        _requireUpsert(operation);
        final scan = await _local.getScanRunForSync(
          userId: operation.userId,
          scanRunId: operation.entityId,
        );
        if (scan == null) {
          throw const LibrarySyncFailure.contract('local_entity_missing');
        }
        await _remote.upsertScanRun(scan);
        return;
      case SyncEntityType.vocabDetection:
        _requireUpsert(operation);
        final detection = await _local.getVocabDetectionForSync(
          userId: operation.userId,
          detectionId: operation.entityId,
        );
        if (detection == null) {
          throw const LibrarySyncFailure.contract('local_entity_missing');
        }
        await _remote.upsertVocabDetection(
          userId: operation.userId,
          detection: detection,
        );
        return;
      case SyncEntityType.vocabAnnotation:
        _requireUpsert(operation, allowSoftDelete: true);
        final annotation = await _local.getVocabAnnotationForSync(
          userId: operation.userId,
          annotationId: operation.entityId,
        );
        if (annotation == null) {
          throw const LibrarySyncFailure.contract('local_entity_missing');
        }
        await _remote.upsertVocabAnnotation(annotation);
        return;
      case SyncEntityType.photoNote:
        if (operation.operationType == SyncOperationType.purge) {
          final target = await _local.getPhotoNotePurgeTarget(
            userId: operation.userId,
            photoNoteId: operation.entityId,
          );
          if (target == null) {
            throw const LibrarySyncFailure.contract('purge_target_missing');
          }
          await _remote.purgePhotoNote(target);
          await _local.markTombstoneRemotePurgeCompleted(
            userId: operation.userId,
            entityType: operation.entityType,
            entityId: operation.entityId,
          );
          return;
        }
        _requireUpsert(operation, allowSoftDelete: true);
        final note = await _local.getPhotoNoteForSync(
          userId: operation.userId,
          photoNoteId: operation.entityId,
        );
        if (note == null) {
          throw const LibrarySyncFailure.contract('local_entity_missing');
        }
        final media = await _local.getMediaAssetForSync(
          userId: operation.userId,
          mediaAssetId: note.mediaAssetId,
        );
        final displayPath = media?.remoteDisplayPath;
        if (displayPath == null) {
          throw const LibrarySyncFailure.contract('media_not_uploaded');
        }
        await _remote.upsertPhotoNote(
          photoNote: note,
          displayObjectPath: displayPath,
        );
        await _local.markPhotoNoteSynced(
          userId: operation.userId,
          photoNoteId: operation.entityId,
        );
        return;
      case SyncEntityType.album:
      case SyncEntityType.albumPhotoNote:
      case SyncEntityType.learningEvent:
      case SyncEntityType.srsProgress:
        throw const LibrarySyncFailure.contract(
          'cloud_entity_contract_missing',
        );
    }
  }

  static void _requireUpsert(
    SyncOperation operation, {
    bool allowSoftDelete = false,
  }) {
    final supported = operation.operationType == SyncOperationType.create ||
        operation.operationType == SyncOperationType.update ||
        allowSoftDelete &&
            operation.operationType == SyncOperationType.softDelete;
    if (!supported) {
      throw const LibrarySyncFailure.contract('unsupported_operation');
    }
  }

  static Duration _backoffFor(int attemptCount) {
    var seconds = 5;
    for (var attempt = 1;
        attempt < attemptCount && seconds < 21600;
        attempt++) {
      seconds *= 2;
    }
    return Duration(seconds: seconds.clamp(5, 21600));
  }
}

SyncOperation _withState(
  SyncOperation operation, {
  required SyncOperationState state,
  required DateTime updatedAt,
  int? attemptCount,
  DateTime? nextAttemptAt,
  String? lastErrorCode,
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
    attemptCount: attemptCount ?? operation.attemptCount,
    nextAttemptAt: nextAttemptAt,
    lastErrorCode: lastErrorCode,
    createdAt: operation.createdAt,
    updatedAt: updatedAt,
  );
}
