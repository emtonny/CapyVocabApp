import 'dart:convert';

import '../../domain/entities/album_models.dart';
import '../../domain/entities/consent_event.dart';
import '../../domain/entities/learning_models.dart';
import '../../domain/entities/library_enums.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/normalized_bounding_box.dart';
import '../../domain/entities/photo_note.dart';
import '../../domain/entities/scan_models.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/entities/training_models.dart';

abstract final class LibrarySqliteCodec {
  static Map<String, Object?> localAccountToMap(LocalAccount value) => {
        'user_id': value.userId,
        'account_state': encodeEnum(value.accountState),
        'last_authenticated_at': _dateToText(value.lastAuthenticatedAt),
        'cloud_backup_enabled': _boolToInt(value.cloudBackupEnabled),
        'local_personalization_enabled':
            _boolToInt(value.localPersonalizationEnabled),
        'federated_contribution_enabled':
            _boolToInt(value.federatedContributionEnabled),
        'created_at': _dateToText(value.createdAt),
        'updated_at': _dateToText(value.updatedAt),
      };

  static LocalAccount localAccountFromMap(Map<String, Object?> row) =>
      LocalAccount(
        userId: row['user_id']! as String,
        accountState: decodeEnum(AccountState.values, row['account_state']),
        lastAuthenticatedAt: _nullableDate(row['last_authenticated_at']),
        cloudBackupEnabled: _boolFromInt(row['cloud_backup_enabled']),
        localPersonalizationEnabled:
            _boolFromInt(row['local_personalization_enabled']),
        federatedContributionEnabled:
            _boolFromInt(row['federated_contribution_enabled']),
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
      );

  static Map<String, Object?> consentEventToMap(ConsentEvent value) => {
        'id': value.id,
        'user_id': value.userId,
        'consent_type': encodeEnum(value.consentType),
        'old_value': _boolToInt(value.oldValue),
        'new_value': _boolToInt(value.newValue),
        'policy_version': value.policyVersion,
        'source_action': value.sourceAction,
        'enforcement_state': encodeEnum(value.enforcementState),
        'occurred_at': _dateToText(value.occurredAt),
      };

  static ConsentEvent consentEventFromMap(Map<String, Object?> row) =>
      ConsentEvent(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        consentType: decodeEnum(ConsentType.values, row['consent_type']),
        oldValue: _boolFromInt(row['old_value']),
        newValue: _boolFromInt(row['new_value']),
        policyVersion: row['policy_version']! as String,
        sourceAction: row['source_action']! as String,
        enforcementState: decodeEnum(
          ConsentEnforcementState.values,
          row['enforcement_state'],
        ),
        occurredAt: _date(row['occurred_at']),
      );

  static Map<String, Object?> mediaAssetToMap(MediaAsset value) => {
        'id': value.id,
        'user_id': value.userId,
        'content_hash_sha256': value.contentHashSha256,
        'original_relative_path': value.originalRelativePath,
        'display_relative_path': value.displayRelativePath,
        'model_input_relative_path': value.modelInputRelativePath,
        'remote_original_path': value.remoteOriginalPath,
        'remote_display_path': value.remoteDisplayPath,
        'mime_type': value.mimeType,
        'width': value.width,
        'height': value.height,
        'orientation': value.orientation,
        'byte_size_original': value.byteSizeOriginal,
        'byte_size_display': value.byteSizeDisplay,
        'preprocessing_version': value.preprocessingVersion,
        'capture_source': encodeEnum(value.captureSource),
        'captured_at': _dateToText(value.capturedAt),
        'created_at': _dateToText(value.createdAt),
        'deleted_at': _dateToText(value.deletedAt),
        'sync_status': encodeEnum(value.syncStatus),
      };

  static MediaAsset mediaAssetFromMap(Map<String, Object?> row) => MediaAsset(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        contentHashSha256: row['content_hash_sha256']! as String,
        originalRelativePath: row['original_relative_path'] as String?,
        displayRelativePath: row['display_relative_path']! as String,
        modelInputRelativePath: row['model_input_relative_path'] as String?,
        remoteOriginalPath: row['remote_original_path'] as String?,
        remoteDisplayPath: row['remote_display_path'] as String?,
        mimeType: row['mime_type']! as String,
        width: row['width']! as int,
        height: row['height']! as int,
        orientation: row['orientation']! as int,
        byteSizeOriginal: row['byte_size_original'] as int?,
        byteSizeDisplay: row['byte_size_display']! as int,
        preprocessingVersion: row['preprocessing_version']! as String,
        captureSource: decodeEnum(
          CaptureSource.values,
          row['capture_source'],
        ),
        capturedAt: _nullableDate(row['captured_at']),
        createdAt: _date(row['created_at']),
        deletedAt: _nullableDate(row['deleted_at']),
        syncStatus: decodeEnum(SyncStatus.values, row['sync_status']),
      );

