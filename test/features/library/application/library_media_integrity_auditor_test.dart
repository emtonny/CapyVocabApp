import 'package:capy_vocab/features/library/application/library_media_integrity_auditor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports orphan and missing media without mutating inventory', () async {
    final inventory = _FakeInventory({
      'capy_scans/referenced.jpg',
      'capy_scans/orphan.jpg',
    });
    final auditor = LibraryMediaIntegrityAuditor(
      loadReferencedPaths: () async => {
        r'capy_scans\referenced.jpg',
        'capy_scans/missing.jpg',
        './capy_scans/referenced.jpg',
      },
      inventory: inventory,
    );

    final report = await auditor.audit();

    expect(report.orphanRelativePaths, {'capy_scans/orphan.jpg'});
    expect(report.missingRelativePaths, {'capy_scans/missing.jpg'});
    expect(report.isHealthy, isFalse);
    expect(
      inventory.paths,
      {'capy_scans/referenced.jpg', 'capy_scans/orphan.jpg'},
      reason: 'an integrity audit must not mutate local media',
    );
  });

  test('healthy inventory returns empty immutable findings', () async {
    final auditor = LibraryMediaIntegrityAuditor(
      loadReferencedPaths: () async => {'capy_scans/scan.jpg'},
      inventory: _FakeInventory({'capy_scans/scan.jpg'}),
    );

    final report = await auditor.audit();

    expect(report.isHealthy, isTrue);
    expect(report.orphanRelativePaths, isEmpty);
    expect(report.missingRelativePaths, isEmpty);
    expect(
      () => report.orphanRelativePaths.add('capy_scans/new.jpg'),
      throwsUnsupportedError,
    );
  });
}

final class _FakeInventory implements LibraryMediaInventory {
  _FakeInventory(Set<String> paths) : paths = Set.of(paths);

  final Set<String> paths;

  @override
  Future<bool> exists(String relativePath) async =>
      paths.contains(relativePath);

  @override
  Future<Set<String>> listManagedRelativePaths() async => Set.of(paths);
}
