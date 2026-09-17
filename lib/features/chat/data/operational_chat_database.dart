import 'package:sqflite/sqflite.dart';

import '../../library/data/local/library_database_factory_native.dart'
    if (dart.library.js_interop) '../../library/data/local/library_database_factory_web.dart'
    as platform;

/// Separate operational DB. Never upgrades/opens the Library/AI database.
final class OperationalChatDatabase {
  OperationalChatDatabase({required this.factory, required this.path});
  final DatabaseFactory factory;
  final String path;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= factory.openDatabase(path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE chat_conversations (
          owner_scope TEXT NOT NULL, id TEXT NOT NULL, peer_id TEXT NOT NULL,
          last_message_at INTEGER, active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
          PRIMARY KEY(owner_scope,id), UNIQUE(owner_scope,peer_id)
        )''');
          // One durable message row is also its outbox: no separate queue can
          // commit without the raw message or forget it on process death.
          await db.execute('''CREATE TABLE chat_messages (
          owner_scope TEXT NOT NULL, id TEXT NOT NULL, conversation_id TEXT NOT NULL,
          sender_id TEXT NOT NULL, raw_text TEXT NOT NULL CHECK(length(raw_text) BETWEEN 1 AND 4000),
          source_language_code TEXT NOT NULL CHECK(source_language_code IN ('vi','en')),
          client_generated_id TEXT NOT NULL, client_created_at INTEGER NOT NULL,
          sent_at INTEGER, send_status TEXT NOT NULL CHECK(send_status IN ('pending','sent','blocked')),
          attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 10),
          next_attempt_at INTEGER,
          PRIMARY KEY(owner_scope,id), UNIQUE(owner_scope,sender_id,client_generated_id),
          FOREIGN KEY(owner_scope,conversation_id) REFERENCES chat_conversations(owner_scope,id) ON DELETE CASCADE,
          CHECK(send_status <> 'sent' OR sent_at IS NOT NULL)
        )''');
          await db.execute(
              'CREATE INDEX chat_order ON chat_messages(owner_scope,conversation_id,sent_at,client_created_at,id)');
          await db.execute(
              "CREATE INDEX chat_outbox ON chat_messages(owner_scope,next_attempt_at) WHERE send_status='pending'");
        },
      ));

  Future<void> close() async {
    final db = await _opening;
    _opening = null;
    await db?.close();
  }
}

Future<OperationalChatDatabase> createOperationalChatDatabase() async {
  final libraryPath = await platform.libraryDatabasePath();
  final slash = libraryPath.lastIndexOf('/');
  final backslash = libraryPath.lastIndexOf('\\');
  final boundary = slash > backslash ? slash : backslash;
  return OperationalChatDatabase(
      factory: platform.libraryDatabaseFactory,
      path:
          '${libraryPath.substring(0, boundary + 1)}capy_chat_operational.db');
}
