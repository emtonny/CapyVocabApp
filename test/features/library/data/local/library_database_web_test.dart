@TestOn('browser')
library;

import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/library_database_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  test('persists the v2 schema and rows across IndexedDB reopen', () async {
    final databaseName =
        'm2a_web_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final indexedDbName = '${databaseName}_holder';
    final options = SqfliteFfiWebOptions(
      sqlite3WasmUri: Uri.parse('assets/web/sqlite3.wasm'),
      indexedDbName: indexedDbName,
    );
    var libraryDatabase = LibraryDatabase(
      factory: createDatabaseFactoryFfiWeb(
        options: options,
        noWebWorker: true,
      ),
      path: databaseName,
    );
    var database = await libraryDatabase.open();

    await database.insert('local_accounts', {
      'user_id': '70000000-0000-0000-0000-000000000001',
      'account_state': 'active',
      'cloud_backup_enabled': 0,
      'local_personalization_enabled': 0,
      'federated_contribution_enabled': 0,
      'created_at': '2026-09-02T03:00:00.000Z',
      'updated_at': '2026-09-02T03:00:00.000Z',
    });
    await libraryDatabase.close();

    libraryDatabase = LibraryDatabase(
      factory: createDatabaseFactoryFfiWeb(
        options: options,
        noWebWorker: true,
      ),
      path: databaseName,
    );
    database = await libraryDatabase.open();

    expect(await database.getVersion(), LibraryDatabaseSchema.version);
    expect(
      await database.query(
        'local_accounts',
        columns: ['user_id'],
      ),
      [
        {'user_id': '70000000-0000-0000-0000-000000000001'},
      ],
    );

    await libraryDatabase.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
