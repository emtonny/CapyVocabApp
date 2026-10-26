import 'dart:io';

import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_store.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'operational_chat_relay_test.dart' as f;

OperationalChatCorrection acceptedCorrection(OperationalChatMessage message) =>
    OperationalChatCorrection(
      id: f.uuid(8001),
      messageId: message.id,
      authorId: f.b,
      targetLanguageCode: 'en',
      proposedText: 'Want to hit the club tonight, bro?',
      status: ChatCorrectionStatus.accepted,
      acceptedBy: f.a,
      acceptedAt: f.instant,
      createdAt: f.instant,
      updatedAt: f.instant,
    );

OperationalChatAnnotation annotation({
  required OperationalChatMessage message,
  required OperationalChatCorrection correction,
  String spanText = 'quẩy',
  int spanStart = 11,
  int spanEnd = 15,
  String createdBy = f.a,
  ChatAnnotationSyncStatus sync = ChatAnnotationSyncStatus.pending,
}) =>
    OperationalChatAnnotation(
      id: f.uuid(8101),
      messageId: message.id,
      correctionId: correction.id,
      createdBy: createdBy,
      spanText: spanText,
      spanStart: spanStart,
      spanEnd: spanEnd,
      tagType: ChatAnnotationType.slang,
      normalizedSource: 'đi chơi hoặc đi bar',
      createdAt: f.instant,
      syncStatus: sync,
      nextAttemptAt:
          sync == ChatAnnotationSyncStatus.pending ? f.instant : null,
    );

void main() {
  late Directory directory;
  late OperationalChatDatabase local;
  late OperationalChatStore store;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_chat_c6d_');
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

  test('remote codec preserves Unicode code-point span and rejects bad shape',
      () {
    final row = {
      'id': f.uuid(8101),
      'message_id': f.uuid(1),
      'correction_id': f.uuid(8001),
      'created_by': f.a,
      'span_text': '😀',
      'span_start': 23,
      'span_end': 24,
      'tag_type': 'slang',
      'normalized_source': 'vui',
      'annotator_role': 'source_speaker',
      'status': 'active',
      'created_at': f.instant.toIso8601String(),
    };
    final decoded = OperationalChatAnnotation.fromRemote(row);
    expect(decoded.spanText.runes.length, 1);
    expect(decoded.spanEnd - decoded.spanStart, 1);
    expect(
        () => OperationalChatAnnotation.fromRemote(
            {...row, 'tag_type': 'unknown'}),
        throwsFormatException);
    expect(
        () => OperationalChatAnnotation.fromRemote(
            {...row, 'annotator_role': 'target_speaker'}),
        throwsFormatException);
  });

  test('offline tag persists, retries and merges canonical server ACK',
      () async {
    final message = f.ack(f.message(1));
    await store.mergeRemote(message);
    final correction = acceptedCorrection(message);
    await store.mergeCorrections(
        conversationId: f.conversation, corrections: [correction]);
    final pending = annotation(message: message, correction: correction);

    await store.enqueueAnnotation(pending);
    expect((await store.dueAnnotations(f.instant)).single.spanText, 'quẩy');
    await store.failAnnotation(pending,
        blocked: false, retryAt: f.instant.add(const Duration(seconds: 5)));
    expect(await store.dueAnnotations(f.instant), isEmpty);
    final retry = (await store.annotations(f.conversation)).single;
    expect(retry.attemptCount, 1);

    final ack = OperationalChatAnnotation(
      id: pending.id,
      messageId: pending.messageId,
      correctionId: pending.correctionId,
      createdBy: pending.createdBy,
      spanText: pending.spanText,
      spanStart: pending.spanStart,
      spanEnd: pending.spanEnd,
      tagType: pending.tagType,
      normalizedSource: pending.normalizedSource,
      createdAt: f.instant.add(const Duration(milliseconds: 250)),
    );
    await store.mergeAnnotationAck(ack);
    final cached = (await store.annotations(f.conversation)).single;
    expect(cached.syncStatus, ChatAnnotationSyncStatus.synced);
    expect(cached.spanStart, 11);
    expect(cached.spanEnd, 15);
    expect((await store.messages(f.conversation)).single.rawText,
        'Tối nay đi quẩy k bro?');
    expect((await store.corrections(f.conversation)).single.proposedText,
        correction.proposedText);
  });

  test('only source sender with accepted correction and exact span can enqueue',
      () async {
    final message = f.ack(f.message(1));
    await store.mergeRemote(message);
    final correction = acceptedCorrection(message);
    await store.mergeCorrections(
        conversationId: f.conversation, corrections: [correction]);

    await expectLater(
      store.enqueueAnnotation(
          annotation(message: message, correction: correction, createdBy: f.b)),
      throwsFormatException,
    );
    await expectLater(
      store.enqueueAnnotation(annotation(
        message: message,
        correction: correction,
        spanText: 'quẩy',
        spanStart: 10,
        spanEnd: 14,
      )),
      throwsFormatException,
    );
  });

  test('membership removal hides annotation and blocks its pending outbox',
      () async {
    final message = f.ack(f.message(1));
    await store.mergeRemote(message);
    final correction = acceptedCorrection(message);
    await store.mergeCorrections(
        conversationId: f.conversation, corrections: [correction]);
    await store.enqueueAnnotation(
        annotation(message: message, correction: correction));

    await store.reconcileConversations([]);
    expect(await store.annotations(f.conversation), isEmpty);
    expect(await store.dueAnnotations(f.instant), isEmpty);
    await store
        .cacheConversation(ChatConversation(id: f.conversation, peerId: f.b));
    expect((await store.annotations(f.conversation)).single.syncStatus,
        ChatAnnotationSyncStatus.blocked);
  });

  test('SQLite v4 upgrades additively through v9 annotation cache', () async {
    await store.dispose();
    await local.close();
    final legacyPath = '${directory.path}/legacy_v4.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE chat_messages (
            owner_scope TEXT NOT NULL,id TEXT NOT NULL,
            PRIMARY KEY(owner_scope,id))''');
          await db.execute('''CREATE TABLE chat_corrections (
            owner_scope TEXT NOT NULL,id TEXT NOT NULL,
            PRIMARY KEY(owner_scope,id))''');
        },
      ),
    );
    await legacy.close();

    final upgraded =
        OperationalChatDatabase(factory: databaseFactoryFfi, path: legacyPath);
    final db = await upgraded.open();
    expect(await db.getVersion(), 9);
    expect(
        (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
            .map((row) => row['name']),
        contains('chat_slang_annotations'));
    await upgraded.close();

    local = OperationalChatDatabase(
        factory: databaseFactoryFfi, path: '${directory.path}/chat.db');
    store = OperationalChatStore(
      database: await local.open(),
      owner: ChatOwner(projectRef: f.project, userId: f.a),
    );
  });
}
