import 'domain_validation.dart';
import 'library_enums.dart';

final class TrainingExample {
  TrainingExample({
    required String id,
    required String userId,
    required this.taskType,
    required String featureSchemaVersion,
    required String labelSchemaVersion,
    required String builderVersion,
    required Map<String, Object?> featuresJson,
    required Map<String, Object?> targetJson,
    required this.eligibilityStatus,
    required this.split,
    required String splitSeedVersion,
    required DateTime createdAt,
    String? mediaAssetId,
    String? sourceDetectionId,
    String? sourceAnnotationId,
    double? qualityScore,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        mediaAssetId = _nullableUuid(mediaAssetId, 'mediaAssetId'),
        sourceDetectionId = _nullableUuid(
          sourceDetectionId,
          'sourceDetectionId',
        ),
        sourceAnnotationId = _nullableUuid(
          sourceAnnotationId,
          'sourceAnnotationId',
        ),
        featureSchemaVersion = requireNonEmpty(
          featureSchemaVersion,
          'featureSchemaVersion',
        ),
        labelSchemaVersion = requireNonEmpty(
          labelSchemaVersion,
          'labelSchemaVersion',
        ),
        builderVersion = requireNonEmpty(builderVersion, 'builderVersion'),
        featuresJson = freezeJsonObject(featuresJson, 'featuresJson'),
        targetJson = freezeJsonObject(targetJson, 'targetJson'),
        qualityScore = qualityScore == null
            ? null
            : requireUnitInterval(qualityScore, 'qualityScore'),
        splitSeedVersion = requireNonEmpty(
          splitSeedVersion,
          'splitSeedVersion',
        ),
        createdAt = requireUtc(createdAt, 'createdAt') {
    if (this.sourceAnnotationId == null &&
        this.sourceDetectionId == null &&
        taskType != TrainingTaskType.srsRecall) {
      throw ArgumentError(
        'non-SRS examples require sourceAnnotationId or sourceDetectionId',
      );
    }
    if (eligibilityStatus != TrainingEligibilityStatus.eligible &&
        split != DatasetSplit.excluded) {
      throw ArgumentError('ineligible examples must use the excluded split');
    }
  }

  final String id;
  final String userId;
  final TrainingTaskType taskType;
  final String? mediaAssetId;
  final String? sourceDetectionId;
  final String? sourceAnnotationId;
  final String featureSchemaVersion;
  final String labelSchemaVersion;
  final String builderVersion;
  final Map<String, Object?> featuresJson;
  final Map<String, Object?> targetJson;
  final TrainingEligibilityStatus eligibilityStatus;
  final double? qualityScore;
  final DatasetSplit split;
  final String splitSeedVersion;
  final DateTime createdAt;
}

final class DatasetManifest {
  DatasetManifest({
    required String id,
    required String userId,
    required this.taskType,
    required String builderVersion,
    required String featureSchemaVersion,
    required String labelSchemaVersion,
    required String splitSeedVersion,
    required String sourceWatermark,
    required Map<String, int> splitCounts,
    required Map<String, Object?> consentSnapshot,
    required Map<String, Object?> qualityReport,
    required String manifestHashSha256,
    required DateTime createdAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        builderVersion = requireNonEmpty(builderVersion, 'builderVersion'),
        featureSchemaVersion = requireNonEmpty(
          featureSchemaVersion,
          'featureSchemaVersion',
        ),
        labelSchemaVersion = requireNonEmpty(
          labelSchemaVersion,
          'labelSchemaVersion',
        ),
        splitSeedVersion = requireNonEmpty(
          splitSeedVersion,
          'splitSeedVersion',
        ),
        sourceWatermark = requireNonEmpty(
          sourceWatermark,
          'sourceWatermark',
        ),
        splitCounts = freezeNonNegativeCounts(splitCounts, 'splitCounts'),
        consentSnapshot = freezeJsonObject(
          consentSnapshot,
          'consentSnapshot',
        ),
        qualityReport = freezeJsonObject(qualityReport, 'qualityReport'),
        manifestHashSha256 = requireSha256(
          manifestHashSha256,
          'manifestHashSha256',
        ),
        createdAt = requireUtc(createdAt, 'createdAt');

  final String id;
  final String userId;
  final TrainingTaskType taskType;
  final String builderVersion;
  final String featureSchemaVersion;
  final String labelSchemaVersion;
  final String splitSeedVersion;
  final String sourceWatermark;
  final Map<String, int> splitCounts;
  final Map<String, Object?> consentSnapshot;
  final Map<String, Object?> qualityReport;
  final String manifestHashSha256;
  final DateTime createdAt;
}

final class ModelVersion {
  ModelVersion({
    required String id,
    required String userId,
    required this.taskType,
    required String baseModelVersion,
    required String featureSchemaVersion,
    required String labelSchemaVersion,
    required this.activationStatus,
    required Map<String, Object?> baselineMetrics,
    required Map<String, Object?> personalizedMetrics,
    required DateTime createdAt,
    String? localCheckpointRelativePath,
    DateTime? invalidatedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        baseModelVersion = requireNonEmpty(
          baseModelVersion,
          'baseModelVersion',
        ),
        featureSchemaVersion = requireNonEmpty(
          featureSchemaVersion,
          'featureSchemaVersion',
        ),
        labelSchemaVersion = requireNonEmpty(
          labelSchemaVersion,
          'labelSchemaVersion',
        ),
        localCheckpointRelativePath = _nullableRelativePath(
          localCheckpointRelativePath,
          'localCheckpointRelativePath',
        ),
        baselineMetrics = freezeJsonObject(
          baselineMetrics,
          'baselineMetrics',
        ),
        personalizedMetrics = freezeJsonObject(
          personalizedMetrics,
          'personalizedMetrics',
        ),
        createdAt = requireUtc(createdAt, 'createdAt'),
        invalidatedAt = requireNullableUtc(invalidatedAt, 'invalidatedAt') {
    if ((activationStatus == ModelActivationStatus.invalidated) !=
        (this.invalidatedAt != null)) {
      throw ArgumentError(
        'invalidated models require invalidatedAt and other states forbid it',
      );
    }
    if (this.invalidatedAt?.isBefore(this.createdAt) == true) {
      throw ArgumentError('invalidatedAt must not be before createdAt');
    }
  }

  final String id;
  final String userId;
  final TrainingTaskType taskType;
  final String baseModelVersion;
  final String featureSchemaVersion;
  final String labelSchemaVersion;
  final String? localCheckpointRelativePath;
  final ModelActivationStatus activationStatus;
  final Map<String, Object?> baselineMetrics;
  final Map<String, Object?> personalizedMetrics;
  final DateTime createdAt;
  final DateTime? invalidatedAt;
}

final class TrainingRun {
  TrainingRun({
    required String id,
    required String userId,
    required String modelVersionId,
    required String datasetManifestId,
    required this.status,
    required int sampleCount,
    required int trainingSteps,
    required Map<String, Object?> metrics,
    required Map<String, Object?> runtimeMetadata,
    required DateTime startedAt,
    DateTime? completedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        modelVersionId = requireUuid(modelVersionId, 'modelVersionId'),
        datasetManifestId = requireUuid(
          datasetManifestId,
          'datasetManifestId',
        ),
        sampleCount = requireNonNegativeInt(sampleCount, 'sampleCount'),
        trainingSteps = requireNonNegativeInt(trainingSteps, 'trainingSteps'),
        metrics = freezeJsonObject(metrics, 'metrics'),
        runtimeMetadata = freezeJsonObject(
          runtimeMetadata,
          'runtimeMetadata',
        ),
        startedAt = requireUtc(startedAt, 'startedAt'),
        completedAt = requireNullableUtc(completedAt, 'completedAt') {
    if (this.completedAt?.isBefore(this.startedAt) == true) {
      throw ArgumentError('completedAt must not be before startedAt');
    }
  }

  final String id;
  final String userId;
  final String modelVersionId;
  final String datasetManifestId;
  final TrainingRunStatus status;
  final int sampleCount;
  final int trainingSteps;
  final Map<String, Object?> metrics;
  final Map<String, Object?> runtimeMetadata;
  final DateTime startedAt;
  final DateTime? completedAt;
}

final class TrainingRunExample {
  TrainingRunExample({
    required String trainingRunId,
    required String trainingExampleId,
  })  : trainingRunId = requireUuid(trainingRunId, 'trainingRunId'),
        trainingExampleId = requireUuid(
          trainingExampleId,
          'trainingExampleId',
        );

  final String trainingRunId;
  final String trainingExampleId;
}

String? _nullableUuid(String? value, String fieldName) {
  return value == null ? null : requireUuid(value, fieldName);
}

String? _nullableRelativePath(String? value, String fieldName) {
  return value == null ? null : requireRelativePath(value, fieldName);
}
