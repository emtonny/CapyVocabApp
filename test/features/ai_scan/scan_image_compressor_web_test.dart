@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/features/ai_scan/data/services/scan_image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flutter_image_compress Web tạo JPEG dưới 300KB', () async {
    final pngBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );

    final compressed = await FlutterScanImageCompressor().compress(pngBytes);

    expect(compressed.lengthInBytes, lessThanOrEqualTo(300 * 1024));
    expect(compressed.take(2), [0xff, 0xd8]);
    expect(compressed.skip(compressed.length - 2), [0xff, 0xd9]);
  });
}
