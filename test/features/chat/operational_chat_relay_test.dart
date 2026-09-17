import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_store.dart';
import 'package:capy_vocab/features/chat/application/operational_chat_relay.dart';

const a = '10000000-0000-0000-0000-000000000001';
const b = '10000000-0000-0000-0000-000000000002';
const outsider = '10000000-0000-0000-0000-000000000003';
const conversation = '20000000-0000-0000-0000-000000000001';
const project = 'ssssssssssssssssssss';
final instant = DateTime.utc(2026, 9, 15, 12);
String uuid(int value) =>
    '30000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';
OperationalChatMessage message(int value,
        {String sender = a,
        String text = 'Tối nay đi quẩy k bro?',
        DateTime? sentAt}) =>
    OperationalChatMessage(
      id: uuid(value),
      conversationId: conversation,
      senderId: sender,
      rawText: text,
      sourceLanguageCode: sender == b ? 'en' : 'vi',
      clientGeneratedId: uuid(value + 1000),
      clientCreatedAt: instant,
      sentAt: sentAt,
      sendStatus: sentAt == null ? ChatSendStatus.pending : ChatSendStatus.sent,
    );
OperationalChatMessage ack(OperationalChatMessage m) => OperationalChatMessage(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.senderId,
      rawText: m.rawText,
      sourceLanguageCode: m.sourceLanguageCode,
      clientGeneratedId: m.clientGeneratedId,
      clientCreatedAt: m.clientCreatedAt,
      sentAt: instant,
      sendStatus: ChatSendStatus.sent,
    );

final class Server implements OperationalChatTransport {
  final rows = <String, OperationalChatMessage>{};
  int calls = 0;
  bool loseFirstResponse = false;
  bool denied = false;
  bool offline = false;
  Completer<void>? barrier;
  @override
  Future<OperationalChatMessage> send(OperationalChatMessage m) async {
    calls++;
    if (barrier != null) await barrier!.future;
    if (denied) throw const ChatRelayException(ChatRelayFailureKind.denied);
    if (offline) throw const ChatRelayException(ChatRelayFailureKind.retryable);
    final existing =
        rows.putIfAbsent('${m.senderId}:${m.clientGeneratedId}', () => ack(m));
    if (loseFirstResponse && calls == 1) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
    return existing;
  }
}

