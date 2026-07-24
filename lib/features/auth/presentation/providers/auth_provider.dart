// FR-AUTH-01, FR-AUTH-02, UC-AUTH-01
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-AUTH-01, FR-AUTH-02, UC-AUTH-01
class AuthState {
  const AuthState();
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-AUTH-01, FR-AUTH-02, UC-AUTH-01
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
