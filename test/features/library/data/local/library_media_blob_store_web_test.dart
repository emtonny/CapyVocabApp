@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:capy_vocab/features/library/data/local/library_media_blob_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  test('persists media bytes across an IndexedDB reopen', () async {
    final databaseName =
        'capy_web_media_${DateTime.now().microsecondsSinceEpoch}.sqlite';
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sqlite3WasmUri: Uri.parse('assets/web/sqlite3.wasm'),
        indexedDbName: '${databaseName}_holder',
      ),
      noWebWorker: true,
    );
    addTearDown(() => factory.deleteDatabase(databaseName));

    const relativePath = 'capy_scans/photo.jpg';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    var store = LibraryMediaBlobStore(
      factory: factory,
      path: databaseName,
    );
    await store.write(relativePath, bytes);
    await store.close();

    store = LibraryMediaBlobStore(
      factory: factory,
      path: databaseName,
    );
    expect(await store.read(relativePath), bytes);
    expect(await store.size(relativePath), bytes.lengthInBytes);
    await store.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
