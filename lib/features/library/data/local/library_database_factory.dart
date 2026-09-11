import 'package:sqflite/sqflite.dart';

import 'library_database.dart';
import 'library_database_factory_native.dart'
    if (dart.library.js_interop) 'library_database_factory_web.dart'
    as platform;

Future<LibraryDatabase> createDefaultLibraryDatabase() async {
  return LibraryDatabase(
    factory: platform.libraryDatabaseFactory,
    path: await platform.libraryDatabasePath(),
  );
}

final Future<LibraryDatabase> _defaultLibraryDatabase =
    createDefaultLibraryDatabase();

Future<Database> openDefaultLibraryDatabase() async {
  return (await _defaultLibraryDatabase).open();
}
