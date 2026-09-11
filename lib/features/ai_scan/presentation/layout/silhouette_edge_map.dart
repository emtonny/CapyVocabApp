import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../vocab_scan/domain/label_connector_geometry.dart';
import '../../../vocab_scan/domain/label_placement_solver.dart';

const double maxConnectorLengthRatio = 0.22;

enum RayCastFallbackReason {
  none,
  invalidInput,
  noClearEdge,
  excessiveShift,
  otherObjectCore,
  connectorCapExceeded,
}

enum AnchorRefinementMethod { sobel, bbox }

class RayCastAnchorResult {
  const RayCastAnchorResult({
    required this.anchor,
    required this.fallbackAnchor,
    required this.fallbackReason,
    required this.scannedSampleCount,
    this.gradientMagnitude,
    this.backgroundGradient,
    this.method = AnchorRefinementMethod.bbox,
  });

  final Offset anchor;
  final Offset fallbackAnchor;
  final RayCastFallbackReason fallbackReason;
  final int scannedSampleCount;
  final double? gradientMagnitude;
  final double? backgroundGradient;
  final AnchorRefinementMethod method;

  bool get usedFallback => fallbackReason != RayCastFallbackReason.none;

  RayCastAnchorResult fallback(RayCastFallbackReason reason) =>
      RayCastAnchorResult(
        anchor: fallbackAnchor,
        fallbackAnchor: fallbackAnchor,
        fallbackReason: reason,
        scannedSampleCount: scannedSampleCount,
        gradientMagnitude: gradientMagnitude,
        backgroundGradient: backgroundGradient,
        method: AnchorRefinementMethod.bbox,
      );
}

class AnchorRefinementBatch {
  const AnchorRefinementBatch({
    required this.connectorPaths,
    required this.results,
  });

  final List<ConnectorPath> connectorPaths;
  final List<RayCastAnchorResult> results;
}

/// Refines connector endpoints without changing solver-owned label placement.
///
/// Sobel refines the endpoint when image data is available, while the
/// deterministic bbox connector remains the final fallback.
AnchorRefinementBatch refineConnectorPaths({
  required List<PlacedLabel> placedLabels,
  required List<ConnectorPath> bboxPaths,
  required Rect imageRect,
  SilhouetteEdgeMap? edgeMap,
}) {
  if (placedLabels.length != bboxPaths.length) {
    throw ArgumentError('Placed labels and connector paths must align.');
  }
  final imageDiagonal = math.sqrt(
    imageRect.width * imageRect.width + imageRect.height * imageRect.height,
  );
  final paths = <ConnectorPath>[];
  final results = <RayCastAnchorResult>[];

  for (var index = 0; index < placedLabels.length; index++) {
    final placed = placedLabels[index];
    final bboxPath = bboxPaths[index];
    RayCastAnchorResult result;
    if (edgeMap != null) {
      result = edgeMap.findAnchor(
        cardAnchor: bboxPath.from,
        objectRect: placed.anchorBox,
        imageRect: imageRect,
        fallbackAnchor: bboxPath.to,
        otherObjectRects: [
          for (var otherIndex = 0;
              otherIndex < placedLabels.length;
              otherIndex++)
            if (otherIndex != index) placedLabels[otherIndex].anchorBox,
        ],
      );
    } else {
      result = RayCastAnchorResult(
        anchor: bboxPath.to,
        fallbackAnchor: bboxPath.to,
        fallbackReason: RayCastFallbackReason.invalidInput,
        scannedSampleCount: 0,
      );
    }

    final refinedLength = (result.anchor - bboxPath.from).distance;
    final bboxLength = (bboxPath.to - bboxPath.from).distance;
    final maximumLength = math.max(
      bboxLength,
      imageDiagonal * maxConnectorLengthRatio,
    );
    if (refinedLength > maximumLength + 0.001) {
      result = result.fallback(RayCastFallbackReason.connectorCapExceeded);
    }
    paths.add(ConnectorPath(from: bboxPath.from, to: result.anchor));
    results.add(result);
  }

  return AnchorRefinementBatch(
    connectorPaths: List.unmodifiable(paths),
    results: List.unmodifiable(results),
  );
}

