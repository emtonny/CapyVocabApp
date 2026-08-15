import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../core/services/gemini_vision_service.dart';
import 'vocab_hand_drawn_jitter.dart';

const int maxVisibleObjects = 12;
const int maxSlotsPerSide = 3;
const double targetPlacementGridCellSize = 40;
const int minimumPlacementGridColumns = 6;
const int minimumPlacementGridRows = 6;
const int labelPlacementLocalSearchRounds = 5;
const int _placementBezierIntersectionSegments = 12;

/// Relative importance of each term in the candidate-placement cost function.
///
/// Label overlap deliberately dominates every other term. Costs are normalized
/// by label area or image diagonal so the same weights work at every canvas
/// size.
class LabelPlacementCostWeights {
  const LabelPlacementCostWeights({
    this.labelOverlap = 1000000,
    this.objectOverlap = 100,
    this.distance = 300,
    this.edgeOverflow = 100,
    this.arrowCollision = 5000,
    this.arrowIntersection = 100000,
    this.busyProximity = 50,
    this.farDistance = 20000,
    this.farDistanceThreshold = 2.5,
  });

  final double labelOverlap;
  final double objectOverlap;
  final double distance;
  final double edgeOverflow;
  final double arrowCollision;
  final double arrowIntersection;
  final double busyProximity;
  final double farDistance;
  final double farDistanceThreshold;
}

enum LabelCandidateDirection {
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  topLeft,
}

enum LabelSide { top, right, bottom, left }

enum LabelSizeTier {
  small(columns: 2, rows: 2),
  medium(columns: 3, rows: 2),
  large(columns: 3, rows: 3),
  extraLarge(columns: 4, rows: 3);

  const LabelSizeTier({required this.columns, required this.rows});

  final int columns;
  final int rows;
}

class GridCell {
  const GridCell(this.column, this.row);

  final int column;
  final int row;

  int index(int gridColumns) => row * gridColumns + column;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.column == column && other.row == row;

  @override
  int get hashCode => Object.hash(column, row);
}

class GridArea {
  const GridArea({
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
  });

  final int column;
  final int row;
  final int columns;
  final int rows;

  double get centerColumn => column + columns / 2;
  double get centerRow => row + rows / 2;

  Set<GridCell> get cells => {
        for (var y = row; y < row + rows; y++)
          for (var x = column; x < column + columns; x++) GridCell(x, y),
      };

  bool containsCell(GridCell cell) =>
      cell.column >= column &&
      cell.column < column + columns &&
      cell.row >= row &&
      cell.row < row + rows;

  bool overlaps(GridArea other) =>
      column < other.column + other.columns &&
      column + columns > other.column &&
      row < other.row + other.rows &&
      row + rows > other.row;
}

class OverlayPlacementGrid {
  OverlayPlacementGrid({
    required this.imageRect,
    double targetCellSize = targetPlacementGridCellSize,
    int minimumColumns = minimumPlacementGridColumns,
    int minimumRows = minimumPlacementGridRows,
  })  : columns = _dynamicGridDimension(
          imageRect.width,
          targetCellSize,
          minimumColumns,
        ),
        rows = _dynamicGridDimension(
          imageRect.height,
          targetCellSize,
          minimumRows,
        );

  const OverlayPlacementGrid.withDimensions({
    required this.imageRect,
    required this.columns,
    required this.rows,
  })  : assert(columns > 0),
        assert(rows > 0);

  final Rect imageRect;
  final int columns;
  final int rows;

  Size get cellSize => Size(imageRect.width / columns, imageRect.height / rows);

  Rect rectForArea(GridArea area) {
    final left = imageRect.left + area.column * cellSize.width;
    final top = imageRect.top + area.row * cellSize.height;
    final right = area.column + area.columns == columns
        ? imageRect.right
        : imageRect.left + (area.column + area.columns) * cellSize.width;
    final bottom = area.row + area.rows == rows
        ? imageRect.bottom
        : imageRect.top + (area.row + area.rows) * cellSize.height;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  GridArea areaForRect(Rect rect) {
    final left = ((rect.left - imageRect.left) / cellSize.width)
        .floor()
        .clamp(0, columns - 1);
    final top = ((rect.top - imageRect.top) / cellSize.height)
        .floor()
        .clamp(0, rows - 1);
    final right = ((rect.right - imageRect.left) / cellSize.width)
        .ceil()
        .clamp(left + 1, columns);
    final bottom = ((rect.bottom - imageRect.top) / cellSize.height)
        .ceil()
        .clamp(top + 1, rows);
    return GridArea(
      column: left,
      row: top,
      columns: right - left,
      rows: bottom - top,
    );
  }

  GridArea areaForObjectRect(Rect rect) {
    var left = ((rect.left - imageRect.left) / cellSize.width - 0.5)
        .ceil()
        .clamp(0, columns - 1);
    var top = ((rect.top - imageRect.top) / cellSize.height - 0.5)
        .ceil()
        .clamp(0, rows - 1);
    var right = ((rect.right - imageRect.left) / cellSize.width - 0.5)
        .floor()
        .clamp(0, columns - 1);
    var bottom = ((rect.bottom - imageRect.top) / cellSize.height - 0.5)
        .floor()
        .clamp(0, rows - 1);
    if (right < left) {
      left = ((rect.center.dx - imageRect.left) / cellSize.width)
          .floor()
          .clamp(0, columns - 1);
      right = left;
    }
    if (bottom < top) {
      top = ((rect.center.dy - imageRect.top) / cellSize.height)
          .floor()
          .clamp(0, rows - 1);
      bottom = top;
    }
    return GridArea(
      column: left,
      row: top,
      columns: right - left + 1,
      rows: bottom - top + 1,
    );
  }
}

int _dynamicGridDimension(
  double extent,
  double targetCellSize,
  int minimum,
) {
  if (!extent.isFinite ||
      extent <= 0 ||
      !targetCellSize.isFinite ||
      targetCellSize <= 0 ||
      minimum <= 0) {
    return math.max(1, minimum);
  }
  return math.max(minimum, (extent / targetCellSize).round());
}

class LabelSlot {
  const LabelSlot({
    required this.id,
    required this.side,
    required this.cardRect,
    required this.anchorPoint,
    this.gridArea,
    this.sizeTier,
  });

  final String id;
  final LabelSide side;
  final Rect cardRect;
  final Offset anchorPoint;
  final GridArea? gridArea;
  final LabelSizeTier? sizeTier;
}

class LabelPlacement {
  const LabelPlacement({
    required this.detection,
    required this.slot,
    required this.objectRect,
  });

  final VocabDetection detection;
  final LabelSlot slot;
  final Rect objectRect;
}

class VocabOverlayLayout {
  const VocabOverlayLayout({
    required this.imageRect,
    required this.slots,
    required this.placements,
    this.grid,
  });

  final Rect imageRect;
  final List<LabelSlot> slots;
  final List<LabelPlacement> placements;
  final OverlayPlacementGrid? grid;
}

class ArrowGeometry {
  const ArrowGeometry({
    required this.start,
    required this.end,
    required this.controlPoint,
    required this.arrowHeadPoints,
  });

  final Offset start;
  final Offset end;
  final Offset controlPoint;
  final List<Offset> arrowHeadPoints;
}

class ContentBusyMap {
  const ContentBusyMap._({
    required this.grid,
    required this.busyCellIndexes,
  });

  factory ContentBusyMap.fromDetections({
    required OverlayPlacementGrid grid,
    required Iterable<VocabDetection> detections,
  }) {
    if (!_hasFinitePositiveRect(grid.imageRect)) {
      return ContentBusyMap._(
        grid: grid,
        busyCellIndexes: {},
      );
    }

    final busyCells = <int>{};
    for (final detection in detections.where(_hasValidNormalizedBox)) {
      final objectRect =
          _LayoutObject.fromDetection(detection, grid.imageRect).rect;
      for (final cell in grid.areaForObjectRect(objectRect).cells) {
        busyCells.add(cell.index(grid.columns));
      }
    }

    return ContentBusyMap._(
      grid: grid,
      busyCellIndexes: Set.unmodifiable(busyCells),
    );
  }

  final OverlayPlacementGrid grid;
  final Set<int> busyCellIndexes;

  Rect get imageRect => grid.imageRect;

  Size get cellSize => grid.cellSize;

  bool isCellBusy(int column, int row) {
    if (column < 0 || column >= grid.columns || row < 0 || row >= grid.rows) {
      return false;
    }
    return busyCellIndexes.contains(row * grid.columns + column);
  }

  bool isBusyAt(Offset point) {
    if (!imageRect.contains(point)) return false;
    final column = ((point.dx - imageRect.left) / cellSize.width)
        .floor()
        .clamp(0, grid.columns - 1);
    final row = ((point.dy - imageRect.top) / cellSize.height)
        .floor()
        .clamp(0, grid.rows - 1);
    return isCellBusy(column, row);
  }

