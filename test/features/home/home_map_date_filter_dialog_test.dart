import 'package:capy_vocab/features/home/presentation/providers/daily_lesson_provider.dart';
import 'package:capy_vocab/features/home/presentation/widgets/home_map_date_filter_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';

void main() {
  testWidgets(
      'calendar selection applies day and period; cancel changes nothing',
      (tester) async {
    ({LessonMapPeriod period, DateTime day})? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await showDialog<({LessonMapPeriod period, DateTime day})>(
            context: context,
            builder: (_) => HomeMapDateFilterDialog(
              today: DateTime.utc(2026, 10, 8),
              selection: HomeLessonMapSelection(
                period: LessonMapPeriod.week,
                anchorDay: DateTime.utc(2026, 10, 8),
              ),
            ),
          );
        },
        child: const Text('Open'),
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(calendar.lastDate, DateTime(2026, 10, 8));
    expect(
        tester
            .widget<StickerButton>(
                find.byKey(const Key('home-map-filter-month-10')))
            .surfaceColor,
        const Color(0xFFFF9800));
    expect(find.text('7 ngày'), findsNothing);
    expect(
        tester.getTopLeft(find.byKey(const Key('home-map-filter-month-10'))).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const Key('home-map-filter-month-1')))
            .dy));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final monthScroll = find.descendant(
      of: find.byKey(const Key('home-map-filter-month-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
        find.byKey(const Key('home-map-filter-month-12')), 180,
        scrollable: monthScroll);
    expect(
        tester
            .widget<StickerButton>(
                find.byKey(const Key('home-map-filter-month-12')))
            .onPressed,
        isNull);
    await tester.scrollUntilVisible(
        find.byKey(const Key('home-map-filter-month-9')), -100,
        scrollable: monthScroll);
    await tester.tap(find.byKey(const Key('home-map-filter-month-9')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 9, 12));
    await tester.pump();
    await tester.tap(find.byKey(const Key('home-map-date-filter-apply')));
    await tester.pumpAndSettle();
    expect(result,
        (period: LessonMapPeriod.month, day: DateTime.utc(2026, 9, 12)));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'narrow dialog keeps both columns usable and clear restores current month',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    ({LessonMapPeriod period, DateTime day})? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        child: const Text('Open'),
        onPressed: () async {
          result = await showDialog<({LessonMapPeriod period, DateTime day})>(
            context: context,
            builder: (_) => HomeMapDateFilterDialog(
              today: DateTime.utc(2026, 10, 8),
              selection: HomeLessonMapSelection(
                period: LessonMapPeriod.month,
                anchorDay: DateTime.utc(2026, 9),
              ),
            ),
          );
        },
      ),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-map-date-filter-clear')));
    await tester.pumpAndSettle();
    expect(result,
        (period: LessonMapPeriod.month, day: DateTime.utc(2026, 10, 8)));
    expect(tester.takeException(), isNull);
  });
}
