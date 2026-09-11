import '../entities/domain_validation.dart';
import '../entities/library_enums.dart';
import '../entities/media_asset.dart';
import '../entities/photo_note.dart';
import '../entities/photo_note_snapshot.dart';

final class PhotoNoteQuery {
  PhotoNoteQuery({
    required String userId,
    this.visibility = PhotoNoteVisibility.active,
    String? albumId,
    DateTime? capturedFromInclusive,
    DateTime? capturedToExclusive,
    this.limit = 100,
  })  : userId = requireUuid(userId, 'userId'),
        albumId = albumId == null ? null : requireUuid(albumId, 'albumId'),
        capturedFromInclusive = requireNullableUtc(
          capturedFromInclusive,
          'capturedFromInclusive',
        ),
        capturedToExclusive = requireNullableUtc(
          capturedToExclusive,
          'capturedToExclusive',
        ) {
    if (limit <= 0 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 500');
    }
    if (this.capturedFromInclusive != null &&
        this.capturedToExclusive != null &&
        !this.capturedFromInclusive!.isBefore(this.capturedToExclusive!)) {
      throw ArgumentError(
          'capturedFromInclusive must be before capturedToExclusive');
    }
  }

  final String userId;
  final PhotoNoteVisibility visibility;
  final String? albumId;
  final DateTime? capturedFromInclusive;
  final DateTime? capturedToExclusive;
  final int limit;
}

final class LibraryStorageSummary {
  const LibraryStorageSummary({
    required this.activeCount,
    required this.trashCount,
    required this.localMediaBytes,
    required this.localMediaCount,
    required this.cloudOnlyMediaCount,
    required this.missingMediaCount,
  });

  final int activeCount;
  final int trashCount;
  final int localMediaBytes;
  final int localMediaCount;
  final int cloudOnlyMediaCount;
  final int missingMediaCount;

  int get totalMediaCount =>
      localMediaCount + cloudOnlyMediaCount + missingMediaCount;
}

abstract interface class LibraryRepository {
  Stream<List<PhotoNote>> watchPhotoNotes(PhotoNoteQuery query);

  Stream<LibraryStorageSummary> watchStorageSummary({required String userId});

  /// Lists distinct media still retained by an active or trashed Photo Note.
  Future<List<MediaAsset>> getStorageMediaAssets({required String userId});

  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  });

  /// Persists the local aggregate and its outbox operations atomically.
  Future<void> saveCapturedPhotoNote(PhotoNoteSnapshot snapshot);

  /// Marks notes as soft-deleted and records delete operations atomically.
  Future<void> movePhotoNotesToTrash({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime deletedAt,
  });

  /// Restores notes that have not yet been purged and records sync operations.
  Future<void> restorePhotoNotes({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime restoredAt,
  });

  /// Creates permanent-delete tombstones; physical cleanup is implementation
  /// work performed only after lineage and remote purge requirements are met.
  Future<void> requestPermanentDeletion({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime requestedAt,
  });
}
