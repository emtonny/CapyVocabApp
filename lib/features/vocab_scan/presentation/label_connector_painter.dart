import 'package:flutter/material.dart';

import '../domain/label_connector_geometry.dart';
import '../domain/label_placement_solver.dart';

typedef PlacedLabelRectResolver = Rect Function(PlacedLabel placedLabel);

void paintConnector(
  Canvas canvas,
  ConnectorPath path, {
  Color color = const Color(0xFFD85B24),
  double strokeWidth = 1.7,
}) {
  paintConnectorRoute(
    canvas,
    connectorRouteFromPath(path),
    color: color,
    strokeWidth: strokeWidth,
  );
}

void paintConnectorRoute(
  Canvas canvas,
  ConnectorRoute route, {
  Color color = const Color(0xFFD85B24),
  double strokeWidth = 1.7,
}) {
  final path = route.toPath();
  canvas
    ..drawPath(path, _connectorHaloPaint(strokeWidth))
    ..drawPath(
      path,
      _connectorPaint(color: color, strokeWidth: strokeWidth),
    );
  _paintArrowHead(
    canvas,
    route,
    color: color,
    strokeWidth: strokeWidth,
  );
}

void paintAllConnectors(
  Canvas canvas,
  List<PlacedLabel> placedLabels, {
  PlacedLabelRectResolver? labelRectResolver,
  Size? canvasSize,
}) {
  final labelRects = placedLabels
      .map(
        (placed) => labelRectResolver?.call(placed) ?? placed.labelRect,
      )
      .toList(growable: false);
  final routes = <ConnectorRoute>[];
  for (final (index, placed) in placedLabels.indexed) {
    final route = selectConnectorRoute(
      labelRect: labelRects[index],
      targetBox: placed.anchorBox,
      obstacleRects: [
        for (final (otherIndex, rect) in labelRects.indexed)
          if (otherIndex != index) rect,
        for (final (otherIndex, other) in placedLabels.indexed)
          if (otherIndex != index) other.anchorBox,
      ],
      existingRoutes: routes,
      canvasRect: canvasSize == null ? null : Offset.zero & canvasSize,
    );
    routes.add(route);
    if (placed.quality == PlacementQuality.fallbackEdge) {
      _paintDashedConnector(canvas, route);
    } else {
      paintConnectorRoute(canvas, route);
    }
  }
}

ConnectorPath connectorPathForPlacedLabel(
  PlacedLabel placedLabel, {
  PlacedLabelRectResolver? labelRectResolver,
}) {
  return computeConnectorPath(
    labelRect: labelRectResolver?.call(placedLabel) ?? placedLabel.labelRect,
    targetBox: placedLabel.anchorBox,
  );
}

void _paintDashedConnector(
  Canvas canvas,
  ConnectorRoute route, {
  Color color = const Color(0xFFD85B24),
  double strokeWidth = 1.7,
  double dashLength = 6,
  double gapLength = 4,
}) {
  final path = route.toPath();
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final endDistance = (distance + dashLength).clamp(0.0, metric.length);
      final dash = metric.extractPath(distance, endDistance);
      canvas
        ..drawPath(dash, _connectorHaloPaint(strokeWidth))
        ..drawPath(
          dash,
          _connectorPaint(color: color, strokeWidth: strokeWidth),
        );
      distance += dashLength + gapLength;
    }
  }
  _paintArrowHead(
    canvas,
    route,
    color: color,
    strokeWidth: strokeWidth,
  );
}

void _paintArrowHead(
  Canvas canvas,
  ConnectorRoute route, {
  required Color color,
  required double strokeWidth,
}) {
  final tangent = route.endTangent;
  final tangentLength = tangent.distance;
  if (tangentLength == 0) return;

  final connectorLength = (route.to - route.from).distance;
  final headScale = (connectorLength / 8).clamp(0.35, 1.0);
  final headLength = 5.5 * headScale;
  final wingHalfWidth = 2.9 * headScale;
  final direction = tangent / tangentLength;
  final normal = Offset(-direction.dy, direction.dx);
  final base = route.to - direction * headLength;
  final arrowHead = Path()
    ..moveTo(
      base.dx + normal.dx * wingHalfWidth,
      base.dy + normal.dy * wingHalfWidth,
    )
    ..lineTo(route.to.dx, route.to.dy)
    ..lineTo(
      base.dx - normal.dx * wingHalfWidth,
      base.dy - normal.dy * wingHalfWidth,
    );
  canvas
    ..drawPath(arrowHead, _connectorHaloPaint(strokeWidth))
    ..drawPath(
      arrowHead,
      _connectorPaint(color: color, strokeWidth: strokeWidth),
    );
}

Paint _connectorHaloPaint(double strokeWidth) => _connectorPaint(
      color: const Color(0xFFFFFCF5),
      strokeWidth: strokeWidth + 2.6,
    );

Paint _connectorPaint({required Color color, required double strokeWidth}) {
  return Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}
