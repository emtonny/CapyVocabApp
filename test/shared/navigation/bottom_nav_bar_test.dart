import 'package:capy_vocab/features/home/presentation/screens/home_screen.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:capy_vocab/shared/navigation/bottom_nav_bar.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('hiển thị bốn tab và nút Camera nổi bật', (tester) async {
    await tester.pumpWidget(_navOnlyApp());

    expect(find.byType(BottomNavBar), findsOneWidget);
    expect(find.byTooltip('Trang chủ'), findsOneWidget);
    expect(find.byTooltip('Thư viện'), findsOneWidget);
    expect(find.byTooltip('Cửa hàng'), findsOneWidget);
    expect(find.byTooltip('Bạn bè'), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-camera-button')), findsOneWidget);
  });

  testWidgets('chỉ Camera mở Scan và Back quay lại Home', (tester) async {
    await tester.pumpWidget(_testApp());

    // Tapping other tabs navigates to their respective screens, not HomeScreen
    await tester.tap(find.byTooltip('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('StorageScreen'), findsOneWidget);

    await tester.tap(find.byTooltip('Cửa hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ShopScreen'), findsOneWidget);

    await tester.tap(find.byTooltip('Bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('FriendsScreen'), findsOneWidget);

    // Tap Home returns to HomeScreen
    await tester.tap(find.byTooltip('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('HomeScreen'), findsOneWidget);
    expect(find.text('ScanScreen'), findsNothing);

    await tester.tap(find.byKey(const Key('bottom-nav-camera-button')));
    await tester.pumpAndSettle();

    expect(find.text('ScanScreen'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('HomeScreen'), findsOneWidget);
    expect(find.text('ScanScreen'), findsNothing);
  });

  testWidgets('giữ đúng tỷ lệ neo-brutal trên màn hình hẹp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_navOnlyApp());

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('bottom-nav-home-icon'))),
      const Size.square(47),
    );
    expect(
      tester.getSize(find.byKey(const Key('bottom-nav-camera-frame'))),
      const Size.square(66),
    );

    final shellRect = tester.getRect(find.byKey(const Key('bottom-nav-shell')));
    expect(shellRect.left, closeTo(0, 0.01));
    expect(shellRect.right, closeTo(320, 0.01));
    expect(shellRect.bottom, closeTo(640, 0.01));

    final shellTop = shellRect.top;
    final cameraTop =
        tester.getTopLeft(find.byKey(const Key('bottom-nav-camera-frame'))).dy;
    expect(cameraTop - shellTop, closeTo(3, 0.01));

    final cameraCenter =
        tester.getCenter(find.byKey(const Key('bottom-nav-camera-frame'))).dy;
    final homeCenter =
        tester.getCenter(find.byKey(const Key('bottom-nav-home-icon'))).dy;
    expect(cameraCenter, closeTo(homeCenter - 3, 0.5));

    final cameraButton = tester.widget<StickerButton>(
      find.byKey(const Key('bottom-nav-camera-button')),
    );
    expect(cameraButton.surfaceColor, AppColors.duoOrange);
    expect(cameraButton.radius, 33);
    expect(cameraButton.flat, isFalse);
    expect(cameraButton.semanticLabel, 'Quét ảnh từ vựng');
  });

  testWidgets('khớp golden của thanh điều hướng neo-brutal', (tester) async {
    tester.view.physicalSize = const Size(390, 180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_navOnlyApp());

    await expectLater(
      find.byType(BottomNavBar),
      matchesGoldenFile('goldens/bottom_nav_bar.png'),
    );
  });
}

Widget _testApp() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/storage',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('StorageScreen')),
          bottomNavigationBar: BottomNavBar(),
        ),
      ),
      GoRoute(
        path: '/pet-shop',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('ShopScreen')),
          bottomNavigationBar: BottomNavBar(),
        ),
      ),
      GoRoute(
        path: '/friends',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('FriendsScreen')),
          bottomNavigationBar: BottomNavBar(),
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('ScanScreen')),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

Widget _navOnlyApp() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: BottomNavBar(),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}
