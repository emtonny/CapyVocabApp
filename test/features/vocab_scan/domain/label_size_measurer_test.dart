import 'dart:math' as math;

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_size_measurer.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_unit_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wardrobe_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const measurer = LabelSizeMeasurer();

  test('measuring the same badge-card footprint twice is deterministic', () {
    final first = measurer.measure(wardrobeWords.first, _fullConfig);
    final second = measurer.measure(wardrobeWords.first, _fullConfig);

    expect(second, first);
    expect(second.width, first.width);
    expect(second.height, first.height);
  });

  test('TV and refrigerator produce ordered finite footprint widths', () {
    const shortWord = VocabDetection(
      word: 'TV',
      phonetic: '/TV/',
      meaning: 'tivi',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );
    const longWord = VocabDetection(
      word: 'refrigerator',
      phonetic: '/refrigerator/',
      meaning: 'tủ lạnh',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

    final shortSize = measurer.measure(shortWord, _fullConfig);
    final longSize = measurer.measure(longWord, _fullConfig);

    expect(longSize.width, greaterThan(shortSize.width));
    for (final size in [shortSize, longSize]) {
      expect(size.width, isPositive);
      expect(size.height, isPositive);
      expect(size.width.isFinite, isTrue);
      expect(size.height.isFinite, isTrue);
      expect(size.width.isNaN, isFalse);
      expect(size.height.isNaN, isFalse);
    }
  });

  test('compact uses the 6px floor and a smaller measured footprint', () {
    final compact = measurer.measure(wardrobeWords.first, _compactConfig);
    final full = measurer.measure(wardrobeWords.first, _fullConfig);

    expect(full.width, greaterThan(compact.width));
    expect(full.height, greaterThan(compact.height));
    expect(_fullConfig.badgeTextStyle, _compactConfig.badgeTextStyle);
    expect(_fullConfig.wordStyle.fontSize, 7);
    expect(_compactConfig.wordStyle.fontSize, 6);
    expect(_fullConfig.phoneticStyle, _compactConfig.phoneticStyle);
    expect(_compactConfig.phoneticStyle.fontSize, 6);
    expect(_fullConfig.meaningStyle.fontSize, 7);
    expect(_compactConfig.meaningStyle.fontSize, 6);
    debugPrint(
      'FALLBACK_FONT_SIZE_EVIDENCE word=${wardrobeWords.first.word} '
      'full=${full.width}x${full.height} compact=${compact.width}x${compact.height} '
      'fullFonts=7/6/7 compactFonts=6/6/6',
    );
  });

  test('optional icon contributes to the word row and complete footprint', () {
    final withoutIcon = measurer.measure(wardrobeWords.first, _fullConfig);
    final withIcon = measurer.measure(
      wardrobeWords.first,
      _fullConfig.copyWith(iconWidth: 200, iconGap: 6),
    );

    expect(withIcon.width, greaterThan(withoutIcon.width));
    expect(withIcon.height, greaterThanOrEqualTo(withoutIcon.height));
  });

  test('measureAll returns one ordered footprint per detection', () {
    final sizes = measurer.measureAll(wardrobeWords, _fullConfig);

    expect(sizes, hasLength(wardrobeWords.length));
    expect(
      sizes.last,
      measurer.measure(wardrobeWords.last, _fullConfig),
    );
  });

  test('card measurement contains exactly word, IPA, and Vietnamese lines', () {
    const word = VocabDetection(
      number: 15,
      word: 'TV',
      phonetic: '/TV/',
      meaning: 'một cụm nghĩa tiếng Việt rất dài',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );
    final card = measurer.measureCard(word, _fullConfig);
    final lineSizes = [
      _measureLine(word.word, _fullConfig.wordStyle),
      _measureLine(word.phonetic, _fullConfig.phoneticStyle),
      _measureLine(word.meaningVi, _fullConfig.meaningStyle),
    ];
    final expectedWidth = math.max(
      lineSizes.map((size) => size.width).reduce(math.max) +
          _fullConfig.padding.horizontal * 2,
      _fullConfig.badgeSize.width,
    );
    final expectedHeight = lineSizes.fold<double>(
          0,
          (total, size) => total + size.height,
        ) +
        _fullConfig.lineSpacing * 2 +
        _fullConfig.padding.vertical +
        _fullConfig.padding.bottom;

    expect(card, LabelSize(width: expectedWidth, height: expectedHeight));
  });

  test('one- and two-digit numbers do not change fixed unit geometry', () {
    const oneDigit = VocabDetection(
      number: 1,
      word: 'mirror',
      phonetic: '/mirror/',
      meaning: 'gương',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );
    const twoDigits = VocabDetection(
      number: 15,
      word: 'mirror',
      phonetic: '/mirror/',
      meaning: 'gương',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

    expect(measurer.measure(twoDigits, _fullConfig),
        measurer.measure(oneDigit, _fullConfig));
    expect(measurer.measureCard(twoDigits, _fullConfig),
        measurer.measureCard(oneDigit, _fullConfig));
  });

  test('badge numbers 1, 9, 10, 11, and 15 fit the fixed circle', () {
    for (final number in const [1, 9, 10, 11, 15]) {
      final fullText = _measureLine('$number', _fullConfig.badgeTextStyle);
      final compactText = _measureLine(
        '$number',
        _compactConfig.badgeTextStyle,
      );

      expect(fullText.width, lessThanOrEqualTo(_fullConfig.badgeSize.width));
      expect(fullText.height, lessThanOrEqualTo(_fullConfig.badgeSize.height));
      expect(
        compactText.width,
        lessThanOrEqualTo(_compactConfig.badgeSize.width),
      );
      expect(
        compactText.height,
        lessThanOrEqualTo(_compactConfig.badgeSize.height),
      );
    }
  });

  test('prints previous versus reconciled full-style footprint evidence', () {
    final footprints = measurer.measureAll(wardrobeWords, _fullConfig);
    final cards = wardrobeWords
        .map((word) => measurer.measureCard(word, _fullConfig))
        .toList(growable: false);
    final changes = <double>[];

    debugPrint('RECONCILED_FULL_STYLE_WARDROBE_FOOTPRINT_TABLE');
    debugPrint(
      'word | previous_w | previous_h | previous_area | card_w | '
      'card_h | footprint_w | footprint_h | footprint_area | change',
    );
    for (var index = 0; index < wardrobeWords.length; index++) {
      final previous = _previousTask9Footprints[index];
      final card = cards[index];
      final footprint = footprints[index];
      final previousArea = previous.width * previous.height;
      final footprintArea = footprint.width * footprint.height;
      final change = footprintArea / previousArea - 1;
      changes.add(change);
      debugPrint(
        '${wardrobeWords[index].word} | '
        '${previous.width.toStringAsFixed(2)} | '
        '${previous.height.toStringAsFixed(2)} | '
        '${previousArea.toStringAsFixed(2)} | ${card.width.toStringAsFixed(2)} | '
        '${card.height.toStringAsFixed(2)} | '
        '${footprint.width.toStringAsFixed(2)} | '
        '${footprint.height.toStringAsFixed(2)} | '
        '${footprintArea.toStringAsFixed(2)} | '
        '${(change * 100).toStringAsFixed(2)}%',
      );
    }

    final sorted = [...changes]..sort();
    final average = changes.reduce((a, b) => a + b) / changes.length;
    final median = (sorted[5] + sorted[6]) / 2;
    final reducedCount = changes.where((value) => value < 0).length;
    final increasedCount = changes.where((value) => value > 0).length;
    debugPrint(
      'SUMMARY average=${(average * 100).toStringAsFixed(2)}% '
      'median=${(median * 100).toStringAsFixed(2)}% '
      'worst=${(sorted.first * 100).toStringAsFixed(2)}% '
      'best=${(sorted.last * 100).toStringAsFixed(2)}% '
      'reduced=$reducedCount increased=$increasedCount',
    );

    expect(average.isFinite, isTrue);
    expect(reducedCount + increasedCount, wardrobeWords.length);
  });

  test('measured footprint equals the pure badge-card union', () {
    final card = measurer.measureCard(wardrobeWords.first, _fullConfig);
    final footprint = measurer.measure(wardrobeWords.first, _fullConfig);
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: Size(card.width, card.height),
      badgeSize: _fullConfig.badgeSize,
    );

    expect(
      footprint,
      LabelSize(
        width: geometry.footprintRect.width,
        height: geometry.footprintRect.height,
      ),
    );
  });
}

const _fullConfig = LabelStyleConfig(
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

const _compactConfig = LabelStyleConfig(
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

Size _measureLine(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

// Snapshot captured from the approved overlapping-badge Task 9 layout.
const _previousTask9Footprints = [
  LabelSize(width: 134, height: 52),
  LabelSize(width: 104, height: 52),
  LabelSize(width: 124, height: 52),
  LabelSize(width: 104, height: 52),
  LabelSize(width: 114, height: 52),
  LabelSize(width: 114, height: 52),
  LabelSize(width: 104, height: 52),
  LabelSize(width: 104, height: 52),
  LabelSize(width: 84, height: 52),
  LabelSize(width: 94, height: 52),
  LabelSize(width: 104, height: 52),
  LabelSize(width: 94, height: 52),
];
