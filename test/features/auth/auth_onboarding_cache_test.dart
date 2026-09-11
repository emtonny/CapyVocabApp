import 'dart:async';

import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:capy_vocab/features/onboarding/application/onboarding_status_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('sign-in starts background onboarding refresh for the signed-in owner',
      () async {
    final session = _sessionFor('user-a');
    final store = MemoryOnboardingStatusStore();
    final response = Completer<bool>();
    final requestedUsers = <String>[];
    final refresher = OnboardingStatusRefresher(
      store: store,
      loadRemoteStatus: (userId) {
        requestedUsers.add(userId);
        return response.future;
      },
    );
    final notifier = AuthNotifier(
      repository: _AuthRepository(session: session),
      initialSession: null,
      onboardingStatusStore: store,
      onboardingStatusRefresher: refresher,
    );
    addTearDown(notifier.dispose);
    addTearDown(store.dispose);

    expect(
      await notifier.signInWithPassword(
        email: 'capy@example.com',
        password: 'secret',
      ),
      session,
    );
    expect(requestedUsers, ['user-a']);
    expect(store.statusFor('user-a'), OnboardingStatus.unknown);

    response.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(store.statusFor('user-a'), OnboardingStatus.complete);
  });

  test('sign-up marks only the new owner incomplete', () async {
    final session = _sessionFor('user-b');
    final store = MemoryOnboardingStatusStore();
    final notifier = AuthNotifier(
      repository: _AuthRepository(session: session),
      initialSession: null,
      onboardingStatusStore: store,
      onboardingStatusRefresher: OnboardingStatusRefresher(
        store: store,
        loadRemoteStatus: (_) async => true,
      ),
    );
    addTearDown(notifier.dispose);
    addTearDown(store.dispose);

    await notifier.signUp(
      email: 'new@example.com',
      password: 'secret',
      displayName: 'New User',
    );

    expect(store.statusFor('user-b'), OnboardingStatus.incomplete);
    expect(store.statusFor('user-a'), OnboardingStatus.unknown);
  });
}

Session _sessionFor(String userId) => Session(
      accessToken: 'not-a-jwt',
      tokenType: 'bearer',
      user: User(
        id: userId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-09-08T00:00:00.000Z',
      ),
    );

class _AuthRepository implements AuthRepository {
  _AuthRepository({required this.session});

  final Session session;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => session.user;

  @override
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async =>
      AuthResponse(session: session, user: session.user);

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      AuthResponse(session: session, user: session.user);

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) async => false;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> updatePassword(String password) async {}
}
