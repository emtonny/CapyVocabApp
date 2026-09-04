import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:capy_vocab/core/services/local_storage_service.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      'Đăng ký gửi email xác nhận, quay về đăng nhập và truyền họ tên đã trim',
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
      'abc123',
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pumpAndSettle();

    expect(repository.receivedDisplayName, 'Nguyễn Văn An');
    expect(find.byKey(const Key('sign-up-display-name-field')), findsNothing);
    expect(find.byKey(const Key('email-confirmation-card')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('email-field')))
          .controller
          ?.text,
      'an@example.com',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('password-field')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.byKey(const Key('top-notification-banner')), findsOneWidget);
    expect(
      find.text(
        'Đã gửi email xác nhận. Vui lòng kiểm tra hộp thư để hoàn tất đăng ký Deery Vocab.',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byKey(const Key('top-notification-banner')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('top-notification-banner')), findsNothing);
  });

  testWidgets('video lớn và tên thương hiệu nằm phía trên trên mọi kích thước',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(600, 1000);
    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    expect(tester.takeException(), isNull);
    final mobileBrandTitle = tester.widget<Text>(find.text('Deery Vocab'));
    expect(mobileBrandTitle.style?.fontSize, 42);
    expect(mobileBrandTitle.style?.fontWeight, FontWeight.w900);
    expect(mobileBrandTitle.style?.fontFamily, contains('RobotoCondensed'));
    expect(
      tester.getTopLeft(find.text('Deery Vocab')).dy,
      lessThan(tester.getTopLeft(find.text('🦌')).dy),
    );
    tester.view.physicalSize = const Size(900, 1000);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final wideBrandTitle = tester.widget<Text>(find.text('Deery Vocab'));
    expect(wideBrandTitle.style?.fontSize, 42);
    expect(wideBrandTitle.style?.fontWeight, FontWeight.w900);
    expect(wideBrandTitle.style?.fontFamily, contains('RobotoCondensed'));
    final videoCardSize = tester.getSize(find.byType(CapyVideoHeader));
    expect(videoCardSize.width, 315);
    expect(videoCardSize.height, greaterThan(500));
  });

  testWidgets('nhập mật khẩu và toggle ẩn/hiện mật khẩu hoạt động chính xác',
      (tester) async {
    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    final emailFinder = find.byKey(const Key('email-field'));
    final emailField = tester.widget<EditableText>(
      find.descendant(of: emailFinder, matching: find.byType(EditableText)),
    );
    final passwordFinder = find.byKey(const Key('password-field'));
    expect(passwordFinder, findsOneWidget);
    expect(
      emailField.autofillHints,
      containsAll([AutofillHints.username, AutofillHints.email]),
    );

    var passwordField = tester.widget<EditableText>(
      find.descendant(of: passwordFinder, matching: find.byType(EditableText)),
    );
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.obscuringCharacter, '•');
    expect(passwordField.autofillHints, contains(AutofillHints.password));

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

  testWidgets('tự điền email đã ghi nhớ nhưng không tự điền mật khẩu',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalStorageService.rememberedEmailKey: 'remembered@example.com',
    });
    await _pumpAuthScreen(tester, _RecordingAuthRepository());
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('email-field')),
    );
    final passwordField = tester.widget<TextFormField>(
      find.byKey(const Key('password-field')),
    );
    final rememberCheckbox = tester.widget<InkWell>(
      find.byKey(const Key('remember-account-checkbox')),
    );

    expect(emailField.controller?.text, 'remembered@example.com');
    expect(passwordField.controller?.text, isEmpty);
    expect(rememberCheckbox.onTap, isNotNull);
    expect(
      tester
          .widget<Container>(
            find.byKey(const Key('remember-account-indicator')),
          )
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'selected color',
        AppColors.lime,
      ),
    );
  });

  testWidgets('đăng nhập thành công chỉ lưu email khi bật ghi nhớ',
      (tester) async {
    await _pumpAuthScreen(
      tester,
      _RecordingAuthRepository(signInSucceeds: true),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('email-field')),
      '  saved@example.com  ',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'DoNotStoreThisPassword123',
    );
    await tester.tap(find.byKey(const Key('remember-account-checkbox')));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(LocalStorageService.rememberedEmailKey),
      'saved@example.com',
    );
    expect(preferences.getKeys(), {LocalStorageService.rememberedEmailKey});
  });

  testWidgets('bỏ ghi nhớ sẽ xóa email đã lưu', (tester) async {
    SharedPreferences.setMockInitialValues({
      LocalStorageService.rememberedEmailKey: 'remembered@example.com',
    });
    await _pumpAuthScreen(tester, _RecordingAuthRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remember-account-checkbox')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(LocalStorageService.rememberedEmailKey),
      isNull,
    );
  });

  testWidgets('các box đăng nhập dùng neo-brutal radius, viền và hard shadow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);

    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    _expectNeoBox(tester, const Key('auth-hero-box'), radius: 12, shadow: 4);
    _expectNeoBox(tester, const Key('auth-form-box'), radius: 12, shadow: 4);
    _expectNeoBox(
      tester,
      const Key('selected-auth-tab-box'),
      radius: 8,
      shadow: 3,
    );

    // Ghi nhớ tài khoản không có box nền/shadow và icon tick gióng thẳng hàng với icon email, mật khẩu
    final emailIconBox = tester.getRect(
      find
          .ancestor(
            of: find.byIcon(Icons.email_outlined),
            matching: find.byType(Container),
          )
          .first,
    );
    final passwordIconBox = tester.getRect(
      find
          .ancestor(
            of: find.byIcon(Icons.lock_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    final indicator = tester.getRect(
      find.byKey(const Key('remember-account-indicator')),
    );
    final label = tester.getRect(
      find.byKey(const Key('remember-account-label')),
    );
    final forgotPassword = tester.getRect(
      find.byKey(const Key('forgot-password-button')),
    );

    expect(indicator.left, closeTo(emailIconBox.left, 0.01));
    expect(indicator.left, closeTo(passwordIconBox.left, 0.01));
    expect(label.left - indicator.right, closeTo(8, 0.01));
    expect(forgotPassword.left, greaterThan(label.right));

    _expectNeoBox(
      tester,
      const Key('idle-auth-tab-box'),
      radius: 8,
      shadow: 3,
    );
    _expectNeoBox(tester, const Key('google-auth-box'), radius: 8, shadow: 3);
    _expectNeoBox(
      tester,
      const Key('facebook-auth-box'),
      radius: 8,
      shadow: 3,
    );

    for (final keys in const [
      (Key('email-input-box'), Key('email-input-shadow')),
      (Key('password-input-box'), Key('password-input-shadow')),
    ]) {
      expect(tester.widget<Stack>(find.byKey(keys.$1)).clipBehavior, Clip.none);
      final shadow = tester.widget<DecoratedBox>(find.byKey(keys.$2));
      final decoration = shadow.decoration as BoxDecoration;
      expect(decoration.color, AppColors.ink);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(tester.getSize(find.byKey(keys.$2)).height, 48);
      expect(
        tester.getBottomRight(find.byKey(keys.$2)).dx,
        closeTo(tester.getBottomRight(find.byKey(keys.$1)).dx + 3, 0.01),
      );
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
      shadow: 4,
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

  testWidgets('lỗi nhập liệu dễ đọc và giữ phong cách neo-brutal',
      (tester) async {
    await _pumpAuthScreen(tester, _RecordingAuthRepository());

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'email-sai',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      '123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();

    expect(
      find.text('Email chưa đúng định dạng. Ví dụ: ban@example.com'),
      findsOneWidget,
    );
    expect(find.text('Mật khẩu cần ít nhất 6 ký tự.'), findsOneWidget);

    const emailError = 'Email chưa đúng định dạng. Ví dụ: ban@example.com';
    final emailErrorFinder =
        find.byKey(const ValueKey('field-error-$emailError'));
    final errorBox = tester.widget<Container>(emailErrorFinder);
    final errorDecoration = errorBox.decoration! as BoxDecoration;
    final errorText = tester.widget<Text>(find.text(emailError));

    expect(errorDecoration.color, AppColors.coral);
    expect(errorDecoration.border, isA<Border>());
    expect(errorDecoration.boxShadow?.single.offset, const Offset(3, 3));
    expect(errorText.style?.color, AppColors.softWhite);
    expect(errorText.style?.fontWeight, FontWeight.w800);
    expect(
      find.descendant(
        of: emailErrorFinder,
        matching: find.byIcon(Icons.error_outline_rounded),
      ),
      findsOneWidget,
    );

    final emailDecorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('email-field')),
        matching: find.byType(InputDecorator),
      ),
    );
    final errorBorder =
        emailDecorator.decoration.errorBorder! as OutlineInputBorder;
    expect(errorBorder.borderSide.color, AppColors.coral);

    final editableBottom = tester
        .getBottomRight(
          find.descendant(
            of: find.byKey(const Key('email-field')),
            matching: find.byType(EditableText),
          ),
        )
        .dy;
    expect(tester.getTopLeft(emailErrorFinder).dy, greaterThan(editableBottom));
    expect(
      tester.getTopLeft(emailErrorFinder).dx,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('email-input-box'))).dx,
        1,
      ),
    );
    expect(
      tester.getBottomRight(find.byKey(const Key('email-input-shadow'))).dy,
      lessThan(tester.getTopLeft(emailErrorFinder).dy),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text(emailError), findsNothing);
    final emailFieldState = tester.state<FormFieldState<String>>(
      find.byKey(const Key('email-field')),
    );
    expect(emailFieldState.hasError, isTrue);
    final decoratorAfterDismiss = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('email-field')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decoratorAfterDismiss.decoration.error, isNotNull);
  });

  testWidgets('bấm quên mật khẩu mở dialog khôi phục và gửi email thành công',
      (tester) async {
    final repository = _RecordingAuthRepository();
    await _pumpAuthScreen(tester, repository);

    // Điền trước email
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'capy@example.com',
    );

    // Bấm Quên mật khẩu?
    await tester.tap(find.byKey(const Key('forgot-password-button')));
    await tester.pumpAndSettle();

    // Dialog mở ra và pre-fill email
    expect(find.text('Khôi phục mật khẩu'), findsOneWidget);
    expect(find.byKey(const Key('reset-password-email-field')), findsOneWidget);
    expect(find.text('capy@example.com'), findsNWidgets(2));

    // Bấm Gửi liên kết
    await tester.tap(find.byKey(const Key('reset-password-submit-button')));
    await tester.pumpAndSettle();

    // Repository đã nhận email và dialog đóng lại
    expect(repository.resetEmailSent, 'capy@example.com');
    expect(find.text('Khôi phục mật khẩu'), findsNothing);
    expect(
      find.text(
        'Nếu tài khoản tồn tại, bạn sẽ nhận được liên kết đặt lại mật khẩu. Vui lòng kiểm tra cả thư rác.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('top-notification-banner')), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('top-notification-banner')), findsNothing);
  });

  testWidgets('lỗi gửi email không làm lộ lỗi thô từ Supabase', (tester) async {
    final repository = _RecordingAuthRepository(
      resetError: const AuthException('raw backend detail', code: 'unknown'),
    );
    await _pumpAuthScreen(tester, repository);

    await tester.tap(find.byKey(const Key('forgot-password-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reset-password-email-field')),
      'capy@example.com',
    );
    await tester.tap(find.byKey(const Key('reset-password-submit-button')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Đã xảy ra lỗi xác thực. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.textContaining('raw backend detail'), findsNothing);
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
  _RecordingAuthRepository({
    this.signInSucceeds = false,
    this.resetError,
  });

  final bool signInSucceeds;
  final Object? resetError;
  String? receivedDisplayName;
  String? resetEmailSent;

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
  }) async {
    if (!signInSucceeds) throw UnimplementedError();

    final user = User(
      id: 'remembered-user',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email,
      createdAt: '2026-09-04T00:00:00.000Z',
    );
    final session = Session(
      accessToken: 'test-access-token',
      tokenType: 'bearer',
      user: user,
    );
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (resetError != null) throw resetError!;
    resetEmailSent = email;
  }

  @override
  Future<void> updatePassword(String password) async {}
}
