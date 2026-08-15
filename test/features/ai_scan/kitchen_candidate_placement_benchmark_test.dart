import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/layout/vocab_overlay_layout.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_note_card_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kitchen fixture benchmarks old and rebalanced candidate placement', () {
    final grid = OverlayPlacementGrid(
      imageRect: const Rect.fromLTWH(0, 0, 768, 1024),
    );
    const oldWeights = LabelPlacementCostWeights(
      labelOverlap: 1000000,
      objectOverlap: 10000,
      distance: 10,
      edgeOverflow: 100,
      arrowCollision: 1000,
      arrowIntersection: 0,
      busyProximity: 0,
      farDistance: 0,
    );

    List<LabelPlacement> layout({
      required LabelPlacementCostWeights weights,
      required bool hardFilterObjectOverlaps,
    }) =>
        applyGridLabelJitter(
          placements: assignObjectsToGrid(
            detections: kitchenDetections,
            obstacleDetections: kitchenDetections,
            grid: grid,
            measuredSizeForDetection: measureVocabNoteCardTextExtent,
            tierForDetection: (detection, placementGrid) =>
                selectVocabNoteCardSizeTier(
              detection: detection,
              grid: placementGrid,
            ),
            weights: weights,
            hardFilterObjectOverlaps: hardFilterObjectOverlaps,
          ),
          grid: grid,
          geometryScale: 1.28,
        );

    final before = layout(
      weights: oldWeights,
      hardFilterObjectOverlaps: true,
    );
    final after = layout(
      weights: const LabelPlacementCostWeights(),
      hardFilterObjectOverlaps: false,
    );
    final beforeMetrics = KitchenBenchmarkMetrics.fromPlacements(before, grid);
    final afterMetrics = KitchenBenchmarkMetrics.fromPlacements(after, grid);

    // ignore: avoid_print
    print('KITCHEN_BEFORE ${beforeMetrics.describe()}');
    // ignore: avoid_print
    print('KITCHEN_AFTER ${afterMetrics.describe()}');
    // ignore: avoid_print
    print(
        'KITCHEN_AFTER_PLACEMENTS ${afterMetrics.placementDetails.join(' | ')}');

    expect(before, hasLength(kitchenDetections.length));
    expect(after, hasLength(kitchenDetections.length));
    expect(_labelsOverlap(before), isFalse);
    expect(_labelsOverlap(after), isFalse);
    expect(afterMetrics.totalBezierLength,
        lessThan(beforeMetrics.totalBezierLength));
    expect(
      afterMetrics.arrowIntersectionPairs,
      lessThanOrEqualTo(beforeMetrics.arrowIntersectionPairs),
    );
    expect(
      afterMetrics.farLabelCount,
      lessThanOrEqualTo(beforeMetrics.farLabelCount),
    );
    expect(afterMetrics.objectOverlapCells, greaterThanOrEqualTo(0));
  });
}

const kitchenDetections = <VocabDetection>[
  VocabDetection(
    word: 'refrigerator',
    phonetic: '/rɪˈfrɪdʒəreɪtər/',
    meaning: 'tủ lạnh',
    x: 0.04,
    y: 0.2,
    w: 0.4,
    h: 0.57,
  ),
  VocabDetection(
    word: 'vase',
    phonetic: '/vɑːz/',
    meaning: 'lọ hoa',
    x: 0.25,
    y: 0.05,
    w: 0.14,
    h: 0.16,
  ),
  VocabDetection(
    word: 'teddy bear',
    phonetic: '/ˈtedi beər/',
    meaning: 'gấu bông',
    x: 0.35,
    y: 0.14,
    w: 0.09,
    h: 0.1,
  ),
  VocabDetection(
    word: 'bottles',
    phonetic: '/ˈbɒtlz/',
    meaning: 'chai lọ',
    x: 0.08,
    y: 0.09,
    w: 0.22,
    h: 0.12,
  ),
  VocabDetection(
    word: 'water jug',
    phonetic: '/ˈwɔːtər dʒʌɡ/',
    meaning: 'bình nước',
    x: 0.12,
    y: 0.44,
    w: 0.22,
    h: 0.28,
  ),
  VocabDetection(
    word: 'electric kettle',
    phonetic: '/ɪˈlektrɪk ˈketl/',
    meaning: 'ấm siêu tốc',
    x: 0.33,
    y: 0.56,
    w: 0.14,
    h: 0.14,
  ),
  VocabDetection(
    word: 'utensil holder',
    phonetic: '/juːˈtensl həʊldər/',
    meaning: 'ống đựng dụng cụ',
    x: 0.52,
    y: 0.42,
    w: 0.14,
    h: 0.18,
  ),
  VocabDetection(
    word: 'dish rack',
    phonetic: '/dɪʃ ræk/',
    meaning: 'giá úp chén',
    x: 0.5,
    y: 0.55,
    w: 0.48,
    h: 0.41,
  ),
  VocabDetection(
    word: 'rice cooker',
    phonetic: '/raɪs ˈkʊkər/',
    meaning: 'nồi cơm điện',
    x: 0.25,
    y: 0.73,
    w: 0.24,
    h: 0.21,
  ),
  VocabDetection(
    word: 'electric stove',
    phonetic: '/ɪˈlektrɪk stəʊv/',
    meaning: 'bếp điện',
    x: 0.55,
    y: 0.83,
    w: 0.38,
    h: 0.15,
  ),
];

