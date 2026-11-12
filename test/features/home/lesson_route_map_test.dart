import 'package:capy_vocab/features/home/presentation/providers/daily_lesson_provider.dart';
import 'package:capy_vocab/features/home/presentation/widgets/lesson_route_map.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'photo presence controls sticker color regardless of lesson status',
      (tester) async {
    final today = DateTime.utc(2026, 10, 8);
    DailyLessonNode day(DateTime date, int photos, DailyLessonStatus status) =>
        DailyLessonNode(
          day: date,
          startsAt: date,
          endsAt: date.add(const Duration(days: 1)),
          status: status,
          targetWords: 10,
          validWords: 0,
          correctWords: 0,
          photoCount: photos,
          projectedYuzu: 0,
          exclusionReasons: const {},
          photoNoteIds: const [],
          hasSystemPending: false,
        );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LessonRouteMap(
      nodes: [
        day(today.subtract(const Duration(days: 1)), 1,
            DailyLessonStatus.expired),
        day(today, 0, DailyLessonStatus.ready)
      ],
      today: today,
      onOpen: (_) {},
    ))));
    final withPhoto = tester.widget<StickerButton>(
        find.byKey(const Key('home-lesson-node-2026-10-07')));
    final withoutPhoto = tester.widget<StickerButton>(
        find.byKey(const Key('home-lesson-node-2026-10-08')));
    expect(withPhoto.surfaceColor, AppColors.duoGreen);
    expect(withoutPhoto.surfaceColor, const Color(0xFFE5E5E5));
    expect(withPhoto.borderColor, AppColors.ink);
    expect(withPhoto.radius, 999);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'weekly route has seven day buttons and forwards the selected day',
      (tester) async {
    final today = DateTime.utc(2026, 10, 8);
    final overview = buildDailyLessonOverview(
      snapshots: const [],
      selection: HomeLessonMapSelection(
          period: LessonMapPeriod.week, anchorDay: today),
      boundary: const AccountDayBoundary(Duration.zero),
      now: today,
      dailyTarget: 10,
    );
    DailyLessonNode? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
        child: LessonRouteMap(
            nodes: overview.nodes,
            today: today,
            onOpen: (node) => opened = node),
      )),
    ));
    final buttons = find.byWidgetPredicate((widget) =>
        widget is StickerButton &&
        widget.key.toString().contains('home-lesson-node-'));
    expect(buttons, findsNWidgets(7));
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('7/7'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    final dayButton = find.byKey(const Key('home-lesson-node-2026-10-08'));
    await tester.ensureVisible(dayButton);
    await tester.tap(dayButton);
    expect(opened?.day, today);
    final first = find.byKey(const Key('home-lesson-node-2026-10-02'));
    expect(
        tester.getTopLeft(dayButton).dy, lessThan(tester.getTopLeft(first).dy));
    expect(tester.widget<StickerButton>(dayButton).surfaceColor,
        const Color(0xFFE5E5E5));
    expect(tester.takeException(), isNull);
  });
}
