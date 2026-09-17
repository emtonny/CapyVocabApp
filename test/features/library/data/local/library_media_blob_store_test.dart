import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/data/local/library_media_blob_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('persists browser media bytes across store reopen', () async {
    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'capy_web_media_${DateTime.now().microsecondsSinceEpoch}.db';
    addTearDown(() => databaseFactoryFfi.deleteDatabase(path));

    const relativePath = 'capy_scans/photo.jpg';
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    var store = LibraryMediaBlobStore(
      factory: databaseFactoryFfi,
      path: path,
    );
    await store.write(relativePath, bytes);

    expect(await store.exists(relativePath), isTrue);
    expect(await store.size(relativePath), bytes.length);
    expect(await store.listPaths(), {relativePath});
    await store.close();

    store = LibraryMediaBlobStore(
      factory: databaseFactoryFfi,
      path: path,
    );
    expect(await store.read(relativePath), bytes);

    await store.delete(relativePath);
    expect(await store.exists(relativePath), isFalse);
    await store.close();
  });

  test('rejects paths outside the managed relative namespace', () async {
    final store = LibraryMediaBlobStore(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    expect(
      () => store.write('../escape.jpg', Uint8List.fromList([1])),
      throwsArgumentError,
    );
  });
}
