import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player_win/video_player_win_plugin.dart';
import 'core/services/supabase_service.dart';
import 'features/onboarding/application/onboarding_status_store.dart';
import 'features/onboarding/data/datasources/supabase_onboarding_status_loader.dart';
import 'features/onboarding/presentation/providers/onboarding_status_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    WindowsVideoPlayer.registerWith();
  }

  try {
    await dotenv.load(fileName: 'assets/config/client.config');
  } catch (e) {
    debugPrint('Dotenv load warning: $e');
  }

  late final OnboardingStatusStore onboardingStatusStore;
  try {
    onboardingStatusStore =
        await SharedPreferencesOnboardingStatusStore.create();
  } catch (error) {
    debugPrint('Onboarding cache initialization warning: $error');
    onboardingStatusStore = MemoryOnboardingStatusStore();
  }

  Widget rootApp;
  try {
    await SupabaseService.initialize();
    final onboardingStatusRefresher = OnboardingStatusRefresher(
      store: onboardingStatusStore,
      loadRemoteStatus: loadSupabaseOnboardingStatus,
    );
    rootApp = ProviderScope(
      overrides: [
        onboardingStatusStoreProvider.overrideWithValue(
          onboardingStatusStore,
        ),
        onboardingStatusRefresherProvider.overrideWithValue(
          onboardingStatusRefresher,
        ),
      ],
      child: CapyVocabApp(
        onboardingStatusStore: onboardingStatusStore,
        onboardingStatusRefresher: onboardingStatusRefresher,
      ),
    );
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
    rootApp = const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ứng dụng chưa được cấu hình máy chủ hợp lệ.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  runApp(rootApp);
}