  int busyCellOverlapCount(Rect rect) {
    var count = 0;
    for (final index in busyCellIndexes) {
      final row = index ~/ grid.columns;
      final column = index % grid.columns;
      if (grid
          .rectForArea(
            GridArea(column: column, row: row, columns: 1, rows: 1),
          )
          .overlaps(rect)) {
        count++;
      }
    }
    return count;
  }
}

/// Returns valid detections in deterministic visual-priority order.
///
/// Larger boxes are preferred because they are normally easier for learners
/// to identify. Geometry and text fields provide stable tie-breakers so the
/// result does not depend on the response order from the scan service.
List<VocabDetection> selectVisibleObjects(
  Iterable<VocabDetection> detections,
) {
  final sorted = detections.where(_hasValidNormalizedBox).toList()
    ..sort(_compareByVisualPriority);

  return List.unmodifiable(sorted.take(maxVisibleObjects));
}

Rect calculateContainedImageRect({
  required Size sourceSize,
  required Rect availableRect,
}) {
  if (!sourceSize.width.isFinite ||
      !sourceSize.height.isFinite ||
      sourceSize.isEmpty ||
      !_hasFinitePositiveRect(availableRect)) {
    return Rect.zero;
  }

  final scale = math.min(
    availableRect.width / sourceSize.width,
    availableRect.height / sourceSize.height,
  );
  final displayedSize = Size(
    sourceSize.width * scale,
    sourceSize.height * scale,
  );
  return Rect.fromCenter(
    center: availableRect.center,
    width: displayedSize.width,
    height: displayedSize.height,
  );
}

VocabOverlayLayout buildVocabOverlayLayout({
  required Size overlaySize,
  required Size sourceImageSize,
  required Size cardSize,
  required Iterable<VocabDetection> detections,
  Size Function(VocabDetection detection)? cardSizeForDetection,
  LabelSizeTier Function(
    VocabDetection detection,
    OverlayPlacementGrid grid,
  )? labelTierForDetection,
  Iterable<VocabDetection>? busyMapDetections,
  double safeMargin = 12,
  double slotGap = 8,
  double labelJitterScale = 0,
}) {
  final overlayRect = Offset.zero & overlaySize;
  if (!_hasFinitePositiveRect(overlayRect) ||
      !cardSize.width.isFinite ||
      !cardSize.height.isFinite ||
      cardSize.isEmpty ||
      safeMargin < 0 ||
      slotGap < 0) {
    return const VocabOverlayLayout(
      imageRect: Rect.zero,
      slots: [],
      placements: [],
    );
  }

  final imageRect = calculateContainedImageRect(
    sourceSize: sourceImageSize,
    availableRect: overlayRect,
  );
  final grid = OverlayPlacementGrid(imageRect: imageRect);
  final gridPlacements = assignObjectsToGrid(
    detections: detections,
    grid: grid,
    measuredSizeForDetection: cardSizeForDetection ?? (_) => cardSize,
    tierForDetection: labelTierForDetection,
    obstacleDetections: busyMapDetections ?? detections,
  );
  final placements = labelJitterScale > 0
      ? applyGridLabelJitter(
          placements: gridPlacements,
          grid: grid,
          geometryScale: labelJitterScale,
        )
      : gridPlacements;

  return VocabOverlayLayout(
    imageRect: imageRect,
    slots: List.unmodifiable(placements.map((placement) => placement.slot)),
    placements: placements,
    grid: grid,
  );
}

LabelSizeTier selectLabelSizeTier({
  required Size measuredSize,
  required OverlayPlacementGrid grid,
}) {
  if (!measuredSize.width.isFinite ||
      !measuredSize.height.isFinite ||
      measuredSize.isEmpty) {
    return LabelSizeTier.small;
  }
  for (final tier in LabelSizeTier.values) {
    if (measuredSize.width <= tier.columns * grid.cellSize.width &&
        measuredSize.height <= tier.rows * grid.cellSize.height) {
      return tier;
    }
  }
  return LabelSizeTier.extraLarge;
}

List<LabelPlacement> assignObjectsToGrid({
  required Iterable<VocabDetection> detections,
  required OverlayPlacementGrid grid,
  required Size Function(VocabDetection detection) measuredSizeForDetection,
  LabelSizeTier Function(
    VocabDetection detection,
    OverlayPlacementGrid grid,
  )? tierForDetection,
  Iterable<VocabDetection>? obstacleDetections,
  int localSearchRounds = labelPlacementLocalSearchRounds,
  LabelPlacementCostWeights weights = const LabelPlacementCostWeights(),
  bool hardFilterObjectOverlaps = false,
}) {
  if (!_hasFinitePositiveRect(grid.imageRect) ||
      grid.columns < LabelSizeTier.extraLarge.columns ||
      grid.rows < LabelSizeTier.extraLarge.rows ||
      localSearchRounds < 0) {
    return const [];
  }
  final objects = selectVisibleObjects(detections)
      .map((detection) => _GridObject(
            detection: detection,
            pixelRect: _LayoutObject.fromDetection(
              detection,
              grid.imageRect,
            ).rect,
            area: grid.areaForObjectRect(
              _LayoutObject.fromDetection(detection, grid.imageRect).rect,
            ),
          ))
      .toList(growable: false);
  final obstacleObjects = (obstacleDetections ?? detections)
      .where(_hasValidNormalizedBox)
      .map((detection) {
    final rect = _LayoutObject.fromDetection(detection, grid.imageRect).rect;
    return _GridObject(
      detection: detection,
      pixelRect: rect,
      area: grid.areaForObjectRect(rect),
    );
  }).toList(growable: false);
  final candidateSets = <_GridObject, List<LabelSlot>>{};
  for (var index = 0; index < objects.length; index++) {
    final object = objects[index];
    final tier = tierForDetection?.call(object.detection, grid) ??
        selectLabelSizeTier(
          measuredSize: measuredSizeForDetection(object.detection),
          grid: grid,
        );
    final primaryCandidates = generateGridLabelCandidates(
      objectArea: object.area,
      tier: tier,
      grid: grid,
      idPrefix: 'object-$index',
    );
    final candidates = <LabelSlot>[
      ...primaryCandidates,
      ..._gridFallbackCandidates(
        objectArea: object.area,
        tier: tier,
        grid: grid,
        idPrefix: 'object-$index',
        excludedAreas:
            primaryCandidates.map((candidate) => candidate.gridArea!),
      ),
    ];
    candidateSets[object] = hardFilterObjectOverlaps
        ? candidates.where((candidate) {
            final area = candidate.gridArea!;
            return !obstacleObjects.any(
              (obstacle) => area.overlaps(obstacle.area),
            );
          }).toList(growable: false)
        : candidates;
  }

  final assignments = <_GridObject, LabelSlot>{};
  for (final object in objects) {
    final candidates = candidateSets[object] ?? const [];
    final available = candidates.where((candidate) {
      final area = candidate.gridArea!;
      return !assignments.values.any(
        (assigned) => area.overlaps(assigned.gridArea!),
      );
    }).toList(growable: false);
    if (available.isEmpty) {
      _repairGridAssignment(
        object: object,
        candidates: candidates,
        assignments: assignments,
        candidateSets: candidateSets,
        obstacles: obstacleObjects,
        grid: grid,
        weights: weights,
      );
      continue;
    }
    assignments[object] = _lowestGridCostCandidate(
      object: object,
      candidates: available,
      assignments: assignments,
      obstacles: obstacleObjects,
      grid: grid,
      weights: weights,
    );
  }

  var globalCost = _globalGridCost(
    assignments: assignments,
    obstacles: obstacleObjects,
    grid: grid,
    weights: weights,
  );
  for (var round = 0; round < localSearchRounds; round++) {
    var improved = false;
    for (final object in objects) {
      final current = assignments[object];
      final candidates = candidateSets[object];
      if (current == null || candidates == null) continue;
      var best = current;
      var bestCost = globalCost;
      for (final candidate in candidates) {
        if (candidate.id == current.id ||
            assignments.entries.any(
              (entry) =>
                  entry.key != object &&
                  candidate.gridArea!.overlaps(entry.value.gridArea!),
            )) {
          continue;
        }
        assignments[object] = candidate;
        final cost = _globalGridCost(
          assignments: assignments,
          obstacles: obstacleObjects,
          grid: grid,
          weights: weights,
        );
        if (cost < bestCost) {
          best = candidate;
          bestCost = cost;
        }
      }
      assignments[object] = best;
      if (best.id != current.id) {
        globalCost = bestCost;
        improved = true;
      }
    }
    if (!improved) break;
  }

  return List.unmodifiable([
    for (final object in objects)
      if (assignments[object] case final slot?)
        LabelPlacement(
          detection: object.detection,
          slot: slot,
          objectRect: object.pixelRect,
        ),
  ]);
}

bool _repairGridAssignment({
  required _GridObject object,
  required List<LabelSlot> candidates,
  required Map<_GridObject, LabelSlot> assignments,
  required Map<_GridObject, List<LabelSlot>> candidateSets,
  required List<_GridObject> obstacles,
  required OverlayPlacementGrid grid,
  required LabelPlacementCostWeights weights,
}) {
  for (final candidate in candidates) {
    final blockers = assignments.entries
        .where(
          (entry) => candidate.gridArea!.overlaps(entry.value.gridArea!),
        )
        .toList(growable: false);
    if (blockers.isEmpty || blockers.length > 2) continue;
    final tentative = Map<_GridObject, LabelSlot>.of(assignments);
    for (final blocker in blockers) {
      tentative.remove(blocker.key);
    }
    tentative[object] = candidate;
    var repaired = true;
    for (final blocker in blockers) {
      final alternatives = (candidateSets[blocker.key] ?? const [])
          .where(
            (alternative) => !tentative.values.any(
              (assigned) => alternative.gridArea!.overlaps(assigned.gridArea!),
            ),
          )
          .toList(growable: false);
      if (alternatives.isEmpty) {
        repaired = false;
        break;
      }
      tentative[blocker.key] = _lowestGridCostCandidate(
        object: blocker.key,
        candidates: alternatives,
        assignments: tentative,
        obstacles: obstacles,
        grid: grid,
        weights: weights,
      );
    }
    if (repaired) {
      assignments
        ..clear()
        ..addAll(tentative);
      return true;
    }
  }
  return false;
}

List<LabelSlot> generateGridLabelCandidates({
  required GridArea objectArea,
  required LabelSizeTier tier,
  required OverlayPlacementGrid grid,
  String idPrefix = 'candidate',
}) {
  const gap = 1;
  final centeredColumn = (objectArea.centerColumn - tier.columns / 2).floor();
  final centeredRow = (objectArea.centerRow - tier.rows / 2).floor();
  final above = objectArea.row - gap - tier.rows;
  final below = objectArea.row + objectArea.rows + gap;
  final left = objectArea.column - gap - tier.columns;
  final right = objectArea.column + objectArea.columns + gap;
  final positions = <LabelCandidateDirection, (int, int)>{
    LabelCandidateDirection.top: (centeredColumn, above),
    LabelCandidateDirection.topRight: (right, above),
    LabelCandidateDirection.right: (right, centeredRow),
    LabelCandidateDirection.bottomRight: (right, below),
    LabelCandidateDirection.bottom: (centeredColumn, below),
    LabelCandidateDirection.bottomLeft: (left, below),
    LabelCandidateDirection.left: (left, centeredRow),
    LabelCandidateDirection.topLeft: (left, above),
  };
  final seen = <(int, int)>{};
  final candidates = <LabelSlot>[];
  for (final direction in LabelCandidateDirection.values) {
    final position = positions[direction]!;
    final column = position.$1.clamp(0, grid.columns - tier.columns);
    final row = position.$2.clamp(0, grid.rows - tier.rows);
    if (!seen.add((column, row))) continue;
    final area = GridArea(
      column: column,
      row: row,
      columns: tier.columns,
      rows: tier.rows,
    );
    final side = _sideForDirection(direction);
    candidates.add(
      _gridSlot(
        id: '$idPrefix-${direction.name}',
        side: side,
        area: area,
        tier: tier,
        grid: grid,
      ),
    );
  }
  return List.unmodifiable(candidates);
}

List<LabelSlot> _gridFallbackCandidates({
  required GridArea objectArea,
  required LabelSizeTier tier,
  required OverlayPlacementGrid grid,
  required String idPrefix,
  required Iterable<GridArea> excludedAreas,
}) {
  final excluded = {
    for (final area in excludedAreas) (area.column, area.row),
  };
  final candidates = <LabelSlot>[];
  for (var row = 0; row <= grid.rows - tier.rows; row++) {
    for (var column = 0; column <= grid.columns - tier.columns; column++) {
      if (excluded.contains((column, row))) continue;
      final area = GridArea(
        column: column,
        row: row,
        columns: tier.columns,
        rows: tier.rows,
      );
      final horizontalDelta = area.centerColumn - objectArea.centerColumn;
      final verticalDelta = area.centerRow - objectArea.centerRow;
      final side = horizontalDelta.abs() >= verticalDelta.abs()
          ? (horizontalDelta >= 0 ? LabelSide.right : LabelSide.left)
          : (verticalDelta >= 0 ? LabelSide.bottom : LabelSide.top);
      candidates.add(
        _gridSlot(
          id: '$idPrefix-grid-$column-$row',
          side: side,
          area: area,
          tier: tier,
          grid: grid,
        ),
      );
    }
  }
  candidates.sort((a, b) {
    final aDistance =
        (a.gridArea!.centerColumn - objectArea.centerColumn).abs() +
            (a.gridArea!.centerRow - objectArea.centerRow).abs();
    final bDistance =
        (b.gridArea!.centerColumn - objectArea.centerColumn).abs() +
            (b.gridArea!.centerRow - objectArea.centerRow).abs();
    final byDistance = aDistance.compareTo(bDistance);
    return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
  });
  return candidates;
}

List<LabelPlacement> applyGridLabelJitter({
  required Iterable<LabelPlacement> placements,
  required OverlayPlacementGrid grid,
  required double geometryScale,
}) {
  if (!geometryScale.isFinite || geometryScale <= 0) {
    return List.unmodifiable(placements);
  }
  final visualInset = math.min(grid.cellSize.width, grid.cellSize.height) * 0.1;
  return List.unmodifiable([
    for (final placement in placements)
      if (placement.slot.gridArea case final area?)
        () {
          final footprint = grid.rectForArea(area);
          final baseRect = footprint.deflate(visualInset);
          final jitter = VocabHandDrawnJitter.forWord(
                placement.detection.word,
              ).positionOffset *
              geometryScale;
          final visualRect = _moveRectInside(baseRect.shift(jitter), footprint);
          return LabelPlacement(
            detection: placement.detection,
            objectRect: placement.objectRect,
            slot: LabelSlot(
              id: placement.slot.id,
              side: placement.slot.side,
              cardRect: visualRect,
              anchorPoint: _rectBoundaryPointToward(
                visualRect,
                placement.objectRect.center,
              ),
              gridArea: area,
              sizeTier: placement.slot.sizeTier,
            ),
          );
        }()
      else
        placement,
  ]);
}

LabelSlot _gridSlot({
  required String id,
  required LabelSide side,
  required GridArea area,
  required LabelSizeTier tier,
  required OverlayPlacementGrid grid,
}) {
  final rect = grid.rectForArea(area);
  return LabelSlot(
    id: id,
    side: side,
    cardRect: rect,
    anchorPoint: switch (side) {
      LabelSide.top => rect.bottomCenter,
      LabelSide.right => rect.centerLeft,
      LabelSide.bottom => rect.topCenter,
      LabelSide.left => rect.centerRight,
    },
    gridArea: area,
    sizeTier: tier,
  );
}

LabelSide _sideForDirection(LabelCandidateDirection direction) =>
    switch (direction) {
      LabelCandidateDirection.top ||
      LabelCandidateDirection.topRight =>
        LabelSide.top,
      LabelCandidateDirection.right ||
      LabelCandidateDirection.bottomRight =>
        LabelSide.right,
      LabelCandidateDirection.bottom ||
      LabelCandidateDirection.bottomLeft =>
        LabelSide.bottom,
      LabelCandidateDirection.left ||
      LabelCandidateDirection.topLeft =>
        LabelSide.left,
    };

LabelSlot _lowestGridCostCandidate({
  required _GridObject object,
  required List<LabelSlot> candidates,
  required Map<_GridObject, LabelSlot> assignments,
  required List<_GridObject> obstacles,
  required OverlayPlacementGrid grid,
  required LabelPlacementCostWeights weights,
}) {
  var best = candidates.first;
  var bestCost = double.infinity;
  for (final candidate in candidates) {
    final cost = _gridCandidateCost(
          object: object,
          candidate: candidate,
          otherLabels: assignments.values,
          obstacles: obstacles,
          grid: grid,
          weights: weights,
        ) +
        _candidateArrowIntersectionCount(
              object: object,
              candidate: candidate,
              assignments: assignments,
              grid: grid,
            ) *
            weights.arrowIntersection;
    if (cost < bestCost) {
      best = candidate;
      bestCost = cost;
    }
  }
  return best;
}

double _globalGridCost({
  required Map<_GridObject, LabelSlot> assignments,
  required List<_GridObject> obstacles,
  required OverlayPlacementGrid grid,
  required LabelPlacementCostWeights weights,
}) {
  var cost = 0.0;
  final entries = assignments.entries.toList(growable: false);
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    cost += _gridCandidateCost(
      object: entry.key,
      candidate: entry.value,
      otherLabels: const [],
      obstacles: obstacles,
      grid: grid,
      weights: weights,
    );
    for (var other = index + 1; other < entries.length; other++) {
      cost += weights.labelOverlap *
          _cellOverlapCount(
            entry.value.gridArea!,
            entries[other].value.gridArea!,
          );
    }
    final arrowCells = _lineCells(
      entry.value.gridArea!.centerColumn,
      entry.value.gridArea!.centerRow,
      entry.key.area.centerColumn,
      entry.key.area.centerRow,
      grid,
    );
    for (var other = 0; other < entries.length; other++) {
      if (other == index) continue;
      if (arrowCells.any(entries[other].value.gridArea!.containsCell)) {
        cost += weights.arrowCollision;
      }
    }
  }
  cost += _gridArrowIntersectionCount(assignments, grid) *
      weights.arrowIntersection;
  return cost;
}

