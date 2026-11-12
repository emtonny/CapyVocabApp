import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../providers/daily_lesson_provider.dart';
import 'lesson_route_map.dart';

class MonthlyLessonRouteMap extends StatefulWidget {
  const MonthlyLessonRouteMap({
    super.key,
    required this.nodes,
    required this.today,
    required this.onOpen,
  });

  final List<DailyLessonNode> nodes;
  final DateTime today;
  final ValueChanged<DailyLessonNode> onOpen;

  @override
  State<MonthlyLessonRouteMap> createState() => _MonthlyLessonRouteMapState();
}

class _MonthlyLessonRouteMapState extends State<MonthlyLessonRouteMap> {
  final _scrollController = ScrollController();
  int? _page;

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void didUpdateWidget(covariant MonthlyLessonRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes.isNotEmpty &&
        widget.nodes.isNotEmpty &&
        (oldWidget.nodes.first.day.month != widget.nodes.first.day.month ||
            oldWidget.nodes.first.day.year != widget.nodes.first.day.year)) {
      _page = null;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days =
        widget.nodes.where((node) => !node.day.isAfter(widget.today)).toList();
    final month = days.isEmpty ? widget.today : days.first.day;
    final lastPage = days.isEmpty
        ? 0
        : (days.map((day) => day.day.day).reduce((a, b) => a > b ? a : b) -
                1) ~/
            7;
    final page = (_page ?? lastPage).clamp(0, lastPage);
    final monthLength = DateTime.utc(month.year, month.month + 1, 0).day;
    final firstDay = (page * 7 + 1).clamp(1, monthLength - 6);
    final pageDays = widget.nodes
        .where(
            (node) => node.day.day >= firstDay && node.day.day < firstDay + 7)
        .toList();
    final photographed = days.where((node) => node.photoCount > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF3E4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Tháng ${month.month}/${month.year}',
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
              Text('$photographed/${days.length} ngày có ảnh',
                  style: const TextStyle(
                      color: AppColors.darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          key: const Key('home-monthly-map-viewport'),
          height: (MediaQuery.sizeOf(context).height * .56).clamp(340.0, 480.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              thickness: 5,
              radius: const Radius.circular(6),
              child: SingleChildScrollView(
                key: const Key('home-monthly-map-scroll'),
                controller: _scrollController,
                primary: false,
                child: LessonRouteMap(
                  nodes: pageDays,
                  showDates: true,
                  includeFutureDays: true,
                  today: widget.today,
                  onOpen: widget.onOpen,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          StickerButton(
            key: const Key('home-monthly-map-previous'),
            icon: const Icon(Icons.chevron_left_rounded),
            semanticLabel: '7 ngày trước',
            minHeight: 48,
            onPressed: page > 0 ? () => _goToPage(page - 1) : null,
          ),
          StickerButton(
            key: const Key('home-monthly-map-next'),
            icon: const Icon(Icons.chevron_right_rounded),
            semanticLabel: '7 ngày sau',
            minHeight: 48,
            onPressed: page < lastPage ? () => _goToPage(page + 1) : null,
          ),
        ]),
      ],
    );
  }
}
