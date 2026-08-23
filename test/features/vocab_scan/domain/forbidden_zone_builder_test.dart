import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/vocab_scan/domain/forbidden_zone_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts a normalized box through a real letterboxed image rect', () {
    const word = VocabDetection(
      word: 'shirt',
      phonetic: '/shirt/',
      meaning: 'áo sơ mi',
      x: 0.1,
      y: 0.1,
      w: 0.2,
      h: 0.2,
    );

    final zones = ForbiddenZoneBuilder.build(
      words: const [word],
      sourceImageSize: const Size(400, 400),
      canvasSize: const Size(400, 800),
    );

    // A 400x400 image is centered at y=200 in a 400x800 canvas. The box is
    // (40, 240, 80, 80), then the default 6px margin is applied.
    expect(zones, hasLength(1));
    expect(zones.single, _rectCloseTo(const Rect.fromLTWH(34, 234, 92, 92)));
  });

  test('nearby boxes overlap after each forbidden zone is inflated', () {
    const words = [
      VocabDetection(
        word: 'shirt',
        phonetic: '/shirt/',
        meaning: 'áo sơ mi',
        x: 0.1,
        y: 0.1,
        w: 0.2,
        h: 0.2,
      ),
      VocabDetection(
        word: 'jacket',
        phonetic: '/jacket/',
        meaning: 'áo khoác',
        x: 0.325,
        y: 0.1,
        w: 0.2,
        h: 0.2,
      ),
    ];

    final zones = ForbiddenZoneBuilder.build(
      words: words,
      sourceImageSize: const Size(400, 400),
      canvasSize: const Size(400, 400),
    );

    expect(zones, hasLength(2));
    expect(anyOverlap(zones.first, [zones.last]), isTrue);
  });

  test('inflated edge box is clamped to the canvas bounds', () {
    const word = VocabDetection(
      word: 'mirror',
      phonetic: '/mirror/',
      meaning: 'gương',
      x: 0.95,
      y: 0.95,
      w: 0.05,
      h: 0.05,
    );
    const canvasSize = Size(400, 400);

    final zone = ForbiddenZoneBuilder.build(
      words: const [word],
      sourceImageSize: canvasSize,
      canvasSize: canvasSize,
    ).single;

    expect(zone.left, greaterThanOrEqualTo(0));
    expect(zone.top, greaterThanOrEqualTo(0));
    expect(zone.right, lessThanOrEqualTo(canvasSize.width));
    expect(zone.bottom, lessThanOrEqualTo(canvasSize.height));
    expect(zone.right, canvasSize.width);
    expect(zone.bottom, canvasSize.height);
  });

  test('anyOverlap independently identifies overlap and separation', () {
    const zone = Rect.fromLTWH(10, 10, 20, 20);

    expect(
      anyOverlap(const Rect.fromLTWH(20, 20, 20, 20), const [zone]),
      isTrue,
    );
    expect(
      anyOverlap(const Rect.fromLTWH(40, 40, 10, 10), const [zone]),
      isFalse,
    );
  });
}

Matcher _rectCloseTo(Rect expected) => predicate<Rect>(
      (actual) =>
          (actual.left - expected.left).abs() < 0.5 &&
          (actual.top - expected.top).abs() < 0.5 &&
          (actual.right - expected.right).abs() < 0.5 &&
          (actual.bottom - expected.bottom).abs() < 0.5,
      'Rect within 0.5 logical pixels of $expected',
    );
