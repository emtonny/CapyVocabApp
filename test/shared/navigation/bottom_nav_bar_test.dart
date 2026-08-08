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

    for (final label in ['Trang chủ', 'Thư viện', 'Cửa hàng', 'Bạn bè']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('HomeScreen'), findsOneWidget);
      expect(find.text('ScanScreen'), findsNothing);
    }

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
        path: '/scan',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('ScanScreen')),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}
