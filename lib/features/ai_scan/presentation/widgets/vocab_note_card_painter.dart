import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../layout/vocab_hand_drawn_jitter.dart';
import '../layout/vocab_overlay_layout.dart';

const Size vocabNoteCardSize = Size(160, 108);
const double vocabNoteCardMaxWidth = 160;
const double maxCardJitterDegrees = handDrawnMaxRotationDegrees;

const TextStyle vocabNoteCardWordStyle = TextStyle(
  color: Color(0xFF4E342E),
  fontSize: 13,
  fontWeight: FontWeight.w800,
  height: 1.2,
);
const TextStyle vocabNoteCardPhoneticStyle = TextStyle(
  color: Color(0xFF8D6E63),
  fontSize: 9.5,
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w500,
  height: 1.3,
);
const TextStyle vocabNoteCardMeaningStyle = TextStyle(
  color: Color(0xFF6D4C41),
  fontSize: 10,
  fontWeight: FontWeight.w600,
  height: 1.3,
);

const double _horizontalPadding = 8;
const double _verticalPadding = 5;
const double _rotationSafetyInset = 7;
const double _badgeHeight = 16;
const double _badgeToTextGap = 4;
const double _textBlockGap = 2;

int stableStringHash(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

double stableWordJitterRadians(String word) {
  return VocabHandDrawnJitter.forWord(word).rotationRadians;
}

/// Measures the complete card canvas before perimeter placement.
///
/// The returned width includes padding and a small rotation safety inset and
/// never exceeds [vocabNoteCardMaxWidth] at the requested geometry scale.
/// Typography remains fixed; text blocks wrap naturally, so long values
/// increase card height instead of truncating.
Size measureVocabNoteCardSize(
  VocabDetection detection, {
  double scale = 1,
}) {
  if (!scale.isFinite || scale <= 0) return Size.zero;
  return _measureCard(detection, scale).size;
}

/// Measures the unwrapped text demand used to choose a discrete grid tier.
/// Painting still wraps text through [measureVocabNoteCardSize].
Size measureVocabNoteCardTextExtent(
  VocabDetection detection, {
  double scale = 1,
}) {
  if (!scale.isFinite || scale <= 0) return Size.zero;
  final word = _textPainter(
    detection.word.trim(),
    vocabNoteCardWordStyle,
    maxWidth: double.infinity,
    maxLines: 1,
  );
  final phonetic = _textPainter(
    _optionalMetadata(detection.phonetic),
    vocabNoteCardPhoneticStyle,
    maxWidth: double.infinity,
    maxLines: 1,
  );
  final meaning = _textPainter(
    _optionalMetadata(detection.meaning),
    vocabNoteCardMeaningStyle,
    maxWidth: double.infinity,
    maxLines: 1,
  );
  return Size(
    math.max(word.width, math.max(phonetic.width, meaning.width)) +
        2 * (_rotationSafetyInset + _horizontalPadding) * scale,
    2 * (_rotationSafetyInset + _verticalPadding) * scale +
        _badgeHeight * scale +
        _badgeToTextGap * scale +
        word.height +
        phonetic.height +
        meaning.height +
        2 * _textBlockGap * scale,
  );
}

LabelSizeTier selectVocabNoteCardSizeTier({
  required VocabDetection detection,
  required OverlayPlacementGrid grid,
}) {
  for (final tier in LabelSizeTier.values) {
    if (doesVocabNoteCardFitTier(
      detection: detection,
      tier: tier,
      grid: grid,
    )) {
      return tier;
    }
  }
  return LabelSizeTier.extraLarge;
}

bool doesVocabNoteCardFitTier({
  required VocabDetection detection,
  required LabelSizeTier tier,
  required OverlayPlacementGrid grid,
}) {
  final footprint = Size(
    tier.columns * grid.cellSize.width,
    tier.rows * grid.cellSize.height,
  );
  final layout = _measureCard(
    detection,
    1,
    maximumCanvasWidth: footprint.width,
  );
  const tolerance = 0.000001;
  return layout.size.width <= footprint.width + tolerance &&
      layout.size.height <= footprint.height + tolerance &&
      !layout.word.didExceedMaxLines &&
      !layout.phonetic.didExceedMaxLines &&
      !layout.meaning.didExceedMaxLines;
}

class VocabNoteCardPainter extends CustomPainter {
  const VocabNoteCardPainter({
    required this.detection,
    required this.index,
  });

  final VocabDetection detection;
  final int index;

  double get rotationRadians => stableWordJitterRadians(detection.word);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty ||
        size.width <= 2 * _rotationSafetyInset ||
        size.height <= 2 * _rotationSafetyInset) {
      return;
    }

    final layout = _measureCard(
      detection,
      1,
      maximumCanvasWidth: size.width,
    );
    final cardRect = Rect.fromLTWH(
      _rotationSafetyInset,
      _rotationSafetyInset,
      size.width - 2 * _rotationSafetyInset,
      size.height - 2 * _rotationSafetyInset,
    );

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(rotationRadians)
      ..translate(-size.width / 2, -size.height / 2);

    final radius = Radius.circular(
      math.min(12, cardRect.shortestSide * 0.14),
    );
    final cardRRect = RRect.fromRectAndRadius(cardRect, radius);
    final shadowRect = cardRect.shift(const Offset(0, 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, radius),
      Paint()..color = const Color(0x332D1B12),
    );
    canvas.drawRRect(
      cardRRect,
      Paint()..color = const Color(0xFFFDF6EC),
    );

    final borderPaint = Paint()
      ..color = const Color(0xFFB07748)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas
      ..drawRRect(cardRRect, borderPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cardRect.deflate(1.4).shift(const Offset(0.5, 0)),
          radius,
        ),
        borderPaint..color = const Color(0x88B07748),
      );

    final contentLeft = cardRect.left + _horizontalPadding;
    var top = cardRect.top + _verticalPadding;
    final badgeRect = Rect.fromLTWH(
      contentLeft,
      top,
      22,
      _badgeHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFFFFE0B2),
    );
    _textPainter(
      index.clamp(1, 99).toString().padLeft(2, '0'),
      _badgeStyle,
      maxWidth: badgeRect.width - 8,
      maxLines: 1,
    ).paint(canvas, Offset(badgeRect.left + 4, badgeRect.top + 1));

    _textPainter(
      '✦',
      _doodleStyle,
      maxWidth: 14,
      maxLines: 1,
    ).paint(canvas, Offset(cardRect.right - 18, top - 1));

    top += _badgeHeight + _badgeToTextGap;
    layout.word.paint(canvas, Offset(contentLeft, top));
    top += layout.word.height + _textBlockGap;
    layout.phonetic.paint(canvas, Offset(contentLeft, top));
    top += layout.phonetic.height + _textBlockGap;
    layout.meaning.paint(canvas, Offset(contentLeft, top));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VocabNoteCardPainter oldDelegate) {
    return oldDelegate.index != index ||
        oldDelegate.detection.word != detection.word ||
        oldDelegate.detection.phonetic != detection.phonetic ||
        oldDelegate.detection.meaning != detection.meaning ||
        oldDelegate.detection.partOfSpeech != detection.partOfSpeech;
  }
}

