import 'package:capy_vocab/features/auth/data/repositories/account_phone_verification_gateway.dart';
import 'package:capy_vocab/features/settings/data/account_contact_repository.dart';
import 'package:capy_vocab/features/settings/domain/account_contact_settings.dart';
import 'package:capy_vocab/features/settings/presentation/providers/account_contact_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone change requires current password before sending SMS', () async {
    final gateway = _PhoneGateway();
    final notifier = AccountContactNotifier(
      repository: _ContactRepository(),
      phoneGateway: gateway,
    );

    final sent = await notifier.requestPhoneChange(
      phone: '+84 987 654 321',
      currentPassword: '',
    );

    expect(sent, isFalse);
    expect(notifier.state.error, 'Vui lòng nhập mật khẩu hiện tại.');
    expect(gateway.requestedPhone, isNull);
  });

  test('phone change normalizes number and forwards current password',
      () async {
    final gateway = _PhoneGateway();
    final notifier = AccountContactNotifier(
      repository: _ContactRepository(),
      phoneGateway: gateway,
    );

    final sent = await notifier.requestPhoneChange(
      phone: '+84 987 654 321',
      currentPassword: 'secret-password',
    );

    expect(sent, isTrue);
    expect(gateway.requestedPhone, '+84987654321');
    expect(gateway.currentPassword, 'secret-password');
    expect(notifier.state.pendingPhone, '+84987654321');
  });

  test('verified phone reloads contact settings from the server', () async {
    final repository = _ContactRepository();
    final gateway = _PhoneGateway();
    final notifier = AccountContactNotifier(
      repository: repository,
      phoneGateway: gateway,
    );
    await notifier.requestPhoneChange(
      phone: '+84987654321',
      currentPassword: 'secret-password',
    );

    final verified = await notifier.verifyPhoneChange('123456');

    expect(verified, isTrue);
    expect(gateway.verifiedCode, '123456');
    expect(repository.loadCalls, 1);
    expect(notifier.state.settings?.phoneConfirmed, isTrue);
    expect(notifier.state.pendingPhone, isNull);
  });
}

class _PhoneGateway implements AccountPhoneVerificationGateway {
  String? requestedPhone;
  String? currentPassword;
  String? verifiedCode;

  @override
  String? get verifiedPhone => null;

  @override
  Future<void> requestCode(String phone, {String? currentPassword}) async {
    requestedPhone = phone;
    this.currentPassword = currentPassword;
  }

  @override
  Future<void> verifyCode({required String phone, required String code}) async {
    verifiedCode = code;
  }
}

class _ContactRepository implements AccountContactRepository {
  int loadCalls = 0;

  @override
  Future<AccountContactSettings> load() async {
    loadCalls += 1;
    return const AccountContactSettings(
      email: 'verified@example.com',
      phone: '+84987654321',
      emailConfirmed: true,
      phoneConfirmed: true,
      showEmailToFriends: false,
      showPhoneToFriends: false,
    );
  }

  @override
  Future<void> requestEmailChange({
    required String email,
    required String currentPassword,
  }) async {}

  @override
  Future<AccountContactSettings> updateVisibility({
    required bool showEmail,
    required bool showPhone,
  }) async =>
      load();
}
