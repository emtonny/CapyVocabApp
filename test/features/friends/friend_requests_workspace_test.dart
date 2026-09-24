import 'dart:async';

import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/repositories/friends_repository.dart';
import 'package:capy_vocab/features/friends/presentation/providers/accepted_friends_provider.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friend_requests_provider.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friends_provider.dart';
import 'package:capy_vocab/features/friends/presentation/screens/friends_leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const peerId = '20000000-0000-4000-8000-000000000001';
const peerTwoId = '30000000-0000-4000-8000-000000000001';
const conversationId = '40000000-0000-4000-8000-000000000001';
final testOwner = FriendOwner(
  projectRef: 'nxteaznowkfennxpqjmt',
  userId: ownerId,
);
final activeOwnerProvider = StateProvider<FriendOwner?>((_) => testOwner);

FriendConnection request(
  FriendListKind kind, {
  String id = peerId,
  String displayName = 'Bạn Nai',
}) {
  return FriendConnection(
    profile: FriendPublicProfile(
      id: id,
      displayName: displayName,
      username: 'ban_nai',
      avatarUrl: null,
      studyPoints: 42,
      streakDays: 7,
      userLevel: 3,
    ),
    state: kind.relationshipState,
    updatedAt: DateTime.utc(2026, 9, 22, 12),
  );
}

final class WorkspaceFriendsRepository implements FriendsRepository {
  WorkspaceFriendsRepository({
    List<FriendConnection> incoming = const [],
    List<FriendConnection> outgoing = const [],
    List<FriendConnection> accepted = const [],
  }) : cache = {
          FriendListKind.incoming: incoming,
          FriendListKind.outgoing: outgoing,
          FriendListKind.accepted: accepted,
        };