double _gridCandidateCost({
  required _GridObject object,
  required LabelSlot candidate,
  required Iterable<LabelSlot> otherLabels,
  required List<_GridObject> obstacles,
  required OverlayPlacementGrid grid,
  required LabelPlacementCostWeights weights,
}) {
  final area = candidate.gridArea!;
  final arrowCells = _lineCells(
    area.centerColumn,
    area.centerRow,
    object.area.centerColumn,
    object.area.centerRow,
    grid,
  );
  var labelOverlap = 0;
  var objectOverlap = 0;
  var arrowCollisions = 0;
  for (final label in otherLabels) {
    labelOverlap += _cellOverlapCount(area, label.gridArea!);
    if (arrowCells.any(label.gridArea!.containsCell)) arrowCollisions++;
  }
  for (final obstacle in obstacles) {
    if (identical(obstacle.detection, object.detection)) continue;
    objectOverlap += _cellOverlapCount(area, obstacle.area);
    if (arrowCells.any(obstacle.area.containsCell)) arrowCollisions++;
  }
  final busyProximity = _busyProximityCellCount(
    area: area,
    object: object,
    obstacles: obstacles,
    grid: grid,
  );
  final distance = (area.centerColumn - object.area.centerColumn).abs() +
      (area.centerRow - object.area.centerRow).abs();
  final distanceRatio = boundaryDistanceRatio(
    labelRect: candidate.cardRect,
    objectRect: object.pixelRect,
  );
  final farDistanceExcess = math.max(
    0,
    distanceRatio - weights.farDistanceThreshold,
  );
  final edgePenalty = math.min(
            area.column,
            grid.columns - area.column - area.columns,
          ) ==
          0
      ? 1
      : 0;
  final verticalEdgePenalty =
      math.min(area.row, grid.rows - area.row - area.rows) == 0 ? 1 : 0;
  return labelOverlap * weights.labelOverlap +
      objectOverlap * weights.objectOverlap +
      distance * weights.distance +
      (edgePenalty + verticalEdgePenalty) * weights.edgeOverflow +
      arrowCollisions * weights.arrowCollision +
      busyProximity * weights.busyProximity +
      farDistanceExcess * farDistanceExcess * weights.farDistance;
}

int _busyProximityCellCount({
  required GridArea area,
  required _GridObject object,
  required List<_GridObject> obstacles,
  required OverlayPlacementGrid grid,
}) {
  final halo = GridArea(
    column: math.max(0, area.column - 1),
    row: math.max(0, area.row - 1),
    columns: math.min(grid.columns, area.column + area.columns + 1) -
        math.max(0, area.column - 1),
    rows: math.min(grid.rows, area.row + area.rows + 1) -
        math.max(0, area.row - 1),
  );
  final busyCells = <GridCell>{};
  for (final obstacle in obstacles) {
    if (identical(obstacle.detection, object.detection)) continue;
    busyCells.addAll(obstacle.area.cells.where(halo.containsCell));
  }
  return busyCells.length;
}

double boundaryDistanceRatio({
  required Rect labelRect,
  required Rect objectRect,
}) {
  if (!_hasFinitePositiveRect(labelRect) ||
      !_hasFinitePositiveRect(objectRect)) {
    return double.infinity;
  }
  final horizontalGap = math.max(
    0,
    math.max(
        objectRect.left - labelRect.right, labelRect.left - objectRect.right),
  );
  final verticalGap = math.max(
    0,
    math.max(
        objectRect.top - labelRect.bottom, labelRect.top - objectRect.bottom),
  );
  final boundaryDistance = math.sqrt(
    horizontalGap * horizontalGap + verticalGap * verticalGap,
  );
  final objectDiagonal = math.sqrt(
    objectRect.width * objectRect.width + objectRect.height * objectRect.height,
  );
  return objectDiagonal == 0
      ? double.infinity
      : boundaryDistance / objectDiagonal;
}

