import '../domain/entities/media_asset.dart';
import '../domain/entities/photo_note_purge_target.dart';
import '../domain/entities/photo_note.dart';
import '../domain/entities/scan_models.dart';
import 'library_cloud_pull_gateway.dart';

enum SyncFailureDisposition { retry, blockedAuth, blockedContract }

final class LibrarySyncFailure implements Exception {
  const LibrarySyncFailure({required this.code, required this.disposition});

  const LibrarySyncFailure.retry(String code)
      : this(code: code, disposition: SyncFailureDisposition.retry);

  const LibrarySyncFailure.auth(String code)
      : this(code: code, disposition: SyncFailureDisposition.blockedAuth);

  const LibrarySyncFailure.contract(String code)
      : this(code: code, disposition: SyncFailureDisposition.blockedContract);

  final String code;
  final SyncFailureDisposition disposition;

  @override
  String toString() => 'LibrarySyncFailure($code, $disposition)';
}

final class MediaRemotePaths {
  const MediaRemotePaths({
    required this.display,
    this.original,
    this.modelInput,
  });

  final String? original;
  final String display;
  final String? modelInput;
}

/// Authenticated remote boundary used by the outbox worker.
///
/// Implementations must use idempotent upserts and deterministic object keys.
abstract interface class LibrarySyncGateway {
  String? get authenticatedUserId;

  Future<MediaRemotePaths> uploadMedia(MediaAsset asset);

  Future<void> upsertMediaAsset(
    MediaAsset asset,
    MediaRemotePaths remotePaths,
  );

  Future<void> upsertScanRun(ScanRun scanRun);

  Future<void> upsertVocabDetection({
    required String userId,
    required VocabDetection detection,
  });

  Future<void> upsertVocabAnnotation(VocabAnnotation annotation);

  Future<void> upsertPhotoNote({
    required PhotoNote photoNote,
    required String displayObjectPath,
  });

  Future<void> purgePhotoNote(PhotoNotePurgeTarget target);
}

/// Native runtime gateway supports both outbox upload and cursor-based pull.
abstract interface class LibraryRuntimeGateway
    implements LibrarySyncGateway, LibraryCloudPullGateway {}
