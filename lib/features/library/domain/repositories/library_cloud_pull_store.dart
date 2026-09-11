import '../entities/library_cloud_delta.dart';

abstract interface class LibraryCloudPullStore {
  Future<bool> isCloudBackupEnabled({required String userId});

  Future<int> getLibraryPullCursor({required String userId});

  /// Applies metadata and the cursor in one SQLite transaction.
  ///
  /// Implementations must not create upload outbox rows or download media.
  Future<void> applyLibraryCloudDelta(LibraryCloudDelta delta);
}
