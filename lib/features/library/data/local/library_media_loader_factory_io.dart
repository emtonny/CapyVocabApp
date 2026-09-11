import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../application/library_media_loader.dart';
import '../../domain/entities/domain_validation.dart';

typedef LibraryDocumentsDirectoryProvider = Future<Directory> Function();

LibraryMediaLoader createLibraryMediaLoader() => IoLibraryMediaLoader();

final class IoLibraryMediaLoader implements LibraryMediaLoader {
  IoLibraryMediaLoader({
    LibraryDocumentsDirectoryProvider? documentsDirectory,
  }) : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final LibraryDocumentsDirectoryProvider _documentsDirectory;

  Future<File> _resolveFile(String relativePath) async {
    final safePath = requireRelativePath(relativePath, 'relativePath');
    final documents = await _documentsDirectory();
    final platformPath = safePath.replaceAll('/', Platform.pathSeparator);
    return File(
      '${documents.path}${Platform.pathSeparator}$platformPath',
    );
  }

  @override
  Future<Uint8List> readBytes(String relativePath) async {
    try {
      return await (await _resolveFile(relativePath)).readAsBytes();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LibraryMediaLoadException(
          'Không thể đọc ảnh đã lưu trên thiết bị.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<int> sizeBytes(String relativePath) async {
    try {
      return await (await _resolveFile(relativePath)).length();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LibraryMediaLoadException(
          'Không thể đọc dung lượng ảnh trên thiết bị.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
