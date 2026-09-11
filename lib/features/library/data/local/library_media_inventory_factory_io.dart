import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/library_media_integrity_auditor.dart';
import '../../application/library_media_recovery_service.dart';
import '../../domain/entities/domain_validation.dart';

typedef LibraryDocumentsDirectoryProvider = Future<Directory> Function();

LibraryMediaInventory createLibraryMediaInventory() =>
    IoLibraryMediaInventory();

LibraryMediaRecoveryStore createLibraryMediaRecoveryStore() =>
    IoLibraryMediaInventory();

final class IoLibraryMediaInventory implements LibraryMediaRecoveryStore {
  IoLibraryMediaInventory({
    LibraryDocumentsDirectoryProvider? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final LibraryDocumentsDirectoryProvider _documentsDirectory;

  static const _managedDirectoryName = 'capy_scans';
  static const _quarantineDirectoryName = 'capy_quarantine';

  @override
  Future<bool> exists(String relativePath) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    final documents = await _documentsDirectory();
    final platformPath = safePath.replaceAll('/', Platform.pathSeparator);
    return File(
      '${documents.path}${Platform.pathSeparator}$platformPath',
    ).exists();
  }

  @override
  Future<Set<String>> listManagedRelativePaths() async {
    final documents = await _documentsDirectory();
    final scanDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}$_managedDirectoryName',
    );
    if (!await scanDirectory.exists()) return const <String>{};

    final paths = <String>{};
    await for (final entity in scanDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final filename = entity.path.split(Platform.pathSeparator).last;
      paths.add('$_managedDirectoryName/$filename');
    }
    return paths;
  }

  @override
  Future<List<QuarantinedLibraryMedia>> listQuarantined() async {
    final documents = await _documentsDirectory();
    final quarantineDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}$_quarantineDirectoryName',
    );
    if (!await quarantineDirectory.exists()) {
      return const <QuarantinedLibraryMedia>[];
    }

    final entries = <QuarantinedLibraryMedia>[];
    await for (final entity in quarantineDirectory.list(followLinks: false)) {
      if (entity is! File) continue;
      final filename = entity.path.split(Platform.pathSeparator).last;
      final modifiedAt = (await entity.stat()).modified.toUtc();
      entries.add(QuarantinedLibraryMedia(
        relativePath: '$_quarantineDirectoryName/$filename',
        quarantinedAt: modifiedAt,
      ));
    }
    entries.sort((a, b) => a.quarantinedAt.compareTo(b.quarantinedAt));
    return List.unmodifiable(entries);
  }

  @override
  Future<void> quarantine({
    required String managedRelativePath,
    required DateTime quarantinedAt,
  }) async {
    final filename = _requireDirectChild(
      managedRelativePath,
      directoryName: _managedDirectoryName,
      fieldName: 'managedRelativePath',
    );
    final documents = await _documentsDirectory();
    final source = _file(documents, _managedDirectoryName, filename);
    if (!await source.exists()) {
      throw StateError('Managed media is missing');
    }

    final quarantineDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}$_quarantineDirectoryName',
    );
    await quarantineDirectory.create();
    final destination = _file(
      documents,
      _quarantineDirectoryName,
      filename,
    );
    if (await destination.exists()) {
      throw StateError('A quarantined file already uses this name');
    }
    final moved = await source.rename(destination.path);
    await moved.setLastModified(quarantinedAt.toUtc());
  }

  @override
  Future<void> restore(String quarantinedRelativePath) async {
    final filename = _requireDirectChild(
      quarantinedRelativePath,
      directoryName: _quarantineDirectoryName,
      fieldName: 'quarantinedRelativePath',
    );
    final documents = await _documentsDirectory();
    final source = _file(documents, _quarantineDirectoryName, filename);
    if (!await source.exists()) {
      throw StateError('Quarantined media is missing');
    }

    final managedDirectory = Directory(
      '${documents.path}${Platform.pathSeparator}$_managedDirectoryName',
    );
    await managedDirectory.create();
    final destination = _file(documents, _managedDirectoryName, filename);
    if (await destination.exists()) {
      throw StateError('A managed file already uses this name');
    }
    await source.rename(destination.path);
  }

  @override
  Future<void> deleteQuarantined(String quarantinedRelativePath) async {
    final filename = _requireDirectChild(
      quarantinedRelativePath,
      directoryName: _quarantineDirectoryName,
      fieldName: 'quarantinedRelativePath',
    );
    final documents = await _documentsDirectory();
    final file = _file(documents, _quarantineDirectoryName, filename);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<int> purgeExpired({
    required DateTime now,
    required Duration retention,
  }) async {
    if (retention <= Duration.zero) {
      throw ArgumentError.value(retention, 'retention', 'must be positive');
    }
    final cutoff = now.toUtc().subtract(retention);
    var deleted = 0;
    for (final entry in await listQuarantined()) {
      if (entry.quarantinedAt.isAfter(cutoff)) continue;
      await deleteQuarantined(entry.relativePath);
      deleted++;
    }
    return deleted;
  }

  File _file(Directory documents, String directory, String filename) => File(
        '${documents.path}${Platform.pathSeparator}$directory'
        '${Platform.pathSeparator}$filename',
      );

  String _requireDirectChild(
    String relativePath, {
    required String directoryName,
    required String fieldName,
  }) {
    final safePath =
        requireRelativePath(relativePath, fieldName).replaceAll('\\', '/');
    final parts = safePath.split('/');
    if (parts.length != 2 ||
        parts.first != directoryName ||
        parts.last.isEmpty ||
        parts.last == '.' ||
        parts.last == '..') {
      throw ArgumentError.value(
        relativePath,
        fieldName,
        'must be a direct child of $directoryName',
      );
    }
    return parts.last;
  }
}
