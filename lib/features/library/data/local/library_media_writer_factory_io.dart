import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../application/library_cloud_media_restore_service.dart';
import '../../domain/entities/domain_validation.dart';

typedef LibraryWriterDocumentsDirectoryProvider = Future<Directory> Function();

LibraryLocalMediaWriter createLibraryLocalMediaWriter() =>
    IoLibraryLocalMediaWriter();

final class IoLibraryLocalMediaWriter implements LibraryLocalMediaWriter {
  IoLibraryLocalMediaWriter({
    LibraryWriterDocumentsDirectoryProvider? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final LibraryWriterDocumentsDirectoryProvider _documentsDirectory;

  @override
  Future<void> writeAtomically({
    required String relativePath,
    required Uint8List bytes,
  }) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    final documents = await _documentsDirectory();
    final platformPath = safePath.replaceAll('/', Platform.pathSeparator);
    final destination = File(
      '${documents.path}${Platform.pathSeparator}$platformPath',
    );
    if (await destination.exists()) return;

    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.download');
    try {
      if (await temporary.exists()) await temporary.delete();
      await temporary.writeAsBytes(bytes, flush: true);
      if (await destination.exists()) {
        await temporary.delete();
        return;
      }
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
}
