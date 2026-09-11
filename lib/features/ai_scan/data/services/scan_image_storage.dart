import 'dart:typed_data';

abstract interface class ScanImageStorage {
  Future<String> saveJpeg(Uint8List bytes);

  Future<Uint8List> readBytes(String localPath);

  /// Removes an image that was written but never committed to the Library.
  Future<void> delete(String localPath);
}

class ScanImageStorageException implements Exception {
  const ScanImageStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final rootCause = cause;
    return rootCause == null
        ? 'ScanImageStorageException: $message'
        : 'ScanImageStorageException: $message Cause: $rootCause';
  }
}
