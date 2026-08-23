import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_placement_solver.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_size_measurer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../vocab_scan/fixtures/wardrobe_words.dart';

void main() {
  testWidgets('renders the scanned image and normalized object boxes',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    const word = VocabDetection(
      word: 'apple',
      phonetic: '/apple/',
      meaning: 'quả táo',
      x: 0.1,
      y: 0.2,
      w: 0.3,
      h: 0.1,
    );

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
    final painter = _overlayPainter(tester);
    expect(painter.words, const [word]);
    expect(painter.imageRect, const Rect.fromLTWH(100, 0, 600, 600));
    expect(painter.boxes, const [Rect.fromLTWH(160, 120, 180, 60)]);
    expect(find.byType(GestureDetector), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bbox stays within 0.5px at 0.5x, 1x, and 2x reference scale',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final imageProvider = MemoryImage(_testImageBytes());
    const words = [
      VocabDetection(
        word: 'apple',
        phonetic: '/apple/',
        meaning: 'quả táo',
        x: 0.1,
        y: 0.15,
        w: 0.2,
        h: 0.25,
      ),
      VocabDetection(
        word: 'basket',
        phonetic: '/basket/',
        meaning: 'cái giỏ',
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
      return _overlayPainter(tester);
    }

    const zoomLevels = [0.5, 1.0, 2.0];
    for (final zoom in zoomLevels) {
      final painter = await renderAt(Size.square(400 * zoom));
      expect(painter.referenceCanvasSize, const Size.square(400));
      expect(painter.solveInvocationCount, 1);
      expect(painter.boxes, hasLength(words.length));

      for (var index = 0; index < words.length; index++) {
        final word = words[index];
        final expected = Rect.fromLTWH(
          word.x * 400 * zoom,
          word.y * 400 * zoom,
          word.w * 400 * zoom,
          word.h * 400 * zoom,
        );
        expect(painter.boxes[index], _rectWithinHalfPixel(expected));
        expect(
          _normalizeToImage(painter.boxes[index], painter.imageRect),
          _rectCloseTo(Rect.fromLTWH(word.x, word.y, word.w, word.h)),
        );
      }
    }
  });

  test('painter draws boxes without label cards or arrows', () async {
    const canvasSize = Size(300, 240);
    final painter = VocabOverlayPainter(
      words: const [
        VocabDetection(
          word: 'giraffe',
          phonetic: '/giraffe/',
          meaning: 'hươu cao cổ',
          x: 0.5,
          y: 0.5,
          w: 0.25,
          h: 0.25,
        ),
      ],
      imageRect: Offset.zero & canvasSize,
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), canvasSize);
    final image = await recorder.endRecording().toImage(
          canvasSize.width.toInt(),
          canvasSize.height.toInt(),
        );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final box = painter.boxes.single;

    expect(_pixelAlpha(bytes, image.width, box.center), greaterThan(0));
    expect(_pixelAlpha(bytes, image.width, const Offset(20, 20)), 0);

    image.dispose();
  });

  test('card and badge borders paint completely inside solver footprint',
      () async {
    const painterConfig = VocabOverlayPainter(words: [], imageRect: Rect.zero);
    final measured = const LabelSizeMeasurer().measure(
      _appleWord,
      painterConfig.fullStyleConfig,
    );
    final footprint = Rect.fromLTWH(20, 20, measured.width, measured.height);
    final placed = PlacedLabel(
      word: _appleWord,
      labelRect: footprint,
      anchorBox: footprint,
      quality: PlacementQuality.ideal,
    );
    final painter = VocabOverlayPainter(
      words: const [],
      imageRect: Rect.zero,
      placedLabels: [placed],
    );
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(200, 120));
    final image = await recorder.endRecording().toImage(200, 120);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final safeFootprint = footprint.inflate(0.01);

    var paintedPixels = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
        if (alpha == 0) continue;
        paintedPixels++;
        expect(
          safeFootprint.contains(Offset(x + 0.5, y + 0.5)),
          isTrue,
          reason: 'painted pixel ($x, $y) escaped $footprint',
        );
      }
    }
    expect(paintedPixels, greaterThan(0));
    image.dispose();
  });

  test('placement tiers use the reconciled floating-badge typography', () {
    const painter = VocabOverlayPainter(
      words: [],
      imageRect: Rect.zero,
    );

    expect(painter.fullStyleConfig.badgeSize, const Size.square(16));
    expect(painter.fullStyleConfig.badgeTextStyle.fontSize, 7);
    expect(
      painter.fullStyleConfig.badgeTextStyle.fontWeight,
      FontWeight.w700,
    );
    expect(painter.compactStyleConfig.badgeSize, const Size.square(16));
    expect(painter.compactStyleConfig.badgeTextStyle.fontSize, 7);
    expect(
      painter.compactStyleConfig.badgeTextStyle.fontWeight,
      FontWeight.w700,
    );
    expect(painter.fullStyleConfig.wordStyle.fontSize, 7);
    expect(painter.fullStyleConfig.phoneticStyle.fontSize, 6);
    expect(painter.fullStyleConfig.meaningStyle.fontSize, 7);
    expect(painter.compactStyleConfig.wordStyle.fontSize, 6);
    expect(painter.compactStyleConfig.phoneticStyle.fontSize, 6);
    expect(painter.compactStyleConfig.meaningStyle.fontSize, 6);
    expect(painter.fullStyleConfig.wordStyle.fontWeight, FontWeight.w700);
    expect(painter.fullStyleConfig.phoneticStyle.fontStyle, FontStyle.italic);
    expect(painter.fullStyleConfig.meaningStyle.fontWeight, FontWeight.w400);
    expect(painter.fullStyleConfig.padding.bottom, 7);
    expect(painter.compactStyleConfig.padding.bottom, 5);
  });

  testWidgets('five unrelated rebuilds do not recompute placement',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    const word = VocabDetection(
      word: 'apple',
      phonetic: '/apple/',
      meaning: 'quả táo',
      x: 0.1,
      y: 0.2,
      w: 0.2,
      h: 0.2,
    );
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: imageProvider,
        initialWords: const [word],
      ),
      imageProvider: imageProvider,
    );

    final initialPainter = _overlayPainter(tester);
    final initialPlacements = initialPainter.placedLabels;
    expect(initialPainter.solveInvocationCount, 1);
    expect(initialPlacements, hasLength(1));

    for (var rebuild = 0; rebuild < 5; rebuild++) {
      harnessKey.currentState!.rebuildWithoutChanges();
      await tester.pump();
      final rebuiltPainter = _overlayPainter(tester);
      expect(rebuiltPainter.solveInvocationCount, 1);
      expect(identical(rebuiltPainter.placedLabels, initialPlacements), isTrue);
    }
  });

  testWidgets('arbitrary canvas resize never recomputes reference placement',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final imageProvider = MemoryImage(_testImageBytes());
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: imageProvider,
        initialWords: const [_appleWord],
        initialSize: const Size.square(200),
      ),
      imageProvider: imageProvider,
    );
    final initialPainter = _overlayPainter(tester);
    final referencePlacements = initialPainter.placedLabels;
    expect(initialPainter.solveInvocationCount, 1);
    expect(initialPainter.referenceCanvasSize, const Size.square(400));
    expect(
      referencePlacements.single.anchorBox,
      _rectCloseTo(const Rect.fromLTWH(40, 80, 120, 40)),
    );

    for (final size in const [Size.square(400), Size.square(800)]) {
      harnessKey.currentState!.update(size: size);
      await tester.pump();
      final resizedPainter = _overlayPainter(tester);
      expect(resizedPainter.solveInvocationCount, 1);
      expect(
        identical(resizedPainter.placedLabels, referencePlacements),
        isTrue,
      );
    }
  });

  testWidgets('sub-epsilon word and canvas jitter do not recompute placement',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: imageProvider,
        initialWords: const [_appleWord],
      ),
      imageProvider: imageProvider,
    );
    final initialPainter = _overlayPainter(tester);
    final initialPlacements = initialPainter.placedLabels;
    expect(initialPainter.solveInvocationCount, 1);

    harnessKey.currentState!.update(
      words: const [
        VocabDetection(
          word: 'apple',
          phonetic: '/apple/',
          meaning: 'quả táo',
          x: 0.1000005,
          y: 0.2,
          w: 0.3,
          h: 0.1,
        ),
      ],
      size: const Size(800.0000005, 600),
    );
    await tester.pump();

    final jitteredPainter = _overlayPainter(tester);
    expect(jitteredPainter.solveInvocationCount, 1);
    expect(identical(jitteredPainter.placedLabels, initialPlacements), isTrue);
  });

  testWidgets('a real word change recomputes placement exactly once',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: imageProvider,
        initialWords: const [_appleWord],
      ),
      imageProvider: imageProvider,
    );
    expect(_overlayPainter(tester).solveInvocationCount, 1);

    harnessKey.currentState!.update(
      words: const [
        VocabDetection(
          word: 'pear',
          phonetic: '/peər/',
          meaning: 'quả lê',
          x: 0.1,
          y: 0.2,
          w: 0.2,
          h: 0.2,
        ),
      ],
    );
    await tester.pump();
    expect(_overlayPainter(tester).solveInvocationCount, 2);

    harnessKey.currentState!.rebuildWithoutChanges();
    await tester.pump();
    expect(_overlayPainter(tester).solveInvocationCount, 2);
  });

  testWidgets('a real source image size change recomputes placement once',
      (tester) async {
    final firstProvider = MemoryImage(_testImageBytes());
    final secondImageBytes = await tester.runAsync(
      () => _createPngBytes(2, 1),
    );
    final secondProvider = MemoryImage(secondImageBytes!);
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: firstProvider,
        initialWords: const [_appleWord],
        initialSize: const Size(400, 200),
      ),
      imageProvider: firstProvider,
    );
    expect(_overlayPainter(tester).solveInvocationCount, 1);
    expect(_overlayPainter(tester).referenceCanvasSize, const Size(400, 400));

    await tester.runAsync(
      () => precacheImage(
        secondProvider,
        tester.element(find.byType(VocabCanvasOverlay)),
      ),
    );
    harnessKey.currentState!.update(imageProvider: secondProvider);
    await tester.pump();

    final changedPainter = _overlayPainter(tester);
    expect(changedPainter.solveInvocationCount, 2);
    expect(changedPainter.referenceCanvasSize, const Size(400, 200));
  });

  testWidgets('badge taps map back from 0.5x and 2x reference scale',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tappedWords = <VocabDetection>[];
    final imageProvider = MemoryImage(_testImageBytes());
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: imageProvider,
        initialWords: const [_appleWord],
        initialSize: const Size.square(200),
        onLabelTap: tappedWords.add,
      ),
      imageProvider: imageProvider,
    );

    for (final size in const [Size.square(200), Size.square(800)]) {
      harnessKey.currentState!.update(size: size);
      await tester.pump();
      final painter = _overlayPainter(tester);
      final badgeCenter = _referencePointToCanvas(
        painter,
        painter.geometryFor(painter.placedLabels.single).badgeRect.center,
      );
      await tester.tapAt(_customPaintTopLeft(tester) + badgeCenter);
      await tester.pump();
      expect(tappedWords.last.word, _appleWord.word);
    }
    expect(tappedWords, hasLength(2));

    final painter = _overlayPainter(tester);
    const outsideReferencePoint = Offset(1, 1);
    expect(painter.placedLabels.any((placed) {
      return painter.geometryFor(placed).containsVisiblePoint(
            outsideReferencePoint,
          );
    }), isFalse);
    await tester.tapAt(
      _customPaintTopLeft(tester) +
          _referencePointToCanvas(painter, outsideReferencePoint),
    );
    await tester.pump();
    expect(tappedWords, hasLength(2));
  });

  testWidgets(
      'card and badge tap once while transparent footprint gap does not',
      (tester) async {
    final tappedWords = <VocabDetection>[];
    final imageProvider = MemoryImage(_testImageBytes());
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        imageProvider: imageProvider,
        initialWords: const [_appleWord],
        initialSize: const Size.square(400),
        onLabelTap: tappedWords.add,
      ),
      imageProvider: imageProvider,
    );

    final painter = _overlayPainter(tester);
    final geometry = painter.geometryFor(painter.placedLabels.single);
    final paintOrigin = _customPaintTopLeft(tester);

    await tester.tapAt(
      paintOrigin + _referencePointToCanvas(painter, geometry.cardRect.center),
    );
    await tester.pump();
    expect(tappedWords, hasLength(1));

    await tester.tapAt(
      paintOrigin + _referencePointToCanvas(painter, geometry.badgeRect.center),
    );
    await tester.pump();
    expect(tappedWords, hasLength(2));

    final transparentGap = Offset(
      geometry.cardRect.right - 1,
      geometry.footprintRect.top + 1,
    );
    expect(geometry.footprintRect.contains(transparentGap), isTrue);
    expect(geometry.containsVisiblePoint(transparentGap), isFalse);
    await tester.tapAt(
      paintOrigin + _referencePointToCanvas(painter, transparentGap),
    );
    await tester.pump();
    expect(tappedWords, hasLength(2));
  });

  testWidgets(
      'pinch release emits no false tap before the next independent tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tappedWords = <VocabDetection>[];
    final imageProvider = MemoryImage(_testImageBytes());
    final transformationController = TransformationController();
    addTearDown(transformationController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 400,
            child: InteractiveViewer(
              transformationController: transformationController,
              minScale: 0.5,
              maxScale: 4,
              child: VocabCanvasOverlay(
                imageProvider: imageProvider,
                words: const [_appleWord],
                onLabelTap: tappedWords.add,
              ),
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

    final painter = _overlayPainter(tester);
    final labelCenter = _referencePointToCanvas(
      painter,
      painter.geometryFor(painter.placedLabels.single).cardRect.center,
    );
    final viewerTopLeft = tester.getTopLeft(find.byType(InteractiveViewer));
    final focalPoint = viewerTopLeft + labelCenter;
    final firstFinger = await tester.createGesture(pointer: 1);
    final secondFinger = await tester.createGesture(pointer: 2);

    await firstFinger.down(focalPoint - const Offset(20, 0));
    await secondFinger.down(focalPoint + const Offset(20, 0));
    await tester.pump();
    await firstFinger.moveTo(focalPoint - const Offset(70, 0));
    await secondFinger.moveTo(focalPoint + const Offset(70, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(transformationController.value.getMaxScaleOnAxis(), greaterThan(1));

    await secondFinger.up();
    await tester.pump();
    expect(tappedWords, isEmpty);
    await firstFinger.up();
    await tester.pump();
    expect(tappedWords, isEmpty);

    final transformedLabelCenter = MatrixUtils.transformPoint(
      transformationController.value,
      labelCenter,
    );
    expect(
      (Offset.zero & const Size.square(400)).contains(transformedLabelCenter),
      isTrue,
    );
    await tester.tapAt(viewerTopLeft + transformedLabelCenter);
    await tester.pump();

    expect(tappedWords, hasLength(1));
    expect(tappedWords.single.word, _appleWord.word);
  });

  testWidgets('renders all 12 wardrobe labels and connectors without errors',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    final words = _wardrobeDetections();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        imageProvider: imageProvider,
        initialWords: words,
        initialSize: const Size(400, 800),
      ),
      imageProvider: imageProvider,
    );

    final painter = _overlayPainter(tester);
    expect(painter.words, hasLength(12));
    expect(painter.placedLabels, hasLength(12));
    expect(painter.solveInvocationCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the same 12-word reference layout at 0.5x and 1x',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 450));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final imageProvider = MemoryImage(_testImageBytes());
    final words = _wardrobeDetections();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: RepaintBoundary(
              key: const Key('wardrobe-reference-scale-pair'),
              child: ColoredBox(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 200,
                        child: VocabCanvasOverlay(
                          imageProvider: imageProvider,
                          words: words,
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox.square(
                        dimension: 400,
                        child: VocabCanvasOverlay(
                          imageProvider: imageProvider,
                          words: words,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        imageProvider,
        tester.element(find.byType(VocabCanvasOverlay).first),
      ),
    );
    await tester.pump();

    final painters = tester
        .widgetList<CustomPaint>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is VocabOverlayPainter,
          ),
        )
        .map((paint) => paint.painter! as VocabOverlayPainter)
        .toList(growable: false);
    expect(painters, hasLength(2));
    final halfScale = painters[0];
    final fullScale = painters[1];
    expect(halfScale.solveInvocationCount, 1);
    expect(fullScale.solveInvocationCount, 1);
    expect(halfScale.placedLabels, hasLength(12));
    expect(fullScale.placedLabels, hasLength(12));
    for (var index = 0; index < halfScale.placedLabels.length; index++) {
      final halfPlaced = halfScale.placedLabels[index];
      final fullPlaced = fullScale.placedLabels[index];
      expect(halfPlaced.word.word, fullPlaced.word.word);
      expect(halfPlaced.labelRect, _rectCloseTo(fullPlaced.labelRect));
      expect(halfPlaced.anchorBox, _rectCloseTo(fullPlaced.anchorBox));
      expect(
        _normalizeToImage(
          _referenceRectToCanvas(halfScale, halfPlaced.labelRect),
          halfScale.imageRect,
        ),
        _rectCloseTo(
          _normalizeToImage(
            _referenceRectToCanvas(fullScale, fullPlaced.labelRect),
            fullScale.imageRect,
          ),
        ),
      );
    }

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('wardrobe-reference-scale-pair')),
      matchesGoldenFile(
        'goldens/vocab_canvas_overlay_floating_badge_reference_scale_pair.png',
      ),
    );
  });

  testWidgets('more than Gemini maximum stays bbox-only without solving',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    final tooManyWords = List<VocabDetection>.generate(
      maxGeminiVocabularyWords + 1,
      (index) => VocabDetection(
        number: index + 1,
        word: 'word$index',
        phonetic: '/word/',
        meaning: 'nghĩa',
        x: 0.1,
        y: 0.1,
        w: 0.1,
        h: 0.1,
      ),
    );
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        imageProvider: imageProvider,
        initialWords: tooManyWords,
      ),
      imageProvider: imageProvider,
    );
    final painter = _overlayPainter(tester);
    expect(painter.placedLabels, isEmpty);
    expect(painter.boxes, hasLength(maxGeminiVocabularyWords + 1));
    expect(painter.solveInvocationCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pipeline exception falls back to bbox-only without crashing',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        imageProvider: imageProvider,
        initialWords: const [
          VocabDetection(
            word: 'invalid',
            phonetic: '',
            meaning: '',
            x: 0.1,
            y: 0.1,
            w: 0,
            h: 0.1,
          ),
        ],
      ),
      imageProvider: imageProvider,
    );

    final invalidPainter = _overlayPainter(tester);
    expect(invalidPainter.placedLabels, isEmpty);
    expect(invalidPainter.boxes, hasLength(1));
    expect(invalidPainter.solveInvocationCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero-sized layout skips geometry pipeline without crashing',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        imageProvider: imageProvider,
        initialWords: const [_appleWord],
        initialSize: Size.zero,
      ),
      imageProvider: imageProvider,
    );

    expect(find.byType(VocabCanvasOverlay), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is VocabOverlayPainter,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('benchmarks integrated cache-hit and full recompute frames',
      (tester) async {
    final imageProvider = MemoryImage(_testImageBytes());
    final harnessKey = GlobalKey<_OverlayHarnessState>();
    final words = _maximumVocabularyDetections();
    await _pumpHarness(
      tester,
      harness: _OverlayHarness(
        key: harnessKey,
        imageProvider: imageProvider,
        initialWords: words,
        initialSize: const Size(400, 800),
      ),
      imageProvider: imageProvider,
    );
    expect(_overlayPainter(tester).solveInvocationCount, 1);

    const cacheHitIterations = 50;
    final cacheHitStopwatch = Stopwatch()..start();
    for (var iteration = 0; iteration < cacheHitIterations; iteration++) {
      harnessKey.currentState!.rebuildWithoutChanges();
      await tester.pump();
    }
    cacheHitStopwatch.stop();
    expect(_overlayPainter(tester).solveInvocationCount, 1);

    const recomputeIterations = 20;
    final recomputeStopwatch = Stopwatch()..start();
    for (var iteration = 0; iteration < recomputeIterations; iteration++) {
      harnessKey.currentState!.update(
        words: _withCacheRevision(words, iteration),
      );
      await tester.pump();
    }
    recomputeStopwatch.stop();
    expect(
      _overlayPainter(tester).solveInvocationCount,
      1 + recomputeIterations,
    );
    expect(tester.takeException(), isNull);

    final averageCacheHitMicroseconds =
        cacheHitStopwatch.elapsedMicroseconds / cacheHitIterations;
    final averageRecomputeMicroseconds =
        recomputeStopwatch.elapsedMicroseconds / recomputeIterations;
    debugPrint(
      'OVERLAY_PIPELINE_PERFORMANCE words=${words.length} '
      'cacheHitIterations=$cacheHitIterations '
      'cacheHitAverage=${averageCacheHitMicroseconds.toStringAsFixed(2)}us '
      'recomputeIterations=$recomputeIterations '
      'recomputeAverage=${averageRecomputeMicroseconds.toStringAsFixed(2)}us',
    );
    expect(averageCacheHitMicroseconds.isFinite, isTrue);
    expect(averageRecomputeMicroseconds.isFinite, isTrue);

    // Widget-test timing is not a device frame benchmark. This generous limit
    // catches only gross integration regressions without claiming 60 FPS.
    expect(averageRecomputeMicroseconds, lessThan(50000));
  });

  testWidgets('bbox-only and floating-badge painter match review goldens',
      (tester) async {
    const canvasSize = Size(320, 240);
    const imageRect = Rect.fromLTWH(40, 0, 240, 240);
    const anchorBox = Rect.fromLTWH(64, 48, 72, 24);
    const painterConfig = VocabOverlayPainter(
      words: [],
      imageRect: imageRect,
    );
    final measured = const LabelSizeMeasurer().measure(
      _appleWord,
      painterConfig.fullStyleConfig,
    );
    final placedLabel = PlacedLabel(
      word: _appleWord,
      labelRect: Rect.fromLTWH(145, 82, measured.width, measured.height),
      anchorBox: anchorBox,
      quality: PlacementQuality.ideal,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: Key('bbox-before'),
            child: CustomPaint(
              size: canvasSize,
              painter: VocabOverlayPainter(
                words: [_appleWord],
                imageRect: imageRect,
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('bbox-before')),
      matchesGoldenFile('goldens/vocab_canvas_overlay_bbox_before.png'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const Key('floating-badge-card-after'),
            child: CustomPaint(
              size: const Size(320, 240),
              painter: VocabOverlayPainter(
                words: const [_appleWord],
                imageRect: const Rect.fromLTWH(40, 0, 240, 240),
                placedLabels: [placedLabel],
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const Key('floating-badge-card-after')),
      matchesGoldenFile(
        'goldens/vocab_canvas_overlay_floating_badge_fixed_type.png',
      ),
    );
  });
}

const _appleWord = VocabDetection(
  word: 'apple',
  phonetic: '/apple/',
  meaning: 'quả táo',
  x: 0.1,
  y: 0.2,
  w: 0.3,
  h: 0.1,
);

class _OverlayHarness extends StatefulWidget {
  const _OverlayHarness({
    required this.imageProvider,
    required this.initialWords,
    this.initialSize = const Size(800, 600),
    this.onLabelTap,
    super.key,
  });

  final ImageProvider imageProvider;
  final List<VocabDetection> initialWords;
  final Size initialSize;
  final void Function(VocabDetection word)? onLabelTap;

  @override
  State<_OverlayHarness> createState() => _OverlayHarnessState();
}

class _OverlayHarnessState extends State<_OverlayHarness> {
  late ImageProvider _imageProvider = widget.imageProvider;
  late List<VocabDetection> _words = widget.initialWords;
  late Size _size = widget.initialSize;

  void rebuildWithoutChanges() => setState(() {});

  void update({
    ImageProvider? imageProvider,
    List<VocabDetection>? words,
    Size? size,
  }) {
    setState(() {
      _imageProvider = imageProvider ?? _imageProvider;
      _words = words ?? _words;
      _size = size ?? _size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: _size,
          child: VocabCanvasOverlay(
            imageProvider: _imageProvider,
            words: _words,
            onLabelTap: widget.onLabelTap,
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required Widget harness,
  required ImageProvider imageProvider,
}) async {
  await tester.pumpWidget(harness);
  await tester.runAsync(
    () => precacheImage(
      imageProvider,
      tester.element(find.byType(VocabCanvasOverlay)),
    ),
  );
  await tester.pump();
}

List<VocabDetection> _wardrobeDetections() {
  return List.generate(wardrobeWords.length, (index) {
    final word = wardrobeWords[index];
    final box = wardrobeNormalizedBoxes[index];
    return VocabDetection(
      number: word.number,
      word: word.word,
      phonetic: word.phonetic,
      meaning: word.meaning,
      partOfSpeech: word.partOfSpeech,
      x: box.left,
      y: box.top,
      w: box.width,
      h: box.height,
    );
  });
}

List<VocabDetection> _maximumVocabularyDetections() {
  return [
    ..._wardrobeDetections(),
    const VocabDetection(
      number: 13,
      word: 'shelf',
      phonetic: '/ʃelf/',
      meaning: 'kệ',
      x: 0.18,
      y: 0.24,
      w: 0.1,
      h: 0.1,
    ),
    const VocabDetection(
      number: 14,
      word: 'scarf',
      phonetic: '/skɑːrf/',
      meaning: 'khăn quàng',
      x: 0.44,
      y: 0.24,
      w: 0.1,
      h: 0.1,
    ),
    const VocabDetection(
      number: 15,
      word: 'hat',
      phonetic: '/hæt/',
      meaning: 'mũ',
      x: 0.70,
      y: 0.24,
      w: 0.1,
      h: 0.1,
    ),
  ];
}

List<VocabDetection> _withCacheRevision(
  List<VocabDetection> words,
  int revision,
) {
  return words
      .map(
        (word) => VocabDetection(
          number: word.number,
          word: word.word,
          phonetic: word.phonetic,
          meaning: word.meaning,
          partOfSpeech: 'benchmark-$revision',
          x: word.x,
          y: word.y,
          w: word.w,
          h: word.h,
        ),
      )
      .toList(growable: false);
}

VocabOverlayPainter _overlayPainter(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VocabOverlayPainter,
    ),
  );
  return customPaint.painter! as VocabOverlayPainter;
}

Uint8List _testImageBytes() => Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );

Future<Uint8List> _createPngBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Offset _customPaintTopLeft(WidgetTester tester) {
  return tester.getTopLeft(
    find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VocabOverlayPainter,
    ),
  );
}

Offset _referencePointToCanvas(
  VocabOverlayPainter painter,
  Offset referencePoint,
) {
  final referenceSize = painter.referenceCanvasSize!;
  final scale = painter.imageRect.width / referenceSize.width;
  return painter.imageRect.topLeft + referencePoint * scale;
}

Rect _referenceRectToCanvas(
  VocabOverlayPainter painter,
  Rect referenceRect,
) {
  final topLeft = _referencePointToCanvas(painter, referenceRect.topLeft);
  final bottomRight = _referencePointToCanvas(
    painter,
    referenceRect.bottomRight,
  );
  return Rect.fromPoints(topLeft, bottomRight);
}

Rect _normalizeToImage(Rect rect, Rect imageRect) => Rect.fromLTRB(
      (rect.left - imageRect.left) / imageRect.width,
      (rect.top - imageRect.top) / imageRect.height,
      (rect.right - imageRect.left) / imageRect.width,
      (rect.bottom - imageRect.top) / imageRect.height,
    );

Matcher _rectCloseTo(Rect expected) => predicate<Rect>(
      (actual) =>
          (actual.left - expected.left).abs() < 0.000001 &&
          (actual.top - expected.top).abs() < 0.000001 &&
          (actual.right - expected.right).abs() < 0.000001 &&
          (actual.bottom - expected.bottom).abs() < 0.000001,
      'Rect close to $expected',
    );

Matcher _rectWithinHalfPixel(Rect expected) => predicate<Rect>(
      (actual) =>
          (actual.left - expected.left).abs() < 0.5 &&
          (actual.top - expected.top).abs() < 0.5 &&
          (actual.right - expected.right).abs() < 0.5 &&
          (actual.bottom - expected.bottom).abs() < 0.5,
      'Rect within 0.5px of $expected',
    );

int _pixelAlpha(ByteData bytes, int imageWidth, Offset point) {
  final x = point.dx.round();
  final y = point.dy.round();
  return bytes.getUint8((y * imageWidth + x) * 4 + 3);
}
