import 'dart:ui';

const _badgeCardOverlap = 3.0;

/// Pixel-space geometry for one complete vocabulary label unit.
///
/// [footprintRect] is the solver/collision truth. [cardRect] and [badgeRect]
/// are the two visible components inside that footprint.
class LabelUnitGeometry {
  const LabelUnitGeometry({
    required this.footprintRect,
    required this.cardRect,
    required this.badgeRect,
  });

  final Rect footprintRect;
  final Rect cardRect;
  final Rect badgeRect;

  bool containsVisiblePoint(Offset point) {
    return cardRect.contains(point) || badgeRect.contains(point);
  }
}

/// Resolves the floating badge/card layout from the solver's footprint
/// top-left.
///
/// The badge is left-aligned above the card. The card overlaps the badge's
/// bottom edge by 3 logical pixels, creating one integrated silhouette while
/// keeping the badge clear of all text.
/// Geometry depends only on fixed style metrics, never on the number of digits
/// painted inside the badge.
LabelUnitGeometry resolveLabelUnitGeometry({
  required Offset footprintTopLeft,
  required Size cardSize,
  required Size badgeSize,
}) {
  _validateInputs(
    footprintTopLeft: footprintTopLeft,
    cardSize: cardSize,
    badgeSize: badgeSize,
  );

  final badgeRect = Rect.fromLTWH(
    footprintTopLeft.dx,
    footprintTopLeft.dy,
    badgeSize.width,
    badgeSize.height,
  );
  final cardRect = Rect.fromLTWH(
    footprintTopLeft.dx,
    footprintTopLeft.dy + badgeSize.height - _badgeCardOverlap,
    cardSize.width,
    cardSize.height,
  );
  final footprintRect = badgeRect.expandToInclude(cardRect);

  return LabelUnitGeometry(
    footprintRect: footprintRect,
    cardRect: cardRect,
    badgeRect: badgeRect,
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
}) {
  final cardSize = Size(
    footprintRect.width,
    footprintRect.height - badgeSize.height + _badgeCardOverlap,
  );
  final resolved = resolveLabelUnitGeometry(
    footprintTopLeft: footprintRect.topLeft,
    cardSize: cardSize,
    badgeSize: badgeSize,
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
  if (cardSize.width < badgeSize.width) {
    throw ArgumentError.value(
      cardSize,
      'cardSize',
      'must be at least as wide as the floating badge',
    );
  }
}
