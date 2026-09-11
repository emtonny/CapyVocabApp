import '../domain/repositories/library_cloud_pull_store.dart';
import 'library_cloud_pull_gateway.dart';
import 'library_sync_gateway.dart';

final class LibraryCloudPullResult {
  const LibraryCloudPullResult({
    required this.batches,
    required this.snapshots,
    required this.deletions,
    required this.hasMore,
    required this.skippedForConsent,
  });

  final int batches;
  final int snapshots;
  final int deletions;
  final bool hasMore;
  final bool skippedForConsent;
}

/// Pulls bounded cloud metadata into SQLite. Binary media is never requested.
final class LibraryCloudPullWorker {
  const LibraryCloudPullWorker({
    required LibraryCloudPullStore local,
    required LibraryCloudPullGateway remote,
  })  : _local = local,
        _remote = remote;

  final LibraryCloudPullStore _local;
  final LibraryCloudPullGateway _remote;

  Future<LibraryCloudPullResult> pull({
    required String userId,
    int batchLimit = 100,
    int maxBatches = 5,
  }) async {
    if (batchLimit <= 0 || batchLimit > 500) {
      throw ArgumentError.value(
        batchLimit,
        'batchLimit',
        'must be between 1 and 500',
      );
    }
    if (maxBatches <= 0 || maxBatches > 20) {
      throw ArgumentError.value(
        maxBatches,
        'maxBatches',
        'must be between 1 and 20',
      );
    }
    if (!await _local.isCloudBackupEnabled(userId: userId)) {
      return const LibraryCloudPullResult(
        batches: 0,
        snapshots: 0,
        deletions: 0,
        hasMore: false,
        skippedForConsent: true,
      );
    }
    if (_remote.authenticatedUserId != userId) {
      throw const LibrarySyncFailure.auth('pull_auth_required');
    }

    var batches = 0;
    var snapshots = 0;
    var deletions = 0;
    var hasMore = false;
    var cursor = await _local.getLibraryPullCursor(userId: userId);
    while (batches < maxBatches) {
      final delta = await _remote.pullLibraryDelta(
        userId: userId,
        afterCursor: cursor,
        limit: batchLimit,
      );
      if (delta.userId != userId || delta.previousCursor != cursor) {
        throw const LibrarySyncFailure.contract('invalid_pull_cursor');
      }
      await _local.applyLibraryCloudDelta(delta);
      batches++;
      snapshots += delta.snapshots.length;
      deletions += delta.deletions.length;
      hasMore = delta.hasMore;
      if (!hasMore) break;
      if (delta.nextCursor == cursor) {
        throw const LibrarySyncFailure.contract('pull_cursor_not_advanced');
      }
      cursor = delta.nextCursor;
    }
    return LibraryCloudPullResult(
      batches: batches,
      snapshots: snapshots,
      deletions: deletions,
      hasMore: hasMore,
      skippedForConsent: false,
    );
  }
}
