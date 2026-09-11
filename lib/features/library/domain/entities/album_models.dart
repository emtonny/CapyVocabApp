import 'domain_validation.dart';
import 'library_enums.dart';

final class Album {
  Album({
    required String id,
    required String userId,
    required String name,
    required String icon,
    required this.isFavorite,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.syncStatus,
    DateTime? deletedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        name = requireNonEmpty(name, 'name'),
        icon = requireNonEmpty(icon, 'icon'),
        createdAt = requireUtc(createdAt, 'createdAt'),
        updatedAt = requireUtc(updatedAt, 'updatedAt'),
        deletedAt = requireNullableUtc(deletedAt, 'deletedAt') {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt');
    }
  }

  final String id;
  final String userId;
  final String name;
  final String icon;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  bool get isDeleted => deletedAt != null;
}

final class AlbumPhotoNote {
  AlbumPhotoNote({
    required String albumId,
    required String photoNoteId,
    required DateTime addedAt,
    required String operationId,
    DateTime? removedAt,
  })  : albumId = requireUuid(albumId, 'albumId'),
        photoNoteId = requireUuid(photoNoteId, 'photoNoteId'),
        addedAt = requireUtc(addedAt, 'addedAt'),
        operationId = requireUuid(operationId, 'operationId'),
        removedAt = requireNullableUtc(removedAt, 'removedAt') {
    if (this.removedAt?.isBefore(this.addedAt) == true) {
      throw ArgumentError('removedAt must not be before addedAt');
    }
  }

  final String albumId;
  final String photoNoteId;
  final DateTime addedAt;
  final DateTime? removedAt;
  final String operationId;

  bool get isActive => removedAt == null;
}
