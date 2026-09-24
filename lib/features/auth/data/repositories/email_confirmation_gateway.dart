import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import 'auth_repository_impl.dart';

abstract interface class EmailConfirmationGateway {
  Future<void> resendSignUpConfirmation(String email);
}

class SupabaseEmailConfirmationGateway implements EmailConfirmationGateway {
  SupabaseEmailConfirmationGateway({
    SupabaseClient? client,
    String? emailRedirectTo,
  })  : _client = client ?? SupabaseService.client,
        _emailRedirectTo = emailRedirectTo ??
            (kIsWeb
                ? Uri.base.origin
                : AuthRepositoryImpl.mobileLoginRedirectUrl);

  final SupabaseClient _client;
  final String _emailRedirectTo;

  @override
  Future<void> resendSignUpConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _emailRedirectTo,
    );
  }
}

final emailConfirmationGatewayProvider = Provider<EmailConfirmationGateway>(
  (ref) => SupabaseEmailConfirmationGateway(),
);
