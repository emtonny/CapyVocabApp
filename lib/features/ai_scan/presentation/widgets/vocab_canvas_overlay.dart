import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../vocab_scan/domain/forbidden_zone_builder.dart';
import '../../../vocab_scan/domain/image_rect_calculator.dart';
import '../../../vocab_scan/domain/label_placement_solver.dart';
import '../../../vocab_scan/domain/label_size_measurer.dart';
import '../../../vocab_scan/domain/label_unit_geometry.dart';
import '../../../vocab_scan/presentation/label_connector_painter.dart';
import '../label_visual_style.dart';

const _darkBrown = Color(0xFF8F6E50);
const _meaningRed = Color(0xFFB00000);
const _cacheDoubleEpsilon = 0.000001;
const _deerBadgeMinimumGap = 2.0;
const _fixedBadgeWidth = 26.0;
const _fixedBadgeHeight = 16.0;
const _fixedBadgeCardOverlap = 8.0;
const _fixedLabelLineSpacing = 0.0;
const _fixedLabelTextHeight = 1.0;
const _fontFamilyFallback = [
  'Nunito',
  'Roboto',
  'Noto Sans',
  'Segoe UI',
  'Arial',
  'sans-serif',
];

const _fixedBadgeTextStyle = TextStyle(
  fontFamily: 'Nunito',
  fontFamilyFallback: _fontFamilyFallback,
  color: _darkBrown,
  fontSize: 8,
  fontWeight: FontWeight.w700,
);

// Matches the approved Task 7 visual baseline while making placement
// independent from preview, fullscreen, window, and InteractiveViewer sizes.
const _referenceCanvasWidth = 400.0;

const _fullLabelStyleConfig = LabelStyleConfig(
  badgeTextStyle: _fixedBadgeTextStyle,
  badgeWidth: _fixedBadgeWidth,
  badgeHeight: _fixedBadgeHeight,
  wordStyle: TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: _fontFamilyFallback,
    color: _darkBrown,
    fontSize: 7.5,
    fontWeight: FontWeight.w700,
    height: _fixedLabelTextHeight,
  ),
  phoneticStyle: TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: _fontFamilyFallback,
    color: _darkBrown,
    fontSize: 6.2,
    fontStyle: FontStyle.italic,
    height: _fixedLabelTextHeight,
  ),
  meaningStyle: TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: _fontFamilyFallback,
    color: _meaningRed,
    fontSize: 8,
    fontWeight: FontWeight.w700,
    height: _fixedLabelTextHeight,
  ),
  padding: LabelPaddingConfig(horizontal: 6, vertical: 12, bottom: 9),
  mode: LabelCardMode.full,
  lineSpacing: _fixedLabelLineSpacing,
  uniformLineRows: true,
  badgeLeftInset: 0,
  badgeCardOverlap: _fixedBadgeCardOverlap,
  deerStickerSize: Size.square(19),
  cookieIconSize: Size.square(15),
);

const _compactLabelStyleConfig = LabelStyleConfig(
  badgeTextStyle: _fixedBadgeTextStyle,
  badgeWidth: _fixedBadgeWidth,
  badgeHeight: _fixedBadgeHeight,
  wordStyle: TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: _fontFamilyFallback,
    color: _darkBrown,
    fontSize: 6.2,
    fontWeight: FontWeight.w700,
    height: _fixedLabelTextHeight,
  ),
  phoneticStyle: TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: _fontFamilyFallback,
    color: _darkBrown,
    fontSize: 5.5,
    fontStyle: FontStyle.italic,
    height: _fixedLabelTextHeight,
  ),
  meaningStyle: TextStyle(
    fontFamily: 'Nunito',
    fontFamilyFallback: _fontFamilyFallback,
    color: _meaningRed,
    fontSize: 6.5,
    fontWeight: FontWeight.w700,
    height: _fixedLabelTextHeight,
  ),
  padding: LabelPaddingConfig(horizontal: 4, vertical: 8, bottom: 7),
  mode: LabelCardMode.compact,
  lineSpacing: _fixedLabelLineSpacing,
  uniformLineRows: true,
  badgeLeftInset: 0,
  badgeCardOverlap: _fixedBadgeCardOverlap,
  deerStickerSize: Size.square(16),
  cookieIconSize: Size.square(12.5),
);

const _labelSizeMeasurer = LabelSizeMeasurer();

class VocabCanvasOverlay extends StatefulWidget {
  const VocabCanvasOverlay({
    required this.imageProvider,
    required this.words,
    this.sceneWords,
    this.ttsService,
    this.onLabelTap,
    this.visualStyle = LabelVisualStyle.standard,
    super.key,
  });

  final ImageProvider imageProvider;
  final List<VocabDetection> words;

  // Kept for compatibility with existing callers. Placement uses [words], and
  // speech remains caller-owned through [onLabelTap].
  final List<VocabDetection>? sceneWords;
  final TtsService? ttsService;
  final LabelVisualStyle visualStyle;

  /// Reports the label selected by hit-testing; audio playback stays with the
  /// caller and is intentionally outside this widget.
  final void Function(VocabDetection word)? onLabelTap;

