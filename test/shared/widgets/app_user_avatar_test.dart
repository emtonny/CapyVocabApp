import 'package:capy_vocab/shared/widgets/app_user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('user photo is requested and a failed load uses the default',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUserAvatar(
            avatarUrl: 'https://example.com/avatar.png',
            size: 48,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://example.com/avatar.png');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('default-user-avatar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing avatar shows the default silhouette', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUserAvatar(avatarUrl: null, size: 48),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('default-user-avatar')), findsOneWidget);

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppUserAvatar),
        matching: find.byType(Container),
      ),
    );
    final foreground = container.foregroundDecoration! as BoxDecoration;
    expect(foreground.borderRadius, BorderRadius.circular(24));
    expect(foreground.border, isNotNull);
  });

  testWidgets('invalid avatar URL shows the default silhouette',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUserAvatar(avatarUrl: 'assets/demo-avatar.png', size: 48),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('default-user-avatar')), findsOneWidget);
  });
}
