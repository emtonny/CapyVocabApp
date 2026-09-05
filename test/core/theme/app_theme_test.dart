import 'package:capy_vocab/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page transition uses a soft fade and slide', (tester) async {
    Widget? transition;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            transition = buildSoftPageTransition(
              context,
              const AlwaysStoppedAnimation(0.5),
              kAlwaysDismissedAnimation,
              const SizedBox(),
            );
            return transition!;
          },
        ),
      ),
    );

    expect(transition, isA<FadeTransition>());
    expect((transition! as FadeTransition).child, isA<SlideTransition>());
  });

  testWidgets('page transition respects reduced motion', (tester) async {
    const child = SizedBox(key: Key('page'));
    Widget? transition;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              transition = buildSoftPageTransition(
                context,
                const AlwaysStoppedAnimation(0.5),
                kAlwaysDismissedAnimation,
                child,
              );
              return transition!;
            },
          ),
        ),
      ),
    );

    expect(identical(transition, child), isTrue);
    expect(find.byKey(const Key('page')), findsOneWidget);
  });
}