  @override
  State<VocabCanvasOverlay> createState() => _VocabCanvasOverlayState();
}

class _VocabCanvasOverlayState extends State<VocabCanvasOverlay> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ui.Image? _image;
  Object? _loadError;
  final _placementCache = _PlacementCache();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant VocabCanvasOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    _removeImageListener();
    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (!mounted) return;

        void updateImage() {
          _image = imageInfo.image;
          _loadError = null;
        }

        if (synchronousCall) {
          updateImage();
        } else {
          setState(updateImage);
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() => _loadError = error);
      },
    );
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return const Center(child: Text('Không thể mở ảnh đã quét.'));
    }

    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final sourceSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = _resolveCanvasSize(
          constraints,
          sourceSize.width / sourceSize.height,
        );
        if (canvasSize.isEmpty) {
          return SizedBox.fromSize(size: canvasSize);
        }
        final imageRect = ImageRectCalculator.calculate(
          sourceImageSize: sourceSize,
          canvasSize: canvasSize,
        );
        final referenceCanvasSize = _calculateReferenceCanvasSize(sourceSize);
        final fullStyleConfig = _resolveVisualStyle(
          _fullLabelStyleConfig,
          widget.visualStyle,
        );
        final compactStyleConfig = _resolveVisualStyle(
          _compactLabelStyleConfig,
          widget.visualStyle,
        );
        final placedLabels = _placementCache.resolve(
          words: widget.words,
          sourceImageSize: sourceSize,
          fullStyleConfig: fullStyleConfig,
          compactStyleConfig: compactStyleConfig,
        );
        final customPaint = CustomPaint(
          painter: VocabOverlayPainter(
            words: widget.words,
            imageRect: imageRect,
            placedLabels: placedLabels,
            referenceCanvasSize: referenceCanvasSize,
            fullStyleConfig: fullStyleConfig,
            compactStyleConfig: compactStyleConfig,
            visualStyle: widget.visualStyle,
            solveInvocationCount: _placementCache.solveInvocationCount,
          ),
        );
        final overlay = widget.onLabelTap == null
            ? IgnorePointer(child: customPaint)
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) => _handleLabelTap(
                  canvasPosition: details.localPosition,
                  imageRect: imageRect,
                  referenceCanvasSize: referenceCanvasSize,
                  placedLabels: placedLabels,
                  fullStyleConfig: fullStyleConfig,
                  compactStyleConfig: compactStyleConfig,
                ),
                child: customPaint,
              );

        return Center(
          child: SizedBox.fromSize(
            size: canvasSize,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: imageRect,
                  child: Image(
                    image: widget.imageProvider,
                    fit: BoxFit.fill,
                  ),
                ),
                overlay,
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleLabelTap({
    required Offset canvasPosition,
    required Rect imageRect,
    required Size referenceCanvasSize,
    required List<PlacedLabel> placedLabels,
    required LabelStyleConfig fullStyleConfig,
    required LabelStyleConfig compactStyleConfig,
  }) {
    final callback = widget.onLabelTap;
    if (callback == null) return;

    final referencePosition = _OverlayViewportTransform(
      referenceSize: referenceCanvasSize,
      viewportRect: imageRect,
    ).toReference(canvasPosition);
    if (referencePosition == null) return;

    // Later labels are painted on top, so they receive taps first if the
    // audited last-resort fallback allowed two cards to overlap.
    for (final placedLabel in placedLabels.reversed) {
      final config = _styleForQuality(
        placedLabel.quality,
        fullStyleConfig: fullStyleConfig,
        compactStyleConfig: compactStyleConfig,
      );
      final geometry = _resolvePlacedGeometry(
        placedLabel,
        fullStyleConfig: fullStyleConfig,
        compactStyleConfig: compactStyleConfig,
      );
      if (geometry.containsVisiblePoint(
        referencePosition,
        includeDeerSticker: _shouldShowDeerSticker(
          word: placedLabel.word,
          config: config,
          geometry: geometry,
        ),
      )) {
        callback(placedLabel.word);
        return;
      }
    }
  }

  Size _resolveCanvasSize(BoxConstraints constraints, double aspectRatio) {
    if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    if (constraints.hasBoundedWidth) {
      return Size(constraints.maxWidth, constraints.maxWidth / aspectRatio);
    }
    if (constraints.hasBoundedHeight) {
      return Size(constraints.maxHeight * aspectRatio, constraints.maxHeight);
    }
    return Size(_image!.width.toDouble(), _image!.height.toDouble());
  }
}

class VocabOverlayPainter extends CustomPainter {
  const VocabOverlayPainter({
    required this.words,
    required this.imageRect,
    this.placedLabels = const [],
    this.referenceCanvasSize,
    this.fullStyleConfig = _fullLabelStyleConfig,
    this.compactStyleConfig = _compactLabelStyleConfig,
    this.visualStyle = LabelVisualStyle.standard,
    this.solveInvocationCount = 0,
  });

  final List<VocabDetection> words;
  final Rect imageRect;
  final List<PlacedLabel> placedLabels;

