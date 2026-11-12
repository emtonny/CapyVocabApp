import 'lesson_completion_sync_gateway.dart';
import 'lesson_completion_sync_store.dart';

typedef LessonSyncClock = DateTime Function();

final class LessonSyncDrainResult {
  const LessonSyncDrainResult({
    required this.recovered,
    required this.synced,
    required this.retried,
    required this.blocked,
  });

  final int recovered;
  final int synced;
  final int retried;
  final int blocked;
}

final class LessonCompletionSyncWorker {
  LessonCompletionSyncWorker({
    required LessonCompletionSyncStore store,
    required LessonCompletionSyncGateway gateway,
    LessonSyncClock? clock,
    this.interruptedAfter = const Duration(minutes: 15),
  })  : _store = store,
        _gateway = gateway,
        _clock = clock ?? (() => DateTime.now().toUtc()) {
    if (interruptedAfter <= Duration.zero) {
      throw ArgumentError.value(
        interruptedAfter,
        'interruptedAfter',
        'must be positive',
      );
    }
  }

  final LessonCompletionSyncStore _store;
  final LessonCompletionSyncGateway _gateway;
  final LessonSyncClock _clock;
  final Duration interruptedAfter;

  Future<LessonSyncDrainResult> drainOnce({
    required String userId,
    int limit = 20,
  }) async {
    if (limit <= 0 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }
    final now = _clock().toUtc();
    final recovered = await _store.recoverInterruptedSyncs(
      userId: userId,
      interruptedBefore: now.subtract(interruptedAfter),
      now: now,
    );
    if (_gateway.authenticatedUserId != userId) {
      return LessonSyncDrainResult(
        recovered: recovered,
        synced: 0,
        retried: 0,
        blocked: 0,
      );
    }

    final payloads = await _store.readySyncPayloads(
      userId: userId,
      now: now,
      limit: limit,
    );
    var synced = 0;
    var retried = 0;
    var blocked = 0;
    for (final payload in payloads) {
      final running = await _store.markSyncing(
        userId: userId,
        resultId: payload.result.id,
        now: now,
      );
      if (running == null) continue;
      try {
        final receipt = await _gateway.sync(payload);
        if (receipt.resultId != payload.result.id || receipt.userId != userId) {
          throw const LessonSyncFailure.blocked('receipt_owner_mismatch');
        }
        await _store.markSynced(
          userId: userId,
          resultId: payload.result.id,
          receipt: receipt,
          now: now,
        );
        synced++;
      } on LessonSyncFailure catch (failure) {
        final canRetry =
            failure.disposition == LessonSyncFailureDisposition.retry;
        await _store.markSyncFailed(
          userId: userId,
          resultId: payload.result.id,
          errorCode: failure.code,
          retryAt:
              canRetry ? now.add(_backoffFor(running.syncAttemptCount)) : null,
          now: now,
        );
        if (canRetry) {
          retried++;
        } else {
          blocked++;
        }
      } catch (_) {
        await _store.markSyncFailed(
          userId: userId,
          resultId: payload.result.id,
          errorCode: 'transient_unknown',
          retryAt: now.add(_backoffFor(running.syncAttemptCount)),
          now: now,
        );
        retried++;
      }
    }
    return LessonSyncDrainResult(
      recovered: recovered,
      synced: synced,
      retried: retried,
      blocked: blocked,
    );
  }

  static Duration _backoffFor(int attemptCount) {
    var seconds = 5;
    for (var attempt = 1;
        attempt < attemptCount && seconds < 21600;
        attempt++) {
      seconds *= 2;
    }
    return Duration(seconds: seconds.clamp(5, 21600));
  }
}
