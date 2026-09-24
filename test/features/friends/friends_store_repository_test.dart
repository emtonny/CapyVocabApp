import 'dart:async';
import 'dart:io';

import 'package:capy_vocab/features/friends/data/local/friends_database.dart';
import 'package:capy_vocab/features/friends/data/local/friends_store.dart';
import 'package:capy_vocab/features/friends/data/repositories/cached_friends_repository.dart';
import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/repositories/friends_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const project = 'nxteaznowkfennxpqjmt';
const accountA = '10000000-0000-4000-8000-000000000001';
const accountB = '10000000-0000-4000-8000-000000000002';
String peer(int value) =>
    '20000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
final baseTime = DateTime.utc(2026, 9, 22, 10);

FriendConnection connection(
  int value, {
  FriendRelationshipState state = FriendRelationshipState.accepted,
  DateTime? updatedAt,
  String? displayName,
}) {
  return FriendConnection(
    profile: FriendPublicProfile(
      id: peer(value),
      displayName: displayName ?? 'Friend $value',
      username: 'friend$value',
      avatarUrl: null,
      studyPoints: value,
      streakDays: value,
      userLevel: 1,
    ),
    state: state,
    updatedAt: updatedAt ?? baseTime.add(Duration(minutes: value)),
  );
}

final class FakeFriendsGateway implements FriendsRemoteGateway {
  final pages = <FriendListKind, List<FriendPage>>{};
  Completer<FriendPage>? acceptedBarrier;
  int listCalls = 0;
  int otherCalls = 0;

  @override
  Stream<FriendRemoteSignal> get signals => const Stream.empty();

  FriendPage _take(FriendListKind kind) {
    final queue = pages[kind] ?? <FriendPage>[];
    return queue.isEmpty ? FriendPage(items: const []) : queue.removeAt(0);
  }

  @override
  Future<FriendPage> listAccepted(
      {FriendCursor? cursor, int limit = 100}) async {
    listCalls++;
    if (acceptedBarrier case final barrier?) return barrier.future;
    return _take(FriendListKind.accepted);
  }

  @override
  Future<FriendPage> listRequests({
    required FriendRequestDirection direction,
    FriendCursor? cursor,
    int limit = 100,
  }) async {
    listCalls++;
    return _take(
      direction == FriendRequestDirection.incoming
          ? FriendListKind.incoming
          : FriendListKind.outgoing,
    );
  }

