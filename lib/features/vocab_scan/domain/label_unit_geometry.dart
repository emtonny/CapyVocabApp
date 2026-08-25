import 'dart:ui';

const defaultBadgeCardOverlap = 3.0;
const _deerRightInset = 1.0;
const _cookieRightOverhang = 3.0;
const _cookieBottomOverhang = 3.0;

/// Pixel-space geometry for one complete vocabulary label unit.
///
/// [footprintRect] is the solver/collision truth. [cardRect] and [badgeRect]
/// are the two visible components inside that footprint.
class LabelUnitGeometry {
  const LabelUnitGeometry({
    required this.footprintRect,
    required this.cardRect,
    required this.badgeRect,
    this.deerStickerRect,
    this.cookieIconRect,
  });

  final Rect footprintRect;
  final Rect cardRect;
  final Rect badgeRect;
  final Rect? deerStickerRect;
  final Rect? cookieIconRect;

  List<Rect> get visibleCollisionRects => [
        cardRect,
        badgeRect,
        if (deerStickerRect != null) deerStickerRect!,
        if (cookieIconRect != null) cookieIconRect!,
      ];

  LabelUnitGeometry shift(Offset delta) {
    return LabelUnitGeometry(
      footprintRect: footprintRect.shift(delta),
      cardRect: cardRect.shift(delta),
      badgeRect: badgeRect.shift(delta),
      deerStickerRect: deerStickerRect?.shift(delta),
      cookieIconRect: cookieIconRect?.shift(delta),
    );
  }

  bool containsVisiblePoint(
    Offset point, {
    bool includeDeerSticker = true,
  }) {
    return cardRect.contains(point) ||
        badgeRect.contains(point) ||
        (includeDeerSticker && (deerStickerRect?.contains(point) ?? false)) ||
        (cookieIconRect?.contains(point) ?? false);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelUnitGeometry &&
            other.footprintRect == footprintRect &&
            other.cardRect == cardRect &&
            other.badgeRect == badgeRect &&
            other.deerStickerRect == deerStickerRect &&
            other.cookieIconRect == cookieIconRect;
  }

  @override
  int get hashCode => Object.hash(
        footprintRect,
        cardRect,
        badgeRect,
        deerStickerRect,
        cookieIconRect,
      );
}

/// Resolves the floating badge/card layout from the solver's footprint
/// top-left.
///
/// The badge floats above the card with an optional left inset. The card
/// overlaps its bottom edge by [badgeCardOverlap], while optional deer and
/// cookie decorations occupy the top-right and bottom-right corners.
/// Geometry depends only on fixed style metrics, never on the number of digits
/// painted inside the badge.
LabelUnitGeometry resolveLabelUnitGeometry({
  required Offset footprintTopLeft,
  required Size cardSize,
  required Size badgeSize,
  double badgeLeftInset = 0,
  double badgeCardOverlap = defaultBadgeCardOverlap,
  Size deerStickerSize = Size.zero,
  Size cookieIconSize = Size.zero,
}) {
  _validateInputs(
    footprintTopLeft: footprintTopLeft,
    cardSize: cardSize,
    badgeSize: badgeSize,
    badgeLeftInset: badgeLeftInset,
    badgeCardOverlap: badgeCardOverlap,
    deerStickerSize: deerStickerSize,
    cookieIconSize: cookieIconSize,
  );

  final cardTopOffset = _cardTopOffset(badgeSize, badgeCardOverlap);
  final cardRect = Rect.fromLTWH(
    footprintTopLeft.dx,
    footprintTopLeft.dy + cardTopOffset,
    cardSize.width,
    cardSize.height,
  );
  final badgeRect = Rect.fromLTWH(
    footprintTopLeft.dx + badgeLeftInset,
    footprintTopLeft.dy,
    badgeSize.width,
    badgeSize.height,
  );
  final deerStickerRect = deerStickerSize.isEmpty
      ? null
      : Rect.fromLTWH(
          cardRect.right - deerStickerSize.width - _deerRightInset,
          footprintTopLeft.dy,
          deerStickerSize.width,
          deerStickerSize.height,
        );
  final cookieIconRect = cookieIconSize.isEmpty
      ? null
      : Rect.fromLTWH(
          cardRect.right + _cookieRightOverhang - cookieIconSize.width,
          cardRect.bottom + _cookieBottomOverhang - cookieIconSize.height,
          cookieIconSize.width,
          cookieIconSize.height,
        );
  var footprintRect = badgeRect.expandToInclude(cardRect);
  if (deerStickerRect != null) {
    footprintRect = footprintRect.expandToInclude(deerStickerRect);
  }
  if (cookieIconRect != null) {
    footprintRect = footprintRect.expandToInclude(cookieIconRect);
  }

  return LabelUnitGeometry(
    footprintRect: footprintRect,
    cardRect: cardRect,
    badgeRect: badgeRect,
    deerStickerRect: deerStickerRect,
    cookieIconRect: cookieIconRect,
  );
}

