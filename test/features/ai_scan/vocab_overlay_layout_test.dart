import 'dart:math' as math;

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/presentation/layout/vocab_hand_drawn_jitter.dart';
import 'package:capy_vocab/features/ai_scan/presentation/layout/vocab_overlay_layout.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_note_card_painter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('word seed creates repeatable position and stagger ranges', () {
    final first = VocabHandDrawnJitter.forWord('basket');
    final second = VocabHandDrawnJitter.forWord('basket');

    expect(second.positionOffset, first.positionOffset);
    expect(second.stagger, first.stagger);
    expect(second.rotationRadians, first.rotationRadians);
    expect(
      first.positionOffset.dx.abs(),
      inInclusiveRange(
        handDrawnMinPositionJitter,
        handDrawnMaxPositionJitter,
      ),
    );
    expect(
      first.positionOffset.dy.abs(),
      inInclusiveRange(
        handDrawnMinPositionJitter,
        handDrawnMaxPositionJitter,
      ),
    );
    expect(
      first.stagger.abs(),
      inInclusiveRange(handDrawnMinStagger, handDrawnMaxStagger),
    );
  });

  group('selectVisibleObjects', () {
    test('keeps every valid detection when the total is at most 12', () {
      final detections = [
        _detection('small', width: 0.1, height: 0.1),
        _detection('large', width: 0.3, height: 0.2),
      ];

      final selected = selectVisibleObjects(detections);

      expect(selected, hasLength(2));
      expect(selected.map((item) => item.word), ['large', 'small']);
    });

    test('selects exactly the 12 largest boxes from 15 detections', () {
      final detections = List.generate(
        15,
        (index) => _detection(
          'object-$index',
          width: (index + 1) / 100,
          height: 0.1,
        ),
      );

      final selected = selectVisibleObjects(detections);

      expect(selected, hasLength(maxVisibleObjects));
      expect(
        selected.map((item) => item.word),
        [for (var index = 14; index >= 3; index--) 'object-$index'],
      );
    });

    test('uses centerY, centerX, then word as deterministic tie-breakers', () {
      final detections = [
        _detection('zebra', x: 0.1, y: 0.1),
        _detection('apple', x: 0.1, y: 0.1),
        _detection('right', x: 0.3, y: 0.1),
        _detection('bottom', x: 0.1, y: 0.3),
      ];

      final selected = selectVisibleObjects(detections.reversed);

      expect(
        selected.map((item) => item.word),
        ['apple', 'zebra', 'right', 'bottom'],
      );
    });

    test('filters boxes that are empty, non-finite, or outside the image', () {
      final detections = [
        _detection('valid'),
        _detection('empty', width: 0),
        _detection('negative', x: -0.1),
        _detection('overflow', x: 0.95, width: 0.1),
        _detection('infinite', width: double.infinity),
      ];

      final selected = selectVisibleObjects(detections);

      expect(selected.map((item) => item.word), ['valid']);
    });

    test('returns the same result when response order changes', () {
      final detections = List.generate(
        15,
        (index) => _detection(
          'object-$index',
          x: (index % 5) * 0.1,
          y: (index ~/ 5) * 0.1,
          width: 0.05 + index / 100,
          height: 0.1,
        ),
      );

      final forward = selectVisibleObjects(detections);
      final reversed = selectVisibleObjects(detections.reversed);

      expect(
        reversed.map((item) => item.word),
        forward.map((item) => item.word),
      );
    });
  });

  group('generatePerimeterSlots', () {
    test('generates three ordered slots on every edge when space allows', () {
      final slots = generatePerimeterSlots(
        overlaySize: const Size(800, 800),
        imageRect: const Rect.fromLTWH(0, 0, 800, 800),
        cardSize: const Size(100, 60),
        safeMargin: 20,
        slotGap: 12,
      );

      expect(slots, hasLength(maxVisibleObjects));
      for (final side in LabelSide.values) {
        expect(slots.where((slot) => slot.side == side), hasLength(3));
      }
      expect(
        slots.map((slot) => slot.id),
        [
          'top-0',
          'top-1',
          'top-2',
          'right-0',
          'right-1',
          'right-2',
          'bottom-0',
          'bottom-1',
          'bottom-2',
          'left-0',
          'left-1',
          'left-2',
        ],
      );
    });

    test('reduces capacity per edge when three cards cannot fit', () {
      final slots = generatePerimeterSlots(
        overlaySize: const Size(600, 600),
        imageRect: const Rect.fromLTWH(150, 150, 300, 300),
        cardSize: const Size(120, 120),
        safeMargin: 16,
        slotGap: 12,
      );

      expect(slots, hasLength(4));
      expect(slots.where((slot) => slot.side == LabelSide.top), hasLength(2));
      expect(
        slots.where((slot) => slot.side == LabelSide.bottom),
        hasLength(2),
      );
      expect(slots.where((slot) => slot.side == LabelSide.left), isEmpty);
      expect(slots.where((slot) => slot.side == LabelSide.right), isEmpty);
    });

    test('keeps every card on the image without card overlap', () {
      const overlaySize = Size(800, 800);
      const imageRect = Rect.fromLTWH(100, 80, 600, 640);
      final slots = generatePerimeterSlots(
        overlaySize: overlaySize,
        imageRect: imageRect,
        cardSize: const Size(100, 60),
        safeMargin: 20,
        slotGap: 12,
      );

      for (final slot in slots) {
        expect(slot.cardRect.left, greaterThanOrEqualTo(imageRect.left + 20));
        expect(slot.cardRect.top, greaterThanOrEqualTo(imageRect.top + 20));
        expect(slot.cardRect.right, lessThanOrEqualTo(imageRect.right - 20));
        expect(slot.cardRect.bottom, lessThanOrEqualTo(imageRect.bottom - 20));
      }

      for (var first = 0; first < slots.length; first++) {
        for (var second = first + 1; second < slots.length; second++) {
          expect(
              slots[first].cardRect.overlaps(slots[second].cardRect), isFalse);
        }
      }
    });

    test('anchors face the image and generation is deterministic', () {
      List<LabelSlot> generate() => generatePerimeterSlots(
            overlaySize: const Size(800, 800),
            imageRect: const Rect.fromLTWH(0, 0, 800, 800),
            cardSize: const Size(100, 60),
            safeMargin: 20,
            slotGap: 12,
          );

      final first = generate();
      final second = generate();

      expect(
        second.map((slot) => (slot.id, slot.cardRect, slot.anchorPoint)),
        first.map((slot) => (slot.id, slot.cardRect, slot.anchorPoint)),
      );
      for (final slot in first) {
        final expectedAnchor = switch (slot.side) {
          LabelSide.top => slot.cardRect.bottomCenter,
          LabelSide.right => slot.cardRect.centerLeft,
          LabelSide.bottom => slot.cardRect.topCenter,
          LabelSide.left => slot.cardRect.centerRight,
        };
        expect(slot.anchorPoint, expectedAnchor);
      }
    });

    test('generates slots when the image fills the canvas', () {
      final slots = generatePerimeterSlots(
        overlaySize: const Size(320, 480),
        imageRect: const Rect.fromLTWH(0, 0, 320, 480),
        cardSize: const Size(100, 60),
      );

      expect(slots, isNotEmpty);
      for (final slot in slots) {
        expect(slot.cardRect.left, greaterThanOrEqualTo(12));
        expect(slot.cardRect.top, greaterThanOrEqualTo(12));
        expect(slot.cardRect.right, lessThanOrEqualTo(308));
        expect(slot.cardRect.bottom, lessThanOrEqualTo(468));
      }
    });
  });

  group('content-aware placement', () {
    test('uses the approved candidate-placement weights', () {
      const weights = LabelPlacementCostWeights();

      expect(weights.labelOverlap, 1000000);
      expect(weights.objectOverlap, 100);
      expect(weights.distance, 300);
      expect(weights.arrowCollision, 5000);
      expect(weights.arrowIntersection, 100000);
      expect(weights.edgeOverflow, 100);
      expect(weights.busyProximity, 50);
      expect(weights.farDistance, 20000);
      expect(weights.farDistanceThreshold, 2.5);
    });

    test('uses one dynamic 40dp grid for tier size and candidates', () {
      final grid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 480, 320),
      );
      const objectArea = GridArea(
        column: 5,
        row: 3,
        columns: 2,
        rows: 2,
      );

      expect(grid.columns, 12);
      expect(grid.rows, 8);
      expect(grid.cellSize, const Size(40, 40));
      const cell = GridCell(2, 1);
      expect(cell.index(grid.columns), 14);
      expect(cell.index(20), 22);
      expect(
        LabelSizeTier.values.map(
          (tier) => (tier.columns, tier.rows),
        ),
        [(2, 2), (3, 2), (3, 3), (4, 3)],
      );
      expect(
        selectLabelSizeTier(
          measuredSize: const Size(70, 70),
          grid: grid,
        ),
        LabelSizeTier.small,
      );
      expect(
        selectLabelSizeTier(
          measuredSize: const Size(110, 70),
          grid: grid,
        ),
        LabelSizeTier.medium,
      );
      final candidates = generateGridLabelCandidates(
        objectArea: objectArea,
        tier: LabelSizeTier.medium,
        grid: grid,
      );
      expect(candidates, hasLength(8));
      expect(
        candidates.every(
          (candidate) =>
              candidate.gridArea!.columns == 3 && candidate.gridArea!.rows == 2,
        ),
        isTrue,
      );
      expect(
        candidates.every(
          (candidate) => !candidate.gridArea!.overlaps(objectArea),
        ),
        isTrue,
      );
    });

    test('animal fixture selects the smallest tier with fixed typography', () {
      const detections = [
        VocabDetection(
          word: 'giraffe',
          phonetic: '/dʒəˈrɑːf/',
          meaning: 'hươu cao cổ',
          x: 0.32,
          y: 0.04,
          w: 0.16,
          h: 0.72,
        ),
        VocabDetection(
          word: 'elephant',
          phonetic: '/ˈelɪfənt/',
          meaning: 'con voi',
          x: 0.5,
          y: 0.1,
          w: 0.34,
          h: 0.4,
        ),
        VocabDetection(
          word: 'lion',
          phonetic: '/ˈlaɪən/',
          meaning: 'sư tử',
          x: 0.62,
          y: 0.43,
          w: 0.23,
          h: 0.35,
        ),
        VocabDetection(
          word: 'tiger',
          phonetic: '/ˈtaɪɡə/',
          meaning: 'con hổ',
          x: 0.05,
          y: 0.38,
          w: 0.25,
          h: 0.34,
        ),
        VocabDetection(
          word: 'leaf',
          phonetic: '/liːf/',
          meaning: 'lá cây',
          x: 0.02,
          y: 0.12,
          w: 0.22,
          h: 0.3,
        ),
        VocabDetection(
          word: 'flower',
          phonetic: '/ˈflaʊə/',
          meaning: 'bông hoa',
          x: 0.5,
          y: 0.72,
          w: 0.18,
          h: 0.2,
        ),
      ];
      final compactGrid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(40, 0, 360, 360),
      );
      final largeGrid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(80, 0, 720, 720),
      );
      final smallPhoneGrid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 240, 240),
      );

      Map<String, LabelSizeTier> selectTiers(
        OverlayPlacementGrid grid,
      ) =>
          {
            for (final detection in detections)
              detection.word: selectVocabNoteCardSizeTier(
                detection: detection,
                grid: grid,
              ),
          };

      final compactTiers = selectTiers(compactGrid);
      final largeTiers = selectTiers(largeGrid);
      final smallPhoneTiers = selectTiers(smallPhoneGrid);
      expect(
        compactTiers,
        {
          'giraffe': LabelSizeTier.extraLarge,
          'elephant': LabelSizeTier.large,
          'lion': LabelSizeTier.large,
          'tiger': LabelSizeTier.large,
          'leaf': LabelSizeTier.large,
          'flower': LabelSizeTier.large,
        },
      );
      expect(
        largeTiers,
        compactTiers,
      );
      expect(smallPhoneTiers, compactTiers);

      for (final (grid, tiers) in [
        (compactGrid, compactTiers),
        (largeGrid, largeTiers),
        (smallPhoneGrid, smallPhoneTiers),
      ]) {
        for (final detection in detections) {
          final selected = tiers[detection.word]!;
          expect(
            doesVocabNoteCardFitTier(
              detection: detection,
              tier: selected,
              grid: grid,
            ),
            isTrue,
          );
          for (final smaller in LabelSizeTier.values.take(selected.index)) {
            expect(
              doesVocabNoteCardFitTier(
                detection: detection,
                tier: smaller,
                grid: grid,
              ),
              isFalse,
            );
          }
        }
      }
    });

    test('same tier footprint stays near 40dp across square and wide images',
        () {
      final animalGrid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 360, 360),
      );
      final basketGrid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 800, 444),
      );
      final smallPhoneGrid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 240, 240),
      );
      const tier = LabelSizeTier.extraLarge;

      Size footprint(OverlayPlacementGrid grid) => grid
          .rectForArea(
            GridArea(
              column: 0,
              row: 0,
              columns: tier.columns,
              rows: tier.rows,
            ),
          )
          .size;

      final animalFootprint = footprint(animalGrid);
      final basketFootprint = footprint(basketGrid);
      final smallPhoneFootprint = footprint(smallPhoneGrid);
      double differenceRatio(double first, double second) =>
          (first - second).abs() / first;

      expect((animalGrid.columns, animalGrid.rows), (9, 9));
      expect((basketGrid.columns, basketGrid.rows), (20, 11));
      expect((smallPhoneGrid.columns, smallPhoneGrid.rows), (6, 6));
      expect(animalGrid.cellSize, const Size(40, 40));
      expect(basketGrid.cellSize.width, 40);
      expect(basketGrid.cellSize.height, closeTo(40.363636, 0.000001));
      expect(smallPhoneGrid.cellSize, const Size(40, 40));
      expect(animalFootprint, const Size(160, 120));
      expect(basketFootprint.width, 160);
      expect(basketFootprint.height, closeTo(121.090909, 0.000001));
      expect(smallPhoneFootprint, animalFootprint);
      expect(
        differenceRatio(animalFootprint.width, basketFootprint.width),
        lessThanOrEqualTo(0.2),
      );
      expect(
        differenceRatio(animalFootprint.height, basketFootprint.height),
        lessThanOrEqualTo(0.2),
      );
    });

    test('minimum 6x6 grid protects very small containers', () {
      final tinyLandscape = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 180, 120),
      );

      expect(tinyLandscape.columns, minimumPlacementGridColumns);
      expect(tinyLandscape.rows, minimumPlacementGridRows);
      expect(tinyLandscape.cellSize, const Size(30, 20));
    });

    test('busy map uses the same dynamic object-cell occupancy', () {
      final grid = OverlayPlacementGrid(
        imageRect: const Rect.fromLTWH(0, 0, 800, 600),
      );
      final map = ContentBusyMap.fromDetections(
        grid: grid,
        detections: [
          _detection(
            'tiny-object',
            x: 0,
            y: 0,
            width: 0.01,
            height: 0.01,
          ),
        ],
      );

      expect(identical(map.grid, grid), isTrue);
      expect(map.cellSize, grid.cellSize);
      expect(map.isCellBusy(0, 0), isTrue);
      expect(map.isCellBusy(1, 0), isFalse);
    });

    test('prefers a nearby empty slot over a busy slot', () {
      const imageRect = Rect.fromLTWH(0, 0, 800, 600);
      final grid = OverlayPlacementGrid(imageRect: imageRect);
      final busyMap = ContentBusyMap.fromDetections(
        grid: grid,
        detections: [
          _detection(
            'large-obstacle',
            x: 0,
            y: 0,
            width: 0.5,
            height: 0.5,
          ),
        ],
      );
      const busySlot = LabelSlot(
        id: 'top-busy',
        side: LabelSide.top,
        cardRect: Rect.fromLTWH(0, 0, 100, 80),
        anchorPoint: Offset(50, 80),
      );
      const emptySlot = LabelSlot(
        id: 'top-empty',
        side: LabelSide.top,
        cardRect: Rect.fromLTWH(700, 0, 100, 80),
        anchorPoint: Offset(750, 80),
      );
      final target = _detection(
        'target',
        x: 0.45,
        y: 0.45,
        width: 0.1,
        height: 0.1,
      );

      final baseline = assignObjectsToSlots(
        detections: [target],
        imageRect: imageRect,
        slots: const [busySlot, emptySlot],
      );
      final aware = assignObjectsToSlots(
        detections: [target],
        imageRect: imageRect,
        slots: const [busySlot, emptySlot],
        busyMap: busyMap,
      );

      expect(baseline.single.slot.id, 'top-busy');
      expect(aware.single.slot.id, 'top-empty');
      expect(busyMap.isBusyAt(aware.single.slot.cardRect.center), isFalse);
    });

    test('basket image fixture is safe, non-overlapping, and non-uniform', () {
      final rawScene = [
        _detection(
          'basket',
          phonetic: '/ˈbɑːskɪt/',
          meaning: 'giỏ đựng nhiều trái táo',
          x: 0.412,
          y: 0.219,
          width: 0.38,
          height: 0.617,
        ),
        _detection(
          'apple',
          phonetic: '/ˈæpl/',
          meaning: 'quả táo',
          x: 0.062,
          y: 0.631,
          width: 0.109,
          height: 0.189,
        ),
        _detection(
          'apple',
          phonetic: '/ˈæpl/',
          meaning: 'quả táo',
          x: 0.149,
          y: 0.626,
          width: 0.09,
          height: 0.167,
        ),
        _detection(
          'apple',
          phonetic: '/ˈæpl/',
          meaning: 'quả táo',
          x: 0.29,
          y: 0.644,
          width: 0.118,
          height: 0.159,
        ),
        _detection(
          'apple',
          phonetic: '/ˈæpl/',
          meaning: 'quả táo',
          x: 0.5,
          y: 0.365,
          width: 0.117,
          height: 0.185,
        ),
        _detection(
          'apple',
          phonetic: '/ˈæpl/',
          meaning: 'quả táo',
          x: 0.609,
          y: 0.441,
          width: 0.113,
          height: 0.113,
        ),
        _detection(
          'apple',
          phonetic: '/ˈæpl/',
          meaning: 'quả táo',
          x: 0.672,
          y: 0.392,
          width: 0.106,
          height: 0.153,
        ),
        _detection(
          'leaf',
          phonetic: '/liːf/',
          meaning: 'lá cây',
          x: 0.324,
          y: 0.144,
          width: 0.334,
          height: 0.34,
        ),
        _detection(
          'table',
          phonetic: '/ˈteɪbl/',
          meaning: 'cái bàn',
          x: 0,
          y: 0.77,
          width: 1,
          height: 0.23,
        ),
      ];
      final visible = keepLargestDetectionPerWord(rawScene);
      const overlaySize = Size(800, 600);
      const sourceSize = Size(900, 500);
      const cardSize = Size(100, 60);

      final imageRect = calculateContainedImageRect(
        sourceSize: sourceSize,
        availableRect: Offset.zero & overlaySize,
      );
      final perimeterSlots = generatePerimeterSlots(
        imageRect: imageRect,
        overlaySize: overlaySize,
        cardSize: cardSize,
        safeMargin: 20,
        slotGap: 12,
      );
      final baseline = VocabOverlayLayout(
        imageRect: imageRect,
        slots: perimeterSlots,
        placements: assignObjectsToSlots(
          detections: visible,
          imageRect: imageRect,
          slots: perimeterSlots,
        ),
      );
      final aware = buildVocabOverlayLayout(
        overlaySize: overlaySize,
        sourceImageSize: sourceSize,
        cardSize: cardSize,
        detections: visible,
        cardSizeForDetection: (detection) =>
            measureVocabNoteCardTextExtent(detection) * (5 / 3),
        labelTierForDetection: (detection, grid) => selectVocabNoteCardSizeTier(
          detection: detection,
          grid: grid,
        ),
        busyMapDetections: rawScene,
        safeMargin: 20,
        slotGap: 12,
        labelJitterScale: 5 / 3,
      );
      final busyMap = ContentBusyMap.fromDetections(
        grid: aware.grid!,
        detections: rawScene,
      );
      int busyOverlapScore(VocabOverlayLayout layout) => layout.placements
          .map(
            (placement) =>
                busyMap.busyCellOverlapCount(placement.slot.cardRect),
          )
          .fold(0, (sum, count) => sum + count);
      String describe(VocabOverlayLayout layout) => layout.placements
          .map(
            (placement) => '${placement.detection.word}:${placement.slot.id}'
                '(centerBusy=${busyMap.isBusyAt(placement.slot.cardRect.center)},'
                'overlap=${busyMap.busyCellOverlapCount(placement.slot.cardRect)},'
                'tier=${placement.slot.sizeTier},rect=${placement.slot.cardRect})',
          )
          .join(', ');

      expect(visible.where((item) => item.word == 'apple'), hasLength(1));
      expect(
        aware.placements,
        hasLength(4),
        reason: visible
            .map((detection) =>
                '${detection.word}:${measureVocabNoteCardTextExtent(detection) * (5 / 3)}')
            .join(', '),
      );
      final candidateBusyOverlap = busyOverlapScore(aware);
      expect(
        candidateBusyOverlap,
        greaterThan(0),
        reason: 'O_object is a soft cost: ${describe(aware)}',
      );
      expect(
        aware.placements.map((item) => item.slot.id).toList(),
        isNot(baseline.placements.map((item) => item.slot.id).toList()),
      );
      final grid = aware.grid!;
      for (final placement in aware.placements) {
        final area = placement.slot.gridArea!;
        expect(area.cells, hasLength(area.columns * area.rows));
        expect(
          doesVocabNoteCardFitTier(
            detection: placement.detection,
            tier: placement.slot.sizeTier!,
            grid: grid,
          ),
          isTrue,
        );
        expect(placement.slot.cardRect.width, lessThanOrEqualTo(160));
        expect(placement.slot.cardRect.height, lessThanOrEqualTo(122));
        expect(
          placement.slot.cardRect.left,
          greaterThanOrEqualTo(aware.imageRect.left),
        );
        expect(
          placement.slot.cardRect.top,
          greaterThanOrEqualTo(aware.imageRect.top),
        );
        expect(
          placement.slot.cardRect.right,
          lessThanOrEqualTo(aware.imageRect.right),
        );
        expect(
          placement.slot.cardRect.bottom,
          lessThanOrEqualTo(aware.imageRect.bottom),
        );
      }
      for (var first = 0; first < aware.placements.length; first++) {
        for (var second = first + 1;
            second < aware.placements.length;
            second++) {
          expect(
            aware.placements[first].slot.cardRect.overlaps(
              aware.placements[second].slot.cardRect,
            ),
            isFalse,
          );
        }
      }
      final basket = aware.placements.singleWhere(
        (placement) => placement.detection.word == 'basket',
      );
      final leaf = aware.placements.singleWhere(
        (placement) => placement.detection.word == 'leaf',
      );
      expect(
        basket.slot.gridArea!.cells.length,
        greaterThan(leaf.slot.gridArea!.cells.length),
        reason: describe(aware),
      );
      expect(
        aware.placements.any((placement) {
          final footprint = grid.rectForArea(placement.slot.gridArea!);
          return placement.slot.cardRect.topLeft != footprint.topLeft;
        }),
        isTrue,
      );
    });
  });

  group('assignObjectsToSlots', () {
    const imageRect = Rect.fromLTWH(0, 0, 800, 800);

    List<LabelSlot> allSlots() => generatePerimeterSlots(
          overlaySize: const Size(800, 800),
          imageRect: imageRect,
          cardSize: const Size(100, 60),
          safeMargin: 20,
          slotGap: 12,
        );

    test('assigns objects to their nearest logical edges in polar order', () {
      final detections = [
        _detection('left', x: 0.05, y: 0.45),
        _detection('bottom', x: 0.45, y: 0.85),
        _detection('right', x: 0.85, y: 0.45),
        _detection('top', x: 0.45, y: 0.05),
      ];

      final placements = assignObjectsToSlots(
        detections: detections,
        imageRect: imageRect,
        slots: allSlots(),
      );

      expect(
        placements.map((placement) => placement.detection.word),
        ['top', 'right', 'bottom', 'left'],
      );
      expect(
        placements.map((placement) => placement.slot.side),
        [LabelSide.top, LabelSide.right, LabelSide.bottom, LabelSide.left],
      );
    });

    test('produces unique non-overlapping assignments capped at 12', () {
      final detections = List.generate(
        15,
        (index) => _detection(
          'object-$index',
          x: (index % 4) * 0.2,
          y: (index ~/ 4) * 0.2,
          width: 0.08 + index / 1000,
          height: 0.08,
        ),
      );

      final placements = assignObjectsToSlots(
        detections: detections,
        imageRect: imageRect,
        slots: allSlots(),
      );

      expect(placements, hasLength(maxVisibleObjects));
      expect(
        placements.map((placement) => placement.slot.id).toSet(),
        hasLength(placements.length),
      );
      for (var first = 0; first < placements.length; first++) {
        for (var second = first + 1; second < placements.length; second++) {
          expect(
            placements[first]
                .slot
                .cardRect
                .overlaps(placements[second].slot.cardRect),
            isFalse,
          );
        }
      }
    });

    test('is independent of detection and slot response order', () {
      final detections = [
        _detection('top', x: 0.45, y: 0.05),
        _detection('right', x: 0.85, y: 0.45),
        _detection('bottom', x: 0.45, y: 0.85),
        _detection('left', x: 0.05, y: 0.45),
      ];
      final slots = allSlots();

      final forward = assignObjectsToSlots(
        detections: detections,
        imageRect: imageRect,
        slots: slots,
      );
      final reversed = assignObjectsToSlots(
        detections: detections.reversed,
        imageRect: imageRect,
        slots: slots.reversed,
      );

      expect(
        reversed.map((item) => (item.detection.word, item.slot.id)),
        forward.map((item) => (item.detection.word, item.slot.id)),
      );
    });

    test('uses an adjacent edge before an opposite-edge fallback', () {
      final placements = assignObjectsToSlots(
        detections: [_detection('upper-left', x: 0.05, y: 0.05)],
        imageRect: const Rect.fromLTWH(100, 100, 200, 200),
        slots: const [
          LabelSlot(
            id: 'left-only',
            side: LabelSide.left,
            cardRect: Rect.fromLTWH(0, 100, 80, 50),
            anchorPoint: Offset(80, 125),
          ),
          LabelSlot(
            id: 'bottom-opposite',
            side: LabelSide.bottom,
            cardRect: Rect.fromLTWH(100, 320, 80, 50),
            anchorPoint: Offset(140, 320),
          ),
        ],
      );

      expect(placements.single.slot.side, LabelSide.left);
    });

    test('retains higher-priority objects when slots are limited', () {
      final slots = generatePerimeterSlots(
        overlaySize: const Size(400, 400),
        imageRect: const Rect.fromLTWH(100, 100, 200, 200),
        cardSize: const Size(180, 80),
        safeMargin: 8,
        slotGap: 8,
      );
      final placements = assignObjectsToSlots(
        detections: [
          _detection('small', width: 0.05, height: 0.05),
          _detection('large', width: 0.3, height: 0.3),
          _detection('medium', width: 0.2, height: 0.2),
        ],
        imageRect: const Rect.fromLTWH(100, 100, 200, 200),
        slots: slots,
      );

      expect(slots, hasLength(2));
      expect(
        placements.map((placement) => placement.detection.word).toSet(),
        {'large', 'medium'},
      );
    });

    test('preserves monotonic object order within every perimeter side', () {
      final detections = [
        for (final x in [0.2, 0.45, 0.7])
          _detection('top-$x', x: x, y: 0.02, width: 0.06, height: 0.06),
        for (final y in [0.2, 0.45, 0.7])
          _detection('right-$y', x: 0.88, y: y, width: 0.06, height: 0.06),
        for (final x in [0.2, 0.45, 0.7])
          _detection('bottom-$x', x: x, y: 0.88, width: 0.06, height: 0.06),
        for (final y in [0.2, 0.45, 0.7])
          _detection('left-$y', x: 0.02, y: y, width: 0.06, height: 0.06),
      ];

      final placements = assignObjectsToSlots(
        detections: detections.reversed,
        imageRect: imageRect,
        slots: allSlots().reversed,
      );

      for (final side in LabelSide.values) {
        final onSide = placements
            .where((placement) => placement.slot.side == side)
            .toList()
          ..sort((a, b) {
            final aPosition = side == LabelSide.top || side == LabelSide.bottom
                ? a.slot.cardRect.left
                : a.slot.cardRect.top;
            final bPosition = side == LabelSide.top || side == LabelSide.bottom
                ? b.slot.cardRect.left
                : b.slot.cardRect.top;
            return aPosition.compareTo(bPosition);
          });
        final objectPositions = onSide.map(
          (placement) => side == LabelSide.top || side == LabelSide.bottom
              ? placement.objectRect.center.dx
              : placement.objectRect.center.dy,
        );

        expect(onSide, hasLength(3));
        expect(
            objectPositions, orderedEquals(objectPositions.toList()..sort()));
      }
    });
  });

  group('image display coordinate mapping', () {
    test('contains a portrait image inside a landscape rect', () {
      final rect = calculateContainedImageRect(
        sourceSize: const Size(100, 200),
        availableRect: const Rect.fromLTWH(0, 0, 300, 200),
      );

      expect(rect, const Rect.fromLTWH(100, 0, 100, 200));
    });

    test('contains a landscape image inside a portrait rect', () {
      final rect = calculateContainedImageRect(
        sourceSize: const Size(200, 100),
        availableRect: const Rect.fromLTWH(0, 0, 100, 300),
      );

      expect(rect, const Rect.fromLTWH(0, 125, 100, 50));
    });

    test('maps normalized Gemini boxes into the displayed image rect', () {
      final layout = buildVocabOverlayLayout(
        overlaySize: const Size(800, 800),
        sourceImageSize: const Size(400, 200),
        cardSize: const Size(100, 60),
        safeMargin: 20,
        slotGap: 12,
        detections: [
          _detection(
            'mapped',
            x: 0.25,
            y: 0.5,
            width: 0.5,
            height: 0.25,
          ),
        ],
      );

      expect(layout.imageRect, const Rect.fromLTWH(0, 200, 800, 400));
      expect(layout.placements, hasLength(1));
      expect(
        layout.placements.single.objectRect,
        const Rect.fromLTWH(200, 400, 400, 100),
      );
    });
  });

  group('overlay layout edge cases', () {
    const overlaySize = Size(800, 800);
    const cardSize = Size(100, 60);

    VocabOverlayLayout build(
      List<VocabDetection> detections, {
      Size sourceImageSize = const Size(600, 600),
    }) {
      return buildVocabOverlayLayout(
        overlaySize: overlaySize,
        sourceImageSize: sourceImageSize,
        cardSize: cardSize,
        safeMargin: 20,
        slotGap: 12,
        detections: detections,
      );
    }

    void expectCardsSafe(VocabOverlayLayout layout) {
      final permittedRect = layout.imageRect;
      expect(layout.placements.length, lessThanOrEqualTo(maxVisibleObjects));
      for (final placement in layout.placements) {
        expect(
          placement.slot.cardRect.left,
          greaterThanOrEqualTo(permittedRect.left),
        );
        expect(
          placement.slot.cardRect.top,
          greaterThanOrEqualTo(permittedRect.top),
        );
        expect(
          placement.slot.cardRect.right,
          lessThanOrEqualTo(permittedRect.right),
        );
        expect(
          placement.slot.cardRect.bottom,
          lessThanOrEqualTo(permittedRect.bottom),
        );
        expect(permittedRect.overlaps(placement.slot.cardRect), isTrue);
      }
      for (var first = 0; first < layout.placements.length; first++) {
        for (var second = first + 1;
            second < layout.placements.length;
            second++) {
          expect(
            layout.placements[first].slot.gridArea!.overlaps(
              layout.placements[second].slot.gridArea!,
            ),
            isFalse,
          );
        }
      }
    }

    test('returns identical full placements for identical input', () {
      final detections = [
        for (var index = 0; index < 12; index++)
          _detection(
            'object-$index',
            x: (index % 4) * 0.22,
            y: (index ~/ 4) * 0.22,
            width: 0.08 + index / 1000,
            height: 0.08,
          ),
      ];

      final first = build(detections);
      final second = build(detections);

      expect(second.imageRect, first.imageRect);
      expect(
        second.placements.map(
          (item) => (
            item.detection.word,
            item.slot.id,
            item.slot.cardRect,
            item.slot.anchorPoint,
            item.objectRect,
          ),
        ),
        first.placements.map(
          (item) => (
            item.detection.word,
            item.slot.id,
            item.slot.cardRect,
            item.slot.anchorPoint,
            item.objectRect,
          ),
        ),
      );
    });

    test('hand-drawn jitter is stable, staggered, bounded, and overlap-free',
        () {
      final detections = [
        _detection('basket', x: 0.42, y: 0.4, width: 0.16, height: 0.2),
        _detection('rabbit', x: 0.12, y: 0.1, width: 0.12, height: 0.12),
        _detection('cat', x: 0.42, y: 0.08, width: 0.12, height: 0.12),
        _detection('dog', x: 0.72, y: 0.12, width: 0.12, height: 0.12),
        _detection('book', x: 0.74, y: 0.42, width: 0.12, height: 0.12),
        _detection('lamp', x: 0.7, y: 0.72, width: 0.12, height: 0.12),
        _detection('pencil', x: 0.4, y: 0.76, width: 0.12, height: 0.12),
        _detection('desk', x: 0.1, y: 0.7, width: 0.12, height: 0.12),
      ];
      VocabOverlayLayout buildWithJitter(double jitterScale) =>
          buildVocabOverlayLayout(
            overlaySize: overlaySize,
            sourceImageSize: const Size(600, 600),
            cardSize: cardSize,
            safeMargin: 20,
            slotGap: 8,
            labelJitterScale: jitterScale,
            detections: detections,
          );

      final theoretical = buildWithJitter(0);
      final first = buildWithJitter(1);
      final second = buildWithJitter(1);

      expect(
        second.placements.map(
          (item) => (item.detection.word, item.slot.cardRect),
        ),
        first.placements.map(
          (item) => (item.detection.word, item.slot.cardRect),
        ),
      );
      expect(
        first.placements.where((placement) {
          final original = theoretical.placements.singleWhere(
            (item) => item.detection.word == placement.detection.word,
          );
          return placement.slot.cardRect != original.slot.cardRect;
        }).length,
        greaterThan(1),
      );

      for (final placement in first.placements) {
        expect(
          placement.slot.cardRect.left,
          greaterThanOrEqualTo(first.imageRect.left),
        );
        expect(
          placement.slot.cardRect.top,
          greaterThanOrEqualTo(first.imageRect.top),
        );
        expect(
          placement.slot.cardRect.right,
          lessThanOrEqualTo(first.imageRect.right),
        );
        expect(
          placement.slot.cardRect.bottom,
          lessThanOrEqualTo(first.imageRect.bottom),
        );
      }
      for (var left = 0; left < first.placements.length; left++) {
        for (var right = left + 1; right < first.placements.length; right++) {
          expect(
            first.placements[left].slot.cardRect.overlaps(
              first.placements[right].slot.cardRect,
            ),
            isFalse,
          );
        }
      }

      expect(
        first.placements.every((placement) {
          final area = placement.slot.gridArea!;
          final footprint = first.grid!.rectForArea(area);
          return footprint.contains(placement.slot.cardRect.center) &&
              placement.slot.cardRect.width < footprint.width &&
              placement.slot.cardRect.height < footprint.height;
        }),
        isTrue,
      );
    });

    for (final count in [1, 2, 4, 5, 8, 9, 12, 15]) {
      test('handles $count detected objects safely', () {
        final layout = build([
          for (var index = 0; index < count; index++)
            _detection(
              'object-$index',
              x: (index % 4) * 0.22,
              y: (index ~/ 4) * 0.22,
              width: 0.08 + index / 1000,
              height: 0.08,
            ),
        ]);

        expect(layout.placements, hasLength(count.clamp(0, 12)));
        expectCardsSafe(layout);
      });
    }

    test('handles tiny boxes at corners and tightly clustered objects', () {
      final detections = [
        _detection('top-left', x: 0, y: 0, width: 0.001, height: 0.001),
        _detection(
          'top-right',
          x: 0.999,
          y: 0,
          width: 0.001,
          height: 0.001,
        ),
        _detection(
          'bottom-right',
          x: 0.999,
          y: 0.999,
          width: 0.001,
          height: 0.001,
        ),
        _detection(
          'bottom-left',
          x: 0,
          y: 0.999,
          width: 0.001,
          height: 0.001,
        ),
        for (var index = 0; index < 4; index++)
          _detection(
            'cluster-$index',
            x: 0.48 + index * 0.002,
            y: 0.48 + index * 0.002,
            width: 0.01,
            height: 0.01,
          ),
      ];

      final first = build(detections);
      final second = build(detections.reversed.toList());

      expect(first.placements, hasLength(detections.length));
      expect(
        second.placements.map((item) => (item.detection.word, item.slot.id)),
        first.placements.map((item) => (item.detection.word, item.slot.id)),
      );
      expectCardsSafe(first);
    });

    test('keeps portrait and landscape layouts inside the canvas', () {
      final detections = [
        for (var index = 0; index < 8; index++)
          _detection(
            'object-$index',
            x: (index % 4) * 0.22,
            y: (index ~/ 4) * 0.4,
          ),
      ];

      final portrait = build(
        detections,
        sourceImageSize: const Size(300, 600),
      );
      final landscape = build(
        detections,
        sourceImageSize: const Size(600, 300),
      );

      expect(portrait.placements, hasLength(detections.length));
      expect(landscape.placements, hasLength(detections.length));
      expect(portrait.imageRect.height, greaterThan(portrait.imageRect.width));
      expect(
        landscape.imageRect.width,
        greaterThan(landscape.imageRect.height),
      );
      expectCardsSafe(portrait);
      expectCardsSafe(landscape);
    });
  });

  group('calculateArrowGeometry', () {
    const placement = LabelPlacement(
      detection: VocabDetection(
        word: 'cabinet',
        phonetic: '/ˈkæbɪnət/',
        meaning: 'tủ',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
      slot: LabelSlot(
        id: 'top-0',
        side: LabelSide.top,
        cardRect: Rect.fromLTWH(80, 20, 80, 60),
        anchorPoint: Offset(120, 80),
      ),
      objectRect: Rect.fromLTWH(100, 100, 40, 50),
    );

    test('detects real quadratic Bezier intersections pairwise', () {
      const first = ArrowGeometry(
        start: Offset(0, 0),
        controlPoint: Offset(5, 5),
        end: Offset(10, 10),
        arrowHeadPoints: [],
      );
      const crossing = ArrowGeometry(
        start: Offset(0, 10),
        controlPoint: Offset(5, 5),
        end: Offset(10, 0),
        arrowHeadPoints: [],
      );
      const separate = ArrowGeometry(
        start: Offset(0, 20),
        controlPoint: Offset(5, 20),
        end: Offset(10, 20),
        arrowHeadPoints: [],
      );

      expect(quadraticBeziersIntersect(first, crossing), isTrue);
      expect(quadraticBeziersIntersect(first, separate), isFalse);
      expect(quadraticBezierLength(first), closeTo(math.sqrt(200), 0.001));
    });

    test('measures soft distance from card boundary to object boundary', () {
      final ratio = boundaryDistanceRatio(
        labelRect: const Rect.fromLTWH(0, 0, 10, 10),
        objectRect: const Rect.fromLTWH(30, 0, 10, 10),
      );

      expect(ratio, closeTo(math.sqrt(2), 0.000001));
      expect(
        boundaryDistanceRatio(
          labelRect: const Rect.fromLTWH(0, 0, 10, 10),
          objectRect: const Rect.fromLTWH(5, 5, 10, 10),
        ),
        0,
      );
    });

    test('anchors both ends to the nearest rectangle edges', () {
      final arrow = calculateArrowGeometry(
        placement: placement,
        imageCenter: const Offset(200, 200),
      );

      expect(arrow.start, const Offset(120, 80));
      expect(arrow.end.dy, placement.objectRect.top);
      expect(
        arrow.end.dx,
        inInclusiveRange(
          placement.objectRect.left,
          placement.objectRect.right,
        ),
      );
      expect(arrow.arrowHeadPoints, hasLength(3));
    });

    test('nearest-edge anchors shorten every separated compass direction', () {
      const labelRect = Rect.fromLTWH(100, 100, 40, 30);
      const objectRects = <Rect>[
        Rect.fromLTWH(105, 20, 20, 20),
        Rect.fromLTWH(180, 20, 20, 20),
        Rect.fromLTWH(180, 105, 20, 20),
        Rect.fromLTWH(180, 170, 20, 20),
        Rect.fromLTWH(105, 170, 20, 20),
        Rect.fromLTWH(20, 170, 20, 20),
        Rect.fromLTWH(20, 105, 20, 20),
        Rect.fromLTWH(20, 20, 20, 20),
      ];

      for (final objectRect in objectRects) {
        final arrow = calculateArrowGeometry(
          placement: LabelPlacement(
            detection: placement.detection,
            slot: const LabelSlot(
              id: 'candidate',
              side: LabelSide.top,
              cardRect: labelRect,
              // Deliberately stale: rendering must derive anchors from rects.
              anchorPoint: Offset.zero,
            ),
            objectRect: objectRect,
          ),
          imageCenter: const Offset(100, 100),
        );
        final edgeDistance = (arrow.end - arrow.start).distance;
        final centerDistance = (objectRect.center - labelRect.center).distance;

        expect(edgeDistance, lessThan(centerDistance));
        expect(labelRect.inflate(0.001).contains(arrow.start), isTrue);
        expect(labelRect.deflate(0.001).contains(arrow.start), isFalse);
        expect(objectRect.inflate(0.001).contains(arrow.end), isTrue);
        expect(objectRect.deflate(0.001).contains(arrow.end), isFalse);
      }
    });

    test('nearest-edge anchors handle intersecting and contained rectangles',
        () {
      ArrowGeometry arrowFor(Rect labelRect, Rect objectRect) =>
          calculateArrowGeometry(
            placement: LabelPlacement(
              detection: placement.detection,
              slot: LabelSlot(
                id: 'overlap',
                side: LabelSide.top,
                cardRect: labelRect,
                anchorPoint: Offset.zero,
              ),
              objectRect: objectRect,
            ),
            imageCenter: const Offset(100, 100),
          );

      final intersecting = arrowFor(
        const Rect.fromLTWH(0, 0, 20, 20),
        const Rect.fromLTWH(10, 10, 20, 20),
      );
      expect(intersecting.start, intersecting.end);

      final contained = arrowFor(
        const Rect.fromLTWH(10, 10, 10, 10),
        const Rect.fromLTWH(0, 0, 40, 40),
      );
      expect((contained.end - contained.start).distance, 10);
    });

    test('offsets the control point by 15 percent toward image center', () {
      final arrow = calculateArrowGeometry(
        placement: placement,
        imageCenter: const Offset(200, 200),
      );
      final midpoint = (arrow.start + arrow.end) / 2;
      final expectedOffset = (arrow.end - arrow.start).distance * 0.15;

      expect(
        (arrow.controlPoint - midpoint).distance,
        closeTo(expectedOffset, 0.000001),
      );
      final reflectedControl = midpoint * 2 - arrow.controlPoint;
      expect(
        (arrow.controlPoint - const Offset(200, 200)).distanceSquared,
        lessThanOrEqualTo(
          (reflectedControl - const Offset(200, 200)).distanceSquared,
        ),
      );
    });

    test('returns identical geometry for identical layout input', () {
      ArrowGeometry calculate() => calculateArrowGeometry(
            placement: placement,
            imageCenter: const Offset(200, 200),
          );

      final first = calculate();
      final second = calculate();

      expect(second.start, first.start);
      expect(second.end, first.end);
      expect(second.controlPoint, first.controlPoint);
      expect(second.arrowHeadPoints, first.arrowHeadPoints);
    });

    test('detects a segment crossing a rectangular obstacle', () {
      const obstacle = Rect.fromLTWH(105, 150, 30, 80);

      expect(
        segmentIntersectsRect(
          const Offset(120, 80),
          const Offset(120, 300),
          obstacle,
        ),
        isTrue,
      );
      expect(
        segmentIntersectsRect(
          const Offset(20, 80),
          const Offset(20, 300),
          obstacle,
        ),
        isFalse,
      );
    });

    test('chooses a deterministic detour around another label or object', () {
      const distantPlacement = LabelPlacement(
        detection: VocabDetection(
          word: 'cabinet',
          phonetic: '/ˈkæbɪnət/',
          meaning: 'tủ',
          x: 0,
          y: 0,
          w: 0.1,
          h: 0.1,
        ),
        slot: LabelSlot(
          id: 'top-0',
          side: LabelSide.top,
          cardRect: Rect.fromLTWH(80, 20, 80, 60),
          anchorPoint: Offset(120, 80),
        ),
        objectRect: Rect.fromLTWH(100, 300, 40, 50),
      );
      const obstacle = Rect.fromLTWH(105, 150, 30, 80);

      ArrowGeometry calculate() => calculateArrowGeometry(
            placement: distantPlacement,
            imageCenter: const Offset(200, 200),
            obstacles: const [obstacle],
            routingBounds: const Rect.fromLTWH(0, 0, 400, 400),
          );

      final first = calculate();
      final second = calculate();
      final midpoint = (first.start + first.end) / 2;

      expect(
        (first.controlPoint - midpoint).distance,
        greaterThan((first.end - first.start).distance * 0.15),
      );
      expect(
        quadraticBezierIntersectsRect(
          geometry: first,
          obstacle: obstacle,
        ),
        isFalse,
      );
      expect(second.controlPoint, first.controlPoint);
    });
  });
}

VocabDetection _detection(
  String word, {
  String? phonetic,
  String? meaning,
  double x = 0,
  double y = 0,
  double width = 0.1,
  double height = 0.1,
}) {
  return VocabDetection(
    word: word,
    phonetic: phonetic ?? '/$word/',
    meaning: meaning ?? 'meaning $word',
    x: x,
    y: y,
    w: width,
    h: height,
  );
}
