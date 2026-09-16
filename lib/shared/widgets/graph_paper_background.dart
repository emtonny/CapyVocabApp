import 'package:flutter/material.dart';

const _graphPaperBaseColor = Color(0xFFFBF8EE);

/// A [Scaffold] whose entire view uses the shared graph-paper treatment,
/// rendering any bottom navigation bar as a floating overlay on top of the
/// unified full-screen background.
class GraphPaperScaffold extends StatelessWidget {
  const GraphPaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.extendBody,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool? extendBody;

  @override
  Widget build(BuildContext context) {
    return GraphPaperBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: appBar,
              body: SizedBox.expand(
                child: body,
              ),
            ),
          ),
          if (bottomNavigationBar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: bottomNavigationBar!,
            ),
        ],
      ),
    );
  }
}

/// A reusable widget that paints a subtle notebook graph-paper grid pattern
/// behind its child or as a standalone background layer in a Stack.
///
/// Features:
/// - Warm cream base `#FBF8EE`
/// - 1px warm light-gray grid lines at ~6% opacity (0x0F alpha)
/// - 24px square spacing (within the 20–24px specification)
/// - Isolated painting through [RepaintBoundary]
class GraphPaperBackground extends StatelessWidget {
  const GraphPaperBackground({
    super.key,
    this.child,
    this.spacing = 24.0,
    this.lineWidth = 1.0,
    this.lineColor = const Color(0x0F1A1A1A), // ~6% opacity of warm ink #1A1A1A
    this.backgroundColor = _graphPaperBaseColor,
  });

  final Widget? child;
  final double spacing;
  final double lineWidth;
  final Color lineColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: GraphPaperPainter(
          spacing: spacing,
          lineWidth: lineWidth,
          lineColor: lineColor,
          backgroundColor: backgroundColor,
        ),
        size: Size.infinite,
        child: child,
      ),
    );
  }
}

/// CustomPainter for drawing the warm cream background and subtle graph-paper grid.
class GraphPaperPainter extends CustomPainter {
  const GraphPaperPainter({
    this.spacing = 24.0,
    this.lineWidth = 1.0,
    this.lineColor = const Color(0x0F1A1A1A),
    this.backgroundColor = _graphPaperBaseColor,
  });

  final double spacing;
  final double lineWidth;
  final Color lineColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw warm cream base (#FBF8EE)
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Draw 1px subtle graph paper grid lines
    final gridPaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false; // Ensures crisp 1px lines without blur

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPaperPainter oldDelegate) {
    return oldDelegate.spacing != spacing ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
