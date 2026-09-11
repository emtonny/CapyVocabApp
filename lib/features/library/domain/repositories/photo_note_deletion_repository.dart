import '../entities/photo_note_purge_target.dart';

abstract interface class PhotoNoteDeletionRepository {
  /// Promotes soft-deleted notes whose Trash deadline has passed to permanent
  /// deletion requests. Returns the number newly promoted.
  Future<int> requestExpiredPhotoNoteDeletions({
    required String userId,
    required DateTime now,
    required Duration retention,
  });

  Future<List<PhotoNotePurgeTarget>> getPhotoNotePurgeTargets({
    required String userId,
    int limit = 100,
  });

  /// Removes source content after its app-private files have been erased.
  /// The non-content tombstone remains as the deletion receipt.
  Future<bool> finalizePhotoNoteLocalPurge(PhotoNotePurgeTarget target);
}
