import 'dart:async';

import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/repositories/friends_repository.dart';
import 'package:capy_vocab/features/friends/presentation/providers/accepted_friends_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const peerId = '20000000-0000-4000-8000-000000000001';
const peerTwoId = '30000000-0000-4000-8000-000000000001';
const conversationId = '40000000-0000-4000-8000-000000000001';

final owner = FriendOwner(
  projectRef: 'nxteaznowkfennxpqjmt',
  userId: ownerId,
);

FriendConnection accepted(String id, String name) => FriendConnection(
      profile: FriendPublicProfile(
        id: id,
        displayName: name,
        username: name.toLowerCase().replaceAll(' ', '_'),
        avatarUrl: null,
        studyPoints: 20,
        streakDays: 4,
        userLevel: 2,
      ),
      state: FriendRelationshipState.accepted,
      updatedAt: DateTime.utc(2026, 9, 23, 9),
    );

final class FakeAcceptedRepository implements FriendsRepository {
  FakeAcceptedRepository({List<FriendConnection> accepted = const []})
      : cache = List.of(accepted),
        remoteAccepted = List.of(accepted);

  List<FriendConnection> cache;
  List<FriendConnection> remoteAccepted;
  Completer<void>? refreshBarrier;
  int acceptedRefreshes = 0;
  final signals = StreamController<FriendRemoteSignal>.broadcast(sync: true);
  final cacheChanges =
      StreamController<List<FriendConnection>>.broadcast(sync: true);

  @override
  Stream<FriendRemoteSignal> get remoteSignals => signals.stream;

  @override
  Future<List<FriendConnection>> readCached(FriendListKind kind) async =>
      kind == FriendListKind.accepted ? List.unmodifiable(cache) : const [];

  @override
  Stream<List<FriendConnection>> watchCached(FriendListKind kind) =>
      kind == FriendListKind.accepted
          ? cacheChanges.stream
          : const Stream.empty();

  @override
  Future<void> refresh(FriendListKind kind) async {
    if (kind != FriendListKind.accepted) return;
    acceptedRefreshes++;
    final barrier = refreshBarrier;
    if (barrier != null) await barrier.future;
    cache = List.of(remoteAccepted);
    cacheChanges.add(List.unmodifiable(cache));
  }

  @override
  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  }) async =>
      null;

  @override
  Future<FriendDiscoverySettings> getDiscoverySettings() async =>
      const FriendDiscoverySettings(
        discoverableByEmail: false,
        discoverableByPhone: false,
        emailConfirmed: true,
        phoneVerified: true,
      );

  @override
  Future<FriendDiscoverySettings> updateDiscoverySettings({
    required bool discoverableByEmail,
    required bool discoverableByPhone,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> syncVerifiedPhone() async {}

  @override
  Future<FriendMutationResult> sendRequest(String targetUserId) async =>
      throw UnimplementedError();

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async {
    await signals.close();
    await cacheChanges.close();
  }
}

Future<void> flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('hydrates accepted cache before background refresh completes', () async {
    final repository = FakeAcceptedRepository(
      accepted: [accepted(peerId, 'Bạn Nai')],
    );
    addTearDown(repository.dispose);
    repository.remoteAccepted = [accepted(peerTwoId, 'Bạn Hươu')];
    repository.refreshBarrier = Completer<void>();
    final notifier = AcceptedFriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(notifier.dispose);

    await flushAsync();

    expect(notifier.state.cacheLoaded, isTrue);
    expect(notifier.state.items.single.profile.id, peerId);
    expect(notifier.state.refreshing, isTrue);

    repository.refreshBarrier!.complete();
    await flushAsync();

    expect(notifier.state.items.single.profile.id, peerTwoId);
    expect(notifier.state.refreshing, isFalse);
  });

  test('Realtime invalidation refreshes accepted snapshot', () async {
    final repository = FakeAcceptedRepository(
      accepted: [accepted(peerId, 'Bạn Nai')],
    );
    addTearDown(repository.dispose);
    final notifier = AcceptedFriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(notifier.dispose);
    await flushAsync();
    expect(repository.acceptedRefreshes, 1);

    repository.remoteAccepted = [accepted(peerTwoId, 'Bạn Hươu')];
    repository.signals.add(FriendRemoteSignal.changed);
    await flushAsync();

    expect(repository.acceptedRefreshes, 2);
    expect(notifier.state.items.single.profile.id, peerTwoId);
  });

  test('revalidates accepted relation then returns canonical conversation id',
      () async {
    final repository = FakeAcceptedRepository(
      accepted: [accepted(peerId, 'Bạn Nai')],
    );
    addTearDown(repository.dispose);
    final notifier = AcceptedFriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(notifier.dispose);
    await flushAsync();
    var openedPeer = '';

    final opened = await notifier.openChat(
      peerId: peerId,
      openDirectChat: (value) async {
        openedPeer = value;
        return conversationId;
      },
    );

    expect(openedPeer, peerId);
    expect(opened, conversationId);
    expect(repository.acceptedRefreshes, 2);
    expect(notifier.state.openingPeerId, isNull);
  });

  test('revoked relation is removed and blocks Chat RPC', () async {
    final repository = FakeAcceptedRepository(
      accepted: [accepted(peerId, 'Bạn Nai')],
    );
    addTearDown(repository.dispose);
    final notifier = AcceptedFriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(notifier.dispose);
    await flushAsync();
    repository.remoteAccepted = [];
    var openCalls = 0;

    final opened = await notifier.openChat(
      peerId: peerId,
      openDirectChat: (_) async {
        openCalls++;
        return conversationId;
      },
    );

    expect(opened, isNull);
    expect(openCalls, 0);
    expect(notifier.state.items, isEmpty);
    expect(notifier.state.message, contains('đã thay đổi'));
  });

  test('offline Chat attempt keeps cached friend and makes zero RPC calls',
      () async {
    final repository = FakeAcceptedRepository(
      accepted: [accepted(peerId, 'Bạn Nai')],
    );
    addTearDown(repository.dispose);
    final notifier = AcceptedFriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => false,
    );
    addTearDown(notifier.dispose);
    await flushAsync();
    var openCalls = 0;

    final opened = await notifier.openChat(
      peerId: peerId,
      openDirectChat: (_) async {
        openCalls++;
        return conversationId;
      },
    );

    expect(opened, isNull);
    expect(openCalls, 0);
    expect(repository.acceptedRefreshes, 0);
    expect(notifier.state.items.single.profile.id, peerId);
    expect(notifier.state.message, contains('offline'));
  });
}
