import 'package:capy_vocab/features/home/presentation/providers/home_provider.dart';
import 'package:capy_vocab/features/home/presentation/providers/daily_lesson_provider.dart';
import 'package:capy_vocab/features/home/presentation/providers/daily_mission_provider.dart';
import 'package:capy_vocab/features/home/presentation/screens/home_screen.dart';
import 'package:capy_vocab/features/home/presentation/widgets/mini_leaderboard_podium.dart';
import 'package:capy_vocab/features/home/domain/daily_mission.dart';
import 'package:capy_vocab/features/home/presentation/providers/weekly_yuzu_leaderboard_provider.dart';
import 'package:capy_vocab/features/mini_games/application/lesson_session_controller.dart';
import 'package:capy_vocab/features/mini_games/presentation/providers/lesson_session_provider.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

  testWidgets('renders H1 state without a manual streak reward action', (
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

    expect(find.text('420 Yuzu'), findsOneWidget);
    expect(find.text('35 đang chờ đồng bộ'), findsOneWidget);
    expect(find.text('Chào Demo 1!'), findsOneWidget);
    expect(find.text('7 ngày liên tiếp'), findsOneWidget);
    expect(find.byKey(const Key('home-unread-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Chưa có điểm tuần đã xác nhận.'), findsOneWidget);
    expect(find.textContaining('Thắp lửa'), findsNothing);
    expect(find.textContaining('Điểm danh'), findsNothing);

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
    expect(find.text('Mục tiêu: 10 từ'), findsOneWidget);
    expect(find.text('0/10 từ hợp lệ'), findsOneWidget);
    expect(find.text('Còn thiếu: 10 từ'), findsOneWidget);
    expect(find.text('Chưa đủ dữ liệu'), findsWidgets);
    expect(find.byKey(const Key('home-lesson-map-grid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-daily-task-action')));
    await tester.pumpAndSettle();
    expect(openedScan, isTrue);
    router.dispose();
  });

  testWidgets('H2C offers recovery actions and 48px period navigation', (
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

    for (final key in const [
      Key('home-lesson-period-previous'),
      Key('home-lesson-period-today'),
      Key('home-lesson-period-next'),
    ]) {
      final control = find.byKey(key);
      await tester.ensureVisible(control);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
    }

    final retake = find.byKey(const Key('home-retake-photo-action'));
    await tester.ensureVisible(retake);
    expect(tester.getSize(retake).height, 48);
    await tester.tap(retake);
    await tester.pumpAndSettle();
    expect(openedScan, isTrue);

    router.go('/home');
    await tester.pumpAndSettle();
    final choose = find.byKey(const Key('home-choose-same-day-action'));
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
    expect(
        find.byKey(const Key('home-lesson-period-previous')), findsOneWidget);
    expect(find.byKey(const Key('home-lesson-period-next')), findsOneWidget);
    expect(find.byKey(const Key('home-retake-photo-action')), findsOneWidget);
    expect(
        find.byKey(const Key('home-choose-same-day-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.dispose();
  });

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
    await tester.tap(find.byKey(const Key('home-daily-task-action')));
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
    expect(find.text('Chơi lại'), findsWidgets);
    await tester.tap(find.byKey(const Key('home-daily-task-action')));
    await tester.pumpAndSettle();

    expect(launch, isA<RewardedReplayLessonStartRequest>());
    final replay = launch! as RewardedReplayLessonStartRequest;
    expect(replay.missionDate, day);
    expect(replay.targetWords, 10);
    router.dispose();
  });

  testWidgets('H4 keeps pending Yuzu separate and exposes sync failure', (
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

    expect(find.text('420 Yuzu'), findsOneWidget);
    expect(find.text('100 đang chờ đồng bộ'), findsOneWidget);
    expect(find.text('Đồng bộ lỗi'), findsWidgets);
    expect(find.text('Thử đồng bộ lại'), findsOneWidget);
    expect(find.text('Chưa có điểm tuần đã xác nhận.'), findsOneWidget);
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

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Bình'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Chi'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
    expect(find.text('Dũng'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.router,
    required this.dashboard,
    required this.unreadNotifications,
    required this.lessonOverview,
    this.mission,
    this.localPendingYuzu = 0,
  });

  final GoRouter router;
  final HomeState dashboard;
  final int unreadNotifications;
  final DailyLessonOverview lessonOverview;
  final DailyMission? mission;
  final int localPendingYuzu;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
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
      ],
      child: MaterialApp.router(routerConfig: router),
    );
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
