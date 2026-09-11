import 'domain_validation.dart';

/// Owner-scoped data required to permanently erase one Photo Note aggregate.
///
/// The target is persisted in a purge outbox payload before local source rows
/// are removed, so an offline deletion can still finish on Cloud Backup later.
final class PhotoNotePurgeTarget {
  PhotoNotePurgeTarget({
    required String userId,
    required String photoNoteId,
    required String mediaAssetId,
    required Iterable<String> localRelativePaths,
    required Iterable<String> remoteObjectPaths,
    required this.deleteMedia,
    required this.remotePurgeCompleted,
    required this.localContentPresent,
  })  : userId = requireUuid(userId, 'userId'),
        photoNoteId = requireUuid(photoNoteId, 'photoNoteId'),
        mediaAssetId = requireUuid(mediaAssetId, 'mediaAssetId'),
        localRelativePaths = List.unmodifiable(
          localRelativePaths
              .map((path) => requireRelativePath(path, 'localRelativePaths'))
              .toSet(),
        ),
        remoteObjectPaths = List.unmodifiable(
          remoteObjectPaths
              .map((path) => requireRelativePath(path, 'remoteObjectPaths'))
              .toSet(),
        );

  final String userId;
  final String photoNoteId;
  final String mediaAssetId;
  final List<String> localRelativePaths;
  final List<String> remoteObjectPaths;
  final bool deleteMedia;
  final bool remotePurgeCompleted;
  final bool localContentPresent;

  Map<String, Object?> toSyncPayload() => {
        'media_asset_id': mediaAssetId,
        'local_relative_paths': localRelativePaths,
        'remote_object_paths': remoteObjectPaths,
        'delete_media': deleteMedia,
      };

  factory PhotoNotePurgeTarget.fromSyncPayload({
    required String userId,
    required String photoNoteId,
    required Map<String, Object?> payload,
    required bool remotePurgeCompleted,
    required bool localContentPresent,
  }) {
    final mediaAssetId = payload['media_asset_id'];
    if (mediaAssetId is! String) {
      throw const FormatException('purge payload has no media_asset_id');
    }
    return PhotoNotePurgeTarget(
      userId: userId,
      photoNoteId: photoNoteId,
      mediaAssetId: mediaAssetId,
      localRelativePaths: _stringList(
        payload['local_relative_paths'],
        'local_relative_paths',
      ),
      remoteObjectPaths: _stringList(
        payload['remote_object_paths'],
        'remote_object_paths',
      ),
      deleteMedia: payload['delete_media'] is bool
          ? payload['delete_media']! as bool
          : true,
      remotePurgeCompleted: remotePurgeCompleted,
      localContentPresent: localContentPresent,
    );
  }
}

Iterable<String> _stringList(Object? value, String fieldName) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('purge payload has invalid $fieldName');
  }
  return value.cast<String>();
}
