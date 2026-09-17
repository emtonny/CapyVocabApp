import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:capy_vocab/features/chat/application/operational_chat_coordinator.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_store.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'operational_chat_relay_test.dart' as f;

final class Gateway implements OperationalChatGateway {
  final rows = <String, OperationalChatMessage>{};
  final conversations = <String, ChatConversation>{
    f.conversation: ChatConversation(id: f.conversation, peerId: f.b)
  };
  late final events = StreamController<ChatRemoteSignal>.broadcast(
      onListen: () => attaches++, onCancel: () => detaches++);
  int sends = 0, pulls = 0, histories = 0, verifies = 0;
  int attaches = 0, detaches = 0, restarts = 0, disposals = 0, opens = 0;
  bool failSend = false, failHistory = false, failVerification = false;
  Completer<void>? sendBarrier, historyBarrier, inventoryBarrier;
  Completer<void>? historyStarted, inventoryStarted, sendStarted;
  Completer<void>? allSent;
  int? expectedSends;
  @override
  Future<OperationalChatMessage> send(OperationalChatMessage message) async {
    sends++;
    sendStarted?.complete();
    if (sendBarrier != null) await sendBarrier!.future;
    if (failSend) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
    final ack = rows.putIfAbsent(message.id, () => f.ack(message));
    if (sends == expectedSends && allSent != null && !allSent!.isCompleted) {
      allSent!.complete();
    }
    return ack;
  }

  @override
  Future<List<ChatConversation>> fetchConversations() async {
    pulls++;
    final snapshot = conversations.values.toList();
    inventoryStarted?.complete();
    if (inventoryBarrier != null) await inventoryBarrier!.future;
    return snapshot;
  }

  @override
  Future<List<OperationalChatMessage>> fetchHistory(
      String conversationId) async {
    histories++;
    final snapshot =
        rows.values.where((m) => m.conversationId == conversationId).toList();
    historyStarted?.complete();
    if (historyBarrier != null) await historyBarrier!.future;
    if (failHistory) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
    return snapshot;
  }

  @override
  Future<Set<String>> visibleConversationIds(Set<String> ids) async =>
      ids.intersection(conversations.keys.toSet());
  @override
  Future<Set<String>> visibleCachedIds(
      String conversationId, Set<String> ids) async {
    verifies++;
    if (failVerification) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
    return ids
        .where((id) => rows[id]?.conversationId == conversationId)
        .toSet();
  }

  @override
  Stream<ChatRemoteSignal> get signals => events.stream;
  @override
  Future<void> restartRealtime() async {
    restarts++;
  }

  @override
  Future<ChatConversation> openDirectChat(String peerId) async {
    opens++;
    return ChatConversation(id: f.uuid(500), peerId: peerId);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await events.close();
  }
}

