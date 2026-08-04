import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:capy_vocab/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  testWidgets('hủy dialog không reset onboarding', (tester) async {
    var resetCallCount = 0;
    final repository = _RecordingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async => resetCallCount++,
    );

    await tester.tap(find.byKey(const Key('reset-onboarding-debug-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn chắc chắn muốn reset onboarding?'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(resetCallCount, 0);
    expect(repository.signOutCallCount, 0);
    expect(find.text('SettingsScreen'), findsOneWidget);
  });

  testWidgets('RPC lỗi hiển thị thông báo và không đăng xuất', (tester) async {
    final repository = _RecordingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async => throw Exception('RPC failed'),
    );

    await tester.tap(find.byKey(const Key('reset-onboarding-debug-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể reset onboarding. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(repository.signOutCallCount, 0);
    expect(find.text('SettingsScreen'), findsOneWidget);
  });

  testWidgets('reset thành công rồi đăng xuất và điều hướng về auth',
      (tester) async {
    final calls = <String>[];
    final repository = _RecordingAuthRepository(
      onSignOut: () => calls.add('signOut'),
    );
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async => calls.add('rpc'),
    );

    await tester.tap(find.byKey(const Key('reset-onboarding-debug-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(calls, ['rpc', 'signOut']);
    expect(find.text('AuthScreen'), findsOneWidget);
  });
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  required AuthRepository repository,
  required ResetOnboarding resetOnboarding,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const Scaffold(body: Text('AuthScreen')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        resetOnboardingProvider.overrideWithValue(resetOnboarding),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.onSignOut});

  final void Function()? onSignOut;
  int signOutCallCount = 0;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    onSignOut?.call();
  }

  @override
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }
}
