import '../domain/lesson_session.dart';
import 'lesson_completion_sync_gateway.dart';

abstract interface class LessonCompletionSyncStore {
  Stream<void> watchChanges(String userId);

  Future<int> outstandingSyncCount(String userId);

  Future<DateTime?> nextSyncAttemptAt(String userId);

  Future<List<LessonCompletionSyncPayload>> readySyncPayloads({
    required String userId,
    required DateTime now,
    int limit,
  });

  Future<LessonCompletionResult?> markSyncing({
    required String userId,
    required String resultId,
    required DateTime now,
  });

  Future<void> markSynced({
    required String userId,
    required String resultId,
    required LessonCompletionReceipt receipt,
    required DateTime now,
  });

  Future<void> markSyncFailed({
    required String userId,
    required String resultId,
    required String errorCode,
    required DateTime? retryAt,
    required DateTime now,
  });

  Future<int> recoverInterruptedSyncs({
    required String userId,
    required DateTime interruptedBefore,
    required DateTime now,
  });
}
