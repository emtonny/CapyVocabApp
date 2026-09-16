import 'package:capy_vocab/shared/widgets/top_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders notifications at the top and supports manual dismiss',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TopNotificationHost(
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const Key('show-top-notification'),
                  onPressed: () => showTopNotification(
                    context,
                    const SnackBar(
                      content: Text('Thông báo kiểm tra'),
                      duration: Duration(seconds: 10),
                    ),
                  ),
                  child: const Text('Hiện thông báo'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('show-top-notification')));
    await tester.pump();

    final banner = find.byKey(const Key('top-notification-banner'));
    expect(banner, findsOneWidget);
    expect(tester.getTopLeft(banner).dy, lessThan(100));
    expect(find.text('Thông báo kiểm tra'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('top-notification-dismiss-button')),
    );
    await tester.pump();

    expect(banner, findsNothing);
  });

  testWidgets('automatically dismisses after the SnackBar duration',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TopNotificationHost(
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showTopNotification(
                  context,
                  const SnackBar(
                    content: Text('Tự ẩn'),
                    duration: Duration(milliseconds: 100),
                  ),
                ),
                child: const Text('Hiện'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Hiện'));
    await tester.pump();
    expect(find.text('Tự ẩn'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 101));
    expect(find.text('Tự ẩn'), findsNothing);
  });

  testWidgets(
      'renders cleanly when mounted in MaterialApp builder without overlay ancestor',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TopNotificationHost(
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTopNotification(
                context,
                const SnackBar(content: Text('Thông báo builder')),
              ),
              child: const Text('Kích hoạt'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Kích hoạt'));
    await tester.pump();

    expect(find.byKey(const Key('top-notification-banner')), findsOneWidget);
    expect(find.text('Thông báo builder'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('top-notification-dismiss-button')),
    );
    await tester.pump();

    expect(find.byKey(const Key('top-notification-banner')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
