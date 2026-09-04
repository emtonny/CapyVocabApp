import 'package:capy_vocab/shared/widgets/graph_paper_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GraphPaperBackground & GraphPaperPainter tests', () {
    testWidgets('GraphPaperScaffold applies the shared background to its body',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: GraphPaperScaffold(
            body: Text('Page content'),
            bottomNavigationBar: SizedBox(
              height: 100,
              child: Text('Navigation'),
            ),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(GraphPaperBackground), findsOneWidget);
      expect(find.text('Page content'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
      expect(
        tester.getSize(find.byType(GraphPaperBackground)),
        const Size(400, 800),
      );
    });

    testWidgets('renders child on top of graph paper background',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GraphPaperBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('GraphPaperPainter defaults match user specifications', () {
      const painter = GraphPaperPainter();

      // Warm cream base lightened ~20% #FBF8EE
      expect(painter.backgroundColor, const Color(0xFFFBF8EE));
      expect(painter.backgroundColor.toARGB32(), 0xFFFBF8EE);

      // Grid opacity reduced another 10%: ~13% -> ~12% (0x1E1A1A1A)
      expect(painter.lineWidth, 1.0);
      expect(painter.lineColor, const Color(0x1E1A1A1A));

      // 20-24px square spacing
      expect(painter.spacing, greaterThanOrEqualTo(20.0));
      expect(painter.spacing, lessThanOrEqualTo(24.0));
      expect(painter.spacing, 24.0);
    });

    test('GraphPaperPainter shouldRepaint returns false when unchanged', () {
      const painter1 = GraphPaperPainter();
      const painter2 = GraphPaperPainter();

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('GraphPaperPainter shouldRepaint returns true when properties change',
        () {
      const painter1 = GraphPaperPainter(spacing: 24.0);
      const painter2 = GraphPaperPainter(spacing: 20.0);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}