  static Map<String, Object?> photoNoteToMap(PhotoNote value) => {
        'id': value.id,
        'user_id': value.userId,
        'media_asset_id': value.mediaAssetId,
        'primary_scan_run_id': value.primaryScanRunId,
        'title': value.title,
        'emoji': value.emoji,
        'template_id': value.templateId,
        'created_at': _dateToText(value.createdAt),
        'updated_at': _dateToText(value.updatedAt),
        'deleted_at': _dateToText(value.deletedAt),
        'sync_status': encodeEnum(value.syncStatus),
      };

  static PhotoNote photoNoteFromMap(Map<String, Object?> row) => PhotoNote(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        mediaAssetId: row['media_asset_id']! as String,
        primaryScanRunId: row['primary_scan_run_id'] as String?,
        title: row['title']! as String,
        emoji: row['emoji'] as String?,
        templateId: row['template_id']! as String,
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
        deletedAt: _nullableDate(row['deleted_at']),
        syncStatus: decodeEnum(SyncStatus.values, row['sync_status']),
      );

  static Map<String, Object?> scanRunToMap(ScanRun value) => {
        'id': value.id,
        'user_id': value.userId,
        'media_asset_id': value.mediaAssetId,
        'request_id': value.requestId,
        'provider': value.provider,
        'model_name': value.modelName,
        'model_version': value.modelVersion,
        'service_tier': value.serviceTier,
        'prompt_version': value.promptVersion,
        'response_schema_version': value.responseSchemaVersion,
        'preprocessing_version': value.preprocessingVersion,
        'raw_response_json': _jsonToText(value.rawResponseJson),
        'response_hash_sha256': value.responseHashSha256,
        'status': encodeEnum(value.status),
        'error_code': value.errorCode,
        'started_at': _dateToText(value.startedAt),
        'completed_at': _dateToText(value.completedAt),
      };

  static ScanRun scanRunFromMap(Map<String, Object?> row) => ScanRun(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        mediaAssetId: row['media_asset_id']! as String,
        requestId: row['request_id']! as String,
        provider: row['provider']! as String,
        modelName: row['model_name']! as String,
        modelVersion: row['model_version'] as String?,
        serviceTier: row['service_tier'] as String?,
        promptVersion: row['prompt_version']! as String,
        responseSchemaVersion: row['response_schema_version']! as String,
        preprocessingVersion: row['preprocessing_version']! as String,
        rawResponseJson: _nullableJsonMap(row['raw_response_json']),
        responseHashSha256: row['response_hash_sha256'] as String?,
        status: decodeEnum(ScanRunStatus.values, row['status']),
        errorCode: row['error_code'] as String?,
        startedAt: _date(row['started_at']),
        completedAt: _nullableDate(row['completed_at']),
      );

  static Map<String, Object?> vocabDetectionToMap(VocabDetection value) => {
        'id': value.id,
        'scan_run_id': value.scanRunId,
        'word_raw': value.wordRaw,
        'word_normalized': value.wordNormalized,
        'phonetic': value.phonetic,
        'meaning_vi': value.meaningVi,
        'part_of_speech': value.partOfSpeech,
        'example_en': value.exampleEn,
        'example_vi': value.exampleVi,
        'bbox_x': value.boundingBox?.x,
        'bbox_y': value.boundingBox?.y,
        'bbox_width': value.boundingBox?.width,
        'bbox_height': value.boundingBox?.height,
        'confidence': value.confidence,
        'display_order': value.displayOrder,
        'created_at': _dateToText(value.createdAt),
      };

