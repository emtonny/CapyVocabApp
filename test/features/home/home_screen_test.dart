import 'package:capy_vocab/features/home/presentation/providers/home_provider.dart';
import 'package:capy_vocab/features/home/presentation/providers/daily_lesson_provider.dart';
import 'package:capy_vocab/features/home/presentation/providers/daily_mission_provider.dart';
import 'package:capy_vocab/features/home/presentation/screens/home_screen.dart';
import 'package:capy_vocab/features/home/presentation/widgets/mini_leaderboard_podium.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:capy_vocab/features/home/presentation/providers/weekly_yuzu_leaderboard_provider.dart';
import 'package:capy_vocab/features/home/presentation/providers/period_yuzu_leaderboard_provider.dart';
import 'package:capy_vocab/features/home/domain/yuzu_leaderboard_period.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_session_controller.dart';
import 'package:capy_vocab/features/mini_games/presentation/providers/lesson_session_provider.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:capy_vocab/features/home/data/remote/streak_flame_gateway.dart';
import 'package:capy_vocab/features/home/presentation/providers/streak_flame_provider.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final updatedAt = DateTime(2026, 9, 27, 8, 30);
  late HomeState dashboard;
  late DailyLessonOverview lessonOverview;

  setUp(() {
    dashboard = HomeState(
      userId: 'owner-1',
      displayName: 'Demo 1',
      yuzuBalance: 420,
      pendingYuzu: 35,
      streakDays: 7,
      updatedAt: updatedAt,
    );
    lessonOverview = buildDailyLessonOverview(
      snapshots: const [],
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: DateTime.utc(2026, 9, 27),
      ),
      boundary: const AccountDayBoundary(Duration.zero),
      now: DateTime.utc(2026, 9, 27, 8, 30),
      dailyTarget: 10,
    );
  });

  testWidgets('renders H1 state without a manual coin reward action', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 3,
        lessonOverview: lessonOverview,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('420 xu vàng'), findsOneWidget);
    expect(find.text('35 xu vàng đang chờ đồng bộ'), findsOneWidget);
    expect(find.text('Chào Demo 1!'), findsOneWidget);
    expect(find.text('7 ngày liên tiếp'), findsNothing);
    expect(find.byKey(const Key('home-streak-summary')), findsOneWidget);
    expect(find.text('7 ngày học liên tục'), findsOneWidget);
    expect(find.byKey(const Key('home-unread-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Tổng'), findsOneWidget);
    expect(find.text('Không tải được bảng xếp hạng. Hãy thử lại sau.'),
        findsOneWidget);
    expect(find.text('Thắp lửa'), findsOneWidget);
    expect(find.textContaining('Điểm danh'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('home-mini-leaderboard'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('home-daily-task-card'))).dy,
      ),
    );

    final notificationButton =
        find.byKey(const Key('home-notification-button'));
    final semanticsHandle = tester.ensureSemantics();
    expect(
      tester.getSemantics(notificationButton).label,
      'Thông báo, 3 thông báo chưa đọc',
    );
    semanticsHandle.dispose();
    router.dispose();
  });

  testWidgets('flame increases once and never opens capture', (tester) async {
    var openedScan = false;
    var openedLesson = false;
    final gateway = _TestFlameGateway();
    final router = _router(
        onScan: () => openedScan = true, onLesson: (_) => openedLesson = true);
    addTearDown(router.dispose);
    await tester.pumpWidget(_TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
        flameGateway: gateway));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('home-light-the-flame-button'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('8 ngày học liên tục'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('8 ngày học liên tục'), findsOneWidget);
    expect(find.text('9 ngày học liên tục'), findsNothing);
    expect(openedScan, isFalse);
    expect(openedLesson, isFalse);
    expect(gateway.calls, 2);
  });

  testWidgets('failed flame request preserves the streak and allows retry',
      (tester) async {
    final gateway = _TestFlameGateway()..fail = true;
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
        flameGateway: gateway));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('home-light-the-flame-button'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('7 ngày học liên tục'), findsOneWidget);
    expect(find.text('Chưa thắp lửa được. Kiểm tra kết nối và thử lại.'),
        findsOneWidget);
    gateway.fail = false;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('8 ngày học liên tục'), findsOneWidget);
  });

  testWidgets('missing flame RPC reports backend rollout instead of connection',
      (tester) async {
    final gateway = _TestFlameGateway()
      ..error =
          const PostgrestException(message: 'Missing RPC', code: 'PGRST202');
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
        flameGateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-light-the-flame-button')));
    await tester.pumpAndSettle();
    expect(find.text('7 ngày học liên tục'), findsOneWidget);
    expect(
        find.text(
            'Tính năng thắp lửa chưa được cập nhật trên máy chủ. Vui lòng thử lại sau.'),
        findsOneWidget);
  });

  testWidgets('leaderboard defaults to total and switches all earning periods',
      (tester) async {
    var openedFriends = false;
    final router = _router(onFriends: () => openedFriends = true);
    addTearDown(router.dispose);
    await tester.pumpWidget(_TestApp(
      router: router,
      dashboard: dashboard,
      unreadNotifications: 0,
      lessonOverview: lessonOverview,
      leaderboardError: false,
    ));
    await tester.pumpAndSettle();
    final selector = find.byKey(const Key('home-leaderboard-period-selector'));
    expect(find.text('Tổng'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Tháng này'), findsOneWidget);
    expect(
      tester
          .widget<Container>(
              find.byKey(const Key('home-leaderboard-period-total')))
          .color,
      AppColors.yellow,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const Key('home-leaderboard-period-total')))
          .dy,
      closeTo(tester.getBottomLeft(selector).dy - 8, 1),
    );
    expect(
      tester
          .getTopRight(find.byKey(const Key('home-leaderboard-period-day')))
          .dx,
      closeTo(tester.getTopRight(selector).dx, 1),
    );
    await tester.tap(find.text('Hôm nay'));
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
    expect(find.text('Bạn (Demo 1)'), findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Container>(
              find.byKey(const Key('home-leaderboard-period-day')))
          .color,
      AppColors.yellow,
    );
    await tester.tap(find.text('Tháng này'));
    await tester.pumpAndSettle();
    expect(find.text('456'), findsOneWidget);
    expect(find.text('123'), findsNothing);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuần này'));
    await tester.pumpAndSettle();
    expect(find.text('234'), findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tổng').last);
    await tester.pumpAndSettle();
    expect(find.text('420'), findsOneWidget);
    expect(openedFriends, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps settings and friends navigation working', (tester) async {
    var navigatedToSettings = false;
    var navigatedToFriends = false;
    final router = _router(
      onSettings: () => navigatedToSettings = true,
      onFriends: () => navigatedToFriends = true,
    );

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
      ),
    );
    await tester.pumpAndSettle();

    final settings = find.byKey(const Key('home-settings-button'));
    expect(tester.widget(settings), isA<StickerButton>());
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(navigatedToSettings, isTrue);

    router.go('/home');
    await tester.pumpAndSettle();
    final leaderboard = find.byKey(const Key('home-mini-leaderboard'));
    await tester.ensureVisible(leaderboard);
    await tester.tap(leaderboard);
    await tester.pumpAndSettle();
    expect(navigatedToFriends, isTrue);
    router.dispose();
  });

  testWidgets('shows the cached timestamp when Home is offline',
      (tester) async {
    final router = _router();
    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard.copyWith(isOffline: true),
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-offline-notice')), findsOneWidget);
    expect(
      find.text('Đang offline · dữ liệu Home cập nhật lần cuối 27/09 08:30'),
      findsOneWidget,
    );
    expect(
      find.text('Đang offline · chưa có dữ liệu đã lưu'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    router.dispose();
  });

  testWidgets('H1 layout does not overflow on a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 125,
        lessonOverview: lessonOverview,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('99+'), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.dispose();
  });

  testWidgets('renders H2 daily goal and opens capture for an empty day', (
    tester,
  ) async {
    var openedScan = false;
    final router = _router(onScan: () => openedScan = true);
    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-daily-task-card')), findsOneWidget);
    expect(find.byKey(const Key('home-daily-task-action')), findsNothing);
    expect(find.text('Mục tiêu: 10 từ'), findsNothing);
    await _expandDailyTask(tester);
    expect(find.text('Mục tiêu: 10 từ'), findsOneWidget);
    expect(find.text('0/10 từ hợp lệ'), findsOneWidget);
    expect(find.text('Còn thiếu: 10 từ'), findsOneWidget);
    expect(find.text('Chưa đủ dữ liệu'), findsWidgets);
    expect(find.byKey(const Key('home-lesson-map-grid')), findsOneWidget);

    await tester.tap(find.text('Nhiệm vụ hôm nay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-daily-task-action')), findsNothing);
    expect(find.text('Mục tiêu: 10 từ'), findsNothing);
    await _expandDailyTask(tester);

    await _expandDailyTask(tester);
    final dailyTaskAction = find.byKey(const Key('home-daily-task-action'));
    await tester.ensureVisible(dailyTaskAction);
    await tester.tap(dailyTaskAction);
    await tester.pumpAndSettle();
    expect(openedScan, isTrue);
    router.dispose();
  });

  testWidgets('H2C offers recovery actions and a day filter menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var openedScan = false;
    Uri? openedStorage;
    final overview = _overviewWithBlurryPhoto();
    final router = _router(
      onScan: () => openedScan = true,
      onStorage: (uri) => openedStorage = uri,
    );

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: overview,
      ),
    );
    await tester.pumpAndSettle();

    final filter = find.byKey(const Key('home-lesson-period-toggle'));
    await tester.ensureVisible(filter);
    expect(find.descendant(of: filter, matching: find.text('Lọc ngày')),
        findsOneWidget);
    expect(
        find.descendant(
            of: filter, matching: find.byIcon(Icons.calendar_month_rounded)),
        findsOneWidget);
    expect(tester.getSize(filter).height, greaterThanOrEqualTo(48));
    expect(find.byKey(const Key('home-lesson-period-previous')), findsNothing);
    expect(find.byKey(const Key('home-lesson-period-next')), findsNothing);
    expect(find.text('Đang ở hôm nay'), findsNothing);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    expect(find.text('7 ngày'), findsNothing);
    expect(find.text('1 tháng'), findsNothing);
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(
        find.byKey(const Key('home-map-date-filter-dialog')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    final retake = find.byKey(const Key('home-retake-photo-action'));
    await _expandDailyTask(tester);
    await tester.ensureVisible(retake);
    expect(tester.getSize(retake).height, 48);
    await tester.tap(retake);
    await tester.pumpAndSettle();
    expect(openedScan, isTrue);

    router.go('/home');
    await tester.pumpAndSettle();
    final choose = find.byKey(const Key('home-choose-same-day-action'));
    await _expandDailyTask(tester);
    await tester.ensureVisible(choose);
    expect(tester.getSize(choose).height, 48);
    await tester.tap(choose);
    await tester.pumpAndSettle();

    expect(openedStorage?.path, '/storage');
    expect(
      openedStorage?.queryParameters['from'],
      overview.todayNode.startsAt.millisecondsSinceEpoch.toString(),
    );
    expect(
      openedStorage?.queryParameters['to'],
      overview.todayNode.endsAt.millisecondsSinceEpoch.toString(),
    );
    router.dispose();
  });

  testWidgets('H2D Home remains usable at 320px and 200% Android text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final router = _router();

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 125,
        lessonOverview: _overviewWithBlurryPhoto(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-daily-task-card')), findsOneWidget);
    expect(find.byKey(const Key('home-lesson-period-previous')), findsNothing);
    expect(find.byKey(const Key('home-lesson-period-next')), findsNothing);
    await _expandDailyTask(tester);
    expect(find.byKey(const Key('home-retake-photo-action')), findsOneWidget);
    expect(
        find.byKey(const Key('home-choose-same-day-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.dispose();
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets(
        'Home scrolls the map above navigation at text scale $textScale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: lessonOverview,
      ));
      await tester.pumpAndSettle();
      await _expandDailyTask(tester);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('home-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final lastContent = find.byKey(const Key('home-timezone-fallback-note'));
      expect(
          tester.getBottomLeft(lastContent).dy,
          lessThan(tester
              .getTopLeft(find.byKey(const Key('bottom-nav-responsive-frame')))
              .dy));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('H3D ready mission opens the owner-scoped lesson route', (
    tester,
  ) async {
    const userId = '00000000-0000-4000-8000-000000000001';
    final day = DateTime.utc(2026, 9, 27);
    final mission = DailyMission(
      userId: userId,
      day: day,
      timeZone: 'Asia/Bangkok',
      targetWords: 2,
      createdAt: day,
      startsAt: day,
      endsAt: day.add(const Duration(days: 1)),
      nextDayEndsAt: day.add(const Duration(days: 2)),
    );
    final node = DailyLessonNode(
      day: day,
      startsAt: mission.startsAt,
      endsAt: mission.endsAt,
      status: DailyLessonStatus.ready,
      targetWords: 2,
      validWords: 2,
      correctWords: 0,
      photoCount: 1,
      projectedYuzu: 100,
      exclusionReasons: const {},
      photoNoteIds: const ['photo-note-1'],
      hasSystemPending: false,
    );
    final overview = DailyLessonOverview(
      today: day,
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: day,
      ),
      nodes: [node],
      todayNode: node,
      dailyTarget: 2,
      usesDeviceTimeZoneFallback: false,
    );
    DailyLessonStartRequest? launch;
    final router = _router(
      onLesson: (request) => launch = request as DailyLessonStartRequest,
    );

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: overview,
        mission: mission,
      ),
    );
    await tester.pumpAndSettle();
    await _expandDailyTask(tester);
    final dailyTaskAction = find.byKey(const Key('home-daily-task-action'));
    await tester.ensureVisible(dailyTaskAction);
    await tester.tap(dailyTaskAction);
    await tester.pumpAndSettle();

    expect(launch, isNotNull);
    expect(launch!.userId, userId);
    expect(launch!.missionDate, day);
    expect(launch!.photoNoteIds, ['photo-note-1']);
    expect(launch!.nextDayEndsAt, mission.nextDayEndsAt);
    router.dispose();
  });

  testWidgets('H5 completed mission opens the one-third rewarded replay',
      (tester) async {
    const userId = '00000000-0000-4000-8000-000000000001';
    final day = DateTime.utc(2026, 10, 4);
    final mission = DailyMission(
      userId: userId,
      day: day,
      timeZone: 'Asia/Bangkok',
      targetWords: 10,
      createdAt: day,
      startsAt: DateTime.utc(2026, 10, 3, 17),
      endsAt: DateTime.utc(2026, 10, 4, 17),
      nextDayEndsAt: DateTime.utc(2026, 10, 5, 17),
    );
    final node = DailyLessonNode(
      day: day,
      startsAt: mission.startsAt,
      endsAt: mission.endsAt,
      status: DailyLessonStatus.completed,
      targetWords: 10,
      validWords: 10,
      correctWords: 10,
      photoCount: 1,
      projectedYuzu: 100,
      exclusionReasons: const {},
      photoNoteIds: const ['photo-note-1'],
      hasSystemPending: false,
    );
    final overview = DailyLessonOverview(
      today: day,
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: day,
      ),
      nodes: [node],
      todayNode: node,
      dailyTarget: 10,
      usesDeviceTimeZoneFallback: false,
    );
    LessonStartRequest? launch;
    final router = _router(onLesson: (request) => launch = request);

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard,
        unreadNotifications: 0,
        lessonOverview: overview,
        mission: mission,
      ),
    );
    await tester.pumpAndSettle();
    await _expandDailyTask(tester);
    expect(find.text('Chơi lại'), findsWidgets);
    final dailyTaskAction = find.byKey(const Key('home-daily-task-action'));
    await tester.ensureVisible(dailyTaskAction);
    await tester.tap(dailyTaskAction);
    await tester.pumpAndSettle();

    expect(launch, isA<RewardedReplayLessonStartRequest>());
    final replay = launch! as RewardedReplayLessonStartRequest;
    expect(replay.missionDate, day);
    expect(replay.targetWords, 10);
    router.dispose();
  });

  testWidgets('H4 keeps pending coins separate and exposes sync failure', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 9, 27);
    final node = DailyLessonNode(
      day: day,
      startsAt: day,
      endsAt: day.add(const Duration(days: 1)),
      status: DailyLessonStatus.syncFailed,
      targetWords: 10,
      validWords: 10,
      correctWords: 10,
      photoCount: 1,
      projectedYuzu: 100,
      exclusionReasons: const {},
      photoNoteIds: const ['photo-note-1'],
      hasSystemPending: false,
      completionResultId: 'session-1:completion',
      lastSyncErrorCode: 'temporary_network',
    );
    final overview = DailyLessonOverview(
      today: day,
      selection: HomeLessonMapSelection(
        period: LessonMapPeriod.week,
        anchorDay: day,
      ),
      nodes: [node],
      todayNode: node,
      dailyTarget: 10,
      usesDeviceTimeZoneFallback: false,
    );
    final router = _router();

    await tester.pumpWidget(
      _TestApp(
        router: router,
        dashboard: dashboard.copyWith(pendingYuzu: 0),
        unreadNotifications: 0,
        lessonOverview: overview,
        localPendingYuzu: 100,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('420 xu vàng'), findsOneWidget);
    expect(find.text('100 xu vàng đang chờ đồng bộ'), findsOneWidget);
    expect(find.text('Đồng bộ lỗi'), findsWidgets);
    await _expandDailyTask(tester);
    expect(find.text('Thử đồng bộ lại'), findsOneWidget);
    expect(find.text('Không tải được bảng xếp hạng. Hãy thử lại sau.'),
        findsOneWidget);
    router.dispose();
  });

  testWidgets('mini leaderboard sorts and limits entries to the top three', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniLeaderboardPodium(
            entries: [
              MiniLeaderboardEntry(
                userId: 'a',
                displayName: 'An',
                weeklyYuzu: 10,
                rankPosition: 3,
              ),
              MiniLeaderboardEntry(
                userId: 'b',
                displayName: 'Bình',
                weeklyYuzu: 30,
                rankPosition: 1,
              ),
              MiniLeaderboardEntry(
                userId: 'c',
                displayName: 'Chi',
                weeklyYuzu: 20,
                rankPosition: 2,
              ),
              MiniLeaderboardEntry(
                userId: 'd',
                displayName: 'Dũng',
                weeklyYuzu: 5,
                rankPosition: 4,
              ),
            ],
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('home-podium-rank-1')), findsOneWidget);
    expect(find.text('Bình'), findsOneWidget);
    expect(find.byKey(const Key('home-podium-rank-2')), findsOneWidget);
    expect(find.text('Chi'), findsOneWidget);
    expect(find.byKey(const Key('home-podium-rank-3')), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
    expect(find.text('Dũng'), findsNothing);
  });

  for (final higherScore in [0, 10]) {
    testWidgets('owner wins ties without overtaking score $higherScore',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniLeaderboardPodium(
              ownerId: 'z-owner',
              entries: [
                MiniLeaderboardEntry(
                  userId: 'a-friend',
                  displayName: 'Bạn bè',
                  weeklyYuzu: 0,
                  rankPosition: 1,
                ),
                MiniLeaderboardEntry(
                  userId: 'z-owner',
                  displayName: 'Demo 1',
                  weeklyYuzu: 0,
                  rankPosition: 1,
                ),
                if (higherScore > 0)
                  MiniLeaderboardEntry(
                    userId: 'b-leader',
                    displayName: 'Nhiều xu hơn',
                    weeklyYuzu: higherScore,
                    rankPosition: 1,
                  ),
              ],
              onTap: () {},
            ),
          ),
        ),
      );
      final ownerRank = higherScore > 0 ? 2 : 1;
      final friendRank = ownerRank + 1;
      expect(
        tester.getCenter(find.text('Bạn (Demo 1)')).dx,
        closeTo(
          tester.getCenter(find.byKey(Key('home-podium-rank-$ownerRank'))).dx,
          1,
        ),
      );
      expect(
        tester.getCenter(find.text('Bạn bè')).dx,
        closeTo(
          tester.getCenter(find.byKey(Key('home-podium-rank-$friendRank'))).dx,
          1,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('populated podium fits 320px with 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MiniLeaderboardPodium(
                  ownerId: 'a',
                  entries: [
                    MiniLeaderboardEntry(
                      userId: 'a',
                      displayName: 'Demo 1',
                      weeklyYuzu: 100,
                      rankPosition: 1,
                    ),
                    MiniLeaderboardEntry(
                      userId: 'b',
                      displayName: 'Người bạn tên dài',
                      weeklyYuzu: 50,
                      rankPosition: 2,
                    ),
                  ],
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bạn (Demo 1)'), findsOneWidget);
    expect(find.text('Chờ bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _expandDailyTask(WidgetTester tester) async {
  if (find.byKey(const Key('home-daily-task-action')).evaluate().isNotEmpty) {
    return;
  }
  final toggle = find.byKey(const Key('home-daily-task-toggle'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.router,
    required this.dashboard,
    required this.unreadNotifications,
    required this.lessonOverview,
    this.mission,
    this.localPendingYuzu = 0,
    this.flameGateway,
    this.leaderboardError = true,
  });

  final GoRouter router;
  final HomeState dashboard;
  final int unreadNotifications;
  final DailyLessonOverview lessonOverview;
  final DailyMission? mission;
  final int localPendingYuzu;
  final StreakFlameGateway? flameGateway;
  final bool leaderboardError;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (flameGateway != null)
          streakFlameGatewayProvider.overrideWithValue(flameGateway!),
        homeProvider.overrideWith((ref) => Stream.value(dashboard)),
        homeUnreadNotificationsProvider.overrideWith(
          (ref) => Stream.value(unreadNotifications),
        ),
        homeDailyLessonProvider.overrideWith(
          (ref) => Stream.value(lessonOverview),
        ),
        currentDailyMissionProvider.overrideWith((ref) => mission),
        dailyLessonSessionProvider.overrideWith((ref, key) async => null),
        lessonPendingYuzuProvider.overrideWith(
          (ref, userId) => Stream.value(localPendingYuzu),
        ),
        weeklyYuzuLeaderboardProvider.overrideWith(
          (ref) => Stream.error(StateError('No leaderboard fixture')),
        ),
        periodYuzuLeaderboardProvider.overrideWith((ref, period) async {
          if (leaderboardError && period == YuzuLeaderboardPeriod.total) {
            throw StateError('No leaderboard fixture');
          }
          return PeriodYuzuLeaderboard(entries: [
            MiniLeaderboardEntry(
                userId: dashboard.userId,
                displayName: 'Demo 1',
                weeklyYuzu: switch (period) {
                  YuzuLeaderboardPeriod.total => dashboard.yuzuBalance,
                  YuzuLeaderboardPeriod.day => 123,
                  YuzuLeaderboardPeriod.week => 234,
                  YuzuLeaderboardPeriod.month => 456,
                },
                rankPosition: 1),
          ], updatedAt: dashboard.updatedAt);
        }),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
  }
}

class _TestFlameGateway implements StreakFlameGateway {
  bool fail = false;
  Object? error;
  int calls = 0;
  bool _lit = false;
  @override
  Future<StreakFlameResult> light({required String ownerId}) async {
    calls++;
    if (error != null) throw error!;
    if (fail) throw StateError('offline');
    final incremented = !_lit;
    _lit = true;
    return StreakFlameResult(
        ownerId: ownerId,
        streakDays: 8,
        incremented: incremented,
        updatedAt: DateTime.utc(2026, 10, 8));
  }
}

GoRouter _router({
  VoidCallback? onSettings,
  VoidCallback? onFriends,
  VoidCallback? onScan,
  ValueChanged<Uri>? onStorage,
  ValueChanged<LessonStartRequest>? onLesson,
}) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          onSettings?.call();
          return const Scaffold(body: Text('SettingsScreen'));
        },
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) {
          onFriends?.call();
          return const Scaffold(body: Text('FriendsScreen'));
        },
      ),
      GoRoute(
        path: '/storage',
        builder: (context, state) {
          onStorage?.call(state.uri);
          return const Scaffold(body: Text('Storage'));
        },
      ),
      GoRoute(
        path: '/lesson',
        builder: (context, state) {
          onLesson?.call(state.extra! as LessonStartRequest);
          return const Scaffold(body: Text('Lesson'));
        },
      ),
      GoRoute(
        path: '/pet-shop',
        builder: (context, state) => const Scaffold(body: Text('Shop')),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) {
          onScan?.call();
          return const Scaffold(body: Text('Scan'));
        },
      ),
    ],
  );
}

DailyLessonOverview _overviewWithBlurryPhoto() {
  final day = DateTime.utc(2026, 9, 27);
  final node = DailyLessonNode(
    day: day,
    startsAt: day,
    endsAt: day.add(const Duration(days: 1)),
    status: DailyLessonStatus.noData,
    targetWords: 10,
    validWords: 2,
    correctWords: 0,
    photoCount: 1,
    projectedYuzu: 0,
    exclusionReasons: const {
      DailyLessonExclusionReason.blurryImage: 1,
    },
    photoNoteIds: const ['note-1'],
    hasSystemPending: false,
  );
  return DailyLessonOverview(
    today: day,
    selection: HomeLessonMapSelection(
      period: LessonMapPeriod.week,
      anchorDay: day,
    ),
    nodes: [node],
    todayNode: node,
    dailyTarget: 10,
    usesDeviceTimeZoneFallback: false,
  );
}
