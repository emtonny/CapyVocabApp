import 'dart:typed_data';

abstract interface class ScanImageStorage {
  Future<String> saveJpeg(Uint8List bytes);

  Future<Uint8List> readBytes(String localPath);
}

class ScanImageStorageException implements Exception {
  const ScanImageStorageException(this.message);

  final String message;

  @override
  String toString() => 'ScanImageStorageException: $message';
}
