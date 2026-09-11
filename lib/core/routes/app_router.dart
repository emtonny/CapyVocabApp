import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

import '../../features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import '../../features/ai_scan/presentation/screens/photo_scan_bottom_sheet.dart';
import '../../features/ai_scan/presentation/screens/scan_result_overlay_screen.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/friends/presentation/screens/friends_leaderboard_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/storage_album_screen.dart';
import '../../features/onboarding/application/onboarding_status_store.dart';
import '../../features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import '../../features/pet_shop/presentation/screens/pet_shop_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/solo_arena/presentation/screens/solo_lobby_screen.dart';
import '../theme/app_theme.dart';

/// Ánh xạ routing tương đương activateView(viewId) trong bản HTML gốc.
class AppRouter {
  AppRouter({
    required String? Function() currentUserId,
    required Stream<String?> authUserIds,
    required OnboardingStatusStore onboardingStatusStore,
    Stream<AuthState>? authStates,
    String initialLocation = '/auth',
    List<RouteBase>? routes,
  }) {
    _refreshListenable = _RouterRefreshListenable(
      initialUserId: currentUserId(),
      authUserIds: authUserIds,
      authStates: authStates,
      onboardingStatusStore: onboardingStatusStore,
    );
    router = GoRouter(
      initialLocation: initialLocation,
      refreshListenable: _refreshListenable,
      redirect: (context, state) {
        final userId = currentUserId();
        final isOnAuthScreen = state.matchedLocation == '/auth';
        final isOnOnboardingScreen = state.matchedLocation == '/onboarding';
        final isOnResetPasswordScreen =
            state.matchedLocation == '/reset-password';

        if (_refreshListenable.isPasswordRecovery && userId != null) {
          return isOnResetPasswordScreen ? null : '/reset-password';
        }

        if (userId == null) {
          return isOnAuthScreen || isOnResetPasswordScreen ? null : '/auth';
        }

        final status = onboardingStatusStore.statusFor(userId);
        if (status == OnboardingStatus.incomplete) {
          return isOnOnboardingScreen ? null : '/onboarding';
        }

        // Unknown intentionally fails open so a persisted session can reach
        // local/offline features while the background refresh is unavailable.
        if (isOnAuthScreen || isOnOnboardingScreen || isOnResetPasswordScreen) {
          return '/home';
        }

        return null;
      },
      routes: routes ?? _buildAppRoutes(_refreshListenable),
    );
  }

  late final GoRouter router;
  late final _RouterRefreshListenable _refreshListenable;

  void dispose() {
    router.dispose();
    _refreshListenable.dispose();
  }
}

List<RouteBase> _buildAppRoutes(
  _RouterRefreshListenable refreshListenable,
) {
  return [
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => _softPage(
        state,
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
      pageBuilder: (context, state) => _softPage(
        state,
        child: ResetPasswordScreen(
          canResetPassword: refreshListenable.isPasswordRecovery,
        ),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const OnboardingWizardScreen(),
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/storage',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const StorageAlbumScreen(),
      ),
    ),
    GoRoute(
      path: '/storage/trash',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const LibraryTrashScreen(),
      ),
    ),
    GoRoute(
      path: '/storage/:photoNoteId',
      pageBuilder: (context, state) => _softPage(
        state,
        child: LibraryPhotoNoteDetailScreen(
          photoNoteId: state.pathParameters['photoNoteId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/scan',
      pageBuilder: (context, state) => _softPage(
        state,
        opaque: false,
        barrierColor: const Color(0x66000000), // ~40% dark dimming backdrop
        barrierDismissible: true,
        child: const PhotoScanBottomSheet(),
      ),
    ),
    GoRoute(
      path: '/scan-overlay',
      pageBuilder: (context, state) {
        final record = state.extra;
        if (record is! ScanResultRecord) {
          return _softPage(
            state,
            child: const Scaffold(
              body: Center(child: Text('Không tìm thấy kết quả quét.')),
            ),
          );
        }
        return _softPage(
          state,
          child: ScanResultOverlayScreen(record: record),
        );
      },
    ),
    GoRoute(
      path: '/solo-arena',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const SoloLobbyScreen(),
      ),
    ),
    GoRoute(
      path: '/pet-shop',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const PetShopScreen(),
      ),
    ),
    GoRoute(
      path: '/friends',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const FriendsLeaderboardScreen(),
      ),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _softPage(
        state,
        child: const SettingsScreen(),
      ),
    ),
  ];
}

CustomTransitionPage<void> _softPage(
  GoRouterState state, {
  required Widget child,
  bool opaque = true,
  Color? barrierColor,
  bool barrierDismissible = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: softPageTransitionDuration,
    reverseTransitionDuration: softPageReverseTransitionDuration,
    opaque: opaque,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
    transitionsBuilder: buildSoftPageTransition,
    child: child,
  );
}

class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable({
    required String? initialUserId,
    required Stream<String?> authUserIds,
    required OnboardingStatusStore onboardingStatusStore,
    Stream<AuthState>? authStates,
  })  : _userId = initialUserId,
        _onboardingStatusStore = onboardingStatusStore {
    _onboardingStatusStore.addListener(_onStatusChanged);
    _authUserSubscription = authUserIds.distinct().listen(
      (userId) {
        if (_userId == userId) return;
        _userId = userId;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Supabase auth state error: $error');
      },
    );
    _authStateSubscription = authStates?.listen(
      (state) {
        final next = nextPasswordRecoveryState(
          current: isPasswordRecovery,
          event: state.event,
        );
        if (next == isPasswordRecovery) return;
        isPasswordRecovery = next;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Supabase recovery state error: $error');
      },
    );
  }

  final OnboardingStatusStore _onboardingStatusStore;
  late final StreamSubscription<String?> _authUserSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  String? _userId;
  bool isPasswordRecovery = false;

  void _onStatusChanged() => notifyListeners();

  @override
  void dispose() {
    _onboardingStatusStore.removeListener(_onStatusChanged);
    unawaited(_authUserSubscription.cancel());
    final authStateSubscription = _authStateSubscription;
    if (authStateSubscription != null) {
      unawaited(authStateSubscription.cancel());
    }
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
