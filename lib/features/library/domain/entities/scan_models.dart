import 'domain_validation.dart';
import 'library_enums.dart';
import 'normalized_bounding_box.dart';

final class ScanRun {
  ScanRun({
    required String id,
    required String userId,
    required String mediaAssetId,
    required String requestId,
    required String provider,
    required String modelName,
    required String promptVersion,
    required String responseSchemaVersion,
    required String preprocessingVersion,
    required this.status,
    required DateTime startedAt,
    String? modelVersion,
    String? serviceTier,
    Map<String, Object?>? rawResponseJson,
    String? responseHashSha256,
    String? errorCode,
    DateTime? completedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        mediaAssetId = requireUuid(mediaAssetId, 'mediaAssetId'),
        requestId = requireNonEmpty(requestId, 'requestId'),
        provider = requireNonEmpty(provider, 'provider'),
        modelName = requireNonEmpty(modelName, 'modelName'),
        modelVersion = _nullableNonEmpty(modelVersion, 'modelVersion'),
        serviceTier = _nullableNonEmpty(serviceTier, 'serviceTier'),
        promptVersion = requireNonEmpty(promptVersion, 'promptVersion'),
        responseSchemaVersion = requireNonEmpty(
          responseSchemaVersion,
          'responseSchemaVersion',
        ),
        preprocessingVersion = requireNonEmpty(
          preprocessingVersion,
          'preprocessingVersion',
        ),
        rawResponseJson = rawResponseJson == null
            ? null
            : freezeJsonObject(rawResponseJson, 'rawResponseJson'),
        responseHashSha256 = _nullableSha256(
          responseHashSha256,
          'responseHashSha256',
        ),
        errorCode = _nullableNonEmpty(errorCode, 'errorCode'),
        startedAt = requireUtc(startedAt, 'startedAt'),
        completedAt = requireNullableUtc(completedAt, 'completedAt') {
    if (this.completedAt?.isBefore(this.startedAt) == true) {
      throw ArgumentError('completedAt must not be before startedAt');
    }
    if (status == ScanRunStatus.succeeded &&
        (this.rawResponseJson == null || this.responseHashSha256 == null)) {
      throw ArgumentError(
        'a succeeded scan requires rawResponseJson and responseHashSha256',
      );
    }
  }

  final String id;
  final String userId;
  final String mediaAssetId;
  final String requestId;
  final String provider;
  final String modelName;
  final String? modelVersion;
  final String? serviceTier;
  final String promptVersion;
  final String responseSchemaVersion;
  final String preprocessingVersion;
  final Map<String, Object?>? rawResponseJson;
  final String? responseHashSha256;
  final ScanRunStatus status;
  final String? errorCode;
  final DateTime startedAt;
  final DateTime? completedAt;
}

final class VocabDetection {
  VocabDetection({
    required String id,
    required String scanRunId,
    required String wordRaw,
    required String wordNormalized,
    required int displayOrder,
    required DateTime createdAt,
    String? phonetic,
    String? meaningVi,
    String? partOfSpeech,
    String? exampleEn,
    String? exampleVi,
    this.boundingBox,
    double? confidence,
  })  : id = requireUuid(id, 'id'),
        scanRunId = requireUuid(scanRunId, 'scanRunId'),
        wordRaw = requireNonEmpty(wordRaw, 'wordRaw'),
        wordNormalized = requireNonEmpty(wordNormalized, 'wordNormalized'),
        phonetic = _nullableNonEmpty(phonetic, 'phonetic'),
        meaningVi = _nullableNonEmpty(meaningVi, 'meaningVi'),
        partOfSpeech = _nullableNonEmpty(partOfSpeech, 'partOfSpeech'),
        exampleEn = _nullableNonEmpty(exampleEn, 'exampleEn'),
        exampleVi = _nullableNonEmpty(exampleVi, 'exampleVi'),
        confidence = confidence == null
            ? null
            : requireUnitInterval(confidence, 'confidence'),
        displayOrder = requireNonNegativeInt(displayOrder, 'displayOrder'),
        createdAt = requireUtc(createdAt, 'createdAt');

  final String id;
  final String scanRunId;
  final String wordRaw;
  final String wordNormalized;
  final String? phonetic;
  final String? meaningVi;
  final String? partOfSpeech;
  final String? exampleEn;
  final String? exampleVi;
  final NormalizedBoundingBox? boundingBox;
  final double? confidence;
  final int displayOrder;
  final DateTime createdAt;
}

final class VocabAnnotation {
  VocabAnnotation({
    required String id,
    required String userId,
    required String detectionId,
    required this.source,
    required this.qualityStatus,
    required int revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? correctedWord,
    String? correctedPhonetic,
    String? correctedMeaningVi,
    this.correctedBoundingBox,
    DateTime? deletedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        detectionId = requireUuid(detectionId, 'detectionId'),
        correctedWord = _nullableNonEmpty(correctedWord, 'correctedWord'),
        correctedPhonetic = _nullableNonEmpty(
          correctedPhonetic,
          'correctedPhonetic',
        ),
        correctedMeaningVi = _nullableNonEmpty(
          correctedMeaningVi,
          'correctedMeaningVi',
        ),
        revision = _requirePositive(revision, 'revision'),
        createdAt = requireUtc(createdAt, 'createdAt'),
        updatedAt = requireUtc(updatedAt, 'updatedAt'),
        deletedAt = requireNullableUtc(deletedAt, 'deletedAt') {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt');
    }
    if (source == AnnotationSource.userCorrected &&
        this.correctedWord == null &&
        this.correctedPhonetic == null &&
        this.correctedMeaningVi == null &&
        correctedBoundingBox == null) {
      throw ArgumentError('a user correction requires at least one change');
    }
  }

  final String id;
  final String userId;
  final String detectionId;
  final AnnotationSource source;
  final AnnotationQualityStatus qualityStatus;
  final String? correctedWord;
  final String? correctedPhonetic;
  final String? correctedMeaningVi;
  final NormalizedBoundingBox? correctedBoundingBox;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
}

String? _nullableNonEmpty(String? value, String fieldName) {
  return value == null ? null : requireNonEmpty(value, fieldName);
}

String? _nullableSha256(String? value, String fieldName) {
  return value == null ? null : requireSha256(value, fieldName);
}

int _requirePositive(int value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError.value(value, fieldName, 'must be greater than zero');
  }
  return value;
}
