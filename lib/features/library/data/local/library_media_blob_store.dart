import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/domain_validation.dart';

/// Persistent browser-media store backed by the same sqflite Web adapter used
/// by the Library database. It stays separate from the relational database so
/// writing a JPEG can be compensated before the Photo Note transaction commits.
final class LibraryMediaBlobStore {
  LibraryMediaBlobStore({
    required DatabaseFactory factory,
    required this.path,
  }) : _factory = factory;

  final DatabaseFactory _factory;
  final String path;
  Future<Database>? _databaseFuture;

  Future<Database> _open() {
    return _databaseFuture ??= _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => database.execute('''
          CREATE TABLE media_blobs (
            relative_path TEXT PRIMARY KEY,
            bytes BLOB NOT NULL,
            byte_size INTEGER NOT NULL CHECK (byte_size > 0),
            updated_at TEXT NOT NULL
          )
        '''),
      ),
    );
  }

  Future<void> write(String relativePath, Uint8List bytes) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }
    final database = await _open();
    await database.insert(
      'media_blobs',
      {
        'relative_path': safePath,
        'bytes': Uint8List.fromList(bytes),
        'byte_size': bytes.lengthInBytes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Uint8List> read(String relativePath) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    final rows = await (await _open()).query(
      'media_blobs',
      columns: const ['bytes'],
      where: 'relative_path = ?',
      whereArgs: [safePath],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Library media is missing: $safePath');
    final value = rows.single['bytes'];
    if (value is Uint8List) return Uint8List.fromList(value);
    if (value is List<int>) return Uint8List.fromList(value);
    throw StateError('Library media has an unsupported binary encoding');
  }

  Future<int> size(String relativePath) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    final rows = await (await _open()).query(
      'media_blobs',
      columns: const ['byte_size'],
      where: 'relative_path = ?',
      whereArgs: [safePath],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Library media is missing: $safePath');
    return rows.single['byte_size']! as int;
  }

  Future<bool> exists(String relativePath) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    final rows = await (await _open()).query(
      'media_blobs',
      columns: const ['relative_path'],
      where: 'relative_path = ?',
      whereArgs: [safePath],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> listPaths() async {
    final rows = await (await _open()).query(
      'media_blobs',
      columns: const ['relative_path'],
      orderBy: 'relative_path',
    );
    return Set.unmodifiable(
      rows.map((row) => row['relative_path']! as String),
    );
  }

  Future<void> delete(String relativePath) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    await (await _open()).delete(
      'media_blobs',
      where: 'relative_path = ?',
      whereArgs: [safePath],
    );
  }

  Future<void> close() async {
    final database = await _databaseFuture;
    _databaseFuture = null;
    await database?.close();
  }
}
