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
        version: 9,
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
          await _createVersion2(db);
          await _createVersion3(db);
          await _createVersion4(db);
          await _createVersion5(db);
          await _createVersion6(db);
          await _createVersion7(db);
          await _createVersion8(db);
          await _createVersion9(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createVersion2(db);
          if (oldVersion < 3) await _createVersion3(db);
          if (oldVersion < 4) await _createVersion4(db);
          if (oldVersion < 5) await _createVersion5(db);
          if (oldVersion < 6) await _createVersion6(db);
          if (oldVersion < 7) await _createVersion7(db);
          if (oldVersion < 8) await _createVersion8(db);
          if (oldVersion < 9) await _createVersion9(db);
        },
      ));

  static Future<void> _createVersion2(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(chat_conversations)');
    if (!columns.any((row) => row['name'] == 'last_read_at')) {
      await db.execute(
          'ALTER TABLE chat_conversations ADD COLUMN last_read_at INTEGER');
    }
    await db.execute('''CREATE TABLE IF NOT EXISTS chat_peer_profiles (
      owner_scope TEXT NOT NULL, peer_id TEXT NOT NULL,
      display_name TEXT NOT NULL DEFAULT '', username TEXT NOT NULL DEFAULT '',
      avatar_url TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL,
      PRIMARY KEY(owner_scope,peer_id)
    )''');
  }

  static Future<void> _createVersion3(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS chat_translations (
      owner_scope TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL,
      target_language_code TEXT NOT NULL CHECK(target_language_code IN ('vi','en')),
      translated_text TEXT, provider TEXT NOT NULL CHECK(provider='gemini'),
      model TEXT NOT NULL CHECK(model='gemini-3.5-flash-lite'),
      prompt_version TEXT NOT NULL CHECK(prompt_version='chat-translate-p1'),
      translator_version TEXT NOT NULL CHECK(translator_version='chat-translate-v1'),
      status TEXT NOT NULL CHECK(status IN ('queued','processing','succeeded','failed')),
      attempt_count INTEGER NOT NULL CHECK(attempt_count BETWEEN 0 AND 4),
      next_attempt_at INTEGER, error_code TEXT,
      created_at INTEGER NOT NULL, completed_at INTEGER, updated_at INTEGER NOT NULL,
      PRIMARY KEY(owner_scope,id),
      UNIQUE(owner_scope,message_id,target_language_code,translator_version),
      FOREIGN KEY(owner_scope,message_id) REFERENCES chat_messages(owner_scope,id) ON DELETE CASCADE,
      CHECK(error_code IS NULL OR (length(error_code) BETWEEN 1 AND 64 AND error_code NOT GLOB '*[^A-Z0-9_]*')),
      CHECK((status='succeeded' AND translated_text IS NOT NULL
        AND length(translated_text) BETWEEN 1 AND 16000 AND trim(translated_text)<>''
        AND completed_at IS NOT NULL AND error_code IS NULL AND next_attempt_at IS NULL)
        OR (status<>'succeeded' AND translated_text IS NULL AND completed_at IS NULL
          AND ((status='failed' AND error_code IS NOT NULL)
            OR (status<>'failed' AND error_code IS NULL))))
    )''');
    await db.execute('''CREATE INDEX IF NOT EXISTS chat_translation_message
      ON chat_translations(owner_scope,message_id,translator_version)''');
  }

  static Future<void> _createVersion4(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS chat_corrections (
      owner_scope TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL,
      author_id TEXT NOT NULL,
      target_language_code TEXT NOT NULL CHECK(target_language_code IN ('vi','en')),
      proposed_text TEXT NOT NULL CHECK(length(proposed_text) BETWEEN 1 AND 4000 AND trim(proposed_text)<>''),
      status TEXT NOT NULL CHECK(status IN ('proposed','accepted','rejected')),
      accepted_by TEXT, accepted_at INTEGER, rejected_by TEXT, rejected_at INTEGER,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      sync_status TEXT NOT NULL CHECK(sync_status IN
        ('synced','proposalPending','proposalBlocked','decisionPending','decisionBlocked')),
      pending_decision TEXT CHECK(pending_decision IN ('accepted','rejected')),
      attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 4),
      next_attempt_at INTEGER,
      PRIMARY KEY(owner_scope,id),
      FOREIGN KEY(owner_scope,message_id) REFERENCES chat_messages(owner_scope,id) ON DELETE CASCADE,
      CHECK((status='proposed' AND accepted_by IS NULL AND accepted_at IS NULL
        AND rejected_by IS NULL AND rejected_at IS NULL)
        OR (status='accepted' AND accepted_by IS NOT NULL AND accepted_at IS NOT NULL
          AND rejected_by IS NULL AND rejected_at IS NULL)
        OR (status='rejected' AND rejected_by IS NOT NULL AND rejected_at IS NOT NULL
          AND accepted_by IS NULL AND accepted_at IS NULL)),
      CHECK((sync_status='synced' AND pending_decision IS NULL
          AND attempt_count=0 AND next_attempt_at IS NULL)
        OR (sync_status='proposalPending' AND status='proposed'
          AND pending_decision IS NULL AND next_attempt_at IS NOT NULL)
        OR (sync_status='proposalBlocked' AND status='proposed'
          AND pending_decision IS NULL AND next_attempt_at IS NULL)
        OR (sync_status='decisionPending' AND status='proposed'
          AND pending_decision IS NOT NULL AND next_attempt_at IS NOT NULL)
        OR (sync_status='decisionBlocked' AND status='proposed'
          AND pending_decision IS NOT NULL AND next_attempt_at IS NULL))
    )''');
    await db.execute('''CREATE INDEX IF NOT EXISTS chat_correction_message
      ON chat_corrections(owner_scope,message_id,created_at,id)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS chat_correction_outbox
      ON chat_corrections(owner_scope,next_attempt_at)
      WHERE sync_status IN ('proposalPending','decisionPending')''');
    await db.execute(
        '''CREATE UNIQUE INDEX IF NOT EXISTS chat_correction_one_proposed
      ON chat_corrections(owner_scope,message_id,author_id)
      WHERE status='proposed' AND sync_status<>'proposalBlocked' ''');
  }

  static Future<void> _createVersion5(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS chat_slang_annotations (
      owner_scope TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL,
      correction_id TEXT NOT NULL, created_by TEXT NOT NULL,
      span_text TEXT NOT NULL CHECK(length(span_text) BETWEEN 1 AND 4000 AND trim(span_text)<>''),
      span_start INTEGER NOT NULL CHECK(span_start>=0),
      span_end INTEGER NOT NULL CHECK(span_end>span_start),
      tag_type TEXT NOT NULL CHECK(tag_type IN
        ('slang','abbreviation','informal_address','idiom','typo_or_phonetic_spelling','other')),
      normalized_source TEXT NOT NULL
        CHECK(length(normalized_source) BETWEEN 1 AND 4000 AND trim(normalized_source)<>''),
      annotator_role TEXT NOT NULL DEFAULT 'source_speaker'
        CHECK(annotator_role='source_speaker'),
      status TEXT NOT NULL DEFAULT 'active' CHECK(status='active'),
      created_at INTEGER NOT NULL,
      sync_status TEXT NOT NULL CHECK(sync_status IN ('synced','pending','blocked')),
      attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count BETWEEN 0 AND 4),
      next_attempt_at INTEGER,
      PRIMARY KEY(owner_scope,id),
      FOREIGN KEY(owner_scope,message_id)
        REFERENCES chat_messages(owner_scope,id) ON DELETE CASCADE,
      FOREIGN KEY(owner_scope,correction_id)
        REFERENCES chat_corrections(owner_scope,id) ON DELETE CASCADE,
      UNIQUE(owner_scope,correction_id,created_by,span_start,span_end,tag_type,normalized_source),
      CHECK((sync_status='synced' AND attempt_count=0 AND next_attempt_at IS NULL)
        OR (sync_status='pending' AND next_attempt_at IS NOT NULL)
        OR (sync_status='blocked' AND next_attempt_at IS NULL))
    )''');
    await db.execute('''CREATE INDEX IF NOT EXISTS chat_annotation_message
      ON chat_slang_annotations(owner_scope,message_id,created_at,id)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS chat_annotation_outbox
      ON chat_slang_annotations(owner_scope,next_attempt_at)
      WHERE sync_status='pending' ''');
  }

  static Future<void> _createVersion6(DatabaseExecutor db) async {
    // Some pre-release v4 databases did not contain the optional translation
    // cache. Create its v1 shape first so this additive rebuild is safe for
    // every database version already distributed to testers.
    await _createVersion3(db);
    await db.execute('''CREATE TABLE chat_translations_v6 (
      owner_scope TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL,
      target_language_code TEXT NOT NULL CHECK(target_language_code IN ('vi','en')),
      translated_text TEXT, provider TEXT NOT NULL,
      model TEXT NOT NULL, prompt_version TEXT NOT NULL,
      translator_version TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('queued','processing','succeeded','failed')),
      attempt_count INTEGER NOT NULL CHECK(attempt_count BETWEEN 0 AND 4),
      next_attempt_at INTEGER, error_code TEXT,
      created_at INTEGER NOT NULL, completed_at INTEGER, updated_at INTEGER NOT NULL,
      PRIMARY KEY(owner_scope,id),
      UNIQUE(owner_scope,message_id,target_language_code,translator_version),
      FOREIGN KEY(owner_scope,message_id) REFERENCES chat_messages(owner_scope,id) ON DELETE CASCADE,
      CHECK((provider='gemini' AND model='gemini-3.5-flash-lite'
          AND prompt_version='chat-translate-p1' AND translator_version='chat-translate-v1')
        OR (provider='vilao' AND model='gemini-3.8-flash'
          AND prompt_version='chat-translate-p2' AND translator_version='chat-translate-v2')),
      CHECK(error_code IS NULL OR (length(error_code) BETWEEN 1 AND 64 AND error_code NOT GLOB '*[^A-Z0-9_]*')),
      CHECK((status='succeeded' AND translated_text IS NOT NULL
        AND length(translated_text) BETWEEN 1 AND 16000 AND trim(translated_text)<>''
        AND completed_at IS NOT NULL AND error_code IS NULL AND next_attempt_at IS NULL)
        OR (status<>'succeeded' AND translated_text IS NULL AND completed_at IS NULL
          AND ((status='failed' AND error_code IS NOT NULL)
            OR (status<>'failed' AND error_code IS NULL))))
    )''');
    await db.execute('''INSERT INTO chat_translations_v6
      SELECT * FROM chat_translations''');
    await db.execute('DROP TABLE chat_translations');
    await db.execute(
        'ALTER TABLE chat_translations_v6 RENAME TO chat_translations');
    await db.execute('''CREATE INDEX chat_translation_message
      ON chat_translations(owner_scope,message_id,translator_version)''');
  }

  static Future<void> _createVersion7(DatabaseExecutor db) async {
    // peer_id remains the non-null legacy identity column so upgrading never
    // rebuilds the parent table or risks cascading away cached messages.
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_conversations'");
    // A few pre-release correction/annotation-only fixtures intentionally had
    // no conversation cache. Keep them readable; normal app DBs always do.
    if (tables.isEmpty) return;
    await db.execute('''ALTER TABLE chat_conversations ADD COLUMN kind TEXT
      NOT NULL DEFAULT 'direct' CHECK(kind IN ('direct','group'))''');
    await db.execute('ALTER TABLE chat_conversations ADD COLUMN group_id TEXT');
    await db
        .execute('ALTER TABLE chat_conversations ADD COLUMN group_title TEXT');
    await db.execute('ALTER TABLE chat_conversations '
        'ADD COLUMN group_avatar_url TEXT NOT NULL DEFAULT \'\'');
    await db.execute('''ALTER TABLE chat_conversations
      ADD COLUMN group_member_count INTEGER NOT NULL DEFAULT 2
      CHECK(group_member_count>=1)''');
    await db.execute('''ALTER TABLE chat_conversations
      ADD COLUMN group_status TEXT NOT NULL DEFAULT 'active'
      CHECK(group_status IN ('active','archived'))''');
    await db.execute('''ALTER TABLE chat_conversations
      ADD COLUMN group_is_muted INTEGER NOT NULL DEFAULT 0
      CHECK(group_is_muted IN (0,1))''');
    await db.execute('''CREATE UNIQUE INDEX chat_conversation_group_identity
      ON chat_conversations(owner_scope,group_id) WHERE kind='group' ''');
  }

  static Future<void> _createVersion8(DatabaseExecutor db) async {
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chat_conversations'");
    if (tables.isEmpty) return;
    await db.execute(
        'ALTER TABLE chat_conversations ADD COLUMN social_owner_id TEXT');
  }

  static Future<void> _createVersion9(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE chat_translations_v9 (
      owner_scope TEXT NOT NULL, id TEXT NOT NULL, message_id TEXT NOT NULL,
      target_language_code TEXT NOT NULL CHECK(target_language_code IN ('vi','en')),
      translated_text TEXT, provider TEXT NOT NULL,
      model TEXT NOT NULL, prompt_version TEXT NOT NULL,
      translator_version TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('queued','processing','succeeded','failed')),
      attempt_count INTEGER NOT NULL CHECK(attempt_count BETWEEN 0 AND 4),
      next_attempt_at INTEGER, error_code TEXT,
      created_at INTEGER NOT NULL, completed_at INTEGER, updated_at INTEGER NOT NULL,
      PRIMARY KEY(owner_scope,id),
      UNIQUE(owner_scope,message_id,target_language_code,translator_version),
      FOREIGN KEY(owner_scope,message_id) REFERENCES chat_messages(owner_scope,id) ON DELETE CASCADE,
      CHECK((provider='gemini' AND model='gemini-3.5-flash-lite'
          AND prompt_version='chat-translate-p1' AND translator_version='chat-translate-v1')
        OR (provider='vilao' AND model='gemini-3.8-flash'
          AND prompt_version='chat-translate-p2' AND translator_version='chat-translate-v2')
        OR (provider='gemini' AND model='gemini-3-flash-preview'
          AND prompt_version='chat-translate-p3' AND translator_version='chat-translate-v3')),
      CHECK(error_code IS NULL OR (length(error_code) BETWEEN 1 AND 64 AND error_code NOT GLOB '*[^A-Z0-9_]*')),
      CHECK((status='succeeded' AND translated_text IS NOT NULL
        AND length(translated_text) BETWEEN 1 AND 16000 AND trim(translated_text)<>''
        AND completed_at IS NOT NULL AND error_code IS NULL AND next_attempt_at IS NULL)
        OR (status<>'succeeded' AND translated_text IS NULL AND completed_at IS NULL
          AND ((status='failed' AND error_code IS NOT NULL)
            OR (status<>'failed' AND error_code IS NULL))))
    )''');
    await db.execute('''INSERT INTO chat_translations_v9
      SELECT * FROM chat_translations''');
    await db.execute('DROP TABLE chat_translations');
    await db.execute(
        'ALTER TABLE chat_translations_v9 RENAME TO chat_translations');
    await db.execute('''CREATE INDEX chat_translation_message
      ON chat_translations(owner_scope,message_id,translator_version)''');
  }

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
