import 'dart:async';

import 'package:capy_vocab/features/library/application/library_sync_coordinator.dart';
import 'package:capy_vocab/features/library/application/library_sync_worker.dart';
import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:flutter_test/flutter_test.dart';

final _time = DateTime.utc(2026, 9, 4, 12);
const _userId = 'b0000000-0000-0000-0000-000000000001';
const _otherUserId = 'b0000000-0000-0000-0000-000000000002';

void main() {
  testWidgets('cloud pull starts on consent and remains single-flight',
      (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    final firstPull = Completer<void>();
    var active = 0;
    var maximumActive = 0;
    var pulls = 0;
    final coordinator = LibrarySyncCoordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async => _result(),
      pull: ({required userId}) async {
        pulls++;
        active++;
        maximumActive = active > maximumActive ? active : maximumActive;
        if (pulls == 1) await firstPull.future;
        active--;
        return false;
      },
      onError: (error, stackTrace) => fail('unexpected error: $error'),
      clock: () => _time,
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);

    consent.accounts.add(_account(cloudBackup: true));
    await tester.pump();
    expect(pulls, 1);
    coordinator.triggerNow();
    coordinator.triggerNow();
    await tester.pump();
    expect(pulls, 1);

    firstPull.complete();
    await tester.pump();
    await tester.pump();
    expect(pulls, 2, reason: 'overlapping wakes collapse into one follow-up');
    expect(maximumActive, 1);
  });

  testWidgets('remaining cloud pages continue without another lifecycle event',
      (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    var pulls = 0;
    final coordinator = LibrarySyncCoordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async => _result(),
      pull: ({required userId}) async {
        pulls++;
        return pulls == 1;
      },
      onError: (error, stackTrace) => fail('unexpected error: $error'),
      clock: () => _time,
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);

    consent.accounts.add(_account(cloudBackup: true));
    await tester.pump();
    await tester.pump();

    expect(pulls, 2);
  });

  testWidgets('consent and outbox events trigger a drain', (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    var drains = 0;
    final coordinator = _coordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async {
        drains++;
        return _result(completed: 1);
      },
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);

    consent.accounts.add(_account(cloudBackup: false));
    operations.counts.add(1);
    await tester.pump();
    expect(drains, 0);

    consent.accounts.add(_account(cloudBackup: true));
    await tester.pump();
    await tester.pump();
    expect(drains, 1);

    operations.counts.add(0);
    await tester.pump();
  });

  testWidgets('next retry time wakes the worker without a network package',
      (tester) async {
    final operations = _FakeSyncRepository(
      nextRetryAt: _time.add(const Duration(seconds: 5)),
    );
    final consent = _FakeConsentRepository();
    var drains = 0;
    final coordinator = _coordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async {
        drains++;
        return _result();
      },
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);
    consent.accounts.add(_account(cloudBackup: true));
    operations.counts.add(1);
    await tester.pump();
    await tester.pump();
    expect(drains, 1);

    await tester.pump(const Duration(seconds: 4));
    expect(drains, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(drains, 2);

    operations.counts.add(0);
    await tester.pump();
  });

  testWidgets('pending privacy purge triggers while cloud backup is off',
      (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    var drains = 0;
    final coordinator = _coordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async {
        drains++;
        return _result(completed: 1);
      },
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);

    consent.accounts.add(_account(cloudBackup: false));
    operations.counts.add(1);
    await tester.pump();
    expect(drains, 0, reason: 'ordinary uploads remain consent-gated');

    operations.purgeCountsFor(_userId).add(1);
    await tester.pump();
    await tester.pump();
    expect(drains, 1);
  });

  test('logout cancels a scheduled retry', () async {
    final operations = _FakeSyncRepository(
      nextRetryAt: _time.add(const Duration(milliseconds: 20)),
    );
    final consent = _FakeConsentRepository();
    var drains = 0;
    final firstDrain = Completer<void>();
    final coordinator = _coordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async {
        drains++;
        if (!firstDrain.isCompleted) firstDrain.complete();
        return _result();
      },
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);
    consent.accounts.add(_account(cloudBackup: true));
    operations.counts.add(1);
    await firstDrain.future;
    expect(drains, 1);

    await coordinator.setUser(null);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(drains, 1);
  });

  testWidgets('unexpected coordinator failure is reported and retried',
      (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    var attempts = 0;
    final errors = <Object>[];
    final coordinator = LibrarySyncCoordinator(
      operations: operations,
      consent: consent,
      clock: () => _time,
      failureWakeDelay: const Duration(seconds: 1),
      onError: (error, stackTrace) => errors.add(error),
      drain: ({required userId, limit = 100}) async {
        attempts++;
        throw StateError('database temporarily unavailable');
      },
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);
    consent.accounts.add(_account(cloudBackup: true));
    operations.counts.add(1);
    await tester.pump();
    await tester.pump();
    expect(attempts, 1);
    expect(errors, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(attempts, 2);
    expect(errors, hasLength(2));

    operations.counts.add(0);
    await tester.pump();
  });

  testWidgets(
      'offline gate skips cloud calls, stays quiet, and exponentially backs off',
      (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    var online = false;
    var availabilityChecks = 0;
    var drains = 0;
    var pulls = 0;
    final errors = <Object>[];
    final coordinator = LibrarySyncCoordinator(
      operations: operations,
      consent: consent,
      networkAvailable: () async {
        availabilityChecks++;
        return online;
      },
      failureWakeDelay: const Duration(seconds: 1),
      maximumFailureWakeDelay: const Duration(seconds: 4),
      drain: ({required userId, limit = 100}) async {
        drains++;
        return _result();
      },
      pull: ({required userId}) async {
        pulls++;
        return false;
      },
      onError: (error, stackTrace) => errors.add(error),
      clock: () => _time,
    );
    addTearDown(coordinator.dispose);
    await coordinator.setUser(_userId);

    consent.accounts.add(_account(cloudBackup: true));
    await tester.pump();
    await tester.pump();
    expect(availabilityChecks, 1);
    expect(drains, 0);
    expect(pulls, 0);
    expect(errors, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(availabilityChecks, 2);
    expect(drains, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(availabilityChecks, 2, reason: 'second retry waits two seconds');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(availabilityChecks, 3);
    expect(errors, isEmpty);

    online = true;
    coordinator.triggerNow();
    await tester.pump();
    await tester.pump();
    expect(drains, 1);
    expect(pulls, 1);
    expect(errors, isEmpty);
  });

  testWidgets('overlapping auth changes keep only the newest owner subscribed',
      (tester) async {
    final operations = _FakeSyncRepository();
    final consent = _FakeConsentRepository();
    final drainedUsers = <String>[];
    final coordinator = _coordinator(
      operations: operations,
      consent: consent,
      drain: ({required userId, limit = 100}) async {
        drainedUsers.add(userId);
        return _result(completed: 1);
      },
    );
    addTearDown(coordinator.dispose);

    await Future.wait([
      coordinator.setUser(_userId),
      coordinator.setUser(_otherUserId),
    ]);
    consent.accountsFor(_userId).add(_account(
          userId: _userId,
          cloudBackup: true,
        ));
    operations.countsFor(_userId).add(1);
    await tester.pump();
    await tester.pump();
    expect(drainedUsers, isEmpty);

    consent.accountsFor(_otherUserId).add(_account(
          userId: _otherUserId,
          cloudBackup: true,
        ));
    operations.countsFor(_otherUserId).add(1);
    await tester.pump();
    await tester.pump();
    expect(drainedUsers, [_otherUserId]);
  });
}

LibrarySyncCoordinator _coordinator({
  required _FakeSyncRepository operations,
  required _FakeConsentRepository consent,
  required SyncDrain drain,
}) {
  return LibrarySyncCoordinator(
    operations: operations,
    consent: consent,
    drain: drain,
    onError: (error, stackTrace) => fail('unexpected error: $error'),
    clock: () => _time,
  );
}

SyncDrainResult _result({int completed = 0}) {
  return SyncDrainResult(
    recovered: 0,
    completed: completed,
    retried: 0,
    blocked: 0,
    skippedForConsent: false,
  );
}

LocalAccount _account({
  String userId = _userId,
  required bool cloudBackup,
}) {
  return LocalAccount(
    userId: userId,
    accountState: AccountState.active,
    cloudBackupEnabled: cloudBackup,
    localPersonalizationEnabled: false,
    federatedContributionEnabled: false,
    createdAt: _time,
    updatedAt: _time,
  );
}

final class _FakeSyncRepository implements SyncRepository {
  _FakeSyncRepository({this.nextRetryAt});

  final Map<String, StreamController<int>> _counts = {};
  final Map<String, StreamController<int>> _purgeCounts = {};
  DateTime? nextRetryAt;

  StreamController<int> get counts => countsFor(_userId);

  StreamController<int> countsFor(String userId) =>
      _counts.putIfAbsent(userId, StreamController<int>.broadcast);

  StreamController<int> purgeCountsFor(String userId) =>
      _purgeCounts.putIfAbsent(userId, StreamController<int>.broadcast);

  @override
  Future<DateTime?> getNextRetryAt({required String userId}) async =>
      nextRetryAt;

  @override
  Stream<int> watchOperationCount({
    required String userId,
    Set<SyncOperationState> states = const {
      SyncOperationState.pending,
      SyncOperationState.retry,
    },
  }) =>
      countsFor(userId).stream;

  @override
  Stream<int> watchPendingPurgeCount({required String userId}) =>
      purgeCountsFor(userId).stream;

  @override
  Future<void> enqueue(SyncOperation operation) => throw UnimplementedError();

  @override
  Future<List<SyncOperation>> getReadyOperations({
    required String userId,
    required DateTime now,
    int limit = 100,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SyncTombstone>> getPendingTombstones({
    required String userId,
    int limit = 100,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> saveTombstone(SyncTombstone tombstone) =>
      throw UnimplementedError();

  @override
  Future<void> updateOperation(SyncOperation operation) =>
      throw UnimplementedError();
}

final class _FakeConsentRepository implements ConsentRepository {
  final Map<String, StreamController<LocalAccount?>> _accounts = {};

  StreamController<LocalAccount?> get accounts => accountsFor(_userId);

  StreamController<LocalAccount?> accountsFor(String userId) =>
      _accounts.putIfAbsent(
        userId,
        StreamController<LocalAccount?>.broadcast,
      );

  @override
  Stream<LocalAccount?> watchLocalAccount({required String userId}) =>
      accountsFor(userId).stream;

  @override
  Future<List<ConsentEvent>> getPendingEnforcement({
    required String userId,
    ConsentType? consentType,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> recordChange(ConsentEvent event) => throw UnimplementedError();

  @override
  Future<void> updateEnforcementState({
    required String userId,
    required String eventId,
    required ConsentEnforcementState state,
  }) =>
      throw UnimplementedError();

  @override
  Stream<List<ConsentEvent>> watchConsentHistory({required String userId}) =>
      throw UnimplementedError();
}
