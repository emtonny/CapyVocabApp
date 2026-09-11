import 'dart:io';
import 'dart:typed_data';

import 'package:capy_vocab/features/library/data/local/library_media_writer_factory_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late IoLibraryLocalMediaWriter writer;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('library_media_writer_');
    writer = IoLibraryLocalMediaWriter(
      documentsDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('writes cloud bytes atomically inside app-private storage', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    await writer.writeAtomically(
      relativePath: 'capy_scans/restored.jpg',
      bytes: bytes,
    );

    final destination = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}capy_scans'
      '${Platform.pathSeparator}restored.jpg',
    );
    expect(await destination.readAsBytes(), bytes);
    expect(await File('${destination.path}.download').exists(), isFalse);
  });

  test('does not overwrite an existing local copy', () async {
    final destination = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}capy_scans'
      '${Platform.pathSeparator}restored.jpg',
    );
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes([9, 9]);

    await writer.writeAtomically(
      relativePath: 'capy_scans/restored.jpg',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(await destination.readAsBytes(), [9, 9]);
  });

  test('rejects traversal and absolute paths before writing', () async {
    for (final path in ['../escape.jpg', r'C:\escape.jpg', '/escape.jpg']) {
      await expectLater(
        writer.writeAtomically(
          relativePath: path,
          bytes: Uint8List.fromList([1]),
        ),
        throwsArgumentError,
      );
    }
    expect(await temporaryDirectory.list(recursive: true).toList(), isEmpty);
  });
}
