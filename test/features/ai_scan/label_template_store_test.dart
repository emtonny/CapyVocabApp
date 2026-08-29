import 'package:capy_vocab/features/ai_scan/presentation/label_template_store.dart';
import 'package:capy_vocab/features/ai_scan/presentation/label_visual_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = LabelTemplateStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lưu và đọc lại đầy đủ style badge tách biệt', () async {
    final style = LabelVisualStyle.customDefault.copyWith(
      badgeColor: const Color(0xFFEAF8EE),
      badgeTextColor: Colors.black,
      badgeBorderColor: const Color(0xFF3E7A45),
      badgeBorderThickness: LabelBorderThickness.bold,
      badgeShape: LabelBadgeShape.soft,
    );

    await store.save(name: 'Capy bạc hà', style: style);
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'Capy bạc hà');
    expect(
      loaded.single.style,
      style,
      reason: _styleDifferences(loaded.single.style, style).join(', '),
    );
  });

  test('tên trùng không phân biệt hoa thường cập nhật thay vì nhân đôi',
      () async {
    await store.save(
      name: 'Capy Hồng',
      style: LabelVisualStyle.customDefault,
    );
    final replacement = LabelVisualStyle.customDefault.copyWith(
      cardColor: const Color(0xFFFFF1F3),
    );

    final saved = await store.save(name: '  capy hồng  ', style: replacement);

    expect(saved, hasLength(1));
    expect(saved.single.name, 'capy hồng');
    expect(saved.single.style, replacement);
  });

  test('dữ liệu local hỏng được bỏ qua an toàn', () async {
    SharedPreferences.setMockInitialValues({
      'saved_label_templates_v1': '{not-json',
    });

    expect(await store.load(), isEmpty);
  });
}

List<String> _styleDifferences(
  LabelVisualStyle actual,
  LabelVisualStyle expected,
) {
  final values = <(String, Object, Object)>[
    ('textColor', actual.textColor, expected.textColor),
    ('meaningColor', actual.meaningColor, expected.meaningColor),
    ('cardColor', actual.cardColor, expected.cardColor),
    ('borderColor', actual.borderColor, expected.borderColor),
    ('badgeColor', actual.badgeColor, expected.badgeColor),
    ('badgeTextColor', actual.badgeTextColor, expected.badgeTextColor),
    ('badgeBorderColor', actual.badgeBorderColor, expected.badgeBorderColor),
    ('connectorColor', actual.connectorColor, expected.connectorColor),
    (
      'connectorHaloColor',
      actual.connectorHaloColor,
      expected.connectorHaloColor,
    ),
    ('objectBorderColor', actual.objectBorderColor, expected.objectBorderColor),
    ('objectFillColor', actual.objectFillColor, expected.objectFillColor),
  ];
  return [
    for (final (name, actualValue, expectedValue) in values)
      if (actualValue != expectedValue) '$name: $actualValue != $expectedValue',
  ];
}
