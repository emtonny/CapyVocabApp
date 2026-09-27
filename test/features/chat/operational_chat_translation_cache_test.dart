import 'dart:async';
import 'dart:io';

import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:capy_vocab/features/chat/data/operational_chat_store.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const ownerA = '10000000-0000-0000-0000-000000000001';
const ownerB = '10000000-0000-0000-0000-000000000002';
const conversation = '20000000-0000-0000-0000-000000000001';
const messageId = '30000000-0000-0000-0000-000000000001';
const translationId = '40000000-0000-0000-0000-000000000001';
const project = 'ssssssssssssssssssss';
final createdAt = DateTime.utc(2026, 9, 18, 12);

OperationalChatMessage rawMessage({String sender = ownerA}) =>
    OperationalChatMessage(
      id: messageId,
      conversationId: conversation,
      senderId: sender,
      rawText: sender == ownerA ? 'Xin chào 😀' : 'Hello 😀',
      sourceLanguageCode: sender == ownerA ? 'vi' : 'en',
      clientGeneratedId: '50000000-0000-0000-0000-000000000001',
      clientCreatedAt: createdAt,
      sentAt: createdAt,
      sendStatus: ChatSendStatus.sent,
    );

OperationalChatTranslation translation({
  ChatTranslationStatus status = ChatTranslationStatus.succeeded,
  int attemptCount = 1,
  DateTime? updatedAt,
  String? translatedText,
  String? errorCode,
  String targetLanguageCode = 'en',
}) =>
    OperationalChatTranslation(
      id: translationId,
      messageId: messageId,
      targetLanguageCode: targetLanguageCode,
      translatedText: status == ChatTranslationStatus.succeeded
          ? translatedText ?? 'Hello 😀'
          : null,
      provider: operationalChatTranslationProvider,
      model: operationalChatTranslationModel,
      promptVersion: operationalChatPromptVersion,
      translatorVersion: operationalChatTranslatorVersion,
      status: status,
      attemptCount: attemptCount,
      nextAttemptAt: status == ChatTranslationStatus.failed
          ? createdAt.add(const Duration(seconds: 5))
          : null,
      errorCode: status == ChatTranslationStatus.failed
          ? errorCode ?? 'PROVIDER_TIMEOUT'
          : null,
      createdAt: createdAt,
      completedAt: status == ChatTranslationStatus.succeeded ? createdAt : null,
      updatedAt: updatedAt ?? createdAt,
    );

Map<String, dynamic> remoteTranslation({
  String translatorVersion = operationalChatTranslatorVersion,
  String status = 'succeeded',
  Object? translatedText = 'Hello 😀',
  String timestamp = '2026-09-18T12:00:00.000Z',
}) =>
    {
      'id': translationId,
      'message_id': messageId,
      'target_language_code': 'en',
      'translated_text': translatedText,
      'provider': operationalChatTranslationProvider,
      'model': operationalChatTranslationModel,
      'prompt_version': operationalChatPromptVersion,
      'translator_version': translatorVersion,
      'status': status,
      'attempt_count': 1,
      'next_attempt_at': null,
      'error_code': null,
      'created_at': timestamp,
      'completed_at': status == 'succeeded' ? timestamp : null,
      'updated_at': timestamp,
    };

