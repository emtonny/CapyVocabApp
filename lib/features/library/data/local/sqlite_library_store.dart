import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/domain_validation.dart';
import '../../domain/library_domain.dart';
import 'library_sqlite_codec.dart';

typedef LibraryIdGenerator = String Function();
typedef LibraryClock = DateTime Function();
typedef LibraryCloudBackfillCandidate = ({
  String photoNoteId,
  bool requiresMediaUpload,
  List<String> requiredRelativePaths,
});

/// SQLite implementation of the local-first Library contracts.
///
/// The database and identifier generator are injected so tests, native and Web
/// adapters share exactly the same persistence behavior. This class owns no
/// media files and deliberately performs no legacy-owner inference.
final class SqliteLibraryStore
    implements
        LibraryRepository,
        AlbumRepository,
        LearningRepository,
        SyncRepository,
        LibrarySyncSource,
        LibraryCloudPullStore,
        PhotoNoteDeletionRepository,
        TrainingRepository,
        ConsentRepository {
  SqliteLibraryStore({
    required Database database,
    required LibraryIdGenerator idGenerator,
    LibraryClock? clock,
  })  : _database = database,
        _idGenerator = idGenerator,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final Database _database;
  final LibraryIdGenerator _idGenerator;
  final LibraryClock _clock;
  final StreamController<Set<String>> _changes =
      StreamController<Set<String>>.broadcast(sync: true);

  bool _disposed = false;

  /// Returns all local media paths across owners for a device-wide integrity
  /// audit. The audit must include every account so another owner's valid file
  /// is never classified as orphaned.
  Future<Set<String>> listReferencedMediaPaths() async {
    final rows = await _database.query(
      'media_assets',
      columns: const [
        'original_relative_path',
        'display_relative_path',
        'model_input_relative_path',
      ],
    );
    final paths = <String>{};
    for (final row in rows) {
      for (final column in row.values) {
        final path = column as String?;
        if (path != null && path.trim().isNotEmpty) paths.add(path.trim());
      }
    }
    return paths;
  }

  /// Fail-closes on-device training when any persisted rendition for a media
  /// asset is missing. User-facing Photo Notes and normalized scan JSON remain
  /// untouched so offline study still works without the image.
  Future<void> quarantineTrainingDataForMissingMediaPaths(
    Iterable<String> missingRelativePaths, {
    required DateTime detectedAt,
  }) async {
    detectedAt = requireUtc(detectedAt, 'detectedAt');
    final missing = missingRelativePaths
        .map((path) => requireRelativePath(path, 'missingRelativePaths'))
        .map((path) => path.replaceAll('\\', '/'))
        .toSet();
    if (missing.isEmpty) return;

    final affectedOwners = <String>{};
    await _database.transaction((transaction) async {
      final mediaRows = await transaction.query(
        'media_assets',
        columns: const [
          'id',
          'user_id',
          'original_relative_path',
          'display_relative_path',
          'model_input_relative_path',
        ],
      );
      final affectedMedia = mediaRows.where((row) {
        return const [
          'original_relative_path',
          'display_relative_path',
          'model_input_relative_path',
        ].any((column) {
          final value = row[column] as String?;
          return value != null && missing.contains(value.replaceAll('\\', '/'));
        });
      }).toList(growable: false);

      for (final media in affectedMedia) {
        final mediaId = media['id']! as String;
        final userId = media['user_id']! as String;
        affectedOwners.add(userId);
        await transaction.rawUpdate('''
          UPDATE model_versions
          SET activation_status = 'invalidated', invalidated_at = ?
          WHERE user_id = ? AND activation_status != 'invalidated' AND id IN (
            SELECT DISTINCT m.id FROM model_versions m
            JOIN training_runs r
              ON r.model_version_id = m.id AND r.user_id = m.user_id
            JOIN training_run_examples tre ON tre.training_run_id = r.id
            JOIN training_examples e ON e.id = tre.training_example_id
            WHERE m.user_id = ? AND e.user_id = ? AND (
              e.media_asset_id = ? OR
              e.source_detection_id IN (
                SELECT d.id FROM vocab_detections d
                JOIN scan_runs s ON s.id = d.scan_run_id
                WHERE s.user_id = ? AND s.media_asset_id = ?
              ) OR
              e.source_annotation_id IN (
                SELECT a.id FROM vocab_annotations a
                JOIN vocab_detections d ON d.id = a.detection_id
                JOIN scan_runs s ON s.id = d.scan_run_id
                WHERE s.user_id = ? AND s.media_asset_id = ?
              )
            )
          )
        ''', [
          detectedAt.toIso8601String(),
          userId,
          userId,
          userId,
          mediaId,
          userId,
          mediaId,
          userId,
          mediaId,
        ]);
        await transaction.rawUpdate('''
          UPDATE training_examples
          SET eligibility_status = 'quarantined', split = 'excluded'
          WHERE user_id = ? AND (
            media_asset_id = ? OR
            source_detection_id IN (
              SELECT d.id FROM vocab_detections d
              JOIN scan_runs s ON s.id = d.scan_run_id
              WHERE s.user_id = ? AND s.media_asset_id = ?
            ) OR
            source_annotation_id IN (
              SELECT a.id FROM vocab_annotations a
              JOIN vocab_detections d ON d.id = a.detection_id
              JOIN scan_runs s ON s.id = d.scan_run_id
              WHERE s.user_id = ? AND s.media_asset_id = ?
            )
          )
        ''', [userId, mediaId, userId, mediaId, userId, mediaId]);
      }
    });
    _notify(affectedOwners.map((owner) => 'training:$owner').toSet());
  }

  /// Account bootstrap is intentionally concrete rather than part of the
  /// consent contract; the authentication/application layer owns account
  /// lifecycle policy (D10).
  Future<void> saveLocalAccount(LocalAccount account) async {
    await _database.rawInsert(
      _upsertSql('local_accounts',
          LibrarySqliteCodec.localAccountToMap(account), const ['user_id']),
      LibrarySqliteCodec.localAccountToMap(account).values.toList(),
    );
    _notify({'account:${account.userId}'});
  }

  /// Creates the fail-closed local account only when it does not exist.
  ///
  /// Consent UI uses this bootstrap before its first explicit change. Unlike
  /// [saveLocalAccount], this method cannot overwrite consent that another
  /// local flow persisted concurrently.
  Future<void> ensureLocalAccount(LocalAccount account) async {
    await _database.insert(
      'local_accounts',
      LibrarySqliteCodec.localAccountToMap(account),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _notify({'account:${account.userId}'});
  }

  @override
  Stream<List<PhotoNote>> watchPhotoNotes(PhotoNoteQuery query) =>
      _watch('photo:${query.userId}', () => _loadPhotoNotes(query));

  @override
  Stream<LibraryStorageSummary> watchStorageSummary({required String userId}) {
    userId = requireUuid(userId, 'userId');
    return _watch('photo:$userId', () async {
      final countRows = await _database.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN p.deleted_at IS NULL THEN 1 ELSE 0 END), 0)
            AS active_count,
          COALESCE(SUM(CASE
            WHEN p.deleted_at IS NOT NULL AND NOT EXISTS (
              SELECT 1 FROM sync_tombstones t
              WHERE t.user_id = p.user_id
                AND t.entity_type = 'photo_note'
                AND t.entity_id = p.id
            ) THEN 1 ELSE 0 END), 0) AS trash_count
        FROM photo_notes p
        WHERE p.user_id = ?
      ''', [userId]);
      final byteRows = await _database.rawQuery('''
        SELECT COALESCE(SUM(
          m.byte_size_display + CASE
            WHEN m.original_relative_path IS NOT NULL
              AND m.original_relative_path != m.display_relative_path
            THEN COALESCE(m.byte_size_original, 0)
            ELSE 0
          END
        ), 0) AS local_media_bytes
        FROM media_assets m
        WHERE m.user_id = ? AND EXISTS (
          SELECT 1 FROM photo_notes p
          WHERE p.user_id = m.user_id AND p.media_asset_id = m.id
            AND NOT EXISTS (
              SELECT 1 FROM sync_tombstones t
              WHERE t.user_id = p.user_id
                AND t.entity_type = 'photo_note'
                AND t.entity_id = p.id
            )
        )
      ''', [userId]);
      return LibraryStorageSummary(
        activeCount: countRows.single['active_count']! as int,
        trashCount: countRows.single['trash_count']! as int,
        localMediaBytes: byteRows.single['local_media_bytes']! as int,
        localMediaCount: 0,
        cloudOnlyMediaCount: 0,
        missingMediaCount: 0,
      );
    });
  }

  @override
  Future<List<MediaAsset>> getStorageMediaAssets(
      {required String userId}) async {
    userId = requireUuid(userId, 'userId');
    final rows = await _database.rawQuery('''
      SELECT DISTINCT m.*
      FROM media_assets m
      WHERE m.user_id = ? AND EXISTS (
        SELECT 1 FROM photo_notes p
        WHERE p.user_id = m.user_id AND p.media_asset_id = m.id
          AND NOT EXISTS (
            SELECT 1 FROM sync_tombstones t
            WHERE t.user_id = p.user_id
              AND t.entity_type = 'photo_note'
              AND t.entity_id = p.id
          )
      )
      ORDER BY m.created_at, m.id
    ''', [userId]);
    return rows
        .map(LibrarySqliteCodec.mediaAssetFromMap)
        .toList(growable: false);
  }

  Future<List<PhotoNote>> _loadPhotoNotes(PhotoNoteQuery query) async {
    final where = <String>['p.user_id = ?'];
    final arguments = <Object?>[query.userId];
    switch (query.visibility) {
      case PhotoNoteVisibility.active:
        where.add('p.deleted_at IS NULL');
      case PhotoNoteVisibility.trash:
        where.add('''
          p.deleted_at IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM sync_tombstones t
            WHERE t.user_id = p.user_id
              AND t.entity_type = 'photo_note'
              AND t.entity_id = p.id
          )
        ''');
      case PhotoNoteVisibility.all:
        break;
    }
    var join = '';
    if (query.albumId != null) {
      join = '''
        JOIN album_photo_notes apn ON apn.photo_note_id = p.id
          AND apn.album_id = ? AND apn.removed_at IS NULL
        JOIN albums a ON a.id = apn.album_id
          AND a.user_id = p.user_id AND a.deleted_at IS NULL
      ''';
      arguments.insert(0, query.albumId);
    }
    if (query.capturedFromInclusive != null) {
      where.add('COALESCE(m.captured_at, p.created_at) >= ?');
      arguments.add(query.capturedFromInclusive!.toIso8601String());
    }
    if (query.capturedToExclusive != null) {
      where.add('COALESCE(m.captured_at, p.created_at) < ?');
      arguments.add(query.capturedToExclusive!.toIso8601String());
    }
    arguments.add(query.limit);
    final rows = await _database.rawQuery('''
      SELECT p.* FROM photo_notes p
      JOIN media_assets m ON m.id = p.media_asset_id AND m.user_id = p.user_id
      $join
      WHERE ${where.join(' AND ')}
      ORDER BY COALESCE(m.captured_at, p.created_at) DESC, p.id
      LIMIT ?
    ''', arguments);
    return rows
        .map(LibrarySqliteCodec.photoNoteFromMap)
        .toList(growable: false);
  }

  @override
  Future<PhotoNoteSnapshot?> getPhotoNoteSnapshot({
    required String userId,
    required String photoNoteId,
  }) async {
    userId = requireUuid(userId, 'userId');
    photoNoteId = requireUuid(photoNoteId, 'photoNoteId');
    return _loadPhotoNoteSnapshot(_database, userId, photoNoteId);
  }

  Future<PhotoNoteSnapshot?> _loadPhotoNoteSnapshot(
    DatabaseExecutor executor,
    String userId,
    String photoNoteId,
  ) async {
    final noteRows = await executor.query(
      'photo_notes',
      where: 'id = ? AND user_id = ?',
      whereArgs: [photoNoteId, userId],
      limit: 1,
    );
    if (noteRows.isEmpty) return null;
    final note = LibrarySqliteCodec.photoNoteFromMap(noteRows.single);
    final mediaRows = await executor.query(
      'media_assets',
      where: 'id = ? AND user_id = ?',
      whereArgs: [note.mediaAssetId, userId],
      limit: 1,
    );
    if (mediaRows.isEmpty) {
      throw StateError('Photo Note ${note.id} has no owner-scoped media asset');
    }
    ScanRun? scanRun;
    var detections = const <VocabDetection>[];
    var annotations = const <VocabAnnotation>[];
    if (note.primaryScanRunId != null) {
      final scanRows = await executor.query(
        'scan_runs',
        where: 'id = ? AND user_id = ?',
        whereArgs: [note.primaryScanRunId, userId],
        limit: 1,
      );
      if (scanRows.isEmpty) {
        throw StateError('Photo Note ${note.id} has no owner-scoped scan run');
      }
      scanRun = LibrarySqliteCodec.scanRunFromMap(scanRows.single);
      final detectionRows = await executor.query(
        'vocab_detections',
        where: 'scan_run_id = ?',
        whereArgs: [scanRun.id],
        orderBy: 'display_order, id',
      );
      detections = detectionRows
          .map(LibrarySqliteCodec.vocabDetectionFromMap)
          .toList(growable: false);
      if (detections.isNotEmpty) {
        final ids = detections.map((item) => item.id).toList(growable: false);
        final annotationRows = await executor.query(
          'vocab_annotations',
          where:
              'user_id = ? AND detection_id IN (${_placeholders(ids.length)})',
          whereArgs: [userId, ...ids],
          orderBy: 'detection_id, revision',
        );
        annotations = annotationRows
            .map(LibrarySqliteCodec.vocabAnnotationFromMap)
            .toList(growable: false);
      }
    }
    return PhotoNoteSnapshot(
      photoNote: note,
      mediaAsset: LibrarySqliteCodec.mediaAssetFromMap(mediaRows.single),
      primaryScanRun: scanRun,
      detections: detections,
      annotations: annotations,
    );
  }

  /// Returns active local-only notes that have never entered the cloud outbox.
  /// Media existence is checked by the application layer before enqueueing.
  Future<List<LibraryCloudBackfillCandidate>> getCloudBackfillCandidates({
    required String userId,
  }) async {
    userId = requireUuid(userId, 'userId');
    final rows = await _database.rawQuery('''
      SELECT p.id AS photo_note_id,
        m.original_relative_path,
        m.display_relative_path,
        m.model_input_relative_path,
        m.remote_display_path
      FROM photo_notes p
      JOIN media_assets m
        ON m.id = p.media_asset_id AND m.user_id = p.user_id
      WHERE p.user_id = ?
        AND p.deleted_at IS NULL
        AND p.sync_status != 'synced'
        AND NOT EXISTS (
          SELECT 1 FROM sync_tombstones t
          WHERE t.user_id = p.user_id
            AND t.entity_type = 'photo_note'
            AND t.entity_id = p.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM sync_operations o
          WHERE o.user_id = p.user_id
            AND o.entity_type = 'photo_note'
            AND o.entity_id = p.id
        )
      ORDER BY p.created_at, p.id
    ''', [userId]);
    return rows.map((row) {
      final paths = <String>{
        if (row['original_relative_path'] case final String path) path,
        row['display_relative_path']! as String,
        if (row['model_input_relative_path'] case final String path) path,
      }.toList(growable: false);
      return (
        photoNoteId: row['photo_note_id']! as String,
        requiresMediaUpload: row['remote_display_path'] == null,
        requiredRelativePaths: paths,
      );
    }).toList(growable: false);
  }

  /// Atomically queues complete dependency graphs for explicitly selected
  /// pre-consent notes. Revalidation makes repeated taps idempotent.
  Future<int> enqueueCloudBackfill({
    required String userId,
    required Iterable<String> photoNoteIds,
  }) async {
    userId = requireUuid(userId, 'userId');
    final ids = _uuidList(photoNoteIds, 'photoNoteIds');
    if (ids.isEmpty) return 0;

    final queued = await _database.transaction((transaction) async {
      if (!await _cloudBackupEnabled(transaction, userId)) {
        throw StateError('Cloud backup consent is required for backfill');
      }
      var count = 0;
      for (final photoNoteId in ids) {
        final eligible = await transaction.rawQuery('''
          SELECT 1
          FROM photo_notes p
          JOIN media_assets m
            ON m.id = p.media_asset_id AND m.user_id = p.user_id
          WHERE p.id = ? AND p.user_id = ?
            AND p.deleted_at IS NULL
            AND p.sync_status != 'synced'
            AND NOT EXISTS (
              SELECT 1 FROM sync_tombstones t
              WHERE t.user_id = p.user_id
                AND t.entity_type = 'photo_note'
                AND t.entity_id = p.id
            )
            AND NOT EXISTS (
              SELECT 1 FROM sync_operations o
              WHERE o.user_id = p.user_id
                AND o.entity_type = 'photo_note'
                AND o.entity_id = p.id
            )
          LIMIT 1
        ''', [photoNoteId, userId]);
        if (eligible.isEmpty) continue;

        final snapshot =
            await _loadPhotoNoteSnapshot(transaction, userId, photoNoteId);
        if (snapshot == null) continue;
        final requiresMediaUpload =
            snapshot.mediaAsset.remoteDisplayPath == null;
        await _enqueueSnapshotSyncOperations(
          transaction,
          snapshot,
          uploadMedia: requiresMediaUpload,
        );
        if (requiresMediaUpload) {
          await transaction.update(
            'media_assets',
            {'sync_status': 'pending'},
            where: 'id = ? AND user_id = ?',
            whereArgs: [snapshot.mediaAsset.id, userId],
          );
        }
        await transaction.update(
          'photo_notes',
          {'sync_status': 'pending'},
          where: 'id = ? AND user_id = ?',
          whereArgs: [photoNoteId, userId],
        );
        count++;
      }
      return count;
    });
    if (queued > 0) _notifyCapturedPhotoNote(userId);
    return queued;
  }

  @override
  Future<void> saveCapturedPhotoNote(PhotoNoteSnapshot snapshot) async {
    await _database.transaction((transaction) async {
      await _insertCapturedPhotoNote(transaction, snapshot);
    });
    _notifyCapturedPhotoNote(snapshot.photoNote.userId);
  }

  /// Commits a newly captured scan to both the compatibility table and the
  /// normalized Library aggregate. New scans have a known authenticated owner,
  /// unlike pre-v2 legacy rows, so they can be marked imported immediately.
  Future<int> saveCapturedPhotoNoteWithLegacy({
    required LocalAccount accountIfMissing,
    required PhotoNoteSnapshot snapshot,
    required String legacyLocalPath,
    required String legacyVocabJson,
  }) async {
    if (accountIfMissing.userId != snapshot.photoNote.userId) {
      throw ArgumentError('accountIfMissing must own the snapshot');
    }
    final scan = snapshot.primaryScanRun;
    if (scan == null) {
      throw ArgumentError('a captured legacy-compatible scan requires ScanRun');
    }
    final localPath = legacyLocalPath.trim();
    final vocabJson = legacyVocabJson.trim();
    if (localPath.isEmpty || vocabJson.isEmpty) {
      throw ArgumentError('legacy path and JSON must not be empty');
    }

    final legacyId = await _database.transaction((transaction) async {
      await transaction.insert(
        'local_accounts',
        LibrarySqliteCodec.localAccountToMap(accountIfMissing),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final accountRows = await transaction.query(
        'local_accounts',
        columns: ['account_state'],
        where: 'user_id = ?',
        whereArgs: [snapshot.photoNote.userId],
        limit: 1,
      );
      if (accountRows.single['account_state'] != 'active') {
        throw StateError('Only an active local account may capture new scans');
      }
      final id = await transaction.insert(
        'scan_results',
        {
          'local_path': localPath,
          'vocab_json': vocabJson,
          'created_at': snapshot.photoNote.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await _insertCapturedPhotoNote(transaction, snapshot);
      await transaction.insert(
        'legacy_scan_import_queue',
        {
          'legacy_scan_result_id': id,
          'migration_state': 'imported',
          'imported_media_asset_id': snapshot.mediaAsset.id,
          'imported_scan_run_id': scan.id,
          'queued_at': snapshot.photoNote.createdAt.toIso8601String(),
          'processed_at': snapshot.photoNote.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return id;
    });
    _notifyCapturedPhotoNote(snapshot.photoNote.userId);
    return legacyId;
  }

  Future<void> _insertCapturedPhotoNote(
    DatabaseExecutor executor,
    PhotoNoteSnapshot snapshot,
  ) async {
    await executor.insert(
      'media_assets',
      LibrarySqliteCodec.mediaAssetToMap(snapshot.mediaAsset),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final scan = snapshot.primaryScanRun;
    if (scan != null) {
      await executor.insert(
        'scan_runs',
        LibrarySqliteCodec.scanRunToMap(scan),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      for (final detection in snapshot.detections) {
        await executor.insert(
          'vocab_detections',
          LibrarySqliteCodec.vocabDetectionToMap(detection),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      for (final annotation in snapshot.annotations) {
        await executor.insert(
          'vocab_annotations',
          LibrarySqliteCodec.vocabAnnotationToMap(annotation),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    }
    await executor.insert(
      'photo_notes',
      LibrarySqliteCodec.photoNoteToMap(snapshot.photoNote),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    if (!await _cloudBackupEnabled(executor, snapshot.photoNote.userId)) return;
    await _enqueueSnapshotSyncOperations(executor, snapshot);
  }

  Future<void> _enqueueSnapshotSyncOperations(
    DatabaseExecutor executor,
    PhotoNoteSnapshot snapshot, {
    bool uploadMedia = true,
  }) async {
    final scan = snapshot.primaryScanRun;
    final mediaOperationId = uploadMedia
        ? await _enqueueGenerated(
            executor,
            userId: snapshot.photoNote.userId,
            entityType: SyncEntityType.mediaAsset,
            entityId: snapshot.mediaAsset.id,
            operationType: SyncOperationType.upload,
          )
        : null;
    String? scanOperationId;
    final evidenceOperationIds = <String>[];
    if (scan != null) {
      scanOperationId = await _enqueueGenerated(
        executor,
        userId: snapshot.photoNote.userId,
        entityType: SyncEntityType.scanRun,
        entityId: scan.id,
        operationType: SyncOperationType.create,
        dependencies: [if (mediaOperationId != null) mediaOperationId],
      );
      final detectionOperationIds = <String, String>{};
      for (final detection in snapshot.detections) {
        final operationId = await _enqueueGenerated(
          executor,
          userId: snapshot.photoNote.userId,
          entityType: SyncEntityType.vocabDetection,
          entityId: detection.id,
          operationType: SyncOperationType.create,
          dependencies: [scanOperationId],
        );
        detectionOperationIds[detection.id] = operationId;
        evidenceOperationIds.add(operationId);
      }
      for (final annotation in snapshot.annotations) {
        evidenceOperationIds.add(await _enqueueGenerated(
          executor,
          userId: snapshot.photoNote.userId,
          entityType: SyncEntityType.vocabAnnotation,
          entityId: annotation.id,
          operationType: SyncOperationType.create,
          dependencies: [detectionOperationIds[annotation.detectionId]!],
        ));
      }
    }
    await _enqueueGenerated(
      executor,
      userId: snapshot.photoNote.userId,
      entityType: SyncEntityType.photoNote,
      entityId: snapshot.photoNote.id,
      operationType: SyncOperationType.create,
      dependencies: [
        if (mediaOperationId != null) mediaOperationId,
        if (scanOperationId != null) scanOperationId,
        ...evidenceOperationIds,
      ],
    );
  }

  void _notifyCapturedPhotoNote(String userId) {
    _notify({
      'photo:$userId',
      'sync:$userId',
    });
  }

  @override
  Future<void> movePhotoNotesToTrash({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime deletedAt,
  }) {
    return _setPhotoNotesDeleted(
      userId: userId,
      photoNoteIds: photoNoteIds,
      changedAt: deletedAt,
      restore: false,
    );
  }

  @override
  Future<void> restorePhotoNotes({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime restoredAt,
  }) {
    return _setPhotoNotesDeleted(
      userId: userId,
      photoNoteIds: photoNoteIds,
      changedAt: restoredAt,
      restore: true,
    );
  }

  Future<void> _setPhotoNotesDeleted({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime changedAt,
    required bool restore,
  }) async {
    userId = requireUuid(userId, 'userId');
    changedAt = requireUtc(changedAt, 'changedAt');
    final ids = _uuidList(photoNoteIds, 'photoNoteIds');
    if (ids.isEmpty) return;
    await _database.transaction((transaction) async {
      final cloud = await _cloudBackupEnabled(transaction, userId);
      for (final id in ids) {
        if (restore) {
          final tombstone = await transaction.query(
            'sync_tombstones',
            columns: const ['id'],
            where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
            whereArgs: [userId, 'photo_note', id],
            limit: 1,
          );
          if (tombstone.isNotEmpty) {
            throw StateError(
              'A Photo Note pending permanent deletion cannot be restored',
            );
          }
        }
        final count = await transaction.update(
          'photo_notes',
          {
            'deleted_at': restore ? null : changedAt.toIso8601String(),
            'updated_at': changedAt.toIso8601String(),
            'sync_status': cloud ? 'pending' : 'local_only',
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [id, userId],
        );
        if (count != 1) {
          throw StateError('Unknown Photo Note for this account: $id');
        }
        if (cloud) {
          await _enqueueGenerated(
            transaction,
            userId: userId,
            entityType: SyncEntityType.photoNote,
            entityId: id,
            operationType: restore
                ? SyncOperationType.update
                : SyncOperationType.softDelete,
          );
        }
      }
    });
    _notify({'photo:$userId', 'sync:$userId'});
  }

  @override
  Future<void> requestPermanentDeletion({
    required String userId,
    required Iterable<String> photoNoteIds,
    required DateTime requestedAt,
  }) async {
    userId = requireUuid(userId, 'userId');
    requestedAt = requireUtc(requestedAt, 'requestedAt');
    final ids = _uuidList(photoNoteIds, 'photoNoteIds');
    if (ids.isEmpty) return;
    await _database.transaction((transaction) async {
      final invalidatedModelIds = <String>{};
      for (final id in ids) {
        await _requestPermanentDeletionInTransaction(
          transaction,
          userId: userId,
          photoNoteId: id,
          requestedAt: requestedAt,
          invalidatedModelIds: invalidatedModelIds,
        );
      }
      if (invalidatedModelIds.isNotEmpty) {
        await transaction.update(
          'model_versions',
          {
            'activation_status': 'invalidated',
            'invalidated_at': requestedAt.toIso8601String(),
          },
          where:
              'user_id = ? AND id IN (${_placeholders(invalidatedModelIds.length)})',
          whereArgs: [userId, ...invalidatedModelIds],
        );
      }
    });
    _notify({'photo:$userId', 'sync:$userId', 'training:$userId'});
  }

  @override
  Future<int> requestExpiredPhotoNoteDeletions({
    required String userId,
    required DateTime now,
    required Duration retention,
  }) async {
    userId = requireUuid(userId, 'userId');
    now = requireUtc(now, 'now');
    if (retention <= Duration.zero) {
      throw ArgumentError.value(retention, 'retention', 'must be positive');
    }
    final cutoff = now.subtract(retention).toIso8601String();
    final invalidatedModelIds = <String>{};
    final promoted = await _database.transaction((transaction) async {
      final rows = await transaction.rawQuery('''
        SELECT p.id FROM photo_notes p
        WHERE p.user_id = ? AND p.deleted_at IS NOT NULL
          AND p.deleted_at <= ? AND NOT EXISTS (
            SELECT 1 FROM sync_tombstones t
            WHERE t.user_id = p.user_id
              AND t.entity_type = 'photo_note'
              AND t.entity_id = p.id
          )
        ORDER BY p.deleted_at, p.id
      ''', [userId, cutoff]);
      for (final row in rows) {
        await _requestPermanentDeletionInTransaction(
          transaction,
          userId: userId,
          photoNoteId: row['id']! as String,
          requestedAt: now,
          invalidatedModelIds: invalidatedModelIds,
        );
      }
      if (invalidatedModelIds.isNotEmpty) {
        await transaction.update(
          'model_versions',
          {
            'activation_status': 'invalidated',
            'invalidated_at': now.toIso8601String(),
          },
          where:
              'user_id = ? AND id IN (${_placeholders(invalidatedModelIds.length)})',
          whereArgs: [userId, ...invalidatedModelIds],
        );
      }
      return rows.length;
    });
    if (promoted > 0) {
      _notify({'photo:$userId', 'sync:$userId', 'training:$userId'});
    }
    return promoted;
  }

  Future<void> _requestPermanentDeletionInTransaction(
    DatabaseExecutor transaction, {
    required String userId,
    required String photoNoteId,
    required DateTime requestedAt,
    required Set<String> invalidatedModelIds,
  }) async {
    final previous = await transaction.query(
      'sync_tombstones',
      columns: const ['id'],
      where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [userId, 'photo_note', photoNoteId],
      limit: 1,
    );
    if (previous.isNotEmpty) return;

    final notes = await transaction.rawQuery('''
      SELECT p.id, p.media_asset_id, p.sync_status,
        m.original_relative_path, m.display_relative_path,
        m.model_input_relative_path, m.remote_original_path,
        m.remote_display_path
      FROM photo_notes p
      JOIN media_assets m ON m.id = p.media_asset_id AND m.user_id = p.user_id
      WHERE p.id = ? AND p.user_id = ?
      LIMIT 1
    ''', [photoNoteId, userId]);
    if (notes.isEmpty) {
      throw StateError('Unknown Photo Note for this account: $photoNoteId');
    }
    final note = notes.single;
    final mediaId = note['media_asset_id']! as String;
    final activeOtherMediaReferences = Sqflite.firstIntValue(
      await transaction.rawQuery(
        '''
          SELECT COUNT(*) FROM photo_notes other
          WHERE other.user_id = ? AND other.media_asset_id = ?
            AND other.id != ? AND NOT EXISTS (
              SELECT 1 FROM sync_tombstones t
              WHERE t.user_id = other.user_id
                AND t.entity_type = 'photo_note'
                AND t.entity_id = other.id
            )
        ''',
        [userId, mediaId, photoNoteId],
      ),
    );
    final deleteMedia = activeOtherMediaReferences == 0;
    final localPaths = deleteMedia
        ? _nonEmptyStrings(note, const [
            'original_relative_path',
            'display_relative_path',
            'model_input_relative_path',
          ])
        : const <String>[];
    final remotePaths = deleteMedia
        ? _nonEmptyStrings(note, const [
            'remote_original_path',
            'remote_display_path',
          ])
        : const <String>[];
    final cloudRequired = await _cloudBackupEnabled(transaction, userId) ||
        remotePaths.isNotEmpty ||
        note['sync_status'] != 'local_only';
    final target = PhotoNotePurgeTarget(
      userId: userId,
      photoNoteId: photoNoteId,
      mediaAssetId: mediaId,
      localRelativePaths: localPaths,
      remoteObjectPaths: remotePaths,
      deleteMedia: deleteMedia,
      remotePurgeCompleted: !cloudRequired,
      localContentPresent: true,
    );

    await transaction.update(
      'photo_notes',
      {
        'deleted_at': requestedAt.toIso8601String(),
        'updated_at': requestedAt.toIso8601String(),
        'sync_status': cloudRequired ? 'pending' : 'local_only',
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [photoNoteId, userId],
    );
    await transaction.insert(
      'sync_tombstones',
      LibrarySqliteCodec.syncTombstoneToMap(SyncTombstone(
        id: _nextId(),
        userId: userId,
        entityType: SyncEntityType.photoNote,
        entityId: photoNoteId,
        deletionVersion: 1,
        deletedAt: requestedAt,
        remotePurgeCompleted: !cloudRequired,
      )),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    if (deleteMedia) {
      final models = await _findModelsUsingSources(
        transaction,
        userId: userId,
        sourceIds: [photoNoteId, mediaId],
      );
      invalidatedModelIds.addAll(models.map((model) => model.id));
      await transaction.rawUpdate('''
      UPDATE training_examples
      SET eligibility_status = 'excluded', split = 'excluded'
      WHERE user_id = ? AND (
        media_asset_id = ? OR source_detection_id IN (
          SELECT d.id FROM vocab_detections d
          JOIN scan_runs s ON s.id = d.scan_run_id
          WHERE s.user_id = ? AND s.media_asset_id = ?
        ) OR source_annotation_id IN (
          SELECT a.id FROM vocab_annotations a
          JOIN vocab_detections d ON d.id = a.detection_id
          JOIN scan_runs s ON s.id = d.scan_run_id
          WHERE s.user_id = ? AND s.media_asset_id = ?
        )
      )
      ''', [userId, mediaId, userId, mediaId, userId, mediaId]);
    }
    if (cloudRequired) {
      await _enqueueGenerated(
        transaction,
        userId: userId,
        entityType: SyncEntityType.photoNote,
        entityId: photoNoteId,
        operationType: SyncOperationType.purge,
        payload: target.toSyncPayload(),
      );
    }
  }

  @override
  Future<List<PhotoNotePurgeTarget>> getPhotoNotePurgeTargets({
    required String userId,
    int limit = 100,
  }) async {
    userId = requireUuid(userId, 'userId');
    if (limit <= 0 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 1000');
    }
    final tombstones = await _database.query(
      'sync_tombstones',
      where: 'user_id = ? AND entity_type = ?',
      whereArgs: [userId, 'photo_note'],
      orderBy: 'deleted_at, id',
      limit: limit,
    );
    final targets = <PhotoNotePurgeTarget>[];
    for (final tombstoneRow in tombstones) {
      final photoNoteId = tombstoneRow['entity_id']! as String;
      final remoteCompleted = tombstoneRow['remote_purge_completed'] == 1;
      final localRows = await _database.rawQuery('''
        SELECT p.media_asset_id,
          m.original_relative_path, m.display_relative_path,
          m.model_input_relative_path, m.remote_original_path,
          m.remote_display_path,
          (SELECT COUNT(*) FROM photo_notes other
            WHERE other.user_id = p.user_id
              AND other.media_asset_id = p.media_asset_id
              AND other.id != p.id AND NOT EXISTS (
                SELECT 1 FROM sync_tombstones other_tombstone
                WHERE other_tombstone.user_id = other.user_id
                  AND other_tombstone.entity_type = 'photo_note'
                  AND other_tombstone.entity_id = other.id
              )) AS active_other_media_references
        FROM photo_notes p
        JOIN media_assets m ON m.id = p.media_asset_id AND m.user_id = p.user_id
        WHERE p.id = ? AND p.user_id = ?
        LIMIT 1
      ''', [photoNoteId, userId]);
      if (localRows.isNotEmpty) {
        final row = localRows.single;
        final deleteMedia = row['active_other_media_references'] == 0;
        targets.add(PhotoNotePurgeTarget(
          userId: userId,
          photoNoteId: photoNoteId,
          mediaAssetId: row['media_asset_id']! as String,
          localRelativePaths: deleteMedia
              ? _nonEmptyStrings(row, const [
                  'original_relative_path',
                  'display_relative_path',
                  'model_input_relative_path',
                ])
              : const <String>[],
          remoteObjectPaths: deleteMedia
              ? _nonEmptyStrings(row, const [
                  'remote_original_path',
                  'remote_display_path',
                ])
              : const <String>[],
          deleteMedia: deleteMedia,
          remotePurgeCompleted: remoteCompleted,
          localContentPresent: true,
        ));
        continue;
      }
      final operations = await _database.query(
        'sync_operations',
        where: 'user_id = ? AND entity_type = ? AND entity_id = ? '
            'AND operation_type = ?',
        whereArgs: [userId, 'photo_note', photoNoteId, 'purge'],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (operations.isEmpty) continue;
      final operation =
          LibrarySqliteCodec.syncOperationFromMap(operations.single);
      targets.add(PhotoNotePurgeTarget.fromSyncPayload(
        userId: userId,
        photoNoteId: photoNoteId,
        payload: operation.payloadJson,
        remotePurgeCompleted: remoteCompleted,
        localContentPresent: false,
      ));
    }
    return List.unmodifiable(targets);
  }

  @override
  Future<PhotoNotePurgeTarget?> getPhotoNotePurgeTarget({
    required String userId,
    required String photoNoteId,
  }) async {
    userId = requireUuid(userId, 'userId');
    photoNoteId = requireUuid(photoNoteId, 'photoNoteId');
    final targets = await getPhotoNotePurgeTargets(userId: userId, limit: 1000);
    for (final target in targets) {
      if (target.photoNoteId == photoNoteId) return target;
    }
    return null;
  }

  @override
  Future<bool> finalizePhotoNoteLocalPurge(
    PhotoNotePurgeTarget target,
  ) async {
    var removed = false;
    await _database.transaction((transaction) async {
      final tombstones = await transaction.query(
        'sync_tombstones',
        columns: const ['remote_purge_completed'],
        where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [target.userId, 'photo_note', target.photoNoteId],
        limit: 1,
      );
      if (tombstones.isEmpty) throw StateError('Deletion receipt is missing');
      final notes = await transaction.query(
        'photo_notes',
        columns: const ['id'],
        where: 'id = ? AND user_id = ? AND media_asset_id = ?',
        whereArgs: [target.photoNoteId, target.userId, target.mediaAssetId],
        limit: 1,
      );
      if (notes.isNotEmpty) {
        await _purgePhotoNoteSourceRows(transaction, target);
        removed = true;
      }
      if (tombstones.single['remote_purge_completed'] == 1) {
        await transaction.delete(
          'sync_operations',
          where: 'user_id = ? AND entity_type = ? AND entity_id = ? '
              'AND operation_type = ?',
          whereArgs: [
            target.userId,
            'photo_note',
            target.photoNoteId,
            'purge',
          ],
        );
      }
    });
    if (removed) {
      _notify({
        'photo:${target.userId}',
        'album:${target.userId}',
        'learning:${target.userId}',
        'training:${target.userId}',
        'sync:${target.userId}',
      });
    }
    return removed;
  }

  Future<void> _purgePhotoNoteSourceRows(
    DatabaseExecutor transaction,
    PhotoNotePurgeTarget target,
  ) async {
    final mediaId = target.mediaAssetId;
    if (!target.deleteMedia) {
      await transaction.delete(
        'learning_events',
        where: 'user_id = ? AND photo_note_id = ?',
        whereArgs: [target.userId, target.photoNoteId],
      );
      await transaction.delete(
        'photo_notes',
        where: 'id = ? AND user_id = ?',
        whereArgs: [target.photoNoteId, target.userId],
      );
      await transaction.delete(
        'sync_operations',
        where: 'user_id = ? AND entity_type = ? AND entity_id = ? '
            'AND operation_type != ?',
        whereArgs: [
          target.userId,
          'photo_note',
          target.photoNoteId,
          'purge',
        ],
      );
      return;
    }
    final scanRows = await transaction.query(
      'scan_runs',
      columns: const ['id'],
      where: 'user_id = ? AND media_asset_id = ?',
      whereArgs: [target.userId, mediaId],
    );
    final scanIds =
        scanRows.map((row) => row['id']! as String).toList(growable: false);
    final detectionRows = await transaction.rawQuery('''
      SELECT d.id, d.word_normalized FROM vocab_detections d
      JOIN scan_runs s ON s.id = d.scan_run_id
      WHERE s.user_id = ? AND s.media_asset_id = ?
    ''', [target.userId, mediaId]);
    final detectionIds = detectionRows
        .map((row) => row['id']! as String)
        .toList(growable: false);
    final words =
        detectionRows.map((row) => row['word_normalized']! as String).toSet();
    final annotationRows = detectionIds.isEmpty
        ? const <Map<String, Object?>>[]
        : await transaction.query(
            'vocab_annotations',
            columns: const ['id'],
            where: 'user_id = ? AND detection_id IN '
                '(${_placeholders(detectionIds.length)})',
            whereArgs: [target.userId, ...detectionIds],
          );
    final annotationIds = annotationRows
        .map((row) => row['id']! as String)
        .toList(growable: false);
    final exampleRows = await transaction.rawQuery('''
      SELECT id FROM training_examples
      WHERE user_id = ? AND (
        media_asset_id = ?
        ${detectionIds.isEmpty ? '' : 'OR source_detection_id IN (${_placeholders(detectionIds.length)})'}
        ${annotationIds.isEmpty ? '' : 'OR source_annotation_id IN (${_placeholders(annotationIds.length)})'}
      )
    ''', [target.userId, mediaId, ...detectionIds, ...annotationIds]);
    final exampleIds =
        exampleRows.map((row) => row['id']! as String).toList(growable: false);
    if (exampleIds.isNotEmpty) {
      final placeholders = _placeholders(exampleIds.length);
      await transaction.delete(
        'dataset_manifest_examples',
        where: 'training_example_id IN ($placeholders)',
        whereArgs: exampleIds,
      );
      await transaction.delete(
        'training_run_examples',
        where: 'training_example_id IN ($placeholders)',
        whereArgs: exampleIds,
      );
      await transaction.delete(
        'training_examples',
        where: 'user_id = ? AND id IN ($placeholders)',
        whereArgs: [target.userId, ...exampleIds],
      );
    }
    await transaction.delete(
      'learning_events',
      where: 'user_id = ? AND (photo_note_id = ?'
          '${detectionIds.isEmpty ? '' : ' OR detection_id IN (${_placeholders(detectionIds.length)})'}'
          '${annotationIds.isEmpty ? '' : ' OR vocab_annotation_id IN (${_placeholders(annotationIds.length)})'})',
      whereArgs: [
        target.userId,
        target.photoNoteId,
        ...detectionIds,
        ...annotationIds,
      ],
    );

    final legacyRows = await transaction.query(
      'legacy_scan_import_queue',
      columns: const ['legacy_scan_result_id'],
      where: 'imported_media_asset_id = ?',
      whereArgs: [mediaId],
    );
    for (final row in legacyRows) {
      final legacyId = row['legacy_scan_result_id']! as int;
      await transaction.delete(
        'legacy_scan_import_queue',
        where: 'legacy_scan_result_id = ?',
        whereArgs: [legacyId],
      );
      await transaction.delete(
        'scan_results',
        where: 'id = ?',
        whereArgs: [legacyId],
      );
    }

    await transaction.delete(
      'photo_notes',
      where: 'id = ? AND user_id = ?',
      whereArgs: [target.photoNoteId, target.userId],
    );
    final sharedCount = Sqflite.firstIntValue(await transaction.rawQuery(
      'SELECT COUNT(*) FROM photo_notes WHERE user_id = ? AND media_asset_id = ?',
      [target.userId, mediaId],
    ));
    if (sharedCount == 0) {
      await transaction.delete(
        'media_assets',
        where: 'id = ? AND user_id = ?',
        whereArgs: [mediaId, target.userId],
      );
    }
    if (words.isNotEmpty) {
      for (final word in words) {
        final remaining = Sqflite.firstIntValue(await transaction.rawQuery('''
          SELECT COUNT(*) FROM vocab_detections d
          JOIN scan_runs s ON s.id = d.scan_run_id
          WHERE s.user_id = ? AND d.word_normalized = ?
        ''', [target.userId, word]));
        if (remaining == 0) {
          await transaction.delete(
            'srs_progress',
            where: 'user_id = ? AND vocab_key = ?',
            whereArgs: [target.userId, word],
          );
        }
      }
    }
    final sourceReferences = <(String, String)>[
      ('photo_note', target.photoNoteId),
      ('media_asset', mediaId),
      ...scanIds.map((id) => ('scan_run', id)),
      ...detectionIds.map((id) => ('vocab_detection', id)),
      ...annotationIds.map((id) => ('vocab_annotation', id)),
    ];
    await transaction.delete(
      'sync_operations',
      where: 'user_id = ? AND NOT ('
          'entity_type = ? AND entity_id = ? AND operation_type = ?) AND ('
          '${sourceReferences.map((_) => '(entity_type = ? AND entity_id = ?)').join(' OR ')})',
      whereArgs: [
        target.userId,
        'photo_note',
        target.photoNoteId,
        'purge',
        for (final reference in sourceReferences) ...[
          reference.$1,
          reference.$2,
        ],
      ],
    );
  }

  static List<String> _nonEmptyStrings(
    Map<String, Object?> row,
    Iterable<String> columns,
  ) =>
      columns
          .map((column) => row[column] as String?)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false);

  @override
  Stream<List<Album>> watchAlbums({
    required String userId,
    bool includeDeleted = false,
  }) {
    userId = requireUuid(userId, 'userId');
    return _watch('album:$userId', () async {
      final rows = await _database.query(
        'albums',
        where: includeDeleted
            ? 'user_id = ?'
            : 'user_id = ? AND deleted_at IS NULL',
        whereArgs: [userId],
        orderBy: 'is_favorite DESC, created_at DESC, id',
      );
      return rows.map(LibrarySqliteCodec.albumFromMap).toList(growable: false);
    });
  }

  @override
  Stream<List<AlbumPhotoNote>> watchMemberships({
    required String userId,
    required String albumId,
  }) {
    userId = requireUuid(userId, 'userId');
    albumId = requireUuid(albumId, 'albumId');
    return _watch('album:$userId', () async {
      final rows = await _database.rawQuery('''
        SELECT apn.* FROM album_photo_notes apn
        JOIN albums a ON a.id = apn.album_id
        JOIN photo_notes p ON p.id = apn.photo_note_id
        WHERE a.id = ? AND a.user_id = ? AND p.user_id = ?
          AND a.deleted_at IS NULL AND apn.removed_at IS NULL
        ORDER BY apn.added_at DESC, apn.photo_note_id
      ''', [albumId, userId, userId]);
      return rows
          .map(LibrarySqliteCodec.albumPhotoNoteFromMap)
          .toList(growable: false);
    });
  }

  @override
  Future<void> saveAlbum(Album album) async {
    await _database.transaction((transaction) async {
      await _requireStableOwnerAndCreation(
        transaction,
        table: 'albums',
        id: album.id,
        userId: album.userId,
        createdAt: album.createdAt,
      );
      await _upsert(
        transaction,
        'albums',
        LibrarySqliteCodec.albumToMap(album),
        const ['id'],
      );
      if (await _cloudBackupEnabled(transaction, album.userId)) {
        await _enqueueGenerated(
          transaction,
          userId: album.userId,
          entityType: SyncEntityType.album,
          entityId: album.id,
          operationType: SyncOperationType.update,
        );
      }
    });
    _notify({'album:${album.userId}', 'sync:${album.userId}'});
  }

  @override
  Future<void> setFavorite({
    required String userId,
    required String albumId,
    required bool isFavorite,
    required DateTime updatedAt,
  }) async {
    userId = requireUuid(userId, 'userId');
    albumId = requireUuid(albumId, 'albumId');
    updatedAt = requireUtc(updatedAt, 'updatedAt');
    await _database.transaction((transaction) async {
      final cloud = await _cloudBackupEnabled(transaction, userId);
      final count = await transaction.update(
        'albums',
        {
          'is_favorite': isFavorite ? 1 : 0,
          'updated_at': updatedAt.toIso8601String(),
          'sync_status': cloud ? 'pending' : 'local_only',
        },
        where: 'id = ? AND user_id = ? AND deleted_at IS NULL',
        whereArgs: [albumId, userId],
      );
      if (count != 1) {
        throw StateError('Unknown active album for this account: $albumId');
      }
      if (cloud) {
        await _enqueueGenerated(
          transaction,
          userId: userId,
          entityType: SyncEntityType.album,
          entityId: albumId,
          operationType: SyncOperationType.update,
        );
      }
    });
    _notify({'album:$userId', 'sync:$userId'});
  }

  @override
  Future<void> addPhotoNotes({
    required String userId,
    required String albumId,
    required Iterable<String> photoNoteIds,
    required DateTime addedAt,
    required String operationId,
  }) async {
    userId = requireUuid(userId, 'userId');
    albumId = requireUuid(albumId, 'albumId');
    operationId = requireUuid(operationId, 'operationId');
    addedAt = requireUtc(addedAt, 'addedAt');
    final ids = _uuidList(photoNoteIds, 'photoNoteIds');
    if (ids.isEmpty) return;
    await _database.transaction((transaction) async {
      await _requireAlbumAndNotes(transaction, userId, albumId, ids);
      for (final noteId in ids) {
        await _upsert(
          transaction,
          'album_photo_notes',
          LibrarySqliteCodec.albumPhotoNoteToMap(AlbumPhotoNote(
            albumId: albumId,
            photoNoteId: noteId,
            addedAt: addedAt,
            operationId: operationId,
          )),
          const ['album_id', 'photo_note_id'],
        );
      }
      if (await _cloudBackupEnabled(transaction, userId)) {
        await _enqueueExplicit(
          transaction,
          SyncOperation(
            operationId: operationId,
            userId: userId,
            entityType: SyncEntityType.albumPhotoNote,
            entityId: albumId,
            operationType: SyncOperationType.relation,
            payloadJson: {'action': 'add', 'photo_note_ids': ids},
            dependencyIds: const [],
            state: SyncOperationState.pending,
            attemptCount: 0,
            createdAt: addedAt,
            updatedAt: addedAt,
          ),
        );
      }
    });
    _notify({'album:$userId', 'photo:$userId', 'sync:$userId'});
  }

  @override
  Future<void> removePhotoNotes({
    required String userId,
    required String albumId,
    required Iterable<String> photoNoteIds,
    required DateTime removedAt,
    required String operationId,
  }) async {
    userId = requireUuid(userId, 'userId');
    albumId = requireUuid(albumId, 'albumId');
    operationId = requireUuid(operationId, 'operationId');
    removedAt = requireUtc(removedAt, 'removedAt');
    final ids = _uuidList(photoNoteIds, 'photoNoteIds');
    if (ids.isEmpty) return;
    await _database.transaction((transaction) async {
      await _requireAlbumAndNotes(transaction, userId, albumId, ids);
      for (final noteId in ids) {
        final rows = await transaction.query(
          'album_photo_notes',
          where: 'album_id = ? AND photo_note_id = ?',
          whereArgs: [albumId, noteId],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Photo Note $noteId is not in album $albumId');
        }
        final current = LibrarySqliteCodec.albumPhotoNoteFromMap(rows.single);
        if (removedAt.isBefore(current.addedAt)) {
          throw ArgumentError(
              'removedAt must not be before addedAt for $noteId');
        }
        await transaction.update(
          'album_photo_notes',
          {
            'removed_at': removedAt.toIso8601String(),
            'operation_id': operationId
          },
          where: 'album_id = ? AND photo_note_id = ?',
          whereArgs: [albumId, noteId],
        );
      }
      if (await _cloudBackupEnabled(transaction, userId)) {
        await _enqueueExplicit(
          transaction,
          SyncOperation(
            operationId: operationId,
            userId: userId,
            entityType: SyncEntityType.albumPhotoNote,
            entityId: albumId,
            operationType: SyncOperationType.relation,
            payloadJson: {'action': 'remove', 'photo_note_ids': ids},
            dependencyIds: const [],
            state: SyncOperationState.pending,
            attemptCount: 0,
            createdAt: removedAt,
            updatedAt: removedAt,
          ),
        );
      }
    });
    _notify({'album:$userId', 'photo:$userId', 'sync:$userId'});
  }

  @override
  Future<void> deleteAlbums({
    required String userId,
    required Iterable<String> albumIds,
    required DateTime deletedAt,
  }) async {
    userId = requireUuid(userId, 'userId');
    deletedAt = requireUtc(deletedAt, 'deletedAt');
    final ids = _uuidList(albumIds, 'albumIds');
    if (ids.isEmpty) return;
    await _database.transaction((transaction) async {
      final cloud = await _cloudBackupEnabled(transaction, userId);
      for (final id in ids) {
        final count = await transaction.update(
          'albums',
          {
            'deleted_at': deletedAt.toIso8601String(),
            'updated_at': deletedAt.toIso8601String(),
            'sync_status': cloud ? 'pending' : 'local_only',
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [id, userId],
        );
        if (count != 1) throw StateError('Unknown album for this account: $id');
        if (cloud) {
          await _enqueueGenerated(
            transaction,
            userId: userId,
            entityType: SyncEntityType.album,
            entityId: id,
            operationType: SyncOperationType.softDelete,
          );
        }
      }
    });
    _notify({'album:$userId', 'photo:$userId', 'sync:$userId'});
  }

  @override
  Future<void> appendEvent(LearningEvent event) async {
    await _database.transaction((transaction) async {
      await transaction.insert(
        'learning_events',
        LibrarySqliteCodec.learningEventToMap(event),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (await _cloudBackupEnabled(transaction, event.userId)) {
        await _enqueueGenerated(
          transaction,
          userId: event.userId,
          entityType: SyncEntityType.learningEvent,
          entityId: event.id,
          operationType: SyncOperationType.create,
        );
      }
    });
    _notify({'learning:${event.userId}', 'sync:${event.userId}'});
  }

  @override
  Future<List<LearningEvent>> getEvents(LearningEventQuery query) async {
    final where = <String>['user_id = ?'];
    final args = <Object?>[query.userId];
    if (query.occurredFromInclusive != null) {
      where.add('occurred_at >= ?');
      args.add(query.occurredFromInclusive!.toIso8601String());
    }
    if (query.occurredToExclusive != null) {
      where.add('occurred_at < ?');
      args.add(query.occurredToExclusive!.toIso8601String());
    }
    final rows = await _database.query(
      'learning_events',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'occurred_at, id',
      limit: query.limit,
    );
    return rows
        .map(LibrarySqliteCodec.learningEventFromMap)
        .toList(growable: false);
  }

  @override
  Stream<List<SrsProgress>> watchSrsProgress({required String userId}) {
    userId = requireUuid(userId, 'userId');
    return _watch('learning:$userId', () async {
      final rows = await _database.query(
        'srs_progress',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'next_review_at, vocab_key',
      );
      return rows
          .map(LibrarySqliteCodec.srsProgressFromMap)
          .toList(growable: false);
    });
  }

  @override
  Future<SrsProgress?> getSrsProgress({
    required String userId,
    required String vocabKey,
  }) async {
    userId = requireUuid(userId, 'userId');
    if (vocabKey.trim().isEmpty) {
      throw ArgumentError.value(vocabKey, 'vocabKey');
    }
    final rows = await _database.query(
      'srs_progress',
      where: 'user_id = ? AND vocab_key = ?',
      whereArgs: [userId, vocabKey.trim()],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LibrarySqliteCodec.srsProgressFromMap(rows.single);
  }

  @override
  Future<void> saveSrsProgress(SrsProgress progress) async {
    await _database.transaction((transaction) async {
      await _upsert(
        transaction,
        'srs_progress',
        LibrarySqliteCodec.srsProgressToMap(progress),
        const ['user_id', 'vocab_key'],
      );
      if (await _cloudBackupEnabled(transaction, progress.userId)) {
        await _enqueueGenerated(
          transaction,
          userId: progress.userId,
          entityType: SyncEntityType.srsProgress,
          entityId: _nextId(),
          operationType: SyncOperationType.update,
          payload: {'vocab_key': progress.vocabKey},
        );
      }
    });
    _notify({'learning:${progress.userId}', 'sync:${progress.userId}'});
  }

  @override
  Future<void> enqueue(SyncOperation operation) async {
    await _enqueueExplicit(_database, operation);
    _notify({'sync:${operation.userId}'});
  }

  @override
  Future<List<SyncOperation>> getReadyOperations({
    required String userId,
    required DateTime now,
    int limit = 100,
  }) async {
    userId = requireUuid(userId, 'userId');
    now = requireUtc(now, 'now');
    if (limit <= 0 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 1000');
    }
    final rows = await _database.query(
      'sync_operations',
      where: "user_id = ? AND state IN ('pending', 'retry') "
          'AND (next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: [userId, now.toIso8601String()],
      orderBy: 'created_at, operation_id',
    );
    final ready = <SyncOperation>[];
    for (final row in rows) {
      final operation = LibrarySqliteCodec.syncOperationFromMap(row);
      if (await _dependenciesDone(operation)) {
        ready.add(operation);
        if (ready.length == limit) break;
      }
    }
    return ready;
  }

  Future<bool> _dependenciesDone(SyncOperation operation) async {
    if (operation.dependencyIds.isEmpty) return true;
    final rows = await _database.query(
      'sync_operations',
      columns: ['operation_id', 'state'],
      where:
          'user_id = ? AND operation_id IN (${_placeholders(operation.dependencyIds.length)})',
      whereArgs: [operation.userId, ...operation.dependencyIds],
    );
    return rows.length == operation.dependencyIds.length &&
        rows.every((row) => row['state'] == 'done');
  }

  @override
  Future<void> updateOperation(SyncOperation operation) async {
    final currentRows = await _database.query(
      'sync_operations',
      where: 'operation_id = ?',
      whereArgs: [operation.operationId],
      limit: 1,
    );
    if (currentRows.isEmpty) {
      throw StateError('Unknown sync operation: ${operation.operationId}');
    }
    final current = LibrarySqliteCodec.syncOperationFromMap(currentRows.single);
    final nextValues = LibrarySqliteCodec.syncOperationToMap(operation);
    if (current.userId != operation.userId ||
        current.entityType != operation.entityType ||
        current.entityId != operation.entityId ||
        current.operationType != operation.operationType ||
        current.createdAt != operation.createdAt ||
        currentRows.single['payload_json'] != nextValues['payload_json'] ||
        currentRows.single['dependency_ids_json'] !=
            nextValues['dependency_ids_json']) {
      throw StateError('Immutable sync operation data was changed');
    }
    if (operation.updatedAt.isBefore(current.updatedAt) ||
        operation.attemptCount < current.attemptCount) {
      throw StateError('Sync operation time and attempt count are monotonic');
    }
    if (!_allowedSyncTransition(current.state, operation.state)) {
      throw StateError(
          'Invalid sync state transition: ${current.state} -> ${operation.state}');
    }
    final count = await _database.update(
      'sync_operations',
      {
        'state': nextValues['state'],
        'attempt_count': nextValues['attempt_count'],
        'next_attempt_at': nextValues['next_attempt_at'],
        'last_error_code': nextValues['last_error_code'],
        'updated_at': nextValues['updated_at'],
      },
      where: 'operation_id = ? AND user_id = ?',
      whereArgs: [operation.operationId, operation.userId],
    );
    if (count != 1) throw StateError('Sync operation update lost');
    _notify({'sync:${operation.userId}'});
  }

  @override
  Future<DateTime?> getNextRetryAt({required String userId}) async {
    userId = requireUuid(userId, 'userId');
    final rows = await _database.rawQuery('''
      SELECT MIN(next_attempt_at) AS next_attempt_at FROM sync_operations
      WHERE user_id = ? AND state = 'retry' AND next_attempt_at IS NOT NULL
    ''', [userId]);
    final value = rows.single['next_attempt_at'] as String?;
    return value == null ? null : DateTime.parse(value).toUtc();
  }

  @override
  Stream<int> watchOperationCount({
    required String userId,
    Set<SyncOperationState> states = const {
      SyncOperationState.pending,
      SyncOperationState.retry,
    },
  }) {
    userId = requireUuid(userId, 'userId');
    final encoded =
        states.map(LibrarySqliteCodec.encodeEnum).toList(growable: false);
    return _watch('sync:$userId', () async {
      if (encoded.isEmpty) return 0;
      final rows = await _database.rawQuery(
        'SELECT COUNT(*) AS count FROM sync_operations '
        'WHERE user_id = ? AND state IN (${_placeholders(encoded.length)})',
        [userId, ...encoded],
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    });
  }

  @override
  Stream<int> watchPendingPurgeCount({required String userId}) {
    userId = requireUuid(userId, 'userId');
    return _watch('sync:$userId', () async {
      final rows = await _database.rawQuery('''
        SELECT COUNT(*) AS count FROM sync_operations
        WHERE user_id = ? AND operation_type = 'purge'
          AND state IN ('pending', 'retry', 'blocked')
      ''', [userId]);
      return Sqflite.firstIntValue(rows) ?? 0;
    });
  }

  @override
  Future<void> saveTombstone(SyncTombstone tombstone) async {
    await _database.transaction((transaction) async {
      final existing = await transaction.query(
        'sync_tombstones',
        columns: ['id', 'deletion_version', 'remote_purge_completed'],
        where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
        whereArgs: [
          tombstone.userId,
          LibrarySqliteCodec.encodeEnum(tombstone.entityType),
          tombstone.entityId,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.single['id'] != tombstone.id) {
        throw StateError('A tombstone cannot change its identity');
      }
      if (existing.isNotEmpty &&
          tombstone.deletionVersion <
              (existing.single['deletion_version']! as int)) {
        throw StateError('A tombstone cannot move to an older version');
      }
      if (existing.isNotEmpty &&
          existing.single['remote_purge_completed'] == 1 &&
          !tombstone.remotePurgeCompleted) {
        throw StateError('Remote purge completion cannot be reverted');
      }
      await _upsert(
        transaction,
        'sync_tombstones',
        LibrarySqliteCodec.syncTombstoneToMap(tombstone),
        const ['user_id', 'entity_type', 'entity_id'],
        immutableColumns: const ['id'],
      );
    });
    _notify({'sync:${tombstone.userId}'});
  }

  @override
  Future<List<SyncTombstone>> getPendingTombstones({
    required String userId,
    int limit = 100,
  }) async {
    userId = requireUuid(userId, 'userId');
    if (limit <= 0 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 1000');
    }
    final rows = await _database.query(
      'sync_tombstones',
      where: 'user_id = ? AND remote_purge_completed = 0',
      whereArgs: [userId],
      orderBy: 'deleted_at, id',
      limit: limit,
    );
    return rows
        .map(LibrarySqliteCodec.syncTombstoneFromMap)
        .toList(growable: false);
  }

  @override
  Future<bool> isCloudBackupEnabled({required String userId}) {
    userId = requireUuid(userId, 'userId');
    return _cloudBackupEnabled(_database, userId);
  }

  @override
  Future<int> recoverInterruptedOperations({
    required String userId,
    required DateTime interruptedBefore,
    required DateTime recoveredAt,
  }) async {
    userId = requireUuid(userId, 'userId');
    interruptedBefore = requireUtc(interruptedBefore, 'interruptedBefore');
    recoveredAt = requireUtc(recoveredAt, 'recoveredAt');
    if (recoveredAt.isBefore(interruptedBefore)) {
      throw ArgumentError('recoveredAt must not be before interruptedBefore');
    }
    final count = await _database.update(
      'sync_operations',
      {
        'state': 'retry',
        'next_attempt_at': recoveredAt.toIso8601String(),
        'last_error_code': 'interrupted',
        'updated_at': recoveredAt.toIso8601String(),
      },
      where: 'user_id = ? AND state = ? AND updated_at <= ?',
      whereArgs: [
        userId,
        'running',
        interruptedBefore.toIso8601String(),
      ],
    );
    if (count > 0) _notify({'sync:$userId'});
    return count;
  }

  @override
  Future<int> releaseAuthBlockedOperations({
    required String userId,
    required DateTime releasedAt,
  }) async {
    userId = requireUuid(userId, 'userId');
    releasedAt = requireUtc(releasedAt, 'releasedAt');
    final count = await _database.update(
      'sync_operations',
      {
        'state': 'retry',
        'next_attempt_at': releasedAt.toIso8601String(),
        'last_error_code': null,
        'updated_at': releasedAt.toIso8601String(),
      },
      where: 'user_id = ? AND state = ? AND last_error_code = ?',
      whereArgs: [userId, 'blocked', 'auth_required'],
    );
    if (count > 0) _notify({'sync:$userId'});
    return count;
  }

  @override
  Future<MediaAsset?> getMediaAssetForSync({
    required String userId,
    required String mediaAssetId,
  }) async {
    userId = requireUuid(userId, 'userId');
    mediaAssetId = requireUuid(mediaAssetId, 'mediaAssetId');
    final rows = await _database.query(
      'media_assets',
      where: 'id = ? AND user_id = ?',
      whereArgs: [mediaAssetId, userId],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LibrarySqliteCodec.mediaAssetFromMap(rows.single);
  }

  @override
  Future<ScanRun?> getScanRunForSync({
    required String userId,
    required String scanRunId,
  }) async {
    userId = requireUuid(userId, 'userId');
    scanRunId = requireUuid(scanRunId, 'scanRunId');
    final rows = await _database.query(
      'scan_runs',
      where: 'id = ? AND user_id = ?',
      whereArgs: [scanRunId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : LibrarySqliteCodec.scanRunFromMap(rows.single);
  }

  @override
  Future<VocabDetection?> getVocabDetectionForSync({
    required String userId,
    required String detectionId,
  }) async {
    userId = requireUuid(userId, 'userId');
    detectionId = requireUuid(detectionId, 'detectionId');
    final rows = await _database.rawQuery('''
      SELECT d.* FROM vocab_detections d
      JOIN scan_runs s ON s.id = d.scan_run_id
      WHERE d.id = ? AND s.user_id = ?
      LIMIT 1
    ''', [detectionId, userId]);
    return rows.isEmpty
        ? null
        : LibrarySqliteCodec.vocabDetectionFromMap(rows.single);
  }

  @override
  Future<VocabAnnotation?> getVocabAnnotationForSync({
    required String userId,
    required String annotationId,
  }) async {
    userId = requireUuid(userId, 'userId');
    annotationId = requireUuid(annotationId, 'annotationId');
    final rows = await _database.query(
      'vocab_annotations',
      where: 'id = ? AND user_id = ?',
      whereArgs: [annotationId, userId],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LibrarySqliteCodec.vocabAnnotationFromMap(rows.single);
  }

  @override
  Future<PhotoNote?> getPhotoNoteForSync({
    required String userId,
    required String photoNoteId,
  }) async {
    userId = requireUuid(userId, 'userId');
    photoNoteId = requireUuid(photoNoteId, 'photoNoteId');
    final rows = await _database.query(
      'photo_notes',
      where: 'id = ? AND user_id = ?',
      whereArgs: [photoNoteId, userId],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LibrarySqliteCodec.photoNoteFromMap(rows.single);
  }

  @override
  Future<void> markMediaAssetSynced({
    required String userId,
    required String mediaAssetId,
    String? remoteOriginalPath,
    required String remoteDisplayPath,
  }) async {
    userId = requireUuid(userId, 'userId');
    mediaAssetId = requireUuid(mediaAssetId, 'mediaAssetId');
    remoteOriginalPath = remoteOriginalPath == null
        ? null
        : requireRelativePath(remoteOriginalPath, 'remoteOriginalPath');
    remoteDisplayPath =
        requireRelativePath(remoteDisplayPath, 'remoteDisplayPath');
    final count = await _database.update(
      'media_assets',
      {
        'remote_original_path': remoteOriginalPath,
        'remote_display_path': remoteDisplayPath,
        'sync_status': 'synced',
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [mediaAssetId, userId],
    );
    if (count != 1) throw StateError('Unknown media asset for this account');
    _notify({'photo:$userId'});
  }

  @override
  Future<void> markPhotoNoteSynced({
    required String userId,
    required String photoNoteId,
  }) async {
    userId = requireUuid(userId, 'userId');
    photoNoteId = requireUuid(photoNoteId, 'photoNoteId');
    final count = await _database.update(
      'photo_notes',
      {'sync_status': 'synced'},
      where: 'id = ? AND user_id = ?',
      whereArgs: [photoNoteId, userId],
    );
    if (count != 1) throw StateError('Unknown Photo Note for this account');
    _notify({'photo:$userId'});
  }

  @override
  Future<int> getLibraryPullCursor({required String userId}) async {
    userId = requireUuid(userId, 'userId');
    final rows = await _database.query(
      'library_pull_cursors',
      columns: const ['last_sequence'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['last_sequence']! as int;
  }

  @override
  Future<void> applyLibraryCloudDelta(LibraryCloudDelta delta) async {
    final changed = await _database.transaction((transaction) async {
      final accountRows = await transaction.query(
        'local_accounts',
        columns: const ['user_id'],
        where: 'user_id = ?',
        whereArgs: [delta.userId],
        limit: 1,
      );
      if (accountRows.isEmpty) {
        throw StateError('Unknown local account: ${delta.userId}');
      }
      final cursorRows = await transaction.query(
        'library_pull_cursors',
        columns: const ['last_sequence'],
        where: 'user_id = ?',
        whereArgs: [delta.userId],
        limit: 1,
      );
      final currentCursor =
          cursorRows.isEmpty ? 0 : cursorRows.single['last_sequence']! as int;
      if (currentCursor != delta.previousCursor) {
        throw StateError(
          'Library pull cursor changed concurrently: '
          '$currentCursor != ${delta.previousCursor}',
        );
      }

      var contentChanged = false;
      for (final deletion in delta.deletions) {
        final localSource = await transaction.query(
          'photo_notes',
          columns: const ['media_asset_id'],
          where: 'id = ? AND user_id = ?',
          whereArgs: [deletion.photoNoteId, delta.userId],
          limit: 1,
        );
        if (localSource.isNotEmpty) {
          final mediaId = localSource.single['media_asset_id']! as String;
          final models = await _findModelsUsingSources(
            transaction,
            userId: delta.userId,
            sourceIds: [deletion.photoNoteId, mediaId],
          );
          if (models.isNotEmpty) {
            await transaction.update(
              'model_versions',
              {
                'activation_status': 'invalidated',
                'invalidated_at': deletion.deletedAt.toIso8601String(),
              },
              where: 'user_id = ? AND id IN '
                  '(${_placeholders(models.length)})',
              whereArgs: [
                delta.userId,
                ...models.map((model) => model.id),
              ],
            );
          }
          await transaction.rawUpdate('''
            UPDATE training_examples
            SET eligibility_status = 'excluded', split = 'excluded'
            WHERE user_id = ? AND (
              media_asset_id = ? OR source_detection_id IN (
                SELECT d.id FROM vocab_detections d
                JOIN scan_runs s ON s.id = d.scan_run_id
                WHERE s.user_id = ? AND s.media_asset_id = ?
              ) OR source_annotation_id IN (
                SELECT a.id FROM vocab_annotations a
                JOIN vocab_detections d ON d.id = a.detection_id
                JOIN scan_runs s ON s.id = d.scan_run_id
                WHERE s.user_id = ? AND s.media_asset_id = ?
              )
            )
          ''', [
            delta.userId,
            mediaId,
            delta.userId,
            mediaId,
            delta.userId,
            mediaId,
          ]);
        }
        await transaction.rawInsert('''
          INSERT INTO sync_tombstones (
            id, user_id, entity_type, entity_id, deletion_version,
            deleted_at, remote_purge_completed
          ) VALUES (?, ?, 'photo_note', ?, ?, ?, 1)
          ON CONFLICT (user_id, entity_type, entity_id) DO UPDATE SET
            deletion_version = MAX(
              sync_tombstones.deletion_version,
              excluded.deletion_version
            ),
            deleted_at = CASE
              WHEN excluded.deletion_version >= sync_tombstones.deletion_version
              THEN excluded.deleted_at ELSE sync_tombstones.deleted_at END,
            remote_purge_completed = 1
        ''', [
          _nextId(),
          delta.userId,
          deletion.photoNoteId,
          deletion.sequence,
          deletion.deletedAt.toIso8601String(),
        ]);
        await transaction.update(
          'photo_notes',
          {
            'deleted_at': deletion.deletedAt.toIso8601String(),
            'updated_at': deletion.deletedAt.toIso8601String(),
            'sync_status': 'synced',
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [deletion.photoNoteId, delta.userId],
        );
        await transaction.delete(
          'sync_operations',
          where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
          whereArgs: [delta.userId, 'photo_note', deletion.photoNoteId],
        );
        contentChanged = true;
      }

      for (final snapshot in delta.snapshots) {
        final note = snapshot.photoNote;
        final tombstone = await transaction.query(
          'sync_tombstones',
          columns: const ['id'],
          where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
          whereArgs: [delta.userId, 'photo_note', note.id],
          limit: 1,
        );
        if (tombstone.isNotEmpty) continue;

        final localNote = await transaction.query(
          'photo_notes',
          columns: const ['sync_status'],
          where: 'id = ? AND user_id = ?',
          whereArgs: [note.id, delta.userId],
          limit: 1,
        );
        if (localNote.isNotEmpty &&
            localNote.single['sync_status'] != 'synced') {
          continue;
        }

        final mediaMap =
            LibrarySqliteCodec.mediaAssetToMap(snapshot.mediaAsset);
        final localMedia = await transaction.query(
          'media_assets',
          where: 'id = ? AND user_id = ?',
          whereArgs: [snapshot.mediaAsset.id, delta.userId],
          limit: 1,
        );
        if (localMedia.isEmpty) {
          await transaction.insert(
            'media_assets',
            mediaMap,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        } else {
          await transaction.update(
            'media_assets',
            {
              'remote_original_path': mediaMap['remote_original_path'],
              'remote_display_path': mediaMap['remote_display_path'],
              'sync_status': 'synced',
              'deleted_at': mediaMap['deleted_at'],
            },
            where: 'id = ? AND user_id = ?',
            whereArgs: [snapshot.mediaAsset.id, delta.userId],
          );
        }

        final scan = snapshot.primaryScanRun;
        if (scan != null) {
          await transaction.insert(
            'scan_runs',
            LibrarySqliteCodec.scanRunToMap(scan),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          for (final detection in snapshot.detections) {
            await transaction.insert(
              'vocab_detections',
              LibrarySqliteCodec.vocabDetectionToMap(detection),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          for (final annotation in snapshot.annotations) {
            final pending = Sqflite.firstIntValue(await transaction.rawQuery(
              '''
                SELECT COUNT(*) FROM sync_operations
                WHERE user_id = ? AND entity_type = 'vocab_annotation'
                  AND entity_id = ? AND state != 'done'
              ''',
              [delta.userId, annotation.id],
            ));
            if (pending == 0) {
              await _upsert(
                transaction,
                'vocab_annotations',
                LibrarySqliteCodec.vocabAnnotationToMap(annotation),
                const ['id'],
                immutableColumns: const ['user_id', 'created_at'],
              );
            }
          }
        }
        await _upsert(
          transaction,
          'photo_notes',
          LibrarySqliteCodec.photoNoteToMap(note),
          const ['id'],
          immutableColumns: const [
            'user_id',
            'media_asset_id',
            'created_at',
          ],
        );
        contentChanged = true;
      }

      await transaction.rawInsert('''
        INSERT INTO library_pull_cursors (user_id, last_sequence, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT (user_id) DO UPDATE SET
          last_sequence = excluded.last_sequence,
          updated_at = excluded.updated_at
      ''', [
        delta.userId,
        delta.nextCursor,
        _clock().toUtc().toIso8601String(),
      ]);
      return contentChanged;
    });
    if (changed) {
      _notify({
        'photo:${delta.userId}',
        'album:${delta.userId}',
        'learning:${delta.userId}',
        'training:${delta.userId}',
        'sync:${delta.userId}',
      });
    }
  }

  @override
  Future<void> markTombstoneRemotePurgeCompleted({
    required String userId,
    required SyncEntityType entityType,
    required String entityId,
  }) async {
    userId = requireUuid(userId, 'userId');
    entityId = requireUuid(entityId, 'entityId');
    final count = await _database.update(
      'sync_tombstones',
      {'remote_purge_completed': 1},
      where: 'user_id = ? AND entity_type = ? AND entity_id = ?',
      whereArgs: [
        userId,
        LibrarySqliteCodec.encodeEnum(entityType),
        entityId,
      ],
    );
    if (count != 1) throw StateError('Unknown tombstone for this account');
    _notify({'sync:$userId'});
  }

  @override
  Future<void> saveExample(TrainingExample example) async {
    await _database.transaction((transaction) async {
      await _requireStableOwnerAndCreation(
        transaction,
        table: 'training_examples',
        id: example.id,
        userId: example.userId,
        createdAt: example.createdAt,
      );
      await _upsert(
        transaction,
        'training_examples',
        LibrarySqliteCodec.trainingExampleToMap(example),
        const ['id'],
        immutableColumns: const ['user_id', 'created_at'],
      );
    });
    _notify({'training:${example.userId}'});
  }

  @override
  Future<List<TrainingExample>> getEligibleExamples({
    required String userId,
    required TrainingTaskType taskType,
    int limit = 5000,
  }) async {
    userId = requireUuid(userId, 'userId');
    if (limit <= 0 || limit > 10000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 10000');
    }
    final rows = await _database.query(
      'training_examples',
      where: 'user_id = ? AND task_type = ? AND eligibility_status = ?',
      whereArgs: [userId, LibrarySqliteCodec.encodeEnum(taskType), 'eligible'],
      orderBy: 'created_at, id',
      limit: limit,
    );
    return rows
        .map(LibrarySqliteCodec.trainingExampleFromMap)
        .toList(growable: false);
  }

  @override
  Future<void> saveDatasetManifest({
    required DatasetManifest manifest,
    required Iterable<String> trainingExampleIds,
  }) async {
    final ids = _uuidList(trainingExampleIds, 'trainingExampleIds');
    await _database.transaction((transaction) async {
      await _requireTrainingExamples(
        transaction,
        userId: manifest.userId,
        taskType: manifest.taskType,
        ids: ids,
        expectedSplitCounts: manifest.splitCounts,
      );
      await transaction.insert(
        'dataset_manifests',
        LibrarySqliteCodec.datasetManifestToMap(manifest),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      for (final id in ids) {
        await transaction.insert('dataset_manifest_examples', {
          'dataset_manifest_id': manifest.id,
          'training_example_id': id,
        });
      }
    });
    _notify({'training:${manifest.userId}'});
  }

  @override
  Future<void> saveModelVersion(ModelVersion modelVersion) async {
    await _database.transaction((transaction) async {
      await _requireStableOwnerAndCreation(
        transaction,
        table: 'model_versions',
        id: modelVersion.id,
        userId: modelVersion.userId,
        createdAt: modelVersion.createdAt,
      );
      final existing = await transaction.query(
        'model_versions',
        columns: ['activation_status'],
        where: 'id = ? AND user_id = ?',
        whereArgs: [modelVersion.id, modelVersion.userId],
        limit: 1,
      );
      if (existing.isNotEmpty &&
          existing.single['activation_status'] == 'invalidated' &&
          modelVersion.activationStatus != ModelActivationStatus.invalidated) {
        throw StateError('An invalidated model cannot be reactivated');
      }
      if (modelVersion.activationStatus == ModelActivationStatus.active) {
        await transaction.update(
          'model_versions',
          {'activation_status': 'superseded'},
          where:
              'user_id = ? AND task_type = ? AND activation_status = ? AND id != ?',
          whereArgs: [
            modelVersion.userId,
            LibrarySqliteCodec.encodeEnum(modelVersion.taskType),
            'active',
            modelVersion.id,
          ],
        );
      }
      await _upsert(
        transaction,
        'model_versions',
        LibrarySqliteCodec.modelVersionToMap(modelVersion),
        const ['id'],
        immutableColumns: const ['user_id', 'created_at'],
      );
    });
    _notify({'training:${modelVersion.userId}'});
  }

  @override
  Future<ModelVersion?> getActiveModel({
    required String userId,
    required TrainingTaskType taskType,
  }) async {
    userId = requireUuid(userId, 'userId');
    final rows = await _database.query(
      'model_versions',
      where: 'user_id = ? AND task_type = ? AND activation_status = ?',
      whereArgs: [userId, LibrarySqliteCodec.encodeEnum(taskType), 'active'],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : LibrarySqliteCodec.modelVersionFromMap(rows.single);
  }

  @override
  Future<void> saveTrainingRun({
    required TrainingRun run,
    required Iterable<TrainingRunExample> examples,
  }) async {
    final links = List<TrainingRunExample>.unmodifiable(examples);
    if (links.any((link) => link.trainingRunId != run.id)) {
      throw ArgumentError('Every TrainingRunExample must refer to run.id');
    }
    final ids = _uuidList(
      links.map((link) => link.trainingExampleId),
      'trainingExampleIds',
    );
    if (run.sampleCount != ids.length) {
      throw ArgumentError('run.sampleCount must match the example link count');
    }
    await _database.transaction((transaction) async {
      await _requireTrainingOwnership(transaction, run, ids);
      await transaction.insert(
        'training_runs',
        LibrarySqliteCodec.trainingRunToMap(run),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      for (final id in ids) {
        await transaction.insert('training_run_examples', {
          'training_run_id': run.id,
          'training_example_id': id,
        });
      }
    });
    _notify({'training:${run.userId}'});
  }

  @override
  Future<List<ModelVersion>> findModelsUsingSources({
    required String userId,
    required Iterable<String> sourceIds,
  }) {
    userId = requireUuid(userId, 'userId');
    return _findModelsUsingSources(
      _database,
      userId: userId,
      sourceIds: _uuidList(sourceIds, 'sourceIds'),
    );
  }

  Future<List<ModelVersion>> _findModelsUsingSources(
    DatabaseExecutor executor, {
    required String userId,
    required List<String> sourceIds,
  }) async {
    if (sourceIds.isEmpty) return const [];
    final placeholders = _placeholders(sourceIds.length);
    final rows = await executor.rawQuery('''
      SELECT DISTINCT m.* FROM model_versions m
      JOIN training_runs r ON r.model_version_id = m.id AND r.user_id = m.user_id
      JOIN training_run_examples tre ON tre.training_run_id = r.id
      JOIN training_examples e ON e.id = tre.training_example_id AND e.user_id = m.user_id
      WHERE m.user_id = ? AND (
        e.media_asset_id IN ($placeholders) OR
        e.source_detection_id IN ($placeholders) OR
        e.source_annotation_id IN ($placeholders)
      )
      ORDER BY m.created_at, m.id
    ''', [userId, ...sourceIds, ...sourceIds, ...sourceIds]);
    return rows
        .map(LibrarySqliteCodec.modelVersionFromMap)
        .toList(growable: false);
  }

  @override
  Future<void> markModelsInvalidated({
    required String userId,
    required Iterable<String> modelVersionIds,
    required DateTime invalidatedAt,
  }) async {
    userId = requireUuid(userId, 'userId');
    requireUtc(invalidatedAt, 'invalidatedAt');
    final ids = _uuidList(modelVersionIds, 'modelVersionIds');
    if (ids.isEmpty) return;
    await _database.update(
      'model_versions',
      {
        'activation_status': 'invalidated',
        'invalidated_at': invalidatedAt.toIso8601String(),
      },
      where: 'user_id = ? AND id IN (${_placeholders(ids.length)})',
      whereArgs: [userId, ...ids],
    );
    _notify({'training:$userId'});
  }

  @override
  Stream<LocalAccount?> watchLocalAccount({required String userId}) {
    userId = requireUuid(userId, 'userId');
    return _watch('account:$userId', () async {
      final rows = await _database.query(
        'local_accounts',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      return rows.isEmpty
          ? null
          : LibrarySqliteCodec.localAccountFromMap(rows.single);
    });
  }

  @override
  Stream<List<ConsentEvent>> watchConsentHistory({required String userId}) {
    userId = requireUuid(userId, 'userId');
    return _watch('consent:$userId', () async {
      final rows = await _database.query(
        'consent_events',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'occurred_at DESC, id',
      );
      return rows
          .map(LibrarySqliteCodec.consentEventFromMap)
          .toList(growable: false);
    });
  }

  @override
  Future<void> recordChange(ConsentEvent event) async {
    await _database.transaction((transaction) async {
      final column = switch (event.consentType) {
        ConsentType.cloudBackup => 'cloud_backup_enabled',
        ConsentType.localPersonalization => 'local_personalization_enabled',
        ConsentType.federatedContribution => 'federated_contribution_enabled',
      };
      final count = await transaction.update(
        'local_accounts',
        {
          column: event.newValue ? 1 : 0,
          'updated_at': event.occurredAt.toIso8601String()
        },
        where: 'user_id = ? AND $column = ?',
        whereArgs: [event.userId, event.oldValue ? 1 : 0],
      );
      if (count != 1) {
        throw StateError(
            'Consent oldValue does not match materialized account state');
      }
      await transaction.insert(
        'consent_events',
        LibrarySqliteCodec.consentEventToMap(event),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
    _notify({'account:${event.userId}', 'consent:${event.userId}'});
  }

  @override
  Future<List<ConsentEvent>> getPendingEnforcement({
    required String userId,
    ConsentType? consentType,
  }) async {
    userId = requireUuid(userId, 'userId');
    final rows = await _database.query(
      'consent_events',
      where: consentType == null
          ? 'user_id = ? AND enforcement_state = ?'
          : 'user_id = ? AND enforcement_state = ? AND consent_type = ?',
      whereArgs: [
        userId,
        'pending',
        if (consentType != null) LibrarySqliteCodec.encodeEnum(consentType),
      ],
      orderBy: 'occurred_at, id',
    );
    return rows
        .map(LibrarySqliteCodec.consentEventFromMap)
        .toList(growable: false);
  }

  @override
  Future<void> updateEnforcementState({
    required String userId,
    required String eventId,
    required ConsentEnforcementState state,
  }) async {
    userId = requireUuid(userId, 'userId');
    eventId = requireUuid(eventId, 'eventId');
    await _database.transaction((transaction) async {
      final rows = await transaction.query(
        'consent_events',
        columns: ['enforcement_state'],
        where: 'id = ? AND user_id = ?',
        whereArgs: [eventId, userId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Unknown consent event for this account: $eventId');
      }
      final current = rows.single['enforcement_state']! as String;
      final next = LibrarySqliteCodec.encodeEnum(state);
      final allowed = current == next ||
          current == 'pending' ||
          (current == 'failed' && next == 'pending');
      if (!allowed || current == 'applied' && next != 'applied') {
        throw StateError(
            'Invalid consent enforcement transition: $current -> $next');
      }
      await transaction.update(
        'consent_events',
        {'enforcement_state': next},
        where: 'id = ? AND user_id = ?',
        whereArgs: [eventId, userId],
      );
    });
    _notify({'consent:$userId'});
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }

  Stream<T> _watch<T>(String topic, Future<T> Function() load) async* {
    if (_disposed) throw StateError('SqliteLibraryStore is disposed');
    yield await load();
    await for (final topics in _changes.stream) {
      if (topics.contains(topic)) yield await load();
    }
  }

  void _notify(Set<String> topics) {
    if (!_disposed) _changes.add(topics);
  }

  Future<bool> _cloudBackupEnabled(
    DatabaseExecutor executor,
    String userId,
  ) async {
    final rows = await executor.query(
      'local_accounts',
      columns: ['cloud_backup_enabled'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Unknown local account: $userId');
    return rows.single['cloud_backup_enabled'] == 1;
  }

  Future<String> _enqueueGenerated(
    DatabaseExecutor executor, {
    required String userId,
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operationType,
    Iterable<String> dependencies = const [],
    Map<String, Object?> payload = const {},
  }) async {
    final id = _nextId();
    final now = requireUtc(_clock(), 'clock()');
    await _enqueueExplicit(
      executor,
      SyncOperation(
        operationId: id,
        userId: userId,
        entityType: entityType,
        entityId: entityId,
        operationType: operationType,
        payloadJson: payload,
        dependencyIds: dependencies,
        state: SyncOperationState.pending,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> _enqueueExplicit(
    DatabaseExecutor executor,
    SyncOperation operation,
  ) {
    return executor.insert(
      'sync_operations',
      LibrarySqliteCodec.syncOperationToMap(operation),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  String _nextId() => requireUuid(_idGenerator(), 'idGenerator()');

  static Future<void> _requireAlbumAndNotes(
    DatabaseExecutor executor,
    String userId,
    String albumId,
    List<String> noteIds,
  ) async {
    final albumCount = Sqflite.firstIntValue(await executor.rawQuery(
      'SELECT COUNT(*) FROM albums WHERE id = ? AND user_id = ? AND deleted_at IS NULL',
      [albumId, userId],
    ));
    if (albumCount != 1) {
      throw StateError('Unknown active album for this account: $albumId');
    }
    final noteCount = Sqflite.firstIntValue(await executor.rawQuery(
      'SELECT COUNT(*) FROM photo_notes WHERE user_id = ? '
      'AND id IN (${_placeholders(noteIds.length)})',
      [userId, ...noteIds],
    ));
    if (noteCount != noteIds.length) {
      throw StateError('One or more Photo Notes do not belong to this account');
    }
  }

  static Future<void> _requireTrainingExamples(
    DatabaseExecutor executor, {
    required String userId,
    required TrainingTaskType taskType,
    required List<String> ids,
    required Map<String, int> expectedSplitCounts,
  }) async {
    final rows = ids.isEmpty
        ? const <Map<String, Object?>>[]
        : await executor.rawQuery(
            'SELECT split, COUNT(*) AS count FROM training_examples '
            'WHERE user_id = ? AND task_type = ? AND eligibility_status = ? '
            'AND id IN (${_placeholders(ids.length)}) GROUP BY split',
            [
              userId,
              LibrarySqliteCodec.encodeEnum(taskType),
              'eligible',
              ...ids,
            ],
          );
    final actualSplitCounts = <String, int>{
      for (final row in rows) row['split']! as String: row['count']! as int,
    };
    final actualCount =
        actualSplitCounts.values.fold<int>(0, (sum, count) => sum + count);
    if (actualCount != ids.length) {
      throw StateError(
        'Manifest contains missing, ineligible, cross-owner or cross-task examples',
      );
    }
    if (actualSplitCounts.length != expectedSplitCounts.length ||
        expectedSplitCounts.entries.any(
          (entry) => actualSplitCounts[entry.key] != entry.value,
        )) {
      throw StateError('Manifest splitCounts do not match linked examples');
    }
  }

  static Future<void> _requireTrainingOwnership(
    DatabaseExecutor executor,
    TrainingRun run,
    List<String> exampleIds,
  ) async {
    final parents = await executor.rawQuery('''
      SELECT m.task_type AS model_task, d.task_type AS manifest_task
      FROM model_versions m
      JOIN dataset_manifests d ON d.id = ? AND d.user_id = m.user_id
      WHERE m.id = ? AND m.user_id = ?
    ''', [run.datasetManifestId, run.modelVersionId, run.userId]);
    if (parents.length != 1 ||
        parents.single['model_task'] != parents.single['manifest_task']) {
      throw StateError(
          'Training run parents are missing, cross-owner or cross-task');
    }
    if (exampleIds.isEmpty) return;
    final count = Sqflite.firstIntValue(await executor.rawQuery('''
      SELECT COUNT(*) FROM training_examples e
      JOIN dataset_manifest_examples dme ON dme.training_example_id = e.id
        AND dme.dataset_manifest_id = ?
      WHERE e.user_id = ? AND e.task_type = ?
        AND e.eligibility_status = 'eligible'
        AND e.id IN (${_placeholders(exampleIds.length)})
    ''', [
      run.datasetManifestId,
      run.userId,
      parents.single['model_task'],
      ...exampleIds,
    ]));
    if (count != exampleIds.length) {
      throw StateError(
        'Training run examples must belong to its owner, task and manifest',
      );
    }
  }

  static Future<void> _upsert(DatabaseExecutor executor, String table,
      Map<String, Object?> values, List<String> conflictColumns,
      {List<String> immutableColumns = const []}) {
    return executor.rawInsert(
      _upsertSql(
        table,
        values,
        conflictColumns,
        immutableColumns: immutableColumns,
      ),
      values.values.toList(),
    );
  }

  static String _upsertSql(
      String table, Map<String, Object?> values, List<String> conflictColumns,
      {List<String> immutableColumns = const []}) {
    final columns = values.keys.toList(growable: false);
    final updates = columns
        .where(
          (column) =>
              !conflictColumns.contains(column) &&
              !immutableColumns.contains(column),
        )
        .map((column) => '$column = excluded.$column')
        .join(', ');
    return 'INSERT INTO $table (${columns.join(', ')}) '
        'VALUES (${_placeholders(columns.length)}) '
        'ON CONFLICT (${conflictColumns.join(', ')}) DO UPDATE SET $updates';
  }

  static List<String> _uuidList(Iterable<String> values, String fieldName) {
    final ids =
        values.map((id) => requireUuid(id, fieldName)).toList(growable: false);
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('$fieldName must not contain duplicate IDs');
    }
    return ids;
  }

  static Future<void> _requireStableOwnerAndCreation(
    DatabaseExecutor executor, {
    required String table,
    required String id,
    required String userId,
    required DateTime createdAt,
  }) async {
    final existing = await executor.query(
      table,
      columns: ['user_id', 'created_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) return;
    if (existing.single['user_id'] != userId ||
        existing.single['created_at'] != createdAt.toIso8601String()) {
      throw StateError('$table cannot change owner or creation timestamp');
    }
  }

  static String _placeholders(int count) => List.filled(count, '?').join(', ');

  static bool _allowedSyncTransition(
    SyncOperationState from,
    SyncOperationState to,
  ) {
    if (from == to) return true;
    return switch (from) {
      SyncOperationState.pending =>
        to == SyncOperationState.running || to == SyncOperationState.blocked,
      SyncOperationState.running => to == SyncOperationState.retry ||
          to == SyncOperationState.blocked ||
          to == SyncOperationState.done,
      SyncOperationState.retry =>
        to == SyncOperationState.running || to == SyncOperationState.blocked,
      SyncOperationState.blocked =>
        to == SyncOperationState.pending || to == SyncOperationState.retry,
      SyncOperationState.done => false,
    };
  }
}
