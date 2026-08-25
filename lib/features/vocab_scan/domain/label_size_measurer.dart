import 'package:flutter/material.dart';

import '../../../core/services/gemini_vision_service.dart';
import 'label_unit_geometry.dart';

enum LabelCardMode { compact, full }

@immutable
class LabelLineLayout {
  const LabelLineLayout({
    required this.rowHeight,
    required this.lineCount,
    required this.lineSpacing,
  });

  final double rowHeight;
  final int lineCount;
  final double lineSpacing;

  double get contentHeight =>
      rowHeight * lineCount + lineSpacing * (lineCount - 1);

  double centeredLineTop(int index, double lineHeight) {
    assert(index >= 0 && index < lineCount);
    assert(lineHeight >= 0 && lineHeight <= rowHeight);
    return index * (rowHeight + lineSpacing) + (rowHeight - lineHeight) / 2;
  }
}

LabelLineLayout resolveLabelLineLayout({
  required List<double> lineHeights,
  required double lineSpacing,
}) {
  assert(lineHeights.isNotEmpty);
  assert(lineSpacing >= 0);
  final rowHeight = lineHeights.fold<double>(
    0,
    (maximum, height) => height > maximum ? height : maximum,
  );
  return LabelLineLayout(
    rowHeight: rowHeight,
    lineCount: lineHeights.length,
    lineSpacing: lineSpacing,
  );
}

class LabelPaddingConfig {
  const LabelPaddingConfig({
    required this.horizontal,
    required this.vertical,
    double? bottom,
  })  : assert(horizontal >= 0),
        assert(vertical >= 0),
        assert(bottom == null || bottom >= 0),
        bottom = bottom ?? vertical;

  final double horizontal;

  /// Top padding. Kept as [vertical] for backward compatibility.
  final double vertical;
  final double bottom;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelPaddingConfig &&
            other.horizontal == horizontal &&
            other.vertical == vertical &&
            other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(horizontal, vertical, bottom);
}

class LabelStyleConfig {
  const LabelStyleConfig({
    required this.badgeTextStyle,
    required this.badgeWidth,
    required this.badgeHeight,
    required this.wordStyle,
    required this.phoneticStyle,
    required this.meaningStyle,
    required this.padding,
    required this.mode,
    this.iconWidth,
    this.iconGap = 0,
    this.lineSpacing = 0,
    this.uniformLineRows = false,
    this.textDirection = TextDirection.ltr,
    this.badgeLeftInset = 0,
    this.badgeCardOverlap = 3,
    this.deerStickerSize = Size.zero,
    this.cookieIconSize = Size.zero,
  })  : assert(badgeWidth > 0),
        assert(badgeHeight > 0),
        assert(iconWidth == null || iconWidth >= 0),
        assert(iconGap >= 0),
        assert(lineSpacing >= 0),
        assert(badgeLeftInset >= 0),
        assert(badgeCardOverlap >= 0 && badgeCardOverlap <= badgeHeight);

  /// Style used only for the centered number inside the pill badge.
  final TextStyle badgeTextStyle;

  /// Fixed outer size of the floating badge in this style tier.
  final double badgeWidth;
  final double badgeHeight;

  Size get badgeSize => Size(badgeWidth, badgeHeight);

  final TextStyle wordStyle;
  final TextStyle phoneticStyle;
  final TextStyle meaningStyle;

  final LabelPaddingConfig padding;
  final LabelCardMode mode;
  final double? iconWidth;
  final double iconGap;
  final double lineSpacing;
  final bool uniformLineRows;
  final TextDirection textDirection;
  final double badgeLeftInset;
  final double badgeCardOverlap;
  final Size deerStickerSize;
  final Size cookieIconSize;

