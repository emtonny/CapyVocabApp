import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:capy_vocab/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('Họ tên chỉ xuất hiện trong form đăng ký', (tester) async {
    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    expect(
      find.byKey(const Key('sign-up-display-name-field')),
      findsNothing,
    );

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sign-up-display-name-field')),
      findsOneWidget,
    );
  });

  testWidgets(
      'Đăng ký chờ xác nhận email là thành công và truyền họ tên đã trim',
      (tester) async {
    final repository = _RecordingAuthRepository();
    await _pumpAuthScreen(tester, repository);

    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sign-up-display-name-field')),
      '  Nguyễn Văn An  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'an@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'secret123',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(repository.receivedDisplayName, 'Nguyễn Văn An');
    expect(
      find.text('Đăng ký tài khoản thành công! Vui lòng nhập mật khẩu để đăng nhập.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sign-up-display-name-field')),
      findsNothing,
    );
  });
}

Future<void> _pumpAuthScreen(
  WidgetTester tester,
  AuthRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: AuthScreen()),
    ),
  );
}

class _RecordingAuthRepository implements AuthRepository {
  String? receivedDisplayName;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    receivedDisplayName = displayName;
    return AuthResponse(
      user: const User(
        id: 'pending-confirmation-user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'an@example.com',
        createdAt: '2026-07-31T00:00:00.000Z',
      ),
    );
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
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }
}
