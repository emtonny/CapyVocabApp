import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/onboarding_repository.dart';
import '../../domain/entities/onboarding_data.dart';

const _usernamePattern = r'^[a-zA-Z0-9_]{3,20}$';
const _phonePattern = r'^0[0-9]{9}$';
const _timePattern = r'^(?:[01][0-9]|2[0-3]):[0-5][0-9]$';

int studyDurationMinutes(String startTime, String endTime) {
  final startMinutes = _minutesSinceMidnight(startTime);
  final endMinutes = _minutesSinceMidnight(endTime);
  final difference = endMinutes - startMinutes;
  return difference >= 0 ? difference : difference + 24 * 60;
}

int _minutesSinceMidnight(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => SupabaseOnboardingRepository(),
);

class OnboardingState {
  const OnboardingState({
    this.currentStep = 0,
    this.data = const OnboardingData(),
    this.isInitializing = true,
    this.isCheckingUsername = false,
    this.isCheckingPhone = false,
    this.isSaving = false,
    this.fieldErrors = const {},
    this.initializationError,
    this.saveError,
  });

  static const Object _notProvided = Object();

  final int currentStep;
  final OnboardingData data;
  final bool isInitializing;
  final bool isCheckingUsername;
  final bool isCheckingPhone;
  final bool isSaving;
  final Map<String, String> fieldErrors;
  final String? initializationError;
  final String? saveError;

  bool get isBusy => isCheckingUsername || isCheckingPhone || isSaving;

