import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:capy_vocab/features/auth/presentation/screens/auth_screen.dart';
import 'package:capy_vocab/features/auth/presentation/widgets/capy_video_header.dart';
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

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(repository.receivedDisplayName, 'Nguyễn Văn An');
    expect(
      find.text(
          'Đăng ký tài khoản thành công! Vui lòng nhập mật khẩu để đăng nhập.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sign-up-display-name-field')),
      findsNothing,
    );
  });

  testWidgets('video lớn và tên thương hiệu nằm phía trên trên mọi kích thước',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(600, 1000);
    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Deery Vocab')).dy,
      lessThan(tester.getTopLeft(find.text('🦌')).dy),
    );
    tester.view.physicalSize = const Size(900, 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final videoCardSize = tester.getSize(find.byType(CapyVideoHeader));
    expect(videoCardSize.width, 315);
    expect(videoCardSize.height, greaterThan(500));
  });

  testWidgets('nhập mật khẩu và toggle ẩn/hiện mật khẩu hoạt động chính xác',
      (tester) async {
    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    final passwordFinder = find.byKey(const Key('password-field'));
    expect(passwordFinder, findsOneWidget);

    var passwordField = tester.widget<EditableText>(
      find.descendant(of: passwordFinder, matching: find.byType(EditableText)),
    );
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.obscuringCharacter, '•');

    await tester.enterText(passwordFinder, 'MySecretPass123');
    await tester.pumpAndSettle();

    // Tap toggle button to show password
    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pumpAndSettle();

    passwordField = tester.widget<EditableText>(
      find.descendant(of: passwordFinder, matching: find.byType(EditableText)),
    );
    expect(passwordField.obscureText, isFalse);

    // Tap toggle button to hide password again
    await tester.tap(find.byTooltip('Ẩn mật khẩu'));
    await tester.pumpAndSettle();

    passwordField = tester.widget<EditableText>(
      find.descendant(of: passwordFinder, matching: find.byType(EditableText)),
    );
    expect(passwordField.obscureText, isTrue);
  });

  testWidgets('các box đăng nhập dùng neo-brutal radius, viền và hard shadow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);

    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    _expectNeoBox(tester, const Key('auth-hero-box'), radius: 12, shadow: 8);
    _expectNeoBox(tester, const Key('auth-form-box'), radius: 12, shadow: 8);
    _expectNeoBox(
      tester,
      const Key('selected-auth-tab-box'),
      radius: 8,
      shadow: 6,
    );
    _expectNeoBox(
      tester,
      const Key('idle-auth-tab-box'),
      radius: 8,
      shadow: 6,
    );
    _expectNeoBox(tester, const Key('google-auth-box'), radius: 8, shadow: 6);
    _expectNeoBox(
      tester,
      const Key('facebook-auth-box'),
      radius: 8,
      shadow: 6,
    );

    for (final key in const [
      Key('email-input-box'),
      Key('password-input-box'),
    ]) {
      final box = tester.widget<Container>(find.byKey(key));
      final decoration = box.decoration! as BoxDecoration;
      _expectRadiusAndShadow(decoration, radius: 8, shadow: 6);
    }

    for (final fieldKey in const [Key('email-field'), Key('password-field')]) {
      final inputDecorator = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(fieldKey),
          matching: find.byType(InputDecorator),
        ),
      );
      final border =
          inputDecorator.decoration.enabledBorder! as OutlineInputBorder;
      expect(border.borderRadius.topLeft.x, 8);
      expect(border.borderSide.color, AppColors.ink);
      expect(border.borderSide.width, inInclusiveRange(2, 3));
    }

    final submit = tester.widget<FilledButton>(find.byType(FilledButton));
    final submitShape =
        submit.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(submitShape.borderRadius, BorderRadius.circular(8));
    expect(submitShape.side.color, AppColors.ink);
    expect(submitShape.side.width, inInclusiveRange(2, 3));
    _expectRadiusAndShadow(
      tester
          .widget<Container>(find.byKey(const Key('auth-submit-shadow-box')))
          .decoration! as BoxDecoration,
      radius: 8,
      shadow: 8,
    );

    final layoutException = tester.takeException();
    expect(
      layoutException,
      isNull,
      reason: layoutException is FlutterError
          ? layoutException.toStringDeep()
          : '$layoutException',
    );
  });
}

void _expectNeoBox(
  WidgetTester tester,
  Key key, {
  required double radius,
  required double shadow,
}) {
  final box = tester.widget<Container>(find.byKey(key));
  final decoration = box.decoration! as BoxDecoration;
  final border = decoration.border! as Border;

  expect(border.top.color, AppColors.ink);
  expect(border.top.width, inInclusiveRange(2, 3));
  _expectRadiusAndShadow(decoration, radius: radius, shadow: shadow);
}

void _expectRadiusAndShadow(
  BoxDecoration decoration, {
  required double radius,
  required double shadow,
}) {
  final borderRadius = decoration.borderRadius! as BorderRadius;
  final boxShadow = decoration.boxShadow!.single;

  expect(borderRadius.topLeft.x, radius);
  expect(boxShadow.color, AppColors.ink);
  expect(boxShadow.blurRadius, 0);
  expect(boxShadow.offset, Offset(shadow, shadow));
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
