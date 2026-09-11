import 'dart:typed_data';

/// Reads an app-private Library media file by its persisted relative path.
abstract interface class LibraryMediaLoader {
  Future<Uint8List> readBytes(String relativePath);

  /// Returns the real on-device byte count without loading the image payload.
  Future<int> sizeBytes(String relativePath);
}

final class LibraryMediaLoadException implements Exception {
  const LibraryMediaLoadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'LibraryMediaLoadException: $message';
}
