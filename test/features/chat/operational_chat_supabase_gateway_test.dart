import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_supabase_gateway.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';

const a = '10000000-0000-0000-0000-000000000001';
const b = '10000000-0000-0000-0000-000000000002';
const conversation = '20000000-0000-0000-0000-000000000001';
String uuid(int n) =>
    '30000000-0000-0000-0000-${n.toString().padLeft(12, '0')}';
final instant = DateTime.utc(2026, 9, 15);
String token(String user) => '${base64Url.encode(utf8.encode('{}'))}.'
    '${base64Url.encode(utf8.encode(jsonEncode({
          'sub': user,
          'exp': 4102444800
        })))}.test';
Session session(String user) => Session(
    accessToken: token(user),
    tokenType: 'bearer',
    user: User(
        id: user,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: instant.toIso8601String()));
OperationalChatMessage message(int n) => OperationalChatMessage(
    id: uuid(n),
    conversationId: conversation,
    senderId: a,
    rawText: '  k bro? 😀  ',
    sourceLanguageCode: 'vi',
    clientGeneratedId: uuid(n + 1000),
    clientCreatedAt: instant);
Map<String, dynamic> remote(int n) => {
      ...message(n).insertPayload,
      'sent_at': instant.toIso8601String(),
      'deleted_at': null,
      'moderation_state': 'visible'
    };
Map<String, dynamic> chatRow(
        {String id = conversation, String low = a, String high = b}) =>
    {
      'id': id,
      'kind': 'direct',
      'participant_low': low,
      'participant_high': high,
      'last_message_at': null
    };
