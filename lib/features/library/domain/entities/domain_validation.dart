import 'dart:collection';

String requireNonEmpty(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  return normalized;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String requireUuid(String value, String fieldName) {
  final normalized = requireNonEmpty(value, fieldName).toLowerCase();
  if (!_uuidPattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, fieldName, 'must be a UUID');
  }
  return normalized;
}

final RegExp _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

String requireSha256(String value, String fieldName) {
  final normalized = requireNonEmpty(value, fieldName).toLowerCase();
  if (!_sha256Pattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, fieldName, 'must be a SHA-256 hex digest');
  }
  return normalized;
}

final RegExp _uriSchemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

String requireRelativePath(String value, String fieldName) {
  final normalized = requireNonEmpty(value, fieldName).replaceAll('\\', '/');
  final segments = normalized.split('/');
  if (normalized.startsWith('/') ||
      _uriSchemePattern.hasMatch(normalized) ||
      segments.any((segment) => segment == '..')) {
    throw ArgumentError.value(
      value,
      fieldName,
      'must be a safe relative path without a URI scheme or parent traversal',
    );
  }
  return normalized;
}

int requireNonNegativeInt(int value, String fieldName) {
  if (value < 0) {
    throw ArgumentError.value(value, fieldName, 'must not be negative');
  }
  return value;
}

double requireUnitInterval(double value, String fieldName) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, fieldName, 'must be between 0 and 1');
  }
  return value;
}

double requireNonNegativeDouble(double value, String fieldName) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
        value, fieldName, 'must be finite and non-negative');
  }
  return value;
}

DateTime requireUtc(DateTime value, String fieldName) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, fieldName, 'must be in UTC');
  }
  return value;
}

DateTime? requireNullableUtc(DateTime? value, String fieldName) {
  return value == null ? null : requireUtc(value, fieldName);
}

List<String> freezeStringList(Iterable<String> values, String fieldName) {
  return List<String>.unmodifiable(
    values.map((value) => requireNonEmpty(value, fieldName)),
  );
}

List<String> freezeUuidList(Iterable<String> values, String fieldName) {
  return List<String>.unmodifiable(
    values.map((value) => requireUuid(value, fieldName)),
  );
}

Map<String, Object?> freezeJsonObject(
  Map<String, Object?> value,
  String fieldName,
) {
  return _freezeJsonValue(value, fieldName) as Map<String, Object?>;
}

Map<String, int> freezeNonNegativeCounts(
  Map<String, int> value,
  String fieldName,
) {
  return UnmodifiableMapView<String, int>(
    value.map(
      (key, count) => MapEntry(
        requireNonEmpty(key, '$fieldName key'),
        requireNonNegativeInt(count, '$fieldName[$key]'),
      ),
    ),
  );
}

Object? _freezeJsonValue(Object? value, String fieldName) {
  if (value == null || value is String || value is bool) {
    return value;
  }
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        fieldName,
        'must contain finite JSON numbers only',
      );
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.map((item) => _freezeJsonValue(item, fieldName)),
    );
  }
  if (value is Map<String, Object?>) {
    return UnmodifiableMapView<String, Object?>(
      value.map(
        (key, item) => MapEntry(
          requireNonEmpty(key, '$fieldName key'),
          _freezeJsonValue(item, fieldName),
        ),
      ),
    );
  }
  throw ArgumentError.value(
    value,
    fieldName,
    'must contain JSON-compatible values only',
  );
}
