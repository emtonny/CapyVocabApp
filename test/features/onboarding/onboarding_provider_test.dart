import 'dart:async';

import 'package:capy_vocab/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:capy_vocab/features/onboarding/application/onboarding_status_store.dart';
import 'package:capy_vocab/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:capy_vocab/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:capy_vocab/features/auth/data/repositories/account_phone_verification_gateway.dart';
import 'package:capy_vocab/features/language_profile/application/language_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wizard validate và chuyển đúng thứ tự 6 bước', () async {
    final repository = _FakeOnboardingRepository();
    final notifier = _buildNotifier(repository);
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

    expect(notifier.state.data.interfaceLocale, 'vi-VN');
    expect(notifier.state.data.learningLocale, 'en-US');
    expect(notifier.state.data.nativeLanguageCode, 'vi');
    expect(notifier.state.data.learningLanguageCode, 'en');
    notifier.updateInterfaceLocale('en-GB');
    notifier.updateLearningLocale('en-US');
    expect(await notifier.nextStep(), isFalse);
    expect(
      notifier.state.fieldErrors['learningLocale'],
      contains('phải khác'),
    );

    notifier.updateLearningLocale('vi-VN');
    notifier.updateProficiencyLevel('intermediate');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 2);
    expect(notifier.state.data.nativeLanguageCode, 'en');
    expect(notifier.state.data.learningLanguageCode, 'vi');

    notifier.updateAge(0);
    notifier.updatePhone('123');
    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.fieldErrors['age'], contains('1 đến 120'));
    expect(notifier.state.fieldErrors['phone'], isNull);

    notifier.updateAge(20);
    repository.phoneAvailable = false;
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 3);
    expect(repository.checkedPhone, isNull);

    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.fieldErrors['accountRole'], isNotNull);

    notifier.updateAccountRole('admin');
    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.currentStep, 3);

    notifier.updateAccountRole('teacher');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 4);
    expect(notifier.state.data.accountRole, 'teacher');

    notifier.updateReminderTime('25:00');
    expect(await notifier.nextStep(), isFalse);
    expect(notifier.state.fieldErrors['reminderTime'], isNotNull);

    notifier.updateReminderTime('07:05');
    notifier.updateStudyEndTime('07:05');
    expect(await notifier.nextStep(), isFalse);
    expect(
      notifier.state.fieldErrors['studyEndTime'],
      'Giờ kết thúc không được trùng giờ bắt đầu.',
    );

    notifier.updateStudyTimeRange(start: '22:00', end: '02:00');
    expect(await notifier.nextStep(), isTrue);
    expect(notifier.state.currentStep, 5);

    notifier.updateDailyTargetWords(0);
    expect(await notifier.validateCurrentStep(), isFalse);
    expect(notifier.state.fieldErrors['dailyTargetWords'], isNotNull);

    notifier.updateDailyTargetWords(15);
    expect(await notifier.validateCurrentStep(), isTrue);
  });

  test('tính thời lượng cùng ngày, qua đêm và trùng giờ', () {
    expect(studyDurationMinutes('20:00', '23:00'), 180);
    expect(studyDurationMinutes('22:00', '02:00'), 240);
    expect(studyDurationMinutes('07:05', '07:05'), 0);
  });

  test('dữ liệu được giữ nguyên khi quay lại bước trước', () async {
    final repository = _FakeOnboardingRepository();
    final notifier = _buildNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadInitialData();

    notifier.updateUsername('capy_may');
    await notifier.nextStep();
    notifier.updateInterfaceLocale('en-GB');
    notifier.updateLearningLocale('vi-VN');
    await notifier.nextStep();
    notifier.updateAge(18);
    await notifier.nextStep();

    notifier.previousStep();

    expect(notifier.state.currentStep, 2);
    expect(notifier.state.data.username, 'capy_may');
    expect(notifier.state.data.interfaceLocale, 'en-GB');
    expect(notifier.state.data.learningLocale, 'vi-VN');
    expect(notifier.state.data.age, 18);
    expect(notifier.state.data.phone, isEmpty);
  });

  test('chặn submit lặp trong lúc đang lưu', () async {
    final repository = _FakeOnboardingRepository()
      ..completeCompleter = Completer<void>();
    final notifier = _buildNotifier(repository);
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

  test('complete thành công cập nhật cache đúng owner', () async {
    final repository = _FakeOnboardingRepository();
    final store = MemoryOnboardingStatusStore();
    final languageStore = MemoryLanguageProfileStore();
    final notifier = OnboardingNotifier(
      repository: repository,
      phoneVerificationGateway: _FakePhoneVerificationGateway(),
      onboardingStatusStore: store,
      languageProfileStore: languageStore,
      currentUserId: () => 'user-a',
    );
    addTearDown(notifier.dispose);
    addTearDown(store.dispose);
    addTearDown(languageStore.dispose);
    await notifier.loadInitialData();
    await _moveToFinalStep(notifier);

    expect(await notifier.completeOnboarding(), isTrue);
    expect(store.statusFor('user-a'), OnboardingStatus.complete);
    expect(store.statusFor('user-b'), OnboardingStatus.unknown);
    expect(languageStore.profileFor('user-a')?.nativeLanguageCode, 'vi');
    expect(languageStore.profileFor('user-a')?.learningLanguageCode, 'en');
    expect(languageStore.profileFor('user-b'), isNull);
  });

  test('lỗi lưu giữ onboarding chưa hoàn tất và cho phép thử lại', () async {
    final repository = _FakeOnboardingRepository()
      ..completeError = const OnboardingRepositoryException(
        'Không thể lưu thông tin thiết lập. Vui lòng thử lại.',
      );
    final notifier = _buildNotifier(repository);
    addTearDown(notifier.dispose);
    await notifier.loadInitialData();
    await _moveToFinalStep(notifier);

    expect(await notifier.completeOnboarding(), isFalse);
    expect(notifier.state.currentStep, 5);
    expect(notifier.state.isSaving, isFalse);
    expect(notifier.state.saveError, contains('thử lại'));
  });

  for (final testCase in <({
    OnboardingConflictField field,
    String message,
    int expectedStep,
    String? expectedErrorKey,
  })>[
    (
      field: OnboardingConflictField.username,
      message: 'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.',
      expectedStep: 0,
      expectedErrorKey: 'username',
    ),
    (
      field: OnboardingConflictField.phone,
      message: 'Số điện thoại đã được sử dụng. Vui lòng dùng số khác.',
      expectedStep: 2,
      expectedErrorKey: 'phone',
    ),
    (
      field: OnboardingConflictField.email,
      message: 'Email đã được sử dụng. Vui lòng dùng email khác.',
      expectedStep: 5,
      expectedErrorKey: null,
    ),
  ]) {
    test('đưa lỗi unique ${testCase.field.name} về đúng bước', () async {
      final repository = _FakeOnboardingRepository()
        ..completeError = OnboardingRepositoryException(
          testCase.message,
          conflictingField: testCase.field,
        );
      final notifier = _buildNotifier(repository);
      addTearDown(notifier.dispose);
      await notifier.loadInitialData();
      await _moveToFinalStep(notifier);

      expect(await notifier.completeOnboarding(), isFalse);
      expect(notifier.state.currentStep, testCase.expectedStep);
      expect(notifier.state.saveError, testCase.message);
      if (testCase.expectedErrorKey case final key?) {
        expect(notifier.state.fieldErrors[key], testCase.message);
      } else {
        expect(notifier.state.fieldErrors, isEmpty);
      }
    });
  }
}

Future<void> _moveToFinalStep(OnboardingNotifier notifier) async {
  notifier.updateUsername('capy_may');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateInterfaceLocale('vi-VN');
  notifier.updateLearningLocale('en-US');
  notifier.updateProficiencyLevel('beginner');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateAge(20);
  expect(await notifier.nextStep(), isTrue);
  notifier.updateAccountRole('personal');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateStudyTimeRange(start: '20:00', end: '21:00');
  expect(await notifier.nextStep(), isTrue);
  notifier.updateDailyTargetWords(10);
}

OnboardingNotifier _buildNotifier(OnboardingRepository repository) {
  return OnboardingNotifier(
    repository: repository,
    phoneVerificationGateway: _FakePhoneVerificationGateway(),
  );
}

class _FakePhoneVerificationGateway implements AccountPhoneVerificationGateway {
  String? _verifiedPhone;

  @override
  String? get verifiedPhone => _verifiedPhone;

  @override
  Future<void> requestCode(String phone, {String? currentPassword}) async {}

  @override
  Future<void> verifyCode({required String phone, required String code}) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const AccountPhoneVerificationException('Mã không hợp lệ.');
    }
    _verifiedPhone = phone;
  }
}

class _FakeOnboardingRepository implements OnboardingRepository {
  OnboardingData draft = const OnboardingData(displayName: 'Capy Mây');
  bool usernameAvailable = true;
  bool phoneAvailable = true;
  String? checkedUsername;
  String? checkedPhone;
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
  Future<bool> isPhoneAvailable(String phone) async {
    checkedPhone = phone;
    return phoneAvailable;
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
