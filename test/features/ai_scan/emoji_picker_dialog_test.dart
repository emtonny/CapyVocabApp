import 'package:capy_vocab/features/ai_scan/presentation/widgets/emoji_picker_dialog.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHarness({
    required String currentEmoji,
    required ValueChanged<String?> onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open-dialog-btn'),
            onPressed: () async {
              final result = await EmojiPickerDialog.show(
                context,
                title: 'Sticker',
                currentEmoji: currentEmoji,
                controlKey: 'test-emoji',
              );
              onSelected(result);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  testWidgets('EmojiPickerDialog searches by keyword in Vietnamese and English',
      (tester) async {
    String? selectedResult;
    await tester.pumpWidget(
      buildHarness(
        currentEmoji: '🦌',
        onSelected: (val) => selectedResult = val,
      ),
    );

    // Open dialog
    await tester.tap(find.byKey(const Key('open-dialog-btn')));
    await tester.pumpAndSettle();

    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text('Kho biểu tượng sắc màu chuẩn iPhone'), findsOneWidget);

    // Search for "mèo"
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'mèo');
    await tester.pumpAndSettle();

    expect(find.text('🐱'), findsOneWidget);

    // Tap the cat emoji
    await tester.tap(find.text('🐱'));
    await tester.pumpAndSettle();

    expect(selectedResult, '🐱');
  });

  testWidgets('EmojiPickerDialog supports selecting category and quick clear',
      (tester) async {
    String? selectedResult;
    await tester.pumpWidget(
      buildHarness(
        currentEmoji: '🍓',
        onSelected: (val) => selectedResult = val,
      ),
    );

    // Open dialog
    await tester.tap(find.byKey(const Key('open-dialog-btn')));
    await tester.pumpAndSettle();

    // Switch to category "Mặt cười"
    final smileyChip = find.text('Mặt cười');
    expect(smileyChip, findsOneWidget);
    await tester.tap(smileyChip);
    await tester.pumpAndSettle();

    expect(find.text('😀'), findsOneWidget);

    // Click "Không dùng"
    final clearAction = find.text('Không dùng');
    expect(clearAction, findsOneWidget);
    await tester.tap(clearAction);
    await tester.pumpAndSettle();

    expect(selectedResult, '');
  });

  testWidgets(
      'EmojiPickerDialog supports selecting Quốc kỳ category and searching flags',
      (tester) async {
    String? selectedResult;
    await tester.pumpWidget(
      buildHarness(
        currentEmoji: '🦌',
        onSelected: (val) => selectedResult = val,
      ),
    );

    // Open dialog
    await tester.tap(find.byKey(const Key('open-dialog-btn')));
    await tester.pumpAndSettle();

    // Switch to category "Quốc kỳ"
    final flagChip = find.text('Quốc kỳ');
    expect(flagChip, findsOneWidget);
    await tester.ensureVisible(flagChip);
    await tester.pumpAndSettle();
    await tester.tap(flagChip);
    await tester.pumpAndSettle();

    // Vietnam flag is present in Quốc kỳ
    expect(find.text('🇻🇳'), findsWidgets);

    // Search for "nhat ban"
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'nhat ban');
    await tester.pumpAndSettle();

    expect(find.text('🇯🇵'), findsOneWidget);

    await tester.tap(find.text('🇯🇵'));
    await tester.pumpAndSettle();

    expect(selectedResult, '🇯🇵');
  });

  testWidgets('dialog neo-brutal giữ ô emoji đủ lớn trên màn hình hẹp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      buildHarness(currentEmoji: '🦌', onSelected: (_) {}),
    );
    await tester.tap(find.byKey(const Key('open-dialog-btn')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(dialog.backgroundColor, AppColors.softWhite);
    expect(dialog.elevation, 0);
    expect(shape.side.color, AppColors.ink);
    expect(shape.side.width, 2.8);
    final firstEmoji = tester.getSize(
      find.byKey(const Key('test-emoji-0')),
    );
    expect(firstEmoji.width, greaterThanOrEqualTo(48));
    expect(firstEmoji.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
