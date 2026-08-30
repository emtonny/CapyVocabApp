import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../vocab_scan/presentation/label_connector_painter.dart';
import 'label_visual_style.dart';

class SavedLabelTemplate {
  const SavedLabelTemplate({
    required this.name,
    required this.style,
    this.iconEmoji,
  });

  final String name;
  final LabelVisualStyle style;
  final String? iconEmoji;

  String get effectiveEmoji {
    if (iconEmoji != null && iconEmoji!.isNotEmpty) return iconEmoji!;
    if (style.showDeerSticker && style.effectiveStickerEmoji.isNotEmpty) {
      return style.effectiveStickerEmoji;
    }
    return '🏷️';
  }
}

class LabelTemplateStore {
  const LabelTemplateStore();

  static const _storageKey = 'saved_label_templates_v1';

  Future<List<SavedLabelTemplate>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (_decodeTemplate(item) case final template?) template,
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<List<SavedLabelTemplate>> save({
    required String name,
    required LabelVisualStyle style,
    String? iconEmoji,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }

    final templates = [...await load()];
    final duplicateIndex = templates.indexWhere(
      (template) => template.name.toLowerCase() == normalizedName.toLowerCase(),
    );
    final saved = SavedLabelTemplate(
      name: normalizedName,
      style: style,
      iconEmoji: iconEmoji,
    );
    if (duplicateIndex == -1) {
      templates.add(saved);
    } else {
      templates[duplicateIndex] = saved;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(templates.map(_encodeTemplate).toList(growable: false)),
    );
    return List.unmodifiable(templates);
  }

  Future<List<SavedLabelTemplate>> delete(String name) async {
    final normalizedName = name.trim().toLowerCase();
    final templates = [...await load()];
    templates.removeWhere((t) => t.name.toLowerCase() == normalizedName);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(templates.map(_encodeTemplate).toList(growable: false)),
    );
    return List.unmodifiable(templates);
  }
}

Map<String, Object> _encodeTemplate(SavedLabelTemplate template) => {
      'name': template.name,
      'style': _encodeStyle(template.style),
      if (template.iconEmoji != null) 'iconEmoji': template.iconEmoji!,
    };

SavedLabelTemplate? _decodeTemplate(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final name = value['name'];
  final style = value['style'];
  final iconEmoji = value['iconEmoji'] as String?;
  if (name is! String ||
      name.trim().isEmpty ||
      style is! Map<String, dynamic>) {
    return null;
  }
  try {
    return SavedLabelTemplate(
      name: name.trim(),
      style: _decodeStyle(style),
      iconEmoji: iconEmoji,
    );
  } on FormatException {
    return null;
  }
}

Map<String, Object> _encodeStyle(LabelVisualStyle style) => {
      'textColor': style.textColor.toARGB32(),
      'meaningColor': style.meaningColor.toARGB32(),
      'cardColor': style.cardColor.toARGB32(),
      'cardOpacity': style.cardOpacity,
      'cornerStyle': style.cornerStyle.name,
      'borderColor': style.borderColor.toARGB32(),
      'borderThickness': style.borderThickness.name,
      'badgeColor': style.badgeColor.toARGB32(),
      'badgeTextColor': style.badgeTextColor.toARGB32(),
      'badgeBorderColor': style.badgeBorderColor.toARGB32(),
      'badgeBorderThickness': style.badgeBorderThickness.name,
      'badgeShape': style.badgeShape.name,
      'connectorColor': style.connectorColor.toARGB32(),
      'connectorHaloColor': style.connectorHaloColor.toARGB32(),
      'connectorLineStyle': style.connectorLineStyle.name,
      'connectorThickness': style.connectorThickness.name,
      'connectorArrowStyle': style.connectorArrowStyle.name,
      'showConnectorHalo': style.showConnectorHalo,
      'showBoundingBox': style.showBoundingBox,
      'objectBorderColor': style.objectBorderColor.toARGB32(),
      'objectFillColor': style.objectFillColor.toARGB32(),
      'objectFillOpacity': style.objectFillOpacity,
      'sticker': style.sticker.name,
      'cornerIcon': style.cornerIcon.name,
      if (style.customStickerEmoji != null)
        'customStickerEmoji': style.customStickerEmoji!,
      if (style.customCornerIconEmoji != null)
        'customCornerIconEmoji': style.customCornerIconEmoji!,
    };

LabelVisualStyle _decodeStyle(Map<String, dynamic> json) => LabelVisualStyle(
      textColor: _color(json, 'textColor'),
      meaningColor: _color(json, 'meaningColor'),
      cardColor: _color(json, 'cardColor'),
      cardOpacity: _double(json, 'cardOpacity'),
      cornerStyle: _enum(json, 'cornerStyle', LabelCornerStyle.values),
      borderColor: _color(json, 'borderColor'),
      borderThickness:
          _enum(json, 'borderThickness', LabelBorderThickness.values),
      badgeColor: _color(json, 'badgeColor'),
      badgeTextColor: _color(json, 'badgeTextColor'),
      badgeBorderColor: _color(json, 'badgeBorderColor'),
      badgeBorderThickness: _enum(
        json,
        'badgeBorderThickness',
        LabelBorderThickness.values,
      ),
      badgeShape: _enum(json, 'badgeShape', LabelBadgeShape.values),
      connectorColor: _color(json, 'connectorColor'),
      connectorHaloColor: _color(json, 'connectorHaloColor'),
      connectorLineStyle:
          _enum(json, 'connectorLineStyle', ConnectorLineStyle.values),
      connectorThickness:
          _enum(json, 'connectorThickness', ConnectorThickness.values),
      connectorArrowStyle:
          _enum(json, 'connectorArrowStyle', ConnectorArrowStyle.values),
      showConnectorHalo: _bool(json, 'showConnectorHalo'),
      showBoundingBox: _bool(json, 'showBoundingBox'),
      objectBorderColor: _color(json, 'objectBorderColor'),
      objectFillColor: _color(json, 'objectFillColor'),
      objectFillOpacity: _double(json, 'objectFillOpacity'),
      sticker: _enum(json, 'sticker', LabelSticker.values),
      cornerIcon: _enum(json, 'cornerIcon', LabelCornerIcon.values),
      customStickerEmoji: json['customStickerEmoji'] as String?,
      customCornerIconEmoji: json['customCornerIconEmoji'] as String?,
    );

Color _color(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Invalid $key');
  return Color(value);
}

double _double(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Invalid $key');
  final result = value.toDouble();
  if (!result.isFinite || result < 0 || result > 1) {
    throw FormatException('Invalid $key');
  }
  return result;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}

T _enum<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid $key');
  return values.firstWhere(
    (candidate) => candidate.name == value,
    orElse: () => throw FormatException('Invalid $key'),
  );
}
