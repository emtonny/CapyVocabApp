import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../providers/daily_lesson_provider.dart';
import 'learning_map_scenery.dart';

/// Most recent captured account days appear at the top of the route.
class LessonRouteMap extends StatelessWidget {
  const LessonRouteMap({
    super.key,
    required this.nodes,
    required this.today,
    required this.onOpen,
    this.includeFutureDays = false,
    this.showDates = false,
  });

  final List<DailyLessonNode> nodes;
  final DateTime today;
  final ValueChanged<DailyLessonNode> onOpen;
  final bool includeFutureDays;
  final bool showDates;

  @override
  Widget build(BuildContext context) {
    final days = nodes
        .where((node) => includeFutureDays || !node.day.isAfter(today))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return LayoutBuilder(builder: (context, constraints) {
      const step = 128.0;
      const top = 74.0;
      final width = constraints.maxWidth;
      final fixedLandscape = days.length == 7;
      final mapHeight = fixedLandscape
          ? width * 1639 / 960
          : top + 80 + (days.length - 1).clamp(0, days.length) * step;
      final buttonSize =
          fixedLandscape ? (width * .153).clamp(48.0, 90.0) : 70.0;
      final nodeWidth = buttonSize > 70 ? buttonSize + 6 : 76.0;
      final routeWidth = (width - 84).clamp(0.0, width);
      final points = [
        for (var i = 0; i < days.length; i++)
          if (fixedLandscape)
            Offset(width * const [.50, .76, .32, .72, .32, .75, .50][i],
                mapHeight * const [.10, .24, .355, .50, .64, .755, .91][i])
          else
            Offset(
                42 +
                    routeWidth *
                        const [.50, .88, .23, .82, .22, .86, .50][i % 7],
                top + i * step),
      ];
      return Container(
        key: const Key('home-lesson-map-grid'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF8F3),
          borderRadius: BorderRadius.circular(22),
          border: fixedLandscape
              ? null
              : Border.all(color: const Color(0xFFE7DCCE), width: 2),
        ),
        child: SizedBox(
          height: mapHeight,
          child: Stack(
            children: [
              if (fixedLandscape)
                Positioned.fill(
                    child: Image.asset(
                  'assets/images/learning_map_forest_background.png',
                  key: const Key('home-map-fixed-background'),
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ))
              else ...[
                Positioned.fill(
                    child: CustomPaint(
                  painter: LearningMapScenery(points: points),
                )),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoutePainter(points: points),
                  ),
                ),
              ],
              for (var i = 0; i < days.length; i++)
                Positioned(
                  left: points[i].dx - nodeWidth / 2,
                  top: points[i].dy - buttonSize / 2,
                  width: nodeWidth,
                  child: _RouteDay(
                    node: days[i],
                    isToday: days[i].day == today,
                    isFuture: days[i].day.isAfter(today),
                    index: i + 1,
                    total: days.length,
                    showDates: showDates,
                    buttonSize: buttonSize,
                    onTap: () => onOpen(days[i]),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _RouteDay extends StatelessWidget {
  const _RouteDay({
    required this.node,
    required this.isToday,
    required this.isFuture,
    required this.index,
    required this.total,
    required this.showDates,
    required this.buttonSize,
    required this.onTap,
  });

  final DailyLessonNode node;
  final bool isToday;
  final bool isFuture;
  final int index;
  final int total;
  final bool showDates;
  final double buttonSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = node.photoCount == 0;
    final failed = node.status == DailyLessonStatus.syncFailed;
    final color = isFuture
        ? const Color(0xFFFF6B6B)
        : locked
            ? const Color(0xFFE5E5E5)
            : AppColors.duoGreen;
    final symbol = locked
        ? Icons.lock_rounded
        : failed
            ? Icons.warning_rounded
            : isToday
                ? Icons.menu_book_rounded
                : Icons.laptop_chromebook_rounded;
    final statusLabel = isFuture
        ? 'Chưa tới ngày học'
        : switch (node.status) {
            DailyLessonStatus.noData => 'Chưa đủ dữ liệu',
            DailyLessonStatus.ready => 'Sẵn sàng học',
            DailyLessonStatus.inProgress => 'Đang học',
            DailyLessonStatus.pendingSync => 'Chờ đồng bộ',
            DailyLessonStatus.syncFailed => 'Đồng bộ lỗi',
            DailyLessonStatus.completed => 'Đã hoàn thành',
            DailyLessonStatus.expired => 'Đã quá hạn',
          };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '${node.day.day}/${node.day.month}, $statusLabel, '
              '${node.validWords}/${node.targetWords} từ',
          child: Tooltip(
            message: '${node.day.day}/${node.day.month}: '
                '${node.validWords}/${node.targetWords} từ',
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: buttonSize,
                  child: StickerButton(
                    key: Key('home-lesson-node-${node.day.year}-'
                        '${node.day.month.toString().padLeft(2, '0')}-'
                        '${node.day.day.toString().padLeft(2, '0')}'),
                    onPressed: isFuture ? null : onTap,
                    semanticLabel:
                        '${node.day.day}/${node.day.month}, $statusLabel',
                    surfaceColor: color,
                    edgeColor: const Color(0xFFBDBDB8),
                    borderColor: AppColors.ink,
                    radius: 999,
                    minHeight: buttonSize,
                    expand: true,
                    padding: EdgeInsets.zero,
                    icon: Icon(symbol,
                        size: 27,
                        color: isFuture
                            ? Colors.white
                            : locked
                                ? const Color(0xFFE6B675)
                                : isToday
                                    ? Colors.white
                                    : failed
                                        ? AppColors.ink
                                        : const Color(0xFF3A9DE0),
                        shadows: isToday
                            ? const [
                                Shadow(
                                  color: AppColors.ink,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null),
                  ),
                ),
                if (isToday)
                  const Positioned(
                      top: -28,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFFF7850),
                        size: 34,
                        shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF4EAD8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8DCC8), width: 1.5),
          ),
          child: Text(
              showDates ? '${node.day.day}/${node.day.month}' : '$index/$total',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              )),
        ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.points});

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final before = i == 0 ? start : points[i - 1];
      final after = i + 2 < points.length ? points[i + 2] : end;
      final controlStart = start + (end - before) / 6;
      final controlEnd = end - (after - start) / 6;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(controlStart.dx, controlStart.dy, controlEnd.dx,
            controlEnd.dy, end.dx, end.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE6DCCF);
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 19) {
          canvas.drawPath(
              metric.extractPath(d, (d + 10).clamp(0, metric.length)), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}
