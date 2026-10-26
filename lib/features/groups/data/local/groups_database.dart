import 'package:sqflite/sqflite.dart';

import '../../../library/data/local/library_database_factory_native.dart'
    if (dart.library.js_interop) '../../../library/data/local/library_database_factory_web.dart'
    as platform;

final class GroupsDatabase {
  GroupsDatabase({required this.factory, required this.path});

  final DatabaseFactory factory;
  final String path;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE learning_group_summaries (
              project_ref TEXT NOT NULL,
              owner_id TEXT NOT NULL,
              group_id TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              group_status TEXT NOT NULL,
              member_role TEXT NOT NULL,
              membership_status TEXT NOT NULL,
              is_muted INTEGER NOT NULL CHECK(is_muted IN (0,1)),
              active_student_count INTEGER NOT NULL CHECK(active_student_count >= 0),
              pending_student_count INTEGER NOT NULL CHECK(pending_student_count >= 0),
              server_updated_at INTEGER NOT NULL,
              cached_at INTEGER NOT NULL,
              PRIMARY KEY(project_ref,owner_id,group_id)
            )''');
            await db.execute('''CREATE INDEX learning_group_summaries_order
              ON learning_group_summaries(
                project_ref,owner_id,server_updated_at DESC,group_id DESC
              )''');
            await db.execute('''CREATE TABLE learning_group_sync_meta (
              project_ref TEXT NOT NULL,
              owner_id TEXT NOT NULL,
              refreshed_at INTEGER NOT NULL,
              PRIMARY KEY(project_ref,owner_id)
            )''');
            await _createDetailCache(db);
          },
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _createDetailCache(db);
          },
        ),
      );

  Future<void> close() async {
    final db = await _opening;
    _opening = null;
    await db?.close();
  }
}

Future<void> _createDetailCache(Database db) async {
  const parent = '''FOREIGN KEY(project_ref,owner_id,group_id)
    REFERENCES learning_group_summaries(project_ref,owner_id,group_id)
    ON DELETE CASCADE''';
  await db.execute('''CREATE TABLE learning_group_detail_sync (
    project_ref TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    includes_management INTEGER NOT NULL CHECK(includes_management IN (0,1)),
    refreshed_at INTEGER NOT NULL,
    PRIMARY KEY(project_ref,owner_id,group_id),
    $parent
  )''');
  await db.execute('''CREATE TABLE learning_group_member_cache (
    project_ref TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    display_name TEXT NOT NULL,
    username TEXT NOT NULL,
    avatar_url TEXT,
    member_role TEXT NOT NULL,
    membership_status TEXT NOT NULL,
    is_muted INTEGER NOT NULL CHECK(is_muted IN (0,1)),
    server_updated_at INTEGER NOT NULL,
    PRIMARY KEY(project_ref,owner_id,group_id,user_id),
    $parent
  )''');
  await db.execute('''CREATE INDEX learning_group_member_cache_order
    ON learning_group_member_cache(
      project_ref,owner_id,group_id,member_role,membership_status,
      server_updated_at DESC,user_id
    )''');
  await db.execute('''CREATE TABLE learning_group_announcement_cache (
    project_ref TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    announcement_id TEXT NOT NULL,
    author_user_id TEXT NOT NULL,
    author_display_name TEXT NOT NULL,
    body TEXT NOT NULL,
    is_pinned INTEGER NOT NULL CHECK(is_pinned IN (0,1)),
    created_at INTEGER NOT NULL,
    server_updated_at INTEGER NOT NULL,
    PRIMARY KEY(project_ref,owner_id,group_id,announcement_id),
    $parent
  )''');
  await db.execute('''CREATE INDEX learning_group_announcement_cache_order
    ON learning_group_announcement_cache(
      project_ref,owner_id,group_id,is_pinned DESC,created_at DESC,
      announcement_id DESC
    )''');
  await db.execute('''CREATE TABLE learning_group_invite_status_cache (
    project_ref TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    has_active_invite INTEGER NOT NULL CHECK(has_active_invite IN (0,1)),
    expires_at INTEGER,
    use_count INTEGER NOT NULL CHECK(use_count >= 0),
    last_used_at INTEGER,
    created_at INTEGER,
    PRIMARY KEY(project_ref,owner_id,group_id),
    $parent
  )''');
  await db.execute('''CREATE TABLE learning_group_moderation_event_cache (
    project_ref TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    group_id TEXT NOT NULL,
    event_id INTEGER NOT NULL,
    actor_user_id TEXT NOT NULL,
    actor_display_name TEXT NOT NULL,
    target_user_id TEXT,
    target_display_name TEXT,
    target_message_id TEXT,
    action TEXT NOT NULL,
    reason_code TEXT,
    occurred_at INTEGER NOT NULL,
    PRIMARY KEY(project_ref,owner_id,group_id,event_id),
    $parent
  )''');
  await db.execute('''CREATE INDEX learning_group_moderation_cache_order
    ON learning_group_moderation_event_cache(
      project_ref,owner_id,group_id,occurred_at DESC,event_id DESC
    )''');
}

Future<GroupsDatabase> createGroupsDatabase() async {
  final libraryPath = await platform.libraryDatabasePath();
  final slash = libraryPath.lastIndexOf('/');
  final backslash = libraryPath.lastIndexOf('\\');
  final boundary = slash > backslash ? slash : backslash;
  return GroupsDatabase(
    factory: platform.libraryDatabaseFactory,
    path: '${libraryPath.substring(0, boundary + 1)}capy_groups.db',
  );
}
