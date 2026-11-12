import 'package:capy_vocab/features/auth/data/repositories/email_confirmation_gateway.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resend trims email and reports success', () async {
    final gateway = _EmailGateway();
    final notifier = EmailConfirmationNotifier(gateway);

    final sent = await notifier.resend('  user@example.com  ');

    expect(sent, isTrue);
    expect(gateway.email, 'user@example.com');
    expect(notifier.state, isA<AsyncData<void>>());
  });

  test('resend reports failure without throwing to the UI', () async {
    final notifier = EmailConfirmationNotifier(
      _EmailGateway(error: StateError('mail unavailable')),
    );

    final sent = await notifier.resend('user@example.com');

    expect(sent, isFalse);
    expect(notifier.state, isA<AsyncError<void>>());
  });
}

class _EmailGateway implements EmailConfirmationGateway {
  _EmailGateway({this.error});

  final Object? error;
  String? email;

  @override
  Future<void> resendSignUpConfirmation(String email) async {
    this.email = email;
    if (error case final error?) throw error;
  }
}
