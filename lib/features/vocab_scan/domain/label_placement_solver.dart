import 'dart:math' as math;
import 'dart:ui';

import '../../../core/services/gemini_vision_service.dart';
import 'forbidden_zone_builder.dart';
import 'label_angle_ranker.dart';
import 'label_candidate_generator.dart';
import 'label_connector_geometry.dart';
import 'label_size_measurer.dart';
import 'label_unit_geometry.dart';

const double _candidateDistanceTieEpsilon = 1e-9;

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
    this.collisionGeometry,
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

  /// Visible card, badge, and sticker bounds used for collision checks.
  /// Null keeps legacy rectangular behavior for callers with raw sizes.
  final LabelUnitGeometry? collisionGeometry;
}

/// Places at most 15 Gemini vocabulary labels using deterministic candidates.
///
/// With N <= 15 (see maxGeminiVocabularyWords), recomputing the remaining
/// candidate counts after each placement is intentionally preferable to a
/// more complex spatial index.
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
  final placedLabels = <PlacedLabel>[];
  final unresolvedQueue = <int>[];
  // Production builds both lists from the same input words. Without exactly
  // one zone per word, no positional zone exclusion is safe for other callers.
  final hasOneForbiddenZonePerWord = forbiddenZones.length == words.length;

  final remainingIndexes = List<int>.generate(words.length, (index) => index);
  while (remainingIndexes.isNotEmpty) {
    final feasible = <_CandidateAssessment>[];
    final impossible = <int>[];
    for (final index in remainingIndexes) {
      final ownForbiddenZoneIndex = hasOneForbiddenZonePerWord ? index : null;
      final measured = labelSizes[index];
      final size = _toSize(measured);
      final candidates = _validCandidatesWithAngularRecovery(
        anchorBox: anchorBoxes[index],
        labelSize: size,
        candidateCollisionGeometry: measured.collisionGeometry,
        canvasSize: canvasSize,
        canvasRect: canvasRect,
        forbiddenZones: forbiddenZones,
        placedLabels: placedLabels,
        maximumOverlapRatio: 0,
        ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
        avoidConnectorIntersections: true,
        angleDegrees: defaultCandidateAngleDegrees,
      );
      if (candidates.isEmpty) {
        impossible.add(index);
      } else {
        feasible.add(
          _CandidateAssessment(
            index: index,
            candidateCount: candidates.length,
            labelArea: size.width * size.height,
          ),
        );
      }
    }

    // A valid ideal slot can only disappear as more labels are placed. Defer
    // zero-candidate words immediately, then place the most constrained word.
    unresolvedQueue.addAll(impossible);
    remainingIndexes.removeWhere(impossible.contains);
    if (feasible.isEmpty) break;
    feasible.sort((first, second) {
      final byCandidateCount = first.candidateCount.compareTo(
        second.candidateCount,
      );
      if (byCandidateCount != 0) return byCandidateCount;
      final byLabelArea = first.labelArea.compareTo(second.labelArea);
      return byLabelArea != 0
          ? byLabelArea
          : first.index.compareTo(second.index);
    });
    final selected = feasible.first;
    final index = selected.index;
    final measured = labelSizes[index];
    final ownForbiddenZoneIndex = hasOneForbiddenZonePerWord ? index : null;
    final rankedAngles = _rankAnglesForSnapshot(
      anchorBox: anchorBoxes[index],
      canvasSize: canvasSize,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      angleRanker: angleRanker,
    );
    final rect = _findCandidate(
      anchorBox: anchorBoxes[index],
      labelSize: _toSize(measured),
      candidateCollisionGeometry: measured.collisionGeometry,
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
      // A custom angle ranker may legally return a subset of the angles used
      // for MRV counting. Keep that word recoverable through the fallback.
      unresolvedQueue.add(index);
      remainingIndexes.remove(index);
      continue;
    }
    placedLabels.add(
      PlacedLabel(
        word: words[index],
        labelRect: rect,
        anchorBox: anchorBoxes[index],
        quality: PlacementQuality.ideal,
        collisionGeometry: _positionCollisionGeometry(measured, rect),
      ),
    );
    remainingIndexes.remove(index);
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
      candidateCollisionGeometry: compactMeasured.collisionGeometry,
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
          collisionGeometry: _positionCollisionGeometry(
            compactMeasured,
            smallerFontRect,
          ),
        ),
      );
      continue;
    }

    final connectorSafeRelaxedRect = _findCandidate(
      anchorBox: anchorBoxes[index],
      labelSize: compactSize,
      candidateCollisionGeometry: compactMeasured.collisionGeometry,
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
    final targetContainerSafeRelaxedRect = connectorSafeRelaxedRect ??
        (hasTargetContainingForeignZone
            ? _findCandidate(
                anchorBox: anchorBoxes[index],
                labelSize: compactSize,
                candidateCollisionGeometry: compactMeasured.collisionGeometry,
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
    if (targetContainerSafeRelaxedRect != null) {
      placedLabels.add(
        PlacedLabel(
          word: words[index],
          labelRect: targetContainerSafeRelaxedRect,
          anchorBox: anchorBoxes[index],
          quality: PlacementQuality.fallbackAllowOverlap,
          collisionGeometry: _positionCollisionGeometry(
            compactMeasured,
            targetContainerSafeRelaxedRect,
          ),
        ),
      );
      continue;
    }

    // Moving the complete label to a connector-safe edge is preferable to
    // drawing a connector through another object after a badge collision
    // invalidates every nearby candidate.
    final connectorSafeEdgePlacement = _findEdgePlacement(
          anchorBox: anchorBoxes[index],
          labelSize: compactSize,
          forbiddenZones: forbiddenZones,
          placedLabels: placedLabels,
          canvasSize: canvasSize,
          ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
          avoidConnectorIntersections: true,
        ) ??
        (hasTargetContainingForeignZone
            ? _findEdgePlacement(
                anchorBox: anchorBoxes[index],
                labelSize: compactSize,
                forbiddenZones: forbiddenZones,
                placedLabels: placedLabels,
                canvasSize: canvasSize,
                ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
                avoidConnectorIntersections: true,
                allowTargetContainingZoneIntersection: true,
              )
            : null);
    if (connectorSafeEdgePlacement != null) {
      placedLabels.add(
        PlacedLabel(
          word: words[index],
          labelRect: connectorSafeEdgePlacement.rect,
          anchorBox: anchorBoxes[index],
          quality: PlacementQuality.fallbackEdge,
          overlapsForbiddenZone:
              connectorSafeEdgePlacement.overlapsForbiddenZone,
          overlapsPlacedLabel: connectorSafeEdgePlacement.overlapsPlacedLabel,
          collisionGeometry: _positionCollisionGeometry(
            compactMeasured,
            connectorSafeEdgePlacement.rect,
          ),
        ),
      );
      continue;
    }

    // Preserve candidate order, but relax the connector constraint only after
    // both connector-safe passes fail. A containing object zone is waived
    // separately because reaching a nested target makes that intersection
    // geometrically unavoidable. Footprints may overlap by up to 20%, but a
    // badge remains a hard collision boundary against every visible label
    // component in both directions.
    final relaxedRect = _findCandidate(
      anchorBox: anchorBoxes[index],
      labelSize: compactSize,
      candidateCollisionGeometry: compactMeasured.collisionGeometry,
      canvasSize: canvasSize,
      canvasRect: canvasRect,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      maximumOverlapRatio: 0.2,
      ignoredForbiddenZoneIndex: ownForbiddenZoneIndex,
      avoidConnectorIntersections: false,
      angleDegrees: rankedAngles,
    );
    if (relaxedRect != null) {
      placedLabels.add(
        PlacedLabel(
          word: words[index],
          labelRect: relaxedRect,
          anchorBox: anchorBoxes[index],
          quality: PlacementQuality.fallbackAllowOverlap,
          collisionGeometry: _positionCollisionGeometry(
            compactMeasured,
            relaxedRect,
          ),
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
        collisionGeometry: _positionCollisionGeometry(
          compactMeasured,
          edgePlacement.rect,
        ),
      ),
    );
  }

  return List.unmodifiable(placedLabels);
}

Rect? _findCandidate({
  required Rect anchorBox,
  required Size labelSize,
  required LabelUnitGeometry? candidateCollisionGeometry,
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
  final candidates = _validCandidatesWithAngularRecovery(
    anchorBox: anchorBox,
    labelSize: labelSize,
    candidateCollisionGeometry: candidateCollisionGeometry,
    canvasSize: canvasSize,
    canvasRect: canvasRect,
    forbiddenZones: forbiddenZones,
    placedLabels: placedLabels,
    maximumOverlapRatio: maximumOverlapRatio,
    ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
    avoidConnectorIntersections: avoidConnectorIntersections,
    angleDegrees: angleDegrees,
    allowTargetContainingZoneIntersection:
        allowTargetContainingZoneIntersection,
  );
  return candidates.firstOrNull;
}

List<Rect> _validCandidatesWithAngularRecovery({
  required Rect anchorBox,
  required Size labelSize,
  required LabelUnitGeometry? candidateCollisionGeometry,
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
  final recoveryAngles = generateRecoveryAngleDegrees(angleDegrees);
  for (final radiusTier in CandidateRadiusTier.values) {
    final baseCandidates = _validCandidates(
      anchorBox: anchorBox,
      labelSize: labelSize,
      candidateCollisionGeometry: candidateCollisionGeometry,
      canvasSize: canvasSize,
      canvasRect: canvasRect,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      maximumOverlapRatio: maximumOverlapRatio,
      ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
      avoidConnectorIntersections: avoidConnectorIntersections,
      angleDegrees: angleDegrees,
      radiusTier: radiusTier,
      allowTargetContainingZoneIntersection:
          allowTargetContainingZoneIntersection,
    );
    if (baseCandidates.isNotEmpty) return baseCandidates;
    if (recoveryAngles.isEmpty) continue;

    final recoveryCandidates = _validCandidates(
      anchorBox: anchorBox,
      labelSize: labelSize,
      candidateCollisionGeometry: candidateCollisionGeometry,
      canvasSize: canvasSize,
      canvasRect: canvasRect,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      maximumOverlapRatio: maximumOverlapRatio,
      ignoredForbiddenZoneIndex: ignoredForbiddenZoneIndex,
      avoidConnectorIntersections: avoidConnectorIntersections,
      angleDegrees: recoveryAngles,
      radiusTier: radiusTier,
      allowTargetContainingZoneIntersection:
          allowTargetContainingZoneIntersection,
    );
    if (recoveryCandidates.isNotEmpty) return recoveryCandidates;
  }
  return const [];
}

List<Rect> _validCandidates({
  required Rect anchorBox,
  required Size labelSize,
  required LabelUnitGeometry? candidateCollisionGeometry,
  required Size canvasSize,
  required Rect canvasRect,
  required List<Rect> forbiddenZones,
  required List<PlacedLabel> placedLabels,
  required double maximumOverlapRatio,
  required int? ignoredForbiddenZoneIndex,
  required bool avoidConnectorIntersections,
  required List<double> angleDegrees,
  required CandidateRadiusTier radiusTier,
  bool allowTargetContainingZoneIntersection = false,
}) {
  final candidates = generateCandidates(
    anchorBox: anchorBox,
    labelSize: labelSize,
    canvasSize: canvasSize,
    angleDegrees: angleDegrees,
    radiusTier: radiusTier,
  );
  final validCandidates =
      <({Rect rect, double distance, int angleRank, int order})>[];
  for (final (order, topLeft) in candidates.indexed) {
    final candidate = topLeft & labelSize;
    if (!_isFullyInside(candidate, canvasRect) ||
        anyOverlap(candidate, forbiddenZones) ||
        _badgeOverlapsPlacedLabel(
          candidate,
          candidateCollisionGeometry,
          placedLabels,
        )) {
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
    if (respectsPlacedLabels) {
      final connector = computeConnectorPath(
        labelRect: candidate,
        targetBox: anchorBox,
      );
      validCandidates.add((
        rect: candidate,
        distance: (connector.to - connector.from).distance,
        angleRank: _candidateAngleRank(
          candidateCenter: candidate.center,
          anchorCenter: anchorBox.center,
          rankedAngleDegrees: angleDegrees,
        ),
        order: order,
      ));
    }
  }
  validCandidates.sort((first, second) {
    final distanceDifference = first.distance - second.distance;
    if (distanceDifference.abs() > _candidateDistanceTieEpsilon) {
      return distanceDifference.sign.toInt();
    }
    final byAngleRank = first.angleRank.compareTo(second.angleRank);
    return byAngleRank != 0 ? byAngleRank : first.order.compareTo(second.order);
  });
  return validCandidates.map((candidate) => candidate.rect).toList();
}

int _candidateAngleRank({
  required Offset candidateCenter,
  required Offset anchorCenter,
  required List<double> rankedAngleDegrees,
}) {
  final direction = candidateCenter - anchorCenter;
  final rawDegrees = math.atan2(direction.dy, direction.dx) * 180 / math.pi;
  final candidateDegrees = rawDegrees < 0 ? rawDegrees + 360 : rawDegrees;
  var closestRank = 0;
  var closestDifference = double.infinity;
  for (final (rank, degrees) in rankedAngleDegrees.indexed) {
    final normalizedDegrees = (degrees % 360 + 360) % 360;
    final difference = (candidateDegrees - normalizedDegrees).abs();
    final circularDifference = math.min(difference, 360 - difference);
    if (circularDifference < closestDifference) {
      closestDifference = circularDifference;
      closestRank = rank;
    }
  }
  return closestRank;
}

class _CandidateAssessment {
  const _CandidateAssessment({
    required this.index,
    required this.candidateCount,
    required this.labelArea,
  });

  final int index;
  final int candidateCount;
  final double labelArea;
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
  final foreignZones = <Rect>[];
  for (final (zoneIndex, zone) in forbiddenZones.indexed) {
    // A connector whose target is nested inside another detection must enter
    // that containing zone. Treating it as avoidable would force every strict
    // candidate into a relaxed tier and also waive avoidable label/connector
    // conflicts.
    if (zoneIndex == ignoredForbiddenZoneIndex ||
        (allowTargetContainingZoneIntersection &&
            _containsRect(zone, anchorBox))) {
      continue;
    }
    foreignZones.add(zone);
  }

  // Preserve the established placement contract: a curve may not rescue a
  // candidate whose direct connector was already considered invalid. The
  // sampled route check below is an additional visual-safety guard only.
  final directConnector = computeConnectorPath(
    labelRect: labelRect,
    targetBox: anchorBox,
  );
  for (final zone in foreignZones) {
    if (segmentIntersectsRect(
      from: directConnector.from,
      to: directConnector.to,
      rect: zone,
    )) {
      return false;
    }
  }
  for (final placed in placedLabels) {
    if (connectorConflictsWithPlacedGeometry(
      candidateLabelRect: labelRect,
      candidateConnector: directConnector,
      placedLabelRect: placed.labelRect,
      placedConnector: computeConnectorPath(
        labelRect: placed.labelRect,
        targetBox: placed.anchorBox,
      ),
    )) {
      return false;
    }
  }

  final placedConnectors = <ConnectorRoute>[];
  for (final (placedIndex, placed) in placedLabels.indexed) {
    placedConnectors.add(
      selectConnectorRoute(
        labelRect: placed.labelRect,
        targetBox: placed.anchorBox,
        obstacleRects: [
          labelRect,
          for (final (otherIndex, other) in placedLabels.indexed)
            if (otherIndex != placedIndex) other.labelRect,
        ],
        existingRoutes: placedConnectors,
      ),
    );
  }
  final connector = selectConnectorRoute(
    labelRect: labelRect,
    targetBox: anchorBox,
    obstacleRects: [
      ...foreignZones,
      ...placedLabels.map((placed) => placed.labelRect),
    ],
    existingRoutes: placedConnectors,
  );
  for (final zone in foreignZones) {
    if (connectorRouteIntersectsRect(route: connector, rect: zone)) {
      return false;
    }
  }
  for (final (index, placed) in placedLabels.indexed) {
    final placedConnector = placedConnectors[index];
    if (connectorRouteConflictsWithPlacedGeometry(
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

LabelUnitGeometry? _positionCollisionGeometry(
  LabelSize size,
  Rect footprintRect,
) {
  final geometry = size.collisionGeometry;
  return geometry?.shift(
    footprintRect.topLeft - geometry.footprintRect.topLeft,
  );
}

bool _badgeOverlapsPlacedLabel(
  Rect candidateFootprint,
  LabelUnitGeometry? candidateRelativeGeometry,
  List<PlacedLabel> placedLabels,
) {
  if (candidateRelativeGeometry == null) return false;
  final candidateGeometry = candidateRelativeGeometry.shift(
    candidateFootprint.topLeft -
        candidateRelativeGeometry.footprintRect.topLeft,
  );
  for (final placed in placedLabels) {
    final placedGeometry = placed.collisionGeometry;
    if (placedGeometry == null) continue;
    if (placedGeometry.visibleCollisionRects.any(
      candidateGeometry.badgeRect.overlaps,
    )) {
      return true;
    }
    if (candidateGeometry.visibleCollisionRects.any(
      placedGeometry.badgeRect.overlaps,
    )) {
      return true;
    }
  }
  return false;
}

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
