import 'dart:async';

import 'package:capy_vocab/features/friends/data/datasources/friends_supabase_datasource.dart';
import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/repositories/friends_repository.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friends_provider.dart';
import 'package:flutter_test/flutter_test.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const peerId = '20000000-0000-4000-8000-000000000001';
final owner = FriendOwner(
  projectRef: FriendsSupabaseDataSource.stagingRef,
  userId: ownerId,
);

FriendConnection result({
  FriendRelationshipState state = FriendRelationshipState.none,
}) {
  return FriendConnection(
    profile: FriendPublicProfile(
      id: peerId,
      displayName: 'Bạn Nai',
      username: 'ban_nai',
      avatarUrl: null,
      studyPoints: 42,
      streakDays: 7,
      userLevel: 3,
    ),
    state: state,
    updatedAt: null,
  );
}

final class FakeFriendsRepository implements FriendsRepository {
  final signals = StreamController<FriendRemoteSignal>.broadcast();
  final searchBarriers = <Completer<FriendConnection?>>[];
  Completer<FriendMutationResult>? sendBarrier;
  int searchCalls = 0;
  int sendCalls = 0;
  final refreshed = <FriendListKind>[];
  final searches = <({FriendSearchMethod method, String query})>[];

  @override
  Stream<FriendRemoteSignal> get remoteSignals => signals.stream;

  @override
  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  }) {
    searchCalls++;
    searches.add((method: method, query: query));
    final barrier = Completer<FriendConnection?>();
    searchBarriers.add(barrier);
    return barrier.future;
  }

  @override
  Future<FriendMutationResult> sendRequest(String targetUserId) {
    sendCalls++;
    return (sendBarrier ??= Completer<FriendMutationResult>()).future;
  }

  @override
  Future<void> refresh(FriendListKind kind) async => refreshed.add(kind);

  @override
  Future<List<FriendConnection>> readCached(FriendListKind kind) async => [];

  @override
  Stream<List<FriendConnection>> watchCached(FriendListKind kind) =>
      const Stream.empty();

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
      FriendDiscoverySettings(
        discoverableByEmail: discoverableByEmail,
        discoverableByPhone: discoverableByPhone,
        emailConfirmed: true,
        phoneVerified: true,
      );

  @override
  Future<void> syncVerifiedPhone() async {}

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async => signals.close();
}

void main() {
  test('normalizes and validates exact username email and Vietnam phone', () {
    expect(
      normalizeFriendSearchQuery(FriendSearchMethod.username, ' Deer_Friend '),
      'deer_friend',
    );
    expect(
      normalizeFriendSearchQuery(FriendSearchMethod.email, ' A@Example.COM '),
      'a@example.com',
    );
    expect(
      normalizeFriendSearchQuery(FriendSearchMethod.phone, '+84 912.345.678'),
      '0912345678',
    );
    expect(validateFriendSearchQuery(FriendSearchMethod.username, 'ab'),
        isNotNull);
    expect(
        validateFriendSearchQuery(FriendSearchMethod.email, 'a@b'), isNotNull);
    expect(validateFriendSearchQuery(FriendSearchMethod.phone, '0912345678'),
        isNull);
  });

  test('debounces valid input and never calls remote for invalid input',
      () async {
    final repository = FakeFriendsRepository();
    final notifier = FriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
      debounce: const Duration(milliseconds: 2),
    );
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);

    notifier.queryChanged('ab');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(repository.searchCalls, 0);
    expect(notifier.state.phase, FriendSearchPhase.invalid);

    notifier.queryChanged('ban_nai');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(repository.searchCalls, 1);
    repository.searchBarriers.single.complete(result());
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.phase, FriendSearchPhase.found);
  });

  test('sends normalized exact email and phone with the selected method',
      () async {
    final repository = FakeFriendsRepository();
    final notifier = FriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
      debounce: const Duration(milliseconds: 2),
    );
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);

    notifier.selectMethod(FriendSearchMethod.email);
    notifier.queryChanged(' A@Example.COM ');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(
      repository.searches.single,
      (method: FriendSearchMethod.email, query: 'a@example.com'),
    );
    repository.searchBarriers.single.complete(null);
    await Future<void>.delayed(Duration.zero);

    notifier.selectMethod(FriendSearchMethod.phone);
    notifier.queryChanged('+84 912.345.678');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(
      repository.searches.last,
      (method: FriendSearchMethod.phone, query: '0912345678'),
    );
  });

  test('ignores an old search response after the query changes', () async {
    final repository = FakeFriendsRepository();
    final notifier = FriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
      debounce: const Duration(milliseconds: 2),
    );
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);

    notifier.queryChanged('friend_one');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    notifier.queryChanged('friend_two');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(repository.searchCalls, 2);

    repository.searchBarriers.first.complete(result());
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.result, isNull);
    repository.searchBarriers.last.complete(result());
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.result?.profile.id, peerId);
  });

  test('cancels a stale search before remote lookup after network preflight',
      () async {
    final repository = FakeFriendsRepository();
    final networkBarriers = <Completer<bool>>[];
    final notifier = FriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () {
        final barrier = Completer<bool>();
        networkBarriers.add(barrier);
        return barrier.future;
      },
      debounce: const Duration(milliseconds: 2),
    );
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);

    notifier.queryChanged('friend_one');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(networkBarriers, hasLength(1));

    notifier.queryChanged('friend_two');
    networkBarriers.first.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.searchCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 8));
    expect(networkBarriers, hasLength(2));
    networkBarriers.last.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(repository.searches.single.query, 'friend_two');
  });

  test('offline search fails before any repository request', () async {
    final repository = FakeFriendsRepository();
    final notifier = FriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => false,
      debounce: const Duration(milliseconds: 2),
    );
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);

    notifier.queryChanged('ban_nai');
    await Future<void>.delayed(const Duration(milliseconds: 8));

    expect(repository.searchCalls, 0);
    expect(notifier.state.phase, FriendSearchPhase.failure);
    expect(notifier.state.message, contains('offline'));
  });

  test('double tap sends once and reconciles outgoing cache', () async {
    final repository = FakeFriendsRepository();
    final notifier = FriendsNotifier(
      owner: owner,
      repository: repository,
      networkAvailable: () async => true,
      debounce: const Duration(milliseconds: 2),
    );
    addTearDown(notifier.dispose);
    addTearDown(repository.dispose);
    notifier.queryChanged('ban_nai');
    await Future<void>.delayed(const Duration(milliseconds: 8));
    repository.searchBarriers.single.complete(result());
    await Future<void>.delayed(Duration.zero);

    final first = notifier.sendRequest();
    final second = notifier.sendRequest();
    await Future<void>.delayed(Duration.zero);
    expect(repository.sendCalls, 1);
    repository.sendBarrier!.complete(FriendMutationResult.outgoingPending);
    await Future.wait([first, second]);

    expect(repository.sendCalls, 1);
    expect(
        notifier.state.result?.state, FriendRelationshipState.outgoingPending);
    expect(repository.refreshed, [FriendListKind.outgoing]);
  });
}
