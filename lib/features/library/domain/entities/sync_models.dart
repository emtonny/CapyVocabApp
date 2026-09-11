import 'domain_validation.dart';
import 'library_enums.dart';

final class SyncOperation {
  SyncOperation({
    required String operationId,
    required String userId,
    required this.entityType,
    required String entityId,
    required this.operationType,
    required Map<String, Object?> payloadJson,
    required Iterable<String> dependencyIds,
    required this.state,
    required int attemptCount,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? nextAttemptAt,
    String? lastErrorCode,
  })  : operationId = requireUuid(operationId, 'operationId'),
        userId = requireUuid(userId, 'userId'),
        entityId = requireUuid(entityId, 'entityId'),
        payloadJson = freezeJsonObject(payloadJson, 'payloadJson'),
        dependencyIds = freezeUuidList(dependencyIds, 'dependencyIds'),
        attemptCount = requireNonNegativeInt(attemptCount, 'attemptCount'),
        nextAttemptAt = requireNullableUtc(nextAttemptAt, 'nextAttemptAt'),
        lastErrorCode = _nullableNonEmpty(lastErrorCode, 'lastErrorCode'),
        createdAt = requireUtc(createdAt, 'createdAt'),
        updatedAt = requireUtc(updatedAt, 'updatedAt') {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt');
    }
    if (this.dependencyIds.contains(this.operationId)) {
      throw ArgumentError('an operation cannot depend on itself');
    }
    if (this.dependencyIds.toSet().length != this.dependencyIds.length) {
      throw ArgumentError('dependencyIds must not contain duplicates');
    }
  }

  final String operationId;
  final String userId;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operationType;
  final Map<String, Object?> payloadJson;
  final List<String> dependencyIds;
  final SyncOperationState state;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastErrorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class SyncTombstone {
  SyncTombstone({
    required String id,
    required String userId,
    required this.entityType,
    required String entityId,
    required int deletionVersion,
    required DateTime deletedAt,
    required this.remotePurgeCompleted,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        entityId = requireUuid(entityId, 'entityId'),
        deletionVersion = _requirePositive(
          deletionVersion,
          'deletionVersion',
        ),
        deletedAt = requireUtc(deletedAt, 'deletedAt');

  final String id;
  final String userId;
  final SyncEntityType entityType;
  final String entityId;
  final int deletionVersion;
  final DateTime deletedAt;
  final bool remotePurgeCompleted;
}

String? _nullableNonEmpty(String? value, String fieldName) {
  return value == null ? null : requireNonEmpty(value, fieldName);
}

int _requirePositive(int value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError.value(value, fieldName, 'must be greater than zero');
  }
  return value;
}
