import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../providers/daily_lesson_provider.dart';

class HomeMapDateFilterDialog extends StatefulWidget {
  const HomeMapDateFilterDialog({
    super.key,
    required this.selection,
    required this.today,
  });

  final HomeLessonMapSelection selection;
  final DateTime today;

  @override
  State<HomeMapDateFilterDialog> createState() =>
      _HomeMapDateFilterDialogState();
}

class _HomeMapDateFilterDialogState extends State<HomeMapDateFilterDialog> {
  late DateTime _day;
  late final ScrollController _monthController;

  DateTime get _today =>
      DateTime(widget.today.year, widget.today.month, widget.today.day);

  @override
  void initState() {
    super.initState();
    final anchor = widget.selection.anchorDay;
    _day = DateTime(anchor.year, anchor.month, anchor.day);
    if (_day.isAfter(_today)) _day = _today;
    _monthController = ScrollController();
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  void _apply(LessonMapPeriod period, DateTime day) => Navigator.pop(context,
      (period: period, day: DateTime.utc(day.year, day.month, day.day)));

  Widget _preset(String label, bool selected, VoidCallback? onPressed,
          {Key? key}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          selected: selected,
          child: StickerButton(
            key: key,
            text: label,
            icon: selected
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
            fontSize: 12,
            minHeight: 48,
            expand: true,
            surfaceColor: selected ? const Color(0xFFFF9800) : Colors.white,
            textColor: selected ? Colors.white : AppColors.ink,
            onPressed: onPressed,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        key: const Key('home-map-date-filter-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        backgroundColor: AppColors.softWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.ink, width: 2.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Text('🗓️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Chọn Ngày Học Tập',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                StickerButton(
                  onPressed: () => Navigator.pop(context),
                  semanticLabel: 'Đóng',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  padding: const EdgeInsets.all(7),
                  radius: 10,
                ),
              ]),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final presetWidth = constraints.maxWidth < 400 ? 100.0 : 140.0;
                return SizedBox(
                  height: 310,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: presetWidth,
                          child: Column(children: [
                            Expanded(
                              child: Scrollbar(
                                controller: _monthController,
                                thumbVisibility: true,
                                thickness: 3,
                                child: ListView(
                                  controller: _monthController,
                                  key: const Key('home-map-filter-month-list'),
                                  primary: false,
                                  padding: EdgeInsets.zero,
                                  children: [
                                    for (final month in [
                                      _today.month,
                                      for (var m = 1; m <= 12; m++)
                                        if (m != _today.month) m,
                                    ])
                                      _preset(
                                          'Tháng $month',
                                          _day.month == month,
                                          DateTime(_day.year, month)
                                                  .isAfter(_today)
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _day = _day.year ==
                                                                _today.year &&
                                                            month ==
                                                                _today.month
                                                        ? _today
                                                        : DateTime(
                                                            _day.year, month);
                                                  });
                                                },
                                          key: Key(
                                              'home-map-filter-month-$month')),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 1, color: const Color(0xFFD8CFC6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: 300,
                                height: 300,
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme:
                                        Theme.of(context).colorScheme.copyWith(
                                              primary: AppColors.darkGreen,
                                            ),
                                  ),
                                  child: CalendarDatePicker(
                                    key: ValueKey(_day),
                                    initialDate: _day,
                                    firstDate: DateTime(2000),
                                    lastDate: _today,
                                    currentDate: _today,
                                    onDateChanged: (day) =>
                                        setState(() => _day = day),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                );
              }),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: StickerButton(
                    key: const Key('home-map-date-filter-clear'),
                    text: 'Bỏ lọc',
                    expand: true,
                    minHeight: 48,
                    onPressed: () => _apply(LessonMapPeriod.month, _today),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StickerButton(
                    key: const Key('home-map-date-filter-apply'),
                    text: 'Áp dụng 🎯',
                    expand: true,
                    minHeight: 48,
                    surfaceColor: AppColors.duoGreen,
                    textColor: Colors.white,
                    onPressed: () => _apply(LessonMapPeriod.month, _day),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      );
}
