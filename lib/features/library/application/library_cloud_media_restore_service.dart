import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../domain/entities/domain_validation.dart';
import '../domain/entities/media_asset.dart';

abstract interface class LibraryCloudMediaSource {
  String? get authenticatedUserId;

  Future<Uint8List> downloadPrivateMedia(String objectPath);
}

abstract interface class LibraryLocalMediaWriter {
  Future<void> writeAtomically({
    required String relativePath,
    required Uint8List bytes,
  });
}

final class LibraryCloudMediaRestoreException implements Exception {
  const LibraryCloudMediaRestoreException(this.code, {this.cause});

  final String code;
  final Object? cause;

  @override
  String toString() => 'LibraryCloudMediaRestoreException: $code';
}

/// Restores one explicitly requested display rendition into app-private media.
///
/// Callers own the user gesture. This service must never be scheduled from
/// startup, reconnect, Library list rendering or detail rendering.
final class LibraryCloudMediaRestoreService {
  const LibraryCloudMediaRestoreService({
    required LibraryCloudMediaSource remote,
    required LibraryLocalMediaWriter local,
  })  : _remote = remote,
        _local = local;

  final LibraryCloudMediaSource _remote;
  final LibraryLocalMediaWriter _local;

  Future<void> restoreDisplay(MediaAsset asset) async {
    final authenticatedUserId = _remote.authenticatedUserId;
    if (authenticatedUserId == null || authenticatedUserId != asset.userId) {
      throw const LibraryCloudMediaRestoreException('auth_owner_mismatch');
    }
    final objectPath = asset.remoteDisplayPath;
    if (objectPath == null) {
      throw const LibraryCloudMediaRestoreException(
        'remote_display_path_missing',
      );
    }
    final safeObjectPath = requireRelativePath(
      objectPath,
      'remoteDisplayPath',
    );
    if (!safeObjectPath.startsWith('${asset.userId}/')) {
      throw const LibraryCloudMediaRestoreException(
        'remote_object_owner_mismatch',
      );
    }

    try {
      final bytes = await _remote.downloadPrivateMedia(safeObjectPath);
      if (bytes.isEmpty) {
        throw const LibraryCloudMediaRestoreException('empty_cloud_media');
      }
      if (bytes.length != asset.byteSizeDisplay) {
        throw const LibraryCloudMediaRestoreException(
          'cloud_media_size_mismatch',
        );
      }
      if (sha256.convert(bytes).toString() != asset.contentHashSha256) {
        throw const LibraryCloudMediaRestoreException(
          'cloud_media_hash_mismatch',
        );
      }
      await _local.writeAtomically(
        relativePath: asset.displayRelativePath,
        bytes: bytes,
      );
    } on LibraryCloudMediaRestoreException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LibraryCloudMediaRestoreException(
          'cloud_media_restore_failed',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
