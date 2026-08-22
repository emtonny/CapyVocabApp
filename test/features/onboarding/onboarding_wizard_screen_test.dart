import 'package:capy_vocab/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:capy_vocab/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:capy_vocab/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:capy_vocab/features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('progress nằm trên cùng và video onboarding được phóng lớn',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);

    final repository = _WidgetTestRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: OnboardingWizardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(const Key('onboarding-header'))).dy,
      55,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('onboarding-progress-bar'))).dy,
      greaterThan(47),
    );
    expect(
      tester.getSize(find.byKey(const Key('onboarding-video-box'))),
      const Size(63, 112),
    );
  });

  testWidgets('hiển thị và điều hướng đúng thứ tự 5 bước', (tester) async {
    final repository = _WidgetTestRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: OnboardingWizardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Họ tên và tên đăng nhập'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-username-field')),
      'capy_may',
    );
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Độ tuổi và số điện thoại'), findsOneWidget);

    final step2Card = tester.getRect(
      find.byKey(const Key('onboarding-step-content-card')),
    );
    final phoneField = tester.getRect(
      find.byKey(const Key('onboarding-phone-field')),
    );
    expect(step2Card.bottom - phoneField.bottom, closeTo(22.5, 0.1));

    await tester.enterText(
      find.byKey(const Key('onboarding-age-field')),
      '20',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-phone-field')),
      '0987654321',
    );
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn sử dụng ứng dụng với vai trò nào?'),
      findsOneWidget,
    );
    expect(find.byType(Radio<String>), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('role-personal-card')));
    await tester.tap(find.byKey(const Key('role-personal-card')));
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ học hằng ngày'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu từ vựng mỗi ngày'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('onboarding-back-button')));
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ học hằng ngày'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('onboarding-back-button')));
    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn sử dụng ứng dụng với vai trò nào?'),
      findsOneWidget,
    );
  });

  testWidgets('hiện lỗi và không cho qua bước 2 khi SĐT đã được sử dụng',
      (tester) async {
    final repository = _WidgetTestRepository()..phoneAvailable = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: OnboardingWizardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onboarding-username-field')),
      'capy_may',
    );
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('onboarding-age-field')),
      '20',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-phone-field')),
      '0987654321',
    );
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    expect(find.text('Số điện thoại đã được sử dụng.'), findsOneWidget);
    expect(find.text('Độ tuổi và số điện thoại'), findsOneWidget);
  });

  testWidgets('tùy chỉnh khung giờ lưu cả giờ bắt đầu và kết thúc',
      (tester) async {
    final repository = _WidgetTestRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: OnboardingWizardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Đi qua bước 1, 2, 3
    await tester.enterText(
      find.byKey(const Key('onboarding-username-field')),
      'capy_may',
    );
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('onboarding-age-field')), '20');
    await tester.enterText(
      find.byKey(const Key('onboarding-phone-field')),
      '0987654321',
    );
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('role-personal-card')));
    await tester.tap(find.byKey(const Key('role-personal-card')));
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    // Bước 4: mở picker, thay đổi giờ kết thúc và xác nhận.
    expect(find.text('Tùy chỉnh khung giờ'), findsOneWidget);
    expect(find.byKey(const Key('custom-study-time-card')), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingWizardScreen)),
    );
    expect(container.read(onboardingProvider).data.reminderTime, '20:00');
    expect(container.read(onboardingProvider).data.studyEndTime, '21:00');

    await tester.ensureVisible(
      find.byKey(const Key('custom-study-time-card')),
    );
    await tester.tap(find.byKey(const Key('custom-study-time-card')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.text('Giờ bắt đầu'), findsOneWidget);
    expect(find.text('Giờ kết thúc'), findsOneWidget);

    var picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.minimumDate, isNull);
    expect(picker.maximumDate, isNull);
    picker.onDateTimeChanged(DateTime(2000, 1, 1, 22));
    await tester.pump();

    await tester.tap(find.byKey(const Key('study-end-time-tab')));
    await tester.pumpAndSettle();
    picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.minimumDate, isNull);
    expect(picker.maximumDate, isNull);

    // Trùng giờ bị chặn.
    picker.onDateTimeChanged(DateTime(2000, 1, 1, 22));
    await tester.pump();
    expect(find.byKey(const Key('study-time-range-error')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('confirm-study-time-range')),
          )
          .onPressed,
      isNull,
    );

    // 22:00 → 02:00 là 4 giờ qua đêm: có cảnh báo mềm nhưng vẫn xác nhận được.
    picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    picker.onDateTimeChanged(DateTime(2000, 1, 2, 2));
    await tester.pump();
    expect(find.text('22:00 - 02:00'), findsOneWidget);
    expect(
      find.text(
        'Khung giờ học khá dài (4 tiếng) — '
        'nhớ giữ gìn sức khỏe, nghỉ ngơi hợp lý nhé!',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('study-time-range-error')), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('confirm-study-time-range')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('confirm-study-time-range')));
    await tester.pumpAndSettle();
    expect(container.read(onboardingProvider).data.reminderTime, '22:00');
    expect(container.read(onboardingProvider).data.studyEndTime, '02:00');
    expect(
      _cardBorderColor(tester, const Key('custom-study-time-card')),
      const Color(0xFF58CC02),
    );
    expect(
      _cardBorderColor(tester, const Key('study-time-picker-button')),
      const Color(0xFFEADECF),
    );

    // Cảnh báo không chặn Next sang Bước 5.
    await tester.ensureVisible(find.byKey(const Key('onboarding-next-button')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu từ vựng mỗi ngày'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();

    // Thay đổi lần nữa nhưng đóng bottom sheet: state phải được giữ nguyên.
    await tester.tap(find.byKey(const Key('custom-study-time-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('study-end-time-tab')));
    await tester.pumpAndSettle();
    picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    picker.onDateTimeChanged(DateTime(2000, 1, 2, 3));
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(container.read(onboardingProvider).data.reminderTime, '22:00');
    expect(container.read(onboardingProvider).data.studyEndTime, '02:00');

    // Chọn preset trở lại phải xóa trạng thái lựa chọn tùy chỉnh.
    await tester.tap(find.byKey(const Key('study-time-picker-button')));
    await tester.pumpAndSettle();
    expect(container.read(onboardingProvider).data.reminderTime, '20:00');
    expect(container.read(onboardingProvider).data.studyEndTime, '21:00');
    expect(
      _cardBorderColor(tester, const Key('custom-study-time-card')),
      const Color(0xFFEADECF),
    );
    expect(
      _cardBorderColor(tester, const Key('study-time-picker-button')),
      const Color(0xFF58CC02),
    );
  });
}

Color _cardBorderColor(WidgetTester tester, Key cardKey) {
  final animatedContainer = find.descendant(
    of: find.byKey(cardKey),
    matching: find.byType(AnimatedContainer),
  );
  final decoration = tester
      .widget<AnimatedContainer>(animatedContainer)
      .decoration! as BoxDecoration;
  return decoration.border!.top.color;
}

class _WidgetTestRepository implements OnboardingRepository {
  bool phoneAvailable = true;

  @override
  Future<OnboardingData> loadDraft() async {
    return const OnboardingData(displayName: 'Capy Mây');
  }

  @override
  Future<bool> isUsernameAvailable(String username) async => true;

  @override
  Future<bool> isPhoneAvailable(String phone) async => phoneAvailable;

  @override
  Future<void> completeOnboarding(OnboardingData data) async {}
}
