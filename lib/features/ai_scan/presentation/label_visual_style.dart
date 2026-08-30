import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../vocab_scan/presentation/label_connector_painter.dart';

enum NoteLabelTemplate { standard, minimal, custom }

enum LabelCornerStyle { square, soft, round }

enum LabelBadgeShape { square, soft, pill }

enum LabelBorderThickness { thin, medium, bold }

enum ConnectorThickness { thin, medium, bold }

enum LabelSticker {
  none,
  deer,
  capybara,
  star,
  book,
  dog,
  cat,
  rabbit,
  bear,
  panda,
  koala,
  fox,
  lion,
  tiger,
  cow,
  pig,
  frog,
  monkey,
  paw,
  strawberry,
  avocado,
  apple,
  pizza,
  cupcake,
  donut,
  cake,
  chocolate,
  candy,
  coffee,
  milkTea,
  heart,
  ribbon,
  crown,
  balloon,
  teddyBear,
  clover,
  cherryBlossom,
  rainbow,
  fire,
  lightning,
  notebook,
  pencil,
  pin,
  palette,
  tag,
  bulb,
  target,
  rocket,
}

enum LabelCornerIcon {
  none,
  cookie,
  pin,
  heart,
  star,
  sparkles,
  paw,
  flower,
  clover,
  fire,
  crown,
  ribbon,
  strawberry,
  coffee,
  book,
  bulb,
}

extension LabelStickerData on LabelSticker {
  String get emoji => switch (this) {
        LabelSticker.none => '',
        LabelSticker.deer => '🦌',
        LabelSticker.capybara => '🦫',
        LabelSticker.star => '⭐',
        LabelSticker.book => '📚',
        LabelSticker.dog => '🐶',
        LabelSticker.cat => '🐱',
        LabelSticker.rabbit => '🐰',
        LabelSticker.bear => '🐻',
        LabelSticker.panda => '🐼',
        LabelSticker.koala => '🐨',
        LabelSticker.fox => '🦊',
        LabelSticker.lion => '🦁',
        LabelSticker.tiger => '🐯',
        LabelSticker.cow => '🐮',
        LabelSticker.pig => '🐷',
        LabelSticker.frog => '🐸',
        LabelSticker.monkey => '🐵',
        LabelSticker.paw => '🐾',
        LabelSticker.strawberry => '🍓',
        LabelSticker.avocado => '🥑',
        LabelSticker.apple => '🍎',
        LabelSticker.pizza => '🍕',
        LabelSticker.cupcake => '🧁',
        LabelSticker.donut => '🍩',
        LabelSticker.cake => '🍰',
        LabelSticker.chocolate => '🍫',
        LabelSticker.candy => '🍬',
        LabelSticker.coffee => '☕',
        LabelSticker.milkTea => '🧋',
        LabelSticker.heart => '💖',
        LabelSticker.ribbon => '🎀',
        LabelSticker.crown => '👑',
        LabelSticker.balloon => '🎈',
        LabelSticker.teddyBear => '🧸',
        LabelSticker.clover => '🍀',
        LabelSticker.cherryBlossom => '🌸',
        LabelSticker.rainbow => '🌈',
        LabelSticker.fire => '🔥',
        LabelSticker.lightning => '⚡',
        LabelSticker.notebook => '📖',
        LabelSticker.pencil => '✏️',
        LabelSticker.pin => '📌',
        LabelSticker.palette => '🎨',
        LabelSticker.tag => '🏷️',
        LabelSticker.bulb => '💡',
        LabelSticker.target => '🎯',
        LabelSticker.rocket => '🚀',
      };