  static VocabDetection vocabDetectionFromMap(Map<String, Object?> row) =>
      VocabDetection(
        id: row['id']! as String,
        scanRunId: row['scan_run_id']! as String,
        wordRaw: row['word_raw']! as String,
        wordNormalized: row['word_normalized']! as String,
        phonetic: row['phonetic'] as String?,
        meaningVi: row['meaning_vi'] as String?,
        partOfSpeech: row['part_of_speech'] as String?,
        exampleEn: row['example_en'] as String?,
        exampleVi: row['example_vi'] as String?,
        boundingBox: row['bbox_x'] == null
            ? null
            : NormalizedBoundingBox(
                x: (row['bbox_x']! as num).toDouble(),
                y: (row['bbox_y']! as num).toDouble(),
                width: (row['bbox_width']! as num).toDouble(),
                height: (row['bbox_height']! as num).toDouble(),
              ),
        confidence: (row['confidence'] as num?)?.toDouble(),
        displayOrder: row['display_order']! as int,
        createdAt: _date(row['created_at']),
      );

  static Map<String, Object?> vocabAnnotationToMap(VocabAnnotation value) => {
        'id': value.id,
        'user_id': value.userId,
        'detection_id': value.detectionId,
        'source': encodeEnum(value.source),
        'quality_status': encodeEnum(value.qualityStatus),
        'corrected_word': value.correctedWord,
        'corrected_phonetic': value.correctedPhonetic,
        'corrected_meaning_vi': value.correctedMeaningVi,
        'corrected_bbox_json': _jsonToText(
          value.correctedBoundingBox == null
              ? null
              : {
                  'x': value.correctedBoundingBox!.x,
                  'y': value.correctedBoundingBox!.y,
                  'width': value.correctedBoundingBox!.width,
                  'height': value.correctedBoundingBox!.height,
                },
        ),
        'revision': value.revision,
        'created_at': _dateToText(value.createdAt),
        'updated_at': _dateToText(value.updatedAt),
        'deleted_at': _dateToText(value.deletedAt),
      };

  static VocabAnnotation vocabAnnotationFromMap(Map<String, Object?> row) {
    final box = _nullableJsonMap(row['corrected_bbox_json']);
    return VocabAnnotation(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      detectionId: row['detection_id']! as String,
      source: decodeEnum(AnnotationSource.values, row['source']),
      qualityStatus: decodeEnum(
        AnnotationQualityStatus.values,
        row['quality_status'],
      ),
      correctedWord: row['corrected_word'] as String?,
      correctedPhonetic: row['corrected_phonetic'] as String?,
      correctedMeaningVi: row['corrected_meaning_vi'] as String?,
      correctedBoundingBox: box == null
          ? null
          : NormalizedBoundingBox(
              x: (box['x']! as num).toDouble(),
              y: (box['y']! as num).toDouble(),
              width: (box['width']! as num).toDouble(),
              height: (box['height']! as num).toDouble(),
            ),
      revision: row['revision']! as int,
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      deletedAt: _nullableDate(row['deleted_at']),
    );
  }

  static Map<String, Object?> albumToMap(Album value) => {
        'id': value.id,
        'user_id': value.userId,
        'name': value.name,
        'icon': value.icon,
        'is_favorite': _boolToInt(value.isFavorite),
        'created_at': _dateToText(value.createdAt),
        'updated_at': _dateToText(value.updatedAt),
        'deleted_at': _dateToText(value.deletedAt),
        'sync_status': encodeEnum(value.syncStatus),
      };

  static Album albumFromMap(Map<String, Object?> row) => Album(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        name: row['name']! as String,
        icon: row['icon']! as String,
        isFavorite: _boolFromInt(row['is_favorite']),
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
        deletedAt: _nullableDate(row['deleted_at']),
        syncStatus: decodeEnum(SyncStatus.values, row['sync_status']),
      );

  static Map<String, Object?> albumPhotoNoteToMap(AlbumPhotoNote value) => {
        'album_id': value.albumId,
        'photo_note_id': value.photoNoteId,
        'added_at': _dateToText(value.addedAt),
        'removed_at': _dateToText(value.removedAt),
        'operation_id': value.operationId,
      };

  static AlbumPhotoNote albumPhotoNoteFromMap(Map<String, Object?> row) =>
      AlbumPhotoNote(
        albumId: row['album_id']! as String,
        photoNoteId: row['photo_note_id']! as String,
        addedAt: _date(row['added_at']),
        removedAt: _nullableDate(row['removed_at']),
        operationId: row['operation_id']! as String,
      );

