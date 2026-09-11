import '../entities/media_asset.dart';
import '../entities/library_enums.dart';
import '../entities/photo_note.dart';
import '../entities/photo_note_purge_target.dart';
import '../entities/scan_models.dart';

/// Local, owner-scoped data required by the Library outbox worker.
///
/// The worker reads the latest SQLite snapshot so outbox rows created by older
/// app versions (whose payload was empty) remain executable.
abstract interface class LibrarySyncSource {
  Future<bool> isCloudBackupEnabled({required String userId});

  /// Moves operations left in `running` by an interrupted app session back to
  /// `retry`. Returns the number of recovered rows.
  Future<int> recoverInterruptedOperations({
    required String userId,
    required DateTime interruptedBefore,
    required DateTime recoveredAt,
  });

  /// Releases operations blocked only because the authenticated session was
  /// absent. Contract failures remain blocked for manual repair.
  Future<int> releaseAuthBlockedOperations({
    required String userId,
    required DateTime releasedAt,
  });

  Future<MediaAsset?> getMediaAssetForSync({
    required String userId,
    required String mediaAssetId,
  });

  Future<ScanRun?> getScanRunForSync({
    required String userId,
    required String scanRunId,
  });

  Future<VocabDetection?> getVocabDetectionForSync({
    required String userId,
    required String detectionId,
  });

  Future<VocabAnnotation?> getVocabAnnotationForSync({
    required String userId,
    required String annotationId,
  });

  Future<PhotoNote?> getPhotoNoteForSync({
    required String userId,
    required String photoNoteId,
  });

  Future<PhotoNotePurgeTarget?> getPhotoNotePurgeTarget({
    required String userId,
    required String photoNoteId,
  });

  Future<void> markMediaAssetSynced({
    required String userId,
    required String mediaAssetId,
    String? remoteOriginalPath,
    required String remoteDisplayPath,
  });

  Future<void> markPhotoNoteSynced({
    required String userId,
    required String photoNoteId,
  });

  Future<void> markTombstoneRemotePurgeCompleted({
    required String userId,
    required SyncEntityType entityType,
    required String entityId,
  });
}
