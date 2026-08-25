import 'dart:ui' as ui;

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/vocab_scan/domain/forbidden_zone_builder.dart';
import 'package:capy_vocab/features/vocab_scan/domain/image_rect_calculator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_connector_geometry.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_placement_solver.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_size_measurer.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_unit_geometry.dart';
import 'package:capy_vocab/features/vocab_scan/presentation/label_connector_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wardrobe_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fallbackEdge zero-length connector paints without division by zero',
      () {
    const labelRect = Rect.fromLTWH(0, 0, 100, 100);
    const targetBox = Rect.fromLTWH(25, 25, 50, 50);
    final path = computeConnectorPath(
      labelRect: labelRect,
      targetBox: targetBox,
    );
    expect(path.from, path.to);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      () => paintAllConnectors(
        canvas,
        const [
          PlacedLabel(
            word: VocabDetection(
              word: 'contained',
              phonetic: '',
              meaning: 'contained',
              x: 0.25,
              y: 0.25,
              w: 0.5,
              h: 0.5,
            ),
            labelRect: labelRect,
            anchorBox: targetBox,
            quality: PlacementQuality.fallbackEdge,
          ),
        ],
      ),
      returnsNormally,
    );
    recorder.endRecording().dispose();
  });

  test('connector resolver anchors to card instead of transparent footprint',
      () {
    const placed = PlacedLabel(
      word: VocabDetection(
        word: 'mirror',
        phonetic: '/mirror/',
        meaning: 'gương',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
      labelRect: Rect.fromLTWH(0, 0, 100, 80),
      anchorBox: Rect.fromLTWH(140, 30, 20, 20),
      quality: PlacementQuality.ideal,
    );
    const cardRect = Rect.fromLTWH(20, 20, 60, 40);

    final footprintPath = connectorPathForPlacedLabel(placed);
    final cardPath = connectorPathForPlacedLabel(
      placed,
      labelRectResolver: (_) => cardRect,
    );

    expect(footprintPath.from.dx, placed.labelRect.right);
    expect(cardPath.from.dx, cardRect.right);
    expect(cardPath.from.dx, lessThan(footprintPath.from.dx));
  });

  testWidgets(
      'renders solid and dashed connectors for the 12-word wardrobe solve',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final placedLabels = _solveWardrobeDemo();
    expect(placedLabels, hasLength(12));
    expect(
      placedLabels.any(
        (placed) => placed.quality == PlacementQuality.fallbackEdge,
      ),
      isTrue,
    );
    expect(
      placedLabels.any(
        (placed) => placed.quality != PlacementQuality.fallbackEdge,
      ),
      isTrue,
    );

    const repaintKey = Key('wardrobe-connector-demo');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F2EA),
          body: Center(
            child: RepaintBoundary(
              key: repaintKey,
              child: CustomPaint(
                size: _canvasSize,
                painter: _WardrobeConnectorDemoPainter(placedLabels),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(repaintKey),
      matchesGoldenFile('goldens/label_connectors_wardrobe_floating_badge.png'),
    );
  });
}

List<PlacedLabel> _solveWardrobeDemo() {
  final words = List<VocabDetection>.generate(wardrobeWords.length, (index) {
    final source = wardrobeWords[index];
    final box = wardrobeNormalizedBoxes[index];
    return VocabDetection(
      word: source.word,
      phonetic: source.phonetic,
      meaning: source.meaning,
      x: box.left,
      y: box.top,
      w: box.width,
      h: box.height,
    );
  });
  final imageRect = ImageRectCalculator.calculate(
    sourceImageSize: _sourceImageSize,
    canvasSize: _canvasSize,
  );
  final anchorBoxes = words
      .map(
        (word) => ImageRectCalculator.detectionRect(
          detection: word,
          imageRect: imageRect,
        ),
      )
      .toList(growable: false);

  return solve(
    words: words,
    labelSizes: const LabelSizeMeasurer().measureAll(words, _fullStyle),
    anchorBoxes: anchorBoxes,
    forbiddenZones: ForbiddenZoneBuilder.build(
      words: words,
      sourceImageSize: _sourceImageSize,
      canvasSize: _canvasSize,
    ),
    canvasSize: _canvasSize,
    measurer: const LabelSizeMeasurer(),
    compactStyleConfig: _compactStyle,
  );
}

class _WardrobeConnectorDemoPainter extends CustomPainter {
  const _WardrobeConnectorDemoPainter(this.placedLabels);

