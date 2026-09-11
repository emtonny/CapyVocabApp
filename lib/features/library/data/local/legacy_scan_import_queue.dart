import 'package:sqflite/sqflite.dart';

import '../../domain/entities/domain_validation.dart';

enum LegacyScanMigrationState { pending, imported, quarantined }

final class LegacyScanImportCandidate {
  LegacyScanImportCandidate({
    required this.legacyScanResultId,
    required this.localPath,
    required this.vocabJson,
    required this.createdAt,
    required this.queuedAt,
  });

  final int legacyScanResultId;
  final String localPath;
  final String vocabJson;
  final DateTime createdAt;
  final DateTime queuedAt;
}

/// Explicit migration queue for v1 scan rows.
///
/// Listing a candidate never assigns ownership. The application may call
/// [markImported] only after an external, approved account policy has selected
/// an owner and persisted the normalized MediaAsset/ScanRun transaction.
final class LegacyScanImportQueue {
  LegacyScanImportQueue(this._database);

  final Database _database;

  Future<List<LegacyScanImportCandidate>> getPending({int limit = 100}) async {
    if (limit <= 0 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 1000');
    }
    final rows = await _database.rawQuery('''
      SELECT q.legacy_scan_result_id, q.queued_at,
        s.local_path, s.vocab_json, s.created_at
      FROM legacy_scan_import_queue q
      JOIN scan_results s ON s.id = q.legacy_scan_result_id
      WHERE q.migration_state = 'pending'
      ORDER BY q.legacy_scan_result_id
      LIMIT ?
    ''', [limit]);
    return rows
        .map(
          (row) => LegacyScanImportCandidate(
            legacyScanResultId: row['legacy_scan_result_id']! as int,
            localPath: row['local_path']! as String,
            vocabJson: row['vocab_json']! as String,
            createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
            queuedAt: DateTime.parse(row['queued_at']! as String).toUtc(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> markImported({
    required int legacyScanResultId,
    required String userId,
    required String mediaAssetId,
    required String scanRunId,
    required DateTime processedAt,
  }) async {
    if (legacyScanResultId <= 0) {
      throw ArgumentError.value(
        legacyScanResultId,
        'legacyScanResultId',
        'must be positive',
      );
    }
    userId = requireUuid(userId, 'userId');
    mediaAssetId = requireUuid(mediaAssetId, 'mediaAssetId');
    scanRunId = requireUuid(scanRunId, 'scanRunId');
    processedAt = requireUtc(processedAt, 'processedAt');

    await _database.transaction((transaction) async {
      final ownerRows = await transaction.rawQuery('''
        SELECT s.id FROM scan_runs s
        JOIN media_assets m ON m.id = s.media_asset_id
          AND m.user_id = s.user_id
        WHERE s.id = ? AND s.user_id = ? AND s.media_asset_id = ?
      ''', [scanRunId, userId, mediaAssetId]);
      if (ownerRows.length != 1) {
        throw StateError(
          'Imported MediaAsset and ScanRun must belong to the selected owner',
        );
      }
      final count = await transaction.update(
        'legacy_scan_import_queue',
        {
          'migration_state': 'imported',
          'imported_media_asset_id': mediaAssetId,
          'imported_scan_run_id': scanRunId,
          'error_code': null,
          'processed_at': processedAt.toIso8601String(),
        },
        where: 'legacy_scan_result_id = ? AND migration_state = ?',
        whereArgs: [legacyScanResultId, 'pending'],
      );
      if (count != 1) {
        throw StateError('Legacy scan is missing or no longer pending');
      }
    });
  }

  Future<void> markQuarantined({
    required int legacyScanResultId,
    required String errorCode,
    required DateTime processedAt,
  }) async {
    if (legacyScanResultId <= 0) {
      throw ArgumentError.value(
        legacyScanResultId,
        'legacyScanResultId',
        'must be positive',
      );
    }
    final normalizedError = errorCode.trim();
    if (normalizedError.isEmpty) {
      throw ArgumentError.value(errorCode, 'errorCode', 'must not be empty');
    }
    processedAt = requireUtc(processedAt, 'processedAt');
    final count = await _database.update(
      'legacy_scan_import_queue',
      {
        'migration_state': 'quarantined',
        'error_code': normalizedError,
        'processed_at': processedAt.toIso8601String(),
      },
      where: 'legacy_scan_result_id = ? AND migration_state = ?',
      whereArgs: [legacyScanResultId, 'pending'],
    );
    if (count != 1) {
      throw StateError('Legacy scan is missing or no longer pending');
    }
  }
}
