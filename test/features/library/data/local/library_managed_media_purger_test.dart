import 'dart:io';

import 'package:capy_vocab/features/library/data/local/library_managed_media_purger_factory_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late IoLibraryManagedMediaPurger purger;

  setUp(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('library_media_purger_');
    purger = IoLibraryManagedMediaPurger(
      documentsDirectory: () async => temporaryDirectory,
    );
  });

  tearDown(() => temporaryDirectory.delete(recursive: true));

  test('deletes managed files idempotently and preserves files outside scans',
      () async {
    final scans = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}capy_scans',
    );
    await scans.create();
    final managed = File(
      '${scans.path}${Platform.pathSeparator}delete.jpg',
    );
    await managed.writeAsBytes([1, 2, 3]);
    final outside = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}keep.jpg',
    );
    await outside.writeAsBytes([4, 5, 6]);

    await purger.deleteAll(const ['capy_scans/delete.jpg']);
    await purger.deleteAll(const ['capy_scans/delete.jpg']);

    expect(await managed.exists(), isFalse);
    expect(await outside.exists(), isTrue);
  });

  test('rejects traversal and paths outside the managed directory', () async {
    await expectLater(
      purger.deleteAll(const ['../escape.jpg']),
      throwsArgumentError,
    );
    await expectLater(
      purger.deleteAll(const ['other/file.jpg']),
      throwsArgumentError,
    );
  });
}
