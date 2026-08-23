import 'dart:collection';
import 'dart:math' as math;

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/vocab_scan/domain/forbidden_zone_builder.dart';
import 'package:capy_vocab/features/vocab_scan/domain/image_rect_calculator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_angle_ranker.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_candidate_generator.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_connector_geometry.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_placement_solver.dart';
import 'package:capy_vocab/features/vocab_scan/domain/label_size_measurer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/wardrobe_words.dart';
import '../fixtures/task13b_jacket_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const measurer = LabelSizeMeasurer();

  test('Fallback 1 places a compact card when the full card cannot fit', () {
    const word = VocabDetection(
      word: 'a',
      phonetic: '',
      meaning: 'một từ',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

    final result = solve(
      words: const [word],
      labelSizes: const [LabelSize(width: 190, height: 190)],
      anchorBoxes: [
        Rect.fromCenter(
          center: const Offset(100, 100),
          width: 20,
          height: 20,
        ),
      ],
      forbiddenZones: const [],
      canvasSize: const Size(200, 200),
      measurer: measurer,
      compactStyleConfig: _tinyCompactStyle,
    );

    expect(result, hasLength(1));
    expect(result.single.quality, PlacementQuality.fallbackSmallerFont);
    expect(result.single.overlapsForbiddenZone, isFalse);
    expect(result.single.overlapsPlacedLabel, isFalse);
  });

  test('Fallback 2 accepts the first compact candidate at 20 percent overlap',
      () {
    const words = [
      VocabDetection(
        word: 'a',
        phonetic: '',
        meaning: 'first',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
      VocabDetection(
        word: 'bb',
        phonetic: '',
        meaning: 'second',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
    ];
    final result = solve(
      words: words,
      labelSizes: const [
        LabelSize(width: 280, height: 300),
        LabelSize(width: 40, height: 20),
      ],
      anchorBoxes: [
        Rect.fromCenter(
          center: const Offset(200, 200),
          width: 20,
          height: 20,
        ),
        Rect.fromCenter(
          center: const Offset(352, 200),
          width: 20,
          height: 20,
        ),
      ],
      forbiddenZones: const [],
      canvasSize: const Size(400, 400),
      measurer: const _FixedLabelSizeMeasurer(
        LabelSize(width: 40, height: 20),
      ),
      compactStyleConfig: _twentyPixelCompactStyle,
    );

    expect(result, hasLength(2));
    expect(result.first.quality, PlacementQuality.ideal);
    expect(result.last.quality, PlacementQuality.fallbackAllowOverlap);
    expect(
      _overlapRatio(result.first.labelRect, result.last.labelRect),
      closeTo(0.2, 0.000001),
    );
    expect(result.last.overlapsPlacedLabel, isFalse);
  });

  test('Fallback 3 preserves the word and flags unavoidable forbidden overlap',
      () {
    const word = VocabDetection(
      word: 'a',
      phonetic: '',
      meaning: 'một từ',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );
    const canvasSize = Size(200, 200);

    final result = solve(
      words: const [word],
      labelSizes: const [LabelSize(width: 190, height: 190)],
      anchorBoxes: [
        Rect.fromCenter(
          center: const Offset(100, 100),
          width: 20,
          height: 20,
        ),
      ],
      forbiddenZones: const [Rect.fromLTWH(0, 0, 200, 200)],
      canvasSize: canvasSize,
      measurer: measurer,
      compactStyleConfig: _tinyCompactStyle,
    );

    expect(result, hasLength(1));
    expect(result.single.quality, PlacementQuality.fallbackEdge);
    expect(result.single.overlapsForbiddenZone, isTrue);
    expect(result.single.overlapsPlacedLabel, isFalse);
  });

  test('Fallback 3 prefers a safe edge before allowing forbidden overlap', () {
    const word = VocabDetection(
      word: 'a',
      phonetic: '',
      meaning: 'one word',
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

    final result = solve(
      words: const [word],
      labelSizes: const [LabelSize(width: 390, height: 390)],
      anchorBoxes: [
        Rect.fromCenter(
          center: const Offset(200, 200),
          width: 20,
          height: 20,
        ),
      ],
      forbiddenZones: const [Rect.fromLTWH(40, 0, 320, 400)],
      canvasSize: const Size(400, 400),
      measurer: const _FixedLabelSizeMeasurer(
        LabelSize(width: 20, height: 20),
      ),
      compactStyleConfig: _tinyCompactStyle,
    );

    expect(result, hasLength(1));
    expect(result.single.quality, PlacementQuality.fallbackEdge);
    expect(result.single.labelRect.right, lessThanOrEqualTo(40));
    expect(result.single.overlapsForbiddenZone, isFalse);
    expect(result.single.overlapsPlacedLabel, isFalse);
  });

  test('Fallback 3 flags placed-label overlap only after y search is exhausted',
      () {
    const words = [
      VocabDetection(
        word: 'a',
        phonetic: '',
        meaning: 'first',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
      VocabDetection(
        word: 'b',
        phonetic: '',
        meaning: 'second',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
    ];
    final compactSizes = words
        .map((word) => measurer.measure(word, _tinyCompactStyle))
        .toList(growable: false);
    final canvasSize = Size(
      math.max(compactSizes[0].width, compactSizes[1].width) + 12,
      math.max(compactSizes[0].height, compactSizes[1].height),
    );
    final forbiddenCanvas = Offset.zero & canvasSize;

    final result = solve(
      words: words,
      labelSizes: [
        LabelSize(width: canvasSize.width * 2, height: canvasSize.height * 2),
        LabelSize(width: canvasSize.width * 2, height: canvasSize.height * 2),
      ],
      anchorBoxes: [
        Rect.fromCenter(
          center: canvasSize.center(Offset.zero),
          width: 2,
          height: 2,
        ),
        Rect.fromCenter(
          center: canvasSize.center(Offset.zero),
          width: 2,
          height: 2,
        ),
      ],
      forbiddenZones: [forbiddenCanvas],
      canvasSize: canvasSize,
      measurer: measurer,
      compactStyleConfig: _tinyCompactStyle,
    );

    expect(result, hasLength(2));
    expect(
      result.map((placed) => placed.quality),
      everyElement(PlacementQuality.fallbackEdge),
    );
    expect(result.first.overlapsPlacedLabel, isFalse);
    expect(result.last.overlapsPlacedLabel, isTrue);
    expect(_overlapRatio(result.first.labelRect, result.last.labelRect), 1.0);
  });

  test(
      'area sorting preserves each word-anchor identity instead of output index',
      () {
    const words = [
      VocabDetection(
        word: 'small',
        phonetic: '',
        meaning: 'small',
        x: 0,
        y: 0,
        w: 0.1,
        h: 0.1,
      ),
      VocabDetection(
        word: 'large-first',
        phonetic: '',
        meaning: 'large',
        x: 0,
        y: 0,
        w: 0.2,
        h: 0.2,
      ),
      VocabDetection(
        word: 'large-second',
        phonetic: '',
        meaning: 'large',
        x: 0,
        y: 0,
        w: 0.2,
        h: 0.2,
      ),
    ];
    const anchorBoxes = [
      Rect.fromLTWH(50, 50, 10, 10),
      Rect.fromLTWH(200, 200, 20, 20),
      Rect.fromLTWH(600, 600, 20, 20),
    ];

    final result = solve(
      words: words,
      labelSizes: const [
        LabelSize(width: 20, height: 10),
        LabelSize(width: 20, height: 10),
        LabelSize(width: 20, height: 10),
      ],
      anchorBoxes: anchorBoxes,
      forbiddenZones: const [],
      canvasSize: const Size(1000, 1000),
      measurer: measurer,
      compactStyleConfig: _tinyCompactStyle,
    );

    expect(
      result.map((placed) => placed.word.word),
      ['large-first', 'large-second', 'small'],
    );
    expect(
      result.map((placed) => placed.anchorBox),
      [anchorBoxes[1], anchorBoxes[2], anchorBoxes[0]],
    );
  });

  test('rejects the nearest candidate when its connector crosses another box',
      () {
    final words = [_word('A'), _word('B'), _word('C')];
    const labelSize = LabelSize(width: 10, height: 10);
    const anchorBoxes = [
      Rect.fromLTWH(80, 80, 40, 40),
      Rect.fromLTWH(125, 95, 5, 10),
      Rect.fromLTWH(260, 260, 10, 10),
    ];
    const canvasSize = Size(400, 400);
    final nearestCandidate = generateCandidates(
          anchorBox: anchorBoxes[0],
          labelSize: const Size(10, 10),
          canvasSize: canvasSize,
        ).first &
        const Size(10, 10);
    final blockedConnector = computeConnectorPath(
      labelRect: nearestCandidate,
      targetBox: anchorBoxes[0],
    );
    expect(
      segmentIntersectsRect(
        from: blockedConnector.from,
        to: blockedConnector.to,
        rect: anchorBoxes[1],
      ),
      isTrue,
    );

    final result = solve(
      words: words,
      labelSizes: const [labelSize, labelSize, labelSize],
      anchorBoxes: anchorBoxes,
      forbiddenZones: anchorBoxes,
      canvasSize: canvasSize,
      measurer: const _FixedLabelSizeMeasurer(labelSize),
      compactStyleConfig: _tinyCompactStyle,
    );

    final placedA = result.singleWhere((placed) => placed.word.word == 'A');
    final selectedConnector = computeConnectorPath(
      labelRect: placedA.labelRect,
      targetBox: placedA.anchorBox,
    );
    expect(placedA.quality, PlacementQuality.ideal);
    expect(placedA.labelRect, isNot(nearestCandidate));
    expect(
      segmentIntersectsRect(
        from: selectedConnector.from,
        to: selectedConnector.to,
        rect: anchorBoxes[1],
      ),
      isFalse,
    );
  });

  test('connector exclusion follows original identity after area sorting', () {
    final words = [_word('small'), _word('large'), _word('medium')];
    const anchorBoxes = [
      Rect.fromLTWH(95, 95, 10, 10),
      Rect.fromLTWH(280, 80, 40, 40),
      Rect.fromLTWH(490, 90, 20, 20),
    ];

    final result = solve(
      words: words,
      labelSizes: const [
        LabelSize(width: 10, height: 10),
        LabelSize(width: 10, height: 10),
        LabelSize(width: 10, height: 10),
      ],
      anchorBoxes: anchorBoxes,
      forbiddenZones: anchorBoxes,
      canvasSize: const Size(700, 300),
      measurer: const _FixedLabelSizeMeasurer(
        LabelSize(width: 10, height: 10),
      ),
      compactStyleConfig: _tinyCompactStyle,
    );

    expect(result.map((placed) => placed.word.word), [
      'large',
      'medium',
      'small',
    ]);
    expect(
      result.map((placed) => placed.quality),
      everyElement(PlacementQuality.ideal),
    );
    for (final placed in result) {
      final originalIndex = words.indexWhere(
        (word) => identical(word, placed.word),
      );
      final connector = computeConnectorPath(
        labelRect: placed.labelRect,
        targetBox: placed.anchorBox,
      );
      expect(
        segmentIntersectsRect(
          from: connector.from,
          to: connector.to,
          rect: anchorBoxes[originalIndex],
        ),
        isTrue,
        reason: 'The connector must touch its own original-index zone.',
      );
    }
  });

  test(
      'fallback reuses one ranking object per word and invalidates it for the next word',
      () {
    final words = [_word('A'), _word('B')];
    const anchorBoxes = [
      Rect.fromLTWH(50, 90, 20, 20),
      Rect.fromLTWH(130, 90, 20, 20),
    ];
    final calls = <_RankingCall>[];

    List<double> trackingRanker({
      required Rect anchorBox,
      required List<double> angleDegrees,
      required List<Rect> forbiddenZones,
      required List<Rect> placedLabels,
      required Size canvasSize,
    }) {
      final angles = _TrackingAngleList(
        anchorBox.center.dx < canvasSize.width / 2
            ? angleDegrees
            : angleDegrees.reversed.toList(growable: false),
      );
      calls.add(
        _RankingCall(
          anchorBox: anchorBox,
          placedLabelCount: placedLabels.length,
          angles: angles,
        ),
      );
      return angles;
    }

    final result = solve(
      words: words,
      labelSizes: const [
        LabelSize(width: 190, height: 190),
        LabelSize(width: 190, height: 190),
      ],
      anchorBoxes: anchorBoxes,
      forbiddenZones: const [
        Rect.fromLTWH(0, 0, 200, 200),
        Rect.fromLTWH(0, 0, 200, 200),
      ],
      canvasSize: const Size(200, 200),
      measurer: const _FixedLabelSizeMeasurer(
        LabelSize(width: 20, height: 20),
      ),
      compactStyleConfig: _tinyCompactStyle,
      angleRanker: trackingRanker,
    );

    final callsForA = calls
        .where((call) => call.anchorBox == anchorBoxes[0])
        .toList(growable: false);
    final callsForB = calls
        .where((call) => call.anchorBox == anchorBoxes[1])
        .toList(growable: false);
    expect(result, hasLength(2));
    expect(callsForA, hasLength(2));
    expect(callsForB, hasLength(2));
    expect(callsForA.map((call) => call.placedLabelCount), [0, 0]);
    expect(callsForB.map((call) => call.placedLabelCount), [0, 1]);

    final fallbackAnglesA = callsForA.last.angles;
    final fallbackAnglesB = callsForB.last.angles;
    // generateCandidates iterates the same angle object once per ring. Four
    // fallback searches x five rings prove that one cached object was reused,
    // including the nested-target-safe pass added by Task 13b.
    expect(fallbackAnglesA.iteratorRequests, 20);
    expect(fallbackAnglesB.iteratorRequests, 20);
    expect(identical(fallbackAnglesA, fallbackAnglesB), isFalse);
    expect(fallbackAnglesA, isNot(equals(fallbackAnglesB)));
  });

  test('wardrobe ranking cache reduces calls from 16 to 14', () {
    final scenario = _buildScenario(
      name: 'wardrobe-400x800',
      canvasSize: const Size(400, 800),
      normalizedBoxes: wardrobeNormalizedBoxes,
    );
    var rankCallCount = 0;

    final result = solve(
      words: scenario.words,
      labelSizes: scenario.labelSizes,
      anchorBoxes: scenario.anchorBoxes,
      forbiddenZones: scenario.forbiddenZones,
      canvasSize: scenario.canvasSize,
      measurer: const LabelSizeMeasurer(),
      compactStyleConfig: _compactStyle,
      angleRanker: ({
        required anchorBox,
        required angleDegrees,
        required forbiddenZones,
        required placedLabels,
        required canvasSize,
      }) {
        rankCallCount++;
        return _task11Ranker(
          anchorBox: anchorBox,
          angleDegrees: angleDegrees,
          forbiddenZones: forbiddenZones,
          placedLabels: placedLabels,
          canvasSize: canvasSize,
        );
      },
    );

    expect(result, hasLength(scenario.words.length));
    expect(rankCallCount, 14);
  });

  test('synthetic wardrobe jacket stays clear of every other connector', () {
    // Coverage for the production validation matrix, not a reproduction of the
    // original photo: these fixtures use the synthetic wardrobeWords grid.
    final scenarios = [
      _buildScenario(
        name: 'wardrobe-400x800',
        canvasSize: const Size(400, 800),
        normalizedBoxes: wardrobeNormalizedBoxes,
      ),
      _buildScenario(
        name: 'top-edge-wardrobe-400x400',
        canvasSize: const Size(400, 400),
        normalizedBoxes: _topEdgeWardrobeBoxes,
      ),
    ];

    for (final scenario in scenarios) {
      final result = _solveScenario(scenario);
      final jacket =
          result.singleWhere((placed) => placed.word.word == 'jacket');
      final jacketConnector = computeConnectorPath(
        labelRect: jacket.labelRect,
        targetBox: jacket.anchorBox,
      );

      for (final other
          in result.where((placed) => placed.word.word != 'jacket')) {
        final otherConnector = computeConnectorPath(
          labelRect: other.labelRect,
          targetBox: other.anchorBox,
        );
        expect(
          segmentIntersectsRect(
            from: otherConnector.from,
            to: otherConnector.to,
            rect: jacket.labelRect,
          ),
          isFalse,
          reason: '${scenario.name}: jacket must not cover the '
              '${other.word.word} connector',
        );
        expect(
          segmentIntersectsRect(
            from: jacketConnector.from,
            to: jacketConnector.to,
            rect: other.labelRect,
          ),
          isFalse,
          reason: '${scenario.name}: jacket connector must not cross the '
              '${other.word.word} label',
        );
        expect(
          segmentsIntersect(
            firstFrom: jacketConnector.from,
            firstTo: jacketConnector.to,
            secondFrom: otherConnector.from,
            secondTo: otherConnector.to,
          ),
          isFalse,
          reason: '${scenario.name}: jacket connector must not cross '
              '${other.word.word}',
        );
      }
    }
  });

  test('wardrobe allow-overlap hanger has no final connector conflict', () {
    final scenario = _buildScenario(
      name: 'wardrobe-400x800',
      canvasSize: const Size(400, 800),
      normalizedBoxes: wardrobeNormalizedBoxes,
    );
    final result = _solveScenario(scenario);
    final hanger = result.singleWhere((placed) => placed.word.word == 'hanger');
    final hangerConnector = computeConnectorPath(
      labelRect: hanger.labelRect,
      targetBox: hanger.anchorBox,
    );
    final ownIndex = scenario.words.indexWhere((word) => word.word == 'hanger');

    expect(hanger.quality, PlacementQuality.fallbackAllowOverlap);
    for (final (index, zone) in scenario.forbiddenZones.indexed) {
      if (index == ownIndex) continue;
      expect(
        segmentIntersectsRect(
          from: hangerConnector.from,
          to: hangerConnector.to,
          rect: zone,
        ),
        isFalse,
        reason: 'hanger connector must avoid ${scenario.words[index].word}',
      );
    }
    for (final other
        in result.where((placed) => placed.word.word != 'hanger')) {
      expect(
        connectorConflictsWithPlacedGeometry(
          candidateLabelRect: hanger.labelRect,
          candidateConnector: hangerConnector,
          placedLabelRect: other.labelRect,
          placedConnector: computeConnectorPath(
            labelRect: other.labelRect,
            targetBox: other.anchorBox,
          ),
        ),
        isFalse,
        reason: 'hanger must stay clear of ${other.word.word}',
      );
    }
  });

  test('Task 13b original-layout approximation keeps jacket connector-safe',
      () {
    final scenario = _buildTask13bJacketScenario();
    final result = _solveScenario(scenario);
    final jacket = result.singleWhere(
      (placed) => placed.word.word == 'jacket',
    );
    final geometry = _candidateGeometry(jacket);
    final conflicts = _placementGeometryConflicts(
      placed: jacket,
      allPlacements: result,
    );
    final allConflicts = [
      for (final placed in result)
        ..._placementGeometryConflicts(
          placed: placed,
          allPlacements: result,
        ).map((conflict) => '${placed.word.word}:$conflict'),
    ];
    final wardrobe = result.singleWhere(
      (placed) => placed.word.word == 'wardrobe',
    );
    final curtain = result.singleWhere(
      (placed) => placed.word.word == 'curtain',
    );

    debugPrint(
      'TASK13B_AFTER jacketRect=('
      '${jacket.labelRect.left.toStringAsFixed(6)},'
      '${jacket.labelRect.top.toStringAsFixed(6)},'
      '${jacket.labelRect.right.toStringAsFixed(6)},'
      '${jacket.labelRect.bottom.toStringAsFixed(6)}) '
      'angle=${geometry.angleDegrees.toStringAsFixed(0)} '
      'ring=${geometry.ringFactor.toStringAsFixed(1)} '
      'quality=${jacket.quality.name} conflicts=$conflicts',
    );
    expect(result, hasLength(task13bJacketWords.length));
    expect(
      scenario.words.map((word) => word.word),
      ['wardrobe', 'curtain', 'fan', 'box', 'jacket'],
    );
    expect(scenario.anchorBoxes[2].overlaps(scenario.anchorBoxes[1]), isTrue);
    expect(scenario.anchorBoxes[4].overlaps(scenario.anchorBoxes[0]), isTrue);
    expect(
      scenario.anchorBoxes[4].center.dx,
      greaterThan(scenario.anchorBoxes[0].center.dx),
    );
    expect(
      (scenario.anchorBoxes[4].top - scenario.anchorBoxes[0].top).abs(),
      lessThan(4),
    );
    expect(
      scenario.anchorBoxes[3].center.dy,
      greaterThan(scenario.anchorBoxes[0].center.dy),
    );
    expect(
      wardrobe.labelRect.center.dy,
      lessThan(wardrobe.anchorBox.center.dy),
    );
    expect(
      curtain.labelRect.center.dy,
      lessThan(curtain.anchorBox.center.dy),
    );
    expect(jacket.labelRect.left, closeTo(156.409928, 0.02));
    expect(jacket.labelRect.top, closeTo(187.209928, 0.02));
    expect(jacket.labelRect.right, closeTo(212.409928, 0.02));
    expect(jacket.labelRect.bottom, closeTo(225.209928, 0.02));
    expect(geometry.angleDegrees, closeTo(225, 1e-9));
    expect(geometry.ringFactor, closeTo(1, 1e-9));
    expect(jacket.quality, PlacementQuality.fallbackAllowOverlap);
    expect(conflicts, isEmpty);
    expect(allConflicts, isEmpty);
    expect(_qualityCounts(result), [0, 0, 3, 2]);
    expect(_strictConnectorCrossings(scenario, result), 0);
  });

  test('reports wardrobe, crowded, and small-canvas evidence plus performance',
      () {
    final scenarios = [
      _buildScenario(
        name: 'wardrobe-400x800',
        canvasSize: const Size(400, 800),
        normalizedBoxes: wardrobeNormalizedBoxes,
      ),
      _buildScenario(
        name: 'crowded-center-400x800',
        canvasSize: const Size(400, 800),
        normalizedBoxes: _crowdedBoxes,
      ),
      _buildScenario(
        name: 'scattered-small-300x500',
        canvasSize: const Size(300, 500),
        normalizedBoxes: _smallCanvasBoxes,
      ),
    ];
    const expectedQualityCounts = [
      [9, 1, 1, 1],
      [4, 0, 8, 0],
      [10, 1, 0, 1],
    ];

    for (final (scenarioIndex, scenario) in scenarios.indexed) {
      final result = _solveScenario(scenario);
      _verifyAndPrintScenario(scenario, result);
      for (final (qualityIndex, quality) in PlacementQuality.values.indexed) {
        expect(
          result.where((placed) => placed.quality == quality),
          hasLength(expectedQualityCounts[scenarioIndex][qualityIndex]),
        );
      }
    }
  });

  test('dense wardrobe with a small edge object uses shorter connectors', () {
    // Captured from the Task 10 fixed-angle solver on this exact fixture.
    const task10AverageDistance = 33.6241;
    final scenario = _buildScenario(
      name: 'dense-wardrobe-edge-400x800',
      canvasSize: const Size(400, 800),
      normalizedBoxes: _denseWardrobeEdgeBoxes,
    );
    final result = _solveScenario(scenario);
    final averageDistance = _averageConnectorLength(result);
    final reductionPercent =
        (task10AverageDistance - averageDistance) * 100 / task10AverageDistance;

    debugPrint(
      'TASK11_DISTANCE dense-wardrobe-edge-400x800 '
      'task10Average=${task10AverageDistance.toStringAsFixed(4)} '
      'task11Average=${averageDistance.toStringAsFixed(4)} '
      'reduction=${reductionPercent.toStringAsFixed(2)}%',
    );
    expect(result, hasLength(scenario.words.length));
    expect(averageDistance, lessThan(task10AverageDistance));
  });

  test('compares center-bias weights on a crowded top-edge wardrobe', () {
    final scenario = _buildScenario(
      name: 'top-edge-wardrobe-400x400',
      canvasSize: const Size(400, 400),
      normalizedBoxes: _topEdgeWardrobeBoxes,
    );
    final task11 = solve(
      words: scenario.words,
      labelSizes: scenario.labelSizes,
      anchorBoxes: scenario.anchorBoxes,
      forbiddenZones: scenario.forbiddenZones,
      canvasSize: scenario.canvasSize,
      measurer: const LabelSizeMeasurer(),
      compactStyleConfig: _compactStyle,
      angleRanker: _task11Ranker,
    );
    final conservative = solve(
      words: scenario.words,
      labelSizes: scenario.labelSizes,
      anchorBoxes: scenario.anchorBoxes,
      forbiddenZones: scenario.forbiddenZones,
      canvasSize: scenario.canvasSize,
      measurer: const LabelSizeMeasurer(),
      compactStyleConfig: _compactStyle,
      angleRanker: _centerBiasRanker(0.35),
    );
    final strong = solve(
      words: scenario.words,
      labelSizes: scenario.labelSizes,
      anchorBoxes: scenario.anchorBoxes,
      forbiddenZones: scenario.forbiddenZones,
      canvasSize: scenario.canvasSize,
      measurer: const LabelSizeMeasurer(),
      compactStyleConfig: _compactStyle,
      angleRanker: _centerBiasRanker(0.60),
    );
    final task11Distance = _averageConnectorLength(task11);
    final conservativeDistance = _averageConnectorLength(conservative);
    final strongDistance = _averageConnectorLength(strong);
    final improvementPercent =
        (task11Distance - conservativeDistance) * 100 / task11Distance;
    final task11Wardrobe = task11.singleWhere(
      (placed) => placed.word.word == 'wardrobe',
    );
    final task12Wardrobe = conservative.singleWhere(
      (placed) => placed.word.word == 'wardrobe',
    );
    final centerDirection = (Offset.zero & scenario.canvasSize).center -
        task11Wardrobe.anchorBox.center;
    final task11WardrobeAlignment = centerAlignmentScore(
      candidateDirection:
          task11Wardrobe.labelRect.center - task11Wardrobe.anchorBox.center,
      anchorToCanvasCenter: centerDirection,
    );
    final task12WardrobeAlignment = centerAlignmentScore(
      candidateDirection:
          task12Wardrobe.labelRect.center - task12Wardrobe.anchorBox.center,
      anchorToCanvasCenter: centerDirection,
    );

    debugPrint(
      'TASK12_WEIGHT_COMPARISON '
      'task11Distance=${task11Distance.toStringAsFixed(4)} '
      'w1.0_w0.35=${conservativeDistance.toStringAsFixed(4)} '
      'w1.0_w0.60=${strongDistance.toStringAsFixed(4)} '
      'improvement=${improvementPercent.toStringAsFixed(2)}% '
      'wardrobeAlignment=${task11WardrobeAlignment.toStringAsFixed(4)}->'
      '${task12WardrobeAlignment.toStringAsFixed(4)}',
    );
    expect(conservative, hasLength(scenario.words.length));
    expect(strong, hasLength(scenario.words.length));
    expect(conservativeDistance, lessThan(task11Distance));
    expect(strongDistance, closeTo(conservativeDistance, 1e-9));
    expect(task12WardrobeAlignment, greaterThan(task11WardrobeAlignment));
    // Center bias improves one label from fallbackEdge to
    // fallbackAllowOverlap; the gate is "no worse", not exact equality.
    expect(_qualityCounts(task11), [5, 1, 4, 2]);
    expect(_qualityCounts(conservative), [5, 1, 5, 1]);
    expect(_qualityCounts(strong), [5, 1, 5, 1]);
    expect(_strictConnectorCrossings(scenario, conservative), 0);
    expect(_strictConnectorCrossings(scenario, strong), 0);
  });

  test('benchmarks solve for N=15', () {
    final benchmarkScenario = _buildBenchmarkScenario15();
    for (var warmUp = 0; warmUp < 20; warmUp++) {
      _solveScenario(benchmarkScenario);
    }
    const iterations = 100;
    final stopwatch = Stopwatch()..start();
    for (var iteration = 0; iteration < iterations; iteration++) {
      _solveScenario(benchmarkScenario);
    }
    stopwatch.stop();
    final averageMicroseconds = stopwatch.elapsedMicroseconds / iterations;
    debugPrint(
      'SOLVER_PERFORMANCE N=15 iterations=$iterations '
      'average=${averageMicroseconds.toStringAsFixed(2)}us',
    );
    expect(averageMicroseconds.isFinite, isTrue);
    expect(averageMicroseconds, greaterThanOrEqualTo(0));
  });
}

_Scenario _buildBenchmarkScenario15() {
  final words = List<VocabDetection>.generate(15, (index) {
    final source = wardrobeWords[index % wardrobeWords.length];
    final box = _benchmarkBoxes15[index];
    return VocabDetection(
      word: '${source.word}-$index',
      phonetic: source.phonetic,
      meaning: source.meaning,
      x: box.left,
      y: box.top,
      w: box.width,
      h: box.height,
    );
  });
  const sourceImageSize = Size(400, 400);
  const canvasSize = Size(400, 800);
  final imageRect = ImageRectCalculator.calculate(
    sourceImageSize: sourceImageSize,
    canvasSize: canvasSize,
  );
  return _Scenario(
    name: 'benchmark-15-400x800',
    words: words,
    labelSizes: const LabelSizeMeasurer().measureAll(words, _fullStyle),
    anchorBoxes: words
        .map(
          (word) => ImageRectCalculator.detectionRect(
            detection: word,
            imageRect: imageRect,
          ),
        )
        .toList(growable: false),
    forbiddenZones: ForbiddenZoneBuilder.build(
      words: words,
      sourceImageSize: sourceImageSize,
      canvasSize: canvasSize,
    ),
    canvasSize: canvasSize,
  );
}

_Scenario _buildTask13bJacketScenario({
  List<Rect> normalizedBoxes = task13bJacketNormalizedBoxes,
}) {
  final words = List<VocabDetection>.generate(task13bJacketWords.length, (
    index,
  ) {
    final source = task13bJacketWords[index];
    final box = normalizedBoxes[index];
    return VocabDetection(
      number: source.number,
      word: source.word,
      phonetic: source.phonetic,
      meaning: source.meaning,
      x: box.left,
      y: box.top,
      w: box.width,
      h: box.height,
    );
  }, growable: false);
  const sourceImageSize = task13bJacketCanvasSize;
  const canvasSize = task13bJacketCanvasSize;
  final imageRect = ImageRectCalculator.calculate(
    sourceImageSize: sourceImageSize,
    canvasSize: canvasSize,
  );
  return _Scenario(
    name: 'task13b-original-layout-approximation-400x800',
    words: words,
    labelSizes: const LabelSizeMeasurer().measureAll(words, _fullStyle),
    anchorBoxes: words
        .map(
          (word) => ImageRectCalculator.detectionRect(
            detection: word,
            imageRect: imageRect,
          ),
        )
        .toList(growable: false),
    forbiddenZones: ForbiddenZoneBuilder.build(
      words: words,
      sourceImageSize: sourceImageSize,
      canvasSize: canvasSize,
    ),
    canvasSize: canvasSize,
  );
}

_Scenario _buildScenario({
  required String name,
  required Size canvasSize,
  required List<Rect> normalizedBoxes,
}) {
  final words = List<VocabDetection>.generate(wardrobeWords.length, (index) {
    final source = wardrobeWords[index];
    final box = normalizedBoxes[index];
    return VocabDetection(
      word: source.word,
      phonetic: source.phonetic,
      meaning: source.meaning,
      x: box.left,
      y: box.top,
      w: box.width,
      h: box.height,
    );
  });
  const sourceImageSize = Size(400, 400);
  final imageRect = ImageRectCalculator.calculate(
    sourceImageSize: sourceImageSize,
    canvasSize: canvasSize,
  );
  return _Scenario(
    name: name,
    words: words,
    labelSizes: const LabelSizeMeasurer().measureAll(words, _fullStyle),
    anchorBoxes: words
        .map(
          (word) => ImageRectCalculator.detectionRect(
            detection: word,
            imageRect: imageRect,
          ),
        )
        .toList(growable: false),
    forbiddenZones: ForbiddenZoneBuilder.build(
      words: words,
      sourceImageSize: sourceImageSize,
      canvasSize: canvasSize,
    ),
    canvasSize: canvasSize,
  );
}

List<PlacedLabel> _solveScenario(_Scenario scenario) {
  return solve(
    words: scenario.words,
    labelSizes: scenario.labelSizes,
    anchorBoxes: scenario.anchorBoxes,
    forbiddenZones: scenario.forbiddenZones,
    canvasSize: scenario.canvasSize,
    measurer: const LabelSizeMeasurer(),
    compactStyleConfig: _compactStyle,
  );
}

({double angleDegrees, double ringFactor}) _candidateGeometry(
  PlacedLabel placed,
) {
  final offset = placed.labelRect.center - placed.anchorBox.center;
  final rawDegrees = math.atan2(offset.dy, offset.dx) * 180 / math.pi;
  final angleDegrees = rawDegrees < 0 ? rawDegrees + 360 : rawDegrees;
  return (
    angleDegrees: angleDegrees,
    ringFactor: offset.distance / placed.anchorBox.longestSide,
  );
}

List<String> _placementGeometryConflicts({
  required PlacedLabel placed,
  required List<PlacedLabel> allPlacements,
}) {
  final connector = computeConnectorPath(
    labelRect: placed.labelRect,
    targetBox: placed.anchorBox,
  );
  final conflicts = <String>[];
  for (final other in allPlacements) {
    if (identical(other, placed)) continue;
    final otherConnector = computeConnectorPath(
      labelRect: other.labelRect,
      targetBox: other.anchorBox,
    );
    if (segmentIntersectsRect(
      from: connector.from,
      to: connector.to,
      rect: other.labelRect,
    )) {
      conflicts.add('jacketConnector-vs-${other.word.word}Label');
    }
    if (segmentIntersectsRect(
      from: otherConnector.from,
      to: otherConnector.to,
      rect: placed.labelRect,
    )) {
      conflicts.add('${other.word.word}Connector-vs-jacketLabel');
    }
    if (segmentsIntersect(
      firstFrom: connector.from,
      firstTo: connector.to,
      secondFrom: otherConnector.from,
      secondTo: otherConnector.to,
    )) {
      conflicts.add('jacketConnector-vs-${other.word.word}Connector');
    }
  }
  return List.unmodifiable(conflicts);
}

void _verifyAndPrintScenario(
  _Scenario scenario,
  List<PlacedLabel> result,
) {
  expect(result, hasLength(scenario.words.length));
  expect(result.map((placed) => placed.word).toSet(), hasLength(result.length));
  for (final word in scenario.words) {
    final placed = result.singleWhere(
      (placed) => identical(placed.word, word),
    );
    final inputIndex = scenario.words.indexWhere(
      (input) => identical(input, word),
    );
    expect(placed.anchorBox, scenario.anchorBoxes[inputIndex]);
  }

  final counts = {
    for (final quality in PlacementQuality.values)
      quality: result.where((placed) => placed.quality == quality).length,
  };
  debugPrint('SOLVER_SCENARIO ${scenario.name} total=${result.length}');
  for (final quality in PlacementQuality.values) {
    final count = counts[quality]!;
    final percentage = count * 100 / result.length;
    debugPrint(
      'quality=${quality.name} count=$count '
      'percent=${percentage.toStringAsFixed(2)}%',
    );
  }

  var flaggedForbiddenCount = 0;
  var connectorForeignZoneCrossingCount = 0;
  var strictTierConnectorCrossingCount = 0;
  var totalConnectorLength = 0.0;
  for (final placed in result) {
    expect(placed.labelRect.left.isFinite, isTrue);
    expect(placed.labelRect.top.isFinite, isTrue);
    expect(placed.labelRect.right.isFinite, isTrue);
    expect(placed.labelRect.bottom.isFinite, isTrue);
    expect(placed.labelRect.left, greaterThanOrEqualTo(0));
    expect(placed.labelRect.top, greaterThanOrEqualTo(0));
    expect(
        placed.labelRect.right, lessThanOrEqualTo(scenario.canvasSize.width));
    expect(
      placed.labelRect.bottom,
      lessThanOrEqualTo(scenario.canvasSize.height),
    );

    final overlapArea = scenario.forbiddenZones.fold<double>(
      0,
      (sum, zone) => sum + _intersectionArea(placed.labelRect, zone),
    );
    final overlapRatio = scenario.forbiddenZones.fold<double>(
      0,
      (maximum, zone) => math.max(
        maximum,
        _overlapRatio(placed.labelRect, zone),
      ),
    );
    final inputIndex = scenario.words.indexWhere(
      (word) => identical(word, placed.word),
    );
    final connector = computeConnectorPath(
      labelRect: placed.labelRect,
      targetBox: placed.anchorBox,
    );
    totalConnectorLength += (connector.to - connector.from).distance;
    final connectorCrossings = scenario.forbiddenZones.indexed.where((entry) {
      return entry.$1 != inputIndex &&
          segmentIntersectsRect(
            from: connector.from,
            to: connector.to,
            rect: entry.$2,
          );
    }).length;
    connectorForeignZoneCrossingCount += connectorCrossings;
    if (placed.quality == PlacementQuality.ideal ||
        placed.quality == PlacementQuality.fallbackSmallerFont) {
      strictTierConnectorCrossingCount += connectorCrossings;
      expect(connectorCrossings, 0);
    }
    debugPrint(
      'word=${placed.word.word} quality=${placed.quality.name} '
      'rect=${placed.labelRect} connectorCrossings=$connectorCrossings '
      'forbiddenOverlapArea=${overlapArea.toStringAsFixed(1)} '
      'forbiddenOverlapRatio=${overlapRatio.toStringAsFixed(4)} '
      'forbiddenFlag=${placed.overlapsForbiddenZone} '
      'placedFlag=${placed.overlapsPlacedLabel}',
    );
    if (placed.quality != PlacementQuality.fallbackEdge) {
      expect(overlapArea, 0.0);
      expect(placed.overlapsForbiddenZone, isFalse);
    } else if (placed.overlapsForbiddenZone) {
      flaggedForbiddenCount++;
      expect(overlapArea, greaterThan(0));
    } else {
      expect(overlapArea, 0.0);
    }
  }
  debugPrint(
    'connectorForeignZoneCrossingCount=$connectorForeignZoneCrossingCount',
  );
  debugPrint(
    'strictTierConnectorCrossingCount=$strictTierConnectorCrossingCount',
  );
  debugPrint(
    'averageConnectorLength='
    '${(totalConnectorLength / result.length).toStringAsFixed(4)}',
  );
  debugPrint('fallbackEdgeForbiddenOverlapCount=$flaggedForbiddenCount');

  final flaggedPlacedLabels = result
      .where((placed) => placed.overlapsPlacedLabel)
      .toList(growable: false);
  debugPrint(
    'fallbackEdgePlacedOverlapCount=${flaggedPlacedLabels.length}',
  );
  for (final flagged in flaggedPlacedLabels) {
    final overlapRatios = result
        .where((other) => !identical(other, flagged))
        .map((other) => _overlapRatio(flagged.labelRect, other.labelRect))
        .where((ratio) => ratio > 0)
        .toList(growable: false);
    final maximumRatio =
        overlapRatios.isEmpty ? 0.0 : overlapRatios.reduce(math.max);
    debugPrint(
      'auditedPlacedOverlap word=${flagged.word.word} '
      'maxRatio=${maximumRatio.toStringAsFixed(4)}',
    );
    expect(maximumRatio, greaterThan(0));
  }

  final nonIdealRatios = <double>[];
  final unauditedEdgeToEdgeRatios = <double>[];
  for (var first = 0; first < result.length; first++) {
    for (var second = first + 1; second < result.length; second++) {
      if (result[first].quality == PlacementQuality.ideal &&
          result[second].quality == PlacementQuality.ideal) {
        continue;
      }
      final ratio =
          _overlapRatio(result[first].labelRect, result[second].labelRect);
      final isAudited = result[first].overlapsPlacedLabel ||
          result[second].overlapsPlacedLabel;
      if (isAudited) continue;
      nonIdealRatios.add(ratio);
      if (result[first].quality == PlacementQuality.fallbackEdge &&
          result[second].quality == PlacementQuality.fallbackEdge) {
        unauditedEdgeToEdgeRatios.add(ratio);
      }
      expect(ratio, lessThanOrEqualTo(0.2 + 1e-12));
    }
  }
  final averageRatio = nonIdealRatios.isEmpty
      ? 0.0
      : nonIdealRatios.reduce((a, b) => a + b) / nonIdealRatios.length;
  final maximumRatio =
      nonIdealRatios.isEmpty ? 0.0 : nonIdealRatios.reduce(math.max);
  debugPrint(
    'nonIdealUnauditedLabelOverlap average=${averageRatio.toStringAsFixed(4)} '
    'max=${maximumRatio.toStringAsFixed(4)}',
  );
  final maximumEdgeToEdge = unauditedEdgeToEdgeRatios.isEmpty
      ? 0.0
      : unauditedEdgeToEdgeRatios.reduce(math.max);
  debugPrint(
    'fallbackEdgeToEdgeUnauditedOverlap '
    'max=${maximumEdgeToEdge.toStringAsFixed(4)}',
  );

  if (scenario.name == 'scattered-small-300x500') {
    for (final pair in const [
      ('shirt', 'mirror'),
      ('jacket', 'sweater'),
      ('wardrobe', 'skirt'),
      ('dress', 'mirror'),
    ]) {
      final first = result.singleWhere(
        (placed) => placed.word.word == pair.$1,
      );
      final second = result.singleWhere(
        (placed) => placed.word.word == pair.$2,
      );
      final ratio = _overlapRatio(first.labelRect, second.labelRect);
      debugPrint(
        'smallCanvasRegressionPair pair=${pair.$1}-${pair.$2} '
        'overlapRatio=${ratio.toStringAsFixed(4)}',
      );
      expect(
        ratio,
        0.0,
        reason: '${pair.$1}-${pair.$2} must no longer overlap',
      );
    }
  }
}

double _overlapRatio(Rect first, Rect second) {
  final overlap = _intersectionArea(first, second);
  if (overlap == 0) return 0;
  final smallerArea = math.min(_area(first), _area(second));
  return smallerArea == 0 ? 0 : overlap / smallerArea;
}

double _intersectionArea(Rect first, Rect second) {
  if (!first.overlaps(second)) return 0;
  final intersection = first.intersect(second);
  return math.max(0, intersection.width) * math.max(0, intersection.height);
}

double _area(Rect rect) => math.max(0, rect.width) * math.max(0, rect.height);

double _averageConnectorLength(List<PlacedLabel> labels) {
  final total = labels.fold<double>(0, (sum, placed) {
    final connector = computeConnectorPath(
      labelRect: placed.labelRect,
      targetBox: placed.anchorBox,
    );
    return sum + (connector.to - connector.from).distance;
  });
  return total / labels.length;
}

List<int> _qualityCounts(List<PlacedLabel> labels) => [
      for (final quality in PlacementQuality.values)
        labels.where((placed) => placed.quality == quality).length,
    ];

int _strictConnectorCrossings(
  _Scenario scenario,
  List<PlacedLabel> labels,
) {
  var crossings = 0;
  for (final placed in labels.where(
    (placed) =>
        placed.quality == PlacementQuality.ideal ||
        placed.quality == PlacementQuality.fallbackSmallerFont,
  )) {
    final inputIndex = scenario.words.indexWhere(
      (word) => identical(word, placed.word),
    );
    final connector = computeConnectorPath(
      labelRect: placed.labelRect,
      targetBox: placed.anchorBox,
    );
    crossings += scenario.forbiddenZones.indexed.where((entry) {
      return entry.$1 != inputIndex &&
          segmentIntersectsRect(
            from: connector.from,
            to: connector.to,
            rect: entry.$2,
          );
    }).length;
  }
  return crossings;
}

List<double> _task11Ranker({
  required Rect anchorBox,
  required List<double> angleDegrees,
  required List<Rect> forbiddenZones,
  required List<Rect> placedLabels,
  required Size canvasSize,
}) {
  return rankAnglesByOpenness(
    anchorBox: anchorBox,
    angleDegrees: angleDegrees,
    forbiddenZones: forbiddenZones,
    placedLabels: placedLabels,
  );
}

AngleRankingFunction _centerBiasRanker(double centerWeight) {
  return ({
    required Rect anchorBox,
    required List<double> angleDegrees,
    required List<Rect> forbiddenZones,
    required List<Rect> placedLabels,
    required Size canvasSize,
  }) {
    return rankAnglesByOpennessAndCenterBiasWithWeights(
      anchorBox: anchorBox,
      angleDegrees: angleDegrees,
      forbiddenZones: forbiddenZones,
      placedLabels: placedLabels,
      canvasSize: canvasSize,
      edgeThresholdFraction: 0.20,
      opennessWeight: 1.0,
      centerWeight: centerWeight,
    );
  };
}

VocabDetection _word(String word) => VocabDetection(
      word: word,
      phonetic: '',
      meaning: word,
      x: 0,
      y: 0,
      w: 0.1,
      h: 0.1,
    );

class _Scenario {
  const _Scenario({
    required this.name,
    required this.words,
    required this.labelSizes,
    required this.anchorBoxes,
    required this.forbiddenZones,
    required this.canvasSize,
  });

  final String name;
  final List<VocabDetection> words;
  final List<LabelSize> labelSizes;
  final List<Rect> anchorBoxes;
  final List<Rect> forbiddenZones;
  final Size canvasSize;
}

class _RankingCall {
  const _RankingCall({
    required this.anchorBox,
    required this.placedLabelCount,
    required this.angles,
  });

  final Rect anchorBox;
  final int placedLabelCount;
  final _TrackingAngleList angles;
}

class _TrackingAngleList extends ListBase<double> {
  _TrackingAngleList(Iterable<double> values)
      : _values = List<double>.of(values, growable: false);

  final List<double> _values;
  int iteratorRequests = 0;

  @override
  int get length => _values.length;

  @override
  set length(int value) => throw UnsupportedError('fixed length');

  @override
  double operator [](int index) => _values[index];

  @override
  void operator []=(int index, double value) =>
      throw UnsupportedError('read only');

  @override
  Iterator<double> get iterator {
    iteratorRequests++;
    return _values.iterator;
  }
}

/// Keeps solver-tier fixtures independent from production typography changes.
/// Label measurement itself is covered by label_size_measurer_test.dart.
class _FixedLabelSizeMeasurer extends LabelSizeMeasurer {
  const _FixedLabelSizeMeasurer(this.size);

  final LabelSize size;

  @override
  LabelSize measure(VocabDetection word, LabelStyleConfig config) => size;
}

const _tinyCompactStyle = LabelStyleConfig(
  badgeTextStyle: TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
  badgeWidth: 24,
  badgeHeight: 24,
  wordStyle: TextStyle(fontSize: 10),
  phoneticStyle: TextStyle(fontSize: 8),
  meaningStyle: TextStyle(fontSize: 8),
  padding: LabelPaddingConfig(horizontal: 2, vertical: 2),
  mode: LabelCardMode.compact,
);

const _twentyPixelCompactStyle = LabelStyleConfig(
  badgeTextStyle: TextStyle(fontSize: 20),
  badgeWidth: 24,
  badgeHeight: 24,
  wordStyle: TextStyle(fontSize: 20),
  phoneticStyle: TextStyle(fontSize: 20),
  meaningStyle: TextStyle(fontSize: 20),
  padding: LabelPaddingConfig(horizontal: 0, vertical: 0),
  mode: LabelCardMode.compact,
);

const _fullStyle = LabelStyleConfig(
  badgeTextStyle: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
  badgeWidth: 16,
  badgeHeight: 16,
  wordStyle: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
  phoneticStyle: TextStyle(fontSize: 6, fontStyle: FontStyle.italic),
  meaningStyle: TextStyle(fontSize: 7),
  padding: LabelPaddingConfig(horizontal: 6, vertical: 4, bottom: 7),
  mode: LabelCardMode.full,
  lineSpacing: 1,
);

const _compactStyle = LabelStyleConfig(
  badgeTextStyle: TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
  badgeWidth: 16,
  badgeHeight: 16,
  wordStyle: TextStyle(fontSize: 6, fontWeight: FontWeight.w700),
  phoneticStyle: TextStyle(fontSize: 6, fontStyle: FontStyle.italic),
  meaningStyle: TextStyle(fontSize: 6),
  padding: LabelPaddingConfig(horizontal: 4, vertical: 2, bottom: 5),
  mode: LabelCardMode.compact,
  lineSpacing: 0,
);

const _crowdedBoxes = [
  Rect.fromLTWH(0.43, 0.42, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.42, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.42, 0.08, 0.08),
  Rect.fromLTWH(0.43, 0.46, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.46, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.46, 0.08, 0.08),
  Rect.fromLTWH(0.43, 0.50, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.50, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.50, 0.08, 0.08),
  Rect.fromLTWH(0.43, 0.54, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.54, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.54, 0.08, 0.08),
];

const _denseWardrobeEdgeBoxes = [
  Rect.fromLTWH(0.43, 0.42, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.42, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.42, 0.08, 0.08),
  Rect.fromLTWH(0.43, 0.46, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.46, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.46, 0.08, 0.08),
  Rect.fromLTWH(0.43, 0.50, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.50, 0.08, 0.08),
  Rect.fromLTWH(0.51, 0.50, 0.08, 0.08),
  Rect.fromLTWH(0.43, 0.54, 0.08, 0.08),
  Rect.fromLTWH(0.47, 0.54, 0.08, 0.08),
  Rect.fromLTWH(0.91, 0.82, 0.04, 0.04),
];

const _topEdgeWardrobeBoxes = [
  Rect.fromLTWH(
    0.32687691582472977,
    0.014725803827084737,
    0.12079117096763625,
    0.31434780933607609,
  ),
  Rect.fromLTWH(
    0.13197271504842639,
    0.55020576595127879,
    0.078196816987237988,
    0.094657909291416709,
  ),
  Rect.fromLTWH(
    0.083916929541461002,
    0.49838471513620725,
    0.053771440903115267,
    0.077669864258365695,
  ),
  Rect.fromLTWH(
    0.64007498069133062,
    0.063596937811099805,
    0.059904548872090180,
    0.10401657602531873,
  ),
  Rect.fromLTWH(
    0.076673911974644113,
    0.31884273787374739,
    0.11185692860103875,
    0.14101043509416733,
  ),
  Rect.fromLTWH(
    0.73865839513094511,
    0.17978938647035467,
    0.055450457907693984,
    0.087806630549410430,
  ),
  Rect.fromLTWH(
    0.34066237791701526,
    0.12681202419714596,
    0.11711410817272860,
    0.085750549278224258,
  ),
  Rect.fromLTWH(
    0.79986073235722843,
    0.36888753151140941,
    0.080130305983839856,
    0.066577278046346500,
  ),
  Rect.fromLTWH(
    0.28101243913621010,
    0.17482819190230292,
    0.099737735833604457,
    0.13323041006913700,
  ),
  Rect.fromLTWH(
    0.78191107018810846,
    0.15636906389397609,
    0.10650378208236133,
    0.11875626682572077,
  ),
  Rect.fromLTWH(
    0.031101135515714952,
    0.28269591943837358,
    0.066750009658612747,
    0.11416637708982252,
  ),
  Rect.fromLTWH(
    0.73769386097062306,
    0.21051813641196712,
    0.070887553216704036,
    0.069884842012384679,
  ),
];

const _smallCanvasBoxes = [
  Rect.fromLTWH(0.04, 0.04, 0.10, 0.10),
  Rect.fromLTWH(0.32, 0.05, 0.10, 0.10),
  Rect.fromLTWH(0.62, 0.04, 0.10, 0.10),
  Rect.fromLTWH(0.83, 0.07, 0.10, 0.10),
  Rect.fromLTWH(0.05, 0.37, 0.10, 0.10),
  Rect.fromLTWH(0.34, 0.36, 0.10, 0.10),
  Rect.fromLTWH(0.63, 0.38, 0.10, 0.10),
  Rect.fromLTWH(0.84, 0.36, 0.10, 0.10),
  Rect.fromLTWH(0.04, 0.72, 0.10, 0.10),
  Rect.fromLTWH(0.33, 0.70, 0.10, 0.10),
  Rect.fromLTWH(0.62, 0.72, 0.10, 0.10),
  Rect.fromLTWH(0.84, 0.70, 0.10, 0.10),
];

const _benchmarkBoxes15 = [
  Rect.fromLTWH(0.06, 0.08, 0.08, 0.08),
  Rect.fromLTWH(0.25, 0.08, 0.08, 0.08),
  Rect.fromLTWH(0.44, 0.08, 0.08, 0.08),
  Rect.fromLTWH(0.63, 0.08, 0.08, 0.08),
  Rect.fromLTWH(0.82, 0.08, 0.08, 0.08),
  Rect.fromLTWH(0.06, 0.43, 0.08, 0.08),
  Rect.fromLTWH(0.25, 0.43, 0.08, 0.08),
  Rect.fromLTWH(0.44, 0.43, 0.08, 0.08),
  Rect.fromLTWH(0.63, 0.43, 0.08, 0.08),
  Rect.fromLTWH(0.82, 0.43, 0.08, 0.08),
  Rect.fromLTWH(0.06, 0.78, 0.08, 0.08),
  Rect.fromLTWH(0.25, 0.78, 0.08, 0.08),
  Rect.fromLTWH(0.44, 0.78, 0.08, 0.08),
  Rect.fromLTWH(0.63, 0.78, 0.08, 0.08),
  Rect.fromLTWH(0.82, 0.78, 0.08, 0.08),
];
