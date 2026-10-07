import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../providers/home_provider.dart';
import '../providers/weekly_yuzu_leaderboard_provider.dart';
import '../../../mini_games/presentation/providers/lesson_session_provider.dart';
import '../widgets/lesson_map_winding_path.dart';
import '../widgets/mini_leaderboard_podium.dart';
import '../widgets/streak_flame_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeProvider);
    final state = dashboard.asData?.value;
    final leaderboard = ref.watch(weeklyYuzuLeaderboardProvider).asData?.value;
    final unread =
        ref.watch(homeUnreadNotificationsProvider).asData?.value ?? 0;
    final localPendingYuzu = state == null
        ? 0
        : ref.watch(lessonPendingYuzuProvider(state.userId)).valueOrNull ?? 0;
    final pendingYuzu = state == null
        ? localPendingYuzu
        : (state.pendingYuzu > localPendingYuzu
            ? state.pendingYuzu
            : localPendingYuzu);

    return GraphPaperScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('home-scroll-view'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'HomeScreen',
                style: TextStyle(fontSize: 0, color: Colors.transparent),
              ),
              _HomeTopBar(
                balance: state?.yuzuBalance,
                pendingYuzu: pendingYuzu,
                unreadNotifications: unread,
              ),
              const SizedBox(height: 22),
              Text(
                state == null ? 'Chào bạn!' : 'Chào ${state.displayName}!',
                key: const Key('home-greeting'),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontFamily: 'Nunito',
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mỗi ngày một Photo Note, mỗi ngày thêm một bước tiến.',
                style: TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (state?.isOffline == true) ...[
                const SizedBox(height: 14),
                _OfflineNotice(updatedAt: state!.updatedAt),
              ],
              if (dashboard.hasError && state == null) ...[
                const SizedBox(height: 14),
                _HomeLoadError(
                  onRetry: () => ref.invalidate(homeProvider),
                ),
              ],
              if (dashboard.isLoading && state == null) ...[
                const SizedBox(height: 28),
                const Center(
                  child: CircularProgressIndicator(
                    key: Key('home-loading'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const LessonMapWindingPath(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final streak = StreakFlameWidget(
                    streakDays: state?.streakDays ?? 0,
                    waitingForSync: pendingYuzu > 0,
                  );
                  final leaderboardCard = MiniLeaderboardPodium(
                    entries: leaderboard?.entries ?? const [],
                    lastUpdatedAt: leaderboard?.updatedAt,
                    isOffline:
                        leaderboard?.isOffline ?? (state?.isOffline ?? false),
                    onTap: () => context.go('/friends'),
                  );
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        streak,
                        const SizedBox(height: 16),
                        leaderboardCard,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: streak),
                      const SizedBox(width: 16),
                      Expanded(child: leaderboardCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.balance,
    required this.pendingYuzu,
    required this.unreadNotifications,
  });

  final int? balance;
  final int pendingYuzu;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            key: const Key('home-yuzu-balance'),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.ink, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🍊', style: TextStyle(fontSize: 23)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        balance == null ? '— Yuzu' : '$balance Yuzu',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (pendingYuzu > 0)
                        Text(
                          '$pendingYuzu đang chờ đồng bộ',
                          key: const Key('home-pending-yuzu'),
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _NotificationButton(unread: unreadNotifications),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: 48,
          child: StickerButton(
            key: const Key('home-settings-button'),
            onPressed: () => context.push('/settings'),
            semanticLabel: 'Cài đặt',
            icon: const Icon(Icons.settings_rounded, size: 24),
            radius: 14,
            padding: EdgeInsets.zero,
            expand: true,
          ),
        ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox.square(
          dimension: 48,
          child: StickerButton(
            key: const Key('home-notification-button'),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Trung tâm thông báo đang được hoàn thiện.'),
              ),
            ),
            semanticLabel: unread == 0
                ? 'Thông báo, không có thông báo chưa đọc'
                : 'Thông báo, $unread thông báo chưa đọc',
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
            surfaceColor: AppColors.softWhite,
            radius: 14,
            padding: EdgeInsets.zero,
            expand: true,
          ),
        ),
        if (unread > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              key: const Key('home-unread-badge'),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-offline-notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(
        'Đang offline · dữ liệu Home cập nhật lần cuối ${_formatTime(updatedAt)}',
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HomeLoadError extends StatelessWidget {
  const _HomeLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-load-error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Chưa tải được dữ liệu Home.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
