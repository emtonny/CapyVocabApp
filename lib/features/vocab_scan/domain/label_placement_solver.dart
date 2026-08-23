import 'dart:math' as math;
import 'dart:ui';

import '../../../core/services/gemini_vision_service.dart';
import 'forbidden_zone_builder.dart';
import 'label_angle_ranker.dart';
import 'label_candidate_generator.dart';
import 'label_connector_geometry.dart';
import 'label_size_measurer.dart';

enum PlacementQuality {
  ideal,
  fallbackSmallerFont,
  fallbackAllowOverlap,
  fallbackEdge,
}

class PlacedLabel {
  const PlacedLabel({
    required this.word,
    required this.labelRect,
    required this.anchorBox,
    required this.quality,
    this.overlapsForbiddenZone = false,
    this.overlapsPlacedLabel = false,
  });

  final VocabDetection word;
  final Rect labelRect;

  /// Exact pixel-space detection box used to place and connect this label.
  final Rect anchorBox;
  final PlacementQuality quality;

  /// True only when the final edge fallback had no forbidden-zone-safe slot.
  ///
  /// All other quality tiers keep forbidden zones as a hard constraint.
  final bool overlapsForbiddenZone;

  /// True only when the final edge fallback had no label-overlap-free slot.
  ///
  /// Edge candidates first avoid every previously placed label, regardless of
  /// quality or selected canvas side.
  final bool overlapsPlacedLabel;
}