/// Recovers visible component rects from a footprint produced by
/// [resolveLabelUnitGeometry].
///
/// This is used after placement, when [PlacedLabel.labelRect] stores the
/// complete footprint rather than the card alone.
LabelUnitGeometry resolvePlacedLabelUnitGeometry({
  required Rect footprintRect,
  required Size badgeSize,
  double badgeLeftInset = 0,
  double badgeCardOverlap = defaultBadgeCardOverlap,
  Size deerStickerSize = Size.zero,
  Size cookieIconSize = Size.zero,
}) {
  final cookieWidthOverhang =
      cookieIconSize.isEmpty ? 0.0 : _cookieRightOverhang;
  final cookieHeightOverhang =
      cookieIconSize.isEmpty ? 0.0 : _cookieBottomOverhang;
  final cardSize = Size(
    footprintRect.width - cookieWidthOverhang,
    footprintRect.height -
        _cardTopOffset(badgeSize, badgeCardOverlap) -
        cookieHeightOverhang,
  );
  final resolved = resolveLabelUnitGeometry(
    footprintTopLeft: footprintRect.topLeft,
    cardSize: cardSize,
    badgeSize: badgeSize,
    badgeLeftInset: badgeLeftInset,
    badgeCardOverlap: badgeCardOverlap,
    deerStickerSize: deerStickerSize,
    cookieIconSize: cookieIconSize,
  );
  if (!_rectsEqual(resolved.footprintRect, footprintRect)) {
    throw ArgumentError.value(
      footprintRect,
      'footprintRect',
      'must be large enough to contain the configured badge and card',
    );
  }
  return resolved;
}

double minimumLabelCardWidth({
  required Size badgeSize,
  double badgeLeftInset = 0,
  Size deerStickerSize = Size.zero,
  Size cookieIconSize = Size.zero,
}) {
  return [
    badgeLeftInset + badgeSize.width,
    deerStickerSize.isEmpty ? 0.0 : deerStickerSize.width + _deerRightInset,
    cookieIconSize.isEmpty ? 0.0 : cookieIconSize.width - _cookieRightOverhang,
  ].reduce((largest, value) => value > largest ? value : largest);
}

double _cardTopOffset(Size badgeSize, double badgeCardOverlap) {
  final offset = badgeSize.height - badgeCardOverlap;
  return offset > 0 ? offset : 0;
}

bool _rectsEqual(Rect first, Rect second) {
  const epsilon = 1e-9;
  return (first.left - second.left).abs() <= epsilon &&
      (first.top - second.top).abs() <= epsilon &&
      (first.right - second.right).abs() <= epsilon &&
      (first.bottom - second.bottom).abs() <= epsilon;
}

void _validateInputs({
  required Offset footprintTopLeft,
  required Size cardSize,
  required Size badgeSize,
  required double badgeLeftInset,
  required double badgeCardOverlap,
  required Size deerStickerSize,
  required Size cookieIconSize,
}) {
  if (!footprintTopLeft.dx.isFinite || !footprintTopLeft.dy.isFinite) {
    throw ArgumentError.value(
      footprintTopLeft,
      'footprintTopLeft',
      'must be finite',
    );
  }
  if (!cardSize.width.isFinite ||
      !cardSize.height.isFinite ||
      cardSize.width <= 0 ||
      cardSize.height <= 0) {
    throw ArgumentError.value(
      cardSize,
      'cardSize',
      'must be finite and positive',
    );
  }
  if (!badgeSize.width.isFinite ||
      !badgeSize.height.isFinite ||
      badgeSize.width <= 0 ||
      badgeSize.height <= 0) {
    throw ArgumentError.value(
      badgeSize,
      'badgeSize',
      'must be finite and positive',
    );
  }
  if (!badgeLeftInset.isFinite || badgeLeftInset < 0) {
    throw ArgumentError.value(
      badgeLeftInset,
      'badgeLeftInset',
      'must be finite and non-negative',
    );
  }
  if (!badgeCardOverlap.isFinite ||
      badgeCardOverlap < 0 ||
      badgeCardOverlap > badgeSize.height) {
    throw ArgumentError.value(
      badgeCardOverlap,
      'badgeCardOverlap',
      'must be finite and between zero and the badge height',
    );
  }
  for (final entry in {
    'deerStickerSize': deerStickerSize,
    'cookieIconSize': cookieIconSize,
  }.entries) {
    final size = entry.value;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width < 0 ||
        size.height < 0 ||
        (size.width == 0) != (size.height == 0)) {
      throw ArgumentError.value(
        size,
        entry.key,
        'must be empty or finite with two positive dimensions',
      );
    }
  }
  final minimumCardWidth = minimumLabelCardWidth(
    badgeSize: badgeSize,
    badgeLeftInset: badgeLeftInset,
    deerStickerSize: deerStickerSize,
    cookieIconSize: cookieIconSize,
  );
  if (cardSize.width < minimumCardWidth) {
    throw ArgumentError.value(
      cardSize,
      'cardSize',
      'must be wide enough for the badge and label decorations',
    );
  }
}
