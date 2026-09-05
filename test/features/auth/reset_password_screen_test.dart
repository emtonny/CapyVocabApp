import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:capy_vocab/features/auth/presentation/screens/reset_password_screen.dart';
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

  testWidgets('không cho đổi mật khẩu khi liên kết không hợp lệ',
      (tester) async {
    final repository = _RecoveryAuthRepository();
    await _pumpResetScreen(tester, repository, canResetPassword: false);

    expect(find.text('Liên kết không còn hiệu lực'), findsOneWidget);
    expect(find.byKey(const Key('new-password-field')), findsNothing);
    expect(repository.updatedPassword, isNull);
  });

  testWidgets('kiểm tra mật khẩu và hoàn tất đổi mật khẩu', (tester) async {
    final repository = _RecoveryAuthRepository();
    String? resetResult;
    await _pumpResetScreen(
      tester,
      repository,
      canResetPassword: true,
      onLogin: (value) => resetResult = value,
    );

    await tester.enterText(
      find.byKey(const Key('new-password-field')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-new-password-field')),
      'different',
    );
    await tester.tap(find.byKey(const Key('update-password-button')));
    await tester.pump();

    expect(find.text('Mật khẩu phải có ít nhất 6 ký tự.'), findsOneWidget);
    expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
    expect(repository.updatedPassword, isNull);

    await tester.enterText(
      find.byKey(const Key('new-password-field')),
      'abc123',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-new-password-field')),
      'abc123',
    );
    await tester.tap(find.byKey(const Key('update-password-button')));
    await tester.pumpAndSettle();

    expect(repository.updatedPassword, 'abc123');
    expect(repository.signOutCallCount, 1);
    expect(resetResult, 'success');
    expect(find.text('login-target'), findsOneWidget);
  });
}

Future<void> _pumpResetScreen(
  WidgetTester tester,
  AuthRepository repository, {
  required bool canResetPassword,
  ValueChanged<String?>? onLogin,
}) async {
  final router = GoRouter(
    initialLocation: '/reset-password',
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => ResetPasswordScreen(
          canResetPassword: canResetPassword,
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, state) {
          onLogin?.call(state.uri.queryParameters['passwordReset']);
          return const Scaffold(body: Text('login-target'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecoveryAuthRepository implements AuthRepository {
  String? updatedPassword;
  int signOutCallCount = 0;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

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
}
