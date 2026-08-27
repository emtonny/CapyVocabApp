import 'dart:math' as math;
import 'dart:ui';

const double _candidateGap = 6;
const double _softRadiusRatio = 0.20;
const double _hardRadiusRatio = 0.30;
const double _radiusStepRatio = 0.03;
const double _minimumRadiusStep = 8;
const double _maximumRadiusStep = 16;
const double _geometryEpsilon = 1e-9;
const List<double> defaultCandidateAngleDegrees = [
  0,
  45,
  90,
  135,
  180,
  225,
  270,
  315,
];
const List<double> _recoveryAngleOffsets = [-15, 15, -30, 30];

enum CandidateRadiusTier { soft, hard }

/// Adds only the unique ±15° and ±30° directions around [baseAngles].
///
/// Base directions are excluded because recovery runs only after their normal
/// candidate pass has no valid result. Ordering follows the ranked base angle
/// order so recovery retains the same openness and center-bias preference.
List<double> generateRecoveryAngleDegrees(List<double> baseAngles) {
  _validateValues(baseAngles, 'baseAngles', allowNegative: true);
  final normalizedBaseAngles = baseAngles.map(_normalizeDegrees).toSet();
  final seen = <double>{...normalizedBaseAngles};
  final recoveryAngles = <double>[];
  for (final baseAngle in baseAngles) {
    for (final offset in _recoveryAngleOffsets) {
      final recoveryAngle = _normalizeDegrees(baseAngle + offset);
      if (seen.add(recoveryAngle)) recoveryAngles.add(recoveryAngle);
    }
  }
  return List.unmodifiable(recoveryAngles);
}

/// Generates in-bounds label top-left positions in nearest-radius-first order.
///
/// Angles use Flutter canvas coordinates: +x points right, +y points down, so
/// positive angles increase clockwise.
///
/// ```text
///                       270° (up, dy -)
///                              ↑
///              225° ↖          │          ↗ 315°
///                              │
/// 180° (left, dx -) ←──── anchor box ────→ 0° (right, dx +)
///                              │
///              135° ↙          │          ↘ 45°
///                              ↓
///                       90° (down, dy +)
/// ```
///
/// The search starts where the label clears the anchor by [_candidateGap], then
/// advances by a canvas-relative step. The soft tier ends at 20% of the
/// canvas's shorter side; the hard tier continues from there to 30%.
List<Offset> generateCandidates({
  required Rect anchorBox,
  required Size labelSize,
  required Size canvasSize,
  List<double>? angleDegrees,
  CandidateRadiusTier radiusTier = CandidateRadiusTier.soft,
}) {
  _validateGeometry(anchorBox, labelSize, canvasSize);
  final angles = angleDegrees ?? defaultCandidateAngleDegrees;
  _validateValues(angles, 'angleDegrees', allowNegative: true);

  final shorterCanvasSide = math.min(canvasSize.width, canvasSize.height);
  final softRadius = shorterCanvasSide * _softRadiusRatio;
  final hardRadius = shorterCanvasSide * _hardRadiusRatio;
  final radiusStep = (shorterCanvasSide * _radiusStepRatio).clamp(
    _minimumRadiusStep,
    _maximumRadiusStep,
  );
  final canvasRect = Offset.zero & canvasSize;
  final labelCenterOffset = Offset(labelSize.width / 2, labelSize.height / 2);
  final candidates = <({Offset topLeft, double radius, int angleRank})>[];

  for (final (angleRank, degrees) in angles.indexed) {
    final radians = degrees * math.pi / 180;
    final direction = Offset(
      _zeroNearOrigin(math.cos(radians)),
      _zeroNearOrigin(math.sin(radians)),
    );
    final touchRadius = _touchRadius(
      anchorBox: anchorBox,
      labelSize: labelSize,
      direction: direction,
    );
    final radii = _radiiForTier(
      touchRadius: touchRadius,
      step: radiusStep,
      softRadius: softRadius,
      hardRadius: hardRadius,
      tier: radiusTier,
    );
    for (final radius in radii) {
      final candidateCenter = anchorBox.center + direction * radius;
      final topLeft = candidateCenter - labelCenterOffset;
      final candidateRect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        labelSize.width,
        labelSize.height,
      );

      if (_isFullyInside(candidateRect, canvasRect)) {
        candidates
            .add((topLeft: topLeft, radius: radius, angleRank: angleRank));
      }
    }
  }

  candidates.sort((first, second) {
    final byRadius = first.radius.compareTo(second.radius);
    return byRadius != 0
        ? byRadius
        : first.angleRank.compareTo(second.angleRank);
  });
  return List.unmodifiable(candidates.map((candidate) => candidate.topLeft));
}

double _touchRadius({
  required Rect anchorBox,
  required Size labelSize,
  required Offset direction,
}) {
  final clearX = (anchorBox.width + labelSize.width) / 2 + _candidateGap;
  final clearY = (anchorBox.height + labelSize.height) / 2 + _candidateGap;
  final radiusX = direction.dx.abs() <= _geometryEpsilon
      ? double.infinity
      : clearX / direction.dx.abs();
  final radiusY = direction.dy.abs() <= _geometryEpsilon
      ? double.infinity
      : clearY / direction.dy.abs();
  return math.min(radiusX, radiusY);
}

List<double> _radiiForTier({
  required double touchRadius,
  required double step,
  required double softRadius,
  required double hardRadius,
  required CandidateRadiusTier tier,
}) {
  final limit = tier == CandidateRadiusTier.soft ? softRadius : hardRadius;
  if (touchRadius > limit + _geometryEpsilon) return const [];

  final radii = <double>[];
  for (var radius = touchRadius;
      radius <= limit + _geometryEpsilon;
      radius += step) {
    final belongsToTier = tier == CandidateRadiusTier.soft
        ? radius <= softRadius + _geometryEpsilon
        : radius > softRadius + _geometryEpsilon;
    if (belongsToTier) radii.add(radius);
  }
  if (limit >= touchRadius &&
      (tier == CandidateRadiusTier.soft || limit > softRadius) &&
      (radii.isEmpty || (radii.last - limit).abs() > _geometryEpsilon)) {
    radii.add(limit);
  }
  return radii;
}

bool _isFullyInside(Rect candidate, Rect canvas) {
  return candidate.left >= canvas.left &&
      candidate.top >= canvas.top &&
      candidate.right <= canvas.right &&
      candidate.bottom <= canvas.bottom;
}

double _zeroNearOrigin(double value) {
  return value.abs() < 1e-12 ? 0 : value;
}

double _normalizeDegrees(double value) {
  final normalized = value % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

void _validateGeometry(Rect anchorBox, Size labelSize, Size canvasSize) {
  final values = <double>[
    anchorBox.left,
    anchorBox.top,
    anchorBox.right,
    anchorBox.bottom,
    labelSize.width,
    labelSize.height,
    canvasSize.width,
    canvasSize.height,
  ];
  if (values.any((value) => !value.isFinite) ||
      anchorBox.width <= 0 ||
      anchorBox.height <= 0 ||
      labelSize.width <= 0 ||
      labelSize.height <= 0 ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    throw ArgumentError(
        'anchorBox, labelSize, and canvasSize must be finite and positive');
  }
}

void _validateValues(
  List<double> values,
  String name, {
  required bool allowNegative,
}) {
  if (values.any(
    (value) => !value.isFinite || (!allowNegative && value < 0),
  )) {
    throw ArgumentError.value(values, name, 'contains an invalid value');
  }
}
