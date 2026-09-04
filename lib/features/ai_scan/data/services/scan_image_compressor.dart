import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
      final targetSize = calculateChromaSafeTargetSize(
        sourceSize,
        dimension,
      );
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
}

/// Chooses bounds that make the plugin's aspect-preserving JPEG output even
/// on both axes. This avoids a final unpaired chroma row/column in YUV 4:2:0
/// without adding another decode/encode pass.
@visibleForTesting
(int, int) calculateChromaSafeTargetSize(
  (int, int) sourceSize,
  int maxDimension,
) {
  final (width, height) = sourceSize;
  if (width <= 0 || height <= 0 || maxDimension <= 0) {
    throw ArgumentError('Image dimensions must be positive.');
  }

  final sourceLongEdge = math.max(width, height);
  final boundedLongEdge = math.min(sourceLongEdge, maxDimension);
  final floatBuffer = Float32List(1);
  var candidateLongEdge =
      boundedLongEdge.isEven ? boundedLongEdge : boundedLongEdge - 1;

  for (; candidateLongEdge >= 2; candidateLongEdge -= 2) {
    final scaledShortEdge = width >= height
        ? height * candidateLongEdge / width
        : width * candidateLongEdge / height;
    final candidateShortEdge = scaledShortEdge.floor();
    if (candidateShortEdge >= 2 && candidateShortEdge.isEven) {
      final bounds = width >= height
          ? (candidateLongEdge, candidateShortEdge)
          : (candidateShortEdge, candidateLongEdge);
      if (_projectsToEvenSize(sourceSize, bounds) &&
          _projectsToEvenSize(sourceSize, bounds, floatBuffer: floatBuffer)) {
        return bounds;
      }
    }
  }

  // Degenerate one-pixel images cannot have two even axes without upscaling.
  // Preserve the source instead of changing its aspect ratio.
  return sourceSize;
}

bool _projectsToEvenSize(
  (int, int) sourceSize,
  (int, int) bounds, {
  Float32List? floatBuffer,
}) {
  double precision(double value) {
    if (floatBuffer == null) return value;
    floatBuffer[0] = value;
    return floatBuffer[0];
  }

  final sourceWidth = precision(sourceSize.$1.toDouble());
  final sourceHeight = precision(sourceSize.$2.toDouble());
  final widthScale = precision(sourceWidth / precision(bounds.$1.toDouble()));
  final heightScale = precision(
    sourceHeight / precision(bounds.$2.toDouble()),
  );
  final scale = precision(
    math.max(1.0, math.min(widthScale, heightScale)),
  );
  final outputWidth = precision(sourceWidth / scale).truncate();
  final outputHeight = precision(sourceHeight / scale).truncate();
  return outputWidth.isEven && outputHeight.isEven;
}

class ScanImagePreparationException implements Exception {
  const ScanImagePreparationException(this.message);

  final String message;

  @override
  String toString() => 'ScanImagePreparationException: $message';
}
