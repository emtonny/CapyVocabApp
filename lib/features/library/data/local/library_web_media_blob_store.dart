import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'library_media_blob_store.dart';

final libraryWebMediaBlobStore = LibraryMediaBlobStore(
  factory: databaseFactoryFfiWeb,
  path: 'capy_vocab_media.db',
);
