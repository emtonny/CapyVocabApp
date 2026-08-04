import 'package:capy_vocab/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:capy_vocab/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:capy_vocab/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:capy_vocab/features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Độ tuổi và số điện thoại'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-age-field')),
      '20',
    );
    await tester.enterText(
      find.byKey(const Key('onboarding-phone-field')),
      '0987654321',
    );
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Bạn sử dụng ứng dụng với vai trò nào?'),
      findsOneWidget,
    );
    expect(find.byType(Radio<String>), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);

    await tester.tap(find.byKey(const Key('role-personal-card')));
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ học hằng ngày'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu từ vựng mỗi ngày'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ học hằng ngày'), findsOneWidget);

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
    await tester.tap(find.byKey(const Key('onboarding-next-button')));
    await tester.pumpAndSettle();

    expect(find.text('Số điện thoại đã được sử dụng.'), findsOneWidget);
    expect(find.text('Độ tuổi và số điện thoại'), findsOneWidget);
  });
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
