import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/ai_scan/presentation/screens/storage_album_screen.dart';
import '../../features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import '../../features/ai_scan/presentation/screens/photo_scan_bottom_sheet.dart';
import '../../features/ai_scan/presentation/screens/scan_result_overlay_screen.dart';
import '../../features/solo_arena/presentation/screens/solo_lobby_screen.dart';
import '../../features/pet_shop/presentation/screens/pet_shop_screen.dart';
import '../../features/friends/presentation/screens/friends_leaderboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Ánh xạ routing tương đương activateView(viewId) trong bản HTML gốc.
class AppRouter {
  AppRouter._();

  static final _authRefreshListenable = _SupabaseAuthRefreshListenable(
    Supabase.instance.client.auth.onAuthStateChange,
  );

  static final router = GoRouter(
    initialLocation: '/auth',
    refreshListenable: _authRefreshListenable,
    redirect: (context, state) async {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final isOnAuthScreen = state.matchedLocation == '/auth';
      final isOnOnboardingScreen = state.matchedLocation == '/onboarding';
      final isOnResetPasswordScreen =
          state.matchedLocation == '/reset-password';

      if (_authRefreshListenable.isPasswordRecovery && session != null) {
        return isOnResetPasswordScreen ? null : '/reset-password';
      }

      if (session == null) {
        return isOnAuthScreen || isOnResetPasswordScreen ? null : '/auth';
      }

      var hasCompletedOnboarding = false;

      try {
        final profile = await client
            .from('users')
            .select('onboarding_completed')
            .eq('id', session.user.id)
            .maybeSingle();

        hasCompletedOnboarding = profile?['onboarding_completed'] == true;
      } catch (error, stackTrace) {
        debugPrint('Failed to load onboarding status: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!hasCompletedOnboarding) {
        return isOnOnboardingScreen ? null : '/onboarding';
      }

      if (isOnAuthScreen || isOnOnboardingScreen || isOnResetPasswordScreen) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AuthScreen(
            initialMessage:
                state.uri.queryParameters['passwordReset'] == 'success'
                    ? 'Đổi mật khẩu thành công. Hãy đăng nhập lại.'
                    : null,
          ),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: ResetPasswordScreen(
            canResetPassword: _authRefreshListenable.isPasswordRecovery &&
                Supabase.instance.client.auth.currentSession != null,
          ),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const OnboardingWizardScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/storage',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const StorageAlbumScreen(),
        ),
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          barrierColor:
              const Color(0x66000000), // ~40% instant dark dimming backdrop
          barrierDismissible: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
          child: const PhotoScanBottomSheet(),
        ),
      ),
      GoRoute(
        path: '/scan-overlay',
        pageBuilder: (context, state) {
          final record = state.extra;
          if (record is! ScanResultRecord) {
            return NoTransitionPage(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(child: Text('Không tìm thấy kết quả quét.')),
              ),
            );
          }
          return NoTransitionPage(
            key: state.pageKey,
            child: ScanResultOverlayScreen(record: record),
          );
        },
      ),
      GoRoute(
        path: '/solo-arena',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SoloLobbyScreen(),
        ),
      ),
      GoRoute(
        path: '/pet-shop',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const PetShopScreen(),
        ),
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const FriendsLeaderboardScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
    ],
  );
}

class _SupabaseAuthRefreshListenable extends ChangeNotifier {
  _SupabaseAuthRefreshListenable(Stream<AuthState> authStateChanges) {
    _subscription = authStateChanges.listen(
      (state) {
        isPasswordRecovery = nextPasswordRecoveryState(
          current: isPasswordRecovery,
          event: state.event,
        );
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Supabase auth state error: $error');
      },
    );
  }

  late final StreamSubscription<AuthState> _subscription;
  bool isPasswordRecovery = false;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@visibleForTesting
bool nextPasswordRecoveryState({
  required bool current,
  required AuthChangeEvent event,
}) {
  if (event == AuthChangeEvent.passwordRecovery) return true;
  if (event == AuthChangeEvent.signedOut ||
      event == AuthChangeEvent.signedIn ||
      event == AuthChangeEvent.initialSession) {
    return false;
  }
  return current;
}
