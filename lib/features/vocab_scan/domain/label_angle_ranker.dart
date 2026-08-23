import 'dart:math' as math;
import 'dart:ui';

const double centerBiasEdgeThresholdFraction = 0.20;
const double opennessScoreWeight = 1.0;
const double centerAlignmentScoreWeight = 0.35;

typedef AngleRankingFunction = List<double> Function({
  required Rect anchorBox,
  required List<double> angleDegrees,
  required List<Rect> forbiddenZones,
  required List<Rect> placedLabels,
  required Size canvasSize,
});

/// Returns [angleDegrees] with open sample directions before blocked ones.
///
/// The partition is stable: angles keep their input order within both groups.
/// When [sampleRadius] is omitted, the sample point uses the nearest default
/// candidate ring (`anchorBox.longestSide * 1.0`).
List<double> rankAnglesByOpenness({
  required Rect anchorBox,
  required List<double> angleDegrees,
  required List<Rect> forbiddenZones,
  required List<Rect> placedLabels,
  double? sampleRadius,
}) {
  _validateInputs(anchorBox, angleDegrees, sampleRadius);
  final radius = sampleRadius ?? anchorBox.longestSide;
  final obstacles = [...forbiddenZones, ...placedLabels];
  final openAngles = <double>[];
  final blockedAngles = <double>[];

  for (final degrees in angleDegrees) {
    final direction = _directionForAngle(degrees);
    final isBlocked = _isDirectionBlocked(
      anchorBox: anchorBox,
      direction: direction,
      radius: radius,
      obstacles: obstacles,
    );
    (isBlocked ? blockedAngles : openAngles).add(degrees);
  }

  return List.unmodifiable([...openAngles, ...blockedAngles]);
}

/// Returns the cosine similarity of two directions in the range -1 to 1.
///
/// A zero-length vector has no meaningful direction and returns zero.
double centerAlignmentScore({
  required Offset candidateDirection,
  required Offset anchorToCanvasCenter,
}) {
  final candidateLength = candidateDirection.distance;
  final centerLength = anchorToCanvasCenter.distance;
  if (candidateLength == 0 || centerLength == 0) return 0;

  final score = (candidateDirection.dx * anchorToCanvasCenter.dx +
          candidateDirection.dy * anchorToCanvasCenter.dy) /
      (candidateLength * centerLength);
  return score.clamp(-1.0, 1.0).toDouble();
}

/// Ranks angles by obstacle openness and, near an edge, canvas-center alignment.
List<double> rankAnglesByOpennessAndCenterBias({
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
    edgeThresholdFraction: centerBiasEdgeThresholdFraction,
    opennessWeight: opennessScoreWeight,
    centerWeight: centerAlignmentScoreWeight,
  );
}

/// Configurable form used to compare weighting strategies in deterministic tests.
List<double> rankAnglesByOpennessAndCenterBiasWithWeights({
  required Rect anchorBox,
  required List<double> angleDegrees,
  required List<Rect> forbiddenZones,
  required List<Rect> placedLabels,
  required Size canvasSize,
  required double edgeThresholdFraction,
  required double opennessWeight,
  required double centerWeight,
  double? sampleRadius,
}) {
  _validateInputs(anchorBox, angleDegrees, sampleRadius);
  _validateScoringInputs(
    canvasSize: canvasSize,
    edgeThresholdFraction: edgeThresholdFraction,
    opennessWeight: opennessWeight,
    centerWeight: centerWeight,
  );
  final radius = sampleRadius ?? anchorBox.longestSide;
  final obstacles = [...forbiddenZones, ...placedLabels];
  final appliesCenterBias = _isNearCanvasEdge(
    anchorBox: anchorBox,
    canvasSize: canvasSize,
    thresholdFraction: edgeThresholdFraction,
  );
  final anchorToCanvasCenter =
      (Offset.zero & canvasSize).center - anchorBox.center;
  final scoredAngles = <({double angle, int index, double score})>[];

  for (final (index, degrees) in angleDegrees.indexed) {
    final direction = _directionForAngle(degrees);
    final isBlocked = _isDirectionBlocked(
      anchorBox: anchorBox,
      direction: direction,
      radius: radius,
      obstacles: obstacles,
    );
    final opennessScore = isBlocked ? 0.0 : 1.0;
    final centerScore = appliesCenterBias
        ? centerAlignmentScore(
            candidateDirection: direction,
            anchorToCanvasCenter: anchorToCanvasCenter,
          )
        : 0.0;
    scoredAngles.add((
      angle: degrees,
      index: index,
      score: opennessWeight * opennessScore + centerWeight * centerScore,
    ));
  }

  scoredAngles.sort((first, second) {
    final byScore = second.score.compareTo(first.score);
    return byScore != 0 ? byScore : first.index.compareTo(second.index);
  });
  return List.unmodifiable(scoredAngles.map((entry) => entry.angle));
}

Offset _directionForAngle(double degrees) {
  final radians = degrees * math.pi / 180;
  return Offset(math.cos(radians), math.sin(radians));
}

bool _isDirectionBlocked({
  required Rect anchorBox,
  required Offset direction,
  required double radius,
  required List<Rect> obstacles,
}) {
  final samplePoint = anchorBox.center + direction * radius;
  return obstacles.any((rect) => rect.contains(samplePoint));
}

bool _isNearCanvasEdge({
  required Rect anchorBox,
  required Size canvasSize,
  required double thresholdFraction,
}) {
  final normalizedEdgeDistances = [
    anchorBox.left / canvasSize.width,
    anchorBox.top / canvasSize.height,
    (canvasSize.width - anchorBox.right) / canvasSize.width,
    (canvasSize.height - anchorBox.bottom) / canvasSize.height,
  ];
  return normalizedEdgeDistances.reduce(math.min) < thresholdFraction;
}

void _validateScoringInputs({
  required Size canvasSize,
  required double edgeThresholdFraction,
  required double opennessWeight,
  required double centerWeight,
}) {
  if (!canvasSize.width.isFinite ||
      !canvasSize.height.isFinite ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    throw ArgumentError.value(
      canvasSize,
      'canvasSize',
      'must be finite and positive',
    );
  }
  if (!edgeThresholdFraction.isFinite ||
      edgeThresholdFraction < 0 ||
      edgeThresholdFraction > 0.5) {
    throw ArgumentError.value(
      edgeThresholdFraction,
      'edgeThresholdFraction',
      'must be finite and between 0 and 0.5',
    );
  }
  if (!opennessWeight.isFinite ||
      !centerWeight.isFinite ||
      opennessWeight < 0 ||
      centerWeight < 0) {
    throw ArgumentError(
      'opennessWeight and centerWeight must be finite and >= 0',
    );
  }
}

void _validateInputs(
  Rect anchorBox,
  List<double> angleDegrees,
  double? sampleRadius,
) {
  final anchorValues = [
    anchorBox.left,
    anchorBox.top,
    anchorBox.right,
    anchorBox.bottom,
  ];
  if (anchorValues.any((value) => !value.isFinite) ||
      anchorBox.width <= 0 ||
      anchorBox.height <= 0) {
    throw ArgumentError.value(
      anchorBox,
      'anchorBox',
      'must be finite and positive',
    );
  }
  if (angleDegrees.any((angle) => !angle.isFinite)) {
    throw ArgumentError.value(
      angleDegrees,
      'angleDegrees',
      'must contain only finite values',
    );
  }
  if (sampleRadius != null && (!sampleRadius.isFinite || sampleRadius < 0)) {
    throw ArgumentError.value(
      sampleRadius,
      'sampleRadius',
      'must be finite and >= 0',
    );
  }
}