int _gridArrowIntersectionCount(
  Map<_GridObject, LabelSlot> assignments,
  OverlayPlacementGrid grid,
) {
  final entries = assignments.entries.toList(growable: false);
  final geometries = <ArrowGeometry>[
    for (final entry in entries)
      calculateArrowGeometry(
        placement: LabelPlacement(
          detection: entry.key.detection,
          slot: entry.value,
          objectRect: entry.key.pixelRect,
        ),
        imageCenter: grid.imageRect.center,
        obstacles: [
          for (final other in entries)
            if (other.key != entry.key) ...[
              other.value.cardRect,
              other.key.pixelRect,
            ],
        ],
        routingBounds: grid.imageRect,
      ),
  ];
  var intersections = 0;
  for (var first = 0; first < geometries.length; first++) {
    for (var second = first + 1; second < geometries.length; second++) {
      if (quadraticBeziersIntersect(
        geometries[first],
        geometries[second],
        segments: _placementBezierIntersectionSegments,
      )) {
        intersections++;
      }
    }
  }
  return intersections;
}

int _candidateArrowIntersectionCount({
  required _GridObject object,
  required LabelSlot candidate,
  required Map<_GridObject, LabelSlot> assignments,
  required OverlayPlacementGrid grid,
}) {
  final tentative = Map<_GridObject, LabelSlot>.of(assignments)
    ..remove(object)
    ..[object] = candidate;
  final entries = tentative.entries.toList(growable: false);
  final candidateEntry = entries.singleWhere((entry) => entry.key == object);
  final candidateGeometry = _gridArrowGeometry(
    entry: candidateEntry,
    entries: entries,
    grid: grid,
  );
  var intersections = 0;
  for (final other in entries) {
    if (other.key == object) continue;
    if (quadraticBeziersIntersect(
      candidateGeometry,
      _gridArrowGeometry(entry: other, entries: entries, grid: grid),
      segments: _placementBezierIntersectionSegments,
    )) {
      intersections++;
    }
  }
  return intersections;
}

ArrowGeometry _gridArrowGeometry({
  required MapEntry<_GridObject, LabelSlot> entry,
  required List<MapEntry<_GridObject, LabelSlot>> entries,
  required OverlayPlacementGrid grid,
}) =>
    calculateArrowGeometry(
      placement: LabelPlacement(
        detection: entry.key.detection,
        slot: entry.value,
        objectRect: entry.key.pixelRect,
      ),
      imageCenter: grid.imageRect.center,
      obstacles: [
        for (final other in entries)
          if (other.key != entry.key) ...[
            other.value.cardRect,
            other.key.pixelRect,
          ],
      ],
      routingBounds: grid.imageRect,
    );

int _cellOverlapCount(GridArea first, GridArea second) {
  final overlapWidth =
      math.min(first.column + first.columns, second.column + second.columns) -
          math.max(first.column, second.column);
  final overlapHeight =
      math.min(first.row + first.rows, second.row + second.rows) -
          math.max(first.row, second.row);
  final width = overlapWidth > 0 ? overlapWidth : 0;
  final height = overlapHeight > 0 ? overlapHeight : 0;
  return (width * height).toInt();
}

Set<GridCell> _lineCells(
  double startColumn,
  double startRow,
  double endColumn,
  double endRow,
  OverlayPlacementGrid grid,
) {
  final steps = math.max(
    ((endColumn - startColumn).abs() * 4).ceil(),
    ((endRow - startRow).abs() * 4).ceil(),
  );
  if (steps == 0) return const {};
  return {
    for (var step = 1; step < steps; step++)
      GridCell(
        (startColumn + (endColumn - startColumn) * step / steps)
            .floor()
            .clamp(0, grid.columns - 1),
        (startRow + (endRow - startRow) * step / steps)
            .floor()
            .clamp(0, grid.rows - 1),
      ),
  };
}

class _GridObject {
  const _GridObject({
    required this.detection,
    required this.pixelRect,
    required this.area,
  });

  final VocabDetection detection;
  final Rect pixelRect;
  final GridArea area;
}

/// Places each label using eight object-relative candidates and a weighted
/// geometry-only cost function, then improves the greedy result locally.
///
/// No pixels or model output beyond the supplied Gemini bounding boxes are
/// inspected. Objects are always processed by descending box area.
List<LabelPlacement> assignObjectsToCandidates({
  required Iterable<VocabDetection> detections,
  required Rect imageRect,
  required Size Function(VocabDetection detection) cardSizeForDetection,
  Iterable<VocabDetection>? obstacleDetections,
  double safeMargin = 12,
  double objectGap = 8,
  int localSearchRounds = labelPlacementLocalSearchRounds,
  LabelPlacementCostWeights weights = const LabelPlacementCostWeights(),
  Offset Function(VocabDetection detection)? candidateOffsetForDetection,
}) {
  if (!_hasFinitePositiveRect(imageRect) ||
      !safeMargin.isFinite ||
      safeMargin < 0 ||
      !objectGap.isFinite ||
      objectGap < 0 ||
      localSearchRounds < 0) {
    return const [];
  }

  final objects = selectVisibleObjects(detections)
      .map((detection) => _LayoutObject.fromDetection(detection, imageRect))
      .toList(growable: false);
  if (objects.isEmpty) return const [];

  final obstacles = (obstacleDetections ?? detections)
      .where(_hasValidNormalizedBox)
      .map((detection) => _LayoutObject.fromDetection(detection, imageRect))
      .toList(growable: false);
  final safeBounds = imageRect.deflate(safeMargin);
  final candidateSets = <_LayoutObject, List<LabelSlot>>{};
  for (var index = 0; index < objects.length; index++) {
    final object = objects[index];
    final requestedSize = cardSizeForDetection(object.detection);
    if (!requestedSize.width.isFinite ||
        !requestedSize.height.isFinite ||
        requestedSize.isEmpty) {
      continue;
    }
    final size = Size(
      math.min(requestedSize.width, imageRect.width),
      math.min(requestedSize.height, imageRect.height),
    );
    final rawCandidates = generateObjectLabelCandidates(
      objectRect: object.rect,
      cardSize: size,
      objectGap: objectGap,
      idPrefix: 'object-$index',
    );
    final requestedOffset = candidateOffsetForDetection?.call(object.detection);
    final candidateOffset = requestedOffset != null &&
            requestedOffset.dx.isFinite &&
            requestedOffset.dy.isFinite
        ? requestedOffset
        : Offset.zero;
    candidateSets[object] = List.unmodifiable([
      for (final candidate in rawCandidates)
        _fitCandidateWithin(
          _shiftCandidate(candidate, candidateOffset),
          safeBounds,
          object.rect.center,
        ),
    ]);
  }

  final assignments = <_LayoutObject, LabelSlot>{};
  for (final object in objects) {
    final candidates = candidateSets[object];
    if (candidates == null || candidates.isEmpty) continue;
    final overlapFree = candidates
        .where(
          (candidate) => !assignments.values.any(
            (assigned) => candidate.cardRect.overlaps(assigned.cardRect),
          ),
        )
        .toList(growable: false);
    final available = overlapFree.isEmpty ? candidates : overlapFree;
    assignments[object] = _lowestCostCandidate(
      object: object,
      candidates: available,
      assignments: assignments,
      obstacles: obstacles,
      imageRect: imageRect,
      safeBounds: safeBounds,
      weights: weights,
    );
  }

  var globalCost = _globalPlacementCost(
    assignments: assignments,
    obstacles: obstacles,
    imageRect: imageRect,
    safeBounds: safeBounds,
    weights: weights,
  );
  for (var round = 0; round < localSearchRounds; round++) {
    var improved = false;
    for (final object in objects) {
      final current = assignments[object];
      final candidates = candidateSets[object];
      if (current == null || candidates == null) continue;

      var best = current;
      var bestCost = globalCost;
      for (final candidate in candidates) {
        if (candidate.id == current.id) continue;
        assignments[object] = candidate;
        final candidateCost = _globalPlacementCost(
          assignments: assignments,
          obstacles: obstacles,
          imageRect: imageRect,
          safeBounds: safeBounds,
          weights: weights,
        );
        if (candidateCost < bestCost - 0.000001) {
          best = candidate;
          bestCost = candidateCost;
        }
      }
      assignments[object] = best;
      if (best.id != current.id) {
        globalCost = bestCost;
        improved = true;
      }
    }
    if (!improved) break;
  }

  return List.unmodifiable([
    for (final object in objects)
      if (assignments[object] case final slot?)
        LabelPlacement(
          detection: object.detection,
          slot: slot,
          objectRect: object.rect,
        ),
  ]);
}

LabelSlot _shiftCandidate(LabelSlot candidate, Offset offset) {
  if (offset == Offset.zero) return candidate;
  return LabelSlot(
    id: candidate.id,
    side: candidate.side,
    cardRect: candidate.cardRect.shift(offset),
    anchorPoint: candidate.anchorPoint + offset,
  );
}

/// Evaluates a complete placement with the same global cost used by local
/// search. This is exposed for deterministic regression tests and diagnostics.
double calculateCandidatePlacementCost({
  required Iterable<LabelPlacement> placements,
  required Rect imageRect,
  required Iterable<VocabDetection> obstacleDetections,
  double safeMargin = 12,
  LabelPlacementCostWeights weights = const LabelPlacementCostWeights(),
}) {
  if (!_hasFinitePositiveRect(imageRect) || safeMargin < 0) {
    return double.infinity;
  }
  final assignments = <_LayoutObject, LabelSlot>{};
  for (final placement in placements) {
    final center = placement.objectRect.center;
    final delta = center - imageRect.center;
    assignments[_LayoutObject(
      detection: placement.detection,
      rect: placement.objectRect,
      center: center,
      angle: math.atan2(delta.dy, delta.dx),
    )] = placement.slot;
  }
  final obstacles = obstacleDetections
      .where(_hasValidNormalizedBox)
      .map((detection) => _LayoutObject.fromDetection(detection, imageRect))
      .toList(growable: false);
  return _globalPlacementCost(
    assignments: assignments,
    obstacles: obstacles,
    imageRect: imageRect,
    safeBounds: imageRect.deflate(safeMargin),
    weights: weights,
  );
}

LabelSlot _fitCandidateWithin(
  LabelSlot candidate,
  Rect safeBounds,
  Offset objectCenter,
) {
  if (!_hasFinitePositiveRect(safeBounds) ||
      candidate.cardRect.width > safeBounds.width ||
      candidate.cardRect.height > safeBounds.height) {
    return candidate;
  }
  final fittedRect = _moveRectInside(candidate.cardRect, safeBounds);
  return LabelSlot(
    id: candidate.id,
    side: candidate.side,
    cardRect: fittedRect,
    anchorPoint: _rectBoundaryPointToward(fittedRect, objectCenter),
  );
}

