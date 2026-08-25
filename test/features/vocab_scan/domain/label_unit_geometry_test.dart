import 'package:capy_vocab/features/vocab_scan/domain/label_unit_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const badgeSize = Size.square(16);

  test('card covers the bottom three pixels of the left-aligned badge', () {
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: const Offset(10, 20),
      cardSize: const Size(100, 42),
      badgeSize: badgeSize,
    );

    expect(geometry.badgeRect, const Rect.fromLTWH(10, 20, 16, 16));
    expect(geometry.cardRect, const Rect.fromLTWH(10, 33, 100, 42));
    expect(geometry.footprintRect, const Rect.fromLTWH(10, 20, 100, 55));
    expect(geometry.badgeRect.bottom - geometry.cardRect.top, 3);
    expect(geometry.badgeRect.left, geometry.cardRect.left);
    expect(geometry.badgeRect.overlaps(geometry.cardRect), isTrue);
  });

  test('footprint contains the complete floating badge and card', () {
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: const Size(80, 42),
      badgeSize: badgeSize,
    );

    expect(
      geometry.footprintRect.expandToInclude(geometry.badgeRect),
      geometry.footprintRect,
    );
    expect(
      geometry.footprintRect.expandToInclude(geometry.cardRect),
      geometry.footprintRect,
    );
  });

  test('translation changes only absolute coordinates, not relative layout',
      () {
    final first = resolveLabelUnitGeometry(
      footprintTopLeft: const Offset(5, 7),
      cardSize: const Size(80, 42),
      badgeSize: badgeSize,
    );
    const delta = Offset(31, 47);
    final translated = resolveLabelUnitGeometry(
      footprintTopLeft: first.footprintRect.topLeft + delta,
      cardSize: first.cardRect.size,
      badgeSize: first.badgeRect.size,
    );

    expect(translated.footprintRect, first.footprintRect.shift(delta));
    expect(translated.cardRect, first.cardRect.shift(delta));
    expect(translated.badgeRect, first.badgeRect.shift(delta));
  });

  test('one- and two-digit labels share geometry for the same card size', () {
    LabelUnitGeometry geometryForNumber(int number) {
      expect(number, inInclusiveRange(1, 15));
      return resolveLabelUnitGeometry(
        footprintTopLeft: Offset.zero,
        cardSize: const Size(80, 42),
        badgeSize: badgeSize,
      );
    }

    final oneDigit = geometryForNumber(1);
    final twoDigits = geometryForNumber(15);
    expect(twoDigits.badgeRect, oneDigit.badgeRect);
    expect(twoDigits.cardRect, oneDigit.cardRect);
    expect(twoDigits.footprintRect, oneDigit.footprintRect);
  });

  test('badge size stays fixed when the card width grows', () {
    final narrow = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: const Size(40, 42),
      badgeSize: const Size(26, 16),
      badgeCardOverlap: 8,
    );
    final wide = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: const Size(160, 42),
      badgeSize: const Size(26, 16),
      badgeCardOverlap: 8,
    );

    expect(wide.cardRect.width, greaterThan(narrow.cardRect.width));
    expect(narrow.badgeRect.size, const Size(26, 16));
    expect(wide.badgeRect.size, narrow.badgeRect.size);
  });

  test('placed footprint round-trips to the same component rects', () {
    final original = resolveLabelUnitGeometry(
      footprintTopLeft: const Offset(30, 40),
      cardSize: const Size(90, 42),
      badgeSize: badgeSize,
    );
    final restored = resolvePlacedLabelUnitGeometry(
      footprintRect: original.footprintRect,
      badgeSize: badgeSize,
    );

    expect(restored.footprintRect, original.footprintRect);
    expect(restored.cardRect, original.cardRect);
    expect(restored.badgeRect, original.badgeRect);
  });

  test('configured overlap places half the pill inside the card', () {
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: const Offset(10, 20),
      cardSize: const Size(80, 42),
      badgeSize: const Size(26, 16),
      badgeCardOverlap: 8,
    );

    expect(geometry.badgeRect, const Rect.fromLTWH(10, 20, 26, 16));
    expect(geometry.cardRect, const Rect.fromLTWH(10, 28, 80, 42));
    expect(geometry.badgeRect.bottom - geometry.cardRect.top, 8);

    final restored = resolvePlacedLabelUnitGeometry(
      footprintRect: geometry.footprintRect,
      badgeSize: geometry.badgeRect.size,
      badgeCardOverlap: 8,
    );
    expect(restored.badgeRect, geometry.badgeRect);
    expect(restored.cardRect, geometry.cardRect);
  });

  test('decorations match the reference top-right and bottom-right layout', () {
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: const Offset(10, 20),
      cardSize: const Size(80, 42),
      badgeSize: const Size(30, 17),
      badgeLeftInset: 8,
      deerStickerSize: const Size.square(19),
      cookieIconSize: const Size.square(17),
    );

    expect(geometry.cardRect, const Rect.fromLTWH(10, 34, 80, 42));
    expect(geometry.badgeRect, const Rect.fromLTWH(18, 20, 30, 17));
    expect(geometry.deerStickerRect, const Rect.fromLTWH(70, 20, 19, 19));
    expect(geometry.cookieIconRect, const Rect.fromLTWH(76, 62, 17, 17));
    expect(geometry.footprintRect, const Rect.fromLTWH(10, 20, 83, 59));

    final restored = resolvePlacedLabelUnitGeometry(
      footprintRect: geometry.footprintRect,
      badgeSize: geometry.badgeRect.size,
      badgeLeftInset: 8,
      deerStickerSize: const Size.square(19),
      cookieIconSize: const Size.square(17),
    );
    expect(restored.cardRect, geometry.cardRect);
    expect(restored.badgeRect, geometry.badgeRect);
    expect(restored.deerStickerRect, geometry.deerStickerRect);
    expect(restored.cookieIconRect, geometry.cookieIconRect);
  });

  test('visible hit area includes card and badge but excludes footprint gap',
      () {
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: const Size(80, 42),
      badgeSize: badgeSize,
    );
    final transparentGap = Offset(
      geometry.cardRect.right - 1,
      geometry.badgeRect.center.dy,
    );

    expect(geometry.containsVisiblePoint(geometry.cardRect.center), isTrue);
    expect(geometry.containsVisiblePoint(geometry.badgeRect.center), isTrue);
    expect(geometry.footprintRect.contains(transparentGap), isTrue);
    expect(geometry.containsVisiblePoint(transparentGap), isFalse);
  });

  test('decorations are included in the visible hit area', () {
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: const Size(80, 42),
      badgeSize: const Size(30, 17),
      badgeLeftInset: 8,
      deerStickerSize: const Size.square(19),
      cookieIconSize: const Size.square(17),
    );

    expect(geometry.containsVisiblePoint(geometry.deerStickerRect!.center),
        isTrue);
    expect(
      geometry.containsVisiblePoint(
        geometry.deerStickerRect!.center,
        includeDeerSticker: false,
      ),
      isFalse,
    );
    expect(
        geometry.containsVisiblePoint(geometry.cookieIconRect!.center), isTrue);
    expect(geometry.containsVisiblePoint(const Offset(1, 1)), isFalse);
  });
}
