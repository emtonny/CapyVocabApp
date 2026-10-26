import 'dart:convert';
import 'dart:io';

import 'package:capy_vocab/core/services/tts_service.dart';
import 'package:capy_vocab/features/chat/application/operational_chat_coordinator.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_store.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_supabase_gateway.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_screen.dart';
import 'package:capy_vocab/features/friends/presentation/screens/friends_leaderboard_screen.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friends_provider.dart';
import 'package:capy_vocab/features/language_profile/application/language_profile_store.dart';
import 'package:capy_vocab/features/language_profile/domain/entities/language_profile.dart';
import 'package:capy_vocab/features/language_profile/presentation/language_profile_provider.dart';
import 'package:capy_vocab/features/library/domain/entities/local_vocabulary_match.dart';
import 'package:capy_vocab/features/library/domain/repositories/local_vocabulary_lookup_repository.dart';
import 'package:capy_vocab/features/library/presentation/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'operational_chat_coordinator_test.dart' as c;
import 'operational_chat_relay_test.dart' as f;
import 'operational_chat_supabase_gateway_test.dart' as auth;

final class _RecordingTtsService extends TtsService {
  final calls = <(String, String)>[];

  @override
  Future<void> speak(String text, {String languageCode = 'en'}) async {
    calls.add((text, languageCode));
  }

  @override
  Future<void> stop() async {}
}

final class _RecordingLookupRepository
    implements LocalVocabularyLookupRepository {
  final calls = <(String, String)>[];

  @override
  Future<List<LocalVocabularyMatch>> lookupLocalVocabulary({
    required String userId,
    required String query,
    int limit = 8,
  }) async {
    calls.add((userId, query));
    return [
      LocalVocabularyMatch(
        word: 'Translated',
        meaningVi: 'đã dịch',
        occurrenceCount: 1,
        corrected: false,
      ),
    ];
  }
}