http.Response jsonResponse(Object? value, [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
http.Response failure(String code, [int status = 403]) => jsonResponse({
      'code': code,
      'message': 'Synthetic provider error',
      'details': null,
      'hint': null
    }, status);
Matcher relayFailure(ChatRelayFailureKind kind) =>
    throwsA(isA<ChatRelayException>()
        .having((error) => error.kind, 'safe category', kind));

void main() {
  late OperationalChatSupabaseGateway gateway;
  late MockClient client;
  late bool active;
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) handler;
  setUp(() {
    active = true;
    requests = [];
    handler = (_) => jsonResponse([]);
    client = MockClient((request) async {
      requests.add(request);
      final response = await handler(request);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: request);
    });
    gateway = OperationalChatSupabaseGateway.staging(
        owner: ChatOwner(
            projectRef: OperationalChatSupabaseGateway.stagingRef, userId: a),
        session: session(a),
        publishableKey: 'sb_publishable_test',
        isCurrentSession: () => active,
        httpClient: client);
  });
  tearDown(() async {
    await gateway.dispose();
    client.close();
  });

  test('construction does not request and rejects Production/mismatched owner',
      () {
    expect(requests, isEmpty);
    for (final owner in [
      ChatOwner(projectRef: 'vmxonxqxrlkssdzsucrg', userId: a),
      ChatOwner(
          projectRef: OperationalChatSupabaseGateway.stagingRef, userId: b)
    ]) {
      expect(
          () => OperationalChatSupabaseGateway.staging(
              owner: owner,
              session: session(a),
              publishableKey: 'sb_publishable_test',
              isCurrentSession: () => true),
          throwsFormatException);
    }
  });
  test('insert preserves raw and sends only permitted columns with bound JWT',
      () async {
    handler = (_) => jsonResponse(remote(1), 201);
    final ack = await gateway.send(message(1));
    final request = requests.single;
    expect(request.url.host,
        '${OperationalChatSupabaseGateway.stagingRef}.supabase.co');
    expect(request.headers['Authorization'], 'Bearer ${token(a)}');
    expect(request.method, 'POST');
    expect(jsonDecode(request.body), message(1).insertPayload);
    expect(ack.rawText, message(1).rawText);
    expect(ack.sendStatus, ChatSendStatus.sent);
  });
  test('duplicate retries read sender/client key canonical row, never upsert',
      () async {
    handler = (request) => request.method == 'POST'
        ? failure('23505', 409)
        : jsonResponse({...remote(1), 'id': uuid(99)});
    expect((await gateway.send(message(1))).id, uuid(99));
    expect(requests.map((r) => r.method), ['POST', 'GET']);
    expect(requests.last.url.queryParameters['sender_id'], 'eq.$a');
    expect(requests.last.url.queryParameters['client_generated_id'],
        'eq.${uuid(1001)}');
    expect(requests.first.headers['Prefer'],
        isNot(contains('resolution=merge-duplicates')));
  });
  test('duplicate hidden row denied and conflicting canonical text rejected',
      () async {
    handler = (request) =>
        request.method == 'POST' ? failure('23505', 409) : jsonResponse(null);
    await expectLater(
        gateway.send(message(1)), relayFailure(ChatRelayFailureKind.denied));
    handler = (request) => request.method == 'POST'
        ? failure('23505', 409)
        : jsonResponse({...remote(1), 'raw_text': 'rewrite'});
    await expectLater(gateway.send(message(1)), throwsFormatException);
  });
  test('wrong sender rejected without HTTP', () {
    final own = message(1);
    final wrong = OperationalChatMessage(
        id: own.id,
        conversationId: conversation,
        senderId: b,
        rawText: own.rawText,
        sourceLanguageCode: 'en',
        clientGeneratedId: own.clientGeneratedId,
        clientCreatedAt: instant);
    expect(() => gateway.send(wrong), throwsFormatException);
    expect(requests, isEmpty);
  });
  for (final code in ['42501', '22023', '23503', '23514']) {
    test('$code is denied with no raw provider exception', () async {
      handler = (_) => failure(code);
      await expectLater(
          gateway.send(message(1)), relayFailure(ChatRelayFailureKind.denied));
    });
  }
  for (final code in ['PGRST301', 'PGRST302', 'XX000']) {
    test('$code remains retryable for token refresh/server failure', () async {
      handler = (_) => failure(code, code == 'XX000' ? 500 : 401);
      await expectLater(gateway.send(message(1)),
          relayFailure(ChatRelayFailureKind.retryable));
    });
  }
  test('network exception uses safe retry category', () async {
    handler = (_) => throw const SocketException('Synthetic failure');
    await expectLater(
        gateway.send(message(1)), relayFailure(ChatRelayFailureKind.retryable));
  });
  test('inactive owner issues no requests and rejects already in-flight result',
      () async {
    active = false;
    await expectLater(gateway.fetchConversations(),
        relayFailure(ChatRelayFailureKind.retryable));
    expect(requests, isEmpty);
    active = true;
    final started = Completer<void>();
    final response = Completer<http.Response>();
    handler = (_) {
      started.complete();
      return response.future;
    };
    final result = gateway.send(message(1));
    final assertion =
        expectLater(result, relayFailure(ChatRelayFailureKind.retryable));
    await started.future;
    active = false;
    response.complete(jsonResponse(remote(1), 201));
    await assertion;
    expect(requests.single.headers['Authorization'], 'Bearer ${token(a)}');
  });
  test('bounded timeout cannot return late ACK', () async {
    await gateway.dispose();
    gateway = OperationalChatSupabaseGateway.staging(
        owner: ChatOwner(
            projectRef: OperationalChatSupabaseGateway.stagingRef, userId: a),
        session: session(a),
        publishableKey: 'sb_publishable_test',
        isCurrentSession: () => active,
        requestTimeout: const Duration(milliseconds: 25),
        httpClient: client);
    final response = Completer<http.Response>();
    handler = (_) => response.future;
    await expectLater(
        gateway.send(message(1)), relayFailure(ChatRelayFailureKind.retryable));
    response.complete(jsonResponse(remote(1), 201));
  });
  test('history continues until empty even with server capped short pages',
      () async {
    handler = (request) {
      final cursor = request.url.queryParameters['id'];
      return jsonResponse(cursor == null
          ? [remote(1)]
          : cursor == 'gt.${uuid(1)}'
              ? [remote(2)]
              : []);
    };
    expect((await gateway.fetchHistory(conversation)).map((m) => m.id),
        [uuid(1), uuid(2)]);
    expect(requests.length, 3);
    for (final request in requests) {
      expect(request.url.queryParameters['order'], 'id.asc.nullslast');
      expect(
          request.url.queryParameters['conversation_id'], 'eq.$conversation');
      expect(request.url.queryParameters['deleted_at'], 'is.null');
      expect(request.url.queryParameters['moderation_state'], 'eq.visible');
    }
  });
  test('partial pagination failure returns no complete inventory', () async {
    handler = (request) => request.url.queryParameters['id'] == null
        ? jsonResponse([chatRow()])
        : failure('XX000', 500);
    await expectLater(gateway.fetchConversations(),
        relayFailure(ChatRelayFailureKind.retryable));
    expect(requests.length, 2);
  });
  test('repeated cursor, malformed or foreign conversation fails closed',
      () async {
    handler = (_) => jsonResponse([remote(1)]);
    await expectLater(
        gateway.fetchHistory(conversation), throwsFormatException);
    handler = (request) => jsonResponse(
        request.url.queryParameters['id'] == null
            ? [chatRow(low: b, high: uuid(9))]
            : []);
    await expectLater(gateway.fetchConversations(), throwsFormatException);
    handler = (_) => jsonResponse([
          {'id': 42}
        ]);
    await expectLater(gateway.fetchConversations(), throwsFormatException);
  });
  test('hidden row or history for another chat rejected', () async {
    for (final row in [
      {...remote(1), 'moderation_state': 'held'},
      {...remote(1), 'conversation_id': uuid(500)}
    ]) {
      handler = (request) =>
          jsonResponse(request.url.queryParameters['id'] == null ? [row] : []);
      await expectLater(
          gateway.fetchHistory(conversation), throwsFormatException);
    }
  });
  test('open chat uses server RPC, then validates canonical peer', () async {
    handler = (request) => request.method == 'POST'
        ? jsonResponse(conversation)
        : jsonResponse(chatRow());
    expect((await gateway.openDirectChat(b)).peerId, b);
    expect(requests.first.url.path, '/rest/v1/rpc/open_direct_chat');
    expect(jsonDecode(requests.first.body), {'p_peer_id': b});
    handler = (request) => request.method == 'POST'
        ? jsonResponse(conversation)
        : jsonResponse(chatRow(high: uuid(3)));
    await expectLater(gateway.openDirectChat(b), throwsFormatException);
  });
  test(
      'visibility checks chunk/paginate cached IDs only, no broad delete snapshot',
      () async {
    final ids = List.generate(101, (n) => uuid(n + 1)).toSet();
    handler = (request) {
      // Both inFilter and gt may refer to id; retain both query values.
      final filters = request.url.queryParametersAll['id']!;
      if (filters.any((f) => f.startsWith('gt.'))) return jsonResponse([]);
      final id = RegExp(
              r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
          .firstMatch(filters.single)!
          .group(0)!;
      return jsonResponse([
        {'id': id}
      ]);
    };
    expect(await gateway.visibleCachedIds(conversation, ids),
        {uuid(1), uuid(51), uuid(101)});
    expect(requests.length, 6);
    requests.clear();
    expect(await gateway.visibleCachedIds(conversation, {}), isEmpty);
    expect(requests, isEmpty);
  });
  test('visibility partial failure or unexpected ID cannot approve pruning',
      () async {
    handler = (_) => jsonResponse([
          {'id': uuid(99)}
        ]);
    await expectLater(gateway.visibleCachedIds(conversation, {uuid(1)}),
        throwsFormatException);
    handler = (request) =>
        request.url.queryParametersAll['id']!.any((f) => f.startsWith('gt.'))
            ? failure('XX000', 500)
            : jsonResponse([
                {'id': uuid(1)}
              ]);
    await expectLater(gateway.visibleCachedIds(conversation, {uuid(1)}),
        relayFailure(ChatRelayFailureKind.retryable));
  });
  test('dispose is idempotent and prohibits further HTTP/subscriptions',
      () async {
    await gateway.dispose();
    await gateway.dispose();
    await expectLater(gateway.fetchConversations(),
        relayFailure(ChatRelayFailureKind.retryable));
    expect(() => gateway.signals, throwsA(isA<ChatRelayException>()));
    expect(requests, isEmpty);
  });

  test('membership verification paginates short pages and ignores empty input',
      () async {
    handler = (request) => jsonResponse(
        request.url.queryParametersAll['id']!.any((f) => f.startsWith('gt.'))
            ? []
            : [
                {'id': conversation}
              ]);
    expect(
        await gateway.visibleConversationIds({conversation}), {conversation});
    expect(requests.length, 2);
    requests.clear();
    expect(await gateway.visibleConversationIds({}), isEmpty);
    expect(requests, isEmpty);
  });
  test('membership verification rejects IDs outside the captured inventory',
      () async {
    handler = (_) => jsonResponse([
          {'id': uuid(99)}
        ]);
    await expectLater(
        gateway.visibleConversationIds({conversation}), throwsFormatException);
  });

  test(
      'SDK Realtime joins one channel, restarts a fresh socket, detaches and reattaches',
      () async {
    await gateway.dispose();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final joins = <Map<String, dynamic>>[];
    final left = Completer<void>();
    final secondLeft = Completer<void>();
    var leaveCount = 0;
    String? topic;
    Object? joinRef;
    final serverSubscription = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((frame) {
        final decoded = jsonDecode(frame as String);
        final Map<String, dynamic> data = decoded is List
            ? {
                'join_ref': decoded[0],
                'ref': decoded[1],
                'topic': decoded[2],
                'event': decoded[3],
                'payload': decoded[4]
              }
            : Map<String, dynamic>.from(decoded as Map);
        final isJoin = data['event'] == 'phx_join';
        if (data['event'] == 'phx_leave') {
          // SDK settles unsubscribe locally once its channel becomes leaving.
          // Verify the leave frame, but do not reply into its closing socket.
          leaveCount++;
          if (leaveCount == 1) left.complete();
          if (leaveCount == 2) secondLeft.complete();
          return;
        }
        if (isJoin) {
          joins.add(data);
          topic = data['topic'] as String;
          joinRef = data['join_ref'];
        }
        final filters = isJoin
            ? (data['payload']['config']['postgres_changes'] as List)
            : [];
        final payload = {
          'status': 'ok',
          'response': isJoin
              ? {
                  'postgres_changes': [
                    for (var n = 0; n < filters.length; n++)
                      {
                        ...Map<String, dynamic>.from(filters[n] as Map),
                        'id': n + 1
                      }
                  ]
                }
              : {}
        };
        if (socket.readyState == WebSocket.open) {
          socket.add(jsonEncode(decoded is List
              ? [
                  data['join_ref'],
                  data['ref'],
                  data['topic'],
                  'phx_reply',
                  payload
                ]
              : {
                  'join_ref': data['join_ref'],
                  'ref': data['ref'],
                  'topic': data['topic'],
                  'event': 'phx_reply',
                  'payload': payload
                }));
        }
      });
    });
    final defaultTransport = RealtimeClient('ws://localhost').transport;
    gateway = OperationalChatSupabaseGateway.staging(
        owner: ChatOwner(
            projectRef: OperationalChatSupabaseGateway.stagingRef, userId: a),
        session: session(a),
        publishableKey: 'sb_publishable_test',
        isCurrentSession: () => active,
        httpClient: client,
        realtimeOptions: RealtimeClientOptions(
            timeout: const Duration(seconds: 1),
            disconnectOnEmptyChannelsAfter: Duration.zero,
            transport: (_, headers) =>
                defaultTransport('ws://127.0.0.1:${server.port}', headers)));
    final received = <ChatRemoteSignal>[];
    final connected = Completer<void>();
    final reconnected = Completer<void>();
    final changed = Completer<void>();
    final subscription = gateway.signals.listen((signal) {
      received.add(signal);
      if (signal == ChatRemoteSignal.connected &&
          received.where((s) => s == ChatRemoteSignal.connected).length == 2 &&
          !reconnected.isCompleted) {
        reconnected.complete();
      }
      if (signal == ChatRemoteSignal.connected && !connected.isCompleted) {
        connected.complete();
      }
      if (signal == ChatRemoteSignal.changed && !changed.isCompleted) {
        changed.complete();
      }
    });
    final second = gateway.signals.listen((_) {});
    try {
      await connected.future.timeout(const Duration(seconds: 3),
          onTimeout: () => throw StateError('Initial connect timed out.'));
      expect(joins.length, 1);
      expect(joins.single['payload']['access_token'], token(a));
      expect(
          (joins.single['payload']['config']['postgres_changes'] as List)
              .map((row) => row['table'])
              .toSet(),
          {'chat_conversations', 'chat_members', 'chat_operational_messages'});
      final payload = {
        'ids': [3],
        'data': {
          'schema': 'public',
          'table': 'chat_operational_messages',
          'type': 'INSERT',
          'commit_timestamp': instant.toIso8601String(),
          'columns': [],
          'record': {},
          'old_record': {}
        }
      };
      // SDK 2.x protocol is positional; accept both layouts in fixture join above.
      sockets.last
          .add(jsonEncode([joinRef, null, topic, 'postgres_changes', payload]));
      await changed.future.timeout(const Duration(seconds: 3),
          onTimeout: () => throw StateError('Change signal timed out.'));
      await gateway.restartRealtime();
      await reconnected.future.timeout(const Duration(seconds: 3));
      expect(joins.length, 2);
      expect(joins.last['payload']['access_token'], token(a));
      active = false;
      final count = received.length;
      sockets.last
          .add(jsonEncode([joinRef, null, topic, 'postgres_changes', payload]));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(received.length, count);
      await second.cancel();
      await subscription.cancel();
      await left.future.timeout(const Duration(seconds: 3));
      active = true;
      expect(await gateway.signals.first.timeout(const Duration(seconds: 3)),
          ChatRemoteSignal.connected);
      expect(joins.length, 3);
      await secondLeft.future.timeout(const Duration(seconds: 3));
    } finally {
      await second.cancel();
      await subscription.cancel();
      await gateway.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
