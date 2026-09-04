import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Fine linen-paper texture used only by the AI Scan sheet.
class ScanPaperBackground extends StatelessWidget {
  const ScanPaperBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: ScanPaperBackgroundPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class ScanPaperBackgroundPainter extends CustomPainter {
  const ScanPaperBackgroundPainter({
    this.backgroundColor = AppColors.cream,
    this.fiberColor = const Color(0xFF887866),
    this.verticalFiberSpacing = 2.7,
    this.horizontalFiberSpacing = 3.2,
    this.secondaryVerticalSpacing = 7.4,
    this.secondaryHorizontalSpacing = 8.6,
    this.verticalFiberOpacity = 0.068,
    this.horizontalFiberOpacity = 0.052,
    this.secondaryFiberOpacity = 0.032,
  })  : assert(verticalFiberSpacing > 0),
        assert(horizontalFiberSpacing > 0),
        assert(secondaryVerticalSpacing > 0),
        assert(secondaryHorizontalSpacing > 0),
        assert(verticalFiberOpacity >= 0 && verticalFiberOpacity <= 1),
        assert(horizontalFiberOpacity >= 0 && horizontalFiberOpacity <= 1),
        assert(secondaryFiberOpacity >= 0 && secondaryFiberOpacity <= 1);

  final Color backgroundColor;
  final Color fiberColor;
  final double verticalFiberSpacing;
  final double horizontalFiberSpacing;
  final double secondaryVerticalSpacing;
  final double secondaryHorizontalSpacing;
  final double verticalFiberOpacity;
  final double horizontalFiberOpacity;
  final double secondaryFiberOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    _drawFibers(
      canvas,
      size,
      vertical: true,
      spacing: verticalFiberSpacing,
      opacity: verticalFiberOpacity,
      strokeWidth: 0.34,
      drift: 0.2,
      seed: 17,
    );
    _drawFibers(
      canvas,
      size,
      vertical: false,
      spacing: horizontalFiberSpacing,
      opacity: horizontalFiberOpacity,
      strokeWidth: 0.24,
      drift: 0.16,
      seed: 41,
    );
    _drawFibers(
      canvas,
      size,
      vertical: true,
      spacing: secondaryVerticalSpacing,
      opacity: secondaryFiberOpacity,
      strokeWidth: 0.46,
      drift: 0.28,
      seed: 73,
      phase: 1.3,
    );
    _drawFibers(
      canvas,
      size,
      vertical: false,
      spacing: secondaryHorizontalSpacing,
      opacity: secondaryFiberOpacity * 0.72,
      strokeWidth: 0.32,
      drift: 0.22,
      seed: 101,
      phase: 2.1,
    );
  }

  void _drawFibers(
    Canvas canvas,
    Size size, {
    required bool vertical,
    required double spacing,
    required double opacity,
    required double strokeWidth,
    required double drift,
    required int seed,
    double phase = 0,
  }) {
    final extent = vertical ? size.width : size.height;
    final crossExtent = vertical ? size.height : size.width;
    final fiberPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    var position = phase - spacing;
    var index = 0;
    while (position <= extent) {
      final spacingVariation = 0.82 + _unitVariation(index, seed) * 0.36;
      position += spacing * spacingVariation;

      var strength = 0.68 + _unitVariation(index, seed + 11) * 0.5;
      if (!vertical && _unitVariation(index, seed + 67) < 0.12) {
        strength *= 0.22;
      }
      final widthVariation = 0.72 + _unitVariation(index, seed + 23) * 0.56;
      fiberPaint
        ..color = fiberColor.withValues(
          alpha: (opacity * strength).clamp(0, 1),
        )
        ..strokeWidth = strokeWidth * widthVariation;

      final segmentLength = 18 + _unitVariation(index, seed + 37) * 12;
      final path = Path();
      _addPoint(path, vertical, position, 0, moveTo: true);

      var segment = 1;
      for (double along = segmentLength;
          along < crossExtent;
          along += segmentLength) {
        final offset =
            (_unitVariation(index * 97 + segment, seed + 53) - 0.5) * drift * 2;
        _addPoint(path, vertical, position + offset, along);
        segment++;
      }
      _addPoint(path, vertical, position, crossExtent);
      canvas.drawPath(path, fiberPaint);
      index++;
    }
  }

  void _addPoint(
    Path path,
    bool vertical,
    double position,
    double along, {
    bool moveTo = false,
  }) {
    final x = vertical ? position : along;
    final y = vertical ? along : position;
    if (moveTo) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }

  double _unitVariation(int index, int seed) {
    var value = (index * 1103515245 + seed * 12345) & 0x7fffffff;
    value = (value ^ (value >> 11)) & 0x7fffffff;
    value = (value * 48271) & 0x7fffffff;
    return value / 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant ScanPaperBackgroundPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.fiberColor != fiberColor ||
        oldDelegate.verticalFiberSpacing != verticalFiberSpacing ||
        oldDelegate.horizontalFiberSpacing != horizontalFiberSpacing ||
        oldDelegate.secondaryVerticalSpacing != secondaryVerticalSpacing ||
        oldDelegate.secondaryHorizontalSpacing != secondaryHorizontalSpacing ||
        oldDelegate.verticalFiberOpacity != verticalFiberOpacity ||
        oldDelegate.horizontalFiberOpacity != horizontalFiberOpacity ||
        oldDelegate.secondaryFiberOpacity != secondaryFiberOpacity;
  }
}
