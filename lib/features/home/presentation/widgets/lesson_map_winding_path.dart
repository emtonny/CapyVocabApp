import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../mini_games/application/lesson_session_controller.dart';
import '../../../mini_games/domain/lesson_session.dart';
import '../../../mini_games/presentation/providers/lesson_session_provider.dart';
import '../../../mini_games/presentation/providers/lesson_completion_sync_provider.dart';
import '../../domain/daily_mission.dart';
import '../providers/daily_lesson_provider.dart';
import '../providers/daily_mission_provider.dart';

class LessonMapWindingPath extends ConsumerWidget {
  const LessonMapWindingPath({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(homeDailyLessonProvider);
    final currentMission = ref.watch(currentDailyMissionProvider);
    final userId = currentMission?.userId;
    return lesson.when(
      loading: () => const _LessonMapShell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(
              key: Key('home-daily-lesson-loading'),
            ),
          ),
        ),
      ),
      error: (error, _) => _LessonMapShell(
        child: _LessonLoadError(
          onRetry: () => ref.invalidate(homeDailyLessonProvider),
        ),
      ),
      data: (overview) {
        final sessionKey = userId == null
            ? null
            : (
                userId: userId,
                missionDate: overview.todayNode.day,
              );
        final dailySession = sessionKey == null
            ? null
            : ref.watch(dailyLessonSessionProvider(sessionKey)).asData?.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DailyTaskCard(
              node: overview.todayNode,
              session: dailySession,
              onPressed: () => _openNode(
                context,
                overview.todayNode,
                ref: ref,
                userId: userId,
                currentMission: currentMission,
                isToday: true,
              ),
              onRetake: () => context.push('/scan'),
              onChooseSameDay: () => _openSameDayLibrary(
                context,
                overview.todayNode,
              ),
            ),
            const SizedBox(height: 16),
            _LessonMapShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Bản đồ học tập',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _PeriodToggle(
                        selected: overview.selection.period,
                        onSelected: (period) => ref
                            .read(homeLessonMapPeriodProvider.notifier)
                            .setPeriod(period),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _periodLabel(overview.selection),
                    key: const Key('home-lesson-map-period-label'),
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PeriodNavigation(
                    selection: overview.selection,
                    isCurrent: overview.selection.contains(overview.today),
                    onPrevious: () => ref
                        .read(homeLessonMapAnchorProvider.notifier)
                        .shift(overview.selection, -1),
                    onToday: () => ref
                        .read(homeLessonMapAnchorProvider.notifier)
                        .goToday(),
                    onNext: () => ref
                        .read(homeLessonMapAnchorProvider.notifier)
                        .shift(overview.selection, 1),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          overview.selection.period == LessonMapPeriod.week
                              ? (constraints.maxWidth >= 640 ? 7 : 4)
                              : (constraints.maxWidth >= 640 ? 7 : 5);
                      return GridView.count(
                        key: const Key('home-lesson-map-grid'),
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        childAspectRatio:
                            overview.selection.period == LessonMapPeriod.week
                                ? 0.7
                                : 0.55,
                        children: [
                          for (final node in overview.nodes)
                            _LessonNode(
                              node: node,
                              isToday: _sameDay(node.day, overview.today),
                              onTap: () => _openNode(
                                context,
                                node,
                                ref: ref,
                                userId: userId,
                                currentMission: currentMission,
                                isToday: _sameDay(node.day, overview.today),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  const _MapLegend(),
                  if (overview.usesDeviceTimeZoneFallback) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Ngày học đang tạm theo múi giờ trên thiết bị. Ảnh luôn '
                      'được xếp theo thời điểm chụp, không theo lúc xử lý xong.',
                      key: Key('home-timezone-fallback-note'),
                      style: TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DailyTaskCard extends StatelessWidget {
  const _DailyTaskCard({
    required this.node,
    required this.session,
    required this.onPressed,
    required this.onRetake,
    required this.onChooseSameDay,
  });

  final DailyLessonNode node;
  final LessonSession? session;
  final VoidCallback onPressed;
  final VoidCallback onRetake;
  final VoidCallback onChooseSameDay;

  @override
  Widget build(BuildContext context) {
    final status = _taskStatusPresentation(node, session);
    return Container(
      key: const Key('home-daily-task-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _lightSurface(status.color),
        borderRadius: BorderRadius.circular(18),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text(
                'Nhiệm vụ hôm nay',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _StatusPill(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${node.validWords}/${node.targetWords} từ hợp lệ',
            key: const Key('home-valid-word-count'),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            key: const Key('home-daily-task-progress'),
            value: node.targetWords == 0
                ? 0
                : (node.validWords / node.targetWords).clamp(0, 1),
            minHeight: 9,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.softWhite,
            color: status.color,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Mục tiêu: ${node.targetWords} từ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'Còn thiếu: ${node.missingWords} từ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if ((session?.mastery.completedCount ?? node.correctWords) > 0)
                Text(
                  'Bài học: ${session?.mastery.completedCount ?? node.correctWords}/'
                  '${session?.mastery.totalCount ?? node.validWords}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            node.projectedYuzu == 0
                ? 'Đạt mục tiêu để mở thưởng nhiệm vụ ngày.'
                : 'Phần thưởng dự kiến: ${node.projectedYuzu} Yuzu',
            key: const Key('home-projected-yuzu'),
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (node.exclusionReasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Chưa được tính:',
              style: TextStyle(
                color: AppColors.mutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            for (final reason in node.exclusionReasons.entries)
              Text(
                '• ${_reasonLabel(reason.key)}: ${reason.value}',
                style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          if (node.hasSystemPending) ...[
            const SizedBox(height: 8),
            const Text(
              'Ảnh đang xử lý không làm bạn bị phạt.',
              key: Key('home-pending-processing-note'),
              style: TextStyle(
                color: AppColors.mutedInk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('home-daily-task-action'),
            onPressed: onPressed,
            icon: Icon(status.icon),
            label: Text(_actionLabel(node, session)),
            style: FilledButton.styleFrom(
              backgroundColor: status.color,
              foregroundColor: AppColors.ink,
              disabledBackgroundColor: AppColors.mutedInk.withValues(alpha: .2),
              disabledForegroundColor: AppColors.mutedInk,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: const BorderSide(color: AppColors.ink, width: 2),
              ),
            ),
          ),
          if (node.status == DailyLessonStatus.noData &&
              node.photoCount > 0) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final actions = [
                  if (node.canRetake)
                    OutlinedButton.icon(
                      key: const Key('home-retake-photo-action'),
                      onPressed: onRetake,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Chụp lại ảnh lỗi'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('home-choose-same-day-action'),
                    onPressed: onChooseSameDay,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh cùng ngày'),
                  ),
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in actions)
                      SizedBox(
                        width: constraints.maxWidth < 430
                            ? constraints.maxWidth
                            : null,
                        height: 48,
                        child: action,
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodNavigation extends StatelessWidget {
  const _PeriodNavigation({
    required this.selection,
    required this.isCurrent,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final HomeLessonMapSelection selection;
  final bool isCurrent;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          key: const Key('home-lesson-period-previous'),
          tooltip: 'Kỳ trước',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const Key('home-lesson-period-today'),
            onPressed: isCurrent ? null : onToday,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              isCurrent ? 'Đang ở hôm nay' : 'Về hôm nay',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          key: const Key('home-lesson-period-next'),
          tooltip: 'Kỳ sau',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ],
    );
  }
}

class _LessonMapShell extends StatelessWidget {
  const _LessonMapShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.selected, required this.onSelected});

  final LessonMapPeriod selected;
  final ValueChanged<LessonMapPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LessonMapPeriod>(
      key: const Key('home-lesson-period-toggle'),
      segments: const [
        ButtonSegment(value: LessonMapPeriod.week, label: Text('Tuần')),
        ButtonSegment(value: LessonMapPeriod.month, label: Text('Tháng')),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onSelected(values.single),
      style: ButtonStyle(
        visualDensity: const VisualDensity(vertical: -2),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.softWhite
              : AppColors.ink,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.darkGreen
              : AppColors.softWhite,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.ink, width: 1.5),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _LessonNode extends StatelessWidget {
  const _LessonNode({
    required this.node,
    required this.isToday,
    required this.onTap,
  });

  final DailyLessonNode node;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(node.status);
    return Semantics(
      button: true,
      label: '${_dateLabel(node.day)}, ${status.label}, '
          '${node.validWords}/${node.targetWords} từ',
      child: InkWell(
        key: Key('home-lesson-node-${_dayKey(node.day)}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: _lightSurface(status.color),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.ink,
              width: isToday ? 3 : 1.5,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, color: AppColors.ink, size: 22),
                const SizedBox(height: 3),
                Text(
                  '${node.day.day}/${node.day.month}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${node.validWords}/${node.targetWords}',
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 5,
      children: [
        for (final status in DailyLessonStatus.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _statusPresentation(status).icon,
                size: 13,
                color: AppColors.mutedInk,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  _statusPresentation(status).label,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _LessonLoadError extends StatelessWidget {
  const _LessonLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-daily-lesson-error'),
      children: [
        const Text(
          'Chưa đọc được Photo Note trên máy.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    );
  }
}

Future<void> _openNode(
  BuildContext context,
  DailyLessonNode node, {
  required WidgetRef ref,
  required String? userId,
  required DailyMission? currentMission,
  required bool isToday,
}) async {
  switch (node.status) {
    case DailyLessonStatus.noData:
      if (isToday) {
        context.push('/scan');
      } else {
        _showMessage(context, 'Chỉ có thể bổ sung ảnh cho nhiệm vụ hôm nay.');
      }
    case DailyLessonStatus.ready:
    case DailyLessonStatus.inProgress:
      if (userId == null) {
        _showMessage(context, 'Cần đăng nhập để mở bài học.');
        return;
      }
      final mission = currentMission;
      if (mission == null || mission.day != node.day) {
        _showMessage(
          context,
          'Nhiệm vụ ngày chưa sẵn sàng. Hãy thử lại sau ít giây.',
        );
        return;
      }
      final key = (userId: userId, missionDate: node.day);
      await context.push(
        '/lesson',
        extra: DailyLessonStartRequest(
          userId: userId,
          missionDate: node.day,
          photoNoteIds: node.photoNoteIds,
          targetWords: node.targetWords,
          ruleVersion: 'h3-rules-v1',
          startsAt: mission.startsAt,
          endsAt: mission.endsAt,
          nextDayEndsAt: mission.nextDayEndsAt,
          now: DateTime.now().toUtc(),
        ),
      );
      ref.invalidate(dailyLessonSessionProvider(key));
      ref.invalidate(homeDailyLessonProvider);
    case DailyLessonStatus.pendingSync:
      _showMessage(
        context,
        'Kết quả đã được lưu trên máy và sẽ tự đồng bộ khi có mạng.',
      );
    case DailyLessonStatus.syncFailed:
      final resultId = node.completionResultId;
      if (userId == null || resultId == null) {
        _showMessage(context, 'Chưa tìm thấy kết quả để thử đồng bộ lại.');
        return;
      }
      try {
        await retryLessonCompletionSync(
          ref,
          userId: userId,
          resultId: resultId,
        );
        if (context.mounted) {
          _showMessage(context, 'Đã đưa kết quả vào hàng đợi đồng bộ lại.');
        }
      } catch (_) {
        if (context.mounted) {
          _showMessage(
              context, 'Chưa thể thử lại. Kết quả vẫn được giữ trên máy.');
        }
      }
    case DailyLessonStatus.completed:
      if (userId != null) {
        final key = (userId: userId, missionDate: node.day);
        await context.push(
          '/lesson',
          extra: RewardedReplayLessonStartRequest(
            userId: userId,
            missionDate: node.day,
            targetWords: node.targetWords,
            now: DateTime.now().toUtc(),
          ),
        );
        ref.invalidate(dailyLessonSessionProvider(key));
        ref.invalidate(homeDailyLessonProvider);
      } else {
        _showMessage(context, 'Cần đăng nhập để mở lại bài học.');
      }
    case DailyLessonStatus.expired:
      if (node.photoNoteIds.isNotEmpty) {
        context.push('/storage/${node.photoNoteIds.first}');
      } else {
        _showMessage(context, 'Ngày này chưa có Photo Note để mở lại.');
      }
  }
}

void _openSameDayLibrary(BuildContext context, DailyLessonNode node) {
  context.push(
    Uri(
      path: '/storage',
      queryParameters: {
        'from': '${node.startsAt.millisecondsSinceEpoch}',
        'to': '${node.endsAt.millisecondsSinceEpoch}',
      },
    ).toString(),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _actionLabel(DailyLessonNode node, LessonSession? session) {
  if (node.status == DailyLessonStatus.pendingSync) {
    return 'Đang chờ đồng bộ';
  }
  if (node.status == DailyLessonStatus.syncFailed) {
    return 'Thử đồng bộ lại';
  }
  if (session != null) {
    switch (session.status) {
      case LessonSessionStatus.active:
      case LessonSessionStatus.paused:
        return 'Tiếp tục bài học ${session.mastery.completedCount}/'
            '${session.mastery.totalCount}';
      case LessonSessionStatus.blocked:
        return 'Xem bài học bị chặn';
      case LessonSessionStatus.completed:
        return node.status == DailyLessonStatus.completed
            ? 'Chơi lại · thưởng 1/3'
            : 'Xem kết quả 100%';
      case LessonSessionStatus.abandoned:
        return 'Xem bài đã bỏ';
      case LessonSessionStatus.expired:
        return 'Xem nhiệm vụ hết hạn';
    }
  }
  switch (node.status) {
    case DailyLessonStatus.noData:
      return 'Chụp thêm ảnh';
    case DailyLessonStatus.ready:
      return 'Bắt đầu bài học';
    case DailyLessonStatus.inProgress:
      return 'Tiếp tục bài học ${node.correctWords}/${node.validWords}';
    case DailyLessonStatus.pendingSync:
      return 'Đang chờ đồng bộ';
    case DailyLessonStatus.syncFailed:
      return 'Thử đồng bộ lại';
    case DailyLessonStatus.completed:
    case DailyLessonStatus.expired:
      return 'Chơi lại';
  }
}

_StatusPresentation _taskStatusPresentation(
  DailyLessonNode node,
  LessonSession? session,
) {
  if (session == null) return _statusPresentation(node.status);
  if (session.status == LessonSessionStatus.completed &&
      {
        DailyLessonStatus.pendingSync,
        DailyLessonStatus.syncFailed,
        DailyLessonStatus.completed,
      }.contains(node.status)) {
    return _statusPresentation(node.status);
  }
  return switch (session.status) {
    LessonSessionStatus.active ||
    LessonSessionStatus.paused =>
      const _StatusPresentation(
        'Đang học',
        AppColors.blue,
        Icons.play_circle_outline,
      ),
    LessonSessionStatus.blocked => const _StatusPresentation(
        'Thiếu ảnh nguồn',
        AppColors.yellow,
        Icons.broken_image_outlined,
      ),
    LessonSessionStatus.completed => const _StatusPresentation(
        'Hoàn thành',
        AppColors.mint,
        Icons.check_circle_outline,
      ),
    LessonSessionStatus.abandoned => const _StatusPresentation(
        'Đã bỏ bài',
        AppColors.yellow,
        Icons.flag_outlined,
      ),
    LessonSessionStatus.expired => const _StatusPresentation(
        'Hết hạn',
        AppColors.mutedInk,
        Icons.event_busy_outlined,
      ),
  };
}

_StatusPresentation _statusPresentation(DailyLessonStatus status) {
  switch (status) {
    case DailyLessonStatus.noData:
      return const _StatusPresentation(
        'Chưa đủ dữ liệu',
        AppColors.yellow,
        Icons.add_a_photo_outlined,
      );
    case DailyLessonStatus.ready:
      return const _StatusPresentation(
        'Sẵn sàng học',
        AppColors.mint,
        Icons.play_arrow_rounded,
      );
    case DailyLessonStatus.inProgress:
      return const _StatusPresentation(
        'Đang học',
        AppColors.blue,
        Icons.school_outlined,
      );
    case DailyLessonStatus.pendingSync:
      return const _StatusPresentation(
        'Chờ đồng bộ',
        AppColors.yellow,
        Icons.cloud_upload_outlined,
      );
    case DailyLessonStatus.syncFailed:
      return const _StatusPresentation(
        'Đồng bộ lỗi',
        AppColors.coral,
        Icons.sync_problem_rounded,
      );
    case DailyLessonStatus.completed:
      return const _StatusPresentation(
        'Đã hoàn thành',
        AppColors.mint,
        Icons.check_circle_outline_rounded,
      );
    case DailyLessonStatus.expired:
      return const _StatusPresentation(
        'Đã quá hạn',
        AppColors.coral,
        Icons.history_rounded,
      );
  }
}

String _reasonLabel(DailyLessonExclusionReason reason) {
  switch (reason) {
    case DailyLessonExclusionReason.duplicate:
      return 'Từ bị trùng';
    case DailyLessonExclusionReason.blurryImage:
      return 'Ảnh mờ';
    case DailyLessonExclusionReason.notRecognized:
      return 'Không nhận diện được';
    case DailyLessonExclusionReason.wrongLearningLanguage:
      return 'Không đúng ngôn ngữ đang học';
    case DailyLessonExclusionReason.pendingProcessing:
      return 'Ảnh vẫn đang xử lý';
  }
}

String _periodLabel(HomeLessonMapSelection selection) {
  final start = selection.startDay;
  final end = selection.endDayExclusive.subtract(const Duration(days: 1));
  if (selection.period == LessonMapPeriod.month) {
    return 'Tháng ${start.month}/${start.year}';
  }
  return '${start.day}/${start.month} – ${end.day}/${end.month}/${end.year}';
}

String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

Color _lightSurface(Color accent) => Color.alphaBlend(
      accent.withValues(alpha: 0.22),
      AppColors.softWhite,
    );

class _StatusPresentation {
  const _StatusPresentation(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}
