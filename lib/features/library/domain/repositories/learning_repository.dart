import '../entities/domain_validation.dart';
import '../entities/learning_models.dart';

final class LearningEventQuery {
  LearningEventQuery({
    required String userId,
    DateTime? occurredFromInclusive,
    DateTime? occurredToExclusive,
    this.limit = 500,
  })  : userId = requireUuid(userId, 'userId'),
        occurredFromInclusive = requireNullableUtc(
          occurredFromInclusive,
          'occurredFromInclusive',
        ),
        occurredToExclusive = requireNullableUtc(
          occurredToExclusive,
          'occurredToExclusive',
        ) {
    if (limit <= 0 || limit > 5000) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 5000');
    }
    if (this.occurredFromInclusive != null &&
        this.occurredToExclusive != null &&
        !this.occurredFromInclusive!.isBefore(this.occurredToExclusive!)) {
      throw ArgumentError(
          'occurredFromInclusive must be before occurredToExclusive');
    }
  }

  final String userId;
  final DateTime? occurredFromInclusive;
  final DateTime? occurredToExclusive;
  final int limit;
}

abstract interface class LearningRepository {
  /// Implementations must reject updates/deletes: learning events are append-only.
  Future<void> appendEvent(LearningEvent event);

  Future<List<LearningEvent>> getEvents(LearningEventQuery query);

  Stream<List<SrsProgress>> watchSrsProgress({required String userId});

  Future<SrsProgress?> getSrsProgress({
    required String userId,
    required String vocabKey,
  });

  Future<void> saveSrsProgress(SrsProgress progress);
}
