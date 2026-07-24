import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_wizard_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/ai_scan/presentation/screens/storage_album_screen.dart';
import '../../features/solo_arena/presentation/screens/solo_lobby_screen.dart';
import '../../features/pet_shop/presentation/screens/pet_shop_screen.dart';
import '../../features/friends/presentation/screens/friends_leaderboard_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Ánh xạ routing tương đương activateView(viewId) trong bản HTML gốc.
class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWizardScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/storage',
        builder: (context, state) => const StorageAlbumScreen(),
      ),
      GoRoute(
        path: '/solo-arena',
        builder: (context, state) => const SoloLobbyScreen(),
      ),
      GoRoute(
        path: '/pet-shop',
        builder: (context, state) => const PetShopScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsLeaderboardScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