Future<void> eventually(bool Function() predicate) async {
  final until = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(until)) fail('Background condition timed out.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory directory;
  late OperationalChatDatabase local;
  late OperationalChatStore store;
  late Gateway remote;
  late OperationalChatCoordinator coordinator;
  late bool online, active;
  late String? source;
  late DateTime now;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_chat_runtime_');
    local = OperationalChatDatabase(
        factory: databaseFactoryFfi, path: '${directory.path}/chat.db');
    store = OperationalChatStore(
        database: await local.open(),
        owner: ChatOwner(projectRef: f.project, userId: f.a));
    await store
        .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
    remote = Gateway();
    online = true;
    active = true;
    source = 'vi';
    now = f.instant;
    coordinator = OperationalChatCoordinator(
        store: store,
        remote: remote,
        isCurrentSession: () => active,
        networkAvailable: () async => online,
        cachedSourceLanguageCode: () => source,
        clock: () => now);
  });
  tearDown(() async {
    await coordinator.dispose();
    await store.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  test(
      'offline enqueue/inbox/detail are local; spam cannot bypass network backoff',
      () async {
    online = false;
    final queued = await coordinator.enqueue(
        conversationId: f.conversation, rawText: 'k bro?');
    expect((await store.watchConversations().first).single.id, f.conversation);
    expect(
        (await store.watchMessages(f.conversation).first).single.id, queued.id);
    expect(await coordinator.synchronize(), ChatSyncOutcome.offline);
    for (var n = 0; n < 20; n++) {
      coordinator.requestRefresh();
      expect(await coordinator.synchronize(), ChatSyncOutcome.idle);
    }
    expect(remote.sends + remote.pulls + remote.attaches, 0);
    expect((await store.due(now)).single.attemptCount, 0);
    online = true;
    now = now.add(const Duration(seconds: 2));
    expect(await coordinator.synchronize(), ChatSyncOutcome.synchronized);
    expect(remote.sends, 1);
  });
  test('single-flight sends once and raw is sent before failed history request',
      () async {
    await store.enqueue(f.message(1));
    remote.failHistory = true;
    final first = coordinator.synchronize();
    final second = coordinator.synchronize();
    expect(identical(first, second), isTrue);
    expect(await first, ChatSyncOutcome.failed);
    expect(remote.sends, 1);
    expect((await store.messages(f.conversation)).single.sendStatus,
        ChatSendStatus.sent);
  });
  test(
      'unknown/invalid cached profile rejects enqueue and does not consume pending attempts',
      () async {
    await store.enqueue(f.message(1));
    for (final invalid in [null, 'xx']) {
      source = invalid;
      await expectLater(
          coordinator.enqueue(conversationId: f.conversation, rawText: 'test'),
          throwsStateError);
      await coordinator.synchronize();
      expect(remote.sends, 0);
      expect((await store.due(now)).single.attemptCount, 0);
    }
  });
  test('only matching native language pending rows are sent and scheduled',
      () async {
    await store.enqueue(f.message(1));
    source = 'en';
    await store.enqueue(OperationalChatMessage(
        id: f.uuid(2),
        conversationId: f.conversation,
        senderId: f.a,
        rawText: 'Tonight!',
        sourceLanguageCode: 'en',
        clientGeneratedId: f.uuid(1002),
        clientCreatedAt: now));
    await coordinator.synchronize();
    expect(remote.rows.keys, [f.uuid(2)]);
    expect((await store.due(now)).single.id, f.uuid(1));
    expect(await store.nextPendingAt(now, sourceLanguageCode: 'en'), isNull);
  });
  test('snapshot revision rejects a newer local ACK without deleting it',
      () async {
    await store.mergeRemote(f.ack(f.message(1)));
    remote.rows[f.uuid(1)] = f.ack(f.message(1));
    remote.historyBarrier = Completer();
    remote.historyStarted = Completer();
    final flight = coordinator.synchronize();
    await remote.historyStarted!.future;
    final ack = f.ack(f.message(2));
    remote.rows[ack.id] = ack;
    await store.mergeRemote(ack);
    remote.historyBarrier!.complete();
    expect(await flight, ChatSyncOutcome.superseded);
    expect((await store.messages(f.conversation)).map((m) => m.id),
        [f.uuid(1), f.uuid(2)]);
    remote.historyBarrier = null;
    remote.historyStarted = null;
    await coordinator.synchronize();
    expect((await store.messages(f.conversation)).length, 2);
  });
  test(
      'Realtime invalidation fences history; next refresh prunes confirmed hidden sent only',
      () async {
    await store.mergeRemote(f.ack(f.message(1)));
    remote.rows[f.uuid(1)] = f.ack(f.message(1));
    remote.historyBarrier = Completer();
    remote.historyStarted = Completer();
    final flight = coordinator.synchronize();
    await remote.historyStarted!.future;
    remote.rows.clear();
    remote.events.add(ChatRemoteSignal.changed);
    await Future<void>.delayed(Duration.zero);
    remote.historyBarrier!.complete();
    expect(await flight, ChatSyncOutcome.superseded);
    expect((await store.messages(f.conversation)).length, 1);
    remote.historyBarrier = null;
    remote.historyStarted = null;
    source = null;
    await store.enqueue(f.message(2));
    await coordinator.synchronize();
    expect((await store.messages(f.conversation)).single.id, f.uuid(2));
    expect((await store.due(now)).single.attemptCount, 0);
  });
  test('Realtime connect during inventory does not starve initial history pull',
      () async {
    remote.rows[f.uuid(1)] = f.ack(f.message(1));
    remote.inventoryBarrier = Completer<void>();
    remote.inventoryStarted = Completer<void>();
    final flight = coordinator.synchronize();
    await remote.inventoryStarted!.future;
    remote.events.add(ChatRemoteSignal.connected);
    await Future<void>.delayed(Duration.zero);
    remote.inventoryBarrier!.complete();
    expect(await flight, ChatSyncOutcome.synchronized);
    expect(remote.histories, 1);
    expect((await store.messages(f.conversation)).single.id, f.uuid(1));
  });
  test(
      'visibility failure cannot delete old sent messages or merge partial history',
      () async {
    await store.mergeRemote(f.ack(f.message(1)));
    remote.failVerification = true;
    expect(await coordinator.synchronize(), ChatSyncOutcome.failed);
    expect((await store.messages(f.conversation)).single.id, f.uuid(1));
  });
  test(
      'membership snapshot cannot hide a conversation locally opened during pull',
      () async {
    remote.inventoryBarrier = Completer();
    remote.inventoryStarted = Completer();
    final flight = coordinator.synchronize();
    await remote.inventoryStarted!.future;
    final newChat = ChatConversation(id: f.uuid(500), peerId: f.outsider);
    remote.conversations[newChat.id] = newChat;
    await store.cacheConversation(newChat);
    remote.inventoryBarrier!.complete();
    expect(await flight, ChatSyncOutcome.superseded);
    expect((await store.conversations()).length, 2);
  });
  test(
      'membership verification hides inactive owner history and blocks raw pending',
      () async {
    source = null;
    await store.enqueue(f.message(1));
    remote.conversations.clear();
    await coordinator.synchronize();
    expect(await store.conversations(), isEmpty);
    expect(await store.messages(f.conversation), isEmpty);
    expect(await store.due(now), isEmpty);
    await store
        .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
    expect((await store.messages(f.conversation)).single.sendStatus,
        ChatSendStatus.blocked);
  });
  test(
      'transaction current-session guard rolls back merges when owner changes mid-transaction',
      () async {
    await store.enqueue(f.message(1));
    var checks = 0;
    await expectLater(
        store.applyHistoryRefresh(
            conversationId: f.conversation,
            messages: [f.ack(f.message(1)), f.ack(f.message(2))],
            capturedSentIds: {},
            visibleIds: {f.uuid(1), f.uuid(2)},
            expectedRevision: store.revision,
            isCurrent: () => ++checks == 1),
        throwsA(isA<ChatRefreshSuperseded>()));
    expect((await store.messages(f.conversation)).single.sendStatus,
        ChatSendStatus.pending);
    expect((await store.due(now)).single.attemptCount, 0);
  });
  test(
      'foreground pause detaches and suppresses late ACK, resume retries same server identity',
      () async {
    await store.enqueue(f.message(1));
    remote.sendBarrier = Completer();
    remote.sendStarted = Completer();
    final flight = coordinator.synchronize();
    await remote.sendStarted!.future;
    coordinator.setForeground(false);
    await eventually(() => remote.detaches == 1);
    remote.sendBarrier!.complete();
    await flight;
    expect((await store.due(now)).single.id, f.uuid(1));
    expect(await coordinator.synchronize(), ChatSyncOutcome.idle);
    remote.sendBarrier = null;
    remote.sendStarted = null;
    coordinator.setForeground(true);
    await coordinator.synchronize();
    expect(remote.rows.length, 1);
    expect(await store.due(now), isEmpty);
  });
  test('logout during history verification never applies old owner response',
      () async {
    remote.rows[f.uuid(1)] = f.ack(f.message(1));
    remote.historyBarrier = Completer();
    remote.historyStarted = Completer();
    final flight = coordinator.synchronize();
    await remote.historyStarted!.future;
    active = false;
    remote.historyBarrier!.complete();
    await flight;
    expect(await store.messages(f.conversation), isEmpty);
  });
  test('disposal waits for flight but late ACK cannot commit; disposal is once',
      () async {
    await store.enqueue(f.message(1));
    remote.sendBarrier = Completer();
    remote.sendStarted = Completer();
    final flight = coordinator.synchronize();
    await remote.sendStarted!.future;
    final closing = coordinator.dispose();
    remote.sendBarrier!.complete();
    await flight;
    await closing;
    await coordinator.dispose();
    expect(remote.disposals, 1);
    expect((await store.due(now)).single.id, f.uuid(1));
  });
  test(
      'disconnect backoff schedules fresh channel and refresh without request storm',
      () async {
    await coordinator.synchronize();
    remote.events.add(ChatRemoteSignal.disconnected);
    await Future<void>.delayed(Duration.zero);
    expect(await coordinator.synchronize(), ChatSyncOutcome.idle);
    now = now.add(const Duration(seconds: 2));
    await coordinator.synchronize();
    expect(remote.restarts, 1);
    expect(remote.pulls, 2);
  });
  test(
      'durable retry deadline is respected and raw pending survives failed send',
      () async {
    remote.failSend = true;
    await store.enqueue(f.message(1));
    await coordinator.synchronize();
    expect((await store.messages(f.conversation)).single.attemptCount, 1);
    expect(await store.nextPendingAt(now, sourceLanguageCode: 'vi'),
        now.add(const Duration(seconds: 2)));
    await coordinator.synchronize();
    expect(remote.sends, 1);
    now = now.add(const Duration(seconds: 2));
    remote.failSend = false;
    await coordinator.synchronize();
    expect(await store.due(now), isEmpty);
  });
  test('automatic scheduler drains beyond 100 rows without duplicates',
      () async {
    for (var n = 1; n <= 101; n++) {
      await store.enqueue(f.message(n));
    }
    remote.expectedSends = 101;
    remote.allSent = Completer<void>();
    coordinator.start();
    await remote.allSent!.future.timeout(const Duration(seconds: 30));
    expect(remote.rows.length, 101);
    // send result reaches SQLite before relying on durable due() assertions.
    await coordinator.synchronize();
    expect(await store.due(now), isEmpty);
    expect(remote.sends, 101);
  });
  test(
      'scheduler pauses all timers; resume repairs missing Realtime events periodically',
      () async {
    coordinator.start();
    await coordinator.synchronize();
    await eventually(() => coordinator.nextWakeAt != null);
    coordinator.setForeground(false);
    expect(coordinator.nextWakeAt, isNull);
    remote.rows[f.uuid(1)] = f.ack(f.message(1));
    coordinator.setForeground(true);
    await coordinator.synchronize();
    expect((await store.messages(f.conversation)).single.id, f.uuid(1));
    remote.rows.clear();
    now = now.add(const Duration(seconds: 31));
    await coordinator.synchronize();
    expect(await store.messages(f.conversation), isEmpty);
  });
  test('queued SQLite enqueue checks session again before commit', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final lock = store.database.transaction((tx) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final queued = coordinator.enqueue(
        conversationId: f.conversation, rawText: 'stale enqueue');
    final assertion =
        expectLater(queued, throwsA(isA<ChatRefreshSuperseded>()));
    active = false;
    release.complete();
    await lock;
    await assertion;
    expect(await store.messages(f.conversation), isEmpty);
  });
  test(
      'open chat requires online/profile and uses guarded canonical cache commit',
      () async {
    online = false;
    await expectLater(coordinator.openDirectChat(f.outsider),
        throwsA(isA<ChatRelayException>()));
    expect(remote.opens, 0);
    online = true;
    final chat = await coordinator.openDirectChat(f.outsider);
    expect(chat.peerId, f.outsider);
    expect((await store.conversations()).length, 2);
  });
}
