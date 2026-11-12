import 'dart:io';

import 'package:capy_vocab/features/chat/data/operational_chat_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('local v8 upgrade preserves Album messages, retries and v2 translations',
      () async {
    final directory = await Directory.systemTemp.createTemp('chat_upgrade_');
    final path = '${directory.path}/chat.db';
    final legacy = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 8,
            onCreate: (db, _) async {
              await db.execute('''CREATE TABLE chat_conversations (
        owner_scope TEXT, id TEXT, peer_id TEXT NOT NULL,
        last_message_at INTEGER, active INTEGER DEFAULT 1, last_read_at INTEGER,
        PRIMARY KEY(owner_scope,id), UNIQUE(owner_scope,peer_id))''');
              await db.execute('''CREATE TABLE chat_messages (
        owner_scope TEXT, id TEXT, conversation_id TEXT, sender_id TEXT,
        raw_text TEXT, source_language_code TEXT, client_generated_id TEXT,
        client_created_at INTEGER, sent_at INTEGER, send_status TEXT,
        attempt_count INTEGER DEFAULT 0, next_attempt_at INTEGER,
        attachment_kind TEXT DEFAULT 'none', attachment_source_photo_note_id TEXT,
        attachment_object_path TEXT, attachment_mime_type TEXT,
        attachment_byte_size INTEGER, attachment_available INTEGER DEFAULT 1,
        attachment_local_relative_path TEXT, attachment_labels TEXT DEFAULT '[]',
        PRIMARY KEY(owner_scope,id), FOREIGN KEY(owner_scope,conversation_id)
          REFERENCES chat_conversations(owner_scope,id) ON DELETE CASCADE)''');
              await db.execute('''CREATE TABLE chat_translations (
        owner_scope TEXT, id TEXT, message_id TEXT, target_language_code TEXT,
        translated_text TEXT, provider TEXT, model TEXT, prompt_version TEXT,
        translator_version TEXT, status TEXT, attempt_count INTEGER,
        next_attempt_at INTEGER, error_code TEXT, created_at INTEGER,
        completed_at INTEGER, updated_at INTEGER)''');
              await db.execute('''CREATE TABLE chat_album_image_invalidations (
        owner_scope TEXT, source_photo_note_id TEXT, created_at INTEGER,
        attempt_count INTEGER DEFAULT 0, next_attempt_at INTEGER,
        blocked INTEGER DEFAULT 0, PRIMARY KEY(owner_scope,source_photo_note_id))''');
              await db.insert('chat_conversations', {
                'owner_scope': 'owner',
                'id': 'conversation',
                'peer_id': 'peer',
              });
              await db.insert('chat_messages', {
                'owner_scope': 'owner',
                'id': 'image',
                'conversation_id': 'conversation',
                'sender_id': 'owner',
                'raw_text': 'Album',
                'source_language_code': 'vi',
                'client_generated_id': 'image',
                'client_created_at': 1,
                'send_status': 'pending',
                'attachment_kind': 'album_image',
                'attachment_labels': '[{"word":"cat"}]',
                'attachment_local_relative_path': 'photos/cat.jpg',
              });
              await db.insert('chat_album_image_invalidations', {
                'owner_scope': 'owner',
                'source_photo_note_id': 'photo',
                'created_at': 1,
                'attempt_count': 2,
                'next_attempt_at': 3,
              });
              await db.insert('chat_translations', {
                'owner_scope': 'owner',
                'id': 'translation',
                'message_id': 'image',
                'target_language_code': 'en',
                'translated_text': 'Album',
                'provider': 'vilao',
                'model': 'gemini-3.8-flash',
                'prompt_version': 'chat-translate-p2',
                'translator_version': 'chat-translate-v2',
                'status': 'succeeded',
                'attempt_count': 1,
                'created_at': 1,
                'completed_at': 2,
                'updated_at': 2,
              });
            }));
    await legacy.close();
    final upgraded =
        OperationalChatDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(() async {
      await upgraded.close();
      await directory.delete(recursive: true);
    });
    final db = await upgraded.open();
    expect(await db.getVersion(), 11);
    final conversation = (await db.query('chat_conversations')).single;
    expect(conversation['kind'], 'direct');
    expect(conversation['social_owner_id'], isNull);
    final message = (await db.query('chat_messages')).single;
    expect(message['attachment_labels'], '[{"word":"cat"}]');
    expect(message['attachment_local_relative_path'], 'photos/cat.jpg');
    expect(
        (await db.query('chat_album_image_invalidations'))
            .single['attempt_count'],
        2);
    expect((await db.query('chat_translations')).single['translator_version'],
        'chat-translate-v2');
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await db.insert('chat_translations', {
      'owner_scope': 'owner',
      'id': 'v3',
      'message_id': 'image',
      'target_language_code': 'en',
      'provider': 'gemini',
      'model': 'gemini-3-flash-preview',
      'prompt_version': 'chat-translate-p3',
      'translator_version': 'chat-translate-v3',
      'status': 'queued',
      'attempt_count': 0,
      'created_at': 3,
      'updated_at': 3,
    });
    expect(await db.query('chat_translations'), hasLength(2));
  });
}
