import 'dart:io';

import 'package:capy_vocab/features/library/data/local/library_media_inventory_factory_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory documents;
  late IoLibraryMediaInventory inventory;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('media_inventory_');
    inventory = IoLibraryMediaInventory(
      documentsDirectory: () async => documents,
    );
  });

  tearDown(() => documents.delete(recursive: true));

  test('lists only direct app-managed scan files and checks references',
      () async {
    final scans = Directory(
      '${documents.path}${Platform.pathSeparator}capy_scans',
    );
    await scans.create();
    final image = File('${scans.path}${Platform.pathSeparator}scan.jpg');
    await image.writeAsBytes([1, 2, 3]);
    await Directory('${scans.path}${Platform.pathSeparator}nested').create();
    await File('${documents.path}${Platform.pathSeparator}outside.jpg')
        .writeAsBytes([4]);

    expect(await inventory.listManagedRelativePaths(), {'capy_scans/scan.jpg'});
    expect(await inventory.exists('capy_scans/scan.jpg'), isTrue);
    expect(await inventory.exists('capy_scans/missing.jpg'), isFalse);
  });

  test('rejects paths escaping the app documents directory', () async {
    await expectLater(
      inventory.exists('../outside.jpg'),
      throwsArgumentError,
    );
  });

  test('quarantines, restores and explicitly deletes direct scan files',
      () async {
    final scans = Directory(
      '${documents.path}${Platform.pathSeparator}capy_scans',
    );
    await scans.create();
    await File('${scans.path}${Platform.pathSeparator}orphan.jpg')
        .writeAsBytes([1, 2, 3]);
    final quarantinedAt = DateTime.utc(2026, 9, 8, 12);

    await inventory.quarantine(
      managedRelativePath: 'capy_scans/orphan.jpg',
      quarantinedAt: quarantinedAt,
    );

    expect(await inventory.listManagedRelativePaths(), isEmpty);
    var quarantined = await inventory.listQuarantined();
    expect(quarantined, hasLength(1));
    expect(quarantined.single.relativePath, 'capy_quarantine/orphan.jpg');
    expect(quarantined.single.quarantinedAt, quarantinedAt);

    await inventory.restore('capy_quarantine/orphan.jpg');
    expect(await inventory.listManagedRelativePaths(), {
      'capy_scans/orphan.jpg',
    });

    await inventory.quarantine(
      managedRelativePath: 'capy_scans/orphan.jpg',
      quarantinedAt: quarantinedAt,
    );
    await inventory.deleteQuarantined('capy_quarantine/orphan.jpg');
    quarantined = await inventory.listQuarantined();
    expect(quarantined, isEmpty);
  });

  test('purges only quarantine files whose confirmed retention has expired',
      () async {
    final scans = Directory(
      '${documents.path}${Platform.pathSeparator}capy_scans',
    );
    await scans.create();
    await File('${scans.path}${Platform.pathSeparator}old.jpg')
        .writeAsBytes([1]);
    await File('${scans.path}${Platform.pathSeparator}new.jpg')
        .writeAsBytes([2]);
    final now = DateTime.utc(2026, 9, 8, 12);
    await inventory.quarantine(
      managedRelativePath: 'capy_scans/old.jpg',
      quarantinedAt: now.subtract(const Duration(days: 31)),
    );
    await inventory.quarantine(
      managedRelativePath: 'capy_scans/new.jpg',
      quarantinedAt: now.subtract(const Duration(days: 29)),
    );

    expect(
      await inventory.purgeExpired(
        now: now,
        retention: const Duration(days: 30),
      ),
      1,
    );
    expect(
      (await inventory.listQuarantined()).map((entry) => entry.relativePath),
      ['capy_quarantine/new.jpg'],
    );
  });

  test('recovery mutations reject non-direct and wrong-directory paths',
      () async {
    await expectLater(
      inventory.quarantine(
        managedRelativePath: 'capy_scans/nested/image.jpg',
        quarantinedAt: DateTime.utc(2026, 9, 8),
      ),
      throwsArgumentError,
    );
    await expectLater(
      inventory.restore('capy_scans/image.jpg'),
      throwsArgumentError,
    );
    await expectLater(
      inventory.deleteQuarantined('../image.jpg'),
      throwsArgumentError,
    );
  });
}
