import 'dart:ui';

import 'package:capy_vocab/features/vocab_scan/domain/label_connector_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('segmentIntersectsRect', () {
    const rect = Rect.fromLTWH(10, 10, 20, 20);

    test('detects a segment crossing through the middle', () {
      expect(
        segmentIntersectsRect(
          from: const Offset(0, 20),
          to: const Offset(40, 20),
          rect: rect,
        ),
        isTrue,
      );
    });

    test('rejects a segment that does not touch the rect', () {
      expect(
        segmentIntersectsRect(
          from: const Offset(0, 5),
          to: const Offset(40, 5),
          rect: rect,
        ),
        isFalse,
      );
    });

    test('detects a segment with one endpoint inside the rect', () {
      expect(
        segmentIntersectsRect(
          from: const Offset(20, 20),
          to: const Offset(40, 40),
          rect: rect,
        ),
        isTrue,
      );
    });

    test('counts touching exactly one edge as an intersection', () {
      expect(
        segmentIntersectsRect(
          from: const Offset(20, 0),
          to: const Offset(20, 10),
          rect: rect,
        ),
        isTrue,
      );
    });
  });

  group('segmentsIntersect', () {
    test('detects a proper crossing', () {
      expect(
        segmentsIntersect(
          firstFrom: const Offset(0, 0),
          firstTo: const Offset(20, 20),
          secondFrom: const Offset(0, 20),
          secondTo: const Offset(20, 0),
        ),
        isTrue,
      );
    });

    test('counts a shared endpoint and collinear overlap as intersections', () {
      expect(
        segmentsIntersect(
          firstFrom: const Offset(0, 0),
          firstTo: const Offset(10, 0),
          secondFrom: const Offset(10, 0),
          secondTo: const Offset(20, 5),
        ),
        isTrue,
      );
      expect(
        segmentsIntersect(
          firstFrom: const Offset(0, 0),
          firstTo: const Offset(20, 0),
          secondFrom: const Offset(5, 0),
          secondTo: const Offset(15, 0),
        ),
        isTrue,
      );
    });

    test('rejects disjoint segments', () {
      expect(
        segmentsIntersect(
          firstFrom: const Offset(0, 0),
          firstTo: const Offset(10, 0),
          secondFrom: const Offset(0, 10),
          secondTo: const Offset(10, 10),
        ),
        isFalse,
      );
    });
  });

  group('connectorConflictsWithPlacedGeometry', () {
    const farCandidateLabel = Rect.fromLTWH(30, 30, 4, 4);
    const farPlacedLabel = Rect.fromLTWH(-10, -10, 4, 4);
    const farConnector = ConnectorPath(
      from: Offset(30, 40),
      to: Offset(40, 40),
    );

    test('rejects a candidate connector through a placed label', () {
      expect(
        connectorConflictsWithPlacedGeometry(
          candidateLabelRect: farCandidateLabel,
          candidateConnector: const ConnectorPath(
            from: Offset(0, 10),
            to: Offset(20, 10),
          ),
          placedLabelRect: const Rect.fromLTWH(8, 8, 4, 4),
          placedConnector: farConnector,
        ),
        isTrue,
      );
    });

    test('rejects a placed connector hidden by the candidate label', () {
      expect(
        connectorConflictsWithPlacedGeometry(
          candidateLabelRect: const Rect.fromLTWH(8, 8, 4, 4),
          candidateConnector: farConnector,
          placedLabelRect: farPlacedLabel,
          placedConnector: const ConnectorPath(
            from: Offset(0, 10),
            to: Offset(20, 10),
          ),
        ),
        isTrue,
      );
    });

    test('rejects crossing connectors without label intersection', () {
      expect(
        connectorConflictsWithPlacedGeometry(
          candidateLabelRect: farCandidateLabel,
          candidateConnector: const ConnectorPath(
            from: Offset(0, 0),
            to: Offset(20, 20),
          ),
          placedLabelRect: farPlacedLabel,
          placedConnector: const ConnectorPath(
            from: Offset(0, 20),
            to: Offset(20, 0),
          ),
        ),
        isTrue,
      );
    });

    test('accepts disjoint labels and connectors', () {
      expect(
        connectorConflictsWithPlacedGeometry(
          candidateLabelRect: farCandidateLabel,
          candidateConnector: const ConnectorPath(
            from: Offset(30, 20),
            to: Offset(40, 20),
          ),
          placedLabelRect: farPlacedLabel,
          placedConnector: const ConnectorPath(
            from: Offset(0, 0),
            to: Offset(10, 0),
          ),
        ),
        isFalse,
      );
    });
  });

  group('distance-based connector routes', () {
    test('uses subtle, medium, and S routes at the 20px and 80px thresholds',
        () {
      final zero = connectorRouteFromPath(
        const ConnectorPath(from: Offset.zero, to: Offset.zero),
      );
      final subtle = connectorRouteFromPath(
        const ConnectorPath(from: Offset.zero, to: Offset(20, 0)),
      );
      final medium = connectorRouteFromPath(
        const ConnectorPath(from: Offset.zero, to: Offset(60, 0)),
      );
      final long = connectorRouteFromPath(
        const ConnectorPath(from: Offset.zero, to: Offset(81, 0)),
      );

      expect(zero.kind, ConnectorRouteKind.straight);
      expect(subtle.kind, ConnectorRouteKind.subtleCurve);
      expect(subtle.from, const Offset(connectorLabelStartGap, 0));
      expect(subtle.sampledPoints, hasLength(9));
      expect(subtle.control1!.dy, closeTo(1.2, 1e-9));
      expect(medium.kind, ConnectorRouteKind.gentleCurve);
      expect(medium.sampledPoints, hasLength(13));
      expect(long.kind, ConnectorRouteKind.gentleWave);
      expect(long.sampledPoints, hasLength(21));
      expect(long.control1!.dy, greaterThan(0));
      expect(long.control2!.dy, lessThan(0));
    });

    test('leaves a small gap after the label-side anchor', () {
      final route = connectorRouteFromPath(
        const ConnectorPath(from: Offset(10, 10), to: Offset(60, 10)),
      );

      expect(route.from, const Offset(10 + connectorLabelStartGap, 10));
      expect(route.to, const Offset(60, 10));
    });

    test('caps the gap for an extremely short connector', () {
      final route = connectorRouteFromPath(
        const ConnectorPath(from: Offset.zero, to: Offset(2, 0)),
      );

      expect(route.from, const Offset(0.8, 0));
      expect((route.to - route.from).distance, closeTo(1.2, 1e-9));
    });

    test('chooses the mirrored curve that avoids an obstacle', () {
      final route = selectConnectorRoute(
        labelRect: const Rect.fromLTWH(-10, -10, 10, 20),
        targetBox: const Rect.fromLTWH(60, -10, 10, 20),
        obstacleRects: const [Rect.fromLTWH(25, 0.5, 10, 4)],
      );

      expect(route.kind, ConnectorRouteKind.gentleCurve);
      expect(route.control1!.dy, lessThan(0));
      expect(
        connectorRouteIntersectsRect(
          route: route,
          rect: const Rect.fromLTWH(25, 0.5, 10, 4),
        ),
        isFalse,
      );
    });

    test('a medium route can mirror away from a narrow obstacle', () {
      final route = selectConnectorRoute(
        labelRect: const Rect.fromLTWH(-10, -10, 10, 20),
        targetBox: const Rect.fromLTWH(35, -10, 10, 20),
        obstacleRects: const [Rect.fromLTWH(15, -0.5, 5, 1)],
      );

      expect(route.kind, ConnectorRouteKind.gentleCurve);
      expect(
        connectorRouteIntersectsRect(
          route: route,
          rect: const Rect.fromLTWH(15, -0.5, 5, 1),
        ),
        isFalse,
      );
    });

    test('collision checks follow the sampled curve instead of its chord', () {
      final route = connectorRouteFromPath(
        const ConnectorPath(from: Offset.zero, to: Offset(70, 0)),
      );
      const obstacle = Rect.fromLTWH(33, 4.5, 4, 1);

      expect(
        segmentIntersectsRect(
          from: route.from,
          to: route.to,
          rect: obstacle,
        ),
        isFalse,
      );
      expect(
        connectorRouteIntersectsRect(route: route, rect: obstacle),
        isTrue,
      );
    });
  });

  test(
      'computeLabelAnchor uses the top or left border toward an upper-left target',
      () {
    const labelRect = Rect.fromLTWH(300, 600, 80, 80);
    const targetBox = Rect.fromLTWH(20, 30, 40, 40);

    final anchor = computeLabelAnchor(
      labelRect: labelRect,
      targetBox: targetBox,
    );

    expect(_isOnBorder(anchor, labelRect), isTrue);
    expect(anchor.dx == labelRect.left || anchor.dy == labelRect.top, isTrue);
    expect(anchor.dx == labelRect.right, isFalse);
    expect(anchor.dy == labelRect.bottom, isFalse);
  });

  test('computeTargetAnchor uses the target border nearest the label anchor',
      () {
    const targetBox = Rect.fromLTWH(20, 30, 40, 40);
    const labelAnchor = Offset(300, 600);

    final anchor = computeTargetAnchor(
      targetBox: targetBox,
      labelAnchor: labelAnchor,
    );

    expect(_isOnBorder(anchor, targetBox), isTrue);
    expect(
        anchor.dx == targetBox.right || anchor.dy == targetBox.bottom, isTrue);
    expect(anchor.dx == targetBox.left, isFalse);
    expect(anchor.dy == targetBox.top, isFalse);
  });

  test('computeConnectorPath can target the center for visible arrows', () {
    const labelRect = Rect.fromLTWH(300, 600, 80, 80);
    const targetBox = Rect.fromLTWH(20, 30, 40, 40);

    final path = computeConnectorPath(
      labelRect: labelRect,
      targetBox: targetBox,
      targetCenter: true,
    );

    expect(_isOnBorder(path.from, labelRect), isTrue);
    expect(path.to, targetBox.center);
  });

  test('targetBox contained by labelRect collapses to a finite shared anchor',
      () {
    const labelRect = Rect.fromLTWH(0, 0, 200, 200);
    const targetBox = Rect.fromLTWH(80, 80, 40, 40);

    final path = computeConnectorPath(
      labelRect: labelRect,
      targetBox: targetBox,
    );

    expect(path.from, targetBox.center);
    expect(path.to, path.from);
    expect(_isFinite(path.from), isTrue);
    expect(_isFinite(path.to), isTrue);
  });

  test('labelRect contained by targetBox uses the same symmetric fallback', () {
    const labelRect = Rect.fromLTWH(95, 95, 10, 10);
    const targetBox = Rect.fromLTWH(0, 0, 200, 200);

    final path = computeConnectorPath(
      labelRect: labelRect,
      targetBox: targetBox,
    );

    expect(path.from, targetBox.center);
    expect(path.to, path.from);
    expect((path.to - path.from).distance, 0.0);
  });

  test('partial non-concentric overlap keeps a valid shared border point', () {
    const labelRect = Rect.fromLTWH(0, 0, 100, 100);
    const targetBox = Rect.fromLTWH(80, 30, 100, 100);

    final path = computeConnectorPath(
      labelRect: labelRect,
      targetBox: targetBox,
    );

    expect(path.from, const Offset(100, 80));
    expect(_isOnBorder(path.from, labelRect), isTrue);
    expect(_containsInclusive(targetBox, path.from), isTrue);
    expect(path.to, path.from);
  });

  test(
      'border path never exceeds center distance for disjoint and overlap fixtures',
      () {
    const fixtures = [
      (
        label: Rect.fromLTWH(300, 600, 80, 80),
        target: Rect.fromLTWH(20, 30, 40, 40),
      ),
      (
        label: Rect.fromLTWH(0, 0, 200, 200),
        target: Rect.fromLTWH(80, 80, 40, 40),
      ),
      (
        label: Rect.fromLTWH(95, 95, 10, 10),
        target: Rect.fromLTWH(0, 0, 200, 200),
      ),
      (
        label: Rect.fromLTWH(0, 0, 100, 100),
        target: Rect.fromLTWH(80, 30, 100, 100),
      ),
    ];

    for (final fixture in fixtures) {
      final path = computeConnectorPath(
        labelRect: fixture.label,
        targetBox: fixture.target,
      );
      final borderLength = (path.to - path.from).distance;
      final centerLength =
          (fixture.target.center - fixture.label.center).distance;

      expect(borderLength, lessThanOrEqualTo(centerLength + 1e-12));
    }
  });
}

bool _isOnBorder(Offset point, Rect rect) {
  final onHorizontal = (point.dy == rect.top || point.dy == rect.bottom) &&
      point.dx >= rect.left &&
      point.dx <= rect.right;
  final onVertical = (point.dx == rect.left || point.dx == rect.right) &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
  return onHorizontal || onVertical;
}

bool _containsInclusive(Rect rect, Offset point) {
  return point.dx >= rect.left &&
      point.dx <= rect.right &&
      point.dy >= rect.top &&
      point.dy <= rect.bottom;
}

bool _isFinite(Offset point) => point.dx.isFinite && point.dy.isFinite;
