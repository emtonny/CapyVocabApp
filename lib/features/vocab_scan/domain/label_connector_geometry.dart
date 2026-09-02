import 'dart:math' as math;
import 'dart:ui';

class ConnectorPath {
  const ConnectorPath({required this.from, required this.to});

  final Offset from;
  final Offset to;
}

const double connectorSubtleCurveMaxLength = 20;
const double connectorGentleCurveMaxLength = 80;
const double connectorLabelStartGap = 3.5;

@Deprecated('Use connectorSubtleCurveMaxLength instead.')
const double connectorStraightMaxLength = connectorSubtleCurveMaxLength;

enum ConnectorRouteKind { straight, subtleCurve, gentleCurve, gentleWave }

/// A drawable connector whose sampled polyline is also used for collision
/// checks. Keeping those two representations together prevents the solver from
/// approving a straight segment while the painter displays a curve elsewhere.
class ConnectorRoute {
  ConnectorRoute._({
    required this.from,
    required this.to,
    required this.kind,
    this.control1,
    this.control2,
    required List<Offset> sampledPoints,
  })  : sampledPoints = List<Offset>.unmodifiable(sampledPoints),
        bounds = _boundsForPoints(sampledPoints);

  final Offset from;
  final Offset to;
  final ConnectorRouteKind kind;
  final Offset? control1;
  final Offset? control2;
  final List<Offset> sampledPoints;
  final Rect bounds;

  Offset get endTangent {
    switch (kind) {
      case ConnectorRouteKind.straight:
        return to - from;
      case ConnectorRouteKind.subtleCurve:
      case ConnectorRouteKind.gentleCurve:
        return to - control1!;
      case ConnectorRouteKind.gentleWave:
        return to - control2!;
    }
  }

  Path toPath() {
    final path = Path()..moveTo(from.dx, from.dy);
    switch (kind) {
      case ConnectorRouteKind.straight:
        path.lineTo(to.dx, to.dy);
      case ConnectorRouteKind.subtleCurve:
      case ConnectorRouteKind.gentleCurve:
        path.quadraticBezierTo(
          control1!.dx,
          control1!.dy,
          to.dx,
          to.dy,
        );
      case ConnectorRouteKind.gentleWave:
        path.cubicTo(
          control1!.dx,
          control1!.dy,
          control2!.dx,
          control2!.dy,
          to.dx,
          to.dy,
        );
    }
    return path;
  }
}

/// Builds the distance-based route used by both placement and painting.
///
/// [bendSign] selects one of the two sides of the direct segment. Positive and
/// negative values mirror the curve while zero is normalized to positive.
ConnectorRoute computeConnectorRoute({
  required Rect labelRect,
  required Rect targetBox,
  double bendSign = 1,
  ConnectorRouteKind? kindOverride,
}) {
  final endpoints = computeConnectorPath(
    labelRect: labelRect,
    targetBox: targetBox,
  );
  return connectorRouteFromPath(
    endpoints,
    bendSign: bendSign,
    kindOverride: kindOverride,
  );
}