/// Places at most 15 Gemini vocabulary labels using deterministic candidates.
///
/// With N <= 15 (see maxGeminiVocabularyWords), the straightforward
/// O(N^2 * candidateCount) overlap checks are intentionally preferable to a
/// spatial index.
List<PlacedLabel> solve({
  required List<VocabDetection> words,
  required List<LabelSize> labelSizes,
  required List<Rect> anchorBoxes,
  required List<Rect> forbiddenZones,
  required Size canvasSize,
  required LabelSizeMeasurer measurer,
  required LabelStyleConfig compactStyleConfig,
  AngleRankingFunction angleRanker = rankAnglesByOpennessAndCenterBias,
}) {
  _validateInputs(words, labelSizes, anchorBoxes, canvasSize);
  final canvasRect = Offset.zero & canvasSize;
  final indexes = List<int>.generate(words.length, (index) => index)
    ..sort((first, second) {
      final byArea = _area(anchorBoxes[second]).compareTo(
        _area(anchorBoxes[first]),
      );
      return byArea != 0 ? byArea : first.compareTo(second);
    });
  final placedLabels = <PlacedLabel>[];
  final unresolvedQueue = <int>[];
  // Production builds both lists from the same input words. Without exactly
  // one zone per word, no positional zone exclusion is safe for other callers.
  final hasOneForbiddenZonePerWord = forbiddenZones.length == words.length;

  for (final index in indexes) {
    // `index` is the original input identity, not the sorted-loop position.
    final ownForbiddenZoneIndex = hasOneForbiddenZonePerWord ? index : null;
    final rankedAngles = _rankAnglesForSnapshot(
      anchorBox: anchorBoxes[index],
      canvasSize: canvasSize,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      angleRanker: angleRanker,
    );
    final size = _toSize(labelSizes[index]);
    final rect = _findCandidate(
      anchorBox: anchorBoxes[index],
      labelSize: size,
      canvasSize: canvasSize,
      canvasRect: canvasRect,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      maximumOverlapRatio: 0,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      avoidConnectorIntersections: true,
      angleDegrees: rankedAngles,
    );
    if (rect == null) {
      unresolvedQueue.add(index);
      continue;
    }
    placedLabels.add(
      PlacedLabel(
        word: words[index],
        labelRect: rect,
        anchorBox: anchorBoxes[index],
        quality: PlacementQuality.ideal,
      ),
    );
  }

  final compactConfig = compactStyleConfig.mode == LabelCardMode.compact
      ? compactStyleConfig
      : compactStyleConfig.copyWith(mode: LabelCardMode.compact);
  for (final index in unresolvedQueue) {
    final ownForbiddenZoneIndex = hasOneForbiddenZonePerWord ? index : null;
    // No other word is processed until this iteration finishes, so this exact
    // ranking object is safe to reuse across every candidate-based fallback.
    final rankedAngles = _rankAnglesForSnapshot(
      anchorBox: anchorBoxes[index],
      canvasSize: canvasSize,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      angleRanker: angleRanker,
    );
    final compactMeasured = measurer.measure(words[index], compactConfig);
    final compactSize = _toSize(compactMeasured);

    final smallerFontRect = _findCandidate(
      anchorBox: anchorBoxes[index],
      labelSize: compactSize,
      canvasSize: canvasSize,
      canvasRect: canvasRect,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      maximumOverlapRatio: 0,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      avoidConnectorIntersections: true,
      angleDegrees: rankedAngles,
    );
    if (smallerFontRect != null) {
      placedLabels.add(
        PlacedLabel(
          word: words[index],
          labelRect: smallerFontRect,
          anchorBox: anchorBoxes[index],
          quality: PlacementQuality.fallbackSmallerFont,
        ),
      );
      continue;
    }

    final connectorSafeAllowOverlapRect = _findCandidate(
      anchorBox: anchorBoxes[index],
      labelSize: compactSize,
      canvasSize: canvasSize,
      canvasRect: canvasRect,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      maximumOverlapRatio: 0.2,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      avoidConnectorIntersections: true,
      angleDegrees: rankedAngles,
    );
    final hasTargetContainingForeignZone = _hasTargetContainingForeignZone(
      anchorBox: anchorBoxes[index],
      forbiddenZones: forbiddenZones,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
    );
    final targetContainerSafeAllowOverlapRect = connectorSafeAllowOverlapRect ??
        (hasTargetContainingForeignZone
            ? _findCandidate(
                anchorBox: anchorBoxes[index],
                labelSize: compactSize,
                canvasSize: canvasSize,
                canvasRect: canvasRect,
                forbiddenZones: forbiddenZones,
                placedLabels: placedLabels,
                maximumOverlapRatio: 0.2,
                ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
                avoidConnectorIntersections: true,
                allowTargetContainingZoneIntersection: true,
                angleDegrees: rankedAngles,
              )
            : null);
    // Preserve candidate order, but relax the connector constraint only after
    // every 20%-overlap candidate has failed both connector-safe passes. A
    // containing object zone is waived separately because reaching a nested
    // target makes that one intersection geometrically unavoidable; placed
    // label and connector geometry remains a hard constraint in that pass.
    final allowOverlapRect = targetContainerSafeAllowOverlapRect ??
        _findCandidate(
          anchorBox: anchorBoxes[index],
          labelSize: compactSize,
          canvasSize: canvasSize,
          canvasRect: canvasRect,
          forbiddenZones: forbiddenZones,
          placedLabels: placedLabels,
          maximumOverlapRatio: 0.2,
          ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
          avoidConnectorIntersections: false,
          angleDegrees: rankedAngles,
        );
    if (allowOverlapRect != null) {
      placedLabels.add(
        PlacedLabel(
          word: words[index],
          labelRect: allowOverlapRect,
          anchorBox: anchorBoxes[index],
          quality: PlacementQuality.fallbackAllowOverlap,
        ),
      );
      continue;
    }

    final edgePlacement = _placeAtEdge(
      anchorBox: anchorBoxes[index],
      labelSize: compactSize,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      canvasSize: canvasSize,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
    );
    placedLabels.add(
      PlacedLabel(
        word: words[index],
        labelRect: edgePlacement.rect,
        anchorBox: anchorBoxes[index],
        quality: PlacementQuality.fallbackEdge,
        overlapsForbiddenZone: edgePlacement.overlapsForbiddenZone,
        overlapsPlacedLabel: edgePlacement.overlapsPlacedLabel,
      ),
    );
  }

  return List.unmodifiable(placedLabels);
}

Rect? _findCandidate({
  required Rect anchorBox,
  required Size labelSize,
  required Size canvasSize,
  required Rect canvasRect,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required double maximumOverlapRatio,
  required int? ignoredForbiddenZoneIndex,
  required bool avoidConnectorIntersections,
  required List<double> angleDegrees,
  bool allowTargetContainingZoneIntersection = false,
}) {
  final candidates = generateCandidates(
    anchorBox: anchorBox,
    labelSize: labelSize,
    canvasSize: canvasSize,
    angleDegrees: angleDegrees,
  );
  for (final topLeft in candidates) {
    final candidate = topLeft & labelSize;
    if (!_isFullyInside(candidate, canvasRect) ||
        anyOverlap(candidate, forbiddenZones)) {
      continue;
    }
    if (avoidConnectorIntersections &&
        !_connectorAvoidsPlacementGeometry(
          labelRect: candidate,
          anchorBox: anchorBox,
          forbiddenZones: forbiddenZones,
          placedLabels: placedLabels,
          ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
          allowTargetContainingZoneIntersection:
              allowTargetContainingZoneIntersection,
        )) {
      continue;
    }
    final respectsPlacedLabels = placedLabels.every((placed) {
      return _overlapRatio(candidate, placed.labelRect) <=
          maximumOverlapRatio + 1e-12;
    });
    if (respectsPlacedLabels) return candidate;
  }
  return null;
}

