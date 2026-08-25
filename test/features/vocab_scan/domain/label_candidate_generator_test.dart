import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/vocab_scan/domain/image_rect_calculator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_candidate_generator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_size_measurer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wardrobe_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('five rings and eight angles produce 40 candidates on a large canvas',
      () {
    final candidates = generateCandidates(
      anchorBox: Rect.fromCenter(
        center: const Offset(1000, 1000),
        width: 20,
        height: 20,
      ),
      labelSize: const Size(20, 10),
      canvasSize: const Size(2000, 2000),
    );

    expect(candidates, hasLength(40));
  });

  test('the first eight candidates preserve the supplied angle order', () {
    const labelSize = Size(20, 10);
    const angleDegrees = <double>[0, 45, 90, 135, 180, 225, 270, 315];
    final candidates = generateCandidates(
      anchorBox: Rect.fromCenter(
        center: const Offset(1000, 1000),
        width: 50,
        height: 20,
      ),
      labelSize: labelSize,
      canvasSize: const Size(2000, 2000),
      ringFactors: const [1, 2],
      angleDegrees: angleDegrees,
    );
    const diagonal = 35.35533905932738;
    const expectedCenters = [
      Offset(1050, 1000),
      Offset(1000 + diagonal, 1000 + diagonal),
      Offset(1000, 1050),
      Offset(1000 - diagonal, 1000 + diagonal),
      Offset(950, 1000),
      Offset(1000 - diagonal, 1000 - diagonal),
      Offset(1000, 950),
      Offset(1000 + diagonal, 1000 - diagonal),
    ];

    expect(candidates, hasLength(16));
    for (var index = 0; index < angleDegrees.length; index++) {
      expect(
        _centerOf(candidates[index], labelSize),
        _offsetCloseTo(expectedCenters[index]),
        reason: 'angle ${angleDegrees[index]} must remain at index $index',
      );
    }
  });

  test('0 degrees points right and 90 degrees points down', () {
    const labelSize = Size(20, 10);
    final candidates = generateCandidates(
      anchorBox: Rect.fromCenter(
        center: const Offset(100, 100),
        width: 50,
        height: 20,
      ),
      labelSize: labelSize,
      canvasSize: const Size(300, 300),
      ringFactors: const [1],
      angleDegrees: const [0, 90],
    );

    expect(candidates, hasLength(2));
    expect(_centerOf(candidates[0], labelSize),
        _offsetCloseTo(const Offset(150, 100)));
    expect(_centerOf(candidates[1], labelSize),
        _offsetCloseTo(const Offset(100, 150)));
  });

  test('recovery angles add unique 15 and 30 degree offsets', () {
    final recoveryAngles = generateRecoveryAngleDegrees(
      defaultCandidateAngleDegrees,
    );

    expect(recoveryAngles, hasLength(16));
    expect(recoveryAngles.take(4), [345, 15, 330, 30]);
    expect(
      recoveryAngles.where((angle) => angle % 45 == 0),
      isEmpty,
    );
    expect(recoveryAngles.toSet(), hasLength(recoveryAngles.length));
  });

  test('outward top-left candidate is filtered while down-right remains', () {
    const labelSize = Size(20, 20);
    final candidates = generateCandidates(
      anchorBox: const Rect.fromLTWH(10, 10, 20, 20),
      labelSize: labelSize,
      canvasSize: const Size(400, 400),
      ringFactors: const [1],
      angleDegrees: const [225, 45],
    );

    expect(candidates, hasLength(1));
    expect(
      _centerOf(candidates.single, labelSize),
      _offsetCloseTo(const Offset(34.14213562373095, 34.14213562373095)),
    );
  });

  test('prints all valid candidates for a wardrobe sample on 400x800', () {
    const sourceImageSize = Size(400, 400);
    const canvasSize = Size(400, 800);
    final sourceWord = wardrobeWords[1];
    final sampleWord = VocabDetection(
      word: sourceWord.word,
      phonetic: sourceWord.phonetic,
      meaning: sourceWord.meaning,
      x: 0.45,
      y: 0.45,
      w: 0.1,
      h: 0.1,
    );
    final imageRect = ImageRectCalculator.calculate(
      sourceImageSize: sourceImageSize,
      canvasSize: canvasSize,
    );
    final anchorBox = ImageRectCalculator.detectionRect(
      detection: sampleWord,
      imageRect: imageRect,
    );
    const style = LabelStyleConfig(
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
    const ringFactors = <double>[1, 1.5, 2, 2.8, 3.6];
    const angles = <double>[0, 45, 90, 135, 180, 225, 270, 315];
    final measured = const LabelSizeMeasurer().measure(sampleWord, style);
    final labelSize = Size(measured.width, measured.height);
    final candidates = generateCandidates(
      anchorBox: anchorBox,
      labelSize: labelSize,
      canvasSize: canvasSize,
      ringFactors: ringFactors,
      angleDegrees: angles,
    );

    debugPrint('WARDROBE_CANDIDATE_TABLE');
    debugPrint('word=${sampleWord.word}, anchor=$anchorBox, label=$labelSize');
    debugPrint('candidate | ring | angle | topLeft.dx | topLeft.dy');
    var candidateIndex = 0;
    for (var ringIndex = 0; ringIndex < ringFactors.length; ringIndex++) {
      for (final angle in angles) {
        final atRingAndAngle = generateCandidates(
          anchorBox: anchorBox,
          labelSize: labelSize,
          canvasSize: canvasSize,
          ringFactors: [ringFactors[ringIndex]],
          angleDegrees: [angle],
        );
        if (atRingAndAngle.isEmpty) continue;

        final topLeft = atRingAndAngle.single;
        expect(candidates[candidateIndex], _offsetCloseTo(topLeft));
        debugPrint(
          '$candidateIndex | $ringIndex | ${angle.toStringAsFixed(0)} | '
          '${topLeft.dx.toStringAsFixed(2)} | ${topLeft.dy.toStringAsFixed(2)}',
        );
        candidateIndex++;
      }
    }
    expect(candidateIndex, candidates.length);
  });
}

Offset _centerOf(Offset topLeft, Size labelSize) {
  return topLeft + Offset(labelSize.width / 2, labelSize.height / 2);
}

Matcher _offsetCloseTo(Offset expected) => predicate<Offset>(
      (actual) =>
          (actual.dx - expected.dx).abs() < 0.5 &&
          (actual.dy - expected.dy).abs() < 0.5,
      'Offset within 0.5 logical pixels of $expected',
    );
