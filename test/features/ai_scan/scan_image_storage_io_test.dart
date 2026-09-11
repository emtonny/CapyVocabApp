import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory documents;
  late IoScanImageStorage storage;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('scan_storage_');
    storage = IoScanImageStorage(
      documentsDirectory: () async => documents,
    );
  });

  tearDown(() => documents.delete(recursive: true));

  test('deletes an uncommitted managed image idempotently', () async {
    final localPath = await storage.saveJpeg(Uint8List.fromList([1, 2, 3]));
    expect(await File(localPath).exists(), isTrue);

    await storage.delete(localPath);
    await storage.delete(localPath);

    expect(await File(localPath).exists(), isFalse);
  });

  test('refuses to delete a file outside the managed scan directory', () async {
    final outside = File(
      '${documents.path}${Platform.pathSeparator}outside.jpg',
    );
    await outside.writeAsBytes([1]);

    await expectLater(
      storage.delete(outside.path),
      throwsA(isA<ScanImageStorageException>()),
    );

    expect(await outside.exists(), isTrue);
  });
}
