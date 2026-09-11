import 'domain_validation.dart';
import 'library_enums.dart';

final class PhotoNote {
  PhotoNote({
    required String id,
    required String userId,
    required String mediaAssetId,
    required String title,
    required String templateId,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.syncStatus,
    String? primaryScanRunId,
    String? emoji,
    DateTime? deletedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        mediaAssetId = requireUuid(mediaAssetId, 'mediaAssetId'),
        primaryScanRunId = primaryScanRunId == null
            ? null
            : requireUuid(primaryScanRunId, 'primaryScanRunId'),
        title = requireNonEmpty(title, 'title'),
        emoji = emoji?.trim().isEmpty == true ? null : emoji?.trim(),
        templateId = requireNonEmpty(templateId, 'templateId'),
        createdAt = requireUtc(createdAt, 'createdAt'),
        updatedAt = requireUtc(updatedAt, 'updatedAt'),
        deletedAt = requireNullableUtc(deletedAt, 'deletedAt') {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt');
    }
  }

  final String id;
  final String userId;
  final String mediaAssetId;
  final String? primaryScanRunId;
  final String title;
  final String? emoji;
  final String templateId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  bool get isDeleted => deletedAt != null;
}
