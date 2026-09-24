import 'dart:async';

import 'package:capy_vocab/features/friends/data/datasources/friend_phone_verification_datasource.dart';
import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:capy_vocab/features/friends/domain/friend_phone_verification.dart';
import 'package:capy_vocab/features/friends/presentation/widgets/friend_phone_verification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes Vietnamese Auth phone forms without accepting other input',
      () {
    expect(normalizeVietnameseFriendPhone('0123 456 789'), '0123456789');
    expect(normalizeVietnameseFriendPhone('+84 123 456 789'), '0123456789');
    expect(normalizeVietnameseFriendPhone('84123456789'), '0123456789');
    expect(normalizeVietnameseFriendPhone('123456789'), isNull);
    expect(normalizeVietnameseFriendPhone(null), isNull);
    expect(vietnameseFriendPhoneToE164('0123456789'), '+84123456789');
    expect(maskVietnameseFriendPhone('0123456789'), '012 ••• •• 89');
  });

  testWidgets('requests OTP once and verifies an exact six-digit code',
      (tester) async {
    final gateway = _FakePhoneGateway(
      challenge: const FriendPhoneChallenge(
        phoneE164: '+84123456789',
        maskedPhone: '012 ••• •• 89',
      ),
    );
    final result = ValueNotifier<bool?>(null);
    addTearDown(result.dispose);
    await _pumpLauncher(tester, gateway: gateway, result: result);

    await tester.tap(find.byKey(const Key('open-phone-dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('friend-phone-request-otp')));
    await tester.pumpAndSettle();

    expect(gateway.requestCalls, 1);
    expect(find.textContaining('012 ••• •• 89'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('friend-phone-otp-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('friend-phone-submit-otp')));
    await tester.pumpAndSettle();

    expect(gateway.verifyCalls, 1);
    expect(gateway.lastToken, '123456');
    expect(result.value, isTrue);
  });

  testWidgets('request button is single-flight while OTP request is pending',
      (tester) async {
    final request = Completer<FriendPhoneChallenge?>();
    final gateway = _FakePhoneGateway(requestCompleter: request);
    final result = ValueNotifier<bool?>(null);
    addTearDown(result.dispose);
    await _pumpLauncher(tester, gateway: gateway, result: result);

    await tester.tap(find.byKey(const Key('open-phone-dialog')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('friend-phone-request-otp'));
    await tester.tap(button);
    await tester.pump();
    expect(gateway.requestCalls, 1);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    request.complete(null);
    await tester.pumpAndSettle();
    expect(result.value, isTrue);
  });

  testWidgets('backend details are never rendered after OTP failure',
      (tester) async {
    final gateway = _FakePhoneGateway(
      requestError: const FriendException(
        FriendFailureKind.unavailable,
        'private provider response',
      ),
    );
    final result = ValueNotifier<bool?>(null);
    addTearDown(result.dispose);
    await _pumpLauncher(tester, gateway: gateway, result: result);

    await tester.tap(find.byKey(const Key('open-phone-dialog')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('friend-phone-request-otp')));
    await tester.pumpAndSettle();

    expect(find.textContaining('private provider response'), findsNothing);
    expect(
      find.text('Chưa thể kết nối dịch vụ Bạn bè. Hãy thử lại.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  required FriendPhoneVerificationGateway gateway,
  required ValueNotifier<bool?> result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const Key('open-phone-dialog'),
            onPressed: () async {
              result.value = await showFriendPhoneVerificationDialog(
                context,
                gateway: gateway,
              );
            },
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
}

class _FakePhoneGateway implements FriendPhoneVerificationGateway {
  _FakePhoneGateway({
    this.challenge,
    this.requestCompleter,
    this.requestError,
  });

  final FriendPhoneChallenge? challenge;
  final Completer<FriendPhoneChallenge?>? requestCompleter;
  final Object? requestError;
  int requestCalls = 0;
  int verifyCalls = 0;
  String? lastToken;

  @override
  Future<FriendPhoneChallenge?> requestVerification() async {
    requestCalls++;
    if (requestError case final error?) throw error;
    final completer = requestCompleter;
    if (completer != null) return completer.future;
    return challenge;
  }

  @override
  Future<void> verify({
    required FriendPhoneChallenge challenge,
    required String token,
  }) async {
    verifyCalls++;
    lastToken = token;
  }
}
