import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/core/services/tts_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/layout/vocab_overlay_layout.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_note_card_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render ảnh và CustomPaint với box đã chuẩn hóa', (tester) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );
    const word = VocabDetection(
      number: 1,
      word: 'apple',
      phonetic: '/ˈæp.əl/',
      meaning: 'quả táo',
      x: 0.1,
      y: 0.2,
      w: 0.3,
      h: 0.1,
    );

    final imageProvider = MemoryImage(imageBytes);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabCanvasOverlay(
            imageProvider: imageProvider,
            words: const [word],
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        imageProvider,
        tester.element(find.byType(VocabCanvasOverlay)),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    final overlayPaint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VocabOverlayPainter,
    );
    expect(overlayPaint, findsOneWidget);
    final customPaint = tester.widget<CustomPaint>(overlayPaint);
    final painter = customPaint.painter! as VocabOverlayPainter;
    expect(painter.words, const [word]);
    expect(painter.imageRect, const Rect.fromLTWH(100, 0, 600, 600));
    expect(painter.placements, hasLength(1));
    final cardRect = painter.placements.single.slot.cardRect;
    expect(cardRect.left, greaterThanOrEqualTo(painter.imageRect.left));
    expect(cardRect.top, greaterThanOrEqualTo(painter.imageRect.top));
    expect(cardRect.right, lessThanOrEqualTo(painter.imageRect.right));
    expect(cardRect.bottom, lessThanOrEqualTo(painter.imageRect.bottom));
    expect(word.numberedWord, '1. apple');
    expect(tester.takeException(), isNull);
  });

  testWidgets('bấm label phát âm và hiển thị trạng thái đang nhấn',
      (tester) async {
    final imageBytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );
    const word = VocabDetection(
      word: 'apple',
      phonetic: '/ˈæp.əl/',
      meaning: 'quả táo',
      x: 0.1,
      y: 0.2,
      w: 0.3,
      h: 0.1,
    );
    final ttsService = _RecordingTtsService();
    final imageProvider = MemoryImage(imageBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VocabCanvasOverlay(
            imageProvider: imageProvider,
            words: const [word],
            ttsService: ttsService,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        imageProvider,
        tester.element(find.byType(VocabCanvasOverlay)),
      ),
    );
    await tester.pump();

    VocabOverlayPainter painter() {
      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is VocabOverlayPainter,
        ),
      );
      return customPaint.painter! as VocabOverlayPainter;
    }

    final overlayTopLeft = tester.getTopLeft(find.byType(GestureDetector));
    final cardCenter = painter().placements.single.slot.cardRect.center;
    final gesture = await tester.startGesture(overlayTopLeft + cardCenter);
    await tester.pump();

    expect(painter().pressedDetection, same(word));

    await gesture.up();
    await tester.pump();

    expect(painter().pressedDetection, isNull);
    expect(ttsService.spokenWords, const ['apple']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cùng JSON giữ object geometry và label-arrow hợp lệ khi resize',
      (tester) async {
    final imageProvider = MemoryImage(
      Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
          'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        ),
      ),
    );
    const words = [
      VocabDetection(
        word: 'apple',
        phonetic: '/ˈæp.əl/',
        meaning: 'quả táo',
        x: 0.1,
        y: 0.15,
        w: 0.2,
        h: 0.25,
      ),
      VocabDetection(
        word: 'basket',
        phonetic: '/ˈbɑː.skɪt/',
        meaning: 'cái giỏ đựng trái cây',
        x: 0.55,
        y: 0.5,
        w: 0.3,
        h: 0.35,
      ),
    ];

    Future<VocabOverlayPainter> renderAt(Size size) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: VocabCanvasOverlay(
                imageProvider: imageProvider,
                words: words,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          imageProvider,
          tester.element(find.byType(VocabCanvasOverlay)),
        ),
      );
      await tester.pump();

      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is VocabOverlayPainter,
        ),
      );
      return customPaint.painter! as VocabOverlayPainter;
    }

    const previewSize = Size(320, 240);
    const fullscreenSize = Size(640, 480);
    const smallPhoneSize = Size(240, 240);
    final preview = await renderAt(previewSize);
    final fullscreen = await renderAt(fullscreenSize);
    final smallPhone = await renderAt(smallPhoneSize);

    final smallPhoneGrid = OverlayPlacementGrid(
      imageRect: smallPhone.imageRect,
    );
    expect((smallPhoneGrid.columns, smallPhoneGrid.rows), (6, 6));
    expect(smallPhoneGrid.cellSize, const Size(40, 40));
    expect(smallPhone.placements, isNotEmpty);
    for (final placement in smallPhone.placements) {
      expect(placement.slot.cardRect.width, lessThanOrEqualTo(152));
      expect(placement.slot.cardRect.height, lessThanOrEqualTo(112));
      expect(
        doesVocabNoteCardFitTier(
          detection: placement.detection,
          tier: placement.slot.sizeTier!,
          grid: smallPhoneGrid,
        ),
        isTrue,
      );
      expect(
        smallPhone.imageRect
                .inflate(0.001)
                .contains(placement.slot.cardRect.topLeft) &&
            smallPhone.imageRect
                .inflate(0.001)
                .contains(placement.slot.cardRect.bottomRight),
        isTrue,
      );
    }

    expect(
      _normalizedRect(preview.imageRect, previewSize),
      _rectCloseTo(_normalizedRect(fullscreen.imageRect, fullscreenSize)),
    );
    expect(fullscreen.placements, hasLength(preview.placements.length));

    for (final previewPlacement in preview.placements) {
      final fullscreenPlacement = fullscreen.placements.singleWhere(
        (placement) =>
            placement.detection.word == previewPlacement.detection.word,
      );
      expect(
        _normalizedRect(previewPlacement.objectRect, previewSize),
        _rectCloseTo(
          _normalizedRect(fullscreenPlacement.objectRect, fullscreenSize),
        ),
      );
      expect(
        preview.imageRect
                .inflate(0.001)
                .contains(previewPlacement.slot.cardRect.topLeft) &&
            preview.imageRect
                .inflate(0.001)
                .contains(previewPlacement.slot.cardRect.bottomRight),
        isTrue,
        reason:
            'image=${preview.imageRect}, card=${previewPlacement.slot.cardRect}',
      );
      expect(
        fullscreen.imageRect
                .inflate(0.001)
                .contains(fullscreenPlacement.slot.cardRect.topLeft) &&
            fullscreen.imageRect
                .inflate(0.001)
                .contains(fullscreenPlacement.slot.cardRect.bottomRight),
        isTrue,
      );

      final previewArrow = calculateArrowGeometry(
        placement: previewPlacement,
        imageCenter: preview.imageRect.center,
      );
      final fullscreenArrow = calculateArrowGeometry(
        placement: fullscreenPlacement,
        imageCenter: fullscreen.imageRect.center,
      );
      expect(
          previewPlacement.objectRect.inflate(0.001).contains(previewArrow.end),
          isTrue);
      expect(
        fullscreenPlacement.objectRect
            .inflate(0.001)
            .contains(fullscreenArrow.end),
        isTrue,
      );
    }
  });

  test('painter chỉ vẽ label và arrow, không tô hay viền object box', () async {
    const placement = LabelPlacement(
      detection: VocabDetection(
        word: 'giraffe',
        phonetic: '/dʒəˈrɑːf/',
        meaning: 'hươu cao cổ',
        x: 0.56,
        y: 0.5,
        w: 0.25,
        h: 0.25,
      ),
      slot: LabelSlot(
        id: 'giraffe-label',
        side: LabelSide.top,
        cardRect: Rect.fromLTWH(20, 20, 120, 100),
        anchorPoint: Offset(140, 120),
      ),
      objectRect: Rect.fromLTWH(180, 140, 80, 70),
    );
    const canvasSize = Size(300, 240);
    final painter = VocabOverlayPainter(
      placements: const [placement],
      imageRect: Offset.zero & canvasSize,
      geometryScale: 1,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), canvasSize);
    final image = await recorder.endRecording().toImage(
          canvasSize.width.toInt(),
          canvasSize.height.toInt(),
        );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

    final arrow = calculateArrowGeometry(
      placement: placement,
      imageCenter: const Offset(150, 120),
      routingBounds: Offset.zero & canvasSize,
    );
    final arrowMidpoint =
        arrow.start * 0.25 + arrow.controlPoint * 0.5 + arrow.end * 0.25;

    expect(_pixelAlpha(bytes, image.width, placement.objectRect.center), 0);
    expect(
      _pixelAlpha(bytes, image.width, placement.slot.cardRect.center),
      greaterThan(0),
    );
    expect(_hasVisiblePixelNear(bytes, image.width, arrowMidpoint), isTrue);

    image.dispose();
  });
}

