import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

abstract interface class ScanImageCompressor {
  Future<Uint8List> compress(Uint8List sourceBytes);
}

class FlutterScanImageCompressor implements ScanImageCompressor {
  static const maxBytes = 300 * 1024;
  static const _dimensions = [1024, 896, 768, 640, 512, 384];
  static const _qualities = [85, 70, 55, 40, 25, 15];

  @override
  Future<Uint8List> compress(Uint8List sourceBytes) async {
    if (sourceBytes.isEmpty) {
      throw const ScanImagePreparationException('Ảnh đã chọn không hợp lệ.');
    }

    final sourceSize = await _readImageSize(sourceBytes);
    Uint8List? smallest;
    for (final dimension in _dimensions) {
      final targetSize = _fitWithin(sourceSize, dimension);
      for (final quality in _qualities) {
        final compressed = await FlutterImageCompress.compressWithList(
          sourceBytes,
          minWidth: targetSize.$1,
          minHeight: targetSize.$2,
          quality: quality,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
        if (compressed.isEmpty) continue;

        if (smallest == null ||
            compressed.lengthInBytes < smallest.lengthInBytes) {
          smallest = compressed;
        }
        if (compressed.lengthInBytes <= maxBytes) {
          return compressed;
        }
      }
    }

    if (smallest == null) {
      throw const ScanImagePreparationException('Không thể xử lý ảnh đã chọn.');
    }
    throw const ScanImagePreparationException(
      'Ảnh vẫn quá lớn sau khi nén, vui lòng chọn ảnh khác.',
    );
  }

  Future<(int, int)> _readImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return size;
    } on Object {
      throw const ScanImagePreparationException('Ảnh đã chọn không hợp lệ.');
    }
  }

  (int, int) _fitWithin((int, int) sourceSize, int maxDimension) {
    final (width, height) = sourceSize;
    if (width <= maxDimension && height <= maxDimension) {
      return (width, height);
    }

    if (width >= height) {
      return (
        maxDimension,
        (height * maxDimension / width).round().clamp(1, maxDimension),
      );
    }
    return (
      (width * maxDimension / height).round().clamp(1, maxDimension),
      maxDimension,
    );
  }
}

class ScanImagePreparationException implements Exception {
  const ScanImagePreparationException(this.message);

  final String message;

  @override
  String toString() => 'ScanImagePreparationException: $message';
}
