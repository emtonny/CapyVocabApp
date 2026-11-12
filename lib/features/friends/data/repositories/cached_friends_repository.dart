import '../../domain/entities/friend_entity.dart';
import '../../domain/repositories/friends_repository.dart';
import '../local/friends_store.dart';

final class CachedFriendsRepository implements FriendsRepository {
  CachedFriendsRepository({
    required this.remote,
    required this.store,
    required bool Function() isCurrentSession,
    DateTime Function()? now,
  })  : _isCurrentSession = isCurrentSession,
        _now = now ?? DateTime.now;

  final FriendsRemoteGateway remote;
  final FriendsStore store;
  final bool Function() _isCurrentSession;
  final DateTime Function() _now;
  final Map<FriendListKind, Future<void>> _inflight = {};
  bool _closed = false;

  @override
  Stream<FriendRemoteSignal> get remoteSignals => remote.signals;

  @override
  Stream<List<FriendConnection>> watchCached(FriendListKind kind) =>
      store.watch(kind);

  @override
  Future<List<FriendConnection>> readCached(FriendListKind kind) =>
      store.list(kind);

  @override
  Future<void> refresh(FriendListKind kind) {
    _checkCurrent();
    final active = _inflight[kind];
    if (active != null) return active;
    late final Future<void> operation;
    operation = _refresh(kind).whenComplete(() {
      if (identical(_inflight[kind], operation)) _inflight.remove(kind);
    });
    _inflight[kind] = operation;
    return operation;
  }

  Future<void> _refresh(FriendListKind kind) async {
    final refreshStartedAt = _now().toUtc();
    final connections = <FriendConnection>[];
    final peerIds = <String>{};
    FriendCursor? cursor;
    for (var pageCount = 0; pageCount < 1000; pageCount++) {
      _checkCurrent();
      final page = kind == FriendListKind.accepted
          ? await remote.listAccepted(cursor: cursor)
          : await remote.listRequests(
              direction: kind == FriendListKind.incoming
                  ? FriendRequestDirection.incoming
                  : FriendRequestDirection.outgoing,
              cursor: cursor,
            );
      _checkCurrent();
      if (page.items.isEmpty) {
        await store.reconcileSnapshot(
          kind: kind,
          connections: connections,
          refreshStartedAt: refreshStartedAt,
          completedAt: _now().toUtc(),
          isCurrent: _isUsable,
        );
        return;
      }
      for (final connection in page.items) {
        if (!peerIds.add(connection.profile.id)) {
          throw const FriendDataException(
            'The friends service returned a duplicate across pages.',
          );
        }
        connections.add(connection);
      }
      final next = page.nextCursor;
      if (next == null ||
          (cursor != null &&
              next.updatedAt.isAtSameMomentAs(cursor.updatedAt) &&
              next.peerId == cursor.peerId)) {
        throw const FriendDataException(
          'The friends service returned a non-advancing cursor.',
        );
      }
      cursor = next;
    }
    throw const FriendException(
      FriendFailureKind.unavailable,
      'The friends list exceeded the safe pagination limit.',
    );
  }

  @override
  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  }) {
    _checkCurrent();
    return remote.searchFriend(method: method, query: query);
  }

  @override
  Future<FriendDiscoverySettings> getDiscoverySettings() {
    _checkCurrent();
    return remote.getDiscoverySettings();
  }

  @override
  Future<FriendDiscoverySettings> updateDiscoverySettings({
    required bool discoverableByEmail,
    required bool discoverableByPhone,
  }) {
    _checkCurrent();
    return remote.updateDiscoverySettings(
      discoverableByEmail: discoverableByEmail,
      discoverableByPhone: discoverableByPhone,
    );
  }

  @override
  Future<void> syncVerifiedPhone() {
    _checkCurrent();
    return remote.syncVerifiedPhone();
  }

  @override
  Future<FriendMutationResult> sendRequest(String targetUserId) {
    _checkCurrent();
    return remote.sendRequest(targetUserId);
  }

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) {
    _checkCurrent();
    return remote.respondToRequest(
      requesterId: requesterId,
      decision: decision,
    );
  }

  void _checkCurrent() {
    if (!_isUsable()) throw const FriendRefreshSuperseded();
  }

  bool _isUsable() => !_closed && _isCurrentSession();

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await remote.dispose();
    await store.dispose();
  }
}
