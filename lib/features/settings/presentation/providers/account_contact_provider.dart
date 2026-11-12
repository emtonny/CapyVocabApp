import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/repositories/account_phone_verification_gateway.dart';
import '../../../auth/domain/account_phone.dart';
import '../../data/account_contact_repository.dart';
import '../../domain/account_contact_settings.dart';

class AccountContactState {
  const AccountContactState({
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.pendingPhone,
    this.error,
  });

  final AccountContactSettings? settings;
  final bool isLoading;
  final bool isSaving;
  final String? pendingPhone;
  final String? error;

  AccountContactState copyWith({
    AccountContactSettings? settings,
    bool? isLoading,
    bool? isSaving,
    Object? pendingPhone = _notProvided,
    Object? error = _notProvided,
  }) {
    return AccountContactState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      pendingPhone: identical(pendingPhone, _notProvided)
          ? this.pendingPhone
          : pendingPhone as String?,
      error: identical(error, _notProvided) ? this.error : error as String?,
    );
  }

  static const _notProvided = Object();
}

class AccountContactNotifier extends StateNotifier<AccountContactState> {
  AccountContactNotifier({
    required AccountContactRepository repository,
    required AccountPhoneVerificationGateway phoneGateway,
  })  : _repository = repository,
        _phoneGateway = phoneGateway,
        super(const AccountContactState());

  final AccountContactRepository _repository;
  final AccountPhoneVerificationGateway _phoneGateway;

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      state = state.copyWith(
        settings: await _repository.load(),
        isLoading: false,
        error: null,
      );
    } on AccountContactException catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    }
  }

  Future<bool> requestEmailChange({
    required String email,
    required String currentPassword,
  }) async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _repository.requestEmailChange(
        email: email,
        currentPassword: currentPassword,
      );
      state = state.copyWith(isSaving: false, error: null);
      return true;
    } on AccountContactException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    }
  }

  Future<bool> requestPhoneChange({
    required String phone,
    required String currentPassword,
  }) async {
    if (state.isSaving) return false;
    final normalized = normalizeAccountPhone(phone);
    if (normalized == null) {
      state = state.copyWith(
        error: 'Nhập mã quốc gia và số điện thoại, ví dụ +84987654321.',
      );
      return false;
    }
    if (currentPassword.isEmpty) {
      state = state.copyWith(error: 'Vui lòng nhập mật khẩu hiện tại.');
      return false;
    }
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _phoneGateway.requestCode(
        normalized,
        currentPassword: currentPassword,
      );
      state = state.copyWith(
        isSaving: false,
        pendingPhone: normalized,
        error: null,
      );
      return true;
    } on AccountPhoneVerificationException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    }
  }

  Future<bool> verifyPhoneChange(String code) async {
    final phone = state.pendingPhone;
    if (state.isSaving || phone == null) return false;
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _phoneGateway.verifyCode(phone: phone, code: code);
      final settings = await _repository.load();
      state = state.copyWith(
        settings: settings,
        isSaving: false,
        pendingPhone: null,
        error: null,
      );
      return true;
    } on AccountPhoneVerificationException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    } on AccountContactException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
      return false;
    }
  }

  Future<void> updateVisibility({bool? email, bool? phone}) async {
    final current = state.settings;
    if (current == null || state.isSaving) return;
    state = state.copyWith(isSaving: true, error: null);
    try {
      final settings = await _repository.updateVisibility(
        showEmail: email ?? current.showEmailToFriends,
        showPhone: phone ?? current.showPhoneToFriends,
      );
      state = state.copyWith(
        settings: settings,
        isSaving: false,
        error: null,
      );
    } on AccountContactException catch (error) {
      state = state.copyWith(isSaving: false, error: error.message);
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final accountContactProvider =
    StateNotifierProvider<AccountContactNotifier, AccountContactState>((ref) {
  return AccountContactNotifier(
    repository: ref.watch(accountContactRepositoryProvider),
    phoneGateway: ref.watch(accountPhoneVerificationGatewayProvider),
  );
});
