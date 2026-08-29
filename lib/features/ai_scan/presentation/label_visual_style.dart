import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../vocab_scan/presentation/label_connector_painter.dart';

enum NoteLabelTemplate { standard, minimal, custom }

enum LabelCornerStyle { square, soft, round }

enum LabelBadgeShape { square, soft, pill }

enum LabelBorderThickness { thin, medium, bold }

enum ConnectorThickness { thin, medium, bold }

enum LabelSticker { none, deer, capybara, star, book }

enum LabelCornerIcon { none, cookie, pin, heart }

extension LabelBorderThicknessValue on LabelBorderThickness {
  double get value => switch (this) {
        LabelBorderThickness.thin => 0.8,
        LabelBorderThickness.medium => 1.25,
        LabelBorderThickness.bold => 2.2,
      };
}

extension ConnectorThicknessValue on ConnectorThickness {
  double get value => switch (this) {
        ConnectorThickness.thin => 1.1,
        ConnectorThickness.medium => 1.7,
        ConnectorThickness.bold => 2.6,
      };
}

@immutable
class LabelVisualStyle {
  const LabelVisualStyle({
    required this.textColor,
    required this.meaningColor,
    required this.cardColor,
    required this.cardOpacity,
    required this.cornerStyle,
    required this.borderColor,
    required this.borderThickness,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.badgeBorderColor,
    required this.badgeBorderThickness,
    required this.badgeShape,
    required this.connectorColor,
    required this.connectorHaloColor,
    required this.connectorLineStyle,
    required this.connectorThickness,
    required this.connectorArrowStyle,
    required this.showConnectorHalo,
    required this.showBoundingBox,
    required this.objectBorderColor,
    required this.objectFillColor,
    required this.objectFillOpacity,
    required this.sticker,
    required this.cornerIcon,
  })  : assert(cardOpacity >= 0 && cardOpacity <= 1),
        assert(objectFillOpacity >= 0 && objectFillOpacity <= 1);

  static const standard = LabelVisualStyle(
    textColor: Color(0xFF8F6E50),
    meaningColor: Color(0xFFB00000),
    cardColor: Color(0xFFFFFEFA),
    cardOpacity: 1,
    cornerStyle: LabelCornerStyle.soft,
    borderColor: AppColors.capyBrown,
    borderThickness: LabelBorderThickness.medium,
    badgeColor: Color(0xFFFFFEFA),
    badgeTextColor: Color(0xFF8F6E50),
    badgeBorderColor: AppColors.capyBrown,
    badgeBorderThickness: LabelBorderThickness.medium,
    badgeShape: LabelBadgeShape.pill,
    connectorColor: Color(0xFFD85B24),
    connectorHaloColor: Color(0xFFFFFCF5),
    connectorLineStyle: ConnectorLineStyle.adaptive,
    connectorThickness: ConnectorThickness.medium,
    connectorArrowStyle: ConnectorArrowStyle.rounded,
    showConnectorHalo: true,
    showBoundingBox: true,
    objectBorderColor: Colors.deepOrange,
    objectFillColor: Colors.amber,
    objectFillOpacity: 0.22,
    sticker: LabelSticker.deer,
    cornerIcon: LabelCornerIcon.cookie,
  );

  static const minimal = LabelVisualStyle(
    textColor: Colors.black,
    meaningColor: Colors.black,
    cardColor: Colors.white,
    cardOpacity: 1,
    cornerStyle: LabelCornerStyle.soft,
    borderColor: Colors.black,
    borderThickness: LabelBorderThickness.medium,
    badgeColor: Colors.white,
    badgeTextColor: Colors.black,
    badgeBorderColor: Colors.black,
    badgeBorderThickness: LabelBorderThickness.medium,
    badgeShape: LabelBadgeShape.pill,
    connectorColor: Colors.black,
    connectorHaloColor: Colors.white,
    connectorLineStyle: ConnectorLineStyle.adaptive,
    connectorThickness: ConnectorThickness.medium,
    connectorArrowStyle: ConnectorArrowStyle.rounded,
    showConnectorHalo: true,
    showBoundingBox: true,
    objectBorderColor: Colors.black,
    objectFillColor: Colors.white,
    objectFillOpacity: 0.1,
    sticker: LabelSticker.none,
    cornerIcon: LabelCornerIcon.none,
  );

  static final customDefault = standard.copyWith(
    connectorLineStyle: ConnectorLineStyle.solid,
  );

  final Color textColor;
  final Color meaningColor;
  final Color cardColor;
  final double cardOpacity;
  final LabelCornerStyle cornerStyle;
  final Color borderColor;
  final LabelBorderThickness borderThickness;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color badgeBorderColor;
  final LabelBorderThickness badgeBorderThickness;
  final LabelBadgeShape badgeShape;
  final Color connectorColor;
  final Color connectorHaloColor;
  final ConnectorLineStyle connectorLineStyle;
  final ConnectorThickness connectorThickness;
  final ConnectorArrowStyle connectorArrowStyle;
  final bool showConnectorHalo;
  final bool showBoundingBox;
  final Color objectBorderColor;
  final Color objectFillColor;
  final double objectFillOpacity;
  final LabelSticker sticker;
  final LabelCornerIcon cornerIcon;

  bool get showDeerSticker => sticker != LabelSticker.none;
  bool get showCookieIcon => cornerIcon != LabelCornerIcon.none;

