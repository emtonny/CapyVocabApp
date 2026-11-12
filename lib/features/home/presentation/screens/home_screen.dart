import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_user_avatar.dart';
import '../../../../shared/widgets/gold_coin_icon.dart';
import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../../../settings/presentation/providers/current_user_profile_provider.dart';
import '../providers/home_provider.dart';
import '../providers/streak_flame_provider.dart';
import '../providers/period_yuzu_leaderboard_provider.dart';
import '../../../mini_games/presentation/providers/lesson_session_provider.dart';
import '../widgets/lesson_map_winding_path.dart';
import '../widgets/mini_leaderboard_podium.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeProvider);
    final state = dashboard.asData?.value;
    final flameAction = ref.watch(streakFlameProvider);
    final confirmedFlame = flameAction.valueOrNull;
    final streakDays = confirmedFlame != null &&
            confirmedFlame.ownerId == state?.userId &&
            !confirmedFlame.updatedAt.isBefore(state!.updatedAt)
        ? confirmedFlame.streakDays
        : state?.streakDays ?? 0;
    final period = ref.watch(selectedLeaderboardPeriodProvider);
    final ranking = ref.watch(periodYuzuLeaderboardProvider(period));
    final leaderboard = ranking.asData?.value;
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
          // GraphPaperScaffold overlays the navigation on the scroll viewport.
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            BottomNavBar.contentHeight + 32,
          ),
          child: Center(
            child: SizedBox(
              width: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'HomeScreen',
                    style: TextStyle(fontSize: 0, color: Colors.transparent),
                  ),
                  _HomeTopBar(
                    unreadNotifications: unread,
                  ),
                  const SizedBox(height: 12),
                  _HomeWelcomeCard(
                    displayName: state?.displayName,
                    avatarUrl: ref
                        .watch(currentUserProfileProvider)
                        .valueOrNull
                        ?.avatarUrl,
                    balance: state?.yuzuBalance,
                    pendingYuzu: pendingYuzu,
                    streakDays: streakDays,
                    onLightFlame: state == null || flameAction.isLoading
                        ? null
                        : () => _lightFlame(context, ref),
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
                  MiniLeaderboardPodium(
                    entries: leaderboard?.entries ?? const [],
                    period: period,
                    onPeriodChanged: (value) => ref
                        .read(selectedLeaderboardPeriodProvider.notifier)
                        .state = value,
                    isLoading: ranking.isLoading,
                    hasError: ranking.hasError,
                    ownerId: state?.userId,
                    lastUpdatedAt: leaderboard?.updatedAt,
                    isOffline: state?.isOffline ?? false,
                    onTap: () => context.go('/friends'),
                  ),
                  const SizedBox(height: 20),
                  const LessonMapWindingPath(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

Future<void> _lightFlame(BuildContext context, WidgetRef ref) async {
  try {
    final result = await ref.read(streakFlameProvider.notifier).light();
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.incremented
          ? 'Đã thắp lửa! Chuỗi học: ${result.streakDays} ngày.'
          : 'Hôm nay bạn đã thắp lửa hoặc hoàn thành bài học rồi.'),
    ));
  } catch (error) {
    if (!context.mounted) return;
    final missingBackend =
        error is PostgrestException && error.code == 'PGRST202';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(missingBackend
          ? 'Tính năng thắp lửa chưa được cập nhật trên máy chủ. Vui lòng thử lại sau.'
          : 'Chưa thắp lửa được. Kiểm tra kết nối và thử lại.'),
    ));
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.unreadNotifications,
  });

  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Trang chủ',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
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

class _HomeWelcomeCard extends StatelessWidget {
  const _HomeWelcomeCard({
    required this.displayName,
    required this.avatarUrl,
    required this.balance,
    required this.pendingYuzu,
    required this.streakDays,
    required this.onLightFlame,
  });

