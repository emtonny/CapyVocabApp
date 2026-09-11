import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup does not require a successful Supabase health request', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource =
        File('lib/core/routes/app_router.dart').readAsStringSync();
    final syncProviderSource = File(
      'lib/features/library/presentation/providers/library_sync_provider.dart',
    ).readAsStringSync();

    expect(mainSource, isNot(contains('SupabaseService.testConnection()')));
    expect(mainSource, isNot(contains('SupabaseHealthGate')));
    expect(
      mainSource.indexOf('SharedPreferencesOnboardingStatusStore.create()'),
      lessThan(mainSource.indexOf('runApp(rootApp)')),
      reason: 'the synchronous onboarding cache must be ready before runApp',
    );
    expect(
      routerSource,
      isNot(contains("from('users')")),
      reason: 'route evaluation must never query the remote profile',
    );
    expect(routerSource, isNot(contains('redirect: (context, state) async')));
    expect(routerSource, contains('Unknown intentionally fails open'));
    expect(syncProviderSource, contains("'LIBRARY_SYNC_ENABLED'"));
    expect(syncProviderSource, contains('defaultValue: false'));
  });
}
