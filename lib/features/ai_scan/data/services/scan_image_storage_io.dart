import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'scan_image_storage.dart';

ScanImageStorage createScanImageStorage() => IoScanImageStorage();

typedef ScanDocumentsDirectoryProvider = Future<Directory> Function();

class IoScanImageStorage implements ScanImageStorage {
  IoScanImageStorage({
    ScanDocumentsDirectoryProvider? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final ScanDocumentsDirectoryProvider _documentsDirectory;

  @override
  Future<void> delete(String localPath) async {
    try {
      final documentsDirectory = await _documentsDirectory();
      final scanDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}capy_scans',
      );
      final file = File(localPath);
      if (_comparablePath(file.parent.absolute.path) !=
          _comparablePath(scanDirectory.absolute.path)) {
        throw ArgumentError.value(
          localPath,
          'localPath',
          'must be a direct child of the managed scan directory',
        );
      }
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImageStorageException(
          'Không thể dọn ảnh quét chưa được lưu.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<String> saveJpeg(Uint8List bytes) async {
    try {
      final documentsDirectory = await _documentsDirectory();
      final scanDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}capy_scans',
      );
      await scanDirectory.create(recursive: true);
      final filename = 'capy_scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final file = File(
        '${scanDirectory.path}${Platform.pathSeparator}$filename',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImageStorageException(
          'Không thể lưu ảnh đã chọn. Vui lòng thử lại.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  String _comparablePath(String path) {
    return Platform.isWindows ? path.toLowerCase() : path;
  }

  @override
  Future<Uint8List> readBytes(String localPath) async {
    try {
      return await File(localPath).readAsBytes();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        ScanImageStorageException(
          'Không thể đọc ảnh đã lưu. Vui lòng thử lại.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
