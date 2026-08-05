import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/services/gemini_vision_service.dart';

class ScanResultRecord {
  const ScanResultRecord({
    required this.id,
    required this.localPath,
    required this.vocabJson,
    required this.result,
    required this.createdAt,
  });

  final int id;
  final String localPath;
  final String vocabJson;
  final GeminiVisionResult result;
  final DateTime createdAt;
}

abstract interface class ScanResultStore {
  Future<ScanResultRecord> save({
    required String localPath,
    required GeminiVisionResult result,
  });
}

class ScanResultLocalDataSource implements ScanResultStore {
  static const _databaseName = 'capy_vocab.db';
  static const _tableName = 'scan_results';

  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    return openDatabase(
      '$databaseDirectory/$_databaseName',
      version: 1,
      onCreate: (database, version) => _createTable(database),
      onOpen: _createTable,
    );
  }

  Future<void> _createTable(Database database) {
    return database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_path TEXT NOT NULL,
        vocab_json TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  @override
  Future<ScanResultRecord> save({
    required String localPath,
    required GeminiVisionResult result,
  }) async {
    final database = await _database;
    final vocabJson = jsonEncode(result.toJson());
    final createdAt = DateTime.now().toUtc();
    final id = await database.insert(
      _tableName,
      {
        'local_path': localPath,
        'vocab_json': vocabJson,
        'created_at': createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return ScanResultRecord(
      id: id,
      localPath: localPath,
      vocabJson: vocabJson,
      result: result,
      createdAt: createdAt,
    );
  }
}

class MemoryScanResultStore implements ScanResultStore {
  int _nextId = 1;

  @override
  Future<ScanResultRecord> save({
    required String localPath,
    required GeminiVisionResult result,
  }) async {
    final createdAt = DateTime.now().toUtc();
    return ScanResultRecord(
      id: _nextId++,
      localPath: localPath,
      vocabJson: jsonEncode(result.toJson()),
      result: result,
      createdAt: createdAt,
    );
  }
}