  @override
  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  }) async {
    otherCalls++;
    return null;
  }

  @override
  Future<FriendDiscoverySettings> getDiscoverySettings() async {
    otherCalls++;
    return const FriendDiscoverySettings(
      discoverableByEmail: false,
      discoverableByPhone: false,
      emailConfirmed: true,
      phoneVerified: false,
    );
  }

  @override
  Future<FriendDiscoverySettings> updateDiscoverySettings({
    required bool discoverableByEmail,
    required bool discoverableByPhone,
  }) async {
    otherCalls++;
    return FriendDiscoverySettings(
      discoverableByEmail: discoverableByEmail,
      discoverableByPhone: discoverableByPhone,
      emailConfirmed: true,
      phoneVerified: true,
    );
  }

  @override
  Future<void> syncVerifiedPhone() async => otherCalls++;

  @override
  Future<FriendMutationResult> sendRequest(String targetUserId) async {
    otherCalls++;
    return FriendMutationResult.outgoingPending;
  }

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) async {
    otherCalls++;
    return decision == FriendDecision.accept
        ? FriendMutationResult.accepted
        : FriendMutationResult.rejected;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory directory;
  late FriendsDatabase local;
  late Database database;
  late FriendsStore store;
  late FakeFriendsGateway remote;
  late CachedFriendsRepository repository;
  late bool active;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_friends_f2_');
    local = FriendsDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/friends.db',
    );
    database = await local.open();
    store = FriendsStore(
      database: database,
      owner: FriendOwner(projectRef: project, userId: accountA),
    );
    remote = FakeFriendsGateway();
    active = true;
    repository = CachedFriendsRepository(
      remote: remote,
      store: store,
      isCurrentSession: () => active,
      now: () => baseTime.add(const Duration(hours: 1)),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  test('separate v1 database contains only owner-scoped friends tables',
      () async {
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    expect(
      tables.map((row) => row['name']).toSet(),
      {'friend_connections', 'friend_sync_meta'},
    );
    expect(await database.getVersion(), 1);
    expect(
        (await database.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1);
  });

  test('snapshot cache is isolated by project and account', () async {
    await store.reconcileSnapshot(
      kind: FriendListKind.accepted,
      connections: [connection(1)],
      refreshStartedAt: baseTime,
      completedAt: baseTime.add(const Duration(seconds: 1)),
      isCurrent: () => true,
    );
    final accountBStore = FriendsStore(
      database: database,
      owner: FriendOwner(projectRef: project, userId: accountB),
    );
    final otherProjectStore = FriendsStore(
      database: database,
      owner: FriendOwner(projectRef: 'other-project', userId: accountA),
    );
    addTearDown(accountBStore.dispose);
    addTearDown(otherProjectStore.dispose);

    expect(
        (await store.list(FriendListKind.accepted)).single.profile.id, peer(1));
    expect(await accountBStore.list(FriendListKind.accepted), isEmpty);
    expect(await otherProjectStore.list(FriendListKind.accepted), isEmpty);
  });

  test('older snapshot cannot regress an accepted relationship to pending',
      () async {
    final accepted = connection(
      1,
      updatedAt: baseTime.add(const Duration(minutes: 5)),
    );
    await store.reconcileSnapshot(
      kind: FriendListKind.accepted,
      connections: [accepted],
      refreshStartedAt: baseTime,
      completedAt: baseTime.add(const Duration(minutes: 6)),
      isCurrent: () => true,
    );
    await store.reconcileSnapshot(
      kind: FriendListKind.incoming,
      connections: [
        connection(
          1,
          state: FriendRelationshipState.incomingPending,
          updatedAt: baseTime.add(const Duration(minutes: 4)),
        ),
      ],
      refreshStartedAt: baseTime,
      completedAt: baseTime.add(const Duration(minutes: 7)),
      isCurrent: () => true,
    );

    expect((await store.list(FriendListKind.accepted)).single.state,
        FriendRelationshipState.accepted);
    expect(await store.list(FriendListKind.incoming), isEmpty);
  });

  test('duplicate peers reject the whole snapshot', () async {
    await expectLater(
      store.reconcileSnapshot(
        kind: FriendListKind.accepted,
        connections: [connection(1), connection(1)],
        refreshStartedAt: baseTime,
        completedAt: baseTime,
        isCurrent: () => true,
      ),
      throwsA(isA<FriendDataException>()),
    );
    expect(await store.list(FriendListKind.accepted), isEmpty);
  });

  test('repository continues short pages until empty and commits once',
      () async {
    remote.pages[FriendListKind.accepted] = [
      FriendPage(items: [connection(2), connection(1)]),
      FriendPage(items: [
        connection(3, updatedAt: baseTime.subtract(const Duration(minutes: 1))),
      ]),
      FriendPage(items: const []),
    ];

    await repository.refresh(FriendListKind.accepted);

    expect(remote.listCalls, 3);
    expect(
      (await repository.readCached(FriendListKind.accepted))
          .map((item) => item.profile.id)
          .toSet(),
      {peer(1), peer(2), peer(3)},
    );
  });

  test('account switch rejects an in-flight response before cache commit',
      () async {
    final barrier = Completer<FriendPage>();
    remote.acceptedBarrier = barrier;
    final refresh = repository.refresh(FriendListKind.accepted);
    await Future<void>.delayed(Duration.zero);
    active = false;
    barrier.complete(FriendPage(items: [connection(1)]));

    await expectLater(refresh, throwsA(isA<FriendRefreshSuperseded>()));
    expect(await store.list(FriendListKind.accepted), isEmpty);
  });

  test('concurrent refreshes for one list share a single remote operation',
      () async {
    final barrier = Completer<FriendPage>();
    remote.acceptedBarrier = barrier;
    final first = repository.refresh(FriendListKind.accepted);
    final second = repository.refresh(FriendListKind.accepted);
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(remote.listCalls, 1);
    remote.acceptedBarrier = null;
    remote.pages[FriendListKind.accepted] = [FriendPage(items: const [])];
    barrier.complete(FriendPage(items: [connection(1)]));
    await Future.wait([first, second]);
    expect(remote.listCalls, 2);
  });

  test('cold reopen reads cached friends offline without remote calls',
      () async {
    await store.reconcileSnapshot(
      kind: FriendListKind.accepted,
      connections: [connection(1)],
      refreshStartedAt: baseTime,
      completedAt: baseTime.add(const Duration(seconds: 1)),
      isCurrent: () => true,
    );
    await repository.dispose();
    await local.close();

    database = await local.open();
    store = FriendsStore(
      database: database,
      owner: FriendOwner(projectRef: project, userId: accountA),
    );
    remote = FakeFriendsGateway();
    repository = CachedFriendsRepository(
      remote: remote,
      store: store,
      isCurrentSession: () => true,
    );

    expect(
        (await repository.readCached(FriendListKind.accepted))
            .single
            .profile
            .id,
        peer(1));
    expect(remote.listCalls + remote.otherCalls, 0);
  });
}