class KitchenBenchmarkMetrics {
  const KitchenBenchmarkMetrics({
    required this.totalBezierLength,
    required this.arrowIntersectionPairs,
    required this.farLabelCount,
    required this.objectOverlapCells,
    required this.maximumDistanceRatio,
    required this.placementDetails,
  });

  factory KitchenBenchmarkMetrics.fromPlacements(
    List<LabelPlacement> placements,
    OverlayPlacementGrid grid,
  ) {
    final arrows = <ArrowGeometry>[
      for (final placement in placements)
        calculateArrowGeometry(
          placement: placement,
          imageCenter: grid.imageRect.center,
          obstacles: [
            for (final other in placements)
              if (!identical(other, placement)) ...[
                other.slot.cardRect,
                other.objectRect,
              ],
          ],
          routingBounds: grid.imageRect,
          geometryScale: 1.28,
        ),
    ];
    final ratios = [
      for (final placement in placements)
        boundaryDistanceRatio(
          labelRect: placement.slot.cardRect,
          objectRect: placement.objectRect,
        ),
    ];
    final objectAreas = <VocabDetection, GridArea>{
      for (final detection in kitchenDetections)
        detection: grid.areaForObjectRect(
          Rect.fromLTWH(
            grid.imageRect.left + detection.x * grid.imageRect.width,
            grid.imageRect.top + detection.y * grid.imageRect.height,
            detection.w * grid.imageRect.width,
            detection.h * grid.imageRect.height,
          ),
        ),
    };
    var intersections = 0;
    for (var first = 0; first < arrows.length; first++) {
      for (var second = first + 1; second < arrows.length; second++) {
        if (quadraticBeziersIntersect(arrows[first], arrows[second])) {
          intersections++;
        }
      }
    }
    var overlapCells = 0;
    for (final placement in placements) {
      for (final entry in objectAreas.entries) {
        if (identical(entry.key, placement.detection)) continue;
        overlapCells +=
            _overlapCellCount(placement.slot.gridArea!, entry.value);
      }
    }
    return KitchenBenchmarkMetrics(
      totalBezierLength: arrows.fold(
        0.0,
        (total, arrow) => total + quadraticBezierLength(arrow),
      ),
      arrowIntersectionPairs: intersections,
      farLabelCount: ratios.where((ratio) => ratio > 2.5).length,
      objectOverlapCells: overlapCells,
      maximumDistanceRatio: ratios.fold(
          0.0, (maximum, ratio) => ratio > maximum ? ratio : maximum),
      placementDetails: [
        for (var index = 0; index < placements.length; index++)
          '${placements[index].detection.word}:'
              '${placements[index].slot.sizeTier?.name}@'
              '(${placements[index].slot.cardRect.center.dx.toStringAsFixed(0)},'
              '${placements[index].slot.cardRect.center.dy.toStringAsFixed(0)})'
              ',arrow=${quadraticBezierLength(arrows[index]).toStringAsFixed(1)}'
              ',ratio=${ratios[index].toStringAsFixed(2)}',
      ],
    );
  }

  final double totalBezierLength;
  final int arrowIntersectionPairs;
  final int farLabelCount;
  final int objectOverlapCells;
  final double maximumDistanceRatio;
  final List<String> placementDetails;

  String describe() => 'length=${totalBezierLength.toStringAsFixed(2)}, '
      'intersections=$arrowIntersectionPairs, far=$farLabelCount, '
      'maxRatio=${maximumDistanceRatio.toStringAsFixed(3)}, '
      'objectOverlapCells=$objectOverlapCells';
}

int _overlapCellCount(GridArea first, GridArea second) {
  return first.cells.intersection(second.cells).length;
}

bool _labelsOverlap(List<LabelPlacement> placements) {
  for (var first = 0; first < placements.length; first++) {
    for (var second = first + 1; second < placements.length; second++) {
      if (placements[first]
          .slot
          .gridArea!
          .overlaps(placements[second].slot.gridArea!)) {
        return true;
      }
    }
  }
  return false;
}