  static Map<String, Object?> learningEventToMap(LearningEvent value) => {
        'id': value.id,
        'user_id': value.userId,
        'vocab_annotation_id': value.vocabAnnotationId,
        'detection_id': value.detectionId,
        'photo_note_id': value.photoNoteId,
        'session_id': value.sessionId,
        'event_type': encodeEnum(value.eventType),
        'answer_normalized': value.answerNormalized,
        'is_correct': _nullableBoolToInt(value.isCorrect),
        'response_time_ms': value.responseTimeMs,
        'hint_count': value.hintCount,
        'attempt_number': value.attemptNumber,
        'mastery_before': value.masteryBefore,
        'mastery_after': value.masteryAfter,
        'scheduler_version': value.schedulerVersion,
        'model_version_id': value.modelVersionId,
        'occurred_at': _dateToText(value.occurredAt),
        'recorded_at': _dateToText(value.recordedAt),
      };

  static LearningEvent learningEventFromMap(Map<String, Object?> row) =>
      LearningEvent(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        vocabAnnotationId: row['vocab_annotation_id'] as String?,
        detectionId: row['detection_id'] as String?,
        photoNoteId: row['photo_note_id'] as String?,
        sessionId: row['session_id']! as String,
        eventType: decodeEnum(LearningEventType.values, row['event_type']),
        answerNormalized: row['answer_normalized'] as String?,
        isCorrect: _nullableBoolFromInt(row['is_correct']),
        responseTimeMs: row['response_time_ms'] as int?,
        hintCount: row['hint_count'] as int?,
        attemptNumber: row['attempt_number'] as int?,
        masteryBefore: (row['mastery_before'] as num?)?.toDouble(),
        masteryAfter: (row['mastery_after'] as num?)?.toDouble(),
        schedulerVersion: row['scheduler_version']! as String,
        modelVersionId: row['model_version_id'] as String?,
        occurredAt: _date(row['occurred_at']),
        recordedAt: _date(row['recorded_at']),
      );

  static Map<String, Object?> srsProgressToMap(SrsProgress value) => {
        'user_id': value.userId,
        'vocab_key': value.vocabKey,
        'mastery_level': value.masteryLevel,
        'review_count': value.reviewCount,
        'last_reviewed_at': _dateToText(value.lastReviewedAt),
        'next_review_at': _dateToText(value.nextReviewAt),
        'scheduler_version': value.schedulerVersion,
        'updated_at': _dateToText(value.updatedAt),
      };

  static SrsProgress srsProgressFromMap(Map<String, Object?> row) =>
      SrsProgress(
        userId: row['user_id']! as String,
        vocabKey: row['vocab_key']! as String,
        masteryLevel: (row['mastery_level']! as num).toDouble(),
        reviewCount: row['review_count']! as int,
        lastReviewedAt: _nullableDate(row['last_reviewed_at']),
        nextReviewAt: _date(row['next_review_at']),
        schedulerVersion: row['scheduler_version']! as String,
        updatedAt: _date(row['updated_at']),
      );

  static Map<String, Object?> syncOperationToMap(SyncOperation value) => {
        'operation_id': value.operationId,
        'user_id': value.userId,
        'entity_type': encodeEnum(value.entityType),
        'entity_id': value.entityId,
        'operation_type': encodeEnum(value.operationType),
        'payload_json': _jsonToText(value.payloadJson),
        'dependency_ids_json': jsonEncode(value.dependencyIds),
        'state': encodeEnum(value.state),
        'attempt_count': value.attemptCount,
        'next_attempt_at': _dateToText(value.nextAttemptAt),
        'last_error_code': value.lastErrorCode,
        'created_at': _dateToText(value.createdAt),
        'updated_at': _dateToText(value.updatedAt),
      };

  static SyncOperation syncOperationFromMap(Map<String, Object?> row) =>
      SyncOperation(
        operationId: row['operation_id']! as String,
        userId: row['user_id']! as String,
        entityType: decodeEnum(SyncEntityType.values, row['entity_type']),
        entityId: row['entity_id']! as String,
        operationType: decodeEnum(
          SyncOperationType.values,
          row['operation_type'],
        ),
        payloadJson: _jsonMap(row['payload_json']),
        dependencyIds: _stringList(row['dependency_ids_json']),
        state: decodeEnum(SyncOperationState.values, row['state']),
        attemptCount: row['attempt_count']! as int,
        nextAttemptAt: _nullableDate(row['next_attempt_at']),
        lastErrorCode: row['last_error_code'] as String?,
        createdAt: _date(row['created_at']),
        updatedAt: _date(row['updated_at']),
      );