ConnectorRoute connectorRouteFromPath(
  ConnectorPath endpoints, {
  double bendSign = 1,
  ConnectorRouteKind? kindOverride,
}) {
  _validateOffsets([endpoints.from, endpoints.to]);
  final fullDelta = endpoints.to - endpoints.from;
  final fullDistance = fullDelta.distance;
  final kind = kindOverride ?? _routeKindForLength(fullDistance);
  if (fullDistance == 0 || kind == ConnectorRouteKind.straight) {
    return ConnectorRoute._(
      from: endpoints.from,
      to: endpoints.to,
      kind: ConnectorRouteKind.straight,
      sampledPoints: [endpoints.from, endpoints.to],
    );
  }

  final direction = fullDelta / fullDistance;
  final startGap = math.min(
    connectorLabelStartGap,
    fullDistance * 0.4,
  );
  final from = endpoints.from + direction * startGap;
  final delta = endpoints.to - from;
  final sign = bendSign < 0 ? -1.0 : 1.0;
  final normal = Offset(-direction.dy, direction.dx) * sign;
  if (kind == ConnectorRouteKind.subtleCurve ||
      kind == ConnectorRouteKind.gentleCurve) {
    final isSubtle = kind == ConnectorRouteKind.subtleCurve;
    final bend = isSubtle
        ? (fullDistance * 0.06).clamp(0.35, 1.2)
        : (2 + (fullDistance - connectorSubtleCurveMaxLength) * 0.16)
            .clamp(2.0, 12.0);
    final control = from + delta * 0.5 + normal * bend;
    return ConnectorRoute._(
      from: from,
      to: endpoints.to,
      kind: kind,
      control1: control,
      sampledPoints: _sampleQuadratic(
        from,
        control,
        endpoints.to,
        isSubtle ? 8 : 12,
      ),
    );
  }

  final bend = (fullDistance * 0.10).clamp(8.0, 18.0);
  final firstControl = from + delta / 3 + normal * bend;
  final secondControl = from + delta * (2 / 3) - normal * bend;
  return ConnectorRoute._(
    from: from,
    to: endpoints.to,
    kind: kind,
    control1: firstControl,
    control2: secondControl,
    sampledPoints: _sampleCubic(
      from,
      firstControl,
      secondControl,
      endpoints.to,
      20,
    ),
  );
}

