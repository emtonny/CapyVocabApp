import 'dart:async';

import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/repositories/friends_repository.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friends_provider.dart';
import 'package:capy_vocab/features/friends/presentation/screens/friends_leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const peerId = '20000000-0000-4000-8000-000000000001';
final testOwner = FriendOwner(
  projectRef: 'nxteaznowkfennxpqjmt',
  userId: ownerId,
);
final testOwnerProvider = StateProvider<FriendOwner?>((_) => testOwner);

FriendConnection publicResult({
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

final class ImmediateFriendsRepository implements FriendsRepository {
  ImmediateFriendsRepository({this.searchResult});

  FriendConnection? searchResult;
  int searchCalls = 0;
  int sendCalls = 0;
  final sendBarrier = Completer<FriendMutationResult>();

  @override
  Stream<FriendRemoteSignal> get remoteSignals => const Stream.empty();

  @override
  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  }) async {
    searchCalls++;
    return searchResult;
  }

  @override
  Future<FriendMutationResult> sendRequest(String targetUserId) {
    sendCalls++;
    return sendBarrier.future;
  }

  @override
  Future<void> refresh(FriendListKind kind) async {}

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
      throw UnimplementedError();

  @override
  Future<void> syncVerifiedPhone() async {}

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async {}
}

Future<ProviderContainer> pumpFriends(
  WidgetTester tester,
  ImmediateFriendsRepository repository,
) async {
  final container = ProviderContainer(
    overrides: [
      friendsEnabledProvider.overrideWithValue(true),
      operationalChatEnabledProvider.overrideWithValue(false),
      friendsOwnerProvider.overrideWith(
        (ref) => ref.watch(testOwnerProvider),
      ),
      friendsRepositoryProvider.overrideWith(
        (ref, owner) async => repository,
      ),
      friendsNetworkProvider.overrideWithValue(() async => true),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/friends',
    routes: [
      GoRoute(
        path: '/friends',
        builder: (_, __) => const FriendsLeaderboardScreen(),
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
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('phone 320px, large text and keyboard expose only public profile',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    final semantics = tester.ensureSemantics();
    final repository = ImmediateFriendsRepository(searchResult: publicResult());
    await pumpFriends(tester, repository);

    await tester.tap(find.byKey(const Key('open-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('friend-search-field')),
      'ban_nai',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('friend-search-result')), findsOneWidget);
    expect(find.text('Bạn Nai'), findsOneWidget);
    expect(find.text('@ban_nai'), findsOneWidget);
    final resultSemantics =
        tester.getSemantics(find.byKey(const Key('friend-search-result')));
    expect(resultSemantics.label, contains('streak 7 ngày'));
    expect(resultSemantics.label, isNot(contains('@example.com')));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('wide layout constrains modal and method validation is local',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    final repository = ImmediateFriendsRepository(searchResult: publicResult());
    await pumpFriends(tester, repository);

    await tester.tap(find.byKey(const Key('open-add-friend')));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('add-friend-sheet'))).width,
        lessThanOrEqualTo(640));

    await tester.enterText(
      find.byKey(const Key('friend-search-field')),
      'ab',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.searchCalls, 0);
    expect(find.textContaining('3–20 ký tự'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend discovery exposes username only', (tester) async {
    final repository = ImmediateFriendsRepository(searchResult: publicResult());
    await pumpFriends(tester, repository);

    await tester.tap(find.byKey(const Key('open-add-friend')));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.textContaining('username để kết nối'), findsOneWidget);
    expect(find.byKey(const Key('friend-method-email')), findsNothing);
    expect(find.byKey(const Key('friend-method-phone')), findsNothing);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Số điện thoại'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('friend-search-field')),
      'BAN_NAI',
    );
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    expect(repository.searchCalls, 1);
    expect(find.byKey(const Key('friend-search-result')), findsOneWidget);
  });

  const relationshipLabels = <FriendRelationshipState, String>{
    FriendRelationshipState.none: 'Gửi lời mời',
    FriendRelationshipState.outgoingPending: 'Đã gửi',
    FriendRelationshipState.incomingPending: 'Xem lời mời',
    FriendRelationshipState.accepted: 'Đã là bạn',
    FriendRelationshipState.rejected: 'Đã từ chối',
  };
  for (final entry in relationshipLabels.entries) {
    testWidgets('renders ${entry.key.name} as ${entry.value}', (tester) async {
      final repository = ImmediateFriendsRepository(
        searchResult: publicResult(state: entry.key),
      );
      await pumpFriends(tester, repository);
      await tester.tap(find.byKey(const Key('open-add-friend')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('friend-search-field')),
        'ban_nai',
      );
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('friend-result-action')),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('friend-result-action')),
      );
      expect(
        button.onPressed,
        entry.key == FriendRelationshipState.none ||
                entry.key == FriendRelationshipState.incomingPending
            ? isNotNull
            : isNull,
      );
    });
  }

  testWidgets('double tap sends one request and disables the action',
      (tester) async {
    final repository = ImmediateFriendsRepository(searchResult: publicResult());
    await pumpFriends(tester, repository);
    await tester.tap(find.byKey(const Key('open-add-friend')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('friend-search-field')),
      'ban_nai',
    );
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('friend-result-action'));
    await tester.tap(action);
    await tester.tap(action);
    await tester.pump();
    expect(repository.sendCalls, 1);
    expect(find.text('Đang gửi…'), findsOneWidget);
    repository.sendBarrier.complete(FriendMutationResult.outgoingPending);
    await tester.pumpAndSettle();
    expect(repository.sendCalls, 1);
    expect(
      find.descendant(
        of: find.byKey(const Key('friend-result-action')),
        matching: find.text('Đã gửi'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('account switch closes the old owner modal immediately',
      (tester) async {
    final repository = ImmediateFriendsRepository(searchResult: publicResult());
    final container = await pumpFriends(tester, repository);
    await tester.tap(find.byKey(const Key('open-add-friend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-friend-sheet')), findsOneWidget);

    container.read(testOwnerProvider.notifier).state = null;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-friend-sheet')), findsNothing);
    expect(find.byKey(const Key('open-add-friend')), findsNothing);
  });
}
