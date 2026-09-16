import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A tactile sticker-style 3D button with crisp ink outline and press physics.
class StickerButton extends StatefulWidget {
  const StickerButton({
    super.key,
    this.text,
    this.label,
    this.semanticLabel,
    this.onPressed,
    this.icon,
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.textColor,
    this.edgeColor,
    this.borderColor = const Color(0xFF3A2E2B),
    this.padding = const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
    this.fontSize = 12,
    this.radius = 12,
    this.minHeight,
    this.expand = false,
    this.isExpanded,
    this.flat = false,
    this.showShadow = true,
  })  : assert(
          text != null || label != null || icon != null,
          'Text, label, or icon must be provided',
        ),
        assert(
          text != null || label != null || semanticLabel != null,
          'Icon-only buttons require a semanticLabel',
        );

  final String? text;
  final String? label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color surfaceColor;
  final Color? textColor;
  final Color? edgeColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double radius;
  final double? minHeight;
  final bool expand;
  final bool? isExpanded;
  final bool flat;
  final bool showShadow;

  String get displayText => text ?? label ?? '';

  @override
  State<StickerButton> createState() => _StickerButtonState();
}

class _StickerButtonState extends State<StickerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isHeld = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
      reverseCurve: Curves.easeInQuad,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TickerFuture? _currentAnimation;

  void _handlePressDown() {
    if (widget.onPressed == null) return;
    _isHeld = true;
    _currentAnimation = _controller.forward();
  }

  Future<void> _handlePressUp() async {
    if (widget.onPressed == null) return;
    _isHeld = false;
    try {
      if (_controller.status == AnimationStatus.forward) {
        await _currentAnimation?.orCancel;
      }
    } catch (_) {}
    if (mounted && !_isHeld) {
      _controller.reverse();
    }
  }

  void _handlePressCancel() {
    _isHeld = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final surface = widget.surfaceColor;
    final inkCoffee = widget.borderColor;
    final grayShadow = widget.edgeColor ??
        (surface == const Color(0xFFFFFFFF)
            ? const Color(0xFFCCCCCC)
            : HSLColor.fromColor(surface)
                .withLightness(
                  (HSLColor.fromColor(surface).lightness * 0.78)
                      .clamp(0.0, 1.0),
                )
                .toColor());
    final effectiveTextColor = widget.textColor ??
        (surface.computeLuminance() < 0.45 ? Colors.white : inkCoffee);

    Widget content = Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.displayText,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: enabled ? (_) => _handlePressDown() : null,
          onPointerUp: enabled ? (_) => _handlePressUp() : null,
          onPointerCancel: enabled ? (_) => _handlePressCancel() : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _handlePressDown() : null,
            onTapUp: enabled ? (_) => _handlePressUp() : null,
            onTapCancel: enabled ? () => _handlePressCancel() : null,
            onTap: widget.onPressed,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final value = _animation.value;
                final translateY = lerpDouble(0, widget.flat ? 2 : 3, value)!;
                final bottomBorder =
                    widget.flat ? 0.0 : lerpDouble(5, 2, value)!;
                final shadowOffset = lerpDouble(
                  widget.flat ? 3 : 4,
                  1,
                  value,
                )!;

                return AnimatedContainer(
                  key: const Key('sticker-button-motion'),
                  duration: Duration.zero,
                  transform: Matrix4.translationValues(0, translateY, 0),
                  child: CustomPaint(
                    key: const Key('sticker-button-painter'),
                    painter: StickerButtonPainter(
                      surface: surface,
                      inkCoffee: inkCoffee,
                      grayShadow: grayShadow,
                      bottomBorderWidth: bottomBorder,
                      shadowOffset: shadowOffset,
                      radius: widget.radius,
                      shadowSpread: widget.flat ? 0 : 2,
                      flat: widget.flat,
                      showShadow: widget.showShadow,
                    ),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        widget.flat ? 0 : (2 - bottomBorder) / 2,
                      ),
                      child: Padding(
                        padding: widget.padding,
                        child: Row(
                          key: const Key('sticker-button-content'),
                          mainAxisSize: (widget.isExpanded ?? widget.expand)
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              IconTheme(
                                data: IconThemeData(
                                  color: effectiveTextColor,
                                  size: widget.fontSize + 2,
                                ),
                                child: widget.icon!,
                              ),
                              if (widget.displayText.isNotEmpty)
                                const SizedBox(width: 6),
                            ],
                            if (widget.displayText.isNotEmpty)
                              Flexible(
                                child: Text(
                                  widget.displayText,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontSize: widget.fontSize,
                                    fontWeight: FontWeight.w700,
                                    color: effectiveTextColor,
                                    height: 1,
                                  ).copyWith(
                                    fontFamilyFallback: const [
                                      'Nunito',
                                      'Roboto',
                                      'Arial',
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (widget.minHeight != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.minHeight!),
        child: content,
      );
    }

    return content;
  }
}

class StickerButtonPainter extends CustomPainter {
  const StickerButtonPainter({
    required this.surface,
    required this.inkCoffee,
    required this.grayShadow,
    required this.bottomBorderWidth,
    required this.shadowOffset,
    this.radius = 12,
    this.borderWidth = 2,
    this.shadowSpread = 2,
    this.flat = false,
    this.showShadow = true,
  });

  final Color surface;
  final Color inkCoffee;
  final Color grayShadow;

  final double bottomBorderWidth;
  final double shadowOffset;

  final double radius;
  final double borderWidth;
  final double shadowSpread;
  final bool flat;
  final bool showShadow;

  // Backward-compatible getters
  double get bottomEdgeThickness => bottomBorderWidth;
  Color get faceColor => surface;
  Color get edgeColor => grayShadow;
  Color get outlineColor => inkCoffee;
  double get shadowBlurRadius => 0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (flat) {
      final shape = RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius),
      );
      if (showShadow) {
        canvas.drawRRect(
          shape.shift(Offset(0, shadowOffset)),
          Paint()
            ..color = inkCoffee.withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawRRect(
        shape,
        Paint()
          ..color = surface
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        shape,
        Paint()
          ..color = inkCoffee
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );
      return;
    }

    // ─────────────────────────────────────
    // 1. Lớp bao nâu bên ngoài shadow
    // CSS:
    // 0 4px 0 2px var(--ink-coffee)
    // ─────────────────────────────────────
    if (showShadow) {
      final shadowRect = rect.shift(
        Offset(0, shadowOffset),
      );

      final outerShadow = RRect.fromRectAndRadius(
        shadowRect.inflate(shadowSpread),
        Radius.circular(radius + shadowSpread),
      );

      canvas.drawRRect(
        outerShadow,
        Paint()
          ..color = inkCoffee
          ..style = PaintingStyle.fill,
      );

      // ─────────────────────────────────────
      // 2. Shadow xám
      // CSS:
      // 0 4px 0 var(--duo-gray-shadow)
      // ─────────────────────────────────────
      final grayShadowRRect = RRect.fromRectAndRadius(
        shadowRect,
        Radius.circular(radius),
      );

      canvas.drawRRect(
        grayShadowRRect,
        Paint()
          ..color = grayShadow
          ..style = PaintingStyle.fill,
      );
    }

    // ─────────────────────────────────────
    // 3. Toàn bộ thân nút ban đầu
    // ─────────────────────────────────────
    final buttonShape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(radius),
    );

    // Nền viền nâu
    canvas.drawRRect(
      buttonShape,
      Paint()
        ..color = inkCoffee
        ..style = PaintingStyle.fill,
    );

    canvas.save();

    // Không cho màu bên trong vượt khỏi radius.
    canvas.clipRRect(buttonShape);

    // ─────────────────────────────────────
    // 4. Cạnh dưới màu xám
    // border-bottom: 5px solid #CCCCCC
    // ─────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        size.height - bottomBorderWidth,
        size.width,
        size.height,
      ),
      Paint()
        ..color = grayShadow
        ..style = PaintingStyle.fill,
    );

    // ─────────────────────────────────────
    // 5. Mặt trắng của button
    //
    // Chừa:
    // - 2px top
    // - 2px left/right
    // - bottomBorderWidth ở dưới
    // ─────────────────────────────────────
    final innerRect = Rect.fromLTRB(
      borderWidth,
      borderWidth,
      size.width - borderWidth,
      size.height - bottomBorderWidth,
    );

    final innerShape = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(radius - borderWidth),
    );

    canvas.drawRRect(
      innerShape,
      Paint()
        ..color = surface
        ..style = PaintingStyle.fill,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StickerButtonPainter oldDelegate) {
    return oldDelegate.bottomBorderWidth != bottomBorderWidth ||
        oldDelegate.shadowOffset != shadowOffset ||
        oldDelegate.surface != surface ||
        oldDelegate.inkCoffee != inkCoffee ||
        oldDelegate.grayShadow != grayShadow ||
        oldDelegate.radius != radius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.shadowSpread != shadowSpread ||
        oldDelegate.flat != flat ||
        oldDelegate.showShadow != showShadow;
  }
}
