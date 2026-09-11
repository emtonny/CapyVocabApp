import 'package:sqflite/sqflite.dart';

import 'library_database_schema.dart';

/// Opens the versioned Library database against an injected sqflite factory.
///
/// M2A keeps this disconnected from production so the existing version-1
/// scanner database cannot be upgraded before the migration gate is approved.
final class LibraryDatabase {
  LibraryDatabase({required DatabaseFactory factory, required this.path})
      : _factory = factory;

  final DatabaseFactory _factory;
  final String path;

  Future<Database>? _databaseFuture;

  Future<Database> open() {
    return _databaseFuture ??= _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: LibraryDatabaseSchema.version,
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
        onCreate: (database, version) =>
            LibraryDatabaseSchema.createLatest(database),
        onUpgrade: LibraryDatabaseSchema.upgrade,
        onOpen: LibraryDatabaseSchema.queueLegacyRows,
      ),
    );
  }

  Future<void> close() async {
    final database = await _databaseFuture;
    _databaseFuture = null;
    await database?.close();
  }
}