void main() {
  late Directory directory;
  late OperationalChatDatabase local;
  late OperationalChatStore store;
  late Database db;
  late Server server;
  late DateTime now;
  late bool online;
  late bool active;
  var generated = 100;
  OperationalChatRelay relay() => OperationalChatRelay(
      store: store,
      transport: server,
      clock: () => now,
      idGenerator: () => uuid(generated++),
      isCurrentOwner: () => active,
      canReachNetwork: () => online);
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_chat_c3a_');
    local = OperationalChatDatabase(
        factory: databaseFactoryFfi, path: '${directory.path}/chat.db');
    db = await local.open();
    store = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: a));
    await store
        .cacheConversation(ChatConversation(id: conversation, peerId: b));
    server = Server();
    now = instant;
    online = true;
    active = true;
    generated = 100;
  });
  tearDown(() async {
    await store.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  test('separate DB v2 contains operational chat and peer cache only',
      () async {
    final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    expect(rows.map((row) => row['name']).toSet(),
        {'chat_conversations', 'chat_messages', 'chat_peer_profiles'});
    expect(await db.getVersion(), 2);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
  });
  test('raw validation preserves Unicode and counts code points not UTF16', () {
    expect(message(1).rawText, 'Tối nay đi quẩy k bro?');
    expect(
        message(1, text: List.filled(4000, '😀').join()).rawText.runes.length,
        4000);
    expect(() => message(1, text: List.filled(4001, '😀').join()),
        throwsFormatException);
    expect(() => message(1, text: ' \t\n'), throwsFormatException);
    expect(() => ChatOwner(projectRef: 'unknown', userId: a),
        throwsFormatException);
    expect(() => ChatOwner(projectRef: project, userId: 'unknown'),
        throwsFormatException);
  });
  test('remote decoder validates shape moderation and restricted payload', () {
    final row = {
      ...message(1).insertPayload,
      'sent_at': instant.toIso8601String(),
      'deleted_at': null,
      'moderation_state': 'visible'
    };
    expect(
        OperationalChatMessage.fromRemote(row).sendStatus, ChatSendStatus.sent);
    expect(() => OperationalChatMessage.fromRemote({...row, 'raw_text': 42}),
        throwsFormatException);
    expect(
        () => OperationalChatMessage.fromRemote(
            {...row, 'moderation_state': 'held'}),
        throwsFormatException);
    expect(
        () =>
            OperationalChatMessage.fromRemote({...row, 'sent_at': 'not-time'}),
        throwsFormatException);
    expect(message(1).insertPayload.keys, isNot(contains('sent_at')));
    expect(message(1).insertPayload.keys, isNot(contains('translated_text')));
  });
  test(
      'offline enqueue and cold reopen preserve pending raw IDs without request',
      () async {
    online = false;
    final engine = relay();
    final queued = await engine.enqueue(
        conversationId: conversation,
        rawText: '  Tối nay đi quẩy k bro?  ',
        sourceLanguageCode: 'vi');
    await engine.synchronize();
    expect(server.calls, 0);
    engine.dispose();
    await store.dispose();
    await local.close();
    db = await local.open();
    store = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: a));
    final restored = (await store.watchMessages(conversation).first).single;
    expect(restored.rawText, queued.rawText);
    expect(restored.id, queued.id);
    expect(restored.clientGeneratedId, queued.clientGeneratedId);
    expect(restored.sendStatus, ChatSendStatus.pending);
    expect((await store.due(now)).single.id, queued.id);
  });
  test('project and account scoping covers reads writes inbox and outbox',
      () async {
    await store.enqueue(message(1));
    for (final owner in [
      ChatOwner(projectRef: project, userId: b),
      ChatOwner(projectRef: 'pppppppppppppppppppp', userId: a)
    ]) {
      final other = OperationalChatStore(database: db, owner: owner);
      expect(await other.messages(conversation), isEmpty);
      expect(await other.conversations(), isEmpty);
      expect(await other.due(now), isEmpty);
      await other.cacheConversation(ChatConversation(
          id: conversation, peerId: owner.userId == a ? b : a));
      await other.enqueue(message(2, sender: owner.userId));
      expect((await other.messages(conversation)).single.id, uuid(2));
      await other.dispose();
    }
    expect((await store.messages(conversation)).single.id, uuid(1));
    expect((await store.due(now)).single.id, uuid(1));
  });
  test('unknown conversation sender spoof and outsider rejected atomically',
      () async {
    await expectLater(
        store.enqueue(message(1, sender: b)), throwsFormatException);
    await expectLater(
        store.mergeRemote(message(1, sender: outsider, sentAt: instant)),
        throwsFormatException);
    await store.reconcileConversations([]);
    await expectLater(store.enqueue(message(1)), throwsFormatException);
    expect(await db.query('chat_messages'), isEmpty);
  });
  test('duplicate enqueue cannot overwrite persisted raw text', () async {
    await store.enqueue(message(1));
    await expectLater(store.enqueue(message(1, text: 'rewrite')),
        throwsA(isA<DatabaseException>()));
    expect((await store.messages(conversation)).single.rawText,
        message(1).rawText);
    expect((await store.due(now)).length, 1);
  });
  test('single-flight synchronizes pending row once and marks sent', () async {
    final engine = relay();
    await store.enqueue(message(1));
    server.barrier = Completer<void>();
    final first = engine.synchronize();
    final second = engine.synchronize();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    server.barrier!.complete();
    expect((await first).sent, 1);
    await second;
    expect(server.calls, 1);
    expect(await store.due(now), isEmpty);
    expect((await store.messages(conversation)).single.sendStatus,
        ChatSendStatus.sent);
    engine.dispose();
  });
  test(
      'lost ack after server commit retries same key once after durable backoff',
      () async {
    final engine = relay();
    await store.enqueue(message(1));
    server.loseFirstResponse = true;
    expect((await engine.synchronize()).retryScheduled, 1);
    expect(server.rows.length, 1);
    expect(server.calls, 1);
    expect((await store.messages(conversation)).single.attemptCount, 1);
    await engine.synchronize();
    expect(server.calls, 1);
    engine.dispose();
    await store.dispose();
    await local.close();
    db = await local.open();
    store = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: a));
    final restarted = relay();
    await restarted.synchronize();
    expect(server.calls, 1);
    now = now.add(const Duration(seconds: 2));
    expect((await restarted.synchronize()).sent, 1);
    expect(server.calls, 2);
    expect(server.rows.length, 1);
    expect((await store.messages(conversation)).single.id, uuid(1));
    restarted.dispose();
  });
  test('denied sends are blocked without deleting raw or automatic resend',
      () async {
    final engine = relay();
    await store.enqueue(message(1));
    server.denied = true;
    expect((await engine.synchronize()).blocked, 1);
    expect((await store.messages(conversation)).single.sendStatus,
        ChatSendStatus.blocked);
    now = now.add(const Duration(days: 1));
    await engine.synchronize();
    expect(server.calls, 1);
    engine.dispose();
  });
  test('retry cap stops request loop after eight attempts and preserves text',
      () async {
    final engine = relay();
    await store.enqueue(message(1));
    server.offline = true;
    for (var attempt = 0; attempt < 8; attempt++) {
      await engine.synchronize();
      now = now.add(const Duration(hours: 1));
    }
    await engine.synchronize();
    expect(server.calls, 8);
    final row = (await store.messages(conversation)).single;
    expect(row.attemptCount, 8);
    expect(row.sendStatus, ChatSendStatus.blocked);
    expect(row.rawText, message(1).rawText);
    engine.dispose();
  });
  test('late ack after logout or dispose cannot commit a stale owner result',
      () async {
    final engine = relay();
    await store.enqueue(message(1));
    server.barrier = Completer<void>();
    final request = engine.synchronize();
    await Future<void>.delayed(Duration.zero);
    active = false;
    engine.dispose();
    server.barrier!.complete();
    expect((await request).sent, 0);
    expect((await store.messages(conversation)).single.sendStatus,
        ChatSendStatus.pending);
    final other = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: b));
    expect(await other.messages(conversation), isEmpty);
    await other.dispose();
    await expectLater(
        engine.enqueue(
            conversationId: conversation,
            rawText: 'new',
            sourceLanguageCode: 'vi'),
        throwsStateError);
  });
  test('out-of-order duplicate relay merges once with deterministic ordering',
      () async {
    await store.mergeRemote(message(2, sender: b, sentAt: instant));
    await store.mergeRemote(message(1, sentAt: instant));
    await store.mergeRemote(message(2, sender: b, sentAt: instant));
    expect((await store.messages(conversation)).map((m) => m.id),
        [uuid(1), uuid(2)]);
  });
  test(
      'conflicting remote raw and timestamps roll back without clearing outbox',
      () async {
    await store.enqueue(message(1));
    await expectLater(
        store.mergeRemote(message(1, text: 'rewrite', sentAt: instant)),
        throwsFormatException);
    expect((await store.due(now)).single.id, uuid(1));
    await store.mergeRemote(message(1, sentAt: instant));
    await expectLater(
        store.mergeRemote(
            message(1, sentAt: instant.add(const Duration(seconds: 1)))),
        throwsFormatException);
    expect((await store.messages(conversation)).single.sentAt, instant);
  });
  test('complete history hides deleted held rows while retaining pending text',
      () async {
    await store.mergeRemote(message(1, sentAt: instant));
    await store.mergeRemote(message(2, sender: b, sentAt: instant));
    await store.enqueue(message(3));
    await store.reconcileHistory(
        conversation, [message(2, sender: b, sentAt: instant)]);
    expect((await store.messages(conversation)).map((m) => m.id),
        [uuid(2), uuid(3)]);
    await store.reconcileHistory(conversation, []);
    expect((await store.messages(conversation)).single.id, uuid(3));
  });
  test(
      'inactive inventory hides cached history blocks pending and isolates others',
      () async {
    await store.enqueue(message(1));
    final other = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: b));
    await other
        .cacheConversation(ChatConversation(id: conversation, peerId: a));
    await other.enqueue(message(2, sender: b));
    await store.reconcileConversations([]);
    expect(await store.messages(conversation), isEmpty);
    expect(await store.due(now), isEmpty);
    expect((await other.messages(conversation)).single.id, uuid(2));
    await store
        .cacheConversation(ChatConversation(id: conversation, peerId: b));
    expect((await store.messages(conversation)).single.sendStatus,
        ChatSendStatus.blocked);
    await other.dispose();
  });
  test('invalid complete history rolls back all merge operations', () async {
    await store.enqueue(message(1));
    await expectLater(
        store.reconcileHistory(conversation, [
          message(2, sender: b, sentAt: instant),
          message(1, text: 'rewrite', sentAt: instant)
        ]),
        throwsFormatException);
    expect((await store.messages(conversation)).single.id, uuid(1));
    expect((await store.due(now)).length, 1);
  });
  test('local stream reads and optimistic updates require zero transport calls',
      () async {
    final engine = relay();
    final emissions = <List<OperationalChatMessage>>[];
    final initial = Completer<void>();
    final update = Completer<void>();
    final subscription = store.watchMessages(conversation).listen((rows) {
      emissions.add(rows);
      if (rows.isEmpty && !initial.isCompleted) initial.complete();
      if (rows.isNotEmpty && !update.isCompleted) update.complete();
    });
    await initial.future;
    await engine.enqueue(
        conversationId: conversation,
        rawText: 'hello',
        sourceLanguageCode: 'vi');
    await update.future;
    expect(server.calls, 0);
    expect(emissions.first, isEmpty);
    expect(emissions.last.single.rawText, 'hello');
    await subscription.cancel();
    engine.dispose();
  });

  test('sender-client key reconciles canonical server ID without duplicate',
      () async {
    final pending = message(1);
    await store.enqueue(pending);
    final canonical = OperationalChatMessage(
      id: uuid(99),
      conversationId: pending.conversationId,
      senderId: pending.senderId,
      rawText: pending.rawText,
      sourceLanguageCode: pending.sourceLanguageCode,
      clientGeneratedId: pending.clientGeneratedId,
      clientCreatedAt: pending.clientCreatedAt,
      sentAt: instant,
      sendStatus: ChatSendStatus.sent,
    );
    await store.mergeRemote(canonical);
    await store.mergeRemote(canonical);
    expect((await store.messages(conversation)).single.id, uuid(99));
    expect(await store.due(now), isEmpty);
  });
  test('cached inbox timestamp cannot regress on stale conversation metadata',
      () async {
    await store.mergeRemote(message(1, sentAt: instant));
    await store
        .cacheConversation(ChatConversation(id: conversation, peerId: b));
    await store.cacheConversation(ChatConversation(
        id: conversation,
        peerId: b,
        lastMessageAt: instant.subtract(const Duration(hours: 1))));
    expect((await store.conversations()).single.lastMessageAt, instant);
  });
  test('inbound unread count and preview clear only when conversation opens',
      () async {
    await store
        .mergeRemote(message(1, sender: b, text: 'Tin mới', sentAt: instant));
    var row = (await store.conversations()).single;
    expect(row.lastMessageText, 'Tin mới');
    expect(row.unreadCount, 1);
    await store.markConversationRead(conversation);
    row = (await store.conversations()).single;
    expect(row.unreadCount, 0);
    await store.mergeRemote(message(2,
        sender: b,
        text: 'Tin mới hơn',
        sentAt: instant.add(const Duration(minutes: 1))));
    row = (await store.conversations()).single;
    expect(row.lastMessageText, 'Tin mới hơn');
    expect(row.unreadCount, 1);
  });
  test('public peer profiles are isolated by owner and survive store reads',
      () async {
    final profile = ChatPeerProfile(
        id: b,
        displayName: 'Capy Mây',
        username: 'capy_may',
        avatarUrl: 'https://example.com/capy.png');
    await store.cacheProfiles([profile]);
    expect((await store.profiles()).single.label, 'Capy Mây');
    final other = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: outsider));
    expect(await other.profiles(), isEmpty);
    await other.dispose();
  });
  test('timezone-less remote timestamps fail instead of using device timezone',
      () {
    final row = {
      ...message(1).insertPayload,
      'sent_at': '2026-09-15T12:00:00',
      'deleted_at': null,
      'moderation_state': 'visible'
    };
    expect(() => OperationalChatMessage.fromRemote(row), throwsFormatException);
  });
  test(
      'two local owners exchange raw against shared fake server without translation',
      () async {
    final engineA = relay();
    final localB = OperationalChatStore(
        database: db, owner: ChatOwner(projectRef: project, userId: b));
    await localB
        .cacheConversation(ChatConversation(id: conversation, peerId: a));
    final engineB = OperationalChatRelay(
        store: localB,
        transport: server,
        isCurrentOwner: () => true,
        canReachNetwork: () => true,
        clock: () => now);
    await engineA.enqueue(
        conversationId: conversation,
        rawText: 'k bro?',
        sourceLanguageCode: 'vi');
    await engineA.synchronize();
    await localB.mergeRemote(server.rows.values.single);
    await engineB.enqueue(
        conversationId: conversation,
        rawText: 'Tonight!',
        sourceLanguageCode: 'en');
    await engineB.synchronize();
    for (final row in server.rows.values) {
      await store.mergeRemote(row);
    }
    expect((await store.messages(conversation)).map((m) => m.rawText).toSet(),
        {'k bro?', 'Tonight!'});
    expect((await localB.messages(conversation)).map((m) => m.rawText).toSet(),
        {'k bro?', 'Tonight!'});
    expect(server.rows.length, 2);
    engineA.dispose();
    engineB.dispose();
    await localB.dispose();
  });
  test('disposing local store closes cached read subscriptions', () async {
    final done = Completer<void>();
    final subscription =
        store.watchMessages(conversation).listen((_) {}, onDone: done.complete);
    await store.dispose();
    await done.future;
    await subscription.cancel();
  });
}