class SilhouetteEdgeMapInput {
  const SilhouetteEdgeMapInput({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

SilhouetteEdgeMap buildSilhouetteEdgeMap(SilhouetteEdgeMapInput input) =>
    SilhouetteEdgeMap.fromRgba(
      rgba: input.rgba,
      width: input.width,
      height: input.height,
    );

/// Full-resolution grayscale source used for inexpensive silhouette probes.
///
/// Unlike [TextureComplexityMap], this map is never downsampled. Sobel values
/// are computed only at the handful of pixels sampled by each connector ray.
class SilhouetteEdgeMap {
  const SilhouetteEdgeMap._({
    required this.width,
    required this.height,
    required Uint8List grayscale,
  }) : _grayscale = grayscale;

  factory SilhouetteEdgeMap.fromRgba({
    required Uint8List rgba,
    required int width,
    required int height,
  }) {
    if (width < 3 || height < 3 || rgba.length < width * height * 4) {
      return SilhouetteEdgeMap._(
        width: 0,
        height: 0,
        grayscale: Uint8List(0),
      );
    }
    final grayscale = Uint8List(width * height);
    for (var index = 0; index < grayscale.length; index++) {
      final rgbaIndex = index * 4;
      grayscale[index] = (rgba[rgbaIndex] * 0.299 +
              rgba[rgbaIndex + 1] * 0.587 +
              rgba[rgbaIndex + 2] * 0.114)
          .round();
    }
    return SilhouetteEdgeMap._(
      width: width,
      height: height,
      grayscale: grayscale,
    );
  }

  final int width;
  final int height;
  final Uint8List _grayscale;

  bool get isValid => width >= 3 && height >= 3;

  RayCastAnchorResult findAnchor({
    required Offset cardAnchor,
    required Rect objectRect,
    required Rect imageRect,
    required Offset fallbackAnchor,
    double sampleSpacing = 2.5,
    double maxShiftObjectDiagonalRatio = 0.6,
    Iterable<Rect> otherObjectRects = const [],
  }) {
    if (!isValid ||
        !_isFiniteOffset(cardAnchor) ||
        !_isFiniteOffset(fallbackAnchor) ||
        !_isFiniteRect(objectRect) ||
        !_isFiniteRect(imageRect) ||
        sampleSpacing <= 0) {
      return RayCastAnchorResult(
        anchor: fallbackAnchor,
        fallbackAnchor: fallbackAnchor,
        fallbackReason: RayCastFallbackReason.invalidInput,
        scannedSampleCount: 0,
      );
    }

    final sourceCard = _canvasToSource(cardAnchor, imageRect);
    final sourceObjectRect = Rect.fromLTRB(
      (objectRect.left - imageRect.left) / imageRect.width * width,
      (objectRect.top - imageRect.top) / imageRect.height * height,
      (objectRect.right - imageRect.left) / imageRect.width * width,
      (objectRect.bottom - imageRect.top) / imageRect.height * height,
    );
    final sourceCenter = sourceObjectRect.center;
    final ray = sourceCenter - sourceCard;
    final rayLength = ray.distance;
    if (rayLength <= sampleSpacing) {
      return RayCastAnchorResult(
        anchor: fallbackAnchor,
        fallbackAnchor: fallbackAnchor,
        fallbackReason: RayCastFallbackReason.invalidInput,
        scannedSampleCount: 0,
      );
    }

    final direction = ray / rayLength;
    // The backend bbox is intentionally shrunken. Begin looking before that
    // rectangle so the true silhouette outside it can still be recovered.
    final searchPadding = math.min(
          sourceObjectRect.width,
          sourceObjectRect.height,
        ) *
        0.5;
    final searchRect = sourceObjectRect.inflate(searchPadding);
    final entryDistance = _rayEntryDistance(
      origin: sourceCard,
      direction: direction,
      maximumDistance: rayLength,
      rect: searchRect,
    );
    if (entryDistance == null) {
      return RayCastAnchorResult(
        anchor: fallbackAnchor,
        fallbackAnchor: fallbackAnchor,
        fallbackReason: RayCastFallbackReason.invalidInput,
        scannedSampleCount: 0,
      );
    }

    const backgroundSampleCount = 8;
    final scanStart = math.max(
      sampleSpacing,
      entryDistance - (backgroundSampleCount + 2) * sampleSpacing,
    );
    final gradients = <({double magnitude, double alignment})>[];
    final points = <Offset>[];
    for (var distance = scanStart;
        distance <= rayLength;
        distance += sampleSpacing) {
      final point = sourceCard + direction * distance;
      if (point.dx < 1 ||
          point.dy < 1 ||
          point.dx >= width - 1 ||
          point.dy >= height - 1) {
        continue;
      }
      points.add(point);
      final sobel = _sobel(point.dx.round(), point.dy.round());
      final alignment = sobel.magnitude <= 1e-9
          ? 0.0
          : (sobel.gx * direction.dx + sobel.gy * direction.dy).abs() /
              sobel.magnitude;
      gradients.add((magnitude: sobel.magnitude, alignment: alignment));
    }

    if (gradients.length <= backgroundSampleCount) {
      return RayCastAnchorResult(
        anchor: fallbackAnchor,
        fallbackAnchor: fallbackAnchor,
        fallbackReason: RayCastFallbackReason.noClearEdge,
        scannedSampleCount: gradients.length,
      );
    }

    for (var index = backgroundSampleCount; index < gradients.length; index++) {
      final baselineStart = math.max(0, index - backgroundSampleCount);
      final baseline = gradients
          .sublist(baselineStart, index)
          .map((sample) => sample.magnitude)
          .toList(growable: false);
      final mean = baseline.reduce((a, b) => a + b) / baseline.length;
      final variance = baseline.fold<double>(
            0,
            (sum, value) => sum + (value - mean) * (value - mean),
          ) /
          baseline.length;
      final standardDeviation = math.sqrt(variance);
      final adaptiveThreshold = math.max(
        32.0,
        math.max(mean * 1.8, mean + math.max(18, standardDeviation * 2)),
      );
      final pointDistance = (points[index] - sourceCard).distance;
      if (pointDistance + sampleSpacing < entryDistance ||
          gradients[index].magnitude < adaptiveThreshold ||
          gradients[index].alignment < 0.35) {
        continue;
      }
      final canvasAnchor = _sourceToCanvas(points[index], imageRect);
      final objectDiagonal = math.sqrt(
        objectRect.width * objectRect.width +
            objectRect.height * objectRect.height,
      );
      if ((canvasAnchor - fallbackAnchor).distance >
          objectDiagonal * maxShiftObjectDiagonalRatio) {
        return RayCastAnchorResult(
          anchor: fallbackAnchor,
          fallbackAnchor: fallbackAnchor,
          fallbackReason: RayCastFallbackReason.excessiveShift,
          scannedSampleCount: index + 1,
        );
      }
      if (otherObjectRects
          .any((rect) => _innerCore(rect).contains(canvasAnchor))) {
        return RayCastAnchorResult(
          anchor: fallbackAnchor,
          fallbackAnchor: fallbackAnchor,
          fallbackReason: RayCastFallbackReason.otherObjectCore,
          scannedSampleCount: index + 1,
        );
      }
      return RayCastAnchorResult(
        anchor: canvasAnchor,
        fallbackAnchor: fallbackAnchor,
        fallbackReason: RayCastFallbackReason.none,
        scannedSampleCount: index + 1,
        gradientMagnitude: gradients[index].magnitude,
        backgroundGradient: mean,
        method: AnchorRefinementMethod.sobel,
      );
    }

    return RayCastAnchorResult(
      anchor: fallbackAnchor,
      fallbackAnchor: fallbackAnchor,
      fallbackReason: RayCastFallbackReason.noClearEdge,
      scannedSampleCount: gradients.length,
    );
  }

  ({double gx, double gy, double magnitude}) _sobel(int x, int y) {
    int pixel(int dx, int dy) => _grayscale[(y + dy) * width + x + dx];
    final gx = -pixel(-1, -1) +
        pixel(1, -1) -
        2 * pixel(-1, 0) +
        2 * pixel(1, 0) -
        pixel(-1, 1) +
        pixel(1, 1);
    final gy = -pixel(-1, -1) -
        2 * pixel(0, -1) -
        pixel(1, -1) +
        pixel(-1, 1) +
        2 * pixel(0, 1) +
        pixel(1, 1);
    return (
      gx: gx.toDouble(),
      gy: gy.toDouble(),
      magnitude: math.sqrt((gx * gx + gy * gy).toDouble()),
    );
  }

  Offset _canvasToSource(Offset point, Rect imageRect) => Offset(
        (point.dx - imageRect.left) / imageRect.width * width,
        (point.dy - imageRect.top) / imageRect.height * height,
      );

  Offset _sourceToCanvas(Offset point, Rect imageRect) => Offset(
        imageRect.left + point.dx / width * imageRect.width,
        imageRect.top + point.dy / height * imageRect.height,
      );
}

Rect _innerCore(Rect rect) => Rect.fromLTRB(
      rect.left + rect.width * 0.2,
      rect.top + rect.height * 0.2,
      rect.right - rect.width * 0.2,
      rect.bottom - rect.height * 0.2,
    );

double? _rayEntryDistance({
  required Offset origin,
  required Offset direction,
  required double maximumDistance,
  required Rect rect,
}) {
  var minimum = 0.0;
  var maximum = maximumDistance;

  bool clip(
      double originValue, double directionValue, double low, double high) {
    if (directionValue.abs() < 1e-9) {
      return originValue >= low && originValue <= high;
    }
    final first = (low - originValue) / directionValue;
    final second = (high - originValue) / directionValue;
    minimum = math.max(minimum, math.min(first, second));
    maximum = math.min(maximum, math.max(first, second));
    return minimum <= maximum;
  }

  if (!clip(origin.dx, direction.dx, rect.left, rect.right) ||
      !clip(origin.dy, direction.dy, rect.top, rect.bottom)) {
    return null;
  }
  return minimum.clamp(0, maximumDistance);
}

bool _isFiniteOffset(Offset offset) => offset.dx.isFinite && offset.dy.isFinite;

bool _isFiniteRect(Rect rect) =>
    rect.left.isFinite &&
    rect.top.isFinite &&
    rect.right.isFinite &&
    rect.bottom.isFinite &&
    rect.width > 0 &&
    rect.height > 0;
