import 'package:flutter/material.dart';

import 'core/routes/app_router.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/application/onboarding_status_store.dart';
import 'features/library/presentation/widgets/library_sync_runtime.dart';
import 'features/onboarding/presentation/widgets/onboarding_status_runtime.dart';

class CapyVocabApp extends StatefulWidget {
  const CapyVocabApp({
    this.onboardingStatusStore,
    this.onboardingStatusRefresher,
    super.key,
  });

  final OnboardingStatusStore? onboardingStatusStore;
  final OnboardingStatusRefresher? onboardingStatusRefresher;

  @override
  State<CapyVocabApp> createState() => _CapyVocabAppState();
}

class _CapyVocabAppState extends State<CapyVocabApp> {
  late final OnboardingStatusStore _statusStore;
  late final AppRouter _appRouter;
  late final bool _ownsStatusStore;

  Stream<String?> get _authUserIds => SupabaseService.auth.onAuthStateChange
      .map((authState) => authState.session?.user.id);

  @override
  void initState() {
    super.initState();
    _ownsStatusStore = widget.onboardingStatusStore == null;
    _statusStore =
        widget.onboardingStatusStore ?? MemoryOnboardingStatusStore();
    _appRouter = AppRouter(
      currentUserId: () => SupabaseService.auth.currentUser?.id,
      authUserIds: _authUserIds,
      authStates: SupabaseService.auth.onAuthStateChange,
      onboardingStatusStore: _statusStore,
    );
  }

  @override
  void dispose() {
    _appRouter.dispose();
    if (_ownsStatusStore) _statusStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget app = LibrarySyncRuntime(
      child: MaterialApp.router(
        title: 'Deery Vocab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routerConfig: _appRouter.router,
      ),
    );

    final refresher = widget.onboardingStatusRefresher;
    if (refresher != null) {
      app = OnboardingStatusRuntime(
        currentUserId: () => SupabaseService.auth.currentUser?.id,
        authUserIds: _authUserIds,
        refresher: refresher,
        child: app,
      );
    }
    return app;
  }
}