  final List<PlacedLabel> placedLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF8F5EE);
    final imageAreaPaint = Paint()..color = const Color(0xFFE5E0D5);
    final targetFill = Paint()..color = const Color(0x33FFB300);
    final targetBorder = Paint()
      ..color = const Color(0xFFFF8F00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final normalCardPaint = Paint()..color = const Color(0xFFFDFDFD);
    final edgeCardPaint = Paint()..color = const Color(0xFFFFE0B2);
    final cardBorder = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Offset.zero & size, backgroundPaint);
    canvas.drawRect(
      ImageRectCalculator.calculate(
        sourceImageSize: _sourceImageSize,
        canvasSize: size,
      ),
      imageAreaPaint,
    );

    for (final placed in placedLabels) {
      canvas
        ..drawRect(placed.anchorBox, targetFill)
        ..drawRect(placed.anchorBox, targetBorder);
    }

    paintAllConnectors(
      canvas,
      placedLabels,
      labelRectResolver: (placed) => _geometryFor(placed).cardRect,
      canvasSize: size,
    );

    for (final placed in placedLabels) {
      final isEdge = placed.quality == PlacementQuality.fallbackEdge;
      final labelStyle =
          placed.quality == PlacementQuality.ideal ? _fullStyle : _compactStyle;
      final geometry = _geometryFor(placed);
      final rounded = RRect.fromRectAndRadius(
        geometry.cardRect,
        const Radius.circular(5),
      );
      canvas
        ..drawCircle(
          geometry.badgeRect.center,
          geometry.badgeRect.width / 2,
          normalCardPaint,
        )
        ..drawCircle(
          geometry.badgeRect.center,
          geometry.badgeRect.width / 2 - 0.5,
          cardBorder,
        );
      canvas
        ..drawRRect(rounded, isEdge ? edgeCardPaint : normalCardPaint)
        ..drawRRect(rounded, cardBorder);

      final textPainter = TextPainter(
        text: TextSpan(
          text: placed.word.word,
          style: labelStyle.wordStyle.copyWith(
            color: const Color(0xFF3E2723),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: geometry.cardRect.width - 12);
      textPainter.paint(
        canvas,
        Offset(
          geometry.cardRect.left + 6,
          geometry.cardRect.center.dy - textPainter.height / 2,
        ),
      );
      textPainter.dispose();
    }

    _paintLegend(canvas);
  }

  void _paintLegend(Canvas canvas) {
    final legend = TextPainter(
      text: const TextSpan(
        text: 'SOLID = standard     DASHED = fallbackEdge',
        style: TextStyle(
          color: Color(0xFF5D4037),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _canvasSize.width - 24);
    legend.paint(canvas, const Offset(12, 12));
  }

  @override
  bool shouldRepaint(covariant _WardrobeConnectorDemoPainter oldDelegate) {
    return oldDelegate.placedLabels != placedLabels;
  }
}

LabelUnitGeometry _geometryFor(PlacedLabel placed) {
  final style =
      placed.quality == PlacementQuality.ideal ? _fullStyle : _compactStyle;
  return resolvePlacedLabelUnitGeometry(
    footprintRect: placed.labelRect,
    badgeSize: style.badgeSize,
  );
}

const _sourceImageSize = Size(400, 400);
const _canvasSize = Size(300, 500);

const _fullStyle = LabelStyleConfig(
  badgeTextStyle: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
  badgeWidth: 16,
  badgeHeight: 16,
  wordStyle: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
  phoneticStyle: TextStyle(fontSize: 6, fontStyle: FontStyle.italic),
  meaningStyle: TextStyle(fontSize: 7),
  padding: LabelPaddingConfig(horizontal: 6, vertical: 4, bottom: 7),
  mode: LabelCardMode.full,
  lineSpacing: 1,
);

const _compactStyle = LabelStyleConfig(
  badgeTextStyle: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
  badgeWidth: 16,
  badgeHeight: 16,
  wordStyle: TextStyle(fontSize: 6, fontWeight: FontWeight.w700),
  phoneticStyle: TextStyle(fontSize: 6, fontStyle: FontStyle.italic),
  meaningStyle: TextStyle(fontSize: 6),
  padding: LabelPaddingConfig(horizontal: 4, vertical: 2, bottom: 5),
  mode: LabelCardMode.compact,
  lineSpacing: 0,
);
