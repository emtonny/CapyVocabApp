import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/label_connector_geometry.dart';
import '../domain/label_placement_solver.dart';

typedef PlacedLabelRectResolver = Rect Function(PlacedLabel placedLabel);

void paintConnector(
  Canvas canvas,
  ConnectorPath path, {
  Color color = Colors.deepOrange,
  double strokeWidth = 1.5,
}) {
  final paint = _connectorPaint(color: color, strokeWidth: strokeWidth);

  // TODO: bent/orthogonal routing — future work, out of scope Task 5.
  canvas.drawLine(path.from, path.to, paint);
}

void paintAllConnectors(
  Canvas canvas,
  List<PlacedLabel> placedLabels, {
  PlacedLabelRectResolver? labelRectResolver,
}) {
  for (final placed in placedLabels) {
    final path = connectorPathForPlacedLabel(
      placed,
      labelRectResolver: labelRectResolver,
    );
    if (placed.quality == PlacementQuality.fallbackEdge) {
      _paintDashedConnector(canvas, path);
    } else {
      paintConnector(canvas, path);
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
  ConnectorPath path, {
  Color color = Colors.deepOrange,
  double strokeWidth = 1.5,
  double dashLength = 6,
  double gapLength = 4,
}) {
  final delta = path.to - path.from;
  final totalLength = delta.distance;
  if (totalLength == 0) return;

  final direction = delta / totalLength;
  final paint = _connectorPaint(color: color, strokeWidth: strokeWidth);
  var distance = 0.0;
  while (distance < totalLength) {
    final endDistance = math.min(distance + dashLength, totalLength);
    canvas.drawLine(
      path.from + direction * distance,
      path.from + direction * endDistance,
      paint,
    );
    distance += dashLength + gapLength;
  }
}

Paint _connectorPaint({required Color color, required double strokeWidth}) {
  return Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;
}
