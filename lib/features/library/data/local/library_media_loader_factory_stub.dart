import 'dart:typed_data';

import '../../application/library_media_loader.dart';

LibraryMediaLoader createLibraryMediaLoader() =>
    _UnsupportedLibraryMediaLoader();

final class _UnsupportedLibraryMediaLoader implements LibraryMediaLoader {
  @override
  Future<Uint8List> readBytes(String relativePath) {
    throw const LibraryMediaLoadException(
      'Ảnh Library local chưa khả dụng trên nền tảng này.',
    );
  }

  @override
  Future<int> sizeBytes(String relativePath) {
    throw const LibraryMediaLoadException(
      'Dung lượng ảnh Library local chưa khả dụng trên nền tảng này.',
    );
  }
}
