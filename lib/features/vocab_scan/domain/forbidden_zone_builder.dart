import 'dart:ui';

import '../../../core/services/gemini_vision_service.dart';
import 'image_rect_calculator.dart';

class ForbiddenZoneBuilder {
  const ForbiddenZoneBuilder._();

  static List<Rect> build({
    required List<VocabDetection> words,
    required Size sourceImageSize,
    required Size canvasSize,
    double margin = 6.0,
  }) {
    if (!margin.isFinite || margin < 0) {
      throw ArgumentError.value(margin, 'margin', 'must be finite and >= 0');
    }

    final imageRect = ImageRectCalculator.calculate(
      sourceImageSize: sourceImageSize,
      canvasSize: canvasSize,
    );
    final canvasRect = Offset.zero & canvasSize;

    return List.unmodifiable(
      words.map((word) {
        final objectRect = ImageRectCalculator.detectionRect(
          detection: word,
          imageRect: imageRect,
        );
        return _clampToBounds(objectRect.inflate(margin), canvasRect);
      }),
    );
  }

  static Rect _clampToBounds(Rect rect, Rect bounds) {
    return Rect.fromLTRB(
      rect.left.clamp(bounds.left, bounds.right).toDouble(),
      rect.top.clamp(bounds.top, bounds.bottom).toDouble(),
      rect.right.clamp(bounds.left, bounds.right).toDouble(),
      rect.bottom.clamp(bounds.top, bounds.bottom).toDouble(),
    );
  }
}

bool anyOverlap(Rect candidate, List<Rect> zones) {
  return zones.any(candidate.overlaps);
}
