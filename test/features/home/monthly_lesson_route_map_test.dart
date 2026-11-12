import 'package:capy_vocab/features/home/presentation/providers/daily_lesson_provider.dart';
import 'package:capy_vocab/features/home/presentation/widgets/monthly_lesson_route_map.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder node(int day, {int month = 10, int year = 2026}) => find.byKey(Key(
    'home-lesson-node-$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}'));

Future<void> openMap(WidgetTester tester, DateTime today,
    {DateTime? anchor, ValueChanged<DailyLessonNode>? onOpen}) async {
  final overview = buildDailyLessonOverview(
    snapshots: const [],
    selection: HomeLessonMapSelection(
        period: LessonMapPeriod.month, anchorDay: anchor ?? today),
    boundary: const AccountDayBoundary(Duration.zero),
    now: today,
    dailyTarget: 10,
  );
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Padding(
    padding: const EdgeInsets.all(12),
    child: MonthlyLessonRouteMap(
        key: ValueKey(anchor ?? today),
        nodes: overview.nodes,
        today: today,
        onOpen: onOpen ?? (_) {}),
  ))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'current cycle ends today and arrows move exactly seven calendar days',
      (tester) async {
    DailyLessonNode? opened;
    await openMap(tester, DateTime.utc(2026, 10, 8),
        onOpen: (day) => opened = day);
    expect(node(14).hitTestable(), findsOneWidget);
    final background = find.byKey(const Key('home-map-fixed-background'));
    final landscape = tester.widget<Image>(background).image;
    expect((landscape as AssetImage).assetName,
        'assets/images/learning_map_forest_background.png');
    await tester
        .runAsync(() => precacheImage(landscape, tester.element(background)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RawImage>(find.descendant(
                of: background, matching: find.byType(RawImage)))
            .image,
        isNotNull);
    final landscapeSize = tester.getSize(background);
    final topPosition = tester.getTopLeft(node(14));
    final bottomPosition = tester.getTopLeft(node(8));
    expect(node(8), findsOneWidget);
    expect(find.byType(StickerButton), findsNWidgets(9));
    for (var day = 9; day <= 14; day++) {
      expect(tester.widget<StickerButton>(node(day)).surfaceColor,
          const Color(0xFFFF6B6B));
      expect(tester.widget<StickerButton>(node(day)).onPressed, isNull);
      expect(find.text('$day/10'), findsOneWidget);
    }
    expect(tester.widget<StickerButton>(node(8)).surfaceColor,
        const Color(0xFFE5E5E5));
    expect(node(1), findsNothing);
    expect(find.text('8/10'), findsOneWidget);
    final previous = find.byKey(const Key('home-monthly-map-previous'));
    final next = find.byKey(const Key('home-monthly-map-next'));
    expect(tester.widget<StickerButton>(next).onPressed, isNull);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(find.byType(StickerButton), findsNWidgets(9));
    expect(node(8), findsNothing);
    expect(tester.widget<Image>(background).image, landscape);
    expect(tester.getSize(background), landscapeSize);
    expect(tester.getTopLeft(node(7)), topPosition);
    expect(tester.getTopLeft(node(1)), bottomPosition);
    for (var day = 1; day <= 7; day++) {
      expect(node(day), findsOneWidget);
      expect(find.text('$day/10'), findsOneWidget);
    }
    expect(
        tester.getTopLeft(node(7)).dy, lessThan(tester.getTopLeft(node(1)).dy));
    expect(tester.widget<StickerButton>(previous).onPressed, isNull);
    final scroll = find
        .descendant(
            of: find.byKey(const Key('home-monthly-map-scroll')),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(node(1), 200, scrollable: scroll);
    await tester.tap(node(1));
    expect(opened?.day, DateTime.utc(2026, 10, 1));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(node(14).hitTestable(), findsOneWidget);
    expect(node(1), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('past months paginate correctly including leap February',
      (tester) async {
    for (final sample in [
      (2026, 9, 30),
      (2027, 2, 28),
      (2028, 2, 29),
      (2026, 10, 31)
    ]) {
      final anchor = DateTime.utc(sample.$1, sample.$2);
      await openMap(tester, DateTime.utc(sample.$1, sample.$2 + 1, 8),
          anchor: anchor);
      expect(find.byType(StickerButton), findsNWidgets(9));
      expect(node(sample.$3 - 6, month: sample.$2, year: sample.$1),
          findsOneWidget);
      expect(node(sample.$3, month: sample.$2, year: sample.$1).hitTestable(),
          findsOneWidget);
      final next = find.byKey(const Key('home-monthly-map-next'));
      expect(tester.widget<StickerButton>(next).onPressed, isNull);
      await tester.tap(find.byKey(const Key('home-monthly-map-previous')));
      await tester.pumpAndSettle();
      expect(find.byType(StickerButton), findsNWidgets(9));
      expect(
          node(((sample.$3 - 1) ~/ 7) * 7, month: sample.$2, year: sample.$1)
              .hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('seven-day navigation remains bounded at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await openMap(tester, DateTime.utc(2026, 10, 31));
      expect(
          tester
              .getSize(find.byKey(const Key('home-monthly-map-viewport')))
              .height,
          lessThanOrEqualTo(480));
      final previous = find.byKey(const Key('home-monthly-map-previous'));
      for (var i = 0; i < 4; i++) {
        await tester.tap(previous);
        await tester.pumpAndSettle();
      }
      expect(node(7).hitTestable(), findsOneWidget);
      expect(node(1), findsOneWidget);
      expect(tester.widget<StickerButton>(previous).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