  LabelVisualStyle copyWith({
    Color? textColor,
    Color? meaningColor,
    Color? cardColor,
    double? cardOpacity,
    LabelCornerStyle? cornerStyle,
    Color? borderColor,
    LabelBorderThickness? borderThickness,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? badgeBorderColor,
    LabelBorderThickness? badgeBorderThickness,
    LabelBadgeShape? badgeShape,
    Color? connectorColor,
    Color? connectorHaloColor,
    ConnectorLineStyle? connectorLineStyle,
    ConnectorThickness? connectorThickness,
    ConnectorArrowStyle? connectorArrowStyle,
    bool? showConnectorHalo,
    bool? showBoundingBox,
    Color? objectBorderColor,
    Color? objectFillColor,
    double? objectFillOpacity,
    LabelSticker? sticker,
    LabelCornerIcon? cornerIcon,
    bool? showDeerSticker,
    bool? showCookieIcon,
  }) {
    return LabelVisualStyle(
      textColor: textColor ?? this.textColor,
      meaningColor: meaningColor ?? this.meaningColor,
      cardColor: cardColor ?? this.cardColor,
      cardOpacity: cardOpacity ?? this.cardOpacity,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      borderColor: borderColor ?? this.borderColor,
      borderThickness: borderThickness ?? this.borderThickness,
      badgeColor: badgeColor ?? this.badgeColor,
      badgeTextColor: badgeTextColor ?? this.badgeTextColor,
      badgeBorderColor: badgeBorderColor ?? this.badgeBorderColor,
      badgeBorderThickness: badgeBorderThickness ?? this.badgeBorderThickness,
      badgeShape: badgeShape ?? this.badgeShape,
      connectorColor: connectorColor ?? this.connectorColor,
      connectorHaloColor: connectorHaloColor ?? this.connectorHaloColor,
      connectorLineStyle: connectorLineStyle ?? this.connectorLineStyle,
      connectorThickness: connectorThickness ?? this.connectorThickness,
      connectorArrowStyle: connectorArrowStyle ?? this.connectorArrowStyle,
      showConnectorHalo: showConnectorHalo ?? this.showConnectorHalo,
      showBoundingBox: showBoundingBox ?? this.showBoundingBox,
      objectBorderColor: objectBorderColor ?? this.objectBorderColor,
      objectFillColor: objectFillColor ?? this.objectFillColor,
      objectFillOpacity: objectFillOpacity ?? this.objectFillOpacity,
      sticker: sticker ??
          (showDeerSticker == false
              ? LabelSticker.none
              : showDeerSticker == true && this.sticker == LabelSticker.none
                  ? LabelSticker.deer
                  : this.sticker),
      cornerIcon: cornerIcon ??
          (showCookieIcon == false
              ? LabelCornerIcon.none
              : showCookieIcon == true &&
                      this.cornerIcon == LabelCornerIcon.none
                  ? LabelCornerIcon.cookie
                  : this.cornerIcon),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelVisualStyle &&
            _sameColor(other.textColor, textColor) &&
            _sameColor(other.meaningColor, meaningColor) &&
            _sameColor(other.cardColor, cardColor) &&
            other.cardOpacity == cardOpacity &&
            other.cornerStyle == cornerStyle &&
            _sameColor(other.borderColor, borderColor) &&
            other.borderThickness == borderThickness &&
            _sameColor(other.badgeColor, badgeColor) &&
            _sameColor(other.badgeTextColor, badgeTextColor) &&
            _sameColor(other.badgeBorderColor, badgeBorderColor) &&
            other.badgeBorderThickness == badgeBorderThickness &&
            other.badgeShape == badgeShape &&
            _sameColor(other.connectorColor, connectorColor) &&
            _sameColor(other.connectorHaloColor, connectorHaloColor) &&
            other.connectorLineStyle == connectorLineStyle &&
            other.connectorThickness == connectorThickness &&
            other.connectorArrowStyle == connectorArrowStyle &&
            other.showConnectorHalo == showConnectorHalo &&
            other.showBoundingBox == showBoundingBox &&
            _sameColor(other.objectBorderColor, objectBorderColor) &&
            _sameColor(other.objectFillColor, objectFillColor) &&
            other.objectFillOpacity == objectFillOpacity &&
            other.sticker == sticker &&
            other.cornerIcon == cornerIcon;
  }

  @override
  int get hashCode => Object.hashAll([
        textColor.toARGB32(),
        meaningColor.toARGB32(),
        cardColor.toARGB32(),
        cardOpacity,
        cornerStyle,
        borderColor.toARGB32(),
        borderThickness,
        badgeColor.toARGB32(),
        badgeTextColor.toARGB32(),
        badgeBorderColor.toARGB32(),
        badgeBorderThickness,
        badgeShape,
        connectorColor.toARGB32(),
        connectorHaloColor.toARGB32(),
        connectorLineStyle,
        connectorThickness,
        connectorArrowStyle,
        showConnectorHalo,
        showBoundingBox,
        objectBorderColor.toARGB32(),
        objectFillColor.toARGB32(),
        objectFillOpacity,
        sticker,
        cornerIcon,
      ]);
}

bool _sameColor(Color first, Color second) =>
    first.toARGB32() == second.toARGB32();
