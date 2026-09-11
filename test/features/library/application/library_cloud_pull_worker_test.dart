import 'package:capy_vocab/features/library/application/library_cloud_pull_gateway.dart';
import 'package:capy_vocab/features/library/application/library_cloud_pull_worker.dart';
import 'package:capy_vocab/features/library/application/library_sync_gateway.dart';
import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'a1000000-0000-0000-0000-000000000001';

void main() {
  test('consent off performs no remote request', () async {
    final local = _FakePullStore(enabled: false);
    final remote = _FakePullGateway(userId: _userId, deltas: const []);
    final result = await LibraryCloudPullWorker(local: local, remote: remote)
        .pull(userId: _userId);

    expect(result.skippedForConsent, isTrue);
    expect(remote.requestedCursors, isEmpty);
  });

  test('pulls ordered batches and advances cursor after each local commit',
      () async {
    final local = _FakePullStore(enabled: true);
    final remote = _FakePullGateway(userId: _userId, deltas: [
      _delta(previous: 0, next: 4, hasMore: true),
      _delta(previous: 4, next: 8, hasMore: false),
    ]);
    final result = await LibraryCloudPullWorker(local: local, remote: remote)
        .pull(userId: _userId);

    expect(remote.requestedCursors, [0, 4]);
    expect(local.cursor, 8);
    expect(result.batches, 2);
    expect(result.hasMore, isFalse);
    expect(result.skippedForConsent, isFalse);
  });

  test('reports remaining pages when the bounded batch budget is exhausted',
      () async {
    final local = _FakePullStore(enabled: true);
    final remote = _FakePullGateway(userId: _userId, deltas: [
      _delta(previous: 0, next: 4, hasMore: true),
    ]);

    final result = await LibraryCloudPullWorker(local: local, remote: remote)
        .pull(userId: _userId, maxBatches: 1);

    expect(result.batches, 1);
    expect(result.hasMore, isTrue);
    expect(local.cursor, 4);
  });

  test('rejects a has-more page that cannot advance the cursor', () async {
    final local = _FakePullStore(enabled: true);
    final remote = _FakePullGateway(userId: _userId, deltas: [
      _delta(previous: 0, next: 0, hasMore: true),
    ]);

    await expectLater(
      LibraryCloudPullWorker(local: local, remote: remote)
          .pull(userId: _userId),
      throwsA(isA<LibrarySyncFailure>().having(
        (error) => error.code,
        'code',
        'pull_cursor_not_advanced',
      )),
    );
  });

  test('wrong authenticated owner fails before a remote request', () async {
    final local = _FakePullStore(enabled: true);
    final remote = _FakePullGateway(
      userId: 'a1000000-0000-0000-0000-000000000002',
      deltas: const [],
    );
    final worker = LibraryCloudPullWorker(local: local, remote: remote);

    await expectLater(
      worker.pull(userId: _userId),
      throwsA(isA<LibrarySyncFailure>().having(
        (error) => error.code,
        'code',
        'pull_auth_required',
      )),
    );
    expect(remote.requestedCursors, isEmpty);
  });
}

LibraryCloudDelta _delta({
  required int previous,
  required int next,
  required bool hasMore,
}) {
  return LibraryCloudDelta(
    userId: _userId,
    previousCursor: previous,
    nextCursor: next,
    hasMore: hasMore,
    snapshots: const [],
    deletions: const [],
  );
}

final class _FakePullStore implements LibraryCloudPullStore {
  _FakePullStore({required this.enabled});

  final bool enabled;
  int cursor = 0;

  @override
  Future<void> applyLibraryCloudDelta(LibraryCloudDelta delta) async {
    if (delta.previousCursor != cursor) throw StateError('stale cursor');
    cursor = delta.nextCursor;
  }

  @override
  Future<int> getLibraryPullCursor({required String userId}) async => cursor;

  @override
  Future<bool> isCloudBackupEnabled({required String userId}) async => enabled;
}

final class _FakePullGateway implements LibraryCloudPullGateway {
  _FakePullGateway(
      {required String? userId, required List<LibraryCloudDelta> deltas})
      : authenticatedUserId = userId,
        _deltas = List.of(deltas);

  @override
  final String? authenticatedUserId;
  final List<LibraryCloudDelta> _deltas;
  final List<int> requestedCursors = [];

  @override
  Future<LibraryCloudDelta> pullLibraryDelta({
    required String userId,
    required int afterCursor,
    int limit = 100,
  }) async {
    requestedCursors.add(afterCursor);
    return _deltas.removeAt(0);
  }
}
