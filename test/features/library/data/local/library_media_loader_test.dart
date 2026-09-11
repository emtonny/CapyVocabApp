import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/application/library_media_loader.dart';
import 'package:capy_vocab/features/library/data/local/library_media_loader_factory_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late IoLibraryMediaLoader loader;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('library_media_loader_');
    loader = IoLibraryMediaLoader(
      documentsDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('reads persisted media relative to app documents', () async {
    final directory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}capy_scans',
    );
    await directory.create();
    final file = File(
      '${directory.path}${Platform.pathSeparator}saved.jpg',
    );
    await file.writeAsBytes([1, 2, 3, 4]);

    final bytes = await loader.readBytes('capy_scans/saved.jpg');

    expect(bytes, Uint8List.fromList([1, 2, 3, 4]));
    expect(await loader.sizeBytes('capy_scans/saved.jpg'), 4);
  });

  test('rejects parent traversal before reading the filesystem', () async {
    await expectLater(
      loader.readBytes('../outside.jpg'),
      throwsA(isA<LibraryMediaLoadException>()),
    );
  });

  test('wraps a missing local image in a stable Library error', () async {
    await expectLater(
      loader.readBytes('capy_scans/missing.jpg'),
      throwsA(
        isA<LibraryMediaLoadException>().having(
          (error) => error.message,
          'message',
          'Không thể đọc ảnh đã lưu trên thiết bị.',
        ),
      ),
    );
    await expectLater(
      loader.sizeBytes('capy_scans/missing.jpg'),
      throwsA(
        isA<LibraryMediaLoadException>().having(
          (error) => error.message,
          'message',
          'Không thể đọc dung lượng ảnh trên thiết bị.',
        ),
      ),
    );
  });
}
