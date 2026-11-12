import 'dart:async';

import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/repositories/friends_repository.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friend_requests_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const peerId = '20000000-0000-4000-8000-000000000001';
final owner = FriendOwner(projectRef: 'nxteaznowkfennxpqjmt', userId: ownerId);

FriendConnection request(
  FriendListKind kind, {
  String id = peerId,
  String username = 'ban_nai',
}) {
  return FriendConnection(
    profile: FriendPublicProfile(
      id: id,
      displayName: 'Bạn Nai',
      username: username,
      avatarUrl: null,
      studyPoints: 42,
      streakDays: 7,
      userLevel: 3,
    ),
    state: kind.relationshipState,
    updatedAt: DateTime.utc(2026, 9, 22, 12),
  );
}

final class FakeRequestRepository implements FriendsRepository {
  FakeRequestRepository({
    List<FriendConnection> incoming = const [],
    List<FriendConnection> outgoing = const [],
  }) : cache = {
          FriendListKind.incoming: incoming,
          FriendListKind.outgoing: outgoing,
          FriendListKind.accepted: const [],
        };

  final Map<FriendListKind, List<FriendConnection>> cache;
  final signals = StreamController<FriendRemoteSignal>.broadcast(sync: true);
  final controllers = {
    for (final kind in FriendListKind.values)
      kind: StreamController<List<FriendConnection>>.broadcast(sync: true),
  };
  final refreshCalls = <FriendListKind>[];
  final responses = <({String peerId, FriendDecision decision})>[];
  final refreshErrors = <FriendListKind, Object>{};
  Completer<FriendMutationResult>? responseBarrier;

  @override
  Stream<FriendRemoteSignal> get remoteSignals => signals.stream;

  @override
  Future<List<FriendConnection>> readCached(FriendListKind kind) async =>
      List.unmodifiable(cache[kind]!);

  @override
  Stream<List<FriendConnection>> watchCached(FriendListKind kind) =>
      controllers[kind]!.stream;

  @override
  Future<void> refresh(FriendListKind kind) async {
    refreshCalls.add(kind);
    final error = refreshErrors[kind];
    if (error != null) throw error;
    controllers[kind]!.add(List.unmodifiable(cache[kind]!));
  }

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) {
    responses.add((peerId: requesterId, decision: decision));
    return (responseBarrier ??= Completer<FriendMutationResult>()).future;
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
  Future<void> dispose() async {
    await signals.close();
    for (final controller in controllers.values) {
      await controller.close();
    }
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('hydrates incoming and outgoing cache before background reconciliation',
      () async {
    final repository = FakeRequestRepository(
      incoming: [request(FriendListKind.incoming)],
      outgoing: [
        request(
          FriendListKind.outgoing,
          id: '30000000-0000-4000-8000-000000000001',
          username: 'ban_huou',
        ),
      ],
    );
    final notifier = FriendRequestsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(repository.dispose);
    addTearDown(notifier.dispose);

    await settle();

    expect(notifier.state.incoming.single.profile.id, peerId);
    expect(notifier.state.outgoing.single.profile.username, 'ban_huou');
    expect(notifier.state.incomingCacheLoaded, isTrue);
    expect(notifier.state.outgoingCacheLoaded, isTrue);
    expect(repository.refreshCalls, containsAll(FriendListKind.values.take(2)));
  });

  test('double accept responds once, removes row and reconciles accepted cache',
      () async {
    final repository = FakeRequestRepository(
      incoming: [request(FriendListKind.incoming)],
    );
    final notifier = FriendRequestsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(repository.dispose);
    addTearDown(notifier.dispose);
    await settle();

    final first = notifier.respond(peerId, FriendDecision.accept);
    final second = notifier.respond(peerId, FriendDecision.accept);
    await Future<void>.delayed(Duration.zero);
    expect(repository.responses, [
      (peerId: peerId, decision: FriendDecision.accept),
    ]);

    repository.responseBarrier!.complete(FriendMutationResult.accepted);
    await Future.wait([first, second]);

    expect(notifier.state.incoming, isEmpty);
    expect(notifier.state.message, 'Đã chấp nhận lời mời kết bạn.');
    expect(
      repository.refreshCalls.where((kind) => kind == FriendListKind.accepted),
      hasLength(1),
    );
  });

  test('reject removes the row without refreshing accepted friends', () async {
    final repository = FakeRequestRepository(
      incoming: [request(FriendListKind.incoming)],
    );
    final notifier = FriendRequestsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(repository.dispose);
    addTearDown(notifier.dispose);
    await settle();

    final response = notifier.respond(peerId, FriendDecision.reject);
    await Future<void>.delayed(Duration.zero);
    repository.responseBarrier!.complete(FriendMutationResult.rejected);
    await response;

    expect(notifier.state.incoming, isEmpty);
    expect(notifier.state.message, 'Đã từ chối lời mời kết bạn.');
    expect(repository.refreshCalls, isNot(contains(FriendListKind.accepted)));
  });

  test('offline response keeps the cached request and performs zero mutation',
      () async {
    final repository = FakeRequestRepository(
      incoming: [request(FriendListKind.incoming)],
    );
    final notifier = FriendRequestsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => false,
    );
    addTearDown(repository.dispose);
    addTearDown(notifier.dispose);
    await settle();

    await notifier.respond(peerId, FriendDecision.accept);

    expect(repository.responses, isEmpty);
    expect(notifier.state.incoming.single.profile.id, peerId);
    expect(notifier.state.message, contains('offline'));
  });

  test('realtime change invalidates both request directions', () async {
    final repository = FakeRequestRepository();
    final notifier = FriendRequestsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
    );
    addTearDown(repository.dispose);
    addTearDown(notifier.dispose);
    await settle();
    final before = repository.refreshCalls.length;

    repository.signals.add(FriendRemoteSignal.changed);
    await settle();

    expect(repository.refreshCalls.length, before + 2);
  });
}