List<double> _rankAnglesForSnapshot({
  required Rect anchorBox,
  required Size canvasSize,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required int? ignoredForbiddenZoneIndex,
  required AngleRankingFunction angleRanker,
}) {
  final opennessForbiddenZones = ignoredForbiddenZoneIndex == null
      ? forbiddenZones
      : [
          for (final (index, zone) in forbiddenZones.indexed)
            if (index != ignoredForbiddenZoneIndex) zone,
        ];
  return angleRanker(
    anchorBox: anchorBox,
    angleDegrees: defaultCandidateAngleDegrees,
    forbiddenZones: opennessForbiddenZones,
    placedLabels: [
      for (final placed in placedLabels) placed.labelRect,
    ],
    canvasSize: canvasSize,
  );
}

({
  Rect rect,
  bool overlapsForbiddenZone,
  bool overlapsPlacedLabel,
}) _placeAtEdge({
  required Rect anchorBox,
  required Size labelSize,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required Size canvasSize,
  required int? ignoredForbiddenZoneIndex,
}) {
  // Keep connector avoidance best-effort even in the final tier. Only repeat
  // the same edge search without it when every connector-safe option fails.
  final connectorSafe = _findEdgePlacement(
    anchorBox: anchorBox,
    labelSize: labelSize,
    forbiddenZones: forbiddenZones,
    placedLabels: placedLabels,
    canvasSize: canvasSize,
    ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
    avoidConnectorIntersections: true,
  );
  if (connectorSafe != null) return connectorSafe;

  final hasTargetContainingForeignZone = _hasTargetContainingForeignZone(
    anchorBox: anchorBox,
    forbiddenZones: forbiddenZones,
    ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
  );
  final targetContainerSafe = hasTargetContainingForeignZone
      ? _findEdgePlacement(
          anchorBox: anchorBox,
          labelSize: labelSize,
          forbiddenZones: forbiddenZones,
          placedLabels: placedLabels,
          canvasSize: canvasSize,
          ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
          avoidConnectorIntersections: true,
          allowTargetContainingZoneIntersection: true,
        )
      : null;
  return targetContainerSafe ??
      _findEdgePlacement(
        anchorBox: anchorBox,
        labelSize: labelSize,
        forbiddenZones: forbiddenZones,
        placedLabels: placedLabels,
        canvasSize: canvasSize,
        ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
        avoidConnectorIntersections: false,
      )!;
}