void main() {
  late Directory directory;
  late OperationalChatDatabase local;
  late Database database;
  late OperationalChatStore store;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_chat_c4e_');
    local = OperationalChatDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/chat.db',
    );
    database = await local.open();
    store = OperationalChatStore(
      database: database,
      owner: ChatOwner(projectRef: project, userId: ownerA),
    );
    await store.cacheConversation(
      ChatConversation(id: conversation, peerId: ownerB),
    );
    await store.mergeRemote(rawMessage());
  });

  tearDown(() async {
    await store.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  test('version 2 database upgrades additively and preserves raw rows',
      () async {
    final path = '${directory.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE chat_conversations (
            owner_scope TEXT NOT NULL, id TEXT NOT NULL, peer_id TEXT NOT NULL,
            last_message_at INTEGER, active INTEGER NOT NULL DEFAULT 1,
            last_read_at INTEGER, PRIMARY KEY(owner_scope,id),
            UNIQUE(owner_scope,peer_id))''');
          await db.execute('''CREATE TABLE chat_messages (
            owner_scope TEXT NOT NULL, id TEXT NOT NULL,
            conversation_id TEXT NOT NULL, sender_id TEXT NOT NULL,
            raw_text TEXT NOT NULL, source_language_code TEXT NOT NULL,
            client_generated_id TEXT NOT NULL, client_created_at INTEGER NOT NULL,
            sent_at INTEGER, send_status TEXT NOT NULL, attempt_count INTEGER NOT NULL,
            next_attempt_at INTEGER, PRIMARY KEY(owner_scope,id),
            UNIQUE(owner_scope,sender_id,client_generated_id),
            FOREIGN KEY(owner_scope,conversation_id)
              REFERENCES chat_conversations(owner_scope,id) ON DELETE CASCADE)''');
          await db.execute('''CREATE TABLE chat_peer_profiles (
            owner_scope TEXT NOT NULL, peer_id TEXT NOT NULL,
            display_name TEXT NOT NULL DEFAULT '', username TEXT NOT NULL DEFAULT '',
            avatar_url TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL,
            PRIMARY KEY(owner_scope,peer_id))''');
          await db.insert('chat_conversations', {
            'owner_scope': '$project:$ownerA',
            'id': conversation,
            'peer_id': ownerB,
          });
        },
      ),
    );
    await legacy.close();

    final upgraded = OperationalChatDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    final upgradedDb = await upgraded.open();
    expect(await upgradedDb.getVersion(), 6);
    expect(await upgradedDb.query('chat_conversations'), hasLength(1));
    expect(
      (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_translations'",
      )),
      hasLength(1),
    );
    expect(
      (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_corrections'",
      )),
      hasLength(1),
    );
    expect(
      (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_slang_annotations'",
      )),
      hasLength(1),
    );
    await upgraded.close();
  });

  test('remote codec accepts the locked success and rejects stale policy', () {
    final decoded = OperationalChatTranslation.fromRemote(remoteTranslation());
    expect(decoded.status, ChatTranslationStatus.succeeded);
    expect(decoded.translatedText, 'Hello 😀');
    expect(decoded.updatedAt.isUtc, isTrue);

    for (final row in [
      remoteTranslation(translatorVersion: 'chat-translate-old'),
      {...remoteTranslation(), 'model': 'other-model'},
      remoteTranslation(translatedText: '   '),
      remoteTranslation(timestamp: '2026-09-18T12:00:00'),
    ]) {
      expect(() => OperationalChatTranslation.fromRemote(row),
          throwsFormatException);
    }
  });

  test('translation cache is idempotent and emits owner-scoped updates',
      () async {
    final emissions = <List<OperationalChatTranslation>>[];
    final initial = Completer<void>();
    final updated = Completer<void>();
    final subscription = store.watchTranslations(conversation).listen((rows) {
      emissions.add(rows);
      if (rows.isEmpty && !initial.isCompleted) initial.complete();
      if (rows.isNotEmpty && !updated.isCompleted) updated.complete();
    });
    await initial.future;

    await store.mergeTranslations(
      conversationId: conversation,
      translations: [translation()],
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [translation()],
    );
    await updated.future;

    expect((await store.translations(conversation)), hasLength(1));
    expect(emissions.first, isEmpty);
    expect(emissions.last.single.translatedText, 'Hello 😀');
    await subscription.cancel();
  });

  test('cache isolates account and project while sharing the server row',
      () async {
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [translation()],
    );
    for (final owner in [
      ChatOwner(projectRef: project, userId: ownerB),
      ChatOwner(projectRef: 'pppppppppppppppppppp', userId: ownerA),
    ]) {
      final other = OperationalChatStore(database: database, owner: owner);
      expect(await other.translations(conversation), isEmpty);
      await other.cacheConversation(ChatConversation(
        id: conversation,
        peerId: owner.userId == ownerA ? ownerB : ownerA,
      ));
      await other.mergeRemote(rawMessage());
      await other.mergeTranslations(
        conversationId: conversation,
        translations: [translation()],
      );
      expect((await other.translations(conversation)).single.id, translationId);
      await other.dispose();
    }
    expect((await store.translations(conversation)), hasLength(1));
    expect(await database.query('chat_translations'), hasLength(3));
  });

  test('newer states replace pending state while stale state is ignored',
      () async {
    final queued = translation(
      status: ChatTranslationStatus.queued,
      attemptCount: 0,
    );
    final processing = translation(
      status: ChatTranslationStatus.processing,
      updatedAt: createdAt.add(const Duration(seconds: 2)),
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [queued],
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [processing],
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [queued],
    );
    expect((await store.translations(conversation)).single.status,
        ChatTranslationStatus.processing);
  });

  test('successful cache is immutable and conflict rolls back atomically',
      () async {
    final success = translation(
      updatedAt: createdAt.add(const Duration(seconds: 3)),
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [success],
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [success],
    );
    await expectLater(
      store.mergeTranslations(
        conversationId: conversation,
        translations: [
          translation(
            updatedAt: createdAt.add(const Duration(seconds: 4)),
            translatedText: 'Rewritten',
          )
        ],
      ),
      throwsFormatException,
    );
    expect((await store.translations(conversation)).single.translatedText,
        'Hello 😀');
  });

  test('stale response cannot regress an immutable successful cache', () async {
    final success = translation(
      updatedAt: createdAt.add(const Duration(seconds: 3)),
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [success],
    );
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [
        translation(
          status: ChatTranslationStatus.processing,
          updatedAt: createdAt.add(const Duration(seconds: 2)),
        ),
      ],
    );
    final cached = (await store.translations(conversation)).single;
    expect(cached.status, ChatTranslationStatus.succeeded);
    expect(cached.translatedText, 'Hello 😀');
  });

  test('invalid translation cannot damage raw cache', () async {
    await expectLater(
      store.mergeTranslations(
        conversationId: conversation,
        translations: [translation(targetLanguageCode: 'vi')],
      ),
      throwsFormatException,
    );
    expect((await store.messages(conversation)).single.rawText, 'Xin chào 😀');
    expect(await store.translations(conversation), isEmpty);
  });

  test('removing a no-longer-visible raw message cascades its translation',
      () async {
    await store.mergeTranslations(
      conversationId: conversation,
      translations: [translation()],
    );
    await store.reconcileHistory(conversation, const []);
    expect(await store.messages(conversation), isEmpty);
    expect(await store.translations(conversation), isEmpty);
  });
}
