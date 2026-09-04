import 'dart:math' as math;
import 'dart:typed_data';

import 'package:capy_vocab/features/ai_scan/data/services/scan_image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portrait target avoids an odd JPEG edge in a single encode', () {
    const sourceSize = (3020, 4032);

    final bounds = calculateChromaSafeTargetSize(sourceSize, 1024);
    final output = _projectEncoderOutput(sourceSize, bounds);

    expect(bounds, (766, 1024));
    expect(output.$1.isEven, isTrue);
    expect(output.$2.isEven, isTrue);
  });

  test('landscape and small odd images also produce even output', () {
    const sourceSizes = [
      (4031, 3020),
      (1023, 767),
      (767, 1023),
      (999, 999),
      (4000, 2251),
    ];

    for (final sourceSize in sourceSizes) {
      final bounds = calculateChromaSafeTargetSize(sourceSize, 1024);
      final output = _projectEncoderOutput(sourceSize, bounds);

      expect(output.$1.isEven, isTrue, reason: '$sourceSize -> $output');
      expect(output.$2.isEven, isTrue, reason: '$sourceSize -> $output');
      expect(output.$1, lessThanOrEqualTo(sourceSize.$1));
      expect(output.$2, lessThanOrEqualTo(sourceSize.$2));
      expect(math.max(output.$1, output.$2), lessThanOrEqualTo(1024));
    }
  });

  test('already safe dimensions keep their existing resolution', () {
    expect(calculateChromaSafeTargetSize((768, 1024), 1024), (768, 1024));
    expect(calculateChromaSafeTargetSize((640, 480), 1024), (640, 480));
  });

  test('common camera ratios stay chroma-safe on web and Android math', () {
    const maxDimensions = [1024, 896, 768, 640, 512, 384];
    const sourceSizes = [
      (4032, 3024),
      (4032, 3020),
      (4000, 3000),
      (4000, 2250),
      (3840, 2160),
      (3264, 2448),
      (3024, 4032),
      (2251, 4000),
      (2160, 3840),
      (2448, 3264),
    ];

    for (final sourceSize in sourceSizes) {
      for (final maxDimension in maxDimensions) {
        final bounds = calculateChromaSafeTargetSize(
          sourceSize,
          maxDimension,
        );
        for (final useFloat32 in [false, true]) {
          final output = _projectEncoderOutput(
            sourceSize,
            bounds,
            useFloat32: useFloat32,
          );
          expect(
            output.$1.isEven && output.$2.isEven,
            isTrue,
            reason: '$sourceSize @ $maxDimension -> $output '
                '(${useFloat32 ? 'Android' : 'web'})',
          );
        }
      }
    }
  });
}

(int, int) _projectEncoderOutput(
  (int, int) sourceSize,
  (int, int) bounds, {
  bool useFloat32 = false,
}) {
  double precision(double value) => useFloat32 ? _float32(value) : value;
  final widthScale = precision(sourceSize.$1 / bounds.$1);
  final heightScale = precision(sourceSize.$2 / bounds.$2);
  final scale = precision(
    math.max(1, math.min(widthScale, heightScale)).toDouble(),
  );
  return (
    precision(sourceSize.$1 / scale).floor(),
    precision(sourceSize.$2 / scale).floor(),
  );
}

double _float32(double value) {
  final bytes = ByteData(4)..setFloat32(0, value);
  return bytes.getFloat32(0);
}
