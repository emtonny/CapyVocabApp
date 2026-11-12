import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bộ màu cho từng hạng.
class LaurelStyle {
  const LaurelStyle({
    required this.leafLight,
    required this.leafDark,
    required this.outline,
    required this.ribbon,
    required this.glow,
    required this.leavesPerSide,
  });

  final Color leafLight;
  final Color leafDark;
  final Color outline;
  final Color ribbon;
  final Color glow;
  final int leavesPerSide;

  /// Top 1 – Vàng, nơ đỏ, nhiều lá nhất.
  static const gold = LaurelStyle(
    leafLight: Color(0xFFFFE680),
    leafDark: Color(0xFFF2B01E),
    outline: Color(0xFF9A6400),
    ribbon: Color(0xFFE85D5D),
    glow: Color(0xFFFFC83D),
    leavesPerSide: 9,
  );

  /// Top 2 – Bạc, nơ xanh (hợp với card xanh nhạt).
  static const silver = LaurelStyle(
    leafLight: Color(0xFFF4F7FB),
    leafDark: Color(0xFFAAB6C6),
    outline: Color(0xFF5E6B7D),
    ribbon: Color(0xFF5B8DEF),
    glow: Color(0xFFB9C8DC),
    leavesPerSide: 6,
  );

  /// Top 3 – Đồng, nơ cam san hô (hợp với card hồng nhạt).
  static const bronze = LaurelStyle(
    leafLight: Color(0xFFF6C49A),
    leafDark: Color(0xFFC77B45),
    outline: Color(0xFF7A4220),
    ribbon: Color(0xFFE9806A),
    glow: Color(0xFFE6A273),
    leavesPerSide: 4,
  );

  /// Lấy style theo thứ hạng (1, 2, 3). Hạng khác trả về null.
  static LaurelStyle? forRank(int rank) => switch (rank) {
        1 => gold,
        2 => silver,
        3 => bronze,
        _ => null,
      };
}

/// Avatar có vòng nguyệt quế bao quanh – dùng cho Top 1, 2, 3.
///
/// Ví dụ:
/// ```dart
/// LaurelAvatar.rank(
///   rank: 1,
///   size: 96,
///   child: Image.network(user.avatarUrl, fit: BoxFit.cover),
/// )
/// ```
class LaurelAvatar extends StatefulWidget {
  const LaurelAvatar({
    super.key,
    required this.child,
    this.style = LaurelStyle.gold,
    this.size = 96,
    this.avatarRatio = 0.56,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1400),
    this.showWreath = true,
  });

  /// Tạo theo thứ hạng: 1 = vàng, 2 = bạc, 3 = đồng.
  /// Hạng ngoài top 3 vẫn dùng được nhưng sẽ chỉ hiện avatar (không có vòng).
  factory LaurelAvatar.rank({
    Key? key,
    required int rank,
    required Widget child,
    double size = 96,
    double avatarRatio = 0.56,
    bool animate = true,
  }) {
    final style = LaurelStyle.forRank(rank);
    return LaurelAvatar(
      key: key,
      style: style ?? LaurelStyle.gold,
      size: size,
      avatarRatio: avatarRatio,
      // Top 1 mọc chậm hơn chút cho nổi bật
      duration: Duration(milliseconds: rank == 1 ? 1400 : 1100),
      animate: animate,
      showWreath: style != null,
      child: child,
    );
  }

  final Widget child;
  final LaurelStyle style;

  /// Kích thước tổng (vuông) của cả vòng.
  final double size;

  /// Đường kính avatar so với [size].
  final double avatarRatio;

  /// Hiệu ứng nhánh lá "mọc" lên khi xuất hiện.
  final bool animate;
  final Duration duration;

  /// Có vẽ vòng nguyệt quế hay không.
  final bool showWreath;

  @override
  State<LaurelAvatar> createState() => _LaurelAvatarState();
}

class _LaurelAvatarState extends State<LaurelAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.animate ? 0 : 1,
  );
  late final CurvedAnimation _progress =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LaurelAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (!widget.animate) {
      _controller.stop();
      _controller.value = 1;
    } else if (!oldWidget.animate) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.style;
    final avatarSize = widget.size * widget.avatarRatio;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showWreath)
            AnimatedBuilder(
              animation: _progress,
              builder: (_, __) => CustomPaint(
                size: Size.square(widget.size),
                painter: LaurelWreathPainter(
                  progress: _progress.value,
                  leafLight: st.leafLight,
                  leafDark: st.leafDark,
                  outline: st.outline,
                  ribbon: st.ribbon,
                  leavesPerSide: st.leavesPerSide,
                ),
              ),
            ),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.showWreath ? st.outline : const Color(0xFF3A3A3A),
                width: 2,
              ),
              boxShadow: widget.showWreath
                  ? [
                      BoxShadow(
                        color: st.glow.withAlpha(120),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(child: widget.child),
          ),
        ],
      ),
    );
  }
}

/// Vẽ vòng nguyệt quế: 2 nhánh đối xứng mọc từ dưới lên + nơ ở chân.
class LaurelWreathPainter extends CustomPainter {
  LaurelWreathPainter({
    required this.progress,
    required this.leafLight,
    required this.leafDark,
    required this.outline,
    required this.ribbon,
    this.leavesPerSide = 7,
  });

  /// 0 → 1: mức độ "mọc" của nhánh lá.
  final double progress;
  final Color leafLight;
  final Color leafDark;
  final Color outline;
  final Color ribbon;
  final int leavesPerSide;

