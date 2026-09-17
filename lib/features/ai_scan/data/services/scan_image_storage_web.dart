import 'dart:typed_data';

import '../../../library/data/local/library_web_media_blob_store.dart';
import 'scan_image_storage.dart';

ScanImageStorage createScanImageStorage() => WebScanImageStorage();

final class WebScanImageStorage implements ScanImageStorage {
  @override
  Future<String> saveJpeg(Uint8List bytes) async {
    final path =
        'capy_scans/capy_scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    try {
      await libraryWebMediaBlobStore.write(path, bytes);
      return path;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImageStorageException(
          'Không thể lưu ảnh trong trình duyệt.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<Uint8List> readBytes(String localPath) async {
    try {
      return await libraryWebMediaBlobStore.read(localPath);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImageStorageException(
          'Không thể đọc ảnh đã lưu trong trình duyệt.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> delete(String localPath) async {
    try {
      await libraryWebMediaBlobStore.delete(localPath);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImageStorageException(
          'Không thể dọn ảnh quét trong trình duyệt.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