/// Creates the eight compass candidates at a fixed gap from [objectRect].
List<LabelSlot> generateObjectLabelCandidates({
  required Rect objectRect,
  required Size cardSize,
  double objectGap = 8,
  String idPrefix = 'candidate',
}) {
  if (!_hasFinitePositiveRect(objectRect) ||
      !cardSize.width.isFinite ||
      !cardSize.height.isFinite ||
      cardSize.isEmpty ||
      !objectGap.isFinite ||
      objectGap < 0) {
    return const [];
  }

  final centeredLeft = objectRect.center.dx - cardSize.width / 2;
  final centeredTop = objectRect.center.dy - cardSize.height / 2;
  final above = objectRect.top - objectGap - cardSize.height;
  final below = objectRect.bottom + objectGap;
  final left = objectRect.left - objectGap - cardSize.width;
  final right = objectRect.right + objectGap;
  final rects = <LabelCandidateDirection, Rect>{
    LabelCandidateDirection.top:
        Rect.fromLTWH(centeredLeft, above, cardSize.width, cardSize.height),
    LabelCandidateDirection.topRight:
        Rect.fromLTWH(right, above, cardSize.width, cardSize.height),
    LabelCandidateDirection.right:
        Rect.fromLTWH(right, centeredTop, cardSize.width, cardSize.height),
    LabelCandidateDirection.bottomRight:
        Rect.fromLTWH(right, below, cardSize.width, cardSize.height),
    LabelCandidateDirection.bottom:
        Rect.fromLTWH(centeredLeft, below, cardSize.width, cardSize.height),
    LabelCandidateDirection.bottomLeft:
        Rect.fromLTWH(left, below, cardSize.width, cardSize.height),
    LabelCandidateDirection.left:
        Rect.fromLTWH(left, centeredTop, cardSize.width, cardSize.height),
    LabelCandidateDirection.topLeft:
        Rect.fromLTWH(left, above, cardSize.width, cardSize.height),
  };

  return List.unmodifiable([
    for (final direction in LabelCandidateDirection.values)
      LabelSlot(
        id: '$idPrefix-${direction.name}',
        side: switch (direction) {
          LabelCandidateDirection.top ||
          LabelCandidateDirection.topRight =>
            LabelSide.top,
          LabelCandidateDirection.right ||
          LabelCandidateDirection.bottomRight =>
            LabelSide.right,
          LabelCandidateDirection.bottom ||
          LabelCandidateDirection.bottomLeft =>
            LabelSide.bottom,
          LabelCandidateDirection.left ||
          LabelCandidateDirection.topLeft =>
            LabelSide.left,
        },
        cardRect: rects[direction]!,
        anchorPoint: _rectBoundaryPointToward(
          rects[direction]!,
          objectRect.center,
        ),
      ),
  ]);
}

LabelSlot _lowestCostCandidate({
  required _LayoutObject object,
  required List<LabelSlot> candidates,
  required Map<_LayoutObject, LabelSlot> assignments,
  required List<_LayoutObject> obstacles,
  required Rect imageRect,
  required Rect safeBounds,
  required LabelPlacementCostWeights weights,
}) {
  var best = candidates.first;
  var bestCost = double.infinity;
  for (final candidate in candidates) {
    final cost = _candidatePlacementCost(
      object: object,
      candidate: candidate,
      otherLabels: assignments.values,
      obstacles: obstacles,
      imageRect: imageRect,
      safeBounds: safeBounds,
      weights: weights,
    );
    if (cost < bestCost) {
      best = candidate;
      bestCost = cost;
    }
  }
  return best;
}

double _globalPlacementCost({
  required Map<_LayoutObject, LabelSlot> assignments,
  required List<_LayoutObject> obstacles,
  required Rect imageRect,
  required Rect safeBounds,
  required LabelPlacementCostWeights weights,
}) {
  var cost = 0.0;
  final entries = assignments.entries.toList(growable: false);
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    cost += _candidatePlacementCost(
      object: entry.key,
      candidate: entry.value,
      otherLabels: const [],
      obstacles: obstacles,
      imageRect: imageRect,
      safeBounds: safeBounds,
      weights: weights,
    );
    for (var otherIndex = index + 1;
        otherIndex < entries.length;
        otherIndex++) {
      cost += weights.labelOverlap *
          _normalizedOverlap(
            entry.value.cardRect,
            entries[otherIndex].value.cardRect,
          );
    }
    final arrowEnd = _rectBoundaryPointToward(
      entry.key.rect,
      entry.value.anchorPoint,
    );
    for (var otherIndex = 0; otherIndex < entries.length; otherIndex++) {
      if (otherIndex == index) continue;
      if (segmentIntersectsRect(
        entry.value.anchorPoint,
        arrowEnd,
        entries[otherIndex].value.cardRect,
      )) {
        cost += weights.arrowCollision;
      }
    }
  }
  return cost;
}

double _candidatePlacementCost({
  required _LayoutObject object,
  required LabelSlot candidate,
  required Iterable<LabelSlot> otherLabels,
  required List<_LayoutObject> obstacles,
  required Rect imageRect,
  required Rect safeBounds,
  required LabelPlacementCostWeights weights,
}) {
  final cardRect = candidate.cardRect;
  final area = cardRect.width * cardRect.height;
  final imageDiagonal = math.sqrt(
    imageRect.width * imageRect.width + imageRect.height * imageRect.height,
  );
  var labelOverlap = 0.0;
  var objectOverlap = 0.0;
  var arrowCrossings = 0;
  final arrowEnd = _rectBoundaryPointToward(object.rect, candidate.anchorPoint);
  for (final label in otherLabels) {
    labelOverlap += _normalizedOverlap(cardRect, label.cardRect);
    if (segmentIntersectsRect(
      candidate.anchorPoint,
      arrowEnd,
      label.cardRect,
    )) {
      arrowCrossings++;
    }
  }
  for (final obstacle in obstacles) {
    if (identical(obstacle.detection, object.detection)) continue;
    objectOverlap += _intersectionArea(cardRect, obstacle.rect) / area;
    if (segmentIntersectsRect(
      candidate.anchorPoint,
      arrowEnd,
      obstacle.rect,
    )) {
      arrowCrossings++;
    }
  }
  final safeArea = _intersectionArea(cardRect, safeBounds);
  final overflowRatio = 1 - safeArea / area;
  final distance = (candidate.anchorPoint - object.center).distance /
      math.max(imageDiagonal, 1);

  return labelOverlap * weights.labelOverlap +
      objectOverlap * weights.objectOverlap +
      distance * weights.distance +
      overflowRatio * weights.edgeOverflow +
      arrowCrossings * weights.arrowCollision;
}

double _normalizedOverlap(Rect first, Rect second) {
  final denominator = math.min(
    first.width * first.height,
    second.width * second.height,
  );
  return denominator <= 0 ? 0 : _intersectionArea(first, second) / denominator;
}

double _intersectionArea(Rect first, Rect second) {
  final intersection = first.intersect(second);
  return intersection.isEmpty ? 0 : intersection.width * intersection.height;
}

List<LabelPlacement> applyHandDrawnLabelJitter({
  required Iterable<LabelPlacement> placements,
  required Rect imageRect,
  required double geometryScale,
}) {
  final source = placements.toList(growable: false);
  if (source.isEmpty ||
      !_hasFinitePositiveRect(imageRect) ||
      !geometryScale.isFinite ||
      geometryScale <= 0) {
    return List.unmodifiable(source);
  }

  final sideCounts = <LabelSide, int>{
    for (final side in LabelSide.values)
      side: source.where((placement) => placement.slot.side == side).length,
  };
  final accepted = <LabelPlacement>[];
  const reductionFactors = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0];

  for (var index = 0; index < source.length; index++) {
    final placement = source[index];
    final jitter = VocabHandDrawnJitter.forWord(placement.detection.word);
    var desiredOffset = jitter.positionOffset;
    if (sideCounts[placement.slot.side]! > 1) {
      desiredOffset += switch (placement.slot.side) {
        LabelSide.top || LabelSide.bottom => Offset(jitter.stagger, 0),
        LabelSide.right || LabelSide.left => Offset(0, jitter.stagger),
      };
    }
    desiredOffset *= geometryScale;

    final protectedRects = <Rect>[
      ...accepted.map((item) => item.slot.cardRect),
      ...source.skip(index + 1).map((item) => item.slot.cardRect),
    ];
    Rect? acceptedRect;
    for (final factor in reductionFactors) {
      final candidate = _moveRectInside(
        placement.slot.cardRect.shift(desiredOffset * factor),
        imageRect,
      );
      if (!_overlapsAny(candidate, protectedRects)) {
        acceptedRect = candidate;
        break;
      }
    }

    final cardRect = acceptedRect ?? placement.slot.cardRect;
    accepted.add(
      LabelPlacement(
        detection: placement.detection,
        slot: _slotForRect(
          id: placement.slot.id,
          side: placement.slot.side,
          cardRect: cardRect,
        ),
        objectRect: placement.objectRect,
      ),
    );
  }

  return List.unmodifiable(accepted);
}

Rect _moveRectInside(Rect rect, Rect bounds) {
  if (rect.width > bounds.width || rect.height > bounds.height) return rect;
  final left = rect.left.clamp(bounds.left, bounds.right - rect.width);
  final top = rect.top.clamp(bounds.top, bounds.bottom - rect.height);
  return Rect.fromLTWH(left, top, rect.width, rect.height);
}