  String get label => switch (this) {
        LabelSticker.none => 'Không dùng',
        LabelSticker.deer => 'Hươu',
        LabelSticker.capybara => 'Capybara',
        LabelSticker.star => 'Ngôi sao',
        LabelSticker.book => 'Sách vở',
        LabelSticker.dog => 'Cún con',
        LabelSticker.cat => 'Mèo con',
        LabelSticker.rabbit => 'Thỏ trắng',
        LabelSticker.bear => 'Gấu nâu',
        LabelSticker.panda => 'Gấu trúc',
        LabelSticker.koala => 'Koala',
        LabelSticker.fox => 'Cáo đỏ',
        LabelSticker.lion => 'Sư tử',
        LabelSticker.tiger => 'Hổ con',
        LabelSticker.cow => 'Bò sữa',
        LabelSticker.pig => 'Heo hồng',
        LabelSticker.frog => 'Ếch xanh',
        LabelSticker.monkey => 'Khỉ con',
        LabelSticker.paw => 'Dấu chân',
        LabelSticker.strawberry => 'Dâu tây',
        LabelSticker.avocado => 'Quả bơ',
        LabelSticker.apple => 'Táo đỏ',
        LabelSticker.pizza => 'Pizza',
        LabelSticker.cupcake => 'Cupcake',
        LabelSticker.donut => 'Donut',
        LabelSticker.cake => 'Bánh kem',
        LabelSticker.chocolate => 'Socola',
        LabelSticker.candy => 'Kẹo ngọt',
        LabelSticker.coffee => 'Cà phê',
        LabelSticker.milkTea => 'Trà sữa',
        LabelSticker.heart => 'Trái tim',
        LabelSticker.ribbon => 'Nơ hồng',
        LabelSticker.crown => 'Vương miện',
        LabelSticker.balloon => 'Bóng bay',
        LabelSticker.teddyBear => 'Gấu bông',
        LabelSticker.clover => 'Cỏ 4 lá',
        LabelSticker.cherryBlossom => 'Hoa anh đào',
        LabelSticker.rainbow => 'Cầu vồng',
        LabelSticker.fire => 'Lửa cháy',
        LabelSticker.lightning => 'Tia chớp',
        LabelSticker.notebook => 'Sách mở',
        LabelSticker.pencil => 'Bút chì',
        LabelSticker.pin => 'Ghim đỏ',
        LabelSticker.palette => 'Bảng vẽ',
        LabelSticker.tag => 'Thẻ tag',
        LabelSticker.bulb => 'Bóng đèn',
        LabelSticker.target => 'Mục tiêu',
        LabelSticker.rocket => 'Tên lửa',
      };
}

extension LabelCornerIconData on LabelCornerIcon {
  String get emoji => switch (this) {
        LabelCornerIcon.none => '',
        LabelCornerIcon.cookie => '🍪',
        LabelCornerIcon.pin => '📌',
        LabelCornerIcon.heart => '💖',
        LabelCornerIcon.star => '⭐',
        LabelCornerIcon.sparkles => '✨',
        LabelCornerIcon.paw => '🐾',
        LabelCornerIcon.flower => '🌸',
        LabelCornerIcon.clover => '🍀',
        LabelCornerIcon.fire => '🔥',
        LabelCornerIcon.crown => '👑',
        LabelCornerIcon.ribbon => '🎀',
        LabelCornerIcon.strawberry => '🍓',
        LabelCornerIcon.coffee => '☕',
        LabelCornerIcon.book => '📚',
        LabelCornerIcon.bulb => '💡',
      };

  String get label => switch (this) {
        LabelCornerIcon.none => 'Không dùng',
        LabelCornerIcon.cookie => 'Bánh quy',
        LabelCornerIcon.pin => 'Ghim',
        LabelCornerIcon.heart => 'Trái tim',
        LabelCornerIcon.star => 'Ngôi sao',
        LabelCornerIcon.sparkles => 'Lấp lánh',
        LabelCornerIcon.paw => 'Dấu chân',
        LabelCornerIcon.flower => 'Bông hoa',
        LabelCornerIcon.clover => 'Cỏ 4 lá',
        LabelCornerIcon.fire => 'Lửa',
        LabelCornerIcon.crown => 'Vương miện',
        LabelCornerIcon.ribbon => 'Nơ xinh',
        LabelCornerIcon.strawberry => 'Dâu tây',
        LabelCornerIcon.coffee => 'Cà phê',
        LabelCornerIcon.book => 'Sách vở',
        LabelCornerIcon.bulb => 'Bóng đèn',
      };
}

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
    this.customStickerEmoji,
    this.customCornerIconEmoji,
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
  final String? customStickerEmoji;
  final String? customCornerIconEmoji;

  String get effectiveStickerEmoji => customStickerEmoji ?? sticker.emoji;
  String get effectiveCornerIconEmoji =>
      customCornerIconEmoji ?? cornerIcon.emoji;

  bool get showDeerSticker => effectiveStickerEmoji.isNotEmpty;
  bool get showCookieIcon => effectiveCornerIconEmoji.isNotEmpty;

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
    String? customStickerEmoji,
    String? customCornerIconEmoji,
    bool clearCustomStickerEmoji = false,
    bool clearCustomCornerIconEmoji = false,
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
      customStickerEmoji: clearCustomStickerEmoji
          ? null
          : (customStickerEmoji ?? this.customStickerEmoji),
      customCornerIconEmoji: clearCustomCornerIconEmoji
          ? null
          : (customCornerIconEmoji ?? this.customCornerIconEmoji),
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
            other.cornerIcon == cornerIcon &&
            other.customStickerEmoji == customStickerEmoji &&
            other.customCornerIconEmoji == customCornerIconEmoji;
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
        customStickerEmoji,
        customCornerIconEmoji,
      ]);
}

bool _sameColor(Color first, Color second) =>
    first.toARGB32() == second.toARGB32();
