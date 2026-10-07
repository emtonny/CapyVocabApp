import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/weekly_yuzu_leaderboard.dart';

typedef MiniLeaderboardEntry = WeeklyYuzuLeaderboardEntry;

class MiniLeaderboardPodium extends StatelessWidget {
  const MiniLeaderboardPodium({
    super.key,
    required this.entries,
    required this.onTap,
    this.lastUpdatedAt,
    this.isOffline = false,
  });

  final List<WeeklyYuzuLeaderboardEntry> entries;
  final DateTime? lastUpdatedAt;
  final bool isOffline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ranked = [...entries]..sort((left, right) {
        final rank = left.rankPosition.compareTo(right.rankPosition);
        return rank != 0 ? rank : left.userId.compareTo(right.userId);
      });
    final topThree = ranked.take(3).toList(growable: false);

    return Semantics(
      button: true,
      label: 'Mở bảng xếp hạng bạn bè',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-mini-leaderboard'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.ink, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 25)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Bạn bè tuần này',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: 10),
                if (isOffline)
                  Text(
                    lastUpdatedAt == null
                        ? 'Đang offline · chưa có dữ liệu đã lưu'
                        : 'Đang offline · cập nhật lần cuối ${_formatTime(lastUpdatedAt!)}',
                    key: const Key('home-leaderboard-offline-label'),
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (lastUpdatedAt != null)
                  Text(
                    'Cập nhật ${_formatTime(lastUpdatedAt!)}',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (isOffline || lastUpdatedAt != null)
                  const SizedBox(height: 10),
                const Text(
                  'Yuzu tuần chỉ tính thưởng nhiệm vụ lần đầu đã xác nhận; '
                  'thưởng chơi lại chỉ vào ví.',
                  key: Key('home-leaderboard-score-explanation'),
                  style: TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (topThree.isEmpty)
                  const Text(
                    'Chưa có điểm tuần đã xác nhận.',
                    key: Key('home-leaderboard-empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  for (var index = 0; index < topThree.length; index++)
                    _LeaderboardRow(
                      entry: topThree[index],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final WeeklyYuzuLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('home-leaderboard-${entry.userId}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rankPosition}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _LeaderboardAvatar(entry: entry),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${entry.weeklyYuzu} Yuzu',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  const _LeaderboardAvatar({required this.entry});

  final WeeklyYuzuLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final initial = entry.displayName.characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
    final avatarUrl = entry.avatarUrl?.trim();
    return Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.yellow.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? fallback
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
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
