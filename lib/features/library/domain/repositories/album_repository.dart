import '../entities/album_models.dart';

abstract interface class AlbumRepository {
  Stream<List<Album>> watchAlbums({
    required String userId,
    bool includeDeleted = false,
  });

  Stream<List<AlbumPhotoNote>> watchMemberships({
    required String userId,
    required String albumId,
  });

  Future<void> saveAlbum(Album album);

  Future<void> setFavorite({
    required String userId,
    required String albumId,
    required bool isFavorite,
    required DateTime updatedAt,
  });

  Future<void> addPhotoNotes({
    required String userId,
    required String albumId,
    required Iterable<String> photoNoteIds,
    required DateTime addedAt,
    required String operationId,
  });

  Future<void> removePhotoNotes({
    required String userId,
    required String albumId,
    required Iterable<String> photoNoteIds,
    required DateTime removedAt,
    required String operationId,
  });

  /// Deletes only the album and memberships, never the contained Photo Notes.
  Future<void> deleteAlbums({
    required String userId,
    required Iterable<String> albumIds,
    required DateTime deletedAt,
  });
}