({
  Rect rect,
  bool overlapsForbiddenZone,
  bool overlapsPlacedLabel,
})? _findEdgePlacement({
  required Rect anchorBox,
  required Size labelSize,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required Size canvasSize,
  required int? ignoredForbiddenZoneIndex,
  required bool avoidConnectorIntersections,
  bool allowTargetContainingZoneIntersection = false,
}) {
  const margin = 6.0;
  final canvasRect = Offset.zero & canvasSize;
  final leftHalf = Rect.fromLTWH(0, 0, canvasSize.width / 2, canvasSize.height);
  final rightHalf = Rect.fromLTWH(
    canvasSize.width / 2,
    0,
    canvasSize.width / 2,
    canvasSize.height,
  );
  final occupied = <Rect>[
    ...forbiddenZones,
    ...placedLabels.map((placed) => placed.labelRect),
  ];
  final leftOccupied = _occupiedArea(occupied, leftHalf);
  final rightOccupied = _occupiedArea(occupied, rightHalf);
  final preferredSide =
      leftOccupied <= rightOccupied ? _CanvasSide.left : _CanvasSide.right;
  final sideOrder = [preferredSide, preferredSide.opposite];

  // Preserve the forbidden-zone hard constraint for edge placements whenever
  // any safe edge slot exists.
  for (final side in sideOrder) {
    for (final rect in _edgeCandidates(
      side: side,
      labelSize: labelSize,
      canvasSize: canvasSize,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      margin: margin,
    )) {
      if (_isFullyInside(rect, canvasRect) &&
          !anyOverlap(rect, forbiddenZones) &&
          (!avoidConnectorIntersections ||
              _connectorAvoidsPlacementGeometry(
                labelRect: rect,
                anchorBox: anchorBox,
                forbiddenZones: forbiddenZones,
                placedLabels: placedLabels,
                ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
                allowTargetContainingZoneIntersection:
                    allowTargetContainingZoneIntersection,
              ))) {
        return (
          rect: rect,
          overlapsForbiddenZone: false,
          overlapsPlacedLabel: false,
        );
      }
    }
  }

  // The product contract prioritizes returning all N words. Only after both
  // edges have no safe slot may fallbackEdge overlap a forbidden zone.
  for (final side in sideOrder) {
    final candidates = _edgeCandidates(
      side: side,
      labelSize: labelSize,
      canvasSize: canvasSize,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      margin: margin,
    );
    for (final rect in candidates) {
      if (avoidConnectorIntersections &&
          !_connectorAvoidsPlacementGeometry(
            labelRect: rect,
            anchorBox: anchorBox,
            forbiddenZones: forbiddenZones,
            placedLabels: placedLabels,
            ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
            allowTargetContainingZoneIntersection:
                allowTargetContainingZoneIntersection,
          )) {
        continue;
      }
      return (
        rect: rect,
        overlapsForbiddenZone: anyOverlap(rect, forbiddenZones),
        overlapsPlacedLabel: false,
      );
    }
  }

  // No in-canvas y candidate remains clear of every placed label. The modulo
  // fallback preserves all N words and audits whichever constraints it breaks.
  final lastResort = _lastResortEdgeRect(
    side: preferredSide,
    labelSize: labelSize,
    canvasSize: canvasSize,
    edgeLabelCount: placedLabels
        .where((placed) => placed.quality == PlacementQuality.fallbackEdge)
        .length,
    margin: margin,
  );
  if (avoidConnectorIntersections &&
      !_connectorAvoidsPlacementGeometry(
        labelRect: lastResort,
        anchorBox: anchorBox,
        forbiddenZones: forbiddenZones,
        placedLabels: placedLabels,
        ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
        allowTargetContainingZoneIntersection:
            allowTargetContainingZoneIntersection,
      )) {
    return null;
  }
  return (
    rect: lastResort,
    overlapsForbiddenZone: anyOverlap(lastResort, forbiddenZones),
    overlapsPlacedLabel: _overlapsPlaced(lastResort, placedLabels),
  );
}

bool _connectorAvoidsPlacementGeometry({
  required Rect labelRect,
  required Rect anchorBox,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required int? ignoredForbiddenZoneIndex,
  required bool allowTargetContainingZoneIntersection,
}) {
  final connector = computeConnectorPath(
    labelRect: labelRect,
    targetBox: anchorBox,
  );
  for (final (zoneIndex, zone) in forbiddenZones.indexed) {
    // A connector whose target is nested inside another detection must enter
    // that containing zone. Treating it as avoidable would force every strict
    // candidate into a relaxed tier and also waive avoidable label/connector
    // conflicts. Candidate labels still cannot overlap any forbidden zone.
    if (zoneIndex == ignoredForbiddenZoneIndex ||
        (allowTargetContainingZoneIntersection &&
            _containsRect(zone, anchorBox))) {
      continue;
    }
    if (segmentIntersectsRect(
      from: connector.from,
      to: connector.to,
      rect: zone,
    )) {
      return false;
    }
  }
  for (final placed in placedLabels) {
    final placedConnector = computeConnectorPath(
      labelRect: placed.labelRect,
      targetBox: placed.anchorBox,
    );
    if (connectorConflictsWithPlacedGeometry(
      candidateLabelRect: labelRect,
      candidateConnector: connector,
      placedLabelRect: placed.labelRect,
      placedConnector: placedConnector,
    )) {
      return false;
    }
  }
  return true;
}

List<Rect> _edgeCandidates({
  required _CanvasSide side,
  required Size labelSize,
  required Size canvasSize,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required double margin,
}) {
  final x = side == _CanvasSide.left
      ? margin
      : canvasSize.width - labelSize.width - margin;
  if (x < 0 || x + labelSize.width > canvasSize.width) return const [];

  // One global vertical rail prevents left/right edge cards and cards of
  // different quality tiers from silently reusing an overlapping y position.
  final yValues = <double>{margin};
  for (final rect in [
    ...forbiddenZones,
    ...placedLabels.map((label) => label.labelRect),
  ]) {
    yValues
      ..add(rect.bottom + margin)
      ..add(rect.top - labelSize.height - margin);
  }
  final sortedY = yValues.toList()..sort();
  final canvasRect = Offset.zero & canvasSize;
  final candidates = <Rect>[];
  for (final y in sortedY) {
    final rect = Rect.fromLTWH(x, y, labelSize.width, labelSize.height);
    if (!_isFullyInside(rect, canvasRect)) continue;
    if (_overlapsPlaced(rect, placedLabels)) continue;
    candidates.add(rect);
  }
  return candidates;
}

