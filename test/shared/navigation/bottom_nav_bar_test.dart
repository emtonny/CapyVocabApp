import 'package:capy_vocab/features/home/presentation/screens/home_screen.dart';
import 'package:capy_vocab/shared/navigation/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('hiển thị bốn tab và nút Camera nổi bật', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.byType(BottomNavBar), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Thư viện'), findsOneWidget);
    expect(find.text('Cửa hàng'), findsOneWidget);
    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.byKey(const Key('bottom-nav-camera-button')), findsOneWidget);
  });

  testWidgets('chỉ Camera mở Scan và Back quay lại Home', (tester) async {
    await tester.pumpWidget(_testApp());

    // Tapping other tabs navigates to their respective screens, not HomeScreen
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('StorageScreen'), findsOneWidget);

    await tester.tap(find.text('Cửa hàng'));
    await tester.pumpAndSettle();
    expect(find.text('ShopScreen'), findsOneWidget);

    await tester.tap(find.text('Bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('FriendsScreen'), findsOneWidget);

    // Tap Home returns to HomeScreen
    await tester.tap(find.text('Trang chủ'));
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
