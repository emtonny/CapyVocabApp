import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_status_store.dart';
import '../../data/datasources/supabase_onboarding_status_loader.dart';

final onboardingStatusStoreProvider = Provider<OnboardingStatusStore>(
  (ref) {
    final store = MemoryOnboardingStatusStore();
    ref.onDispose(store.dispose);
    return store;
  },
);

final onboardingStatusRefresherProvider = Provider<OnboardingStatusRefresher>(
  (ref) => OnboardingStatusRefresher(
    store: ref.watch(onboardingStatusStoreProvider),
    loadRemoteStatus: loadSupabaseOnboardingStatus,
  ),
);