Rect _lastResortEdgeRect({
  required _CanvasSide side,
  required Size labelSize,
  required Size canvasSize,
  required int edgeLabelCount,
  required double margin,
}) {
  final maximumX = math.max(0.0, canvasSize.width - labelSize.width);
  final requestedX = side == _CanvasSide.left
      ? margin
      : canvasSize.width - labelSize.width - margin;
  final x = requestedX.clamp(0.0, maximumX).toDouble();
  final maximumY = math.max(0.0, canvasSize.height - labelSize.height);
  final verticalStep = labelSize.height + margin;
  final requestedY = margin + edgeLabelCount * verticalStep;
  final y = maximumY == 0 ? 0.0 : requestedY % (maximumY + 1);
  return Rect.fromLTWH(x, y, labelSize.width, labelSize.height);
}

double _occupiedArea(List<Rect> rects, Rect half) {
  return rects.fold(0, (sum, rect) => sum + _intersectionArea(rect, half));
}

double _overlapRatio(Rect first, Rect second) {
  final overlapArea = _intersectionArea(first, second);
  if (overlapArea == 0) return 0;
  final smallerArea = math.min(_area(first), _area(second));
  return smallerArea <= 0 ? 0 : overlapArea / smallerArea;
}

double _intersectionArea(Rect first, Rect second) {
  if (!first.overlaps(second)) return 0;
  final intersection = first.intersect(second);
  return math.max(0, intersection.width) * math.max(0, intersection.height);
}

double _area(Rect rect) => math.max(0, rect.width) * math.max(0, rect.height);

bool _containsRect(Rect outer, Rect inner) {
  return outer.left <= inner.left &&
      outer.top <= inner.top &&
      outer.right >= inner.right &&
      outer.bottom >= inner.bottom;
}

bool _hasTargetContainingForeignZone({
  required Rect anchorBox,
  required List<Rect> forbiddenZones,
  required int? ignoredForbiddenZoneIndex,
}) {
  return forbiddenZones.indexed.any(
    (entry) =>
        entry.$1 != ignoredForbiddenZoneIndex &&
        _containsRect(entry.$2, anchorBox),
  );
}

Size _toSize(LabelSize size) => Size(size.width, size.height);

bool _isFullyInside(Rect rect, Rect bounds) {
  return rect.left >= bounds.left &&
      rect.top >= bounds.top &&
      rect.right <= bounds.right &&
      rect.bottom <= bounds.bottom;
}

bool _overlapsPlaced(Rect rect, List<PlacedLabel> placedLabels) =>
    placedLabels.any((placed) => rect.overlaps(placed.labelRect));

void _validateInputs(
  List<VocabDetection> words,
  List<LabelSize> labelSizes,
  List<Rect> anchorBoxes,
  Size canvasSize,
) {
  if (words.length != labelSizes.length || words.length != anchorBoxes.length) {
    throw ArgumentError(
        'words, labelSizes, and anchorBoxes must have equal lengths');
  }
  if (!canvasSize.width.isFinite ||
      !canvasSize.height.isFinite ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    throw ArgumentError.value(
        canvasSize, 'canvasSize', 'must be finite and positive');
  }
  if (labelSizes.any(
        (size) =>
            !size.width.isFinite ||
            !size.height.isFinite ||
            size.width <= 0 ||
            size.height <= 0,
      ) ||
      anchorBoxes.any(
        (box) =>
            !box.left.isFinite ||
            !box.top.isFinite ||
            !box.right.isFinite ||
            !box.bottom.isFinite ||
            box.width <= 0 ||
            box.height <= 0,
      )) {
    throw ArgumentError(
        'label sizes and anchor boxes must be finite and positive');
  }
}

enum _CanvasSide {
  left,
  right;

  _CanvasSide get opposite =>
      this == _CanvasSide.left ? _CanvasSide.right : _CanvasSide.left;
}
