import 'dart:math' as math;
import 'dart:ui';

class ConnectorPath {
  const ConnectorPath({required this.from, required this.to});

  final Offset from;
  final Offset to;
}

/// Returns the label-side endpoint nearest to [targetBox].
///
/// For disjoint rectangles, the result lies on [labelRect]'s border. The
/// symmetric overlap fallback applies when [targetBox].center is already
/// inside or on [labelRect]: that reference point is returned unchanged. This
/// intentionally permits an interior endpoint so intersecting or containing
/// rectangles can produce a finite zero-length connector instead of a path
/// longer than their center-to-center distance.
Offset computeLabelAnchor({
  required Rect labelRect,
  required Rect targetBox,
}) {
  return _nearestAnchor(
    rect: labelRect,
    reference: targetBox.center,
  );
}

/// Returns the target-side endpoint nearest to [labelAnchor].
///
/// For disjoint rectangles, the result lies on [targetBox]'s border. The same
/// symmetric overlap fallback as [computeLabelAnchor] applies: when
/// [labelAnchor] is already inside or on [targetBox], it is returned unchanged.
/// This lets both containment directions and partial intersections collapse to
/// a deterministic zero-length connector.
Offset computeTargetAnchor({
  required Rect targetBox,
  required Offset labelAnchor,
}) {
  return _nearestAnchor(rect: targetBox, reference: labelAnchor);
}

/// Computes endpoints sequentially: label anchor first, then target anchor.
ConnectorPath computeConnectorPath({
  required Rect labelRect,
  required Rect targetBox,
}) {
  final labelAnchor = computeLabelAnchor(
    labelRect: labelRect,
    targetBox: targetBox,
  );
  final targetAnchor = computeTargetAnchor(
    targetBox: targetBox,
    labelAnchor: labelAnchor,
  );
  return ConnectorPath(from: labelAnchor, to: targetAnchor);
}

/// Whether the closed line segment from [from] to [to] intersects [rect].
///
/// Liang-Barsky clipping keeps the test axis-aligned and inclusive: touching an
/// edge or corner counts as an intersection, as does either endpoint lying on
/// or inside the rectangle.
bool segmentIntersectsRect({
  required Offset from,
  required Offset to,
  required Rect rect,
}) {
  _validateFinite(rect, from);
  _validateFinite(rect, to);

  final delta = to - from;
  var entering = 0.0;
  var leaving = 1.0;

  bool clip(double direction, double distance) {
    if (direction == 0) return distance >= 0;

    final ratio = distance / direction;
    if (direction < 0) {
      if (ratio > leaving) return false;
      if (ratio > entering) entering = ratio;
    } else {
      if (ratio < entering) return false;
      if (ratio < leaving) leaving = ratio;
    }
    return true;
  }

  return clip(-delta.dx, from.dx - rect.left) &&
      clip(delta.dx, rect.right - from.dx) &&
      clip(-delta.dy, from.dy - rect.top) &&
      clip(delta.dy, rect.bottom - from.dy);
}

/// Whether two closed line segments intersect, including endpoint touches and
/// collinear overlap.
bool segmentsIntersect({
  required Offset firstFrom,
  required Offset firstTo,
  required Offset secondFrom,
  required Offset secondTo,
}) {
  _validateOffsets([firstFrom, firstTo, secondFrom, secondTo]);
  final firstSideFrom = _cross(firstFrom, firstTo, secondFrom);
  final firstSideTo = _cross(firstFrom, firstTo, secondTo);
  final secondSideFrom = _cross(secondFrom, secondTo, firstFrom);
  final secondSideTo = _cross(secondFrom, secondTo, firstTo);
  const epsilon = 1e-9;

  final crossesFirst = (firstSideFrom > epsilon && firstSideTo < -epsilon) ||
      (firstSideFrom < -epsilon && firstSideTo > epsilon);
  final crossesSecond = (secondSideFrom > epsilon && secondSideTo < -epsilon) ||
      (secondSideFrom < -epsilon && secondSideTo > epsilon);
  if (crossesFirst && crossesSecond) return true;

  return (firstSideFrom.abs() <= epsilon &&
          _pointOnSegment(firstFrom, firstTo, secondFrom)) ||
      (firstSideTo.abs() <= epsilon &&
          _pointOnSegment(firstFrom, firstTo, secondTo)) ||
      (secondSideFrom.abs() <= epsilon &&
          _pointOnSegment(secondFrom, secondTo, firstFrom)) ||
      (secondSideTo.abs() <= epsilon &&
          _pointOnSegment(secondFrom, secondTo, firstTo));
}

