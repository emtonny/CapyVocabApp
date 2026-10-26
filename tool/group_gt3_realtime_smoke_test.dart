import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef _ProbeResult = ({
  bool delivered,
  List<int> received,
  Map<int, int> visible,
  List<List<RealtimeSubscribeStatus>> statuses,
});

String _required(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('Missing required GT3 smoke environment: $name');
  }
  return value;
}

String _retryMessageId(String messageId) {
  final replacement = messageId.endsWith('0') ? '1' : '0';
  return '${messageId.substring(0, messageId.length - 1)}$replacement';
}

Future<_ProbeResult> _runProbe({
  required String url,
  required String anonKey,
  required List<(String, String)> credentials,
  required String conversationId,
  required String messageId,
  required String marker,
}) async {
  final clients = [
    for (var index = 0; index < credentials.length; index++)
      SupabaseClient(url, anonKey)
  ];
  final channels = <RealtimeChannel>[];
  final statuses = [
    for (var index = 0; index < clients.length; index++)
      <RealtimeSubscribeStatus>[],
  ];

  try {
    for (var index = 0; index < clients.length; index++) {
      final auth = await clients[index].auth.signInWithPassword(
            email: credentials[index].$1,
            password: credentials[index].$2,
          );
      expect(auth.user, isNotNull);
    }

    final subscribed = [
      for (var index = 0; index < clients.length; index++) Completer<void>()
    ];
    final received = [
      for (var index = 0; index < clients.length; index++) Completer<void>()
    ];
    for (var index = 0; index < clients.length; index++) {
      final clientIndex = index;
      final channel = clients[index]
          .channel(
              'gt3-smoke-$clientIndex-${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_operational_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              if (payload.newRecord['id'] == messageId &&
                  !received[clientIndex].isCompleted) {
                received[clientIndex].complete();
              }
            },
          );
      channel.subscribe((status, error) {
        statuses[clientIndex].add(status);
        if (status == RealtimeSubscribeStatus.subscribed &&
            !subscribed[clientIndex].isCompleted) {
          subscribed[clientIndex].complete();
        } else if (status != RealtimeSubscribeStatus.subscribed &&
            !subscribed[clientIndex].isCompleted) {
          subscribed[clientIndex].completeError(
            StateError('GT3 client $clientIndex subscription ended: $status.'),
          );
        }
      });
      channels.add(channel);
    }
    await Future.wait(subscribed.map((ready) => ready.future)).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw StateError(
        'GT3 subscription timeout; statuses=$statuses.',
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));

    final senderId = clients.first.auth.currentUser!.id;
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await clients.first
        .from('chat_operational_messages')
        .insert({
          'id': messageId,
          'conversation_id': conversationId,
          'sender_id': senderId,
          'raw_text': marker,
          'source_language_code': 'vi',
          'client_generated_id': messageId,
          'client_created_at': now,
        })
        .select('id,conversation_id,sender_id,raw_text')
        .single();
    expect(row['id'], messageId);
    expect(row['raw_text'], marker);

    var delivered = true;
    try {
      await Future.wait(received.map((event) => event.future)).timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      delivered = false;
    }

    final visibleByClient = <int, int>{};
    for (var index = 0; index < clients.length; index++) {
      final visible = await clients[index]
          .from('chat_operational_messages')
          .select('id,raw_text')
          .eq('id', messageId);
      visibleByClient[index] = visible.length;
      expect(visible, hasLength(1));
      expect(visible.single['raw_text'], marker);
    }
    return (
      delivered: delivered,
      received: [
        for (var index = 0; index < received.length; index++)
          if (received[index].isCompleted) index,
      ],
      visible: Map<int, int>.unmodifiable(visibleByClient),
      statuses: [
        for (final clientStatuses in statuses)
          List<RealtimeSubscribeStatus>.unmodifiable(clientStatuses),
      ],
    );
  } finally {
    for (var index = 0; index < channels.length; index++) {
      await clients[index].removeChannel(channels[index]);
    }
    for (final client in clients) {
      await client.auth.signOut();
      await client.dispose();
    }
  }
}

void main() {
  test('exact-Staging raw group message reaches three authenticated clients',
      () async {
    final url = _required('CAPY_GT3_SUPABASE_URL');
    final anonKey = _required('CAPY_GT3_ANON_KEY');
    final conversationId = _required('CAPY_GT3_CONVERSATION_ID');
    final messageId = _required('CAPY_GT3_MESSAGE_ID');
    final marker = _required('CAPY_GT3_MESSAGE_MARKER');
    final credentials = [
      (
        _required('CAPY_GT3_TEACHER_EMAIL'),
        _required('CAPY_GT3_TEACHER_PASSWORD')
      ),
      (
        _required('CAPY_GT3_STUDENT_A_EMAIL'),
        _required('CAPY_GT3_STUDENT_A_PASSWORD')
      ),
      (
        _required('CAPY_GT3_STUDENT_B_EMAIL'),
        _required('CAPY_GT3_STUDENT_B_PASSWORD')
      ),
    ];
    final first = await _runProbe(
      url: url,
      anonKey: anonKey,
      credentials: credentials,
      conversationId: conversationId,
      messageId: messageId,
      marker: marker,
    );
    if (!first.delivered) {
      final retry = await _runProbe(
        url: url,
        anonKey: anonKey,
        credentials: credentials,
        conversationId: conversationId,
        messageId: _retryMessageId(messageId),
        marker: '$marker retry',
      );
      if (!retry.delivered) {
        throw StateError(
          'GT3 event timeout after bounded retry; '
          'first_received=${first.received}; first_visible=${first.visible}; '
          'first_statuses=${first.statuses}; retry_received=${retry.received}; '
          'retry_visible=${retry.visible}; retry_statuses=${retry.statuses}.',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
