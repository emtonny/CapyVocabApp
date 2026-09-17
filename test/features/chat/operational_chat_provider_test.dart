import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:capy_vocab/features/chat/data/chat_network_status_native.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_supabase_gateway.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:capy_vocab/features/language_profile/application/language_profile_store.dart';
import 'package:capy_vocab/features/language_profile/domain/entities/language_profile.dart';
import 'package:capy_vocab/features/language_profile/presentation/language_profile_provider.dart';
import 'operational_chat_relay_test.dart' as f;
import 'operational_chat_supabase_gateway_test.dart' as auth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  test('Web keeps chat sync active while hidden; native pauses', () {
    for (final state in AppLifecycleState.values) {
      expect(
        operationalChatRuntimeActiveForLifecycle(state, web: true),
        isTrue,
      );
    }
    expect(
      operationalChatRuntimeActiveForLifecycle(
        AppLifecycleState.resumed,
        web: false,
      ),
      isTrue,
    );
    expect(
      operationalChatRuntimeActiveForLifecycle(
        AppLifecycleState.hidden,
        web: false,
      ),
      isFalse,
    );
    expect(
      operationalChatRuntimeActiveForLifecycle(null, web: false),
      isTrue,
    );
  });
  test('disabled runtime never resolves SDK or opens any database', () async {
    final container = ProviderContainer(overrides: [
      operationalChatEnabledProvider.overrideWithValue(false),
      operationalChatClientProvider
          .overrideWith((_) => throw StateError('SDK must not resolve.')),
      operationalChatDatabaseProvider
          .overrideWith((_) => throw StateError('DB must not resolve.')),
    ]);
    final listener = container.listen(
        operationalChatCoordinatorProvider, (previous, next) {});
    try {
      expect(await container.read(operationalChatCoordinatorProvider.future),
          isNull);
    } finally {
      listener.close();
      container.dispose();
    }
  });
  test('Production is denied even when CHAT_RELAY_ENABLED is true', () async {
    var calls = 0;
    final httpClient = MockClient((_) async {
      calls++;
      return auth.jsonResponse([]);
    });
    final client = SupabaseClient(
        'https://vmxonxqxrlkssdzsucrg.supabase.co', 'sb_publishable_test',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    final container = ProviderContainer(overrides: [
      operationalChatEnabledProvider.overrideWithValue(true),
      operationalChatForegroundProvider.overrideWith((_) => true),
      operationalChatClientProvider.overrideWithValue(client),
      operationalChatDatabaseProvider
          .overrideWith((_) => throw StateError('DB must not open.')),
    ]);
    final listener = container.listen(
        operationalChatCoordinatorProvider, (previous, next) {});
    try {
      expect(await container.read(operationalChatCoordinatorProvider.future),
          isNull);
      expect(container.read(operationalChatOwnerProvider), isNull);
      expect(calls, 0);
    } finally {
      listener.close();
      container.dispose();
      await client.dispose();
      httpClient.close();
    }
  });
  test(
      'Android network gate reuses local channel and fails closed on missing plugin',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.capyvocab.app/network_status');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls++;
      expect(call.method, 'isNetworkAvailable');
      return false;
    });
    try {
      expect(await chatNetworkAvailable(), isFalse);
      expect(calls, 1);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await chatNetworkAvailable(), isFalse);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('SDK auth + real SQLite + cache-only profile wiring', () {
    late Directory directory;
    late OperationalChatDatabase local;
    late SupabaseClient client;
    late MockClient httpClient;
    late MemoryLanguageProfileStore profiles;
    late ProviderContainer container;
    late List<http.Request> requests;
    late Session nextSession;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('capy_chat_provider_');
      local = OperationalChatDatabase(
          factory: databaseFactoryFfi, path: '${directory.path}/chat.db');
      requests = [];
      nextSession = auth.session(f.a);
      httpClient = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(nextSession.toJson()), 200,
            headers: {'content-type': 'application/json'}, request: request);
      });
      client = SupabaseClient(
          'https://${OperationalChatSupabaseGateway.stagingRef}.supabase.co',
          'sb_publishable_test',
          httpClient: httpClient,
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      await client.auth.recoverSession(jsonEncode(auth
          .session(f.a)
          .copyWith(refreshToken: 'synthetic-refresh')
          .toJson()));
      profiles = MemoryLanguageProfileStore();
      await profiles.setProfile(const LanguageProfile(
          userId: f.a, nativeLanguageCode: 'vi', learningLanguageCode: 'en'));
      container = ProviderContainer(overrides: [
        operationalChatEnabledProvider.overrideWithValue(true),
        operationalChatForegroundProvider.overrideWith((_) => true),
        operationalChatClientProvider.overrideWithValue(client),
        operationalChatDatabaseProvider.overrideWith((_) async => local),
        operationalChatNetworkProvider.overrideWithValue(() async => false),
        languageProfileStoreProvider.overrideWithValue(profiles),
        languageProfileRepositoryProvider.overrideWith(
            (_) => throw StateError('No profile API on chat reads.')),
      ]);
    });
    tearDown(() async {
      container.dispose();
      await client.dispose();
      httpClient.close();
      profiles.dispose();
      await local.close();
      await directory.delete(recursive: true);
    });
    ChatOwner owner(String user) => ChatOwner(
        projectRef: OperationalChatSupabaseGateway.stagingRef, userId: user);

    test('inbox/detail/enqueue/re-read use zero HTTP/profile requests offline',
        () async {
      final keep = container.listen(
          operationalChatCoordinatorProvider, (previous, next) {});
      final coordinator =
          (await container.read(operationalChatCoordinatorProvider.future))!;
      try {
        await coordinator.store.cacheConversation(
            ChatConversation(id: f.conversation, peerId: f.b));
        await coordinator.enqueue(
            conversationId: f.conversation, rawText: 'k bro?');
        final inbox = container.listen(
            operationalChatInboxProvider(owner(f.a)), (previous, next) {});
        final detail = container.listen(
            operationalChatMessagesProvider((owner(f.a), f.conversation)),
            (previous, next) {});
        try {
          expect(
              (await container
                      .read(operationalChatInboxProvider(owner(f.a)).future))
                  .single
                  .id,
              f.conversation);
          expect(
              (await container.read(operationalChatMessagesProvider(
                      (owner(f.a), f.conversation)).future))
                  .single
                  .rawText,
              'k bro?');
          // Runtime timer may have already observed offline and entered backoff.
          // The contract is zero requests/attempts, not racing its first tick.
          await coordinator.synchronize();
          expect(
              (await coordinator.store.due(DateTime.now().toUtc()))
                  .single
                  .attemptCount,
              0);
          expect(requests, isEmpty);
        } finally {
          inbox.close();
          detail.close();
        }
      } finally {
        await coordinator.dispose();
        keep.close();
      }
    });
    test('account change cannot expose A cache or enqueue via old runtime',
        () async {
      final keep = container.listen(
          operationalChatCoordinatorProvider, (previous, next) {});
      final old =
          (await container.read(operationalChatCoordinatorProvider.future))!;
      await old.store
          .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
      await old.enqueue(conversationId: f.conversation, rawText: 'A only');
      await client.auth.recoverSession(jsonEncode(auth.session(f.b).toJson()));
      await Future<void>.delayed(Duration.zero);
      try {
        expect(container.read(operationalChatOwnerProvider), owner(f.b));
        await expectLater(
            old.enqueue(conversationId: f.conversation, rawText: 'stale'),
            throwsStateError);
        final next =
            (await container.read(operationalChatCoordinatorProvider.future))!;
        try {
          expect(next.store.owner, owner(f.b));
          expect(await next.store.conversations(), isEmpty);
          expect(await next.store.messages(f.conversation), isEmpty);
          await expectLater(
              next.enqueue(
                  conversationId: f.conversation, rawText: 'missing B profile'),
              throwsStateError);
          expect(requests, isEmpty);
        } finally {
          await next.dispose();
        }
      } finally {
        await old.dispose();
        keep.close();
      }
    });
    test(
        'SDK token refresh replaces gateway/runtime but preserves same-owner cache',
        () async {
      final keep = container.listen(
          operationalChatCoordinatorProvider, (previous, next) {});
      final old =
          (await container.read(operationalChatCoordinatorProvider.future))!;
      await old.store
          .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
      final queued =
          await old.enqueue(conversationId: f.conversation, rawText: 'durable');
      final header = base64Url.encode(utf8.encode('{"revision":2}'));
      nextSession = auth.session(f.a).copyWith(
          accessToken: '$header.${auth.token(f.a).split('.')[1]}.test',
          refreshToken: 'synthetic-refresh');
      await client.auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      try {
        final next =
            (await container.read(operationalChatCoordinatorProvider.future))!;
        try {
          expect(identical(next, old), isFalse);
          expect(
              (await next.store.messages(f.conversation)).single.id, queued.id);
          expect(requests.length, 1);
          expect(requests.single.url.path, '/auth/v1/token');
          await expectLater(
              old.enqueue(conversationId: f.conversation, rawText: 'stale'),
              throwsStateError);
        } finally {
          await next.dispose();
        }
      } finally {
        await old.dispose();
        keep.close();
      }
    });
    test(
        'foreground state disposes runtime and resume gets fresh runtime without losing cache',
        () async {
      final keep = container.listen(
          operationalChatCoordinatorProvider, (previous, next) {});
      final old =
          (await container.read(operationalChatCoordinatorProvider.future))!;
      await old.store
          .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
      await old.enqueue(
          conversationId: f.conversation, rawText: 'before pause');
      container.read(operationalChatForegroundProvider.notifier).state = false;
      expect(await container.read(operationalChatCoordinatorProvider.future),
          isNull);
      await expectLater(
          old.enqueue(conversationId: f.conversation, rawText: 'paused'),
          throwsStateError);
      container.read(operationalChatForegroundProvider.notifier).state = true;
      final next =
          (await container.read(operationalChatCoordinatorProvider.future))!;
      try {
        expect(identical(next, old), isFalse);
        expect((await next.store.messages(f.conversation)).single.rawText,
            'before pause');
        expect(requests, isEmpty);
      } finally {
        await old.dispose();
        await next.dispose();
        keep.close();
      }
    });
  });
}
