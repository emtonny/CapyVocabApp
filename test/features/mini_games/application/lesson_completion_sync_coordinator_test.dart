import 'dart:async';

import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_coordinator.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_gateway.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_store.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_completion_sync_worker.dart';
import 'package:capy_vocab/features/mini_games/domain/lesson_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drains on sign-in and on a new local completion', () async {
    final store = _FakeStore();
    var drains = 0;
    final coordinator = LessonCompletionSyncCoordinator(
      store: store,
      drain: ({required userId, limit = 20}) async {
        drains++;
        return const LessonSyncDrainResult(
          recovered: 0,
          synced: 1,
          retried: 0,
          blocked: 0,
        );
      },
      networkAvailable: () async => true,
      onError: (error, stackTrace) => fail('$error'),
    );
    addTearDown(coordinator.dispose);

    await coordinator.setUser('owner-1');
    await pumpEventQueue();
    expect(drains, 1);

    store.emit('owner-1');
    await pumpEventQueue();
    expect(drains, 2);
  });

  test('keeps offline work queued and drains after reconnect trigger',
      () async {
    final store = _FakeStore();
    var online = false;
    var drains = 0;
    final coordinator = LessonCompletionSyncCoordinator(
      store: store,
      drain: ({required userId, limit = 20}) async {
        drains++;
        return const LessonSyncDrainResult(
          recovered: 0,
          synced: 1,
          retried: 0,
          blocked: 0,
        );
      },
      networkAvailable: () async => online,
      onError: (error, stackTrace) => fail('$error'),
      failureWakeDelay: const Duration(days: 1),
      maximumFailureWakeDelay: const Duration(days: 1),
    );
    addTearDown(coordinator.dispose);

    await coordinator.setUser('owner-1');
    await pumpEventQueue();
    expect(drains, 0);

    online = true;
    coordinator.triggerNow();
    await pumpEventQueue();
    expect(drains, 1);
  });

  test('account switch cancels the previous owner stream', () async {
    final store = _FakeStore();
    final drainedOwners = <String>[];
    final coordinator = LessonCompletionSyncCoordinator(
      store: store,
      drain: ({required userId, limit = 20}) async {
        drainedOwners.add(userId);
        return const LessonSyncDrainResult(
          recovered: 0,
          synced: 0,
          retried: 0,
          blocked: 0,
        );
      },
      networkAvailable: () async => true,
      onError: (error, stackTrace) => fail('$error'),
    );
    addTearDown(coordinator.dispose);

    await coordinator.setUser('owner-1');
    await pumpEventQueue();
    await coordinator.setUser('owner-2');
    await pumpEventQueue();
    final baseline = drainedOwners.length;

    store.emit('owner-1');
    await pumpEventQueue();
    expect(drainedOwners, hasLength(baseline));
    store.emit('owner-2');
    await pumpEventQueue();
    expect(drainedOwners.last, 'owner-2');
  });
}

final class _FakeStore implements LessonCompletionSyncStore {
  final StreamController<String> _changes = StreamController.broadcast();

  void emit(String userId) => _changes.add(userId);

  @override
  Stream<void> watchChanges(String userId) async* {
    yield null;
    yield* _changes.stream.where((owner) => owner == userId);
  }

  @override
  Future<int> outstandingSyncCount(String userId) async => 0;

  @override
  Future<DateTime?> nextSyncAttemptAt(String userId) async => null;

  @override
  Future<List<LessonCompletionSyncPayload>> readySyncPayloads({
    required String userId,
    required DateTime now,
    int limit = 20,
  }) async =>
      const [];

  @override
  Future<LessonCompletionResult?> markSyncing({
    required String userId,
    required String resultId,
    required DateTime now,
  }) async =>
      null;

  @override
  Future<void> markSynced({
    required String userId,
    required String resultId,
    required LessonCompletionReceipt receipt,
    required DateTime now,
  }) async {}

  @override
  Future<void> markSyncFailed({
    required String userId,
    required String resultId,
    required String errorCode,
    required DateTime? retryAt,
    required DateTime now,
  }) async {}

  @override
  Future<int> recoverInterruptedSyncs({
    required String userId,
    required DateTime interruptedBefore,
    required DateTime now,
  }) async =>
      0;
}
