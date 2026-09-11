import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/library_photo_note_deletion_service.dart';
import '../../domain/entities/domain_validation.dart';

typedef PurgerDocumentsDirectoryProvider = Future<Directory> Function();

LibraryManagedMediaPurger createLibraryManagedMediaPurger() =>
    IoLibraryManagedMediaPurger();

final class IoLibraryManagedMediaPurger implements LibraryManagedMediaPurger {
  IoLibraryManagedMediaPurger({
    PurgerDocumentsDirectoryProvider? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final PurgerDocumentsDirectoryProvider _documentsDirectory;

  @override
  Future<void> deleteAll(Iterable<String> relativePaths) async {
    final paths = relativePaths.map(_requireManagedPath).toSet();
    final documents = await _documentsDirectory();
    for (final path in paths) {
      final file = File(
        '${documents.path}${Platform.pathSeparator}'
        '${path.replaceAll('/', Platform.pathSeparator)}',
      );
      if (await file.exists()) await file.delete();
    }
  }

  String _requireManagedPath(String value) {
    final path =
        requireRelativePath(value, 'relativePath').replaceAll('\\', '/');
    final parts = path.split('/');
    if (parts.length != 2 || parts.first != 'capy_scans') {
      throw ArgumentError.value(
        value,
        'relativePath',
        'must be a direct child of capy_scans',
      );
    }
    return path;
  }
}
