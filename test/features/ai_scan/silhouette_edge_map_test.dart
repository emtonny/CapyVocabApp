import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/layout/silhouette_edge_map.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_connector_geometry.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_placement_solver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SilhouetteEdgeMap', () {
    test('finds the first strong Sobel edge before a shrunken bbox', () {
      final result = _verticalEdgeMap(edgeX: 40).findAnchor(
        cardAnchor: const Offset(5, 30),
        objectRect: const Rect.fromLTWH(50, 15, 30, 30),
        imageRect: const Rect.fromLTWH(0, 0, 100, 60),
        fallbackAnchor: const Offset(50, 30),
      );

      expect(result.usedFallback, isFalse);
      expect(result.method, AnchorRefinementMethod.sobel);
      expect(result.anchor.dx, closeTo(40, 3));
      expect(
          result.gradientMagnitude!, greaterThan(result.backgroundGradient!));
    });

    test('rejects a Sobel hit beyond 0.6 object diagonal', () {
      final result = _verticalEdgeMap(edgeX: 45).findAnchor(
        cardAnchor: const Offset(5, 30),
        objectRect: const Rect.fromLTWH(50, 27.5, 5, 5),
        imageRect: const Rect.fromLTWH(0, 0, 100, 60),
        fallbackAnchor: const Offset(50, 30),
      );

      expect(result.anchor, const Offset(50, 30));
      expect(result.fallbackReason, RayCastFallbackReason.excessiveShift);
    });

    test('rejects a Sobel hit inside another object inner core', () {
      final result = _verticalEdgeMap(edgeX: 40).findAnchor(
        cardAnchor: const Offset(5, 30),
        objectRect: const Rect.fromLTWH(50, 15, 30, 30),
        imageRect: const Rect.fromLTWH(0, 0, 100, 60),
        fallbackAnchor: const Offset(50, 30),
        otherObjectRects: const [Rect.fromLTWH(30, 20, 20, 20)],
      );

      expect(result.anchor, const Offset(50, 30));
      expect(result.fallbackReason, RayCastFallbackReason.otherObjectCore);
    });

    test('Sobel fallback keeps placement and respects connector cap', () {
      const placed = PlacedLabel(
        word: VocabDetection(
          word: 'object',
          phonetic: '/object/',
          meaning: 'vật thể',
          x: 0.2,
          y: 0.2,
          w: 0.6,
          h: 0.6,
        ),
        labelRect: Rect.fromLTWH(0, 40, 10, 20),
        anchorBox: Rect.fromLTWH(20, 20, 60, 60),
        quality: PlacementQuality.ideal,
      );
      const bbox = ConnectorPath(from: Offset(10, 50), to: Offset(20, 50));
      final result = refineConnectorPaths(
        placedLabels: const [placed],
        bboxPaths: const [bbox],
        edgeMap: _InvalidEdgeMap.value,
        imageRect: const Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(result.connectorPaths.single, isA<ConnectorPath>());
      expect(result.connectorPaths.single.from, bbox.from);
      expect(placed.labelRect, const Rect.fromLTWH(0, 40, 10, 20));
    });
  });
}

class _InvalidEdgeMap {
  static final value = SilhouetteEdgeMap.fromRgba(
    rgba: Uint8List(0),
    width: 0,
    height: 0,
  );
}

SilhouetteEdgeMap _verticalEdgeMap({
  required int edgeX,
  int width = 100,
  int height = 60,
}) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final value = x < edgeX ? 20 : 220;
      final index = (y * width + x) * 4;
      rgba[index] = value;
      rgba[index + 1] = value;
      rgba[index + 2] = value;
      rgba[index + 3] = 255;
    }
  }
  return SilhouetteEdgeMap.fromRgba(rgba: rgba, width: width, height: height);
}
