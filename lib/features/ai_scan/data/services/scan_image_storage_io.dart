import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'scan_image_storage.dart';

ScanImageStorage createScanImageStorage() => IoScanImageStorage();

class IoScanImageStorage implements ScanImageStorage {
  @override
  Future<String> saveJpeg(Uint8List bytes) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
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
  }

  @override
  Future<Uint8List> readBytes(String localPath) {
    return File(localPath).readAsBytes();
  }
}