  /// When set, [placedLabels] are in this stable reference coordinate space.
  /// The complete overlay is uniformly scaled into [imageRect] at paint time.
  /// A null value preserves the legacy direct-painter coordinate contract.
  final Size? referenceCanvasSize;
  final LabelStyleConfig fullStyleConfig;
  final LabelStyleConfig compactStyleConfig;
  final LabelVisualStyle visualStyle;

  /// Exposed for regression tests; incremented immediately before [solve].
  /// Placement is computed by widget state, never from [paint].
  final int solveInvocationCount;

  List<Rect> get boxes {
    final referenceSize = referenceCanvasSize;
    if (referenceSize == null) {
      return List.unmodifiable(
        words.map(
          (word) => ImageRectCalculator.detectionRect(
            detection: word,
            imageRect: imageRect,
          ),
        ),
      );
    }

    final transform = _OverlayViewportTransform(
      referenceSize: referenceSize,
      viewportRect: imageRect,
    );
    final referenceImageRect = Offset.zero & referenceSize;
    return List.unmodifiable(
      words.map(
        (word) => transform.toCanvasRect(
          ImageRectCalculator.detectionRect(
            detection: word,
            imageRect: referenceImageRect,
          ),
        ),
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final referenceSize = referenceCanvasSize;
    if (referenceSize == null) {
      _paintOverlay(canvas, boxes, canvasSize: size);
      return;
    }

    final transform = _OverlayViewportTransform(
      referenceSize: referenceSize,
      viewportRect: imageRect,
    );
    final referenceImageRect = Offset.zero & referenceSize;
    final referenceBoxes = List<Rect>.unmodifiable(
      words.map(
        (word) => ImageRectCalculator.detectionRect(
          detection: word,
          imageRect: referenceImageRect,
        ),
      ),
    );

    canvas.save();
    // Scaling the canvas keeps geometry, text, corners, and strokes in one
    // coordinate system instead of rebuilding or selectively resizing them.
    transform.applyTo(canvas);
    _paintOverlay(canvas, referenceBoxes, canvasSize: referenceSize);
    canvas.restore();
  }

  void _paintOverlay(
    Canvas canvas,
    List<Rect> boxesToPaint, {
    required Size canvasSize,
  }) {
    final fillPaint = Paint()
      ..color = visualStyle.objectFillColor.withValues(
        alpha: visualStyle.objectFillOpacity,
      );
    final borderPaint = Paint()
      ..color = visualStyle.objectBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (visualStyle.showBoundingBox) {
      for (final box in boxesToPaint) {
        final roundedBox = RRect.fromRectAndRadius(
          box,
          const Radius.circular(4),
        );
        canvas
          ..drawRRect(roundedBox, fillPaint)
          ..drawRRect(roundedBox, borderPaint);
      }
    }

    paintAllConnectors(
      canvas,
      placedLabels,
      labelRectResolver: (placed) => geometryFor(placed).cardRect,
      canvasSize: canvasSize,
      color: visualStyle.connectorColor,
      haloColor: visualStyle.connectorHaloColor,
      strokeWidth: visualStyle.connectorThickness.value,
      lineStyle: visualStyle.connectorLineStyle,
      arrowStyle: visualStyle.connectorArrowStyle,
      showHalo: visualStyle.showConnectorHalo,
    );
    for (final placedLabel in placedLabels) {
      _paintLabelCard(canvas, placedLabel);
    }
  }

  LabelUnitGeometry geometryFor(PlacedLabel placedLabel) {
    return _resolvePlacedGeometry(
      placedLabel,
      fullStyleConfig: fullStyleConfig,
      compactStyleConfig: compactStyleConfig,
    );
  }

  bool shouldPaintDeerFor(PlacedLabel placedLabel) {
    final config = _styleForQuality(
      placedLabel.quality,
      fullStyleConfig: fullStyleConfig,
      compactStyleConfig: compactStyleConfig,
    );
    return _shouldShowDeerSticker(
      word: placedLabel.word,
      config: config,
      geometry: geometryFor(placedLabel),
    );
  }

  void _paintLabelCard(Canvas canvas, PlacedLabel placedLabel) {
    final config = _styleForQuality(
      placedLabel.quality,
      fullStyleConfig: fullStyleConfig,
      compactStyleConfig: compactStyleConfig,
    );
    final geometry = geometryFor(placedLabel);
    canvas.save();
    canvas.clipRect(geometry.footprintRect, doAntiAlias: false);
    final borderColor = visualStyle.borderColor;
    final borderWidth = visualStyle.borderThickness.value;
    final cardRadius = switch (visualStyle.cornerStyle) {
      LabelCornerStyle.square => 0.0,
      LabelCornerStyle.soft => geometry.cardRect.height * 0.28,
      LabelCornerStyle.round => geometry.cardRect.height / 2,
    };
    final roundedCard = RRect.fromRectAndRadius(
      geometry.cardRect,
      Radius.circular(cardRadius),
    );
    final fillPaint = Paint()
      ..color = visualStyle.cardColor.withValues(
        alpha: visualStyle.cardOpacity,
      );
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    final insetCardBorder = RRect.fromRectAndRadius(
      geometry.cardRect.deflate(borderWidth / 2),
      Radius.circular(math.max(0, cardRadius - borderWidth / 2)),
    );

    canvas
      ..drawRRect(roundedCard, fillPaint)
      ..drawRRect(insetCardBorder, borderPaint);

    // The badge is intentionally painted after the card so its complete pill
    // border stays on the upper layer at the card's top-left edge.
    _paintNumberBadge(
      canvas,
      geometry.badgeRect,
      number: placedLabel.word.number,
      config: config,
    );

    final deerStickerRect = geometry.deerStickerRect;
    if (deerStickerRect != null &&
        _shouldShowDeerSticker(
          word: placedLabel.word,
          config: config,
          geometry: geometry,
        )) {
      _paintSticker(canvas, deerStickerRect);
    }
    final cookieIconRect = geometry.cookieIconRect;
    if (cookieIconRect != null) {
      _paintCornerIcon(canvas, cookieIconRect);
    }

    final contentLeft = geometry.cardRect.left + config.padding.horizontal;
    final lines = [
      (placedLabel.word.word, config.wordStyle),
      (placedLabel.word.phonetic, config.phoneticStyle),
      (placedLabel.word.meaningVi, config.meaningStyle),
    ];
    final painters = [
      for (final line in lines)
        _createLinePainter(
          text: line.$1,
          style: line.$2,
          textDirection: config.textDirection,
        ),
    ];
    final contentTop = geometry.cardRect.top + config.padding.vertical;
    if (config.uniformLineRows) {
      final lineLayout = resolveLabelLineLayout(
        lineHeights: [
          math.max(painters.first.height, config.iconWidth ?? 0),
          ...painters.skip(1).map((painter) => painter.height),
        ],
        lineSpacing: config.lineSpacing,
      );
      for (var index = 0; index < painters.length; index++) {
        final painter = painters[index];
        final lineTop =
            contentTop + lineLayout.centeredLineTop(index, painter.height);
        painter
          ..paint(canvas, Offset(contentLeft, lineTop))
          ..dispose();
      }
    } else {
      var lineTop = contentTop;
      for (var index = 0; index < painters.length; index++) {
        final painter = painters[index];
        final lineHeight = painter.height;
        painter
          ..paint(canvas, Offset(contentLeft, lineTop))
          ..dispose();
        lineTop += lineHeight;
        if (index < painters.length - 1) lineTop += config.lineSpacing;
      }
    }

    canvas.restore();
  }

  void _paintNumberBadge(
    Canvas canvas,
    Rect badgeRect, {
    required int number,
    required LabelStyleConfig config,
  }) {
    final borderWidth = visualStyle.badgeBorderThickness.value;
    final fillPaint = Paint()..color = visualStyle.badgeColor;
    final borderPaint = Paint()
      ..color = visualStyle.badgeBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    final radius = switch (visualStyle.badgeShape) {
      LabelBadgeShape.square => 0.0,
      LabelBadgeShape.soft => badgeRect.height * 0.25,
      LabelBadgeShape.pill => badgeRect.height / 2,
    };
    final badge = RRect.fromRectAndRadius(
      badgeRect,
      Radius.circular(radius),
    );
    final insetBadgeBorder = RRect.fromRectAndRadius(
      badgeRect.deflate(borderWidth / 2),
      Radius.circular(math.max(0, radius - borderWidth / 2)),
    );
    canvas
      ..drawRRect(badge, fillPaint)
      ..drawRRect(insetBadgeBorder, borderPaint);

    final numberPainter = _createLinePainter(
      text: number.toString().padLeft(2, '0'),
      style: config.badgeTextStyle,
      textDirection: config.textDirection,
    );
    numberPainter
      ..paint(
        canvas,
        badgeRect.center -
            Offset(numberPainter.width / 2, numberPainter.height / 2),
      )
      ..dispose();
  }

  void _paintSticker(Canvas canvas, Rect targetRect) {
    switch (visualStyle.sticker) {
      case LabelSticker.none:
        return;
      case LabelSticker.deer:
        _paintDeerSticker(canvas, targetRect);
      case LabelSticker.capybara:
        _paintCapybaraSticker(canvas, targetRect);
      case LabelSticker.star:
        _paintStarSticker(canvas, targetRect);
      case LabelSticker.book:
        _paintBookSticker(canvas, targetRect);
    }
  }

  void _paintCornerIcon(Canvas canvas, Rect targetRect) {
    switch (visualStyle.cornerIcon) {
      case LabelCornerIcon.none:
        return;
      case LabelCornerIcon.cookie:
        _paintCookieIcon(canvas, targetRect);
      case LabelCornerIcon.pin:
        _paintPinIcon(canvas, targetRect);
      case LabelCornerIcon.heart:
        _paintHeartIcon(canvas, targetRect);
    }
  }

  void _paintDeerSticker(Canvas canvas, Rect targetRect) {
    const designSize = 24.0;
    final scale = math.min(
      targetRect.width / designSize,
      targetRect.height / designSize,
    );
    canvas.save();
    canvas.clipRect(targetRect, doAntiAlias: false);
    canvas.translate(
      targetRect.left + (targetRect.width - designSize * scale) / 2,
      targetRect.top + (targetRect.height - designSize * scale) / 2,
    );
    canvas.scale(scale);

    final outline = Paint()
      ..color = const Color(0xFF8A4B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fur = Paint()..color = const Color(0xFFC77B46);
    final lightFur = Paint()..color = const Color(0xFFF5C995);
    final dark = Paint()..color = const Color(0xFF4A2A1D);

    final antlers = Path()
      ..moveTo(7.5, 5)
      ..lineTo(6.2, 1.2)
      ..moveTo(6.4, 2.2)
      ..lineTo(4.2, 1)
      ..moveTo(9.5, 4.8)
      ..lineTo(10.8, 1.1)
      ..moveTo(10.5, 2.2)
      ..lineTo(12.8, 1.2);
    canvas.drawPath(antlers, outline);

    final tail = Path()
      ..moveTo(19.2, 13)
      ..lineTo(23, 11.2)
      ..lineTo(21.2, 15.2)
      ..close();
    canvas
      ..drawPath(tail, lightFur)
      ..drawPath(tail, outline)
      ..drawOval(const Rect.fromLTWH(9, 11.5, 11.5, 7.2), fur)
      ..drawOval(const Rect.fromLTWH(9, 11.5, 11.5, 7.2), outline)
      ..drawOval(const Rect.fromLTWH(6, 6, 6.5, 9), fur)
      ..drawOval(const Rect.fromLTWH(6, 6, 6.5, 9), outline)
      ..drawOval(const Rect.fromLTWH(3.2, 4.1, 8.5, 8.2), fur)
      ..drawOval(const Rect.fromLTWH(3.2, 4.1, 8.5, 8.2), outline);

    final leftEar = Path()
      ..moveTo(4.7, 5.8)
      ..lineTo(1.2, 3.5)
      ..lineTo(2.1, 7.5)
      ..close();
    final rightEar = Path()
      ..moveTo(10, 5.4)
      ..lineTo(13.8, 3.2)
      ..lineTo(12.2, 7.3)
      ..close();
    canvas
      ..drawPath(leftEar, fur)
      ..drawPath(leftEar, outline)
      ..drawPath(rightEar, fur)
      ..drawPath(rightEar, outline)
      ..drawOval(const Rect.fromLTWH(1.5, 8.1, 6.7, 4.7), lightFur)
      ..drawCircle(const Offset(4.1, 10.3), 0.75, dark)
      ..drawCircle(const Offset(8.8, 7.5), 0.65, dark)
      ..drawCircle(const Offset(12.6, 13.5), 0.9, lightFur)
      ..drawCircle(const Offset(16, 13.1), 0.8, lightFur)
      ..drawCircle(const Offset(18.3, 15.7), 0.7, lightFur);

    final legs = Path()
      ..moveTo(12, 17)
      ..lineTo(11.5, 22)
      ..lineTo(13.2, 22)
      ..moveTo(18, 17)
      ..lineTo(18.5, 22)
      ..lineTo(20.2, 22);
    canvas.drawPath(legs, outline);
    canvas.restore();
  }

  void _paintCookieIcon(Canvas canvas, Rect targetRect) {
    const designSize = 24.0;
    final scale = math.min(
      targetRect.width / designSize,
      targetRect.height / designSize,
    );
    canvas.save();
    canvas.clipRect(targetRect, doAntiAlias: false);
    canvas.translate(
      targetRect.left + (targetRect.width - designSize * scale) / 2,
      targetRect.top + (targetRect.height - designSize * scale) / 2,
    );
    canvas.scale(scale);

    final cookie = Paint()..color = const Color(0xFFD98A3D);
    final outline = Paint()
      ..color = const Color(0xFF8A431F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final chip = Paint()..color = const Color(0xFF6C321C);
    const cookieRect = Rect.fromLTWH(1.5, 1.5, 21, 21);
    canvas
      ..drawOval(cookieRect, cookie)
      ..drawOval(cookieRect, outline)
      ..drawCircle(const Offset(7, 7), 1.5, chip)
      ..drawCircle(const Offset(15.5, 6), 1.25, chip)
      ..drawCircle(const Offset(11.5, 12), 1.7, chip)
      ..drawCircle(const Offset(17.2, 16.2), 1.45, chip)
      ..drawCircle(const Offset(6.4, 17), 1.2, chip);
    canvas.restore();
  }

  void _paintCapybaraSticker(Canvas canvas, Rect targetRect) {
    _paintInDecorationSpace(canvas, targetRect, (canvas) {
      final outline = Paint()
        ..color = const Color(0xFF5A3927)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final fur = Paint()..color = const Color(0xFFA96F45);
      final muzzle = Paint()..color = const Color(0xFFD9A875);
      final dark = Paint()..color = const Color(0xFF3B281F);
      canvas
        ..drawOval(const Rect.fromLTWH(5, 9, 17, 11), fur)
        ..drawOval(const Rect.fromLTWH(5, 9, 17, 11), outline)
        ..drawOval(const Rect.fromLTWH(2, 5, 11, 12), fur)
        ..drawOval(const Rect.fromLTWH(2, 5, 11, 12), outline)
        ..drawCircle(const Offset(5.2, 5.2), 1.7, fur)
        ..drawCircle(const Offset(10.1, 5.5), 1.5, fur)
        ..drawOval(const Rect.fromLTWH(1, 10, 7, 4.5), muzzle)
        ..drawCircle(const Offset(3.1, 11.8), 0.7, dark)
        ..drawCircle(const Offset(7.5, 8.7), 0.65, dark)
        ..drawLine(const Offset(9, 19), const Offset(8.5, 22), outline)
        ..drawLine(const Offset(18, 19), const Offset(18.5, 22), outline);
    });
  }

  void _paintStarSticker(Canvas canvas, Rect targetRect) {
    _paintInDecorationSpace(canvas, targetRect, (canvas) {
      final star = Path();
      for (var index = 0; index < 10; index++) {
        final radius = index.isEven ? 10.5 : 4.8;
        final angle = -math.pi / 2 + index * math.pi / 5;
        final point = Offset(
          12 + math.cos(angle) * radius,
          12 + math.sin(angle) * radius,
        );
        if (index == 0) {
          star.moveTo(point.dx, point.dy);
        } else {
          star.lineTo(point.dx, point.dy);
        }
      }
      star.close();
      canvas
        ..drawPath(star, Paint()..color = const Color(0xFFFFC928))
        ..drawPath(
          star,
          Paint()
            ..color = const Color(0xFFC98600)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeJoin = StrokeJoin.round,
        );
    });
  }

  void _paintBookSticker(Canvas canvas, Rect targetRect) {
    _paintInDecorationSpace(canvas, targetRect, (canvas) {
      final cover = Paint()..color = const Color(0xFF5B8FC9);
      final pages = Paint()..color = const Color(0xFFFFF7DF);
      final outline = Paint()
        ..color = const Color(0xFF315A84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round;
      final leftPage = Path()
        ..moveTo(2, 5)
        ..quadraticBezierTo(7, 3, 11.5, 6)
        ..lineTo(11.5, 20)
        ..quadraticBezierTo(7, 17, 2, 19)
        ..close();
      final rightPage = Path()
        ..moveTo(22, 5)
        ..quadraticBezierTo(17, 3, 12.5, 6)
        ..lineTo(12.5, 20)
        ..quadraticBezierTo(17, 17, 22, 19)
        ..close();
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 4, 22, 17),
            const Radius.circular(2),
          ),
          cover,
        )
        ..drawPath(leftPage, pages)
        ..drawPath(rightPage, pages)
        ..drawPath(leftPage, outline)
        ..drawPath(rightPage, outline)
        ..drawLine(const Offset(12, 6), const Offset(12, 20), outline);
    });
  }

  void _paintPinIcon(Canvas canvas, Rect targetRect) {
    _paintInDecorationSpace(canvas, targetRect, (canvas) {
      final pin = Paint()..color = const Color(0xFFE25555);
      final outline = Paint()
        ..color = const Color(0xFF8F3030)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas
        ..drawCircle(const Offset(12, 8), 5.2, pin)
        ..drawCircle(const Offset(12, 8), 5.2, outline)
        ..drawLine(const Offset(12, 13), const Offset(12, 22), outline)
        ..drawLine(const Offset(9, 17), const Offset(15, 17), outline);
    });
  }

  void _paintHeartIcon(Canvas canvas, Rect targetRect) {
    _paintInDecorationSpace(canvas, targetRect, (canvas) {
      final heart = Path()
        ..moveTo(12, 21)
        ..cubicTo(9, 17, 3, 13, 3, 8)
        ..cubicTo(3, 3, 9, 2, 12, 6)
        ..cubicTo(15, 2, 21, 3, 21, 8)
        ..cubicTo(21, 13, 15, 17, 12, 21)
        ..close();
      canvas
        ..drawPath(heart, Paint()..color = const Color(0xFFF06B81))
        ..drawPath(
          heart,
          Paint()
            ..color = const Color(0xFFA83E55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
    });
  }

  void _paintInDecorationSpace(
    Canvas canvas,
    Rect targetRect,
    void Function(Canvas canvas) paint,
  ) {
    const designSize = 24.0;
    final scale = math.min(
      targetRect.width / designSize,
      targetRect.height / designSize,
    );
    canvas.save();
    canvas.clipRect(targetRect, doAntiAlias: false);
    canvas.translate(
      targetRect.left + (targetRect.width - designSize * scale) / 2,
      targetRect.top + (targetRect.height - designSize * scale) / 2,
    );
    canvas.scale(scale);
    paint(canvas);
    canvas.restore();
  }

  TextPainter _createLinePainter({
    required String text,
    required TextStyle style,
    required TextDirection textDirection,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant VocabOverlayPainter oldDelegate) {
    return oldDelegate.words != words ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.placedLabels != placedLabels ||
        oldDelegate.referenceCanvasSize != referenceCanvasSize ||
        oldDelegate.fullStyleConfig != fullStyleConfig ||
        oldDelegate.compactStyleConfig != compactStyleConfig ||
        oldDelegate.visualStyle != visualStyle;
  }
}

LabelStyleConfig _resolveVisualStyle(
  LabelStyleConfig base,
  LabelVisualStyle visualStyle,
) {
  return base.copyWith(
    badgeTextStyle:
        base.badgeTextStyle.copyWith(color: visualStyle.badgeTextColor),
    wordStyle: base.wordStyle.copyWith(color: visualStyle.textColor),
    phoneticStyle: base.phoneticStyle.copyWith(color: visualStyle.textColor),
    meaningStyle: base.meaningStyle.copyWith(color: visualStyle.meaningColor),
    deerStickerSize:
        visualStyle.showDeerSticker ? base.deerStickerSize : Size.zero,
    cookieIconSize:
        visualStyle.showCookieIcon ? base.cookieIconSize : Size.zero,
  );
}

LabelStyleConfig _styleForQuality(
  PlacementQuality quality, {
  required LabelStyleConfig fullStyleConfig,
  required LabelStyleConfig compactStyleConfig,
}) {
  return quality == PlacementQuality.ideal
      ? fullStyleConfig
      : compactStyleConfig;
}

bool _shouldShowDeerSticker({
  required VocabDetection word,
  required LabelStyleConfig config,
  required LabelUnitGeometry geometry,
}) {
  final deerStickerRect = geometry.deerStickerRect;
  if (deerStickerRect == null) return false;

  // Both decorations are anchored to opposite card edges, so this clearance
  // grows with the card width. Hide the deer when the top edge cannot fit the
  // badge, a safe gap, and the sticker without crowding each other.
  final horizontalClearance = deerStickerRect.left - geometry.badgeRect.right;
  if (horizontalClearance < _deerBadgeMinimumGap) return false;

  final lines = [
    (word.word, config.wordStyle),
    (word.phonetic, config.phoneticStyle),
    (word.meaningVi, config.meaningStyle),
  ];
  final contentLeft = geometry.cardRect.left + config.padding.horizontal;
  final painters = [
    for (final line in lines)
      TextPainter(
        text: TextSpan(text: line.$1, style: line.$2),
        maxLines: 1,
        textDirection: config.textDirection,
        textScaler: TextScaler.noScaling,
      )..layout(),
  ];
  final contentTop = geometry.cardRect.top + config.padding.vertical;
  var overlapsText = false;
  if (config.uniformLineRows) {
    final lineLayout = resolveLabelLineLayout(
      lineHeights: [
        math.max(painters.first.height, config.iconWidth ?? 0),
        ...painters.skip(1).map((painter) => painter.height),
      ],
      lineSpacing: config.lineSpacing,
    );
    for (var index = 0; index < painters.length; index++) {
      final painter = painters[index];
      final lineTop =
          contentTop + lineLayout.centeredLineTop(index, painter.height);
      final textRect = Offset(contentLeft, lineTop) & painter.size;
      if (deerStickerRect.overlaps(textRect.inflate(0.5))) {
        overlapsText = true;
        break;
      }
    }
  } else {
    var lineTop = contentTop;
    for (var index = 0; index < painters.length; index++) {
      final painter = painters[index];
      final textRect = Offset(contentLeft, lineTop) & painter.size;
      if (deerStickerRect.overlaps(textRect.inflate(0.5))) {
        overlapsText = true;
        break;
      }
      lineTop += painter.height;
      if (index < painters.length - 1) lineTop += config.lineSpacing;
    }
  }
  for (final painter in painters) {
    painter.dispose();
  }
  return !overlapsText;
}

LabelUnitGeometry _resolvePlacedGeometry(
  PlacedLabel placedLabel, {
  required LabelStyleConfig fullStyleConfig,
  required LabelStyleConfig compactStyleConfig,
}) {
  final config = _styleForQuality(
    placedLabel.quality,
    fullStyleConfig: fullStyleConfig,
    compactStyleConfig: compactStyleConfig,
  );
  return resolvePlacedLabelUnitGeometry(
    footprintRect: placedLabel.labelRect,
    badgeSize: config.badgeSize,
    badgeLeftInset: config.badgeLeftInset,
    badgeCardOverlap: config.badgeCardOverlap,
    deerStickerSize: config.deerStickerSize,
    cookieIconSize: config.cookieIconSize,
  );
}

class _PlacementCache {
  _PlacementCacheKey? _key;
  List<PlacedLabel> _placedLabels = const [];

  int solveInvocationCount = 0;

  List<PlacedLabel> resolve({
    required List<VocabDetection> words,
    required Size sourceImageSize,
    required LabelStyleConfig fullStyleConfig,
    required LabelStyleConfig compactStyleConfig,
  }) {
    final nextKey = _PlacementCacheKey.capture(
      words: words,
      sourceImageSize: sourceImageSize,
      fullStyleConfig: fullStyleConfig,
      compactStyleConfig: compactStyleConfig,
    );
    try {
      if (_key?.isEquivalentTo(nextKey) ?? false) return _placedLabels;
    } catch (_) {
      _key = null;
    }

    _key = nextKey;
    if (words.length > maxGeminiVocabularyWords) {
      _placedLabels = const [];
      return _placedLabels;
    }

    try {
      final referenceCanvasSize = _calculateReferenceCanvasSize(
        sourceImageSize,
      );
      final referenceImageRect = ImageRectCalculator.calculate(
        sourceImageSize: sourceImageSize,
        canvasSize: referenceCanvasSize,
      );
      final labelSizes = _labelSizeMeasurer.measureAll(
        words,
        fullStyleConfig,
      );
      final anchorBoxes = List<Rect>.unmodifiable(
        words.map(
          (word) => ImageRectCalculator.detectionRect(
            detection: word,
            imageRect: referenceImageRect,
          ),
        ),
      );
      final forbiddenZones = ForbiddenZoneBuilder.build(
        words: words,
        sourceImageSize: sourceImageSize,
        canvasSize: referenceCanvasSize,
      );
      solveInvocationCount++;
      _placedLabels = solve(
        words: words,
        labelSizes: labelSizes,
        anchorBoxes: anchorBoxes,
        forbiddenZones: forbiddenZones,
        canvasSize: referenceCanvasSize,
        measurer: _labelSizeMeasurer,
        compactStyleConfig: compactStyleConfig,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Vocabulary label placement failed: $error\n$stackTrace');
      _placedLabels = const [];
    }
    return _placedLabels;
  }
}

class _PlacementCacheKey {
  const _PlacementCacheKey({
    required this.words,
    required this.sourceImageSize,
    this.fullStyleConfig,
    this.compactStyleConfig,
  });

  factory _PlacementCacheKey.capture({
    required List<VocabDetection> words,
    required Size sourceImageSize,
    LabelStyleConfig? fullStyleConfig,
    LabelStyleConfig? compactStyleConfig,
  }) {
    return _PlacementCacheKey(
      words: List.unmodifiable(words.map(_WordSnapshot.new)),
      sourceImageSize: sourceImageSize,
      fullStyleConfig: fullStyleConfig,
      compactStyleConfig: compactStyleConfig,
    );
  }

  final List<_WordSnapshot> words;
  final Size sourceImageSize;
  final LabelStyleConfig? fullStyleConfig;
  final LabelStyleConfig? compactStyleConfig;

  bool isEquivalentTo(_PlacementCacheKey other) {
    final currentFull = fullStyleConfig;
    final currentCompact = compactStyleConfig;
    final otherFull = other.fullStyleConfig;
    final otherCompact = other.compactStyleConfig;

    if (currentFull == null ||
        currentCompact == null ||
        otherFull == null ||
        otherCompact == null ||
        currentFull != otherFull ||
        currentCompact != otherCompact ||
        !_sameSize(sourceImageSize, other.sourceImageSize) ||
        words.length != other.words.length) {
      return false;
    }
    for (var index = 0; index < words.length; index++) {
      if (!words[index].isEquivalentTo(other.words[index])) return false;
    }
    return true;
  }
}

class _WordSnapshot {
  _WordSnapshot(VocabDetection word)
      : number = word.number,
        word = word.word,
        phonetic = word.phonetic,
        meaning = word.meaning,
        partOfSpeech = word.partOfSpeech,
        x = word.x,
        y = word.y,
        width = word.w,
        height = word.h;

  final int number;
  final String word;
  final String phonetic;
  final String meaning;
  final String partOfSpeech;
  final double x;
  final double y;
  final double width;
  final double height;

  bool isEquivalentTo(_WordSnapshot other) {
    return number == other.number &&
        word == other.word &&
        phonetic == other.phonetic &&
        meaning == other.meaning &&
        partOfSpeech == other.partOfSpeech &&
        _sameDouble(x, other.x) &&
        _sameDouble(y, other.y) &&
        _sameDouble(width, other.width) &&
        _sameDouble(height, other.height);
  }
}

bool _sameSize(Size first, Size second) {
  return _sameDouble(first.width, second.width) &&
      _sameDouble(first.height, second.height);
}

bool _sameDouble(double first, double second) {
  return (first - second).abs() <= _cacheDoubleEpsilon;
}

Size _calculateReferenceCanvasSize(Size sourceImageSize) {
  return Size(
    _referenceCanvasWidth,
    _referenceCanvasWidth * sourceImageSize.height / sourceImageSize.width,
  );
}

class _OverlayViewportTransform {
  const _OverlayViewportTransform({
    required this.referenceSize,
    required this.viewportRect,
  });

  final Size referenceSize;
  final Rect viewportRect;

  double get scale => viewportRect.width / referenceSize.width;

  void applyTo(Canvas canvas) {
    canvas
      ..translate(viewportRect.left, viewportRect.top)
      ..scale(scale);
  }

  Offset? toReference(Offset canvasPosition) {
    if (!viewportRect.contains(canvasPosition)) return null;
    return Offset(
      (canvasPosition.dx - viewportRect.left) / scale,
      (canvasPosition.dy - viewportRect.top) / scale,
    );
  }

  Rect toCanvasRect(Rect referenceRect) {
    return Rect.fromLTRB(
      viewportRect.left + referenceRect.left * scale,
      viewportRect.top + referenceRect.top * scale,
      viewportRect.left + referenceRect.right * scale,
      viewportRect.top + referenceRect.bottom * scale,
    );
  }
}
