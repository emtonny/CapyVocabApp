import 'library_database_factory.dart';
import 'sqlite_library_store.dart';

/// Production composition root for the approved D1 SQLite adapters.
///
/// Authentication still owns creation of LocalAccount and the caller owns the
/// UUID generator. This keeps account/logout policy and ID generation explicit.
Future<SqliteLibraryStore> createDefaultSqliteLibraryStore({
  required LibraryIdGenerator idGenerator,
  LibraryClock? clock,
}) async {
  return SqliteLibraryStore(
    database: await openDefaultLibraryDatabase(),
    idGenerator: idGenerator,
    clock: clock,
  );
}
