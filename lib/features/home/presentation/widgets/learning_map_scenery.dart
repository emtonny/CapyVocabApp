import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative scenery is drawn behind the interactive day buttons.
class LearningMapScenery extends CustomPainter {
  const LearningMapScenery({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
        const Radius.circular(20)));
    final scale = size.width / 390;
    for (final decoration in _layout(size)) {
      canvas.save();
      canvas.translate(decoration.origin.dx, decoration.origin.dy);
      canvas.scale(scale);
      switch (decoration.kind) {
        case _SceneryKind.forest:
          _forest(canvas);
        case _SceneryKind.smallForest:
          _forest(canvas, small: true);
        case _SceneryKind.cloud:
          _cloud(canvas, 29);
        case _SceneryKind.pond:
          _pond(canvas);
        case _SceneryKind.sign:
          _sign(canvas, decoration.origin.dy > size.height * .8);
      }
      canvas.restore();
    }

    for (var i = 0; i < points.length; i++) {
      canvas.save();
      canvas.translate(points[i].dx, points[i].dy + 29);
      canvas.scale(scale);
      _ellipse(canvas, const Offset(0, 5), 59, 17, const Color(0xFFFFEFC3));
      _ellipse(canvas, const Offset(17, 11), 30, 7, const Color(0xFFFFE6A5));
      _grass(canvas, const Offset(-45, 1));
      _grass(canvas, const Offset(43, 2));
      if (i.isEven) _flower(canvas, const Offset(46, 1));
      canvas.restore();
    }
  }

  /// Visible footprints used to verify spacing on different map sizes.
  @visibleForTesting
  List<Rect> decorationBounds(Size size) =>
      _layout(size).map((decoration) => decoration.bounds).toList();

  List<({Offset origin, Rect bounds, _SceneryKind kind})> _layout(Size size) {
    final scale = size.width / 390;
    final viewport = Offset.zero & size;
    // Reserve the pin, button, label and its island as one group.
    final reserved = [
      for (final point in points)
        Rect.fromLTRB(
            point.dx - 62 * math.max(1, scale),
            point.dy - 68,
            point.dx + 62 * math.max(1, scale),
            point.dy + math.max(66, 52 * scale)),
    ];
    final decorations = <({Offset origin, Rect bounds, _SceneryKind kind})>[];
    const motifs = [
      _SceneryKind.forest,
      _SceneryKind.smallForest,
      _SceneryKind.sign,
      _SceneryKind.smallForest,
      _SceneryKind.forest,
      _SceneryKind.cloud,
      _SceneryKind.pond,
    ];
    final order = List.generate(points.length, (i) => i)
      ..sort((a, b) {
        const priority = [1, 4, 0, 2, 3];
        final comparison = priority[motifs[a % 7].index]
            .compareTo(priority[motifs[b % 7].index]);
        return comparison == 0 ? a.compareTo(b) : comparison;
      });
    for (final i in order) {
      final preferred = motifs[i % 7];
      final left =
          preferred == _SceneryKind.sign || points[i].dx >= size.width / 2;
      var placed = false;
      // Use the free side of the route; fall back to a cloud if a large motif
      // cannot fit. Never force a decoration into an occupied space.
      for (final kind in [
        preferred,
        if (preferred == _SceneryKind.forest) _SceneryKind.smallForest,
        if (preferred != _SceneryKind.cloud) _SceneryKind.cloud,
      ]) {
        for (final offsetY in [
          0.0,
          12.0,
          18.0,
          -18.0,
          -12.0,
          24.0,
          -24.0,
          40.0,
          -40.0,
          54.0,
          -54.0,
          128.0,
          -128.0
        ]) {
          for (final x in [
            left ? .08 : .92,
            left ? .12 : .88,
            if (preferred != _SceneryKind.sign) left ? .99 : .01
          ]) {
            final origin = Offset(size.width * x, points[i].dy + offsetY);
            final local = switch (kind) {
              _SceneryKind.forest => const Rect.fromLTRB(-70, -105, 70, 45),
              _SceneryKind.smallForest => const Rect.fromLTRB(-46, -69, 46, 30),
              _SceneryKind.cloud => const Rect.fromLTRB(-29, -24, 29, 11),
              _SceneryKind.pond => const Rect.fromLTRB(-88, -90, 88, 90),
              _SceneryKind.sign => const Rect.fromLTRB(-32, -22, 32, 40),
            };
            final footprint = Rect.fromLTRB(
              origin.dx + local.left * scale,
              origin.dy + local.top * scale,
              origin.dx + local.right * scale,
              origin.dy + local.bottom * scale,
            );
            if (footprint.top < 8 || footprint.bottom > size.height - 8) {
              continue;
            }
            final bounds = footprint.intersect(viewport);
            if (reserved.any((area) => area.overlaps(bounds.inflate(8))) ||
                decorations.any(
                    (other) => other.bounds.overlaps(bounds.inflate(12)))) {
              continue;
            }
            decorations.add((origin: origin, bounds: bounds, kind: kind));
            placed = true;
            break;
          }
          if (placed) break;
        }
        if (placed) break;
      }
    }
    // These accents belong to the landscape, independent of the displayed dates.
    for (final accent in [
      (kind: _SceneryKind.cloud, position: const Offset(.25, .04)),
      (kind: _SceneryKind.cloud, position: const Offset(.86, .08)),
      (kind: _SceneryKind.cloud, position: const Offset(.93, .42)),
      (kind: _SceneryKind.cloud, position: const Offset(.92, .64)),
      (kind: _SceneryKind.sign, position: const Offset(.82, .91)),
    ]) {
      final origin = Offset(
          accent.position.dx * size.width, accent.position.dy * size.height);
      final local = accent.kind == _SceneryKind.cloud
          ? const Rect.fromLTRB(-29, -24, 29, 11)
          : const Rect.fromLTRB(-32, -22, 32, 40);
      final bounds = Rect.fromLTRB(
              origin.dx + local.left * scale,
              origin.dy + local.top * scale,
              origin.dx + local.right * scale,
              origin.dy + local.bottom * scale)
          .intersect(viewport);
      if (reserved.any((area) => area.overlaps(bounds.inflate(8))) ||
          decorations
              .any((other) => other.bounds.overlaps(bounds.inflate(12)))) {
        continue;
      }
      decorations.add((origin: origin, bounds: bounds, kind: accent.kind));
    }
    return decorations;
  }

  void _ellipse(Canvas c, Offset p, double rx, double ry, Color color) =>
      c.drawOval(Rect.fromCenter(center: p, width: rx * 2, height: ry * 2),
          Paint()..color = color);

  void _cloud(Canvas c, double radius) {
    const color = Color(0xFFE2EEFA);
    _ellipse(c, Offset.zero, radius, radius * .35, color);
    _ellipse(c, Offset(-radius * .15, -radius * .28), radius * .47,
        radius * .52, color);
    _ellipse(c, Offset(radius * .42, -radius * .1), radius * .35, radius * .35,
        color);
  }

  void _tree(Canvas c, Offset p, double s) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(s);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -8, 8, 21), const Radius.circular(3)),
        Paint()..color = const Color(0xFFA67C4C));
    for (var i = 0; i < 3; i++) {
      final y = -23.0 - i * 20;
      final width = 25.0 - i * 4;
      final path = Path()
        ..moveTo(0, y - 42)
        ..quadraticBezierTo(-4, y - 45, -8, y - 31)
        ..lineTo(-width, y)
        ..quadraticBezierTo(-width - 2, y + 8, -width * .5, y + 6)
        ..quadraticBezierTo(0, y + 15, width * .5, y + 6)
        ..quadraticBezierTo(width + 2, y + 8, width, y)
        ..lineTo(5, y - 39)
        ..quadraticBezierTo(2, y - 44, 0, y - 42)
        ..close();
      c.drawPath(path, Paint()..color = const Color(0xFF478775));
      c.drawPath(
          Path()
            ..moveTo(0, y - 42)
            ..lineTo(-width, y)
            ..quadraticBezierTo(-width - 2, y + 8, -width * .5, y + 6)
            ..quadraticBezierTo(-4, y + 8, 0, y - 42),
          Paint()..color = const Color(0xFF659B86));
    }
    c.restore();
  }

  void _forest(Canvas c, {bool small = false}) {
    final s = small ? .65 : 1.0;
    c.save();
    c.scale(s);
    _ellipse(c, const Offset(0, 23), 70, 22, const Color(0xFFFFEDBF));
    _tree(c, const Offset(28, 10), .6);
    _tree(c, const Offset(-10, 5), 1);
    _bush(c, 24);
    _grass(c, const Offset(51, 14));
    _flower(c, const Offset(18, 25));
    c.restore();
  }

  void _bush(Canvas c, double s) {
    _ellipse(c, Offset(-s * .5, 0), s * .6, s * .7, const Color(0xFFACC975));
    _ellipse(c, Offset(0, s * .3), s * .65, s * .55, const Color(0xFF85B267));
    _ellipse(
        c, Offset(s * .55, s * .45), s * .45, s * .4, const Color(0xFF9DC579));
  }

  void _grass(Canvas c, Offset p) {
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate((i - 1) * .4);
      _ellipse(c, const Offset(0, -7), 3, 9,
          i == 1 ? const Color(0xFF8AB35F) : const Color(0xFFB1CE7D));
      c.restore();
    }
  }

  void _flower(Canvas c, Offset p) {
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      c.drawCircle(p + Offset(math.cos(a), math.sin(a)) * 3.5, 2.8,
          Paint()..color = Colors.white);
    }
    c.drawCircle(p, 2, Paint()..color = const Color(0xFFFFD262));
  }

  void _pond(Canvas c) {
    _ellipse(c, Offset.zero, 88, 90, const Color(0xFFFFEDBF));
    _ellipse(c, const Offset(-5, -5), 77, 75, const Color(0xFF91D9F2));
    final ripple = Paint()
      ..color = const Color(0xFFCDF1FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawArc(const Rect.fromLTWH(-53, -52, 100, 78), -.9, 1.8, false, ripple);
    _ellipse(c, const Offset(32, -32), 14, 5, const Color(0xFF9ABD64));
    _ellipse(c, const Offset(19, 28), 12, 5, const Color(0xFF9ABD64));
    for (var i = 0; i < 4; i++) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-63, -4 + i * 10, 61, 9), const Radius.circular(2)),
          Paint()
            ..color =
                i.isEven ? const Color(0xFFD69A60) : const Color(0xFFE8B47A));
    }
    _grass(c, const Offset(54, 62));
  }

  void _sign(Canvas c, bool star) {
    c.save();
    c.rotate(star ? .17 : -.12);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, 0, 6, 37), const Radius.circular(2)),
        Paint()..color = const Color(0xFFA77546));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-26, -15, 52, 29), const Radius.circular(5)),
        Paint()..color = const Color(0xFFD99A5F));
    for (var i = 0; i < 3; i++) {
      c.drawLine(
          Offset(-24, -9.0 + i * 9),
          Offset(24, -9.0 + i * 9),
          Paint()
            ..color = const Color(0xFFBF844F)
            ..strokeWidth = 1.2);
    }
    final icon = star ? Icons.star_rounded : Icons.pets_rounded;
    final text = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: 24,
                color:
                    star ? const Color(0xFFFFD46A) : const Color(0xFF9B6339))),
        textDirection: TextDirection.ltr)
      ..layout();
    text.paint(c, Offset(-text.width / 2, -text.height / 2));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant LearningMapScenery oldDelegate) =>
      oldDelegate.points != points;
}

enum _SceneryKind { forest, cloud, pond, sign, smallForest }