Future<void> flush(WidgetTester tester, {bool Function()? until}) async {
  // FFI completes on real IO, not the widget test's fake clock.
  final deadline = Stopwatch()..start();
  for (var i = 0; i < 5 || (until != null && !until()); i++) {
    if (deadline.elapsed > const Duration(seconds: 30)) {
      fail('Widget/SQLite completion did not reach the expected state.');
    }
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late OperationalChatDatabase local;
  late OperationalChatStore store;
  late OperationalChatCoordinator coordinator;
  late c.Gateway gateway;
  late SupabaseClient client;
  late MockClient httpClient;
  late ProviderContainer container;
  late MemoryLanguageProfileStore profiles;
  late GoRouter router;
  late List<http.Request> requests;
  late bool friendsOnline, relayOnline;
  late _RecordingTtsService speech;
  late _RecordingLookupRepository dictionary;
  final owner = ChatOwner(
      projectRef: OperationalChatSupabaseGateway.stagingRef, userId: f.a);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_chat_widget_');
    local = OperationalChatDatabase(
        factory: databaseFactoryFfi, path: '${directory.path}/chat.db');
    store = OperationalChatStore(database: await local.open(), owner: owner);
    await store
        .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
    await store.cacheProfiles([
      ChatPeerProfile(
        id: f.b,
        displayName: 'Friend',
        username: 'friend',
        avatarUrl: '',
      ),
    ]);
    requests = [];
    friendsOnline = false;
    relayOnline = false;
    speech = _RecordingTtsService();
    dictionary = _RecordingLookupRepository();
    httpClient = MockClient((request) async {
      requests.add(request);
      final after = request.url.queryParameters['friend_id'];
      final peer =
          request.url.queryParameters['user_id'] == 'eq.${f.b}' ? f.a : f.b;
      return http.Response(
          jsonEncode(after == null
              ? [
                  {'friend_id': peer}
                ]
              : []),
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    });
    client = SupabaseClient(
        'https://${owner.projectRef}.supabase.co', 'sb_publishable_test',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    await client.auth.recoverSession(jsonEncode(auth.session(f.a).toJson()));
    profiles = MemoryLanguageProfileStore();
    await profiles.setProfile(const LanguageProfile(
        userId: f.a, nativeLanguageCode: 'vi', learningLanguageCode: 'en'));
    gateway = c.Gateway();
    coordinator = OperationalChatCoordinator(
        store: store,
        remote: gateway,
        isCurrentSession: () => client.auth.currentSession?.user.id == f.a,
        networkAvailable: () async => relayOnline,
        cachedSourceLanguageCode: () =>
            profiles.profileFor(f.a)?.nativeLanguageCode);
    container = ProviderContainer(overrides: [
      operationalChatEnabledProvider.overrideWithValue(true),
      friendsEnabledProvider.overrideWithValue(false),
      operationalChatClientProvider.overrideWithValue(client),
      operationalChatDatabaseProvider.overrideWith((_) async => local),
      operationalChatStoreProvider(owner).overrideWith((_) async => store),
      operationalChatCoordinatorProvider.overrideWith((_) async => coordinator),
      operationalChatProfileRefreshProvider(owner).overrideWith((_) async {}),
      operationalChatNetworkProvider
          .overrideWithValue(() async => friendsOnline),
      operationalChatTtsProvider.overrideWithValue(speech),
      localVocabularyLookupRepositoryProvider
          .overrideWith((_) async => dictionary),
      languageProfileStoreProvider.overrideWithValue(profiles),
      languageProfileRepositoryProvider
          .overrideWith((_) => throw StateError('No profile HTTP.')),
    ]);
    router = GoRouter(initialLocation: '/chat', routes: [
      GoRoute(
          path: '/chat', builder: (_, state) => const OperationalChatScreen()),
      GoRoute(
          path: '/chat/:id',
          builder: (_, state) => OperationalChatScreen(
              conversationId: state.pathParameters['id'])),
      GoRoute(
          path: '/friends',
          builder: (_, state) => const FriendsLeaderboardScreen()),
    ]);
  });
  tearDown(() async {
    router.dispose();
    container.dispose();
    await coordinator.dispose();
    await store.dispose();
    await local.close();
    await client.dispose();
    httpClient.close();
    profiles.dispose();
    await directory.delete(recursive: true);
  });
  Future<void> mount(WidgetTester tester) async {
    // Unmount even after a failed assertion, before the container/FFI teardown.
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: MaterialApp.router(routerConfig: router)));
    await flush(tester,
        until: () => find.byType(CircularProgressIndicator).evaluate().isEmpty);
  }

  testWidgets('offline inbox/detail and raw enqueue use SQLite with zero HTTP',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey(f.conversation)));
    await flush(tester);
    const raw = '  Tối nay đi quẩy k bro? 😀  ';
    await tester.enterText(find.byKey(const Key('chat-compose')), raw);
    await tester.pump();
    expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNotNull);
    await tester.tap(find.byKey(const Key('chat-send')));
    await flush(tester,
        until: () =>
            tester
                .widget<TextField>(find.byKey(const Key('chat-compose')))
                .controller!
                .text
                .isEmpty &&
            find.text(raw).evaluate().isNotEmpty);
    expect(find.text(raw), findsOneWidget);
    expect(
        (tester.widget<TextField>(find.byKey(const Key('chat-compose'))))
            .controller!
            .text,
        isEmpty);
    expect(find.textContaining('Đã lưu trên máy · chờ gửi'), findsOneWidget);
    expect(requests, isEmpty);
    expect(gateway.sends + gateway.pulls + gateway.opens, 0);
    final messages =
        await tester.runAsync(() => store.messages(f.conversation));
    expect(messages!.single.rawText, raw);
    expect(messages.single.attemptCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'route keeps raw selectable and adds cached personalized translation',
      (tester) async {
    await tester.runAsync(() async {
      await store.mergeRemote(f.ack(f.message(1, text: 'sent')));
      await store.mergeTranslations(
        conversationId: f.conversation,
        translations: [
          OperationalChatTranslation(
            id: f.uuid(400),
            messageId: f.uuid(1),
            targetLanguageCode: 'en',
            translatedText: 'translated',
            provider: operationalChatTranslationProvider,
            model: operationalChatTranslationModel,
            promptVersion: operationalChatPromptVersion,
            translatorVersion: operationalChatTranslatorVersion,
            status: ChatTranslationStatus.succeeded,
            attemptCount: 1,
            createdAt: f.instant,
            updatedAt: f.instant,
            completedAt: f.instant,
          ),
        ],
      );
      await store.enqueue(f.message(2, text: 'blocked'));
      await store.fail(f.message(2, text: 'blocked'),
          blocked: true, retryAt: f.instant);
    });
    router.go('/chat/${f.conversation}');
    await mount(tester);
    expect(find.textContaining('Server đã nhận'), findsOneWidget);
    expect(find.textContaining('Không gửi được · bản local được giữ'),
        findsOneWidget);
    final primary = find.byKey(ValueKey('chat-primary-${f.uuid(1)}'));
    final secondary = find.byKey(ValueKey('chat-secondary-${f.uuid(1)}'));
    expect(find.descendant(of: primary, matching: find.text('translated')),
        findsOneWidget);
    expect(find.descendant(of: secondary, matching: find.text('sent')),
        findsOneWidget);
    await tester.tap(find.byKey(
      ValueKey('chat-speak-chat-primary-${f.uuid(1)}'),
    ));
    await tester.pump();
    expect(speech.calls, [('translated', 'en')]);
    expect(find.widgetWithText(SelectableText, 'blocked'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selected English translation opens owner-scoped local lookup',
      (tester) async {
    await tester.runAsync(() async {
      await store.mergeRemote(f.ack(f.message(1, text: 'đã gửi')));
      await store.mergeTranslations(
        conversationId: f.conversation,
        translations: [
          OperationalChatTranslation(
            id: f.uuid(401),
            messageId: f.uuid(1),
            targetLanguageCode: 'en',
            translatedText: 'translated',
            provider: operationalChatTranslationProvider,
            model: operationalChatTranslationModel,
            promptVersion: operationalChatPromptVersion,
            translatorVersion: operationalChatTranslatorVersion,
            status: ChatTranslationStatus.succeeded,
            attemptCount: 1,
            createdAt: f.instant,
            updatedAt: f.instant,
            completedAt: f.instant,
          ),
        ],
      );
    });
    router.go('/chat/${f.conversation}');
    await mount(tester);

    final textFinder = find.byKey(
      ValueKey('chat-text-chat-primary-${f.uuid(1)}'),
    );
    final editable = tester.state<EditableTextState>(find.descendant(
      of: textFinder,
      matching: find.byType(EditableText),
    ));
    final renderEditable = editable.renderEditable;
    final selectionPosition = renderEditable.localToGlobal(
      renderEditable.getLocalRectForCaret(const TextPosition(offset: 1)).center,
    );
    await tester.longPressAt(selectionPosition);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tra từ'));
    await tester.pumpAndSettle();

    expect(dictionary.calls, [(f.a, 'translated')]);
    expect(find.text('Tra từ trên máy'), findsOneWidget);
    expect(find.text('Translated'), findsOneWidget);
    expect(find.text('đã dịch'), findsOneWidget);
    expect(find.textContaining('không dùng mạng'), findsOneWidget);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'unknown language blocks send; cache update enables it without profile API',
      (tester) async {
    await profiles.removeProfile(f.a);
    router.go('/chat/${f.conversation}');
    await mount(tester);
    await tester.enterText(find.byKey(const Key('chat-compose')), 'hello');
    expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNull);
    await profiles.setProfile(const LanguageProfile(
        userId: f.a, nativeLanguageCode: 'vi', learningLanguageCode: 'en'));
    await flush(tester);
    expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNotNull);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'account switch removes A history and draft, including while B cache loads',
      (tester) async {
    await tester.runAsync(
        () => store.mergeRemote(f.ack(f.message(1, text: 'A PRIVATE'))));
    router.go('/chat/${f.conversation}');
    await mount(tester);
    await tester.enterText(find.byKey(const Key('chat-compose')), 'A DRAFT');
    await tester.runAsync(() =>
        client.auth.recoverSession(jsonEncode(auth.session(f.b).toJson())));
    await flush(tester);
    expect(find.text('A PRIVATE'), findsNothing);
    expect(find.text('A DRAFT'), findsNothing);
    expect(find.byKey(const Key('chat-compose')), findsNothing);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('invalid or uncached deep link never exposes compose',
      (tester) async {
    router.go('/chat/not-a-uuid');
    await mount(tester);
    expect(find.text('Không tìm thấy cuộc trò chuyện.'), findsOneWidget);
    expect(find.byKey(const Key('chat-compose')), findsNothing);
    router.go('/chat/${f.uuid(999)}');
    await flush(tester);
    expect(find.byKey(const Key('chat-compose')), findsNothing);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('explicit new-chat picker offline fails promptly with zero HTTP',
      (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const Key('chat-new')));
    await flush(tester);
    expect(find.text('Không tải được danh sách. Thử lại'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'friend fetch is explicit, scoped and exhausts pages even below limit',
      (tester) async {
    friendsOnline = true;
    await mount(tester);
    expect(requests, isEmpty);
    await tester.tap(find.byKey(const Key('chat-new')));
    await flush(tester);
    expect(requests.length, 2);
    expect(requests.first.url.queryParameters['user_id'], 'eq.${f.a}');
    expect(requests.first.url.queryParameters['status'], 'eq.accepted');
    final friendOption = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Friend'),
    );
    expect(friendOption, findsOneWidget);
    await tester.tap(friendOption);
    await flush(tester);
    expect(gateway.opens, 0); // coordinator's local network gate rejects open
    expect(find.textContaining('Chưa mở được chat.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted friend opens canonical detail after SQLite commit',
      (tester) async {
    friendsOnline = true;
    relayOnline = true;
    // Fake gateway creates a new ID; remove the same-peer baseline fixture.
    // Local conversation uniqueness mirrors the canonical direct-chat RPC.
    await tester.runAsync(() => store.database.delete('chat_conversations'));
    await mount(tester);
    await tester.tap(find.byKey(const Key('chat-new')));
    await flush(tester, until: () => find.text('Friend').evaluate().isNotEmpty);
    await tester.tap(find.text('Friend'));
    await flush(tester,
        until: () =>
            find.byKey(const Key('chat-compose')).evaluate().isNotEmpty &&
            find.byType(AlertDialog).evaluate().isEmpty);
    expect(gateway.opens, 1);
    final cached = await tester.runAsync(store.conversations);
    expect(cached!.single.id, f.uuid(500));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('chat-compose')), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/chat/${f.uuid(500)}');
    expect(gateway.sends, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('accepted friend can be selected to create a social group',
      (tester) async {
    friendsOnline = true;
    relayOnline = true;
    await mount(tester);

    await tester.tap(find.byKey(const Key('chat-new-group')));
    await flush(
      tester,
      until: () => find
          .byKey(const ValueKey('social-group-member-${f.b}'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.enterText(
      find.byKey(const Key('social-group-title')),
      'Nhóm cuối tuần',
    );
    final memberTile = find.byKey(const ValueKey('social-group-member-${f.b}'));
    final memberCheckbox = find.descendant(
      of: memberTile,
      matching: find.byType(Checkbox),
    );
    await tester.tap(memberCheckbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(memberCheckbox).value, isTrue);
    await tester.tap(find.byKey(const Key('social-group-create')));
    await flush(
      tester,
      until: () =>
          find.byKey(const Key('chat-compose')).evaluate().isNotEmpty &&
          find.byType(AlertDialog).evaluate().isEmpty,
    );

    expect(gateway.socialCreates, 1);
    expect(gateway.lastSocialTitle, 'Nhóm cuối tuần');
    expect(gateway.lastSocialMembers, [f.b]);
    final cached = await tester.runAsync(store.conversations);
    expect(
      cached!.map((row) => row.id),
      contains(f.uuid(501)),
    );
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/chat/${f.uuid(501)}',
    );
    await tester.tap(find.byKey(const Key('social-group-manage')));
    await flush(
      tester,
      until: () => find
          .byKey(const ValueKey('social-group-profile-${f.b}'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Friend'), findsOneWidget);
    await tester.tap(find.byKey(const Key('social-group-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('social-group-rename-input')), 'Nhóm beta');
    await tester.tap(find.byKey(const Key('social-group-rename-confirm')));
    await flush(
      tester,
      until: () => find.textContaining('Nhóm beta ·').evaluate().isNotEmpty,
    );
    expect(gateway.socialRenames, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  });

  testWidgets('phone and wide layouts fit with keyboard and Unicode send limit',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    router.go('/chat/${f.conversation}');
    tester.view.physicalSize = const Size(320, 740);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await mount(tester);
    await tester.enterText(find.byKey(const Key('chat-compose')), '😀' * 4001);
    await tester.pump();
    expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNull);
    await tester.enterText(find.byKey(const Key('chat-compose')), '😀' * 4000);
    await tester.pump();
    expect(
        tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
        isNotNull);
    expect(tester.getRect(find.byKey(const Key('chat-send'))).right,
        lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.resetViewInsets();
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('chat-compose'))).width,
        lessThan(720));
    expect(tester.takeException(), isNull);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'accepted friends display real scoped peer without a language profile',
      (tester) async {
    friendsOnline = true;
    await profiles.removeProfile(f.a);
    router.go('/friends');
    await mount(tester);
    expect(
        find.byKey(const ValueKey('accepted-friend-${f.b}')), findsOneWidget);
    expect(find.text('Bạn bè đã chấp nhận'), findsOneWidget);
    expect(requests.length, 2);
    expect(requests.every((request) => request.url.path.endsWith('/friends')),
        isTrue);
    expect(requests.first.url.queryParameters['status'], 'eq.accepted');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('friends header opens the full Chat route additively',
      (tester) async {
    router.go('/friends');
    await mount(tester);
    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.byKey(const Key('friends-open-chat')), findsOneWidget);

    await tester.tap(find.byKey(const Key('friends-open-chat')));
    await flush(tester,
        until: () =>
            router.routeInformationProvider.value.uri.path == '/chat' &&
            find.text('Trò chuyện · Beta').evaluate().isNotEmpty);

    expect(router.routeInformationProvider.value.uri.path, '/chat');
    expect(find.text('Trò chuyện · Beta'), findsOneWidget);
    expect(find.byKey(const Key('chat-new')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'friend list switches owners and shows reciprocal peer without A data leakage',
      (tester) async {
    friendsOnline = true;
    router.go('/friends');
    await mount(tester);
    expect(
        find.byKey(const ValueKey('accepted-friend-${f.b}')), findsOneWidget);
    await tester.runAsync(() =>
        client.auth.recoverSession(jsonEncode(auth.session(f.b).toJson())));
    await flush(tester,
        until: () => find
            .byKey(const ValueKey('accepted-friend-${f.a}'))
            .evaluate()
            .isNotEmpty);
    expect(find.byKey(const ValueKey('accepted-friend-${f.b}')), findsNothing);
    expect(
        find.byKey(const ValueKey('accepted-friend-${f.a}')), findsOneWidget);
    expect(
        requests.any(
            (request) => request.url.queryParameters['user_id'] == 'eq.${f.b}'),
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'friends offline state fails promptly with zero HTTP and no fabricated rows',
      (tester) async {
    router.go('/friends');
    await mount(tester);
    expect(find.textContaining('Chưa tải được bạn bè.'), findsOneWidget);
    expect(find.byKey(const Key('accepted-friends-list')), findsNothing);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disabled build never resolves SDK or chat database',
      (tester) async {
    container.dispose();
    container = ProviderContainer(overrides: [
      operationalChatEnabledProvider.overrideWithValue(false),
      friendsEnabledProvider.overrideWithValue(false),
      operationalChatClientProvider
          .overrideWith((_) => throw StateError('No SDK.')),
      operationalChatDatabaseProvider
          .overrideWith((_) => throw StateError('No DB.')),
    ]);
    await mount(tester);
    expect(find.textContaining('Chat chỉ bật'), findsOneWidget);
    expect(find.byKey(const Key('chat-new')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('friends screen exposes one Chat CTA only when relay is enabled',
      (tester) async {
    router.go('/friends');
    await mount(tester);
    expect(find.text('Trò chuyện · Beta'), findsNothing);
    expect(find.byKey(const Key('friends-open-chat')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    container = ProviderContainer(overrides: [
      operationalChatEnabledProvider.overrideWithValue(false),
      friendsEnabledProvider.overrideWithValue(false),
      operationalChatClientProvider
          .overrideWith((_) => throw StateError('No SDK.')),
      operationalChatDatabaseProvider
          .overrideWith((_) => throw StateError('No DB.')),
    ]);
    router.go('/friends');
    await mount(tester);
    expect(find.text('Trò chuyện · Beta'), findsNothing);
    expect(find.byKey(const Key('friends-open-chat')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