int _pixelAlpha(ByteData bytes, int imageWidth, Offset point) {
  final x = point.dx.round();
  final y = point.dy.round();
  return bytes.getUint8((y * imageWidth + x) * 4 + 3);
}

bool _hasVisiblePixelNear(
  ByteData bytes,
  int imageWidth,
  Offset point, {
  int radius = 3,
}) {
  for (var y = point.dy.round() - radius; y <= point.dy.round() + radius; y++) {
    for (var x = point.dx.round() - radius;
        x <= point.dx.round() + radius;
        x++) {
      if (_pixelAlpha(bytes, imageWidth, Offset(x.toDouble(), y.toDouble())) >
          0) {
        return true;
      }
    }
  }
  return false;
}

Rect _normalizedRect(Rect rect, Size containerSize) => Rect.fromLTRB(
      rect.left / containerSize.width,
      rect.top / containerSize.height,
      rect.right / containerSize.width,
      rect.bottom / containerSize.height,
    );

Matcher _rectCloseTo(Rect expected) => predicate<Rect>(
      (actual) =>
          (actual.left - expected.left).abs() < 0.000001 &&
          (actual.top - expected.top).abs() < 0.000001 &&
          (actual.right - expected.right).abs() < 0.000001 &&
          (actual.bottom - expected.bottom).abs() < 0.000001,
      'Rect gần bằng $expected',
    );

class _RecordingTtsService extends TtsService {
  final List<String> spokenWords = [];

  @override
  Future<void> speak(String text) async {
    spokenWords.add(text);
  }
}
