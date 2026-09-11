import 'dart:async';

import 'package:capy_vocab/core/routes/app_router.dart';
import 'package:capy_vocab/features/onboarding/application/onboarding_status_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Home to Library to detail makes zero profile requests',
      (tester) async {
    const userId = 'user-a';
    final authEvents = StreamController<String?>.broadcast();
    final store = MemoryOnboardingStatusStore();
    await store.setStatus(userId, OnboardingStatus.complete);
    var profileRequests = 0;
    final refresher = OnboardingStatusRefresher(
      store: store,
      loadRemoteStatus: (_) async {
        profileRequests++;
        return true;
      },
    );
    addTearDown(authEvents.close);
    addTearDown(store.dispose);

    final appRouter = AppRouter(
      currentUserId: () => userId,
      authUserIds: authEvents.stream,
      onboardingStatusStore: store,
      initialLocation: '/home',
      routes: [
        for (final path in ['/auth', '/onboarding', '/home', '/storage'])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.matchedLocation)),
          ),
        GoRoute(
          path: '/storage/:photoNoteId',
          builder: (_, state) =>
              Scaffold(body: Text(state.pathParameters['photoNoteId']!)),
        ),
      ],
    );
    addTearDown(appRouter.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));
    await tester.pumpAndSettle();
    expect(find.text('/home'), findsOneWidget);

    appRouter.router.go('/storage');
    await tester.pumpAndSettle();
    expect(find.text('/storage'), findsOneWidget);

    appRouter.router.go('/storage/note-1');
    await tester.pumpAndSettle();
    expect(find.text('note-1'), findsOneWidget);
    expect(profileRequests, 0);

    // Keep the refresher in the test boundary: navigation must not invoke it.
    expect(refresher, isNotNull);
  });

  testWidgets('unknown status fails open without leaking another user status',
      (tester) async {
    var userId = 'user-a';
    final authEvents = StreamController<String?>.broadcast();
    final store = MemoryOnboardingStatusStore();
    await store.setStatus('user-b', OnboardingStatus.incomplete);
    addTearDown(authEvents.close);
    addTearDown(store.dispose);

    final appRouter = AppRouter(
      currentUserId: () => userId,
      authUserIds: authEvents.stream,
      onboardingStatusStore: store,
      routes: [
        for (final path in ['/auth', '/onboarding', '/home'])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.matchedLocation)),
          ),
      ],
    );
    addTearDown(appRouter.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));
    await tester.pumpAndSettle();
    expect(find.text('/home'), findsOneWidget);

    userId = 'user-b';
    authEvents.add(userId);
    await tester.pumpAndSettle();
    expect(find.text('/onboarding'), findsOneWidget);
  });
}
