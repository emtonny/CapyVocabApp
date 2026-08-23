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
