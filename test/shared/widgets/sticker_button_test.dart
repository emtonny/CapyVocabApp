import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('draws the raised sticker geometry and optional icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        StickerButton(
          label: 'Chọn tất cả',
          icon: const Icon(Icons.check_box_outline_blank, size: 14),
          onPressed: () {},
        ),
      ),
    );

    final painter = _painter(tester);
    expect(painter.bottomEdgeThickness, 5);
    expect(painter.shadowOffset, 4);
    expect(painter.shadowBlurRadius, 0);
    expect(painter.faceColor, const Color(0xFFFFFFFF));
    expect(painter.edgeColor, const Color(0xFFCCCCCC));
    expect(painter.outlineColor, const Color(0xFF3A2E2B));

    final label = tester.widget<Text>(find.text('Chọn tất cả'));
    expect(label.style?.fontFamily, contains('Nunito'));
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(label.style?.decoration, TextDecoration.none);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

    final semanticsHandle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(StickerButton)).label,
      'Chọn tất cả',
    );
    semanticsHandle.dispose();

    final painterRect = tester.getRect(
      find.byKey(const Key('sticker-button-painter')),
    );
    final contentCenter = tester.getCenter(
      find.byKey(const Key('sticker-button-content')),
    );
    final faceCenterY = painterRect.top + (2 + painterRect.height - 5) / 2;
    expect(contentCenter.dy, closeTo(faceCenterY, 0.01));
  });

  testWidgets('compresses while held then releases and calls onPressed', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      _testApp(
        StickerButton(
          label: 'Chọn tất cả',
          onPressed: () => presses++,
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StickerButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 80));

    final pressedPainter = _painter(tester);
    expect(pressedPainter.bottomEdgeThickness, 2);
    expect(pressedPainter.shadowOffset, 1);
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const Key('sticker-button-motion')),
          )
          .transform
          ?.getTranslation()
          .y,
      3,
    );

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(presses, 1);
    expect(_painter(tester).bottomEdgeThickness, 5);
    expect(_painter(tester).shadowOffset, 4);
  });

  testWidgets('quick tap plays full compression and bounces back up', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      _testApp(
        StickerButton(
          label: 'Nhấn nhanh',
          onPressed: () => presses++,
        ),
      ),
    );

    // Instant tap (down and up in 0ms)
    await tester.tap(find.byType(StickerButton));
    await tester.pump();
    // Mid-press: it has animated to fully compressed state
    await tester.pump(const Duration(milliseconds: 70));

    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const Key('sticker-button-motion')),
          )
          .transform
          ?.getTranslation()
          .y,
      3,
    );
    expect(_painter(tester).bottomEdgeThickness, 2);

    // Bounce back up
    await tester.pumpAndSettle();

    expect(presses, 1);
    expect(_painter(tester).bottomEdgeThickness, 5);
    expect(_painter(tester).shadowOffset, 4);
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const Key('sticker-button-motion')),
          )
          .transform
          ?.getTranslation()
          .y,
      0,
    );
  });

  testWidgets('matches the sticker button golden', (tester) async {
    tester.view.physicalSize = const Size(220, 90);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        StickerButton(label: 'Chọn tất cả', onPressed: () {}),
      ),
    );

    await expectLater(
      find.byType(StickerButton),
      matchesGoldenFile('goldens/sticker_button.png'),
    );
  });

  testWidgets('supports colored expanded and accessible icon-only variants', (
    tester,
  ) async {
    const orange = Color(0xFFFF9600);
    const orangeEdge = Color(0xFFC96F00);
    await tester.pumpWidget(
      _testApp(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              child: StickerButton(
                text: 'Thêm ảnh',
                onPressed: () {},
                surfaceColor: orange,
                edgeColor: orangeEdge,
                textColor: Colors.white,
                isExpanded: true,
              ),
            ),
            const StickerButton(
              semanticLabel: 'Khôi phục',
              icon: Icon(Icons.restore_rounded),
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    final coloredButton = tester.widget<StickerButton>(
      find.widgetWithText(StickerButton, 'Thêm ảnh'),
    );
    expect(coloredButton.surfaceColor, orange);
    expect(coloredButton.edgeColor, orangeEdge);
    expect(
      tester.getSize(find.widgetWithText(StickerButton, 'Thêm ảnh')).width,
      180,
    );
    expect(find.bySemanticsLabel('Khôi phục'), findsOneWidget);
    expect(find.byIcon(Icons.restore_rounded), findsOneWidget);
  });

  testWidgets('flat variant removes the physical edge and keeps a crisp shadow',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        StickerButton(
          semanticLabel: 'Xóa',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () {},
          flat: true,
        ),
      ),
    );

    final painter = _painter(tester);
    expect(painter.flat, isTrue);
    expect(painter.bottomEdgeThickness, 0);
    expect(painter.shadowOffset, 3);
    expect(painter.shadowSpread, 0);
    expect(painter.showShadow, isTrue);
  });

  testWidgets('can remove the shadow without changing the flat face', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        StickerButton(
          semanticLabel: 'Yêu thích',
          icon: const Icon(Icons.star_border_rounded),
          onPressed: () {},
          flat: true,
          showShadow: false,
        ),
      ),
    );

    final painter = _painter(tester);
    expect(painter.flat, isTrue);
    expect(painter.showShadow, isFalse);
  });
}

StickerButtonPainter _painter(WidgetTester tester) {
  return tester
      .widget<CustomPaint>(find.byKey(const Key('sticker-button-painter')))
      .painter! as StickerButtonPainter;
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}
