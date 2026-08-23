import 'dart:math' as math;
import 'dart:ui';

import '../../../core/services/gemini_vision_service.dart';

class ImageRectCalculator {
  const ImageRectCalculator._();

  static Rect calculate({
    required Size sourceImageSize,
    required Size canvasSize,
  }) {
    _validateSize(sourceImageSize, 'sourceImageSize');
    _validateSize(canvasSize, 'canvasSize');

    final scale = math.min(
      canvasSize.width / sourceImageSize.width,
      canvasSize.height / sourceImageSize.height,
    );
    return Rect.fromCenter(
      center: (Offset.zero & canvasSize).center,
      width: sourceImageSize.width * scale,
      height: sourceImageSize.height * scale,
    );
  }

  static Rect detectionRect({
    required VocabDetection detection,
    required Rect imageRect,
  }) {
    return Rect.fromLTWH(
      imageRect.left + detection.x * imageRect.width,
      imageRect.top + detection.y * imageRect.height,
      detection.w * imageRect.width,
      detection.h * imageRect.height,
    );
  }

  static void _validateSize(Size size, String name) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      throw ArgumentError.value(size, name, 'must be finite and positive');
    }
  }
}