  final Map<FriendListKind, List<FriendConnection>> cache;
  final signals = StreamController<FriendRemoteSignal>.broadcast(sync: true);
  final controllers = {
    for (final kind in FriendListKind.values)
      kind: StreamController<List<FriendConnection>>.broadcast(sync: true),
  };
  final responses = <FriendDecision>[];
  Completer<FriendMutationResult>? responseBarrier;
  List<FriendConnection>? acceptedOnNextRefresh;

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
    if (kind == FriendListKind.accepted && acceptedOnNextRefresh != null) {
      cache[kind] = acceptedOnNextRefresh!;
      acceptedOnNextRefresh = null;
    }
    controllers[kind]!.add(List.unmodifiable(cache[kind]!));
  }

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) {
    responses.add(decision);
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

Future<ProviderContainer> pumpWorkspace(
  WidgetTester tester,
  WorkspaceFriendsRepository repository, {
  Future<bool> Function()? networkAvailable,
  FriendChatAccess chatAccess = const FriendChatAccess.unavailable(),
}) async {
  final container = ProviderContainer(
    overrides: [
      friendsEnabledProvider.overrideWithValue(true),
      friendsOwnerProvider.overrideWith(
        (ref) => ref.watch(activeOwnerProvider),
      ),
      friendsRepositoryProvider.overrideWith(
        (ref, owner) async => repository,
      ),
      friendsNetworkProvider.overrideWithValue(
        networkAvailable ?? () async => true,
      ),
      friendChatAccessProvider.overrideWith((ref, owner) => chatAccess),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(repository.dispose);
  final router = GoRouter(
    initialLocation: '/friends',
    routes: [
      GoRoute(
        path: '/friends',
        builder: (_, __) => const FriendsLeaderboardScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (_, state) => Scaffold(
          body: Text('Chat ${state.pathParameters['conversationId']}'),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Cài đặt thử nghiệm')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('320px large text renders badge, public profile and 48dp actions',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    final semantics = tester.ensureSemantics();
    final repository = WorkspaceFriendsRepository(
      incoming: [request(FriendListKind.incoming)],
    );

    await pumpWorkspace(tester, repository);

    expect(find.byKey(const Key('friend-incoming-badge')), findsOneWidget);
    expect(find.text('Bạn Nai'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('friend-accept-$peerId')))
          .height,
      48,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('friend-reject-$peerId')))
          .height,
      48,
    );
    final profile = tester.getSemantics(
      find.byKey(const ValueKey('friend-request-$peerId')),
    );
    expect(profile.label, contains('streak 7 ngày'));
    expect(profile.label, isNot(contains('@example.com')));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('double accept locks one row and removes it after server success',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 1000);
    final repository = WorkspaceFriendsRepository(
      incoming: [
        request(FriendListKind.incoming),
        request(
          FriendListKind.incoming,
          id: peerTwoId,
          displayName: 'Bạn Hươu',
        ),
      ],
    );
    await pumpWorkspace(tester, repository);

    final accept = find.byKey(const ValueKey('friend-accept-$peerId'));
    await tester.tap(accept);
    await tester.tap(accept);
    await tester.pump();

    expect(repository.responses, [FriendDecision.accept]);
    expect(
      tester.widget<FilledButton>(accept).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('friend-accept-$peerTwoId')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('friend-reject-$peerId')),
          )
          .onPressed,
      isNull,
    );

    repository.responseBarrier!.complete(FriendMutationResult.accepted);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('friend-request-$peerId')), findsNothing);
    expect(
      find.byKey(const ValueKey('friend-request-$peerTwoId')),
      findsOneWidget,
    );
    expect(find.text('Đã chấp nhận lời mời kết bạn.'), findsOneWidget);
  });

  testWidgets('outgoing tab shows pending request without mutation controls',
      (tester) async {
    final repository = WorkspaceFriendsRepository(
      outgoing: [request(FriendListKind.outgoing)],
    );
    await pumpWorkspace(tester, repository);

    await tester.tap(find.byKey(const Key('friend-outgoing-tab')));
    await tester.pumpAndSettle();

    expect(find.text('Đã gửi · đang chờ phản hồi'), findsOneWidget);
    expect(find.text('Chấp nhận'), findsNothing);
    expect(find.text('Từ chối'), findsNothing);

    await tester.tap(find.byKey(const Key('friend-accepted-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accepted-friends-empty')), findsOneWidget);
  });

  testWidgets('accepted tab renders public profile and a 48dp Chat action',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    final semantics = tester.ensureSemantics();
    final repository = WorkspaceFriendsRepository(
      accepted: [request(FriendListKind.accepted)],
    );
    await pumpWorkspace(
      tester,
      repository,
      chatAccess: FriendChatAccess.ready((_) async => conversationId),
    );

    await tester.tap(find.byKey(const Key('friend-accepted-tab')));
    await tester.pumpAndSettle();

    final chatButton =
        find.byKey(const ValueKey('accepted-friend-chat-$peerId'));
    expect(find.text('Bạn Nai'), findsOneWidget);
    expect(find.text('@ban_nai'), findsOneWidget);
    expect(tester.getSize(chatButton).height, 48);
    final profile = tester.getSemantics(
      find.byKey(const ValueKey('accepted-friend-$peerId')),
    );
    expect(profile.label, contains('42 điểm'));
    expect(profile.label, isNot(contains('@example.com')));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('accepted peer opens the canonical conversation route',
      (tester) async {
    final repository = WorkspaceFriendsRepository(
      accepted: [request(FriendListKind.accepted)],
    );
    final openedPeers = <String>[];
    await pumpWorkspace(
      tester,
      repository,
      chatAccess: FriendChatAccess.ready((peer) async {
        openedPeers.add(peer);
        return conversationId;
      }),
    );
    await tester.tap(find.byKey(const Key('friend-accepted-tab')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('accepted-friend-chat-$peerId')),
    );
    await tester.pumpAndSettle();

    expect(openedPeers, [peerId]);
    expect(find.text('Chat $conversationId'), findsOneWidget);
  });

  testWidgets('account switch during Chat open cancels old-owner navigation',
      (tester) async {
    final repository = WorkspaceFriendsRepository(
      accepted: [request(FriendListKind.accepted)],
    );
    final barrier = Completer<String>();
    final container = await pumpWorkspace(
      tester,
      repository,
      chatAccess: FriendChatAccess.ready((_) => barrier.future),
    );
    await tester.tap(find.byKey(const Key('friend-accepted-tab')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('accepted-friend-chat-$peerId')),
    );
    await tester.pump();
    container.read(activeOwnerProvider.notifier).state = null;
    await tester.pump();
    barrier.complete(conversationId);
    await tester.pumpAndSettle();

    expect(find.text('Chat $conversationId'), findsNothing);
    expect(find.byKey(const Key('friend-requests-tabs')), findsNothing);
  });

  testWidgets('revoked relation is removed before Chat RPC', (tester) async {
    final repository = WorkspaceFriendsRepository(
      accepted: [request(FriendListKind.accepted)],
    );
    var openCalls = 0;
    await pumpWorkspace(
      tester,
      repository,
      chatAccess: FriendChatAccess.ready((_) async {
        openCalls++;
        return conversationId;
      }),
    );
    await tester.tap(find.byKey(const Key('friend-accepted-tab')));
    await tester.pumpAndSettle();
    repository.acceptedOnNextRefresh = [];

    await tester.tap(
      find.byKey(const ValueKey('accepted-friend-chat-$peerId')),
    );
    await tester.pumpAndSettle();

    expect(openCalls, 0);
    expect(find.byKey(const ValueKey('accepted-friend-$peerId')), findsNothing);
    expect(find.textContaining('đã thay đổi'), findsOneWidget);
  });

  testWidgets('missing language profile blocks Chat and links to Settings',
      (tester) async {
    final repository = WorkspaceFriendsRepository(
      accepted: [request(FriendListKind.accepted)],
    );
    await pumpWorkspace(
      tester,
      repository,
      chatAccess: const FriendChatAccess.ownLanguageProfileRequired(),
    );
    await tester.tap(find.byKey(const Key('friend-accepted-tab')));
    await tester.pumpAndSettle();

    final chatButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('accepted-friend-chat-$peerId')),
    );
    expect(chatButton.onPressed, isNull);
    expect(
        find.text('Thiết lập hồ sơ ngôn ngữ để bắt đầu Chat.'), findsOneWidget);

    await tester.tap(find.text('Mở Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt thử nghiệm'), findsOneWidget);
  });

  testWidgets('account switch removes the old owner request workspace',
      (tester) async {
    final repository = WorkspaceFriendsRepository(
      incoming: [request(FriendListKind.incoming)],
      accepted: [request(FriendListKind.accepted)],
    );
    final container = await pumpWorkspace(tester, repository);
    expect(find.text('Bạn Nai'), findsOneWidget);

    container.read(activeOwnerProvider.notifier).state = null;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('friend-requests-tabs')), findsNothing);
    expect(find.text('Bạn Nai'), findsNothing);
    expect(find.byKey(const Key('accepted-friends-list')), findsNothing);
    expect(find.byKey(const Key('open-add-friend')), findsNothing);
  });

  testWidgets('offline response keeps cached row and shows recovery message',
      (tester) async {
    final repository = WorkspaceFriendsRepository(
      incoming: [request(FriendListKind.incoming)],
    );
    final container = await pumpWorkspace(
      tester,
      repository,
      networkAvailable: () async => false,
    );

    await tester.drag(
      find.byKey(const Key('friend-incoming-list')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friend-accept-$peerId')));
    await tester.pumpAndSettle();

    expect(repository.responses, isEmpty);
    expect(
      container
          .read(friendRequestsProvider(testOwner))
          .incoming
          .single
          .profile
          .id,
      peerId,
    );
    expect(find.textContaining('offline'), findsWidgets);
  });
}