/// Whether a candidate would visually collide with an already placed
/// label-connector unit.
///
/// The check is symmetric: it rejects a candidate connector through the old
/// label, an old connector through the candidate label, or two crossing
/// connectors.
bool connectorConflictsWithPlacedGeometry({
  required Rect candidateLabelRect,
  required ConnectorPath candidateConnector,
  required Rect placedLabelRect,
  required ConnectorPath placedConnector,
}) {
  if (segmentIntersectsRect(
    from: candidateConnector.from,
    to: candidateConnector.to,
    rect: placedLabelRect,
  )) {
    return true;
  }
  if (segmentIntersectsRect(
    from: placedConnector.from,
    to: placedConnector.to,
    rect: candidateLabelRect,
  )) {
    return true;
  }
  if (segmentsIntersect(
    firstFrom: candidateConnector.from,
    firstTo: candidateConnector.to,
    secondFrom: placedConnector.from,
    secondTo: placedConnector.to,
  )) {
    return true;
  }
  return false;
}

double _cross(Offset from, Offset to, Offset point) {
  return (to.dx - from.dx) * (point.dy - from.dy) -
      (to.dy - from.dy) * (point.dx - from.dx);
}

bool _pointOnSegment(Offset from, Offset to, Offset point) {
  const epsilon = 1e-9;
  return point.dx >= math.min(from.dx, to.dx) - epsilon &&
      point.dx <= math.max(from.dx, to.dx) + epsilon &&
      point.dy >= math.min(from.dy, to.dy) - epsilon &&
      point.dy <= math.max(from.dy, to.dy) + epsilon;
}

void _validateOffsets(List<Offset> offsets) {
  if (offsets.any((point) => !point.dx.isFinite || !point.dy.isFinite)) {
    throw ArgumentError('Connector geometry requires finite coordinates.');
  }
}

Offset _nearestAnchor({required Rect rect, required Offset reference}) {
  _validateFinite(rect, reference);
  if (_containsInclusive(rect, reference)) return reference;

  final clamped = Offset(
    reference.dx.clamp(rect.left, rect.right).toDouble(),
    reference.dy.clamp(rect.top, rect.bottom).toDouble(),
  );
  return _projectToNearestBorder(rect, clamped);
}

Offset _projectToNearestBorder(Rect rect, Offset point) {
  final topDistance = (point.dy - rect.top).abs();
  final leftDistance = (point.dx - rect.left).abs();
  final bottomDistance = (rect.bottom - point.dy).abs();
  final rightDistance = (rect.right - point.dx).abs();
  final minimum = [
    topDistance,
    leftDistance,
    bottomDistance,
    rightDistance,
  ].reduce((first, second) => first < second ? first : second);

  if (topDistance == minimum) return Offset(point.dx, rect.top);
  if (leftDistance == minimum) return Offset(rect.left, point.dy);
  if (bottomDistance == minimum) return Offset(point.dx, rect.bottom);
  return Offset(rect.right, point.dy);
}

bool _containsInclusive(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

void _validateFinite(Rect rect, Offset reference) {
  if (!rect.left.isFinite ||
      !rect.top.isFinite ||
      !rect.right.isFinite ||
      !rect.bottom.isFinite ||
      !reference.dx.isFinite ||
      !reference.dy.isFinite) {
    throw ArgumentError('Connector geometry requires finite coordinates.');
  }
}
