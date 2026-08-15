import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double handDrawnMinPositionJitter = 10;
const double handDrawnMaxPositionJitter = 15;
const double handDrawnMinStagger = 8;
const double handDrawnMaxStagger = 12;
const double handDrawnMinRotationDegrees = 1;
const double handDrawnMaxRotationDegrees = 3;

class VocabHandDrawnJitter {
  const VocabHandDrawnJitter({
    required this.positionOffset,
    required this.stagger,
    required this.rotationRadians,
  });

  factory VocabHandDrawnJitter.forWord(String word) {
    final random = math.Random(word.hashCode);

    double signedRange(double minimum, double maximum) {
      final magnitude = minimum + random.nextDouble() * (maximum - minimum);
      return random.nextBool() ? magnitude : -magnitude;
    }

    return VocabHandDrawnJitter(
      positionOffset: Offset(
        signedRange(
          handDrawnMinPositionJitter,
          handDrawnMaxPositionJitter,
        ),
        signedRange(
          handDrawnMinPositionJitter,
          handDrawnMaxPositionJitter,
        ),
      ),
      stagger: signedRange(handDrawnMinStagger, handDrawnMaxStagger),
      rotationRadians: signedRange(
            handDrawnMinRotationDegrees,
            handDrawnMaxRotationDegrees,
          ) *
          math.pi /
          180,
    );
  }

  final Offset positionOffset;
  final double stagger;
  final double rotationRadians;
}
