import 'dart:math' as math;
import 'dart:ui';

const List<double> _defaultRingFactors = [1.0, 1.5, 2.0, 2.8, 3.6];
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

/// Generates in-bounds label top-left positions, preserving ring-first order.
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
/// Every returned [Offset] is the label's top-left corner. The label center is
/// placed at `anchorBox.center + radius * (cos(angle), sin(angle))`, where
/// `radius = anchorBox.longestSide * ringFactor`.
List<Offset> generateCandidates({
  required Rect anchorBox,
  required Size labelSize,
  required Size canvasSize,
  List<double>? ringFactors,
  List<double>? angleDegrees,
}) {
  _validateGeometry(anchorBox, labelSize, canvasSize);
  final rings = ringFactors ?? _defaultRingFactors;
  final angles = angleDegrees ?? defaultCandidateAngleDegrees;
  _validateValues(rings, 'ringFactors', allowNegative: false);
  _validateValues(angles, 'angleDegrees', allowNegative: true);

  final candidates = <Offset>[];
  final canvasRect = Offset.zero & canvasSize;
  final labelCenterOffset = Offset(labelSize.width / 2, labelSize.height / 2);

  for (final ringFactor in rings) {
    final radius = anchorBox.longestSide * ringFactor;
    for (final degrees in angles) {
      final radians = degrees * math.pi / 180;
      final direction = Offset(
        _zeroNearOrigin(math.cos(radians)),
        _zeroNearOrigin(math.sin(radians)),
      );
      final candidateCenter = anchorBox.center + direction * radius;
      final topLeft = candidateCenter - labelCenterOffset;
      final candidateRect = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        labelSize.width,
        labelSize.height,
      );

      if (_isFullyInside(candidateRect, canvasRect)) {
        candidates.add(topLeft);
      }
    }
  }

  return List.unmodifiable(candidates);
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
