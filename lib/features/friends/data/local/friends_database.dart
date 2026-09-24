import 'package:sqflite/sqflite.dart';

import '../../../library/data/local/library_database_factory_native.dart'
    if (dart.library.js_interop) '../../../library/data/local/library_database_factory_web.dart'
    as platform;

/// Friends have an independent operational cache and never open or migrate the
/// Library/AI database or the Chat operational database.
final class FriendsDatabase {
  FriendsDatabase({required this.factory, required this.path});

  final DatabaseFactory factory;
  final String path;
  Future<Database>? _opening;

  Future<Database> open() => _opening ??= factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE friend_connections (
              project_ref TEXT NOT NULL,
              owner_id TEXT NOT NULL,
              peer_id TEXT NOT NULL,
              display_name TEXT NOT NULL DEFAULT '',
              username TEXT NOT NULL DEFAULT '',
              avatar_url TEXT,
              study_points INTEGER NOT NULL CHECK(study_points >= 0),
              streak_days INTEGER NOT NULL CHECK(streak_days >= 0),
              user_level INTEGER NOT NULL CHECK(user_level >= 1),
              relationship_state TEXT NOT NULL CHECK(relationship_state IN
                ('incoming_pending','outgoing_pending','accepted')),
              server_updated_at INTEGER NOT NULL,
              cached_at INTEGER NOT NULL,
              PRIMARY KEY(project_ref, owner_id, peer_id)
            )''');
            await db.execute('''CREATE INDEX friend_connections_list_order
              ON friend_connections(
                project_ref,owner_id,relationship_state,
                server_updated_at DESC,peer_id DESC
              )''');
            await db.execute('''CREATE TABLE friend_sync_meta (
              project_ref TEXT NOT NULL,
              owner_id TEXT NOT NULL,
              list_kind TEXT NOT NULL CHECK(list_kind IN
                ('incoming','outgoing','accepted')),
              refreshed_at INTEGER NOT NULL,
              PRIMARY KEY(project_ref,owner_id,list_kind)
            )''');
          },
        ),
      );

  Future<void> close() async {
    final db = await _opening;
    _opening = null;
    await db?.close();
  }
}

Future<FriendsDatabase> createFriendsDatabase() async {
  final libraryPath = await platform.libraryDatabasePath();
  final slash = libraryPath.lastIndexOf('/');
  final backslash = libraryPath.lastIndexOf('\\');
  final boundary = slash > backslash ? slash : backslash;
  return FriendsDatabase(
    factory: platform.libraryDatabaseFactory,
    path: '${libraryPath.substring(0, boundary + 1)}capy_friends.db',
  );
}