  final String? displayName;
  final String? avatarUrl;
  final int? balance;
  final int pendingYuzu;
  final int streakDays;
  final VoidCallback? onLightFlame;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-welcome-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
          final balanceBadge = _CoinBalanceBadge(
            balance: balance,
            pendingYuzu: pendingYuzu,
            compact: compact,
          );
          final streakBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Color.lerp(AppColors.softWhite, AppColors.coral, .16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                _BobbingFlameIcon(
                  key: const Key('home-streak-flame'),
                  size: compact ? 30 : 36,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: 'Chuỗi $streakDays ngày'
                        '${pendingYuzu > 0 ? ', đang chờ đồng bộ' : ''}',
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '$streakDays ',
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const TextSpan(
                          text: 'ngày học liên tục',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ]),
                      key: const Key('home-streak-summary'),
                    ),
                  ),
                ),
              ],
            ),
          );
          final button = _LightTheFlameButton(
            width: largeText ? constraints.maxWidth : constraints.maxWidth * .4,
            compact: compact,
            onPressed: onLightFlame,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppUserAvatar(
                    key: const Key('home-welcome-avatar'),
                    avatarUrl: avatarUrl,
                    size: compact ? 48 : 80,
                    backgroundColor: AppColors.paleGold,
                    borderWidth: 2.5,
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: _HomeGreeting(
                      displayName: displayName,
                      compact: compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: compact || largeText
                        ? constraints.maxWidth * .43
                        : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: balanceBadge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (largeText) ...[
                streakBadge,
                const SizedBox(height: 12),
                button,
              ] else
                Row(
                  children: [
                    Expanded(child: streakBadge),
                    const SizedBox(width: 10),
                    button,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({
    required this.displayName,
    required this.compact,
  });

  final String? displayName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Chào ${displayName?.trim().isNotEmpty == true ? displayName : 'bạn'}!',
            key: const Key('home-greeting'),
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.ink,
              fontFamily: 'Nunito',
              fontSize: compact ? 17 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 4),
          ExcludeSemantics(
            child: Icon(
              Icons.waving_hand_rounded,
              color: const Color(0xFFFFA51F),
              size: compact ? 20 : 25,
            ),
          ),
        ],
      ],
    );
  }
}

class _CoinBalanceBadge extends StatelessWidget {
  const _CoinBalanceBadge({
    required this.balance,
    required this.pendingYuzu,
    this.compact = false,
  });

  final int? balance;
  final int pendingYuzu;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-coin-balance'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GoldCoinIcon(size: compact ? 16 : 24),
          SizedBox(width: compact ? 5 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                balance == null ? '— xu vàng' : '$balance xu vàng',
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: compact ? 12 : 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (pendingYuzu > 0)
                Text(
                  '$pendingYuzu xu vàng đang chờ đồng bộ',
                  key: const Key('home-pending-yuzu'),
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 24),
          ],
        ],
      ),
    );
  }
}

class _LightTheFlameButton extends StatelessWidget {
  const _LightTheFlameButton({
    required this.width,
    required this.compact,
    required this.onPressed,
  });

  final double width;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('home-light-the-flame-button'),
      width: width,
      height: compact ? 48 : 58,
      child: StickerButton(
        label: 'Thắp lửa',
        onPressed: onPressed,
        surfaceColor: AppColors.duoGreen,
        textColor: Colors.white,
        borderColor: AppColors.ink,
        edgeColor: const Color(0xFF46A302),
        showShadow: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        fontSize: compact ? 14 : 16,
        radius: 999,
        expand: true,
      ),
    );
  }
}

class _BobbingFlameIcon extends StatefulWidget {
  const _BobbingFlameIcon({
    super.key,
    required this.size,
  });

  final double size;

  @override
  State<_BobbingFlameIcon> createState() => _BobbingFlameIconState();
}

class _BobbingFlameIconState extends State<_BobbingFlameIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lửa chuỗi học',
      child: AnimatedBuilder(
        animation: _controller,
        child: Image.asset(
          'assets/images/fluent_fire_3d.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        builder: (context, child) {
          if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
            return child!;
          }
          final offset = 1.5 - (_controller.value * 3);
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
      ),
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
