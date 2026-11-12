import 'package:capy_vocab/features/home/presentation/widgets/laurel_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ranks use gold silver bronze and other ranks have no wreath',
      (tester) async {
    for (final rank in [1, 2, 3, 4]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: LaurelAvatar.rank(
            rank: rank,
            size: 60,
            animate: false,
            child: const ColoredBox(color: Colors.yellow),
          ),
        ),
      ));
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<LaurelWreathPainter>();
      final style = LaurelStyle.forRank(rank);
      if (style == null) {
        expect(painters, isEmpty);
      } else {
        expect(painters.single.leafLight, style.leafLight);
        expect(painters.single.leafDark, style.leafDark);
        expect(painters.single.ribbon, style.ribbon);
        expect(painters.single.leavesPerSide, style.leavesPerSide);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('finishes growing and supports disabling animation mid-flight',
      (tester) async {
    Widget preview(bool animate) => MaterialApp(
          home: Center(
            child: LaurelAvatar(
              size: 60,
              animate: animate,
              child: const ColoredBox(color: Colors.yellow),
            ),
          ),
        );
    double progress() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<LaurelWreathPainter>()
        .single
        .progress;

    await tester.pumpWidget(preview(true));
    expect(progress(), 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(progress(), inExclusiveRange(0, 1));
    await tester.pumpWidget(preview(false));
    await tester.pump();
    expect(progress(), 1);
    await tester.pumpWidget(preview(true));
    await tester.pumpAndSettle();
    expect(progress(), 1);
    expect(tester.takeException(), isNull);
  });
}
