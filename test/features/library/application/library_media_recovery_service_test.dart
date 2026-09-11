import 'package:capy_vocab/features/library/application/library_media_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('re-audits before quarantining an orphan and exposes retention date',
      () async {
    final store = _FakeRecoveryStore({'capy_scans/orphan.jpg'});
    final referenced = <String>{};
    final service = LibraryMediaRecoveryService(
      loadReferencedPaths: () async => Set.of(referenced),
      store: store,
    );
    final now = DateTime.utc(2026, 9, 8, 12);

    await service.quarantineOrphan('capy_scans/orphan.jpg', now: now);
    final snapshot = await service.inspect();

    expect(snapshot.integrity.orphanRelativePaths, isEmpty);
    expect(snapshot.quarantined, hasLength(1));
    expect(snapshot.quarantined.single.purgeEligibleAt,
        DateTime.utc(2026, 10, 8, 12));
  });

  test('refuses stale orphan action after a database reference appears',
      () async {
    final store = _FakeRecoveryStore({'capy_scans/scan.jpg'});
    final referenced = <String>{};
    final service = LibraryMediaRecoveryService(
      loadReferencedPaths: () async => Set.of(referenced),
      store: store,
    );
    expect((await service.audit()).orphanRelativePaths, isNotEmpty);

    referenced.add('capy_scans/scan.jpg');

    await expectLater(
      service.quarantineOrphan(
        'capy_scans/scan.jpg',
        now: DateTime.utc(2026, 9, 8),
      ),
      throwsStateError,
    );
    expect(store.managed, contains('capy_scans/scan.jpg'));
    expect(store.quarantined, isEmpty);
  });
}

final class _FakeRecoveryStore implements LibraryMediaRecoveryStore {
  _FakeRecoveryStore(Set<String> paths) : managed = Set.of(paths);

  final Set<String> managed;
  final Map<String, DateTime> quarantined = {};

  @override
  Future<void> deleteQuarantined(String quarantinedRelativePath) async {
    quarantined.remove(quarantinedRelativePath);
  }

  @override
  Future<bool> exists(String relativePath) async =>
      managed.contains(relativePath);

  @override
  Future<Set<String>> listManagedRelativePaths() async => Set.of(managed);

  @override
  Future<List<QuarantinedLibraryMedia>> listQuarantined() async =>
      quarantined.entries
          .map((entry) => QuarantinedLibraryMedia(
                relativePath: entry.key,
                quarantinedAt: entry.value,
              ))
          .toList(growable: false);

  @override
  Future<int> purgeExpired({
    required DateTime now,
    required Duration retention,
  }) async {
    final expired = quarantined.entries
        .where((entry) => !entry.value.isAfter(now.subtract(retention)))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final path in expired) {
      quarantined.remove(path);
    }
    return expired.length;
  }

  @override
  Future<void> quarantine({
    required String managedRelativePath,
    required DateTime quarantinedAt,
  }) async {
    managed.remove(managedRelativePath);
    quarantined[managedRelativePath.replaceFirst(
        'capy_scans/', 'capy_quarantine/')] = quarantinedAt;
  }

  @override
  Future<void> restore(String quarantinedRelativePath) async {
    final date = quarantined.remove(quarantinedRelativePath);
    if (date == null) throw StateError('missing');
    managed.add(
      quarantinedRelativePath.replaceFirst('capy_quarantine/', 'capy_scans/'),
    );
  }
}
