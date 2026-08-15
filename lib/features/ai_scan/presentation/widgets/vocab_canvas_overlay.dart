import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../../../../core/services/tts_service.dart';
import '../layout/vocab_overlay_layout.dart';
import 'vocab_note_card_painter.dart';

const Size _overlayReferenceSize = Size(440, 360);
const double _referenceSafeMargin = 12;
const double _referenceSlotGap = 8;

class VocabCanvasOverlay extends StatefulWidget {
  const VocabCanvasOverlay({
    required this.imageProvider,
    required this.words,
    this.sceneWords,
    this.ttsService,
    super.key,
  });

  final ImageProvider imageProvider;
  final List<VocabDetection> words;
  final List<VocabDetection>? sceneWords;
  final TtsService? ttsService;

  @override
  State<VocabCanvasOverlay> createState() => _VocabCanvasOverlayState();
}

class _VocabCanvasOverlayState extends State<VocabCanvasOverlay> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ui.Image? _image;
  Object? _loadError;
  late final TtsService _defaultTtsService;
  VocabDetection? _pressedDetection;

  TtsService get _ttsService => widget.ttsService ?? _defaultTtsService;

  @override
  void initState() {
    super.initState();
    _defaultTtsService = TtsService();
  }

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
    final stream = widget.imageProvider.resolve(createLocalImageConfiguration(
      context,
    ));
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final sourceSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
        final canvasSize = _resolveCanvasSize(
          constraints,
          sourceSize.width / sourceSize.height,
        );
        final geometryScale = math.min(
          canvasSize.width / _overlayReferenceSize.width,
          canvasSize.height / _overlayReferenceSize.height,
        );
        final cardSizes = <VocabDetection, Size>{
          for (final detection in selectVisibleObjects(widget.words))
            detection: measureVocabNoteCardTextExtent(detection),
        };
        final cardSize = cardSizes.isEmpty
            ? vocabNoteCardSize
            : cardSizes.values.fold<Size>(
                Size.zero,
                (largest, size) => Size(
                  math.max(largest.width, size.width),
                  math.max(largest.height, size.height),
                ),
              );
        final safeMargin = _referenceSafeMargin * geometryScale;
        final slotGap = _referenceSlotGap * geometryScale;
        final layout = buildVocabOverlayLayout(
          overlaySize: canvasSize,
          sourceImageSize: sourceSize,
          cardSize: cardSize,
          detections: widget.words,
          cardSizeForDetection: (detection) => cardSizes[detection] ?? cardSize,
          labelTierForDetection: (detection, grid) =>
              selectVocabNoteCardSizeTier(
            detection: detection,
            grid: grid,
          ),
          busyMapDetections: widget.sceneWords ?? widget.words,
          safeMargin: safeMargin,
          slotGap: slotGap,
          labelJitterScale: geometryScale,
        );

        return Center(
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fromRect(
                  rect: layout.imageRect,
                  child: Image(
                    image: widget.imageProvider,
                    fit: BoxFit.fill,
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) {
                    final placement = _placementAt(
                      layout.placements,
                      details.localPosition,
                    );
                    if (placement == null) return;
                    setState(() => _pressedDetection = placement.detection);
                  },
                  onTapUp: (details) {
                    final pressedDetection = _pressedDetection;
                    final placement = _placementAt(
                      layout.placements,
                      details.localPosition,
                    );
                    setState(() => _pressedDetection = null);
                    if (pressedDetection != null &&
                        identical(placement?.detection, pressedDetection)) {
                      _speak(pressedDetection.word);
                    }
                  },
                  onTapCancel: () {
                    if (_pressedDetection != null) {
                      setState(() => _pressedDetection = null);
                    }
                  },
                  child: CustomPaint(
                    painter: VocabOverlayPainter(
                      placements: layout.placements,
                      imageRect: layout.imageRect,
                      geometryScale: geometryScale,
                      pressedDetection: _pressedDetection,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  LabelPlacement? _placementAt(
    List<LabelPlacement> placements,
    Offset position,
  ) {
    for (final placement in placements.reversed) {
      if (placement.slot.cardRect.contains(position)) return placement;
    }
    return null;
  }

  Future<void> _speak(String word) async {
    try {
      await _ttsService.speak(word);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Không thể phát âm lúc này.')),
      );
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
    required this.placements,
    required this.imageRect,
    required this.geometryScale,
    this.pressedDetection,
  });

  final List<LabelPlacement> placements;
  final Rect imageRect;
  final double geometryScale;
  final VocabDetection? pressedDetection;

  List<VocabDetection> get words => List.unmodifiable(
        placements.map((placement) => placement.detection),
      );

  @override
  void paint(Canvas canvas, Size size) {
    for (final placement in placements) {
      _paintArrow(canvas, placement);
    }

    for (var index = 0; index < placements.length; index++) {
      final placement = placements[index];
      canvas.save();
      if (identical(placement.detection, pressedDetection)) {
        final center = placement.slot.cardRect.center;
        canvas
          ..translate(center.dx, center.dy)
          ..scale(0.96)
          ..translate(-center.dx, -center.dy);
      }
      canvas.translate(
        placement.slot.cardRect.left,
        placement.slot.cardRect.top,
      );
      VocabNoteCardPainter(
        detection: placement.detection,
        index: index + 1,
      ).paint(canvas, placement.slot.cardRect.size);
      canvas.restore();
    }
  }

  void _paintArrow(Canvas canvas, LabelPlacement placement) {
    final obstacles = <Rect>[
      for (final other in placements)
        if (!identical(other, placement)) ...[
          other.slot.cardRect,
          other.objectRect,
        ],
    ];
    final geometry = calculateArrowGeometry(
      placement: placement,
      imageCenter: imageRect.center,
      obstacles: obstacles,
      routingBounds: imageRect,
      geometryScale: geometryScale,
    );
    final path = Path()
      ..moveTo(geometry.start.dx, geometry.start.dy)
      ..quadraticBezierTo(
        geometry.controlPoint.dx,
        geometry.controlPoint.dy,
        geometry.end.dx,
        geometry.end.dy,
      );
    final arrowPaint = Paint()
      ..color = const Color(0xCCB07748)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55 * geometryScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, arrowPaint);

    final hash = stableStringHash(placement.detection.word);
    final sketchOffset = Offset(
      ((hash & 0x0F) / 15 - 0.5) * 0.8 * geometryScale,
      (((hash >> 4) & 0x0F) / 15 - 0.5) * 0.8 * geometryScale,
    );
    canvas
      ..save()
      ..translate(sketchOffset.dx, sketchOffset.dy)
      ..drawPath(
        path,
        Paint()
          ..color = const Color(0x66E98B3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * geometryScale
          ..strokeCap = StrokeCap.round,
      )
      ..restore();

    for (var index = 0; index < geometry.arrowHeadPoints.length; index++) {
      final point = geometry.arrowHeadPoints[index];
      canvas.drawLine(
        geometry.end,
        point,
        Paint()
          ..color =
              index == 1 ? const Color(0x99E98B3A) : const Color(0xCCB07748)
          ..strokeWidth = (index == 1 ? 1.0 : 1.45) * geometryScale
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant VocabOverlayPainter oldDelegate) {
    return oldDelegate.placements != placements ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.geometryScale != geometryScale ||
        oldDelegate.pressedDetection != pressedDetection;
  }
}
