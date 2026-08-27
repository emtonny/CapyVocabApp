import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/vocab_scan/domain/image_rect_calculator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_candidate_generator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_size_measurer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wardrobe_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('soft tier starts at directional clearance and stops at 20 percent', () {
    const anchorBox = Rect.fromLTWH(89, 189, 22, 22);
    const labelSize = Size(70.4, 46);
    final candidates = generateCandidates(
      anchorBox: anchorBox,
      labelSize: labelSize,
      canvasSize: const Size(400, 800),
      angleDegrees: const [0],
      radiusTier: CandidateRadiusTier.soft,
    );

    expect(candidates, hasLength(4));
    final radii = candidates
        .map((topLeft) =>
            (_centerOf(topLeft, labelSize) - anchorBox.center).distance)
        .toList();
    // 400 px short side gives a 12 px step and an exact 80 px soft boundary.
    expect(radii[0], closeTo(52.2, 1e-9));
    expect(radii[1], closeTo(64.2, 1e-9));
    expect(radii[2], closeTo(76.2, 1e-9));
    expect(radii[3], closeTo(80, 1e-9));
  });

  test('hard tier resumes after soft cap and reaches the 100.2 px gap', () {
    const anchorBox = Rect.fromLTWH(89, 189, 22, 22);
    const labelSize = Size(70.4, 46);
    final candidates = generateCandidates(
      anchorBox: anchorBox,
      labelSize: labelSize,
      canvasSize: const Size(400, 800),
      angleDegrees: const [0],
      radiusTier: CandidateRadiusTier.hard,
    );

    expect(candidates, hasLength(4));
    final radii = candidates
        .map((topLeft) =>
            (_centerOf(topLeft, labelSize) - anchorBox.center).distance)
        .toList();
    // Continue the same 12 px progression, then sample the exact 120 px cap.
    expect(radii[0], closeTo(88.2, 1e-9));
    expect(radii[1], closeTo(100.2, 1e-9));
    expect(radii[2], closeTo(112.2, 1e-9));
    expect(radii[3], closeTo(120, 1e-9));
    expect(
      candidates.every((topLeft) =>
          (_centerOf(topLeft, labelSize) - anchorBox.center).distance > 80),
      isTrue,
    );
  });

  test('closer directional clearance wins before supplied angle rank', () {
    const anchorBox = Rect.fromLTWH(89, 189, 22, 22);
    const labelSize = Size(70.4, 46);
    final candidates = generateCandidates(
      anchorBox: anchorBox,
      labelSize: labelSize,
      canvasSize: const Size(400, 800),
      angleDegrees: const [0, 90],
      radiusTier: CandidateRadiusTier.soft,
    );

    expect(
      _centerOf(candidates.first, labelSize),
      _offsetCloseTo(const Offset(100, 240)),
    );
  });

  test('equal-distance candidates preserve the supplied angle order', () {
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
      angleDegrees: angleDegrees,
    );

    final firstRadius =
        (_centerOf(candidates.first, labelSize) - const Offset(1000, 1000))
            .distance;
    final firstRing = candidates.takeWhile((topLeft) {
      final radius =
          (_centerOf(topLeft, labelSize) - const Offset(1000, 1000)).distance;
      return (radius - firstRadius).abs() <= 1e-9;
    }).toList();
    expect(firstRing, hasLength(2));
    // Vertical clearance is smaller here; 90° still precedes 270° because the
    // supplied angle order is the tie-break after equal radius.
    expect(_centerOf(firstRing[0], labelSize).dy, greaterThan(1000));
    expect(_centerOf(firstRing[1], labelSize).dy, lessThan(1000));
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
      angleDegrees: const [0, 90],
    );

    expect(
      candidates.any((topLeft) {
        final center = _centerOf(topLeft, labelSize);
        return center.dx > 100 && (center.dy - 100).abs() <= 1e-9;
      }),
      isTrue,
    );
    expect(
      candidates.any((topLeft) {
        final center = _centerOf(topLeft, labelSize);
        return center.dy > 100 && (center.dx - 100).abs() <= 1e-9;
      }),
      isTrue,
    );
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
      angleDegrees: const [225, 45],
    );

    // Every 225° sample is outside the canvas; all surviving samples belong
    // to the down-right 45° direction and remain ordered nearest first.
    expect(candidates, hasLength(5));
    expect(
      candidates.every((topLeft) {
        final center = _centerOf(topLeft, labelSize);
        return center.dx > 20 && center.dy > 20;
      }),
      isTrue,
    );
    expect(
      _centerOf(candidates.first, labelSize),
      _offsetCloseTo(const Offset(46, 46)),
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
    const angles = <double>[0, 45, 90, 135, 180, 225, 270, 315];
    final measured = const LabelSizeMeasurer().measure(sampleWord, style);
    final labelSize = Size(measured.width, measured.height);

    debugPrint('WARDROBE_CANDIDATE_TABLE');
    debugPrint('word=${sampleWord.word}, anchor=$anchorBox, label=$labelSize');
    debugPrint('tier | candidate | radius | topLeft.dx | topLeft.dy');
    for (final tier in CandidateRadiusTier.values) {
      final candidates = generateCandidates(
        anchorBox: anchorBox,
        labelSize: labelSize,
        canvasSize: canvasSize,
        angleDegrees: angles,
        radiusTier: tier,
      );
      expect(candidates, isNotEmpty);
      for (final (candidateIndex, topLeft) in candidates.indexed) {
        final radius =
            (_centerOf(topLeft, labelSize) - anchorBox.center).distance;
        debugPrint(
          '${tier.name} | $candidateIndex | ${radius.toStringAsFixed(2)} | '
          '${topLeft.dx.toStringAsFixed(2)} | ${topLeft.dy.toStringAsFixed(2)}',
        );
      }
    }
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
