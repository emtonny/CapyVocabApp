abstract interface class LibraryMediaInventory {
  Future<Set<String>> listManagedRelativePaths();

  Future<bool> exists(String relativePath);
}

typedef ReferencedMediaPathsLoader = Future<Set<String>> Function();

final class LibraryMediaIntegrityReport {
  const LibraryMediaIntegrityReport({
    required this.orphanRelativePaths,
    required this.missingRelativePaths,
  });

  final Set<String> orphanRelativePaths;
  final Set<String> missingRelativePaths;

  bool get isHealthy =>
      orphanRelativePaths.isEmpty && missingRelativePaths.isEmpty;
}

/// Audits local Library media without mutating user data.
///
/// Retention/quarantine policy is intentionally kept outside this service so
/// startup cannot silently delete historical or user-owned files.
final class LibraryMediaIntegrityAuditor {
  const LibraryMediaIntegrityAuditor({
    required ReferencedMediaPathsLoader loadReferencedPaths,
    required LibraryMediaInventory inventory,
  })  : _loadReferencedPaths = loadReferencedPaths,
        _inventory = inventory;

  final ReferencedMediaPathsLoader _loadReferencedPaths;
  final LibraryMediaInventory _inventory;

  Future<LibraryMediaIntegrityReport> audit() async {
    final referenced = (await _loadReferencedPaths())
        .map(_canonicalize)
        .where((path) => path.isNotEmpty)
        .toSet();
    final managed = (await _inventory.listManagedRelativePaths())
        .map(_canonicalize)
        .where((path) => path.isNotEmpty)
        .toSet();
    final missing = <String>{};
    for (final path in referenced) {
      if (!await _inventory.exists(path)) missing.add(path);
    }

    return LibraryMediaIntegrityReport(
      orphanRelativePaths: Set.unmodifiable(managed.difference(referenced)),
      missingRelativePaths: Set.unmodifiable(missing),
    );
  }

  String _canonicalize(String path) {
    var canonical = path.trim().replaceAll('\\', '/');
    while (canonical.startsWith('./')) {
      canonical = canonical.substring(2);
    }
    return canonical;
  }
}