ArrowGeometry calculateArrowGeometry({
  required LabelPlacement placement,
  required Offset imageCenter,
  Iterable<Rect> obstacles = const [],
  Rect? routingBounds,
  double geometryScale = 1,
}) {
  final anchors = _nearestRectBoundaryPoints(
    placement.slot.cardRect,
    placement.objectRect,
  );
  final start = anchors.label;
  final end = anchors.object;
  final vector = end - start;
  final distance = vector.distance;
  if (distance == 0) {
    return ArrowGeometry(
      start: start,
      end: end,
      controlPoint: end,
      arrowHeadPoints: List.unmodifiable([end, end, end]),
    );
  }

  final midpoint = (start + end) / 2;
  final perpendicular = Offset(-vector.dy / distance, vector.dx / distance);
  final curveAmount = distance * 0.15;
  final firstCandidate = midpoint + perpendicular * curveAmount;
  final secondCandidate = midpoint - perpendicular * curveAmount;
  final firstDistance = (firstCandidate - imageCenter).distanceSquared;
  final secondDistance = (secondCandidate - imageCenter).distanceSquared;
  final prefersFirst = firstDistance < secondDistance ||
      (firstDistance == secondDistance &&
          _compareOffsets(firstCandidate, secondCandidate) <= 0);
  final preferredControl = prefersFirst ? firstCandidate : secondCandidate;
  final obstacleRects = obstacles
      .where(_hasFinitePositiveRect)
      .map((rect) => rect.inflate(3 * geometryScale))
      .toList(growable: false);
  final directPathBlocked = obstacleRects.any(
    (rect) => segmentIntersectsRect(start, end, rect),
  );
  final defaultCurveBlocked = _quadraticCollisionCount(
        start: start,
        control: preferredControl,
        end: end,
        obstacles: obstacleRects,
      ) >
      0;
  final controlPoint = directPathBlocked || defaultCurveBlocked
      ? _detourControlPoint(
          start: start,
          end: end,
          perpendicular: perpendicular,
          preferredSign: prefersFirst ? 1 : -1,
          obstacles: obstacleRects,
          routingBounds: routingBounds,
        )
      : preferredControl;

  final tangent = end - controlPoint;
  final tangentLength = tangent.distance;
  final backward = tangentLength == 0
      ? Offset(-vector.dx / distance, -vector.dy / distance)
      : Offset(-tangent.dx / tangentLength, -tangent.dy / tangentLength);
  final arrowHeadLength = (distance * 0.08).clamp(
    5.0 * geometryScale,
    10.0 * geometryScale,
  );
  final arrowHeadPoints = <Offset>[
    end + _rotate(backward, -0.52) * arrowHeadLength,
    end + backward * (arrowHeadLength * 0.66),
    end + _rotate(backward, 0.52) * arrowHeadLength,
  ];

  return ArrowGeometry(
    start: start,
    end: end,
    controlPoint: controlPoint,
    arrowHeadPoints: List.unmodifiable(arrowHeadPoints),
  );
}

double quadraticBezierLength(
  ArrowGeometry geometry, {
  int segments = 32,
}) {
  assert(segments > 0);
  var length = 0.0;
  var previous = geometry.start;
  for (var step = 1; step <= segments; step++) {
    final point = _quadraticBezierPoint(geometry, step / segments);
    length += (point - previous).distance;
    previous = point;
  }
  return length;
}

bool quadraticBeziersIntersect(
  ArrowGeometry first,
  ArrowGeometry second, {
  int segments = 32,
}) {
  assert(segments > 0);
  if (!_quadraticBezierBounds(first).overlaps(_quadraticBezierBounds(second))) {
    return false;
  }
  var firstStart = first.start;
  for (var firstStep = 1; firstStep <= segments; firstStep++) {
    final firstEnd = _quadraticBezierPoint(first, firstStep / segments);
    var secondStart = second.start;
    for (var secondStep = 1; secondStep <= segments; secondStep++) {
      final secondEnd = _quadraticBezierPoint(second, secondStep / segments);
      if (_segmentsIntersect(firstStart, firstEnd, secondStart, secondEnd)) {
        return true;
      }
      secondStart = secondEnd;
    }
    firstStart = firstEnd;
  }
  return false;
}

Rect _quadraticBezierBounds(ArrowGeometry geometry) => Rect.fromLTRB(
      math.min(
        geometry.start.dx,
        math.min(geometry.controlPoint.dx, geometry.end.dx),
      ),
      math.min(
        geometry.start.dy,
        math.min(geometry.controlPoint.dy, geometry.end.dy),
      ),
      math.max(
        geometry.start.dx,
        math.max(geometry.controlPoint.dx, geometry.end.dx),
      ),
      math.max(
        geometry.start.dy,
        math.max(geometry.controlPoint.dy, geometry.end.dy),
      ),
    );

Offset _quadraticBezierPoint(ArrowGeometry geometry, double t) {
  final inverse = 1 - t;
  return geometry.start * (inverse * inverse) +
      geometry.controlPoint * (2 * inverse * t) +
      geometry.end * (t * t);
}

bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
  const epsilon = 0.000001;
  double cross(Offset first, Offset second, Offset third) =>
      (second.dx - first.dx) * (third.dy - first.dy) -
      (second.dy - first.dy) * (third.dx - first.dx);
  bool within(Offset point, Offset start, Offset end) =>
      point.dx >= math.min(start.dx, end.dx) - epsilon &&
      point.dx <= math.max(start.dx, end.dx) + epsilon &&
      point.dy >= math.min(start.dy, end.dy) - epsilon &&
      point.dy <= math.max(start.dy, end.dy) + epsilon;

  final abC = cross(a, b, c);
  final abD = cross(a, b, d);
  final cdA = cross(c, d, a);
  final cdB = cross(c, d, b);
  if (((abC > epsilon && abD < -epsilon) ||
          (abC < -epsilon && abD > epsilon)) &&
      ((cdA > epsilon && cdB < -epsilon) ||
          (cdA < -epsilon && cdB > epsilon))) {
    return true;
  }
  return (abC.abs() <= epsilon && within(c, a, b)) ||
      (abD.abs() <= epsilon && within(d, a, b)) ||
      (cdA.abs() <= epsilon && within(a, c, d)) ||
      (cdB.abs() <= epsilon && within(b, c, d));
}

/// Returns whether the closed segment from [start] to [end] touches [rect].
bool segmentIntersectsRect(Offset start, Offset end, Rect rect) {
  if (!_hasFinitePositiveRect(rect) ||
      !start.dx.isFinite ||
      !start.dy.isFinite ||
      !end.dx.isFinite ||
      !end.dy.isFinite) {
    return false;
  }
  if (rect.contains(start) || rect.contains(end)) return true;

  final delta = end - start;
  var minimumT = 0.0;
  var maximumT = 1.0;

  bool clip(double direction, double distance) {
    if (direction == 0) return distance >= 0;
    final ratio = distance / direction;
    if (direction < 0) {
      if (ratio > maximumT) return false;
      minimumT = math.max(minimumT, ratio);
    } else {
      if (ratio < minimumT) return false;
      maximumT = math.min(maximumT, ratio);
    }
    return true;
  }

  return clip(-delta.dx, start.dx - rect.left) &&
      clip(delta.dx, rect.right - start.dx) &&
      clip(-delta.dy, start.dy - rect.top) &&
      clip(delta.dy, rect.bottom - start.dy) &&
      minimumT <= maximumT;
}

/// Samples a quadratic Bézier as short segments for bounded obstacle checks.
bool quadraticBezierIntersectsRect({
  required ArrowGeometry geometry,
  required Rect obstacle,
}) {
  return _quadraticCollisionCount(
        start: geometry.start,
        control: geometry.controlPoint,
        end: geometry.end,
        obstacles: [obstacle],
      ) >
      0;
}

Offset _detourControlPoint({
  required Offset start,
  required Offset end,
  required Offset perpendicular,
  required int preferredSign,
  required List<Rect> obstacles,
  required Rect? routingBounds,
}) {
  final midpoint = (start + end) / 2;
  final distance = (end - start).distance;
  const curveFactors = [0.28, 0.42, 0.56];
  Offset? bestCandidate;
  var bestCollisionCount = obstacles.length + 1;

  for (final factor in curveFactors) {
    for (final sign in [preferredSign, -preferredSign]) {
      var candidate = midpoint + perpendicular * (distance * factor * sign);
      if (routingBounds != null && _hasFinitePositiveRect(routingBounds)) {
        candidate = Offset(
          candidate.dx.clamp(routingBounds.left, routingBounds.right),
          candidate.dy.clamp(routingBounds.top, routingBounds.bottom),
        );
      }
      final collisionCount = _quadraticCollisionCount(
        start: start,
        control: candidate,
        end: end,
        obstacles: obstacles,
      );
      if (collisionCount < bestCollisionCount) {
        bestCandidate = candidate;
        bestCollisionCount = collisionCount;
      }
      if (collisionCount == 0) return candidate;
    }
  }

  return bestCandidate ?? midpoint;
}

int _quadraticCollisionCount({
  required Offset start,
  required Offset control,
  required Offset end,
  required Iterable<Rect> obstacles,
}) {
  const segmentCount = 16;
  var collisions = 0;
  var previous = start;
  final hitObstacles = <Rect>{};

  for (var index = 1; index <= segmentCount; index++) {
    final time = index / segmentCount;
    final inverse = 1 - time;
    final point = start * (inverse * inverse) +
        control * (2 * inverse * time) +
        end * (time * time);
    for (final obstacle in obstacles) {
      if (!hitObstacles.contains(obstacle) &&
          segmentIntersectsRect(previous, point, obstacle)) {
        hitObstacles.add(obstacle);
        collisions++;
      }
    }
    previous = point;
  }

  return collisions;
}

Offset _rectBoundaryPointToward(Rect rect, Offset point) {
  final delta = point - rect.center;
  if (delta == Offset.zero) return rect.center;

  final horizontalScale =
      delta.dx == 0 ? double.infinity : (rect.width / 2) / delta.dx.abs();
  final verticalScale =
      delta.dy == 0 ? double.infinity : (rect.height / 2) / delta.dy.abs();
  final scale = math.min(horizontalScale, verticalScale);
  return rect.center + delta * scale;
}

({Offset label, Offset object}) _nearestRectBoundaryPoints(
  Rect labelRect,
  Rect objectRect,
) {
  if (!_hasFinitePositiveRect(labelRect) ||
      !_hasFinitePositiveRect(objectRect)) {
    return (label: labelRect.center, object: objectRect.center);
  }

  final horizontal = _nearestAxisCoordinates(
    labelMin: labelRect.left,
    labelMax: labelRect.right,
    objectMin: objectRect.left,
    objectMax: objectRect.right,
  );
  final vertical = _nearestAxisCoordinates(
    labelMin: labelRect.top,
    labelMax: labelRect.bottom,
    objectMin: objectRect.top,
    objectMax: objectRect.bottom,
  );
  final label = Offset(horizontal.label, vertical.label);
  final object = Offset(horizontal.object, vertical.object);

  if (label != object) return (label: label, object: object);

  final intersections = _rectBoundaryIntersections(labelRect, objectRect);
  if (intersections.isNotEmpty) {
    final midpoint = (labelRect.center + objectRect.center) / 2;
    intersections.sort((first, second) {
      final byDistance = (first - midpoint)
          .distanceSquared
          .compareTo((second - midpoint).distanceSquared);
      return byDistance != 0 ? byDistance : _compareOffsets(first, second);
    });
    return (label: intersections.first, object: intersections.first);
  }

  return _nearestContainedRectBoundaryPoints(labelRect, objectRect);
}

({double label, double object}) _nearestAxisCoordinates({
  required double labelMin,
  required double labelMax,
  required double objectMin,
  required double objectMax,
}) {
  if (labelMax < objectMin) {
    return (label: labelMax, object: objectMin);
  }
  if (objectMax < labelMin) {
    return (label: labelMin, object: objectMax);
  }

  final overlapCenter =
      (math.max(labelMin, objectMin) + math.min(labelMax, objectMax)) / 2;
  return (label: overlapCenter, object: overlapCenter);
}