  LabelStyleConfig copyWith({
    TextStyle? badgeTextStyle,
    double? badgeWidth,
    double? badgeHeight,
    TextStyle? wordStyle,
    TextStyle? phoneticStyle,
    TextStyle? meaningStyle,
    LabelPaddingConfig? padding,
    LabelCardMode? mode,
    double? iconWidth,
    bool clearIconWidth = false,
    double? iconGap,
    double? lineSpacing,
    bool? uniformLineRows,
    TextDirection? textDirection,
    double? badgeLeftInset,
    double? badgeCardOverlap,
    Size? deerStickerSize,
    Size? cookieIconSize,
  }) {
    return LabelStyleConfig(
      badgeTextStyle: badgeTextStyle ?? this.badgeTextStyle,
      badgeWidth: badgeWidth ?? this.badgeWidth,
      badgeHeight: badgeHeight ?? this.badgeHeight,
      wordStyle: wordStyle ?? this.wordStyle,
      phoneticStyle: phoneticStyle ?? this.phoneticStyle,
      meaningStyle: meaningStyle ?? this.meaningStyle,
      padding: padding ?? this.padding,
      mode: mode ?? this.mode,
      iconWidth: clearIconWidth ? null : iconWidth ?? this.iconWidth,
      iconGap: iconGap ?? this.iconGap,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      uniformLineRows: uniformLineRows ?? this.uniformLineRows,
      textDirection: textDirection ?? this.textDirection,
      badgeLeftInset: badgeLeftInset ?? this.badgeLeftInset,
      badgeCardOverlap: badgeCardOverlap ?? this.badgeCardOverlap,
      deerStickerSize: deerStickerSize ?? this.deerStickerSize,
      cookieIconSize: cookieIconSize ?? this.cookieIconSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelStyleConfig &&
            other.badgeTextStyle == badgeTextStyle &&
            other.badgeWidth == badgeWidth &&
            other.badgeHeight == badgeHeight &&
            other.wordStyle == wordStyle &&
            other.phoneticStyle == phoneticStyle &&
            other.meaningStyle == meaningStyle &&
            other.padding == padding &&
            other.mode == mode &&
            other.iconWidth == iconWidth &&
            other.iconGap == iconGap &&
            other.lineSpacing == lineSpacing &&
            other.uniformLineRows == uniformLineRows &&
            other.textDirection == textDirection &&
            other.badgeLeftInset == badgeLeftInset &&
            other.badgeCardOverlap == badgeCardOverlap &&
            other.deerStickerSize == deerStickerSize &&
            other.cookieIconSize == cookieIconSize;
  }

  @override
  int get hashCode => Object.hash(
        badgeTextStyle,
        badgeWidth,
        badgeHeight,
        wordStyle,
        phoneticStyle,
        meaningStyle,
        padding,
        mode,
        iconWidth,
        iconGap,
        lineSpacing,
        uniformLineRows,
        textDirection,
        badgeLeftInset,
        badgeCardOverlap,
        deerStickerSize,
        cookieIconSize,
      );
}

class LabelSize {
  const LabelSize({
    required this.width,
    required this.height,
    this.collisionGeometry,
  });

  final double width;
  final double height;
  final LabelUnitGeometry? collisionGeometry;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelSize && other.width == width && other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'LabelSize(width: $width, height: $height)';
}

class LabelSizeMeasurer {
  const LabelSizeMeasurer();

  LabelSize measure(VocabDetection word, LabelStyleConfig config) {
    final cardSize = measureCard(word, config);
    final geometry = resolveLabelUnitGeometry(
      footprintTopLeft: Offset.zero,
      cardSize: Size(cardSize.width, cardSize.height),
      badgeSize: config.badgeSize,
      badgeLeftInset: config.badgeLeftInset,
      badgeCardOverlap: config.badgeCardOverlap,
      deerStickerSize: config.deerStickerSize,
      cookieIconSize: config.cookieIconSize,
    );

    return LabelSize(
      width: geometry.footprintRect.width,
      height: geometry.footprintRect.height,
      collisionGeometry: geometry,
    );
  }

  /// Measures only the visible three-line card, excluding the badge.
  ///
  /// [measure] wraps this size with the fixed badge geometry before returning
  /// the complete footprint consumed by candidate generation and placement.
  LabelSize measureCard(VocabDetection word, LabelStyleConfig config) {
    final wordSize = _measureText(
      TextSpan(text: word.word, style: config.wordStyle),
      config.textDirection,
    );
    final phoneticSize = _measureText(
      TextSpan(text: word.phonetic, style: config.phoneticStyle),
      config.textDirection,
    );
    final meaningSize = _measureText(
      TextSpan(text: word.meaningVi, style: config.meaningStyle),
      config.textDirection,
    );
    final iconWidth = config.iconWidth ?? 0;
    final iconGap = iconWidth > 0 ? config.iconGap : 0;
    final wordRowWidth = wordSize.width + iconGap + iconWidth;
    final wordRowHeight =
        wordSize.height > iconWidth ? wordSize.height : iconWidth;
    final lineSizes = [
      Size(wordRowWidth, wordRowHeight),
      phoneticSize,
      meaningSize,
    ];
    final contentWidth = lineSizes.fold<double>(
      0,
      (maximum, size) => size.width > maximum ? size.width : maximum,
    );
    final contentHeight = config.uniformLineRows
        ? resolveLabelLineLayout(
            lineHeights:
                lineSizes.map((size) => size.height).toList(growable: false),
            lineSpacing: config.lineSpacing,
          ).contentHeight
        : lineSizes.fold<double>(
              0,
              (total, size) => total + size.height,
            ) +
            config.lineSpacing * (lineSizes.length - 1);

    final minimumCardWidth = minimumLabelCardWidth(
      badgeSize: config.badgeSize,
      badgeLeftInset: config.badgeLeftInset,
      deerStickerSize: config.deerStickerSize,
      cookieIconSize: config.cookieIconSize,
    );
    return LabelSize(
      width: _maximum(
        contentWidth + config.padding.horizontal * 2,
        minimumCardWidth,
      ),
      height: contentHeight + config.padding.vertical + config.padding.bottom,
    );
  }

  List<LabelSize> measureAll(
    List<VocabDetection> words,
    LabelStyleConfig config,
  ) {
    return List.unmodifiable(words.map((word) => measure(word, config)));
  }

  Size _measureText(InlineSpan text, TextDirection textDirection) {
    final painter = TextPainter(
      text: text,
      maxLines: 1,
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }
}

double _maximum(double first, double second) {
  return first > second ? first : second;
}
