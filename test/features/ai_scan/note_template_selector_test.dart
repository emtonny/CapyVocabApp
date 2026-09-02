import 'package:capy_vocab/features/ai_scan/presentation/label_template_store.dart';
import 'package:capy_vocab/features/ai_scan/presentation/label_visual_style.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/note_template_selector.dart';
import 'package:capy_vocab/features/vocab_scan/presentation/label_connector_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('custom editor responsive, lưu mẫu và cập nhật đủ các nhóm', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var selectedTemplate = NoteLabelTemplate.standard;
    var customStyle = LabelVisualStyle.customDefault;
    var upgradeRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NoteTemplateSelector(
                selectedTemplate: selectedTemplate,
                customStyle: customStyle,
                onTemplateChanged: (template) {
                  setState(() => selectedTemplate = template);
                },
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
                onUpgradeRequested: () => upgradeRequests++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('label-template-minimal')));
    await tester.pumpAndSettle();
    expect(selectedTemplate, NoteLabelTemplate.minimal);

    await tester.tap(find.byKey(const Key('label-template-custom')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('before-style-preview')), findsOneWidget);
    expect(find.byKey(const Key('after-style-preview')), findsOneWidget);

    await _expandSection(tester, 'Box label');
    final presetColorCenter =
        tester.getCenter(find.byKey(const Key('border-color-0')));
    final customColorCenter = tester.getCenter(
      find.byKey(const Key('border-color-custom-picker')),
    );
    expect(
      presetColorCenter.dy,
      customColorCenter.dy,
      reason: 'Tự chọn màu phải nằm cùng hàng với bảng màu ở viewport 320px',
    );

    await _tapVisible(tester, const Key('corner-style-2'));
    await _tapVisible(tester, const Key('border-thickness-2'));
    await _tapVisible(tester, const Key('border-color-1'));
    final cardOpacity = tester.widget<Slider>(
      find.byKey(const Key('card-opacity-slider')),
    );
    cardOpacity.onChanged!(0.4);
    await tester.pump();
    expect(customStyle.cornerStyle, LabelCornerStyle.round);
    expect(customStyle.borderThickness, LabelBorderThickness.bold);
    expect(customStyle.borderColor, Colors.black);
    expect(customStyle.cardOpacity, 0.4);

    await _expandSection(tester, 'Badge số');
    await _tapVisible(tester, const Key('badge-shape-1'));
    await _tapVisible(tester, const Key('badge-border-thickness-0'));
    await _tapVisible(tester, const Key('badge-color-3'));
    await _tapVisible(tester, const Key('badge-text-color-1'));
    expect(customStyle.badgeShape, LabelBadgeShape.soft);
    expect(customStyle.badgeBorderThickness, LabelBorderThickness.thin);
    expect(customStyle.badgeColor, const Color(0xFFEAF8EE));
    expect(customStyle.badgeTextColor, Colors.black);

    await _expandSection(tester, 'Đường nối & mũi tên');
    await _tapVisible(tester, const Key('connector-line-1'));
    await _tapVisible(tester, const Key('connector-thickness-2'));
    await _tapVisible(tester, const Key('arrow-style-2'));
    await _tapVisible(tester, const Key('toggle-connector-halo'));
    expect(customStyle.connectorLineStyle, ConnectorLineStyle.dashed);
    expect(customStyle.connectorThickness, ConnectorThickness.bold);
    expect(customStyle.connectorArrowStyle, ConnectorArrowStyle.dot);
    expect(customStyle.showConnectorHalo, isFalse);

    await _expandSection(tester, 'Trang trí');
    await _tapVisible(tester, const Key('sticker-picker-button'));
    await _tapVisible(tester, const Key('sticker-1'));
    await _tapVisible(tester, const Key('corner-icon-picker-button'));
    await _tapVisible(tester, const Key('corner-icon-2'));
    expect(customStyle.sticker, LabelSticker.capybara);
    expect(customStyle.cornerIcon, LabelCornerIcon.heart);

    await _tapVisible(tester, const Key('save-label-template-button'));
    await tester.enterText(
      find.byKey(const Key('label-template-name-field')),
      'Capy bạc hà',
    );
    await tester.tap(find.byKey(const Key('confirm-save-label-template')));
    await tester.pumpAndSettle();
    expect(find.text('Capy bạc hà'), findsOneWidget);
    final savedCard = find.byKey(const Key('saved-label-template-0'));
    final customCard = find.byKey(const Key('label-template-custom'));
    expect(savedCard, findsOneWidget);
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
    expect(_isTemplateCardSelected(tester, savedCard), isTrue);
    expect(_isTemplateCardSelected(tester, customCard), isFalse);
    expect(
      tester.getTopLeft(savedCard).dx,
      lessThan(tester.getTopLeft(customCard).dx),
      reason: 'Mẫu đã lưu phải đứng trước Tự thiết kế ở hàng cuối',
    );

    final savedStyle = customStyle;
    await _tapVisible(tester, const Key('label-template-minimal'));
    await _tapVisible(tester, const Key('saved-label-template-0'));
    expect(customStyle, savedStyle);
    expect(selectedTemplate, NoteLabelTemplate.custom);
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
    expect(_isTemplateCardSelected(tester, savedCard), isTrue);
    expect(_isTemplateCardSelected(tester, customCard), isFalse);

    await _tapVisible(tester, const Key('label-template-custom'));
    expect(
      find.byKey(const Key('label-template-pro-limit-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
    await tester.tap(
      find.byKey(const Key('upgrade-label-template-pro-button')),
    );
    await tester.pumpAndSettle();
    expect(upgradeRequests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pro có thể mở editor để tạo thêm sau khi đã có mẫu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const store = LabelTemplateStore();
    await store.save(
      name: 'Mẫu đầu tiên',
      style: LabelVisualStyle.customDefault,
    );

    var selectedTemplate = NoteLabelTemplate.standard;
    var customStyle = LabelVisualStyle.customDefault;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NoteTemplateSelector(
                selectedTemplate: selectedTemplate,
                customStyle: customStyle,
                isPro: true,
                onTemplateChanged: (template) {
                  setState(() => selectedTemplate = template);
                },
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, const Key('label-template-custom'));

    expect(find.byKey(const Key('custom-label-editor')), findsOneWidget);
    expect(
      find.byKey(const Key('label-template-pro-limit-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('đóng editor bỏ trạng thái chọn khỏi ô Tự thiết kế', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var selectedTemplate = NoteLabelTemplate.standard;
    var customStyle = LabelVisualStyle.customDefault;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: NoteTemplateSelector(
                selectedTemplate: selectedTemplate,
                customStyle: customStyle,
                onTemplateChanged: (template) {
                  setState(() => selectedTemplate = template);
                },
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
              ),
            ),
          ),
        ),
      ),
    );

    final customCard = find.byKey(const Key('label-template-custom'));
    await tester.tap(customCard);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('custom-label-editor')), findsOneWidget);
    expect(_isTemplateCardSelected(tester, customCard), isTrue);

    await _tapVisible(tester, const Key('label-template-custom'));
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
    expect(_isTemplateCardSelected(tester, customCard), isFalse);
  });

  testWidgets('selector survives repeated viewport breakpoint changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var style = LabelVisualStyle.customDefault;

    await tester.binding.setSurfaceSize(const Size(440, 956));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NoteTemplateSelector(
                selectedTemplate: NoteLabelTemplate.custom,
                customStyle: style,
                onTemplateChanged: (_) {},
                onCustomStyleChanged: (value) {
                  setState(() => style = value);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final size in const [
      Size(800, 600),
      Size(320, 700),
      Size(440, 956),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'failed at $size');
    }
  });

  testWidgets(
      'mở selector với NoteLabelTemplate.custom không tự bật editor bảng bên dưới',
      (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const store = LabelTemplateStore();
    await store.save(
      name: 'Mẫu có sẵn',
      style: LabelVisualStyle.customDefault,
    );

    var selectedTemplate = NoteLabelTemplate.custom;
    var customStyle = LabelVisualStyle.customDefault;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NoteTemplateSelector(
                selectedTemplate: selectedTemplate,
                customStyle: customStyle,
                onTemplateChanged: (template) {
                  setState(() => selectedTemplate = template);
                },
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Editor should not be open by default
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
    final savedCard = find.byKey(const Key('saved-label-template-0'));
    final customCard = find.byKey(const Key('label-template-custom'));
    expect(savedCard, findsOneWidget);
    expect(_isTemplateCardSelected(tester, savedCard), isTrue);
    expect(_isTemplateCardSelected(tester, customCard), isFalse);
  });

  testWidgets(
      'nhấn giữ mẫu đã lưu cho phép xoá mẫu để tạo mẫu mới trên gói Free', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const store = LabelTemplateStore();
    await store.save(
      name: 'Mẫu muốn xoá',
      style: LabelVisualStyle.customDefault,
    );

    var selectedTemplate = NoteLabelTemplate.custom;
    var customStyle = LabelVisualStyle.customDefault;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NoteTemplateSelector(
                selectedTemplate: selectedTemplate,
                customStyle: customStyle,
                onTemplateChanged: (template) {
                  setState(() => selectedTemplate = template);
                },
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Long press on saved template
    await tester.longPress(find.byKey(const Key('saved-label-template-0')));
    await tester.pumpAndSettle();

    expect(find.text('Xoá mẫu đã lưu?'), findsOneWidget);
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();

    // The template should be gone
    expect(find.byKey(const Key('saved-label-template-0')), findsNothing);

    // Free user can now tap "Tự thiết kế" to open editor
    await _tapVisible(tester, const Key('label-template-custom'));
    expect(find.byKey(const Key('custom-label-editor')), findsOneWidget);
    expect(
        find.byKey(const Key('label-template-pro-limit-dialog')), findsNothing);
  });

  testWidgets('mở dialog tự chọn màu, lăn slider đổi màu và áp dụng thành công',
      (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var customStyle = LabelVisualStyle.customDefault;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NoteTemplateSelector(
                selectedTemplate: NoteLabelTemplate.custom,
                customStyle: customStyle,
                onTemplateChanged: (_) {},
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open editor
    await _tapVisible(tester, const Key('label-template-custom'));
    expect(find.byKey(const Key('custom-label-editor')), findsOneWidget);

    // Expand Box label section
    await _expandSection(tester, 'Box label');

    // Tap custom color picker for border color
    await _tapVisible(tester, const Key('border-color-custom-picker'));
    expect(find.text('Tự chọn Màu viền'), findsOneWidget);

    // Adjust Hue slider
    final hueSlider =
        tester.widget<Slider>(find.byKey(const Key('color-hue-slider')));
    hueSlider.onChanged!(180.0);
    await tester.pump();

    // Confirm color
    await tester.tap(find.byKey(const Key('confirm-custom-color-button')));
    await tester.pumpAndSettle();

    // Color should have updated
    expect(customStyle.borderColor,
        isNot(LabelVisualStyle.customDefault.borderColor));
  });

  testWidgets(
      'khi mở editor rồi click lại để đóng thì khôi phục chọn về mẫu ban đầu và bỏ chọn ô Tự thiết kế',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var selectedTemplate = NoteLabelTemplate.standard;
    var customStyle = LabelVisualStyle.customDefault;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: NoteTemplateSelector(
                selectedTemplate: selectedTemplate,
                customStyle: customStyle,
                onTemplateChanged: (template) {
                  setState(() => selectedTemplate = template);
                },
                onCustomStyleChanged: (style) {
                  setState(() => customStyle = style);
                },
              ),
            ),
          ),
        ),
      ),
    );

    final standardCard = find.byKey(const Key('label-template-standard'));
    final customCard = find.byKey(const Key('label-template-custom'));

    // Ban đầu Standard được chọn
    expect(_isTemplateCardSelected(tester, standardCard), isTrue);
    expect(_isTemplateCardSelected(tester, customCard), isFalse);

    // Mở editor
    await tester.tap(customCard);
    await tester.pumpAndSettle();
    expect(selectedTemplate, NoteLabelTemplate.custom);
    expect(find.byKey(const Key('custom-label-editor')), findsOneWidget);
    expect(_isTemplateCardSelected(tester, customCard), isTrue);
    expect(_isTemplateCardSelected(tester, standardCard), isFalse);

    // Đóng editor bằng cách click lại vào ô Tự thiết kế
    await tester.tap(customCard);
    await tester.pumpAndSettle();
    expect(selectedTemplate, NoteLabelTemplate.standard);
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
    expect(_isTemplateCardSelected(tester, customCard), isFalse);
    expect(_isTemplateCardSelected(tester, standardCard), isTrue);
  });
}

bool? _isTemplateCardSelected(WidgetTester tester, Finder card) {
  final semantics = find
      .ancestor(of: card, matching: find.byType(Semantics))
      .evaluate()
      .map((element) => element.widget as Semantics)
      .firstWhere((widget) => widget.properties.button == true);
  return semantics.properties.selected;
}

Future<void> _expandSection(WidgetTester tester, String title) async {
  final finder = find.text(title);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
