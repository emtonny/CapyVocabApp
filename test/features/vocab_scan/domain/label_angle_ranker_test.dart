import 'package:capy_vocab/features/vocab_scan/domain/label_angle_ranker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const angles = <double>[0, 45, 90, 135, 180, 225, 270, 315];
  const anchorBox = Rect.fromLTWH(90, 90, 20, 20);

  test('moves blocked 0 and 45 degree directions to the end stably', () {
    final ranked = rankAnglesByOpenness(
      anchorBox: anchorBox,
      angleDegrees: angles,
      forbiddenZones: const [Rect.fromLTWH(112, 98, 12, 20)],
      placedLabels: const [],
      sampleRadius: 20,
    );

    expect(ranked, [90, 135, 180, 225, 270, 315, 0, 45]);
  });

  test('preserves the complete input order when every direction is open', () {
    final ranked = rankAnglesByOpenness(
      anchorBox: anchorBox,
      angleDegrees: angles,
      forbiddenZones: const [],
      placedLabels: const [],
    );

    expect(ranked, angles);
  });

  test('combines fixed forbidden zones and dynamic placed labels', () {
    final ranked = rankAnglesByOpenness(
      anchorBox: anchorBox,
      angleDegrees: const [0, 90, 180, 270],
      forbiddenZones: const [Rect.fromLTWH(119, 99, 2, 2)],
      placedLabels: const [Rect.fromLTWH(99, 119, 2, 2)],
    );

    expect(ranked, [180, 270, 0, 90]);
  });

  test('center alignment scores inward, outward, and perpendicular vectors',
      () {
    expect(
      centerAlignmentScore(
        candidateDirection: const Offset(2, 0),
        anchorToCanvasCenter: const Offset(10, 0),
      ),
      closeTo(1, 1e-12),
    );
    expect(
      centerAlignmentScore(
        candidateDirection: const Offset(-2, 0),
        anchorToCanvasCenter: const Offset(10, 0),
      ),
      closeTo(-1, 1e-12),
    );
    expect(
      centerAlignmentScore(
        candidateDirection: const Offset(0, 3),
        anchorToCanvasCenter: const Offset(10, 0),
      ),
      closeTo(0, 1e-12),
    );
  });

  test('center bias applies only inside the outer 20 percent edge band', () {
    final nearTop = rankAnglesByOpennessAndCenterBias(
      anchorBox: const Rect.fromLTWH(90, 10, 20, 20),
      angleDegrees: const [0, 90, 180, 270],
      forbiddenZones: const [],
      placedLabels: const [],
      canvasSize: const Size(200, 200),
    );
    final central = rankAnglesByOpennessAndCenterBias(
      anchorBox: const Rect.fromLTWH(90, 90, 20, 20),
      angleDegrees: const [0, 90, 180, 270],
      forbiddenZones: const [],
      placedLabels: const [],
      canvasSize: const Size(200, 200),
    );

    expect(nearTop.first, 90);
    expect(nearTop.last, 270);
    expect(central, [0, 90, 180, 270]);
  });
}