  OnboardingState copyWith({
    int? currentStep,
    OnboardingData? data,
    bool? isInitializing,
    bool? isCheckingUsername,
    bool? isCheckingPhone,
    bool? isSaving,
    Map<String, String>? fieldErrors,
    Object? initializationError = _notProvided,
    Object? saveError = _notProvided,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      data: data ?? this.data,
      isInitializing: isInitializing ?? this.isInitializing,
      isCheckingUsername: isCheckingUsername ?? this.isCheckingUsername,
      isCheckingPhone: isCheckingPhone ?? this.isCheckingPhone,
      isSaving: isSaving ?? this.isSaving,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      initializationError: identical(initializationError, _notProvided)
          ? this.initializationError
          : initializationError as String?,
      saveError: identical(saveError, _notProvided)
          ? this.saveError
          : saveError as String?,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier({required OnboardingRepository repository})
      : _repository = repository,
        super(const OnboardingState());

  final OnboardingRepository _repository;

  Future<void> loadInitialData() async {
    if (!state.isInitializing) {
      state = state.copyWith(
        isInitializing: true,
        initializationError: null,
      );
    }

    try {
      final data = await _repository.loadDraft();
      state = state.copyWith(
        data: data,
        isInitializing: false,
        initializationError: null,
      );
    } on OnboardingRepositoryException catch (error) {
      state = state.copyWith(
        isInitializing: false,
        initializationError: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isInitializing: false,
        initializationError:
            'Không thể tải thông tin thiết lập. Vui lòng thử lại.',
      );
    }
  }

  void updateDisplayName(String value) {
    state = state.copyWith(
      data: state.data.copyWith(displayName: value),
      fieldErrors: _withoutErrors('displayName'),
      saveError: null,
    );
  }

  void updateUsername(String value) {
    state = state.copyWith(
      data: state.data.copyWith(username: value),
      fieldErrors: _withoutErrors('username'),
      saveError: null,
    );
  }

  void updateAge(int? value) {
    state = state.copyWith(
      data: state.data.copyWith(age: value),
      fieldErrors: _withoutErrors('age'),
      saveError: null,
    );
  }

  void updatePhone(String value) {
    state = state.copyWith(
      data: state.data.copyWith(phone: value),
      fieldErrors: _withoutErrors('phone'),
      saveError: null,
    );
  }

  void updateAccountRole(String value) {
    state = state.copyWith(
      data: state.data.copyWith(accountRole: value),
      fieldErrors: _withoutErrors('accountRole'),
      saveError: null,
    );
  }

  void updateReminderTime(String value) {
    state = state.copyWith(
      data: state.data.copyWith(reminderTime: value),
      fieldErrors: _withoutStudyTimeErrors(),
      saveError: null,
    );
  }

  void updateStudyEndTime(String value) {
    state = state.copyWith(
      data: state.data.copyWith(studyEndTime: value),
      fieldErrors: _withoutStudyTimeErrors(),
      saveError: null,
    );
  }

  void updateStudyTimeRange({required String start, required String end}) {
    state = state.copyWith(
      data: state.data.copyWith(
        reminderTime: start,
        studyEndTime: end,
      ),
      fieldErrors: _withoutStudyTimeErrors(),
      saveError: null,
    );
  }

  void updateDailyTargetWords(int? value) {
    state = state.copyWith(
      data: state.data.copyWith(dailyTargetWords: value),
      fieldErrors: _withoutErrors('dailyTargetWords'),
      saveError: null,
    );
  }

  Future<bool> validateCurrentStep() {
    return switch (state.currentStep) {
      0 => _validateIdentityStep(),
      1 => _validateAgePhoneStep(),
      2 => Future.value(_validateRoleStep()),
      3 => Future.value(_validateStudyTimeStep()),
      4 => Future.value(_validateDailyTargetStep()),
      _ => Future.value(false),
    };
  }

  Future<bool> nextStep() async {
    if (state.isBusy || state.currentStep >= 4) return false;
    if (!await validateCurrentStep()) return false;

    state = state.copyWith(
      currentStep: state.currentStep + 1,
      fieldErrors: const {},
      saveError: null,
    );
    return true;
  }

  void previousStep() {
    if (state.isBusy || state.currentStep == 0) return;
    state = state.copyWith(
      currentStep: state.currentStep - 1,
      fieldErrors: const {},
      saveError: null,
    );
  }

  Future<bool> completeOnboarding() async {
    if (state.isSaving) return false;
    if (!await validateCurrentStep()) return false;

    state = state.copyWith(isSaving: true, saveError: null);

    try {
      final normalized = state.data.normalized();
      await _repository.completeOnboarding(normalized);
      state = state.copyWith(
        data: normalized,
        isSaving: false,
        saveError: null,
      );
      return true;
    } on OnboardingRepositoryException catch (error) {
      final errors = Map<String, String>.from(state.fieldErrors);
      var conflictStep = state.currentStep;
      switch (error.conflictingField) {
        case OnboardingConflictField.username:
          errors['username'] = error.message;
          conflictStep = 0;
          break;
        case OnboardingConflictField.phone:
          errors['phone'] = error.message;
          conflictStep = 1;
          break;
        case OnboardingConflictField.email:
        case null:
          break;
      }
      state = state.copyWith(
        currentStep: conflictStep,
        isSaving: false,
        fieldErrors: errors,
        saveError: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        saveError: 'Không thể lưu thông tin thiết lập. Vui lòng thử lại.',
      );
      return false;
    }
  }

  Future<bool> _validateIdentityStep() async {
    final errors = <String, String>{};
    final displayName = state.data.displayName.trim();
    final username = state.data.username.trim();

    if (displayName.isEmpty) {
      errors['displayName'] = 'Vui lòng nhập họ tên.';
    }
    if (username.isEmpty) {
      errors['username'] = 'Vui lòng nhập tên đăng nhập.';
    } else if (!RegExp(_usernamePattern).hasMatch(username)) {
      errors['username'] =
          'Username phải gồm 3-20 ký tự: chữ, số hoặc dấu gạch dưới.';
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return false;
    }

    final checkedUsername = username.toLowerCase();
    state = state.copyWith(
      isCheckingUsername: true,
      fieldErrors: const {},
    );

    try {
      final isAvailable =
          await _repository.isUsernameAvailable(checkedUsername);

      if (state.data.username.trim().toLowerCase() != checkedUsername) {
        state = state.copyWith(
          isCheckingUsername: false,
          fieldErrors: const {
            'username': 'Username đã thay đổi. Vui lòng kiểm tra lại.',
          },
        );
        return false;
      }

      if (!isAvailable) {
        state = state.copyWith(
          isCheckingUsername: false,
          fieldErrors: const {
            'username': 'Tên đăng nhập đã được sử dụng.',
          },
        );
        return false;
      }

      state = state.copyWith(
        data: state.data.copyWith(
          displayName: displayName,
          username: checkedUsername,
        ),
        isCheckingUsername: false,
        fieldErrors: const {},
      );
      return true;
    } on OnboardingRepositoryException catch (error) {
      state = state.copyWith(
        isCheckingUsername: false,
        fieldErrors: {'username': error.message},
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isCheckingUsername: false,
        fieldErrors: const {
          'username': 'Không thể kiểm tra tên đăng nhập. Vui lòng thử lại.',
        },
      );
      return false;
    }
  }

  Future<bool> _validateAgePhoneStep() async {
    final errors = <String, String>{};
    final age = state.data.age;
    final phone = state.data.phone.trim();

    if (age == null) {
      errors['age'] = 'Vui lòng nhập tuổi.';
    } else if (age < 1 || age > 120) {
      errors['age'] = 'Tuổi phải nằm trong khoảng từ 1 đến 120.';
    }

    if (phone.isEmpty) {
      errors['phone'] = 'Vui lòng nhập số điện thoại.';
    } else if (!RegExp(_phonePattern).hasMatch(phone)) {
      errors['phone'] = 'Số điện thoại phải gồm đúng 10 số và bắt đầu bằng 0.';
    }

    state = state.copyWith(
      data: state.data.copyWith(phone: phone),
      fieldErrors: errors,
    );
    if (errors.isNotEmpty) return false;

    final checkedPhone = phone;
    state = state.copyWith(
      isCheckingPhone: true,
      fieldErrors: const {},
    );

    try {
      final isAvailable = await _repository.isPhoneAvailable(checkedPhone);

      if (state.data.phone.trim() != checkedPhone) {
        state = state.copyWith(
          isCheckingPhone: false,
          fieldErrors: const {
            'phone': 'Số điện thoại đã thay đổi. Vui lòng kiểm tra lại.',
          },
        );
        return false;
      }

      if (!isAvailable) {
        state = state.copyWith(
          isCheckingPhone: false,
          fieldErrors: const {
            'phone': 'Số điện thoại đã được sử dụng.',
          },
        );
        return false;
      }

      state = state.copyWith(
        isCheckingPhone: false,
        fieldErrors: const {},
      );
      return true;
    } on OnboardingRepositoryException catch (error) {
      state = state.copyWith(
        isCheckingPhone: false,
        fieldErrors: {'phone': error.message},
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isCheckingPhone: false,
        fieldErrors: const {
          'phone': 'Không thể kiểm tra số điện thoại. Vui lòng thử lại.',
        },
      );
      return false;
    }
  }

  bool _validateRoleStep() {
    final role = state.data.accountRole;
    final isValid = role == 'personal' || role == 'parent';
    state = state.copyWith(
      fieldErrors: isValid
          ? const {}
          : const {'accountRole': 'Vui lòng chọn một vai trò.'},
    );
    return isValid;
  }

  bool _validateStudyTimeStep() {
    final reminderTime = state.data.reminderTime;
    final studyEndTime = state.data.studyEndTime;
    final errors = <String, String>{};

    if (!_isValidTime(reminderTime)) {
      errors['reminderTime'] = 'Vui lòng chọn giờ bắt đầu hợp lệ.';
    }
    if (!_isValidTime(studyEndTime)) {
      errors['studyEndTime'] = 'Vui lòng chọn giờ kết thúc hợp lệ.';
    } else if (_isValidTime(reminderTime) &&
        studyDurationMinutes(reminderTime!, studyEndTime!) == 0) {
      errors['studyEndTime'] = 'Giờ kết thúc không được trùng giờ bắt đầu.';
    }

    state = state.copyWith(fieldErrors: errors);
    return errors.isEmpty;
  }

  bool _validateDailyTargetStep() {
    final target = state.data.dailyTargetWords;
    final isValid = target != null && target > 0;
    state = state.copyWith(
      fieldErrors: isValid
          ? const {}
          : const {
              'dailyTargetWords': 'Mục tiêu mỗi ngày phải lớn hơn 0.',
            },
    );
    return isValid;
  }

  bool _isValidTime(String? value) {
    return value != null && RegExp(_timePattern).hasMatch(value);
  }

  Map<String, String> _withoutStudyTimeErrors() {
    final errors = Map<String, String>.from(state.fieldErrors);
    errors
      ..remove('reminderTime')
      ..remove('studyEndTime');
    return errors;
  }

  Map<String, String> _withoutErrors(String key) {
    final errors = Map<String, String>.from(state.fieldErrors)..remove(key);
    return errors;
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final notifier = OnboardingNotifier(
    repository: ref.watch(onboardingRepositoryProvider),
  );
  unawaited(notifier.loadInitialData());
  return notifier;
});
