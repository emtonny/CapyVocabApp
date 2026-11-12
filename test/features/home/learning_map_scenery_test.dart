import 'dart:math' as math;

import 'package:capy_vocab/features/home/presentation/widgets/learning_map_scenery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [280.0, 390.0, 600.0]) {
    for (final days in [7, 31]) {
      test('$days days at width $width keep scenery clear of buttons and peers',
          () {
        final points = [
          for (var i = 0; i < days; i++)
            Offset(42 + (width - 84) * [.5, .88, .23, .82, .22, .86, .5][i % 7],
                74 + i * 128),
        ];
        final size = Size(width, 154 + (days - 1) * 128);
        final scenery = LearningMapScenery(points: points);
        final bounds = scenery.decorationBounds(size);
        expect(bounds, isNotEmpty);
        expect(scenery.decorationBounds(size), bounds);
        final scale = width / 390;
        for (var i = 0; i < bounds.length; i++) {
          for (final point in points) {
            final dayArea = Rect.fromLTRB(
                point.dx - 62 * math.max(1, scale),
                point.dy - 68,
                point.dx + 62 * math.max(1, scale),
                point.dy + math.max(66, 52 * scale));
            expect(bounds[i].inflate(8).overlaps(dayArea), isFalse);
          }
          for (var j = i + 1; j < bounds.length; j++) {
            expect(bounds[i].inflate(12).overlaps(bounds[j]), isFalse);
          }
        }
      });
    }
  }
}
