import 'package:flutter/material.dart';

import '../domain/label_connector_geometry.dart';
import '../domain/label_placement_solver.dart';

typedef PlacedLabelRectResolver = Rect Function(PlacedLabel placedLabel);

enum ConnectorLineStyle { adaptive, solid, dashed }

enum ConnectorArrowStyle { pointed, rounded, dot }

void paintConnector(
  Canvas canvas,
  ConnectorPath path, {
  Color color = const Color(0xFFD85B24),
  double strokeWidth = 1.7,
  Color haloColor = const Color(0xFFFFFCF5),
  ConnectorLineStyle lineStyle = ConnectorLineStyle.solid,
  ConnectorArrowStyle arrowStyle = ConnectorArrowStyle.rounded,
  bool showHalo = true,
}) {
  paintConnectorRoute(
    canvas,
    connectorRouteFromPath(path),
    color: color,
    strokeWidth: strokeWidth,
    haloColor: haloColor,
    lineStyle: lineStyle,
    arrowStyle: arrowStyle,
    showHalo: showHalo,
  );
}

void paintConnectorRoute(
  Canvas canvas,
  ConnectorRoute route, {
  Color color = const Color(0xFFD85B24),
  double strokeWidth = 1.7,
  Color haloColor = const Color(0xFFFFFCF5),
  ConnectorLineStyle lineStyle = ConnectorLineStyle.solid,
  ConnectorArrowStyle arrowStyle = ConnectorArrowStyle.rounded,
  bool showHalo = true,
}) {
  final path = route.toPath();
  _paintConnectorPath(
    canvas,
    path,
    lineStyle: lineStyle,
    color: color,
    strokeWidth: strokeWidth,
    haloColor: haloColor,
    showHalo: showHalo,
  );
  _paintArrowHead(
    canvas,
    route,
    color: color,
    strokeWidth: strokeWidth,
    haloColor: haloColor,
    style: arrowStyle,
    showHalo: showHalo,
  );
}

void paintAllConnectors(
  Canvas canvas,
  List<PlacedLabel> placedLabels, {
  PlacedLabelRectResolver? labelRectResolver,
  Size? canvasSize,
  Color color = const Color(0xFFD85B24),
  Color haloColor = const Color(0xFFFFFCF5),
  double strokeWidth = 1.7,
  ConnectorLineStyle lineStyle = ConnectorLineStyle.adaptive,
  ConnectorArrowStyle arrowStyle = ConnectorArrowStyle.rounded,
  bool showHalo = true,
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
    final effectiveLineStyle = lineStyle == ConnectorLineStyle.adaptive
        ? placed.quality == PlacementQuality.fallbackEdge
            ? ConnectorLineStyle.dashed
            : ConnectorLineStyle.solid
        : lineStyle;
    paintConnectorRoute(
      canvas,
      route,
      color: color,
      haloColor: haloColor,
      strokeWidth: strokeWidth,
      lineStyle: effectiveLineStyle,
      arrowStyle: arrowStyle,
      showHalo: showHalo,
    );
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

void _paintConnectorPath(
  Canvas canvas,
  Path path, {
  required ConnectorLineStyle lineStyle,
  required Color color,
  required double strokeWidth,
  required Color haloColor,
  required bool showHalo,
  double dashLength = 6,
  double gapLength = 4,
}) {
  if (lineStyle != ConnectorLineStyle.dashed) {
    if (showHalo) {
      canvas.drawPath(path, _connectorHaloPaint(strokeWidth, haloColor));
    }
    canvas.drawPath(
      path,
      _connectorPaint(color: color, strokeWidth: strokeWidth),
    );
    return;
  }

  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final endDistance = (distance + dashLength).clamp(0.0, metric.length);
      final dash = metric.extractPath(distance, endDistance);
      if (showHalo) {
        canvas.drawPath(dash, _connectorHaloPaint(strokeWidth, haloColor));
      }
      canvas.drawPath(
        dash,
        _connectorPaint(color: color, strokeWidth: strokeWidth),
      );
      distance += dashLength + gapLength;
    }
  }
}

void _paintArrowHead(
  Canvas canvas,
  ConnectorRoute route, {
  required Color color,
  required double strokeWidth,
  required Color haloColor,
  required ConnectorArrowStyle style,
  required bool showHalo,
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

  if (style == ConnectorArrowStyle.dot) {
    final radius = 2.6 * headScale + strokeWidth * 0.35;
    if (showHalo) {
      canvas.drawCircle(
        route.to,
        radius + 1.3,
        Paint()..color = haloColor,
      );
    }
    canvas.drawCircle(route.to, radius, Paint()..color = color);
    return;
  }

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
  if (style == ConnectorArrowStyle.pointed) {
    arrowHead.close();
    if (showHalo) {
      canvas.drawPath(
        arrowHead,
        Paint()
          ..color = haloColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 2.6
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(arrowHead, Paint()..color = color);
    return;
  }

  if (showHalo) {
    canvas.drawPath(arrowHead, _connectorHaloPaint(strokeWidth, haloColor));
  }
  canvas.drawPath(
    arrowHead,
    _connectorPaint(color: color, strokeWidth: strokeWidth),
  );
}

Paint _connectorHaloPaint(double strokeWidth, Color color) => _connectorPaint(
      color: color,
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
