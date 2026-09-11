import 'domain_validation.dart';
import 'library_enums.dart';

final class MediaAsset {
  MediaAsset({
    required String id,
    required String userId,
    required String contentHashSha256,
    required String displayRelativePath,
    required String mimeType,
    required int width,
    required int height,
    required int orientation,
    required int byteSizeDisplay,
    required String preprocessingVersion,
    required this.captureSource,
    required DateTime createdAt,
    required this.syncStatus,
    String? originalRelativePath,
    String? modelInputRelativePath,
    String? remoteOriginalPath,
    String? remoteDisplayPath,
    int? byteSizeOriginal,
    DateTime? capturedAt,
    DateTime? deletedAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        contentHashSha256 = requireSha256(
          contentHashSha256,
          'contentHashSha256',
        ),
        originalRelativePath = _nullableRelativePath(
          originalRelativePath,
          'originalRelativePath',
        ),
        displayRelativePath = requireRelativePath(
          displayRelativePath,
          'displayRelativePath',
        ),
        modelInputRelativePath = _nullableRelativePath(
          modelInputRelativePath,
          'modelInputRelativePath',
        ),
        remoteOriginalPath = _nullableRelativePath(
          remoteOriginalPath,
          'remoteOriginalPath',
        ),
        remoteDisplayPath = _nullableRelativePath(
          remoteDisplayPath,
          'remoteDisplayPath',
        ),
        mimeType = requireNonEmpty(mimeType, 'mimeType'),
        width = _requirePositive(width, 'width'),
        height = _requirePositive(height, 'height'),
        orientation = requireNonNegativeInt(orientation, 'orientation'),
        byteSizeOriginal = byteSizeOriginal == null
            ? null
            : requireNonNegativeInt(byteSizeOriginal, 'byteSizeOriginal'),
        byteSizeDisplay = requireNonNegativeInt(
          byteSizeDisplay,
          'byteSizeDisplay',
        ),
        preprocessingVersion = requireNonEmpty(
          preprocessingVersion,
          'preprocessingVersion',
        ),
        capturedAt = requireNullableUtc(capturedAt, 'capturedAt'),
        createdAt = requireUtc(createdAt, 'createdAt'),
        deletedAt = requireNullableUtc(deletedAt, 'deletedAt');

  final String id;
  final String userId;
  final String contentHashSha256;
  final String? originalRelativePath;
  final String displayRelativePath;
  final String? modelInputRelativePath;
  final String? remoteOriginalPath;
  final String? remoteDisplayPath;
  final String mimeType;
  final int width;
  final int height;
  final int orientation;
  final int? byteSizeOriginal;
  final int byteSizeDisplay;
  final String preprocessingVersion;
  final CaptureSource captureSource;
  final DateTime? capturedAt;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;
}

String? _nullableRelativePath(String? value, String fieldName) {
  return value == null ? null : requireRelativePath(value, fieldName);
}

int _requirePositive(int value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError.value(value, fieldName, 'must be greater than zero');
  }
  return value;
}
