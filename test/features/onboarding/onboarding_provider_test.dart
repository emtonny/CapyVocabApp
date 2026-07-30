import 'dart:async';

import 'package:capy_vocab/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:capy_vocab/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:capy_vocab/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wizard validate và chuyển đúng thứ tự 5 bước', () async {
    final repository = _FakeOnboardingRepository();
    final notifier = OnboardingNotifier(repository: repository);
    addTearDown(notifier.dispose);
    await notifier.loadInitialData();

    notifier.updateUsername('taken_name');
    repository.usernameAvailable = false;
    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.currentStep, 0);
    expect(notifier.state.fieldErrors['username'], contains('đã được sử dụng'));

    repository.usernameAvailable = true;
    notifier.updateUsername('Capy_May');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 1);
    expect(repository.checkedUsername, 'capy_may');

    notifier.updateAge(0);
    notifier.updatePhone('123');
    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.fieldErrors['age'], contains('1 đến 120'));
    expect(notifier.state.fieldErrors['phone'], contains('đúng 10 số'));

    notifier.updateAge(20);
    notifier.updatePhone('0987654321');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 2);

    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.fieldErrors['accountRole'], isNotNull);

    notifier.updateAccountRole('personal');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 3);

    notifier.updateReminderTime('25:00');
    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.fieldErrors['reminderTime'], isNotNull);

    notifier.updateReminderTime('07:05');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 4);

    notifier.updateDailyTargetWords(0);
    expect(await notifier.validateCurrentStep(), isFalse);
    expect(notifier.state.fieldErrors['dailyTargetWords'], isNotNull);

    notifier.updateDailyTargetWords(15);
    expect(await notifier.validateCurrentStep(), isTrue);
  });

  test('dữ liệu được giữ nguyên khi quay lại bước trước', () async {
    final repository = _FakeOnboardingRepository();
    final notifier = OnboardingNotifier(repository: repository);
    addTearDown(notifier.dispose);
    await notifier.loadInitialData();

    notifier.updateUsername('capy_may');
    await notifier.nextStep();
    notifier.updateAge(18);
    notifier.updatePhone('0912345678');
    await notifier.nextStep();

    notifier.previousStep();

    expect(notifier.state.currentStep, 1);
    expect(notifier.state.data.username, 'capy_may');
    expect(notifier.state.data.age, 18);
    expect(notifier.state.data.phone, '0912345678');
  });

  test('chặn submit lặp trong lúc đang lưu', () async {
    final repository = _FakeOnboardingRepository()
      ..completeCompleter = Completer<void>();
    final notifier = OnboardingNotifier(repository: repository);
    addTearDown(notifier.dispose);
    await notifier.loadInitialData();
    await _moveToFinalStep(notifier);

    final firstSubmit = notifier.completeOnboarding();
    await Future<void>.delayed(Duration.zero);
    final secondResult = await notifier.completeOnboarding();

    expect(secondResult, isFalse);
    expect(repository.completeCalls, 1);
    expect(notifier.state.isSaving, isTrue);

    repository.completeCompleter!.complete();
    expect(await firstSubmit, isTrue);
    expect(notifier.state.isSaving, isFalse);
  });

  test('lỗi lưu giữ onboarding chưa hoàn tất và cho phép thử lại', () async {
    final repository = _FakeOnboardingRepository()
      ..completeError = const OnboardingRepositoryException(
        'Không thể lưu thông tin thiết lập. Vui lòng thử lại.',
      );
    final notifier = OnboardingNotifier(repository: repository);
    addTearDown(notifier.dispose);
    await notifier.loadInitialData();
    await _moveToFinalStep(notifier);

    expect(await notifier.completeOnboarding(), isFalse);
    expect(notifier.state.currentStep, 4);
    expect(notifier.state.isSaving, isFalse);
    expect(notifier.state.saveError, contains('thử lại'));
  });
}

Future<void> _moveToFinalStep(OnboardingNotifier notifier) async {
  notifier.updateUsername('capy_may');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateAge(20);
  notifier.updatePhone('0987654321');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateAccountRole('personal');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateReminderTime('20:00');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateDailyTargetWords(10);
}

class _FakeOnboardingRepository implements OnboardingRepository {
  OnboardingData draft = const OnboardingData(displayName: 'Capy Mây');
  bool usernameAvailable = true;
  String? checkedUsername;
  int completeCalls = 0;
  Completer<void>? completeCompleter;
  OnboardingRepositoryException? completeError;

  @override
  Future<OnboardingData> loadDraft() async => draft;

  @override
  Future<bool> isUsernameAvailable(String username) async {
    checkedUsername = username;
    return usernameAvailable;
  }

  @override
  Future<void> completeOnboarding(OnboardingData data) async {
    completeCalls += 1;
    if (completeError case final error?) throw error;
    if (completeCompleter case final completer?) {
      await completer.future;
    }
  }
}
