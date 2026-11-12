import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_user_avatar.dart';
import '../../../../shared/widgets/gold_coin_icon.dart';
import '../../domain/weekly_yuzu_leaderboard.dart';
import '../../domain/yuzu_leaderboard_period.dart';
import 'laurel_avatar.dart';

typedef MiniLeaderboardEntry = WeeklyYuzuLeaderboardEntry;

class MiniLeaderboardPodium extends StatelessWidget {
  const MiniLeaderboardPodium({
    super.key,
    required this.entries,
    required this.onTap,
    this.ownerId,
    this.lastUpdatedAt,
    this.isOffline = false,
    this.period = YuzuLeaderboardPeriod.total,
    this.onPeriodChanged,
    this.isLoading = false,
    this.hasError = false,
  });

  final List<WeeklyYuzuLeaderboardEntry> entries;
  final String? ownerId;
  final DateTime? lastUpdatedAt;
  final bool isOffline;
  final VoidCallback onTap;
  final YuzuLeaderboardPeriod period;
  final ValueChanged<YuzuLeaderboardPeriod>? onPeriodChanged;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final ranked = [...entries]..sort((left, right) {
        final score = right.weeklyYuzu.compareTo(left.weeklyYuzu);
        if (score != 0) return score;
        if (left.userId == right.userId) return 0;
        if (left.userId == ownerId) return -1;
        if (right.userId == ownerId) return 1;
        return left.userId.compareTo(right.userId);
      });
    final topThree = ranked.take(3).toList(growable: false);
    final podiumEntries = <WeeklyYuzuLeaderboardEntry?>[
      topThree.length > 1 ? topThree[1] : null,
      topThree.isNotEmpty ? topThree[0] : null,
      topThree.length > 2 ? topThree[2] : null,
    ];
    const podiumPlaces = [2, 1, 3];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        return Semantics(
          button: true,
          label: 'Mở bảng xếp hạng bạn bè ${period.label.toLowerCase()}',
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('home-mini-leaderboard'),
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(26),
                  child: Ink(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.duoOrange,
                              size: compact ? 24 : 28,
                            ),
                            SizedBox(width: compact ? 5 : 8),
                            Expanded(
                              child: Text(
                                'Bảng Xếp Hạng Bạn Bè',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: compact
                                      ? 14
                                      : constraints.maxWidth < 500
                                          ? 18
                                          : 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * .28),
                              child: PopupMenuButton<YuzuLeaderboardPeriod>(
                                key: const Key(
                                    'home-leaderboard-period-selector'),
                                tooltip: 'Chọn thời gian xếp hạng',
                                position: PopupMenuPosition.under,
                                offset: const Offset(0, -8),
                                constraints: BoxConstraints.tightFor(
                                  width: compact ? 96 : 112,
                                ),
                                elevation: 2,
                                menuPadding: EdgeInsets.zero,
                                color: AppColors.softWhite,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                  side: BorderSide(
                                    color: AppColors.ink,
                                    width: 2,
                                  ),
                                ),
                                onSelected: onPeriodChanged,
                                itemBuilder: (_) => [
                                  for (final option
                                      in YuzuLeaderboardPeriod.values)
                                    PopupMenuItem(
                                      value: option,
                                      height: 40,
                                      padding: EdgeInsets.zero,
                                      child: Semantics(
                                        selected: option == period,
                                        child: Container(
                                          key: Key(
                                              'home-leaderboard-period-${option.name}'),
                                          width: double.infinity,
                                          constraints: const BoxConstraints(
                                            minHeight: 40,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          color: option == period
                                              ? AppColors.yellow
                                              : AppColors.softWhite,
                                          child: Text(
                                            option.label,
                                            style: TextStyle(
                                              color: AppColors.ink,
                                              fontSize: 12,
                                              fontWeight: option == period
                                                  ? FontWeight.w900
                                                  : FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 8 : 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.yellow,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.ink,
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: AppColors.ink,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GoldCoinIcon(size: compact ? 15 : 24),
                                        const SizedBox(width: 5),
                                        Text(
                                          period.label,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: AppColors.ink,
                                            fontSize: compact ? 11 : 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: compact ? 16 : 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (isOffline)
                          Text(
                            lastUpdatedAt == null
                                ? 'Đang offline · chưa có dữ liệu đã lưu'
                                : 'Đang offline · cập nhật lần cuối ${_formatTime(lastUpdatedAt!)}',
                            key: const Key('home-leaderboard-offline-label'),
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: compact ? 11 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else if (lastUpdatedAt != null)
                          Text(
                            'Cập nhật ${_formatTime(lastUpdatedAt!)}',
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: compact ? 11 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (topThree.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              isLoading
                                  ? 'Đang tải bảng xếp hạng…'
                                  : hasError
                                      ? 'Không tải được bảng xếp hạng. Hãy thử lại sau.'
                                      : 'Chưa có điểm ${period.label.toLowerCase()} đã xác nhận.',
                              key: const Key('home-leaderboard-empty'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.mutedInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var index = 0;
                                  index < podiumEntries.length;
                                  index++)
                                Expanded(
                                  flex: switch (podiumPlaces[index]) {
                                    1 => 24,
                                    2 => 21,
                                    _ => 19,
                                  },
                                  child: _LeaderboardPodiumPlace(
                                    entry: podiumEntries[index],
                                    ownerId: ownerId,
                                    place: podiumPlaces[index],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeaderboardPodiumPlace extends StatelessWidget {
  const _LeaderboardPodiumPlace({
    required this.entry,
    required this.ownerId,
    required this.place,
  });

  final WeeklyYuzuLeaderboardEntry? entry;
  final String? ownerId;
  final int place;

  @override
  Widget build(BuildContext context) {
    final currentEntry = entry;
    final isFirst = place == 1;
    final surface = isFirst
        ? AppColors.yellow
        : place == 2
            ? Color.lerp(AppColors.softWhite, AppColors.blue, .16)!
            : Color.lerp(AppColors.softWhite, AppColors.coral, .16)!;
    final displayName = currentEntry == null
        ? 'Chờ bạn'
        : currentEntry.userId == ownerId
            ? 'Bạn (${currentEntry.displayName})'
            : currentEntry.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 110;
          final avatarSize = switch (place) {
            1 => compact ? 32.0 : 40.0,
            2 => compact ? 30.0 : 32.0,
            _ => compact ? 26.0 : 28.0,
          };
          final badgeSize = switch (place) {
            1 => compact ? 30.0 : 40.0,
            2 => compact ? 28.0 : 32.0,
            _ => compact ? 24.0 : 28.0,
          };
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: EdgeInsets.only(top: compact ? 22 : 24),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    6,
                    isFirst ? (compact ? 14 : 12) : (place == 2 ? 9 : 7),
                    6,
                    isFirst ? 8 : (place == 2 ? 7 : 5),
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.ink, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height:
                            isFirst && !compact ? avatarSize * 1.5 : avatarSize,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (currentEntry != null || place == 3)
                              OverflowBox(
                                minWidth: avatarSize * 1.5,
                                maxWidth: avatarSize * 1.5,
                                minHeight: avatarSize * 1.5,
                                maxHeight: avatarSize * 1.5,
                                child: LaurelAvatar.rank(
                                  rank: place,
                                  size: avatarSize * 1.5,
                                  avatarRatio: 2 / 3,
                                  animate:
                                      !MediaQuery.disableAnimationsOf(context),
                                  child: currentEntry != null
                                      ? AppUserAvatar(
                                          avatarUrl: currentEntry.avatarUrl,
                                          size: avatarSize,
                                          backgroundColor: surface,
                                          borderWidth: 0,
                                        )
                                      : const ColoredBox(
                                          color: Color(0xFFE4E5E8),
                                          child: Icon(
                                            Icons.person_add_alt_1_rounded,
                                            color: Color(0xFF989CA3),
                                            size: 20,
                                          ),
                                        ),
                                ),
                              )
                            else
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE4E5E8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: const Color(0xFF989CA3),
                                  size: avatarSize * .7,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: isFirst ? 8 : 6),
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GoldCoinIcon(size: compact ? 20 : 22),
                            const SizedBox(width: 6),
                            Text(
                              '${currentEntry?.weeklyYuzu ?? 0}',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: compact ? 18 : 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: SizedBox(
                  width: badgeSize,
                  height: badgeSize,
                  child: CustomPaint(
                    painter: _RankBadgePainter(place: place),
                    child: Center(
                      child: Padding(
                        padding:
                            EdgeInsets.only(top: isFirst ? badgeSize * .2 : 0),
                        child: Text(
                          '$place',
                          key: Key('home-podium-rank-$place'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 16 : 20,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(
                                  color: Color(0xFFB46D16),
                                  offset: Offset(0, 1))
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isFirst && !compact) ...[
                const Positioned(
                  top: 8,
                  left: 28,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 20, color: Color(0xFFFFD34E)),
                ),
                const Positioned(
                  top: 14,
                  right: 18,
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 20, color: Color(0xFFFFD34E)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RankBadgePainter extends CustomPainter {
  const _RankBadgePainter({required this.place});
  final int place;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final crown = place == 1;
    final path = Path();
    if (crown) {
      path.moveTo(18, 83);
      path.lineTo(10, 31);
      path.quadraticBezierTo(9, 27, 14, 30);
      path.lineTo(31, 45);
      path.lineTo(48, 13);
      path.quadraticBezierTo(50, 9, 52, 13);
      path.lineTo(69, 45);
      path.lineTo(86, 30);
      path.quadraticBezierTo(91, 27, 90, 31);
      path.lineTo(82, 83);
      path.close();
    } else {
      path.moveTo(50, 5);
      path.lineTo(86, 24);
      path.quadraticBezierTo(92, 27, 92, 34);
      path.lineTo(92, 72);
      path.lineTo(50, 96);
      path.lineTo(8, 72);
      path.lineTo(8, 34);
      path.quadraticBezierTo(8, 27, 14, 24);
      path.close();
    }
    final colors = crown
        ? const [Color(0xFFFFE26A), Color(0xFFFFB51E)]
        : place == 2
            ? const [Color(0xFFE3EAFF), Color(0xFF819BD8)]
            : const [Color(0xFFF6D4BB), Color(0xFFC77A5A)];
    final outline = crown
        ? const Color(0xFFFF7E00)
        : place == 2
            ? const Color(0xFF8698D0)
            : const Color(0xFFB97251);
    canvas.drawShadow(path, Colors.black.withValues(alpha: .15), 3, false);
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors)
              .createShader(const Rect.fromLTWH(0, 0, 100, 100)));
    canvas.drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round);
    if (crown) {
      for (final tip in const [
        Offset(12, 28),
        Offset(50, 12),
        Offset(88, 28)
      ]) {
        canvas.drawCircle(tip, 6, Paint()..color = const Color(0xFFFFE26A));
        canvas.drawCircle(
            tip,
            6,
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(18, 80, 64, 10), const Radius.circular(3)),
          Paint()..color = const Color(0xFFFFBA25));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(18, 80, 64, 10), const Radius.circular(3)),
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    } else {
      canvas.save();
      canvas.translate(50, 50);
      canvas.scale(.8);
      canvas.translate(-50, -50);
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RankBadgePainter oldDelegate) =>
      oldDelegate.place != place;
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