class _CardMeasurement {
  const _CardMeasurement({
    required this.size,
    required this.word,
    required this.phonetic,
    required this.meaning,
  });

  final Size size;
  final TextPainter word;
  final TextPainter phonetic;
  final TextPainter meaning;
}

_CardMeasurement _measureCard(
  VocabDetection detection,
  double scale, {
  double? maximumCanvasWidth,
}) {
  final maximumContentWidth =
      (maximumCanvasWidth ?? vocabNoteCardMaxWidth * scale) -
          2 * (_rotationSafetyInset + _horizontalPadding) * scale;
  final word = _textPainter(
    detection.word.trim(),
    vocabNoteCardWordStyle,
    maxWidth: maximumContentWidth,
  );
  final phonetic = _textPainter(
    _optionalMetadata(detection.phonetic),
    vocabNoteCardPhoneticStyle,
    maxWidth: maximumContentWidth,
  );
  final meaning = _textPainter(
    _optionalMetadata(detection.meaning),
    vocabNoteCardMeaningStyle,
    maxWidth: maximumContentWidth,
  );
  final contentWidth = math.max(
    word.width,
    math.max(phonetic.width, meaning.width),
  );
  final cardSize = Size(
    contentWidth + 2 * _horizontalPadding * scale,
    2 * _verticalPadding * scale +
        _badgeHeight * scale +
        _badgeToTextGap * scale +
        word.height +
        phonetic.height +
        meaning.height +
        2 * _textBlockGap * scale,
  );
  final size = Size(
    cardSize.width + 2 * _rotationSafetyInset * scale,
    cardSize.height + 2 * _rotationSafetyInset * scale,
  );

  return _CardMeasurement(
    size: size,
    word: word,
    phonetic: phonetic,
    meaning: meaning,
  );
}

TextPainter _textPainter(
  String text,
  TextStyle style, {
  required double maxWidth,
  int? maxLines,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(1, maxWidth));
}

String _optionalMetadata(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

const TextStyle _badgeStyle = TextStyle(
  color: Color(0xFFE56B2F),
  fontSize: 9,
  fontWeight: FontWeight.w800,
  height: 1.2,
);

const TextStyle _doodleStyle = TextStyle(
  color: Color(0xFFE98B3A),
  fontSize: 13,
  fontWeight: FontWeight.w700,
  height: 1,
);
