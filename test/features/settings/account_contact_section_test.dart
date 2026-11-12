import 'package:capy_vocab/features/auth/data/repositories/account_phone_verification_gateway.dart';
import 'package:capy_vocab/features/settings/data/account_contact_repository.dart';
import 'package:capy_vocab/features/settings/domain/account_contact_settings.dart';
import 'package:capy_vocab/features/settings/presentation/providers/account_contact_provider.dart';
import 'package:capy_vocab/features/settings/presentation/widgets/account_contact_section.dart';
import 'package:capy_vocab/features/settings/presentation/widgets/settings_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('email visibility remains and every SMS control is hidden',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final repository = _Repository();
    final gateway = _PhoneGateway();
    final notifier = AccountContactNotifier(
      repository: repository,
      phoneGateway: gateway,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountContactProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AccountContactSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SettingsToggle>(
            find.byKey(const Key('show-email-to-friends-switch')),
          )
          .value,
      isFalse,
    );
    expect(find.byKey(const Key('change-phone-tile')), findsNothing);
    expect(
      find.byKey(const Key('show-phone-to-friends-switch')),
      findsNothing,
    );
    expect(find.byKey(const Key('request-phone-change')), findsNothing);
    expect(gateway.requestedPhone, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _PhoneGateway implements AccountPhoneVerificationGateway {
  String? requestedPhone;
  String? currentPassword;

  @override
  String? get verifiedPhone => null;

  @override
  Future<void> requestCode(String phone, {String? currentPassword}) async {
    requestedPhone = phone;
    this.currentPassword = currentPassword;
  }

  @override
  Future<void> verifyCode(
      {required String phone, required String code}) async {}
}

class _Repository implements AccountContactRepository {
  @override
  Future<AccountContactSettings> load() async {
    return const AccountContactSettings(
      email: 'owner@example.com',
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
