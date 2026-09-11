import 'dart:async';

import 'package:capy_vocab/features/onboarding/application/onboarding_status_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('unknown is owner-scoped and persisted statuses never mix users',
      () async {
    final store = await SharedPreferencesOnboardingStatusStore.create();

    expect(store.statusFor('user-a'), OnboardingStatus.unknown);
    expect(store.statusFor('user-b'), OnboardingStatus.unknown);

    await store.setStatus('user-a', OnboardingStatus.complete);
    await store.setStatus('user-b', OnboardingStatus.incomplete);

    final restored = await SharedPreferencesOnboardingStatusStore.create();
    expect(restored.statusFor('user-a'), OnboardingStatus.complete);
    expect(restored.statusFor('user-b'), OnboardingStatus.incomplete);
    expect(restored.statusFor('unknown-user'), OnboardingStatus.unknown);
  });

  test('refresh is single-flight per user and writes the resolved owner only',
      () async {
    final store = MemoryOnboardingStatusStore();
    final response = Completer<bool>();
    var requests = 0;
    final refresher = OnboardingStatusRefresher(
      store: store,
      loadRemoteStatus: (_) {
        requests++;
        return response.future;
      },
    );

    final first = refresher.refresh('user-a');
    final second = refresher.refresh('user-a');
    expect(requests, 1);

    response.complete(true);
    await Future.wait([first, second]);

    expect(store.statusFor('user-a'), OnboardingStatus.complete);
    expect(store.statusFor('user-b'), OnboardingStatus.unknown);
  });

  test('failed refresh backs off without blocking and retries after deadline',
      () async {
    final store = MemoryOnboardingStatusStore();
    var now = DateTime.utc(2026, 9, 8);
    var requests = 0;
    final refresher = OnboardingStatusRefresher(
      store: store,
      clock: () => now,
      loadRemoteStatus: (_) async {
        requests++;
        throw StateError('offline');
      },
    );

    await refresher.refresh('user-a');
    await refresher.refresh('user-a');
    expect(requests, 1);
    expect(store.statusFor('user-a'), OnboardingStatus.unknown);

    now = now.add(const Duration(seconds: 30));
    await refresher.refresh('user-a');
    expect(requests, 2);
  });

  test('reset updates cache only after remote reset succeeds', () async {
    final store = MemoryOnboardingStatusStore();
    await store.setStatus('user-a', OnboardingStatus.complete);

    await expectLater(
      resetOnboardingAndUpdateCache(
        userId: 'user-a',
        resetRemote: () async => throw StateError('RPC failed'),
        store: store,
      ),
      throwsStateError,
    );
    expect(store.statusFor('user-a'), OnboardingStatus.complete);

    await resetOnboardingAndUpdateCache(
      userId: 'user-a',
      resetRemote: () async {},
      store: store,
    );
    expect(store.statusFor('user-a'), OnboardingStatus.incomplete);
  });
}
