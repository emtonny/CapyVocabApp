import 'dart:collection';

import 'domain_validation.dart';
import 'photo_note_snapshot.dart';

/// One owner-scoped, cursor-ordered batch read from the cloud change feed.
final class LibraryCloudDelta {
  LibraryCloudDelta({
    required String userId,
    required int previousCursor,
    required int nextCursor,
    required this.hasMore,
    required Iterable<PhotoNoteSnapshot> snapshots,
    required Iterable<LibraryCloudDeletion> deletions,
  })  : userId = requireUuid(userId, 'userId'),
        previousCursor = _nonNegative(previousCursor, 'previousCursor'),
        nextCursor = _nonNegative(nextCursor, 'nextCursor'),
        snapshots = List<PhotoNoteSnapshot>.unmodifiable(snapshots),
        deletions = List<LibraryCloudDeletion>.unmodifiable(deletions) {
    if (this.nextCursor < this.previousCursor) {
      throw ArgumentError('nextCursor must not move backwards');
    }
    if (this.snapshots.any((item) => item.photoNote.userId != this.userId) ||
        this.deletions.any((item) => item.userId != this.userId)) {
      throw ArgumentError('every cloud change must belong to userId');
    }
    final noteIds = this.snapshots.map((item) => item.photoNote.id).toList();
    if (noteIds.toSet().length != noteIds.length) {
      throw ArgumentError('snapshots must not contain duplicate Photo Notes');
    }
  }

  final String userId;
  final int previousCursor;
  final int nextCursor;
  final bool hasMore;
  final List<PhotoNoteSnapshot> snapshots;
  final List<LibraryCloudDeletion> deletions;

  UnmodifiableSetView<String> get deletedPhotoNoteIds =>
      UnmodifiableSetView(deletions.map((item) => item.photoNoteId).toSet());
}

final class LibraryCloudDeletion {
  LibraryCloudDeletion({
    required String userId,
    required String photoNoteId,
    required int sequence,
    required DateTime deletedAt,
  })  : userId = requireUuid(userId, 'userId'),
        photoNoteId = requireUuid(photoNoteId, 'photoNoteId'),
        sequence = _positive(sequence, 'sequence'),
        deletedAt = requireUtc(deletedAt, 'deletedAt');

  final String userId;
  final String photoNoteId;
  final int sequence;
  final DateTime deletedAt;
}

int _nonNegative(int value, String fieldName) {
  if (value < 0) {
    throw ArgumentError.value(value, fieldName, 'must not be negative');
  }
  return value;
}

int _positive(int value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError.value(value, fieldName, 'must be positive');
  }
  return value;
}
