import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Top-left Neon Lime Corner Triangle with black border
class NeoCornerTriangle extends StatelessWidget {
  const NeoCornerTriangle({
    super.key,
    this.size = 48.0,
    this.color = const Color(0xFFC6F135),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NeoCornerTrianglePainter(color: color),
    );
  }
}

class _NeoCornerTrianglePainter extends CustomPainter {
  const _NeoCornerTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.miter;

    // Draw the hypotenuse border line
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(0, size.height),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeoCornerTrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}

/// 3x3 Dot Matrix Grid
class NeoDotMatrix extends StatelessWidget {
  const NeoDotMatrix({
    super.key,
    this.rows = 3,
    this.columns = 3,
    this.dotSize = 4.0,
    this.spacing = 5.0,
    this.color = Colors.black,
  });

  final int rows;
  final int columns;
  final double dotSize;
  final double spacing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(rows, (r) {
        return Padding(
          padding: EdgeInsets.only(bottom: r < rows - 1 ? spacing : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(columns, (c) {
              return Padding(
                padding: EdgeInsets.only(right: c < columns - 1 ? spacing : 0),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

/// Left-edge Purple Zigzag / Lightning Badge with black outline and shadow
class NeoZigzagBadge extends StatelessWidget {
  const NeoZigzagBadge({
    super.key,
    this.width = 24.0,
    this.height = 54.0,
    this.color = const Color(0xFFA855F7),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _NeoZigzagPainter(color: color),
    );
  }
}

class _NeoZigzagPainter extends CustomPainter {
  const _NeoZigzagPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    Path createZigzagPath(double dx, double dy) {
      final p = Path();
      p.moveTo(dx + 2, dy);
      p.lineTo(dx + w - 2, dy + h * 0.22);
      p.lineTo(dx + w * 0.45, dy + h * 0.48);
      p.lineTo(dx + w, dy + h * 0.72);
      p.lineTo(dx + 4, dy + h);
      p.lineTo(dx, dy + h * 0.74);
      p.lineTo(dx + w * 0.4, dy + h * 0.52);
      p.lineTo(dx, dy + h * 0.26);
      p.close();
      return p;
    }

    // Shadow
    final shadowPath = createZigzagPath(3, 3);
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );

    // Main fill
    final mainPath = createZigzagPath(0, 0);
    canvas.drawPath(
      mainPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Stroke
    canvas.drawPath(
      mainPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NeoZigzagPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Bottom-left Purple Checkered Grid
class NeoCheckeredGrid extends StatelessWidget {
  const NeoCheckeredGrid({
    super.key,
    this.columns = 2,
    this.rows = 4,
    this.cellSize = 12.0,
    this.color = const Color(0xFFA855F7),
  });

  final int columns;
  final int rows;
  final double cellSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(rows, (r) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(columns, (c) {
              return Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.0),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}

/// Vertical Dotted Track for Right Edge
class NeoDottedTrack extends StatelessWidget {
  const NeoDottedTrack({
    super.key,
    this.dotCount = 10,
    this.dotSize = 3.5,
    this.spacing = 6.0,
    this.color = Colors.black,
  });

  final int dotCount;
  final double dotSize;
  final double spacing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(dotCount, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < dotCount - 1 ? spacing : 0),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

/// Bottom-right Neon Lime Corner Bracket Shape
class NeoCornerBracket extends StatelessWidget {
  const NeoCornerBracket({
    super.key,
    this.width = 36.0,
    this.height = 42.0,
    this.color = const Color(0xFFC6F135),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _NeoCornerBracketPainter(color: color),
    );
  }
}

class _NeoCornerBracketPainter extends CustomPainter {
  const _NeoCornerBracketPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.4, 0)
      ..lineTo(w, h * 0.35)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, h * 0.65)
      ..lineTo(w * 0.35, h * 0.65)
      ..lineTo(w * 0.35, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant _NeoCornerBracketPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Top-Right Purple Stylized 'X' Close Button
class NeoCloseButton extends StatelessWidget {
  const NeoCloseButton({
    super.key,
    required this.onTap,
    this.size = 34.0,
    this.color = const Color(0xFFA855F7),
  });

  final VoidCallback onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Đóng',
      child: GestureDetector(
        key: const Key('close-sheet-button'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: CustomPaint(
              size: Size(size, size),
              painter: _NeoCloseCrossPainter(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeoCloseCrossPainter extends CustomPainter {
  const _NeoCloseCrossPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    Path createCrossPath(double dx, double dy) {
      final armW = w * 0.28;
      final armL = w * 0.88;
      final r = armW / 2;

      final path = Path();
      // Draw 2 intersecting rounded rectangles rotated 45 and -45 degrees
      final matrix1 = Matrix4.identity()
        ..translateByDouble(cx + dx, cy + dy, 0, 1)
        ..rotateZ(math.pi / 4)
        ..translateByDouble(-armL / 2, -armW / 2, 0, 1);

      final rrect1 = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, armL, armW),
        Radius.circular(r),
      );
      path.addPath(Path()..addRRect(rrect1), Offset.zero,
          matrix4: matrix1.storage);

      final matrix2 = Matrix4.identity()
        ..translateByDouble(cx + dx, cy + dy, 0, 1)
        ..rotateZ(-math.pi / 4)
        ..translateByDouble(-armL / 2, -armW / 2, 0, 1);

      final rrect2 = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, armL, armW),
        Radius.circular(r),
      );
      path.addPath(Path()..addRRect(rrect2), Offset.zero,
          matrix4: matrix2.storage);

      return path;
    }

    // Shadow
    canvas.drawPath(
      createCrossPath(2.5, 2.5),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );

    // Main fill
    final mainPath = createCrossPath(0, 0);
    canvas.drawPath(
      mainPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Outline
    canvas.drawPath(
      mainPath,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _NeoCloseCrossPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Custom Neo-Brutalist Camera Icon with 2 Sparkle Stars
class NeoCameraIcon extends StatelessWidget {
  const NeoCameraIcon({
    super.key,
    this.size = 50.0,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.3,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Black Camera Body
          Positioned(
            left: 4,
            bottom: 2,
            child: Container(
              width: size * 0.95,
              height: size * 0.72,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera top notch
                  Positioned(
                    top: -4,
                    left: size * 0.25,
                    child: Container(
                      width: size * 0.3,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                  // Outer lens ring
                  Container(
                    width: size * 0.44,
                    height: size * 0.44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                    ),
                  ),
                  // Inner lens dot
                  Container(
                    width: size * 0.18,
                    height: size * 0.18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top-right Sparkles
          const Positioned(
            top: -2,
            right: 2,
            child: CustomPaint(
              size: Size(20, 20),
              painter: _SparkleStarPainter(color: Colors.white),
            ),
          ),
          const Positioned(
            top: 10,
            right: -2,
            child: CustomPaint(
              size: Size(13, 13),
              painter: _SparkleStarPainter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkleStarPainter extends CustomPainter {
  const _SparkleStarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final path = Path();
    path.moveTo(cx, 0);
    path.quadraticBezierTo(cx, cy, w, cy);
    path.quadraticBezierTo(cx, cy, cx, h);
    path.quadraticBezierTo(cx, cy, 0, cy);
    path.quadraticBezierTo(cx, cy, cx, 0);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkleStarPainter oldDelegate) => false;
}

/// Custom Neo-Brutalist Landscape / Gallery Icon
class NeoPhotoIcon extends StatelessWidget {
  const NeoPhotoIcon({
    super.key,
    this.size = 46.0,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.15,
      height: size * 0.95,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E), // Emerald Green
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Sun dot
          Positioned(
            top: 6,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Mountains
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(size * 1.15, size * 0.55),
              painter: _MountainsPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MountainsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Mountain 1 (left/center)
    final path1 = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.38, 2)
      ..lineTo(w * 0.75, h)
      ..close();

    canvas.drawPath(
      path1,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path1,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Mountain 2 (right)
    final path2 = Path()
      ..moveTo(w * 0.45, h)
      ..lineTo(w * 0.72, h * 0.3)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(
      path2,
      Paint()
        ..color = const Color(0xFFF0FDF4)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path2,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _MountainsPainter oldDelegate) => false;
}
