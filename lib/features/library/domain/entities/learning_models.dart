import 'domain_validation.dart';
import 'library_enums.dart';

final class LearningEvent {
  LearningEvent({
    required String id,
    required String userId,
    required String sessionId,
    required this.eventType,
    required String schedulerVersion,
    required DateTime occurredAt,
    required DateTime recordedAt,
    String? vocabAnnotationId,
    String? detectionId,
    String? photoNoteId,
    String? answerNormalized,
    this.isCorrect,
    int? responseTimeMs,
    int? hintCount,
    int? attemptNumber,
    double? masteryBefore,
    double? masteryAfter,
    String? modelVersionId,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        vocabAnnotationId = _nullableUuid(
          vocabAnnotationId,
          'vocabAnnotationId',
        ),
        detectionId = _nullableUuid(detectionId, 'detectionId'),
        photoNoteId = _nullableUuid(photoNoteId, 'photoNoteId'),
        sessionId = requireUuid(sessionId, 'sessionId'),
        answerNormalized = _nullableNonEmpty(
          answerNormalized,
          'answerNormalized',
        ),
        responseTimeMs = responseTimeMs == null
            ? null
            : requireNonNegativeInt(responseTimeMs, 'responseTimeMs'),
        hintCount = hintCount == null
            ? null
            : requireNonNegativeInt(hintCount, 'hintCount'),
        attemptNumber = attemptNumber == null
            ? null
            : requireNonNegativeInt(attemptNumber, 'attemptNumber'),
        masteryBefore = masteryBefore == null
            ? null
            : requireNonNegativeDouble(masteryBefore, 'masteryBefore'),
        masteryAfter = masteryAfter == null
            ? null
            : requireNonNegativeDouble(masteryAfter, 'masteryAfter'),
        schedulerVersion = requireNonEmpty(
          schedulerVersion,
          'schedulerVersion',
        ),
        modelVersionId = _nullableUuid(modelVersionId, 'modelVersionId'),
        occurredAt = requireUtc(occurredAt, 'occurredAt'),
        recordedAt = requireUtc(recordedAt, 'recordedAt') {
    if (this.vocabAnnotationId == null && this.detectionId == null) {
      throw ArgumentError(
        'a learning event requires vocabAnnotationId or detectionId',
      );
    }
    if (this.recordedAt.isBefore(this.occurredAt)) {
      throw ArgumentError('recordedAt must not be before occurredAt');
    }
  }

  final String id;
  final String userId;
  final String? vocabAnnotationId;
  final String? detectionId;
  final String? photoNoteId;
  final String sessionId;
  final LearningEventType eventType;
  final String? answerNormalized;
  final bool? isCorrect;
  final int? responseTimeMs;
  final int? hintCount;
  final int? attemptNumber;
  final double? masteryBefore;
  final double? masteryAfter;
  final String schedulerVersion;
  final String? modelVersionId;
  final DateTime occurredAt;
  final DateTime recordedAt;
}

final class SrsProgress {
  SrsProgress({
    required String userId,
    required String vocabKey,
    required double masteryLevel,
    required int reviewCount,
    required DateTime nextReviewAt,
    required String schedulerVersion,
    required DateTime updatedAt,
    DateTime? lastReviewedAt,
  })  : userId = requireUuid(userId, 'userId'),
        vocabKey = requireNonEmpty(vocabKey, 'vocabKey'),
        masteryLevel = requireNonNegativeDouble(
          masteryLevel,
          'masteryLevel',
        ),
        reviewCount = requireNonNegativeInt(reviewCount, 'reviewCount'),
        lastReviewedAt = requireNullableUtc(
          lastReviewedAt,
          'lastReviewedAt',
        ),
        nextReviewAt = requireUtc(nextReviewAt, 'nextReviewAt'),
        schedulerVersion = requireNonEmpty(
          schedulerVersion,
          'schedulerVersion',
        ),
        updatedAt = requireUtc(updatedAt, 'updatedAt');

  final String userId;
  final String vocabKey;
  final double masteryLevel;
  final int reviewCount;
  final DateTime? lastReviewedAt;
  final DateTime nextReviewAt;
  final String schedulerVersion;
  final DateTime updatedAt;
}

String? _nullableNonEmpty(String? value, String fieldName) {
  return value == null ? null : requireNonEmpty(value, fieldName);
}

String? _nullableUuid(String? value, String fieldName) {
  return value == null ? null : requireUuid(value, fieldName);
}
