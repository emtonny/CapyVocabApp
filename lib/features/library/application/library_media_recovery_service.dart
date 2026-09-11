import 'library_media_integrity_auditor.dart';

const libraryMediaQuarantineRetention = Duration(days: 30);

final class QuarantinedLibraryMedia {
  const QuarantinedLibraryMedia({
    required this.relativePath,
    required this.quarantinedAt,
  });

  final String relativePath;
  final DateTime quarantinedAt;

  DateTime get purgeEligibleAt =>
      quarantinedAt.add(libraryMediaQuarantineRetention);
}

abstract interface class LibraryMediaRecoveryStore
    implements LibraryMediaInventory {
  Future<List<QuarantinedLibraryMedia>> listQuarantined();

  Future<void> quarantine({
    required String managedRelativePath,
    required DateTime quarantinedAt,
  });

  Future<void> restore(String quarantinedRelativePath);

  Future<void> deleteQuarantined(String quarantinedRelativePath);

  Future<int> purgeExpired({
    required DateTime now,
    required Duration retention,
  });
}

final class LibraryMediaRecoverySnapshot {
  const LibraryMediaRecoverySnapshot({
    required this.integrity,
    required this.quarantined,
  });

  final LibraryMediaIntegrityReport integrity;
  final List<QuarantinedLibraryMedia> quarantined;

  bool get hasFindings => !integrity.isHealthy || quarantined.isNotEmpty;
}

/// Coordinates explicit, reversible recovery actions for app-private media.
///
/// An orphan is re-audited immediately before it is moved so stale UI cannot
/// quarantine a file that a concurrent database commit has started to use.
final class LibraryMediaRecoveryService {
  const LibraryMediaRecoveryService({
    required ReferencedMediaPathsLoader loadReferencedPaths,
    required LibraryMediaRecoveryStore store,
  })  : _loadReferencedPaths = loadReferencedPaths,
        _store = store;

  final ReferencedMediaPathsLoader _loadReferencedPaths;
  final LibraryMediaRecoveryStore _store;

  Future<LibraryMediaIntegrityReport> audit() => LibraryMediaIntegrityAuditor(
        loadReferencedPaths: _loadReferencedPaths,
        inventory: _store,
      ).audit();

  Future<LibraryMediaRecoverySnapshot> inspect() async {
    final integrityFuture = audit();
    final quarantinedFuture = _store.listQuarantined();
    return LibraryMediaRecoverySnapshot(
      integrity: await integrityFuture,
      quarantined: List.unmodifiable(await quarantinedFuture),
    );
  }

  Future<void> quarantineOrphan(
    String managedRelativePath, {
    required DateTime now,
  }) async {
    final report = await audit();
    if (!report.orphanRelativePaths.contains(managedRelativePath)) {
      throw StateError('Media is no longer an orphan');
    }
    await _store.quarantine(
      managedRelativePath: managedRelativePath,
      quarantinedAt: now.toUtc(),
    );
  }

  Future<void> restore(String quarantinedRelativePath) =>
      _store.restore(quarantinedRelativePath);

  Future<void> deleteQuarantined(String quarantinedRelativePath) =>
      _store.deleteQuarantined(quarantinedRelativePath);

  Future<int> purgeExpired({required DateTime now}) => _store.purgeExpired(
        now: now.toUtc(),
        retention: libraryMediaQuarantineRetention,
      );
}
