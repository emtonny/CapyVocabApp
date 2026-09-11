import '../domain/repositories/photo_note_deletion_repository.dart';

const photoNoteTrashRetention = Duration(days: 30);

abstract interface class LibraryManagedMediaPurger {
  /// Idempotently deletes only validated app-private Library media paths.
  Future<void> deleteAll(Iterable<String> relativePaths);
}

final class PhotoNoteDeletionMaintenanceResult {
  const PhotoNoteDeletionMaintenanceResult({
    required this.promoted,
    required this.localPurged,
  });

  final int promoted;
  final int localPurged;
}

/// Performs the local half of permanent deletion without requiring network.
/// Cloud deletion remains an authenticated, retryable outbox responsibility.
final class LibraryPhotoNoteDeletionService {
  const LibraryPhotoNoteDeletionService({
    required PhotoNoteDeletionRepository repository,
    required LibraryManagedMediaPurger mediaPurger,
  })  : _repository = repository,
        _mediaPurger = mediaPurger;

  final PhotoNoteDeletionRepository _repository;
  final LibraryManagedMediaPurger _mediaPurger;

  Future<PhotoNoteDeletionMaintenanceResult> maintain({
    required String userId,
    required DateTime now,
  }) async {
    final promoted = await _repository.requestExpiredPhotoNoteDeletions(
      userId: userId,
      now: now.toUtc(),
      retention: photoNoteTrashRetention,
    );
    var localPurged = 0;
    for (final target in await _repository.getPhotoNotePurgeTargets(
      userId: userId,
    )) {
      if (!target.localContentPresent) {
        await _repository.finalizePhotoNoteLocalPurge(target);
        continue;
      }
      await _mediaPurger.deleteAll(target.localRelativePaths);
      if (await _repository.finalizePhotoNoteLocalPurge(target)) {
        localPurged++;
      }
    }
    return PhotoNoteDeletionMaintenanceResult(
      promoted: promoted,
      localPurged: localPurged,
    );
  }
}
