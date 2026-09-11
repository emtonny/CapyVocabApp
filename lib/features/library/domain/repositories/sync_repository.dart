import '../entities/library_enums.dart';
import '../entities/sync_models.dart';

abstract interface class SyncRepository {
  Future<void> enqueue(SyncOperation operation);

  Future<List<SyncOperation>> getReadyOperations({
    required String userId,
    required DateTime now,
    int limit = 100,
  });

  Future<void> updateOperation(SyncOperation operation);

  /// Earliest delayed retry for scheduling the next worker wake-up.
  Future<DateTime?> getNextRetryAt({required String userId});

  Stream<int> watchOperationCount({
    required String userId,
    Set<SyncOperationState> states = const {
      SyncOperationState.pending,
      SyncOperationState.retry,
    },
  });

  Stream<int> watchPendingPurgeCount({required String userId});

  Future<void> saveTombstone(SyncTombstone tombstone);

  Future<List<SyncTombstone>> getPendingTombstones({
    required String userId,
    int limit = 100,
  });
}
