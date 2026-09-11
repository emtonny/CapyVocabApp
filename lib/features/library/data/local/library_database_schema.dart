import 'package:sqflite/sqflite.dart';

abstract final class LibraryDatabaseSchema {
  static const version = 3;

  static const tableNames = <String>{
    'scan_results',
    'local_accounts',
    'consent_events',
    'media_assets',
    'scan_runs',
    'photo_notes',
    'vocab_detections',
    'vocab_annotations',
    'albums',
    'album_photo_notes',
    'model_versions',
    'learning_events',
    'srs_progress',
    'sync_operations',
    'sync_tombstones',
    'library_pull_cursors',
    'training_examples',
    'dataset_manifests',
    'dataset_manifest_examples',
    'training_runs',
    'training_run_examples',
    'legacy_scan_import_queue',
  };

  static Future<void> createLatest(Database database) async {
    for (final statement in _createStatements) {
      await database.execute(statement);
    }
    await queueLegacyRows(database);
  }

  static Future<void> upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await createLatest(database);
      return;
    }
    if (oldVersion < 3) {
      await database.execute(_libraryPullCursorsTable);
    }
  }

  static Future<void> queueLegacyRows(Database database) {
    return database.execute('''
      INSERT OR IGNORE INTO legacy_scan_import_queue (
        legacy_scan_result_id,
        migration_state,
        queued_at
      )
      SELECT id, 'pending', COALESCE(created_at, datetime('now'))
      FROM scan_results
    ''');
  }

  static const _createStatements = <String>[
    '''
      CREATE TABLE IF NOT EXISTS scan_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_path TEXT NOT NULL,
        vocab_json TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS local_accounts (
        user_id TEXT PRIMARY KEY,
        account_state TEXT NOT NULL
          CHECK (account_state IN ('active', 'locked', 'pending_purge')),
        last_authenticated_at TEXT,
        cloud_backup_enabled INTEGER NOT NULL DEFAULT 0
          CHECK (cloud_backup_enabled IN (0, 1)),
        local_personalization_enabled INTEGER NOT NULL DEFAULT 0
          CHECK (local_personalization_enabled IN (0, 1)),
        federated_contribution_enabled INTEGER NOT NULL DEFAULT 0
          CHECK (federated_contribution_enabled IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS consent_events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        consent_type TEXT NOT NULL CHECK (
          consent_type IN (
            'cloud_backup',
            'local_personalization',
            'federated_contribution'
          )
        ),
        old_value INTEGER NOT NULL CHECK (old_value IN (0, 1)),
        new_value INTEGER NOT NULL CHECK (new_value IN (0, 1)),
        policy_version TEXT NOT NULL,
        source_action TEXT NOT NULL,
        enforcement_state TEXT NOT NULL
          CHECK (enforcement_state IN ('pending', 'applied', 'failed')),
        occurred_at TEXT NOT NULL,
        CHECK (old_value != new_value),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS media_assets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        content_hash_sha256 TEXT NOT NULL CHECK (
          length(content_hash_sha256) = 64 AND
          lower(content_hash_sha256) NOT GLOB '*[^0-9a-f]*'
        ),
        original_relative_path TEXT,
        display_relative_path TEXT NOT NULL,
        model_input_relative_path TEXT,
        remote_original_path TEXT,
        remote_display_path TEXT,
        mime_type TEXT NOT NULL,
        width INTEGER NOT NULL CHECK (width > 0),
        height INTEGER NOT NULL CHECK (height > 0),
        orientation INTEGER NOT NULL CHECK (orientation >= 0),
        byte_size_original INTEGER CHECK (byte_size_original >= 0),
        byte_size_display INTEGER NOT NULL CHECK (byte_size_display >= 0),
        preprocessing_version TEXT NOT NULL,
        capture_source TEXT NOT NULL CHECK (
          capture_source IN ('camera', 'gallery', 'imported', 'migration')
        ),
        captured_at TEXT,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT NOT NULL CHECK (
          sync_status IN (
            'local_only', 'pending', 'syncing', 'synced',
            'failed_retryable', 'blocked_auth', 'blocked_contract',
            'quarantined'
          )
        ),
        UNIQUE (id, user_id),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS scan_runs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        media_asset_id TEXT NOT NULL,
        request_id TEXT NOT NULL UNIQUE,
        provider TEXT NOT NULL,
        model_name TEXT NOT NULL,
        model_version TEXT,
        service_tier TEXT,
        prompt_version TEXT NOT NULL,
        response_schema_version TEXT NOT NULL,
        preprocessing_version TEXT NOT NULL,
        raw_response_json TEXT,
        response_hash_sha256 TEXT CHECK (
          response_hash_sha256 IS NULL OR (
            length(response_hash_sha256) = 64 AND
            lower(response_hash_sha256) NOT GLOB '*[^0-9a-f]*'
          )
        ),
        status TEXT NOT NULL
          CHECK (status IN ('pending', 'succeeded', 'failed', 'quarantined')),
        error_code TEXT,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        UNIQUE (id, user_id),
        CHECK (
          status != 'succeeded' OR
          (raw_response_json IS NOT NULL AND response_hash_sha256 IS NOT NULL)
        ),
        FOREIGN KEY (media_asset_id, user_id)
          REFERENCES media_assets(id, user_id) ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS photo_notes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        media_asset_id TEXT NOT NULL,
        primary_scan_run_id TEXT,
        title TEXT NOT NULL CHECK (length(trim(title)) > 0),
        emoji TEXT,
        template_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT NOT NULL CHECK (
          sync_status IN (
            'local_only', 'pending', 'syncing', 'synced',
            'failed_retryable', 'blocked_auth', 'blocked_contract',
            'quarantined'
          )
        ),
        UNIQUE (id, user_id),
        FOREIGN KEY (media_asset_id, user_id)
          REFERENCES media_assets(id, user_id) ON DELETE CASCADE,
        FOREIGN KEY (primary_scan_run_id, user_id)
          REFERENCES scan_runs(id, user_id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS vocab_detections (
        id TEXT PRIMARY KEY,
        scan_run_id TEXT NOT NULL,
        word_raw TEXT NOT NULL,
        word_normalized TEXT NOT NULL,
        phonetic TEXT,
        meaning_vi TEXT,
        part_of_speech TEXT,
        example_en TEXT,
        example_vi TEXT,
        bbox_x REAL,
        bbox_y REAL,
        bbox_width REAL,
        bbox_height REAL,
        confidence REAL CHECK (
          confidence IS NULL OR confidence BETWEEN 0.0 AND 1.0
        ),
        display_order INTEGER NOT NULL CHECK (display_order >= 0),
        created_at TEXT NOT NULL,
        CHECK (
          (bbox_x IS NULL AND bbox_y IS NULL AND
            bbox_width IS NULL AND bbox_height IS NULL) OR
          (bbox_x BETWEEN 0.0 AND 1.0 AND
            bbox_y BETWEEN 0.0 AND 1.0 AND
            bbox_width > 0.0 AND bbox_height > 0.0 AND
            bbox_x + bbox_width <= 1.0 AND
            bbox_y + bbox_height <= 1.0)
        ),
        FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS vocab_annotations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        detection_id TEXT NOT NULL,
        source TEXT NOT NULL
          CHECK (source IN ('user_confirmed', 'user_corrected', 'imported')),
        quality_status TEXT NOT NULL
          CHECK (quality_status IN ('accepted', 'corrected', 'rejected')),
        corrected_word TEXT,
        corrected_phonetic TEXT,
        corrected_meaning_vi TEXT,
        corrected_bbox_json TEXT,
        revision INTEGER NOT NULL CHECK (revision > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        UNIQUE (detection_id, revision),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE,
        FOREIGN KEY (detection_id) REFERENCES vocab_detections(id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS albums (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL CHECK (length(trim(name)) > 0),
        icon TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        sync_status TEXT NOT NULL CHECK (
          sync_status IN (
            'local_only', 'pending', 'syncing', 'synced',
            'failed_retryable', 'blocked_auth', 'blocked_contract',
            'quarantined'
          )
        ),
        UNIQUE (id, user_id),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS album_photo_notes (
        album_id TEXT NOT NULL,
        photo_note_id TEXT NOT NULL,
        added_at TEXT NOT NULL,
        removed_at TEXT,
        operation_id TEXT NOT NULL,
        PRIMARY KEY (album_id, photo_note_id),
        FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE,
        FOREIGN KEY (photo_note_id) REFERENCES photo_notes(id) ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS model_versions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        task_type TEXT NOT NULL CHECK (
          task_type IN ('srs_recall', 'vision_classification', 'embedding_rerank')
        ),
        base_model_version TEXT NOT NULL,
        feature_schema_version TEXT NOT NULL,
        label_schema_version TEXT NOT NULL,
        local_checkpoint_relative_path TEXT,
        activation_status TEXT NOT NULL CHECK (
          activation_status IN ('candidate', 'active', 'superseded', 'invalidated')
        ),
        baseline_metrics_json TEXT NOT NULL,
        personalized_metrics_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        invalidated_at TEXT,
        CHECK (
          (activation_status = 'invalidated' AND invalidated_at IS NOT NULL) OR
          (activation_status != 'invalidated' AND invalidated_at IS NULL)
        ),
        UNIQUE (id, user_id),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS learning_events (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        vocab_annotation_id TEXT,
        detection_id TEXT,
        photo_note_id TEXT,
        session_id TEXT NOT NULL,
        event_type TEXT NOT NULL CHECK (
          event_type IN ('shown', 'answered', 'hinted', 'skipped', 'corrected')
        ),
        answer_normalized TEXT,
        is_correct INTEGER CHECK (is_correct IS NULL OR is_correct IN (0, 1)),
        response_time_ms INTEGER CHECK (
          response_time_ms IS NULL OR response_time_ms >= 0
        ),
        hint_count INTEGER CHECK (hint_count IS NULL OR hint_count >= 0),
        attempt_number INTEGER CHECK (
          attempt_number IS NULL OR attempt_number >= 0
        ),
        mastery_before REAL,
        mastery_after REAL,
        scheduler_version TEXT NOT NULL,
        model_version_id TEXT,
        occurred_at TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        CHECK (vocab_annotation_id IS NOT NULL OR detection_id IS NOT NULL),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE,
        FOREIGN KEY (vocab_annotation_id) REFERENCES vocab_annotations(id),
        FOREIGN KEY (detection_id) REFERENCES vocab_detections(id),
        FOREIGN KEY (photo_note_id) REFERENCES photo_notes(id),
        FOREIGN KEY (model_version_id) REFERENCES model_versions(id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS srs_progress (
        user_id TEXT NOT NULL,
        vocab_key TEXT NOT NULL,
        mastery_level REAL NOT NULL,
        review_count INTEGER NOT NULL CHECK (review_count >= 0),
        last_reviewed_at TEXT,
        next_review_at TEXT NOT NULL,
        scheduler_version TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, vocab_key),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS sync_operations (
        operation_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL CHECK (
          operation_type IN (
            'create', 'update', 'soft_delete', 'purge', 'upload', 'relation'
          )
        ),
        payload_json TEXT NOT NULL,
        dependency_ids_json TEXT NOT NULL DEFAULT '[]',
        state TEXT NOT NULL
          CHECK (state IN ('pending', 'running', 'retry', 'blocked', 'done')),
        attempt_count INTEGER NOT NULL CHECK (attempt_count >= 0),
        next_attempt_at TEXT,
        last_error_code TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS sync_tombstones (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        deletion_version INTEGER NOT NULL CHECK (deletion_version > 0),
        deleted_at TEXT NOT NULL,
        remote_purge_completed INTEGER NOT NULL DEFAULT 0
          CHECK (remote_purge_completed IN (0, 1)),
        UNIQUE (user_id, entity_type, entity_id),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    _libraryPullCursorsTable,
    '''
      CREATE TABLE IF NOT EXISTS training_examples (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        task_type TEXT NOT NULL CHECK (
          task_type IN ('srs_recall', 'vision_classification', 'embedding_rerank')
        ),
        media_asset_id TEXT,
        source_detection_id TEXT,
        source_annotation_id TEXT,
        feature_schema_version TEXT NOT NULL,
        label_schema_version TEXT NOT NULL,
        builder_version TEXT NOT NULL,
        features_json TEXT NOT NULL,
        target_json TEXT NOT NULL,
        eligibility_status TEXT NOT NULL
          CHECK (eligibility_status IN ('eligible', 'excluded', 'quarantined')),
        quality_score REAL CHECK (
          quality_score IS NULL OR quality_score BETWEEN 0.0 AND 1.0
        ),
        split TEXT NOT NULL
          CHECK (split IN ('train', 'validation', 'test', 'excluded')),
        split_seed_version TEXT NOT NULL,
        created_at TEXT NOT NULL,
        CHECK (eligibility_status = 'eligible' OR split = 'excluded'),
        CHECK (
          task_type = 'srs_recall' OR
          source_detection_id IS NOT NULL OR
          source_annotation_id IS NOT NULL
        ),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE,
        FOREIGN KEY (media_asset_id) REFERENCES media_assets(id),
        FOREIGN KEY (source_detection_id) REFERENCES vocab_detections(id),
        FOREIGN KEY (source_annotation_id) REFERENCES vocab_annotations(id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS dataset_manifests (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        task_type TEXT NOT NULL CHECK (
          task_type IN ('srs_recall', 'vision_classification', 'embedding_rerank')
        ),
        builder_version TEXT NOT NULL,
        feature_schema_version TEXT NOT NULL,
        label_schema_version TEXT NOT NULL,
        split_seed_version TEXT NOT NULL,
        source_watermark TEXT NOT NULL,
        split_counts_json TEXT NOT NULL,
        consent_snapshot_json TEXT NOT NULL,
        quality_report_json TEXT NOT NULL,
        manifest_hash_sha256 TEXT NOT NULL CHECK (
          length(manifest_hash_sha256) = 64 AND
          lower(manifest_hash_sha256) NOT GLOB '*[^0-9a-f]*'
        ),
        created_at TEXT NOT NULL,
        UNIQUE (id, user_id),
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS dataset_manifest_examples (
        dataset_manifest_id TEXT NOT NULL,
        training_example_id TEXT NOT NULL,
        PRIMARY KEY (dataset_manifest_id, training_example_id),
        FOREIGN KEY (dataset_manifest_id) REFERENCES dataset_manifests(id)
          ON DELETE CASCADE,
        FOREIGN KEY (training_example_id) REFERENCES training_examples(id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS training_runs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        model_version_id TEXT NOT NULL,
        dataset_manifest_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK (
          status IN ('pending', 'running', 'succeeded', 'failed', 'cancelled')
        ),
        sample_count INTEGER NOT NULL CHECK (sample_count >= 0),
        training_steps INTEGER NOT NULL CHECK (training_steps >= 0),
        metrics_json TEXT NOT NULL,
        runtime_metadata_json TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE,
        FOREIGN KEY (model_version_id) REFERENCES model_versions(id),
        FOREIGN KEY (dataset_manifest_id) REFERENCES dataset_manifests(id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS training_run_examples (
        training_run_id TEXT NOT NULL,
        training_example_id TEXT NOT NULL,
        PRIMARY KEY (training_run_id, training_example_id),
        FOREIGN KEY (training_run_id) REFERENCES training_runs(id)
          ON DELETE CASCADE,
        FOREIGN KEY (training_example_id) REFERENCES training_examples(id)
      )
    ''',
    '''
      CREATE TABLE IF NOT EXISTS legacy_scan_import_queue (
        legacy_scan_result_id INTEGER PRIMARY KEY,
        migration_state TEXT NOT NULL
          CHECK (migration_state IN ('pending', 'imported', 'quarantined')),
        imported_media_asset_id TEXT,
        imported_scan_run_id TEXT,
        error_code TEXT,
        queued_at TEXT NOT NULL,
        processed_at TEXT,
        FOREIGN KEY (legacy_scan_result_id) REFERENCES scan_results(id)
          ON DELETE RESTRICT,
        FOREIGN KEY (imported_media_asset_id) REFERENCES media_assets(id),
        FOREIGN KEY (imported_scan_run_id) REFERENCES scan_runs(id)
      )
    ''',
    '''
      CREATE INDEX IF NOT EXISTS idx_photo_notes_user_created
      ON photo_notes(user_id, deleted_at, created_at DESC)
    ''',
    '''
      CREATE INDEX IF NOT EXISTS idx_albums_user_favorite
      ON albums(user_id, deleted_at, is_favorite DESC, created_at DESC)
    ''',
    '''
      CREATE INDEX IF NOT EXISTS idx_detections_scan_order
      ON vocab_detections(scan_run_id, display_order)
    ''',
    '''
      CREATE INDEX IF NOT EXISTS idx_learning_events_user_time
      ON learning_events(user_id, occurred_at)
    ''',
    '''
      CREATE INDEX IF NOT EXISTS idx_sync_operations_ready
      ON sync_operations(user_id, state, next_attempt_at, created_at)
    ''',
    '''
      CREATE INDEX IF NOT EXISTS idx_training_examples_eligible
      ON training_examples(user_id, task_type, eligibility_status, split)
    ''',
    '''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_model_versions_one_active
      ON model_versions(user_id, task_type)
      WHERE activation_status = 'active'
    ''',
    '''
      CREATE TRIGGER IF NOT EXISTS trg_scan_runs_raw_immutable
      BEFORE UPDATE OF raw_response_json, response_hash_sha256 ON scan_runs
      WHEN OLD.raw_response_json IS NOT NULL AND (
        NEW.raw_response_json IS NOT OLD.raw_response_json OR
        NEW.response_hash_sha256 IS NOT OLD.response_hash_sha256
      )
      BEGIN
        SELECT RAISE(ABORT, 'scan run raw evidence is immutable');
      END
    ''',
    '''
      CREATE TRIGGER IF NOT EXISTS trg_learning_events_no_update
      BEFORE UPDATE ON learning_events
      BEGIN
        SELECT RAISE(ABORT, 'learning events are append-only');
      END
    ''',
    '''
      CREATE TRIGGER IF NOT EXISTS trg_consent_events_audit_immutable
      BEFORE UPDATE OF
        user_id,
        consent_type,
        old_value,
        new_value,
        policy_version,
        source_action,
        occurred_at
      ON consent_events
      BEGIN
        SELECT RAISE(ABORT, 'consent audit evidence is immutable');
      END
    ''',
  ];

  static const _libraryPullCursorsTable = '''
      CREATE TABLE IF NOT EXISTS library_pull_cursors (
        user_id TEXT PRIMARY KEY,
        last_sequence INTEGER NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES local_accounts(user_id)
          ON DELETE CASCADE
      )
    ''';
}
