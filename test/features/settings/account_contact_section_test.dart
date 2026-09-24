import 'package:capy_vocab/features/auth/data/repositories/account_phone_verification_gateway.dart';
import 'package:capy_vocab/features/settings/data/account_contact_repository.dart';
import 'package:capy_vocab/features/settings/domain/account_contact_settings.dart';
import 'package:capy_vocab/features/settings/presentation/providers/account_contact_provider.dart';
import 'package:capy_vocab/features/settings/presentation/widgets/account_contact_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('contacts default hidden and phone change requires password',
      (tester) async {
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
          .widget<SwitchListTile>(
            find.byKey(const Key('show-email-to-friends-switch')),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('show-phone-to-friends-switch')),
          )
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('change-phone-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('current-password-for-phone-field')), findsOne);

    await tester.enterText(
      find.byKey(const Key('new-phone-field')),
      '+33 1 42 27 81 86',
    );
    await tester.enterText(
      find.byKey(const Key('current-password-for-phone-field')),
      'current-password',
    );
    await tester.tap(find.byKey(const Key('request-phone-change')));
    await tester.pumpAndSettle();

    expect(gateway.requestedPhone, '+33142278186');
    expect(gateway.currentPassword, 'current-password');
    expect(find.byKey(const Key('phone-change-code-field')), findsOne);
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