  static Map<String, Object?> syncTombstoneToMap(SyncTombstone value) => {
        'id': value.id,
        'user_id': value.userId,
        'entity_type': encodeEnum(value.entityType),
        'entity_id': value.entityId,
        'deletion_version': value.deletionVersion,
        'deleted_at': _dateToText(value.deletedAt),
        'remote_purge_completed': _boolToInt(value.remotePurgeCompleted),
      };

  static SyncTombstone syncTombstoneFromMap(Map<String, Object?> row) =>
      SyncTombstone(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        entityType: decodeEnum(SyncEntityType.values, row['entity_type']),
        entityId: row['entity_id']! as String,
        deletionVersion: row['deletion_version']! as int,
        deletedAt: _date(row['deleted_at']),
        remotePurgeCompleted: _boolFromInt(row['remote_purge_completed']),
      );

  static Map<String, Object?> trainingExampleToMap(TrainingExample value) => {
        'id': value.id,
        'user_id': value.userId,
        'task_type': encodeEnum(value.taskType),
        'media_asset_id': value.mediaAssetId,
        'source_detection_id': value.sourceDetectionId,
        'source_annotation_id': value.sourceAnnotationId,
        'feature_schema_version': value.featureSchemaVersion,
        'label_schema_version': value.labelSchemaVersion,
        'builder_version': value.builderVersion,
        'features_json': _jsonToText(value.featuresJson),
        'target_json': _jsonToText(value.targetJson),
        'eligibility_status': encodeEnum(value.eligibilityStatus),
        'quality_score': value.qualityScore,
        'split': encodeEnum(value.split),
        'split_seed_version': value.splitSeedVersion,
        'created_at': _dateToText(value.createdAt),
      };

  static TrainingExample trainingExampleFromMap(Map<String, Object?> row) =>
      TrainingExample(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        taskType: decodeEnum(TrainingTaskType.values, row['task_type']),
        mediaAssetId: row['media_asset_id'] as String?,
        sourceDetectionId: row['source_detection_id'] as String?,
        sourceAnnotationId: row['source_annotation_id'] as String?,
        featureSchemaVersion: row['feature_schema_version']! as String,
        labelSchemaVersion: row['label_schema_version']! as String,
        builderVersion: row['builder_version']! as String,
        featuresJson: _jsonMap(row['features_json']),
        targetJson: _jsonMap(row['target_json']),
        eligibilityStatus: decodeEnum(
          TrainingEligibilityStatus.values,
          row['eligibility_status'],
        ),
        qualityScore: (row['quality_score'] as num?)?.toDouble(),
        split: decodeEnum(DatasetSplit.values, row['split']),
        splitSeedVersion: row['split_seed_version']! as String,
        createdAt: _date(row['created_at']),
      );

  static Map<String, Object?> datasetManifestToMap(DatasetManifest value) => {
        'id': value.id,
        'user_id': value.userId,
        'task_type': encodeEnum(value.taskType),
        'builder_version': value.builderVersion,
        'feature_schema_version': value.featureSchemaVersion,
        'label_schema_version': value.labelSchemaVersion,
        'split_seed_version': value.splitSeedVersion,
        'source_watermark': value.sourceWatermark,
        'split_counts_json': jsonEncode(value.splitCounts),
        'consent_snapshot_json': _jsonToText(value.consentSnapshot),
        'quality_report_json': _jsonToText(value.qualityReport),
        'manifest_hash_sha256': value.manifestHashSha256,
        'created_at': _dateToText(value.createdAt),
      };

  static DatasetManifest datasetManifestFromMap(Map<String, Object?> row) =>
      DatasetManifest(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        taskType: decodeEnum(TrainingTaskType.values, row['task_type']),
        builderVersion: row['builder_version']! as String,
        featureSchemaVersion: row['feature_schema_version']! as String,
        labelSchemaVersion: row['label_schema_version']! as String,
        splitSeedVersion: row['split_seed_version']! as String,
        sourceWatermark: row['source_watermark']! as String,
        splitCounts: _intMap(row['split_counts_json']),
        consentSnapshot: _jsonMap(row['consent_snapshot_json']),
        qualityReport: _jsonMap(row['quality_report_json']),
        manifestHashSha256: row['manifest_hash_sha256']! as String,
        createdAt: _date(row['created_at']),
      );

