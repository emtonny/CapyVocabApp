import 'dart:typed_data';

import 'scan_image_storage.dart';

ScanImageStorage createScanImageStorage() => MemoryScanImageStorage();

class MemoryScanImageStorage implements ScanImageStorage {
  final _images = <String, Uint8List>{};

  @override
  Future<String> saveJpeg(Uint8List bytes) async {
    final key =
        'memory://capy_scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    _images[key] = Uint8List.fromList(bytes);
    return key;
  }

  @override
  Future<Uint8List> readBytes(String localPath) async {
    final bytes = _images[localPath];
    if (bytes == null) {
      throw const ScanImageStorageException('Không tìm thấy ảnh đã quét.');
    }
    return Uint8List.fromList(bytes);
  }
}
