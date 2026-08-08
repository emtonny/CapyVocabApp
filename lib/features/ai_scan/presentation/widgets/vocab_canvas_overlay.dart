import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/services/gemini_vision_service.dart';

class VocabCanvasOverlay extends StatefulWidget {
  const VocabCanvasOverlay({
    required this.imageProvider,
    required this.words,
    super.key,
  });

  final ImageProvider imageProvider;
  final List<VocabDetection> words;

  @override
  State<VocabCanvasOverlay> createState() => _VocabCanvasOverlayState();
}

class _VocabCanvasOverlayState extends State<VocabCanvasOverlay> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ui.Image? _image;
  Object? _loadError;

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

    final aspectRatio = image.width / image.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * aspectRatio,
        );
        final height = width / aspectRatio;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: widget.imageProvider, fit: BoxFit.fill),
                IgnorePointer(
                  child: CustomPaint(
                    painter: VocabOverlayPainter(widget.words),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VocabOverlayPainter extends CustomPainter {
  const VocabOverlayPainter(this.words);

  final List<VocabDetection> words;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.amber.withValues(alpha: 0.22);
    final borderPaint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final word in words) {
      final rect = Rect.fromLTWH(
        word.x * size.width,
        word.y * size.height,
        word.w * size.width,
        word.h * size.height,
      );
      final roundedRect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(4),
      );
      canvas
        ..drawRRect(roundedRect, fillPaint)
        ..drawRRect(roundedRect, borderPaint);

      _paintLabel(canvas, size, rect, word.word);
    }
  }

  void _paintLabel(Canvas canvas, Size size, Rect box, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, size.width - 12));

    const horizontalPadding = 6.0;
    const verticalPadding = 3.0;
    final labelSize = Size(
      textPainter.width + horizontalPadding * 2,
      textPainter.height + verticalPadding * 2,
    );
    final left = box.left
        .clamp(0.0, math.max(0.0, size.width - labelSize.width))
        .toDouble();
    final preferredTop = box.top - labelSize.height - 2;
    final top = preferredTop >= 0
        ? preferredTop
        : math.min(size.height - labelSize.height, box.bottom + 2);
    final labelRect = Rect.fromLTWH(
      left,
      math.max(0.0, top),
      labelSize.width,
      labelSize.height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      Paint()..color = Colors.deepOrange,
    );
    textPainter.paint(
      canvas,
      Offset(
        labelRect.left + horizontalPadding,
        labelRect.top + verticalPadding,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant VocabOverlayPainter oldDelegate) {
    return oldDelegate.words != words;
  }
}
