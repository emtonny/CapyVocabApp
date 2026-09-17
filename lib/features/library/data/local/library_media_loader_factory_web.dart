import 'dart:typed_data';

import '../../application/library_media_loader.dart';
import 'library_web_media_blob_store.dart';

LibraryMediaLoader createLibraryMediaLoader() => WebLibraryMediaLoader();

final class WebLibraryMediaLoader implements LibraryMediaLoader {
  @override
  Future<Uint8List> readBytes(String relativePath) async {
    try {
      return await libraryWebMediaBlobStore.read(relativePath);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LibraryMediaLoadException(
          'Không thể đọc ảnh Library trong trình duyệt.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<int> sizeBytes(String relativePath) async {
    try {
      return await libraryWebMediaBlobStore.size(relativePath);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LibraryMediaLoadException(
          'Không thể đọc dung lượng ảnh trong trình duyệt.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