  static Map<String, Object?> modelVersionToMap(ModelVersion value) => {
        'id': value.id,
        'user_id': value.userId,
        'task_type': encodeEnum(value.taskType),
        'base_model_version': value.baseModelVersion,
        'feature_schema_version': value.featureSchemaVersion,
        'label_schema_version': value.labelSchemaVersion,
        'local_checkpoint_relative_path': value.localCheckpointRelativePath,
        'activation_status': encodeEnum(value.activationStatus),
        'baseline_metrics_json': _jsonToText(value.baselineMetrics),
        'personalized_metrics_json': _jsonToText(value.personalizedMetrics),
        'created_at': _dateToText(value.createdAt),
        'invalidated_at': _dateToText(value.invalidatedAt),
      };

  static ModelVersion modelVersionFromMap(Map<String, Object?> row) =>
      ModelVersion(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        taskType: decodeEnum(TrainingTaskType.values, row['task_type']),
        baseModelVersion: row['base_model_version']! as String,
        featureSchemaVersion: row['feature_schema_version']! as String,
        labelSchemaVersion: row['label_schema_version']! as String,
        localCheckpointRelativePath:
            row['local_checkpoint_relative_path'] as String?,
        activationStatus: decodeEnum(
          ModelActivationStatus.values,
          row['activation_status'],
        ),
        baselineMetrics: _jsonMap(row['baseline_metrics_json']),
        personalizedMetrics: _jsonMap(row['personalized_metrics_json']),
        createdAt: _date(row['created_at']),
        invalidatedAt: _nullableDate(row['invalidated_at']),
      );

  static Map<String, Object?> trainingRunToMap(TrainingRun value) => {
        'id': value.id,
        'user_id': value.userId,
        'model_version_id': value.modelVersionId,
        'dataset_manifest_id': value.datasetManifestId,
        'status': encodeEnum(value.status),
        'sample_count': value.sampleCount,
        'training_steps': value.trainingSteps,
        'metrics_json': _jsonToText(value.metrics),
        'runtime_metadata_json': _jsonToText(value.runtimeMetadata),
        'started_at': _dateToText(value.startedAt),
        'completed_at': _dateToText(value.completedAt),
      };

  static TrainingRun trainingRunFromMap(Map<String, Object?> row) =>
      TrainingRun(
        id: row['id']! as String,
        userId: row['user_id']! as String,
        modelVersionId: row['model_version_id']! as String,
        datasetManifestId: row['dataset_manifest_id']! as String,
        status: decodeEnum(TrainingRunStatus.values, row['status']),
        sampleCount: row['sample_count']! as int,
        trainingSteps: row['training_steps']! as int,
        metrics: _jsonMap(row['metrics_json']),
        runtimeMetadata: _jsonMap(row['runtime_metadata_json']),
        startedAt: _date(row['started_at']),
        completedAt: _nullableDate(row['completed_at']),
      );

  static String encodeEnum(Enum value) {
    return value.name.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  static T decodeEnum<T extends Enum>(List<T> values, Object? raw) {
    for (final value in values) {
      if (encodeEnum(value) == raw) return value;
    }
    throw FormatException('Unknown ${T.toString()} database value: $raw');
  }

  static String? _dateToText(DateTime? value) => value?.toIso8601String();

  static DateTime _date(Object? value) => DateTime.parse(value! as String);

  static DateTime? _nullableDate(Object? value) {
    return value == null ? null : _date(value);
  }

  static int _boolToInt(bool value) => value ? 1 : 0;

  static int? _nullableBoolToInt(bool? value) {
    return value == null ? null : _boolToInt(value);
  }

  static bool _boolFromInt(Object? value) => value == 1;

  static bool? _nullableBoolFromInt(Object? value) {
    return value == null ? null : _boolFromInt(value);
  }

  static String? _jsonToText(Object? value) {
    return value == null ? null : jsonEncode(value);
  }

  static Map<String, Object?> _jsonMap(Object? value) {
    final decoded = jsonDecode(value! as String);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  static Map<String, Object?>? _nullableJsonMap(Object? value) {
    return value == null ? null : _jsonMap(value);
  }

  static List<String> _stringList(Object? value) {
    final decoded = jsonDecode(value! as String);
    if (decoded is! List<Object?> || decoded.any((item) => item is! String)) {
      throw const FormatException('Expected a JSON string list');
    }
    return decoded.cast<String>();
  }

  static Map<String, int> _intMap(Object? value) {
    final decoded = _jsonMap(value);
    return decoded.map((key, item) {
      if (item is! int) throw const FormatException('Expected integer values');
      return MapEntry(key, item);
    });
  }
}