List<Offset> _rectBoundaryIntersections(Rect first, Rect second) {
  final intersections = <Offset>{};
  for (final x in [first.left, first.right]) {
    for (final y in [second.top, second.bottom]) {
      if (x >= second.left &&
          x <= second.right &&
          y >= first.top &&
          y <= first.bottom) {
        intersections.add(Offset(x, y));
      }
    }
  }
  for (final x in [second.left, second.right]) {
    for (final y in [first.top, first.bottom]) {
      if (x >= first.left &&
          x <= first.right &&
          y >= second.top &&
          y <= second.bottom) {
        intersections.add(Offset(x, y));
      }
    }
  }
  return intersections.toList(growable: false);
}

({Offset label, Offset object}) _nearestContainedRectBoundaryPoints(
  Rect labelRect,
  Rect objectRect,
) {
  final sharedX = (math.max(labelRect.left, objectRect.left) +
          math.min(labelRect.right, objectRect.right)) /
      2;
  final sharedY = (math.max(labelRect.top, objectRect.top) +
          math.min(labelRect.bottom, objectRect.bottom)) /
      2;
  final candidates = <({Offset label, Offset object})>[
    (
      label: Offset(labelRect.left, sharedY),
      object: Offset(objectRect.left, sharedY),
    ),
    (
      label: Offset(labelRect.right, sharedY),
      object: Offset(objectRect.right, sharedY),
    ),
    (
      label: Offset(sharedX, labelRect.top),
      object: Offset(sharedX, objectRect.top),
    ),
    (
      label: Offset(sharedX, labelRect.bottom),
      object: Offset(sharedX, objectRect.bottom),
    ),
  ]..sort((first, second) {
      final byDistance = (first.label - first.object)
          .distanceSquared
          .compareTo((second.label - second.object).distanceSquared);
      return byDistance != 0
          ? byDistance
          : _compareOffsets(first.label, second.label);
    });
  return candidates.first;
}

Offset _rotate(Offset vector, double radians) {
  final cosine = math.cos(radians);
  final sine = math.sin(radians);
  return Offset(
    vector.dx * cosine - vector.dy * sine,
    vector.dx * sine + vector.dy * cosine,
  );
}

int _compareOffsets(Offset a, Offset b) {
  final byX = a.dx.compareTo(b.dx);
  return byX != 0 ? byX : a.dy.compareTo(b.dy);
}

/// Generates non-overlapping card slots on an already-positioned image.
///
/// Cards are inset from the displayed image edges, so they overlay the source
/// image instead of consuming an external canvas band. Vertical-edge slots
/// avoid the top and bottom card rows to keep the corners collision-free.
List<LabelSlot> generatePerimeterSlots({
  required Rect imageRect,
  required Size overlaySize,
  required Size cardSize,
  double safeMargin = 12,
  double slotGap = 8,
}) {
  if (!_hasValidSlotGeometry(
    imageRect: imageRect,
    overlaySize: overlaySize,
    cardSize: cardSize,
    safeMargin: safeMargin,
    slotGap: slotGap,
  )) {
    return const [];
  }

  final overlayRect = Offset.zero & overlaySize;
  final visibleImageRect = imageRect.intersect(overlayRect);
  if (visibleImageRect.isEmpty) return const [];

  final contentRect = visibleImageRect.deflate(safeMargin);
  if (!_hasFinitePositiveRect(contentRect) ||
      contentRect.width < cardSize.width ||
      contentRect.height < cardSize.height) {
    return const [];
  }

  final horizontalStart = contentRect.left;
  final horizontalEnd = contentRect.right;
  final top = contentRect.top;
  final bottom = contentRect.bottom - cardSize.height;
  final verticalStart = top + cardSize.height + slotGap;
  final verticalEnd = bottom - slotGap;

  final slots = <LabelSlot>[];

  slots.addAll(
    _horizontalSlots(
      side: LabelSide.top,
      start: horizontalStart,
      end: horizontalEnd,
      top: top,
      cardSize: cardSize,
      slotGap: slotGap,
    ),
  );

  if (verticalEnd - verticalStart >= cardSize.height) {
    slots.addAll(
      _verticalSlots(
        side: LabelSide.right,
        start: verticalStart,
        end: verticalEnd,
        left: contentRect.right - cardSize.width,
        cardSize: cardSize,
        slotGap: slotGap,
      ),
    );
  }

  if (bottom - top >= cardSize.height + slotGap) {
    slots.addAll(
      _horizontalSlots(
        side: LabelSide.bottom,
        start: horizontalStart,
        end: horizontalEnd,
        top: bottom,
        cardSize: cardSize,
        slotGap: slotGap,
      ),
    );
  }

  if (verticalEnd - verticalStart >= cardSize.height) {
    slots.addAll(
      _verticalSlots(
        side: LabelSide.left,
        start: verticalStart,
        end: verticalEnd,
        left: contentRect.left,
        cardSize: cardSize,
        slotGap: slotGap,
      ),
    );
  }

  return List.unmodifiable(slots.take(maxVisibleObjects));
}

/// Assigns prioritized detections to unique perimeter slots deterministically.
///
/// The highest-priority objects are retained when there are fewer slots than
/// detections. Those objects are then processed in polar-angle order to
/// preserve their spatial relationship around the image.
List<LabelPlacement> assignObjectsToSlots({
  required Iterable<VocabDetection> detections,
  required Rect imageRect,
  required Iterable<LabelSlot> slots,
  ContentBusyMap? busyMap,
}) {
  if (!_hasFinitePositiveRect(imageRect)) return const [];

  final availableSlots = _usableSlots(slots);
  if (availableSlots.isEmpty) return const [];

  if (busyMap != null) {
    return _assignObjectsToContentAwareSlots(
      detections: detections,
      imageRect: imageRect,
      slots: availableSlots,
      busyMap: busyMap,
    );
  }

  final prioritized = selectVisibleObjects(detections)
      .take(availableSlots.length)
      .map((detection) => _LayoutObject.fromDetection(detection, imageRect))
      .toList()
    ..sort(_compareByPolarAngle);

  final slotsBySide = <LabelSide, List<LabelSlot>>{
    for (final side in LabelSide.values)
      side: availableSlots.where((slot) => slot.side == side).toList(),
  };
  final objectsBySide = <LabelSide, List<_LayoutObject>>{
    for (final side in LabelSide.values) side: [],
  };
  final remainingCapacity = <LabelSide, int>{
    for (final side in LabelSide.values) side: slotsBySide[side]!.length,
  };

  for (final object in prioritized) {
    final preferredSides = _preferredSides(object.center, imageRect.center);
    final maximumDistance = availableSlots.fold<double>(
      0,
      (current, slot) => math.max(
        current,
        (slot.anchorPoint - object.center).distance,
      ),
    );
    final sidePenaltyUnit = maximumDistance + 1;

    LabelSide? bestSide;
    double? bestCost;
    for (final side in LabelSide.values) {
      if (remainingCapacity[side] == 0) continue;

      final sideRank = preferredSides.indexOf(side);
      final nearestSlotDistance = slotsBySide[side]!
          .map((slot) => (slot.anchorPoint - object.center).distance)
          .reduce(math.min);
      final cost = nearestSlotDistance + sideRank * sidePenaltyUnit;
      if (bestCost == null ||
          cost < bestCost ||
          (cost == bestCost && side.index < bestSide!.index)) {
        bestSide = side;
        bestCost = cost;
      }
    }

    final selectedSide = bestSide;
    if (selectedSide == null) break;
    objectsBySide[selectedSide]!.add(object);
    remainingCapacity[selectedSide] = remainingCapacity[selectedSide]! - 1;
  }

  final assignedSlots = <_LayoutObject, LabelSlot>{};
  for (final side in LabelSide.values) {
    final sideObjects = objectsBySide[side]!
      ..sort((a, b) => _compareObjectsAlongSide(a, b, side));
    final sideSlots = slotsBySide[side]!;
    for (var index = 0; index < sideObjects.length; index++) {
      assignedSlots[sideObjects[index]] = sideSlots[index];
    }
  }

  return List.unmodifiable([
    for (final object in prioritized)
      if (assignedSlots[object] case final slot?)
        LabelPlacement(
          detection: object.detection,
          slot: slot,
          objectRect: object.rect,
        ),
  ]);
}

List<LabelPlacement> _assignObjectsToContentAwareSlots({
  required Iterable<VocabDetection> detections,
  required Rect imageRect,
  required List<LabelSlot> slots,
  required ContentBusyMap busyMap,
}) {
  final objects = selectVisibleObjects(detections)
      .take(slots.length)
      .map((detection) => _LayoutObject.fromDetection(detection, imageRect))
      .toList()
    ..sort(_compareByPolarAngle);
  final nearbySlotAllowance = 2 *
      math.sqrt(
        busyMap.cellSize.width * busyMap.cellSize.width +
            busyMap.cellSize.height * busyMap.cellSize.height,
      );
  final nearestDistances = [
    for (final object in objects)
      slots
          .map((slot) => (slot.anchorPoint - object.center).distance)
          .reduce(math.min),
  ];
  final memo = <(int, int), _ContentAwareAssignment>{};

  _ContentAwareAssignment solve(int objectIndex, int usedSlotMask) {
    if (objectIndex == objects.length) {
      return const _ContentAwareAssignment(cost: 0, slotIndexes: []);
    }
    final key = (objectIndex, usedSlotMask);
    final cached = memo[key];
    if (cached != null) return cached;

    _ContentAwareAssignment? best;
    for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
      final slotBit = 1 << slotIndex;
      if (usedSlotMask & slotBit != 0) continue;

      final remaining = solve(objectIndex + 1, usedSlotMask | slotBit);
      final cost = _contentAwareSlotCost(
            object: objects[objectIndex],
            slot: slots[slotIndex],
            imageRect: imageRect,
            busyMap: busyMap,
            nearestDistance: nearestDistances[objectIndex],
            nearDistanceAllowance: nearbySlotAllowance,
          ) +
          remaining.cost;
      final candidate = _ContentAwareAssignment(
        cost: cost,
        slotIndexes: [slotIndex, ...remaining.slotIndexes],
      );
      if (best == null ||
          candidate.cost < best.cost ||
          (candidate.cost == best.cost && slotIndex < best.slotIndexes.first)) {
        best = candidate;
      }
    }

    return memo[key] = best!;
  }

  final assignment = solve(0, 0);

  return List.unmodifiable([
    for (var index = 0; index < objects.length; index++)
      LabelPlacement(
        detection: objects[index].detection,
        slot: slots[assignment.slotIndexes[index]],
        objectRect: objects[index].rect,
      ),
  ]);
}