/// Chooses the mirrored curve with the fewest collisions. A short connector
/// remains straight unless an obstacle requires a small detour.
ConnectorRoute selectConnectorRoute({
  required Rect labelRect,
  required Rect targetBox,
  bool targetCenter = false,
  Iterable<Rect> obstacleRects = const [],
  Iterable<ConnectorRoute> existingRoutes = const [],
  Rect? canvasRect,
}) {
  final endpoints = computeConnectorPath(
    labelRect: labelRect,
    targetBox: targetBox,
    targetCenter: targetCenter,
  );
  final baseKind =
      _routeKindForLength((endpoints.to - endpoints.from).distance);
  final candidates = <ConnectorRoute>[
    connectorRouteFromPath(endpoints, bendSign: 1, kindOverride: baseKind),
    if (baseKind != ConnectorRouteKind.straight)
      connectorRouteFromPath(endpoints, bendSign: -1, kindOverride: baseKind),
  ];

  var best = candidates.first;
  var bestScore = _routeCollisionScore(
    best,
    obstacleRects: obstacleRects,
    existingRoutes: existingRoutes,
    canvasRect: canvasRect,
  );
  for (final candidate in candidates.skip(1)) {
    final score = _routeCollisionScore(
      candidate,
      obstacleRects: obstacleRects,
      existingRoutes: existingRoutes,
      canvasRect: canvasRect,
    );
    if (score < bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
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
Offset computeTargetAnchor({
  required Rect targetBox,
  required Offset labelAnchor,
}) {
  return _nearestAnchor(rect: targetBox, reference: labelAnchor);
}

/// Computes endpoints sequentially: label anchor first, then target anchor.
/// Set [targetCenter] for visible arrows that should point into the detected
/// object while placement geometry continues to use the nearest bbox border.
ConnectorPath computeConnectorPath({
  required Rect labelRect,
  required Rect targetBox,
  bool targetCenter = false,
}) {
  final labelAnchor = computeLabelAnchor(
    labelRect: labelRect,
    targetBox: targetBox,
  );
  final targetAnchor = targetCenter
      ? targetBox.center
      : computeTargetAnchor(
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

bool connectorRouteIntersectsRect({
  required ConnectorRoute route,
  required Rect rect,
}) {
  if (!_rectsOverlapInclusive(route.bounds, rect)) return false;
  for (var index = 0; index < route.sampledPoints.length - 1; index++) {
    if (segmentIntersectsRect(
      from: route.sampledPoints[index],
      to: route.sampledPoints[index + 1],
      rect: rect,
    )) {
      return true;
    }
  }
  return false;
}

bool connectorRoutesIntersect(
  ConnectorRoute first,
  ConnectorRoute second,
) {
  if (!_rectsOverlapInclusive(first.bounds, second.bounds)) return false;
  for (var firstIndex = 0;
      firstIndex < first.sampledPoints.length - 1;
      firstIndex++) {
    for (var secondIndex = 0;
        secondIndex < second.sampledPoints.length - 1;
        secondIndex++) {
      if (segmentsIntersect(
        firstFrom: first.sampledPoints[firstIndex],
        firstTo: first.sampledPoints[firstIndex + 1],
        secondFrom: second.sampledPoints[secondIndex],
        secondTo: second.sampledPoints[secondIndex + 1],
      )) {
        return true;
      }
    }
  }
  return false;
}

bool connectorRouteConflictsWithPlacedGeometry({
  required Rect candidateLabelRect,
  required ConnectorRoute candidateConnector,
  required Rect placedLabelRect,
  required ConnectorRoute placedConnector,
}) {
  return connectorRouteIntersectsRect(
        route: candidateConnector,
        rect: placedLabelRect,
      ) ||
      connectorRouteIntersectsRect(
        route: placedConnector,
        rect: candidateLabelRect,
      ) ||
      connectorRoutesIntersect(candidateConnector, placedConnector);
}

ConnectorRouteKind _routeKindForLength(double length) {
  if (length == 0) {
    return ConnectorRouteKind.straight;
  }
  if (length <= connectorSubtleCurveMaxLength) {
    return ConnectorRouteKind.subtleCurve;
  }
  if (length <= connectorGentleCurveMaxLength) {
    return ConnectorRouteKind.gentleCurve;
  }
  return ConnectorRouteKind.gentleWave;
}

int _routeCollisionScore(
  ConnectorRoute route, {
  required Iterable<Rect> obstacleRects,
  required Iterable<ConnectorRoute> existingRoutes,
  required Rect? canvasRect,
}) {
  var score = 0;
  for (final obstacle in obstacleRects) {
    if (connectorRouteIntersectsRect(route: route, rect: obstacle)) {
      score += 1000;
    }
  }
  for (final existing in existingRoutes) {
    if (connectorRoutesIntersect(route, existing)) score += 1000;
  }
  if (canvasRect != null) {
    score += route.sampledPoints
            .where((point) => !_containsInclusive(canvasRect, point))
            .length *
        100;
  }
  return score;
}

List<Offset> _sampleQuadratic(
  Offset from,
  Offset control,
  Offset to,
  int segments,
) {
  return List<Offset>.generate(segments + 1, (index) {
    final t = index / segments;
    final inverse = 1 - t;
    return from * (inverse * inverse) +
        control * (2 * inverse * t) +
        to * (t * t);
  }, growable: false);
}

List<Offset> _sampleCubic(
  Offset from,
  Offset firstControl,
  Offset secondControl,
  Offset to,
  int segments,
) {
  return List<Offset>.generate(segments + 1, (index) {
    final t = index / segments;
    final inverse = 1 - t;
    return from * (inverse * inverse * inverse) +
        firstControl * (3 * inverse * inverse * t) +
        secondControl * (3 * inverse * t * t) +
        to * (t * t * t);
  }, growable: false);
}

Rect _boundsForPoints(List<Offset> points) {
  var left = points.first.dx;
  var top = points.first.dy;
  var right = left;
  var bottom = top;
  for (final point in points.skip(1)) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

bool _rectsOverlapInclusive(Rect first, Rect second) {
  return first.left <= second.right &&
      first.right >= second.left &&
      first.top <= second.bottom &&
      first.bottom >= second.top;
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