  // Góc trong Flutter: 0 = phải, pi/2 = dưới, pi = trái (theo chiều kim đồng hồ).
  static const double _startAngle = math.pi / 2 + 0.24; // gần đáy
  static const double _endAngle =
      3 * math.pi / 2 - 0.42; // gần đỉnh, chừa chỗ cho vương miện
  static const double _sweep = _endAngle - _startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final r = s / 2 * 0.74;

    // Nhánh trái
    _drawBranch(canvas, c, r, s);

    // Nhánh phải = lật gương nhánh trái
    canvas.save();
    canvas.translate(c.dx, 0);
    canvas.scale(-1, 1);
    canvas.translate(-c.dx, 0);
    _drawBranch(canvas, c, r, s);
    canvas.restore();

    _drawRibbon(canvas, Offset(c.dx, c.dy + r), s);
  }

  void _drawBranch(Canvas canvas, Offset c, double r, double s) {
    final sweepNow = _sweep * progress;
    if (sweepNow <= 0) return;

    // Thân cành: viền tối + lõi vàng
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      _startAngle,
      sweepNow,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.034
        ..color = outline,
    );
    canvas.drawArc(
      rect,
      _startAngle,
      sweepNow,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.022
        ..color = leafDark,
    );

    // Các cặp lá dọc theo cành, nhỏ dần về phía ngọn
    for (var i = 0; i < leavesPerSide; i++) {
      final t = (i + 0.5) / (leavesPerSide + 0.4);
      final pop = _pop(t);
      if (pop <= 0) continue;

      final shrink = 1.0 - 0.38 * t;
      final baseLen = s * 0.17 * shrink * pop;
      final theta = _startAngle + _sweep * t;
      final tangent = theta + math.pi / 2; // hướng cành đang mọc

      // Lá ngoài
      _drawLeaf(canvas, _onCircle(c, r, theta), tangent - 0.78, baseLen, s);
      // Lá trong, lệch nhẹ để tạo nhịp so le
      final thetaIn = theta + _sweep * 0.035;
      _drawLeaf(
          canvas, _onCircle(c, r, thetaIn), tangent + 0.72, baseLen * 0.82, s);
    }

    // Lá ngọn
    final tipPop = _pop(0.97);
    if (tipPop > 0) {
      _drawLeaf(canvas, _onCircle(c, r, _endAngle), _endAngle + math.pi / 2,
          s * 0.12 * tipPop, s);
    }
  }

  /// Độ "nảy" của lá ở vị trí t khi cành mọc tới.
  double _pop(double t) {
    final local = ((progress - t) / 0.14).clamp(0.0, 1.0);
    return local == 0 ? 0 : Curves.easeOutBack.transform(local);
  }

  Offset _onCircle(Offset c, double r, double angle) =>
      c + Offset(math.cos(angle) * r, math.sin(angle) * r);

  void _drawLeaf(
      Canvas canvas, Offset base, double angle, double len, double s) {
    if (len <= 0.5) return;
    final w = len * 0.56; // bề rộng thực tế ≈ w/2 mỗi bên

    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.45, -w, len, 0)
      ..quadraticBezierTo(len * 0.45, w, 0, 0)
      ..close();

    // Tô gradient vàng
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [leafLight, leafDark],
        ).createShader(Rect.fromLTWH(0, -w / 2, len, w)),
    );

    // Viền tối (đồng bộ phong cách cartoon của app)
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s * 0.012
        ..color = outline,
    );

    // Gân lá
    canvas.drawLine(
      Offset(len * 0.15, 0),
      Offset(len * 0.78, 0),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.009
        ..color = outline.withAlpha(120),
    );

    // Ánh sáng nhỏ trên lá
    canvas.drawLine(
      Offset(len * 0.3, -w * 0.17),
      Offset(len * 0.55, -w * 0.2),
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.008
        ..color = Colors.white.withAlpha(170),
    );

    canvas.restore();
  }

  void _drawRibbon(Canvas canvas, Offset knot, double s) {
    final appear = ((progress - 0.05) / 0.2).clamp(0.0, 1.0);
    if (appear <= 0) return;

    final fill = Paint()..color = ribbon;
    final dark = Paint()..color = Color.lerp(ribbon, Colors.black, 0.25)!;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.012
      ..color = outline;

    final tailLen = s * 0.13 * appear;
    final hw = s * 0.032;

    for (final dir in [const Offset(-0.5, 1), const Offset(0.5, 1)]) {
      final d = dir / dir.distance;
      final n = Offset(-d.dy, d.dx);
      final end = knot + d * tailLen;
      final tail = Path()
        ..moveTo((knot + n * hw).dx, (knot + n * hw).dy)
        ..lineTo((end + n * hw).dx, (end + n * hw).dy)
        ..lineTo((end - d * hw * 1.1).dx, (end - d * hw * 1.1).dy) // khía chữ V
        ..lineTo((end - n * hw).dx, (end - n * hw).dy)
        ..lineTo((knot - n * hw).dx, (knot - n * hw).dy)
        ..close();
      canvas.drawPath(tail, dir.dx < 0 ? fill : dark);
      canvas.drawPath(tail, stroke);
    }

    // Nút thắt
    final knotRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: knot, width: s * 0.09, height: s * 0.07),
      Radius.circular(s * 0.025),
    );
    canvas.drawRRect(knotRect, fill);
    canvas.drawRRect(knotRect, stroke);
  }

  @override
  bool shouldRepaint(covariant LaurelWreathPainter old) =>
      old.progress != progress ||
      old.leafLight != leafLight ||
      old.leafDark != leafDark ||
      old.outline != outline ||
      old.ribbon != ribbon ||
      old.leavesPerSide != leavesPerSide;
}