double _contentAwareSlotCost({
  required _LayoutObject object,
  required LabelSlot slot,
  required Rect imageRect,
  required ContentBusyMap busyMap,
  required double nearestDistance,
  required double nearDistanceAllowance,
}) {
  final distance = (slot.anchorPoint - object.center).distance;
  final isOutsideNearRange = distance > nearestDistance + nearDistanceAllowance;
  final centerBusy = busyMap.isBusyAt(slot.cardRect.center);
  final busyOverlapCount = busyMap.busyCellOverlapCount(slot.cardRect);
  final sideRank = _preferredSides(
    object.center,
    imageRect.center,
  ).indexOf(slot.side);

  return (isOutsideNearRange ? 1e12 : 0) +
      (centerBusy ? 1e9 : 0) +
      busyOverlapCount * 1e6 +
      sideRank * 1e4 +
      distance;
}

class _ContentAwareAssignment {
  const _ContentAwareAssignment({
    required this.cost,
    required this.slotIndexes,
  });

  final double cost;
  final List<int> slotIndexes;
}

int _compareObjectsAlongSide(
  _LayoutObject a,
  _LayoutObject b,
  LabelSide side,
) {
  final aPrimary = switch (side) {
    LabelSide.top || LabelSide.bottom => a.center.dx,
    LabelSide.right || LabelSide.left => a.center.dy,
  };
  final bPrimary = switch (side) {
    LabelSide.top || LabelSide.bottom => b.center.dx,
    LabelSide.right || LabelSide.left => b.center.dy,
  };
  final byPrimary = aPrimary.compareTo(bPrimary);
  if (byPrimary != 0) return byPrimary;

  final aSecondary = switch (side) {
    LabelSide.top || LabelSide.bottom => a.center.dy,
    LabelSide.right || LabelSide.left => a.center.dx,
  };
  final bSecondary = switch (side) {
    LabelSide.top || LabelSide.bottom => b.center.dy,
    LabelSide.right || LabelSide.left => b.center.dx,
  };
  final bySecondary = aSecondary.compareTo(bSecondary);
  return bySecondary != 0 ? bySecondary : _compareByPolarAngle(a, b);
}

List<LabelSlot> _usableSlots(Iterable<LabelSlot> slots) {
  final sorted = slots.where(_hasValidSlot).toList()..sort(_compareSlots);
  final accepted = <LabelSlot>[];
  final acceptedIds = <String>{};

  for (final slot in sorted) {
    if (!acceptedIds.add(slot.id)) continue;
    if (_overlapsAny(slot.cardRect, accepted.map((other) => other.cardRect))) {
      continue;
    }
    accepted.add(slot);
  }

  return accepted;
}

bool _overlapsAny(Rect candidate, Iterable<Rect> otherRects) {
  return otherRects.any(candidate.overlaps);
}

bool _hasValidSlot(LabelSlot slot) {
  return slot.id.isNotEmpty &&
      _hasFinitePositiveRect(slot.cardRect) &&
      slot.anchorPoint.dx.isFinite &&
      slot.anchorPoint.dy.isFinite;
}

int _compareSlots(LabelSlot a, LabelSlot b) {
  final bySide = a.side.index.compareTo(b.side.index);
  if (bySide != 0) return bySide;

  final aPrimary = switch (a.side) {
    LabelSide.top || LabelSide.bottom => a.cardRect.left,
    LabelSide.right || LabelSide.left => a.cardRect.top,
  };
  final bPrimary = switch (b.side) {
    LabelSide.top || LabelSide.bottom => b.cardRect.left,
    LabelSide.right || LabelSide.left => b.cardRect.top,
  };
  final byPrimary = aPrimary.compareTo(bPrimary);
  if (byPrimary != 0) return byPrimary;

  final byLeft = a.cardRect.left.compareTo(b.cardRect.left);
  if (byLeft != 0) return byLeft;

  final byTop = a.cardRect.top.compareTo(b.cardRect.top);
  if (byTop != 0) return byTop;

  return a.id.compareTo(b.id);
}

List<LabelSide> _preferredSides(Offset objectCenter, Offset imageCenter) {
  final dx = objectCenter.dx - imageCenter.dx;
  final dy = objectCenter.dy - imageCenter.dy;
  final scores = <LabelSide, double>{
    LabelSide.top: -dy,
    LabelSide.right: dx,
    LabelSide.bottom: dy,
    LabelSide.left: -dx,
  };

  return LabelSide.values.toList()
    ..sort((a, b) {
      final byDirection = scores[b]!.compareTo(scores[a]!);
      return byDirection != 0 ? byDirection : a.index.compareTo(b.index);
    });
}

int _compareByPolarAngle(_LayoutObject a, _LayoutObject b) {
  final byAngle = a.angle.compareTo(b.angle);
  if (byAngle != 0) return byAngle;

  final byCenterY = a.center.dy.compareTo(b.center.dy);
  if (byCenterY != 0) return byCenterY;

  final byCenterX = a.center.dx.compareTo(b.center.dx);
  if (byCenterX != 0) return byCenterX;

  return _compareByVisualPriority(a.detection, b.detection);
}

bool _hasFinitePositiveRect(Rect rect) {
  return rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite &&
      !rect.isEmpty;
}

class _LayoutObject {
  const _LayoutObject({
    required this.detection,
    required this.rect,
    required this.center,
    required this.angle,
  });

  factory _LayoutObject.fromDetection(
    VocabDetection detection,
    Rect imageRect,
  ) {
    final rect = Rect.fromLTWH(
      imageRect.left + detection.x * imageRect.width,
      imageRect.top + detection.y * imageRect.height,
      detection.w * imageRect.width,
      detection.h * imageRect.height,
    );
    final center = rect.center;
    final delta = center - imageRect.center;

    return _LayoutObject(
      detection: detection,
      rect: rect,
      center: center,
      angle: math.atan2(delta.dy, delta.dx),
    );
  }

  final VocabDetection detection;
  final Rect rect;
  final Offset center;
  final double angle;
}

List<LabelSlot> _horizontalSlots({
  required LabelSide side,
  required double start,
  required double end,
  required double top,
  required Size cardSize,
  required double slotGap,
}) {
  final offsets = _axisOffsets(
    start: start,
    end: end,
    itemExtent: cardSize.width,
    slotGap: slotGap,
  );

  return [
    for (var index = 0; index < offsets.length; index++)
      _slotForRect(
        id: '${side.name}-$index',
        side: side,
        cardRect: Offset(offsets[index], top) & cardSize,
      ),
  ];
}

List<LabelSlot> _verticalSlots({
  required LabelSide side,
  required double start,
  required double end,
  required double left,
  required Size cardSize,
  required double slotGap,
}) {
  final offsets = _axisOffsets(
    start: start,
    end: end,
    itemExtent: cardSize.height,
    slotGap: slotGap,
  );

  return [
    for (var index = 0; index < offsets.length; index++)
      _slotForRect(
        id: '${side.name}-$index',
        side: side,
        cardRect: Offset(left, offsets[index]) & cardSize,
      ),
  ];
}

List<double> _axisOffsets({
  required double start,
  required double end,
  required double itemExtent,
  required double slotGap,
}) {
  final availableExtent = end - start;
  final capacity = ((availableExtent + slotGap) / (itemExtent + slotGap))
      .floor()
      .clamp(0, maxSlotsPerSide);
  if (capacity == 0) return const [];
  if (capacity == 1) {
    return [start + (availableExtent - itemExtent) / 2];
  }

  final step = (availableExtent - itemExtent) / (capacity - 1);
  return [for (var index = 0; index < capacity; index++) start + step * index];
}

LabelSlot _slotForRect({
  required String id,
  required LabelSide side,
  required Rect cardRect,
}) {
  final anchorPoint = switch (side) {
    LabelSide.top => cardRect.bottomCenter,
    LabelSide.right => cardRect.centerLeft,
    LabelSide.bottom => cardRect.topCenter,
    LabelSide.left => cardRect.centerRight,
  };

  return LabelSlot(
    id: id,
    side: side,
    cardRect: cardRect,
    anchorPoint: anchorPoint,
  );
}

bool _hasValidSlotGeometry({
  required Rect imageRect,
  required Size overlaySize,
  required Size cardSize,
  required double safeMargin,
  required double slotGap,
}) {
  final values = [
    imageRect.left,
    imageRect.top,
    imageRect.right,
    imageRect.bottom,
    overlaySize.width,
    overlaySize.height,
    cardSize.width,
    cardSize.height,
    safeMargin,
    slotGap,
  ];

  return values.every((value) => value.isFinite) &&
      !imageRect.isEmpty &&
      overlaySize.width > safeMargin * 2 &&
      overlaySize.height > safeMargin * 2 &&
      cardSize.width > 0 &&
      cardSize.height > 0 &&
      safeMargin >= 0 &&
      slotGap >= 0;
}

bool _hasValidNormalizedBox(VocabDetection detection) {
  final coordinates = [
    detection.x,
    detection.y,
    detection.w,
    detection.h,
  ];

  return coordinates.every((value) => value.isFinite) &&
      detection.x >= 0 &&
      detection.y >= 0 &&
      detection.w > 0 &&
      detection.h > 0 &&
      detection.x + detection.w <= 1 &&
      detection.y + detection.h <= 1;
}

int _compareByVisualPriority(VocabDetection a, VocabDetection b) {
  final byArea = (b.w * b.h).compareTo(a.w * a.h);
  if (byArea != 0) return byArea;

  final byCenterY = (a.y + a.h / 2).compareTo(b.y + b.h / 2);
  if (byCenterY != 0) return byCenterY;

  final byCenterX = (a.x + a.w / 2).compareTo(b.x + b.w / 2);
  if (byCenterX != 0) return byCenterX;

  final byNormalizedWord = a.word.toLowerCase().compareTo(b.word.toLowerCase());
  if (byNormalizedWord != 0) return byNormalizedWord;

  final byWord = a.word.compareTo(b.word);
  if (byWord != 0) return byWord;

  final byPhonetic = a.phonetic.compareTo(b.phonetic);
  if (byPhonetic != 0) return byPhonetic;

  final byMeaning = a.meaning.compareTo(b.meaning);
  if (byMeaning != 0) return byMeaning;

  return a.partOfSpeech.compareTo(b.partOfSpeech);
}
