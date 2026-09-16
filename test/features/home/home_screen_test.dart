import 'package:capy_vocab/features/home/presentation/screens/home_screen.dart';
import 'package:capy_vocab/shared/widgets/sticker_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('renders settings StickerButton and handles navigation', (
    tester,
  ) async {
    var navigatedToSettings = false;

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            navigatedToSettings = true;
            return const Scaffold(body: Text('SettingsScreen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    // Verify settings button is a StickerButton
    final buttonFinder = find.byKey(const Key('home-settings-button'));
    expect(buttonFinder, findsOneWidget);
    expect(tester.widget(buttonFinder), isA<StickerButton>());
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    // Verify semantics label
    final semanticsHandle = tester.ensureSemantics();
    expect(
      tester.getSemantics(buttonFinder).label,
      'Cài đặt',
    );
    semanticsHandle.dispose();

    // Tap button to verify navigation
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(navigatedToSettings, isTrue);
    expect(find.text('SettingsScreen'), findsOneWidget);
  });
}
