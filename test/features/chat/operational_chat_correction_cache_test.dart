import 'dart:io';

import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_store.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'operational_chat_relay_test.dart' as f;

OperationalChatCorrection proposal({
  required OperationalChatMessage message,
  String author = f.a,
  ChatCorrectionSyncStatus sync = ChatCorrectionSyncStatus.proposalPending,
  int id = 7001,
}) =>
    OperationalChatCorrection(
      id: f.uuid(id),
      messageId: message.id,
      authorId: author,
      targetLanguageCode: message.sourceLanguageCode == 'vi' ? 'en' : 'vi',
      proposedText: message.sourceLanguageCode == 'vi'
          ? 'Are you going tonight?'
          : 'Tối nay bạn có đi không?',
      status: ChatCorrectionStatus.proposed,
      createdAt: f.instant,
      updatedAt: f.instant,
      syncStatus: sync,
      nextAttemptAt:
          sync == ChatCorrectionSyncStatus.proposalPending ? f.instant : null,
    );

void main() {
  late Directory directory;
  late OperationalChatDatabase local;
  late OperationalChatStore store;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_chat_c6c_');
    local = OperationalChatDatabase(
        factory: databaseFactoryFfi, path: '${directory.path}/chat.db');
    store = OperationalChatStore(
      database: await local.open(),
      owner: ChatOwner(projectRef: f.project, userId: f.a),
    );
    await store
        .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
  });
  tearDown(() async {
    await store.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  test('remote codec accepts canonical rows and rejects invalid decision shape',
      () {
    final row = {
      'id': f.uuid(7001),
      'message_id': f.uuid(1),
      'author_id': f.b,
      'target_language_code': 'en',
      'proposed_text': 'Are you going tonight?',
      'status': 'accepted',
      'accepted_by': f.a,
      'accepted_at': f.instant.toIso8601String(),
      'rejected_by': null,
      'rejected_at': null,
      'created_at': f.instant.toIso8601String(),
      'updated_at': f.instant.toIso8601String(),
    };
    expect(OperationalChatCorrection.fromRemote(row).status,
        ChatCorrectionStatus.accepted);
    expect(
        () =>
            OperationalChatCorrection.fromRemote({...row, 'rejected_by': f.a}),
        throwsFormatException);
    expect(
        () => OperationalChatCorrection.fromRemote(
            {...row, 'created_at': '2026-09-15T12:00:00'}),
        throwsFormatException);
  });

  test('offline proposal persists, retries, then merges canonical ACK',
      () async {
    final incoming = f.ack(f.message(1, sender: f.b));
    await store.mergeRemote(incoming);
    final pending = proposal(message: incoming);
    await store.enqueueCorrection(pending);

    expect((await store.dueCorrections(f.instant)).single.id, pending.id);
    await store.failCorrection(pending,
        blocked: false, retryAt: f.instant.add(const Duration(seconds: 5)));
    expect(await store.dueCorrections(f.instant), isEmpty);

    final retry = (await store.corrections(f.conversation)).single;
    expect(retry.attemptCount, 1);
    final ack = OperationalChatCorrection(
      id: pending.id,
      messageId: pending.messageId,
      authorId: pending.authorId,
      targetLanguageCode: pending.targetLanguageCode,
      proposedText: pending.proposedText,
      status: ChatCorrectionStatus.proposed,
      createdAt: f.instant.add(const Duration(milliseconds: 250)),
      updatedAt: f.instant.add(const Duration(milliseconds: 250)),
    );
    await store.mergeCorrectionAck(ack);
    final cached = (await store.corrections(f.conversation)).single;
    expect(cached.syncStatus, ChatCorrectionSyncStatus.synced);
    expect(cached.proposedText, pending.proposedText);
  });

  test('message sender queues a decision without rewriting raw or proposal',
      () async {
    final ownMessage = f.ack(f.message(1));
    await store.mergeRemote(ownMessage);
    final remoteProposal = proposal(
      message: ownMessage,
      author: f.b,
      sync: ChatCorrectionSyncStatus.synced,
    );
    await store.mergeCorrections(
        conversationId: f.conversation, corrections: [remoteProposal]);

    await store.queueCorrectionDecision(
        remoteProposal.id, ChatCorrectionDecision.accepted, f.instant);
    final queued = (await store.dueCorrections(f.instant)).single;
    expect(queued.pendingDecision, ChatCorrectionDecision.accepted);
    expect(queued.status, ChatCorrectionStatus.proposed);

    final acceptedAt = f.instant.add(const Duration(seconds: 1));
    final accepted = OperationalChatCorrection(
      id: remoteProposal.id,
      messageId: remoteProposal.messageId,
      authorId: remoteProposal.authorId,
      targetLanguageCode: remoteProposal.targetLanguageCode,
      proposedText: remoteProposal.proposedText,
      status: ChatCorrectionStatus.accepted,
      acceptedBy: f.a,
      acceptedAt: acceptedAt,
      createdAt: remoteProposal.createdAt,
      updatedAt: acceptedAt,
    );
    await store.mergeCorrectionAck(accepted);
    expect((await store.corrections(f.conversation)).single.status,
        ChatCorrectionStatus.accepted);
    expect((await store.messages(f.conversation)).single.rawText,
        ownMessage.rawText);
  });

  test(
      'correction author, target language and one active proposal are enforced',
      () async {
    final incoming = f.ack(f.message(1, sender: f.b));
    await store.mergeRemote(incoming);
    await expectLater(
      store.enqueueCorrection(proposal(message: incoming, author: f.b)),
      throwsFormatException,
    );
    final first = proposal(message: incoming);
    await store.enqueueCorrection(first);
    await expectLater(
      store.enqueueCorrection(proposal(message: incoming, id: 7002)),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('membership removal hides correction and blocks its outbox', () async {
    final incoming = f.ack(f.message(1, sender: f.b));
    await store.mergeRemote(incoming);
    await store.enqueueCorrection(proposal(message: incoming));
    await store.reconcileConversations([]);
    expect(await store.corrections(f.conversation), isEmpty);
    expect(await store.dueCorrections(f.instant), isEmpty);
    await store
        .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
    expect((await store.corrections(f.conversation)).single.syncStatus,
        ChatCorrectionSyncStatus.proposalBlocked);
  });
}
