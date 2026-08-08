import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/onboarding_provider.dart';

class Step4StudyTime extends ConsumerStatefulWidget {
  const Step4StudyTime({super.key});

  @override
  ConsumerState<Step4StudyTime> createState() => _Step4StudyTimeState();
}

class _Step4StudyTimeState extends ConsumerState<Step4StudyTime> {
  static const _presetSlots = <Map<String, String>>[
    {
      'icon': '🌅',
      'title': 'Sáng sớm',
      'range': '07:00 - 08:00',
      'start': '07:00',
      'end': '08:00',
    },
    {
      'icon': '☀️',
      'title': 'Trưa nghỉ',
      'range': '12:00 - 13:00',
      'start': '12:00',
      'end': '13:00',
    },
    {
      'icon': '🌆',
      'title': 'Chiều tối',
      'range': '17:30 - 18:30',
      'start': '17:30',
      'end': '18:30',
    },
    {
      'icon': '🌙',
      'title': 'Buổi tối',
      'range': '20:00 - 21:00',
      'start': '20:00',
      'end': '21:00',
    },
  ];

  String? _customRange;

  Future<void> _pickCustomTimeRange(
    BuildContext context,
    WidgetRef ref,
    String currentStartTime,
    String currentEndTime,
  ) async {
    final initialStart =
        _parseTime(currentStartTime, const TimeOfDay(hour: 20, minute: 0));
    final initialEnd =
        _parseTime(currentEndTime, const TimeOfDay(hour: 21, minute: 0));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _CustomTimePickerBottomSheet(
          initialStart: initialStart,
          initialEnd: initialEnd,
          onConfirm: (startTime, endTime) {
            final start = _formatTime(startTime);
            final end = _formatTime(endTime);

            setState(() {
              _customRange = '$start - $end';
            });

            ref
                .read(onboardingProvider.notifier)
                .updateStudyTimeRange(start: start, end: end);
          },
        );
      },
    );
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final currentStartTime = state.data.reminderTime ?? '20:00';
    final currentEndTime = state.data.studyEndTime ?? '21:00';
    final matchingPreset = _presetSlots.any(
      (slot) =>
          slot['start'] == currentStartTime && slot['end'] == currentEndTime,
    );
    final isCustomSelected = _customRange != null || !matchingPreset;
    final customDisplayRange = _customRange ??
        (isCustomSelected
            ? '$currentStartTime - $currentEndTime'
            : 'Tự chọn khung giờ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 0,
          child: Text('Chọn giờ học hằng ngày', style: TextStyle(fontSize: 0)),
        ),
        SizedBox(
          height: 0,
          child: Text(currentStartTime, style: const TextStyle(fontSize: 0)),
        ),
        SizedBox(
          height: 0,
          child: Text(currentEndTime, style: const TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '4. Khung giờ học hàng ngày của bạn? ⏰',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 18),

        // 2x2 Grid of Preset Study Time Slots
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.35,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _presetSlots.length,
          itemBuilder: (context, index) {
            final slot = _presetSlots[index];
            final slotStart = slot['start']!;
            final slotEnd = slot['end']!;
            final isSelected = !isCustomSelected &&
                currentStartTime == slotStart &&
                currentEndTime == slotEnd;

            return _TimeSlotCard(
              key: index == 3 ? const Key('study-time-picker-button') : null,
              icon: slot['icon']!,
              title: slot['title']!,
              range: slot['range']!,
              isSelected: isSelected,
              enabled: !state.isBusy,
              onTap: () {
                setState(() => _customRange = null);
                notifier.updateStudyTimeRange(start: slotStart, end: slotEnd);
              },
            );
          },
        ),

        const SizedBox(height: 12),

        // Custom study-time range selection option card.
        _CustomTimeSlotCard(
          key: const Key('custom-study-time-card'),
          time: customDisplayRange,
          isSelected: isCustomSelected,
          enabled: !state.isBusy,
          onTap: () => _pickCustomTimeRange(
            context,
            ref,
            currentStartTime,
            currentEndTime,
          ),
        ),

        if (state.fieldErrors['reminderTime'] case final error?) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.fieldErrors['studyEndTime'] case final error?) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _CustomTimeSlotCard extends StatelessWidget {
  const _CustomTimeSlotCard({
    required this.time,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String time;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF6DC) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF58CC02) : const Color(0xFFEADECF),
          width: isSelected ? 2.5 : 2.0,
        ),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Color(0xFF58CC02),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0xFFEADECF),
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text(
                  '⏱️',
                  style: TextStyle(fontSize: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tùy chỉnh khung giờ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C2A21),
                          fontFamily: 'Fredoka',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF58CC02)
                              : const Color(0xFF786C65),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_calendar_rounded,
                  color: isSelected
                      ? const Color(0xFF58CC02)
                      : const Color(0xFF786C65),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({
    required this.icon,
    required this.title,
    required this.range,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String icon;
  final String title;
  final String range;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF6DC) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF58CC02) : const Color(0xFFEADECF),
          width: isSelected ? 2.5 : 2.0,
        ),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Color(0xFF58CC02),
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0xFFEADECF),
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C2A21),
                      fontFamily: 'Fredoka',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    range,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF786C65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomTimePickerBottomSheet extends StatefulWidget {
  const _CustomTimePickerBottomSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.onConfirm,
  });

  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;
  final void Function(TimeOfDay start, TimeOfDay end) onConfirm;

  @override
  State<_CustomTimePickerBottomSheet> createState() =>
      __CustomTimePickerBottomSheetState();
}

class __CustomTimePickerBottomSheetState
    extends State<_CustomTimePickerBottomSheet> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStart;
    _endTime = widget.initialEnd;
  }

  String _formatTime(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime _dateTime(TimeOfDay time) {
    return DateTime(2000, 1, 1, time.hour, time.minute);
  }

  void _selectStart(DateTime value) {
    setState(() {
      _startTime = TimeOfDay(hour: value.hour, minute: value.minute);
    });
  }

  void _selectEnd(DateTime value) {
    setState(() {
      _endTime = TimeOfDay(hour: value.hour, minute: value.minute);
    });
  }

  String _formatDurationHours(int durationMinutes) {
    if (durationMinutes % 60 == 0) {
      return '${durationMinutes ~/ 60}';
    }
    final hours = (durationMinutes / 60).toStringAsFixed(2);
    return hours
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final isPickingStart = _activeTab == 0;
    final selectedTime = isPickingStart ? _startTime : _endTime;
    final durationMinutes = studyDurationMinutes(
      _formatTime(_startTime),
      _formatTime(_endTime),
    );
    final isValidRange = durationMinutes > 0;
    final shouldWarnAboutDuration = durationMinutes > 180;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFEADECF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Modal Title
          const Text(
            'Tùy chỉnh khung giờ học ⏰',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3C2A21),
              fontFamily: 'Fredoka',
            ),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEADECF)),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _TimeTab(
                    key: const Key('study-start-time-tab'),
                    label: 'Giờ bắt đầu',
                    time: _formatTime(_startTime),
                    isSelected: isPickingStart,
                    onTap: () => setState(() => _activeTab = 0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _TimeTab(
                    key: const Key('study-end-time-tab'),
                    label: 'Giờ kết thúc',
                    time: _formatTime(_endTime),
                    isSelected: !isPickingStart,
                    onTap: () => setState(() => _activeTab = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cupertino Scroll Wheel Time Picker
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              key: ValueKey('study-time-picker-$_activeTab'),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: _dateTime(selectedTime),
              onDateTimeChanged: isPickingStart ? _selectStart : _selectEnd,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6DC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF58CC02)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '⏰  Khung giờ chọn: ',
                  style: TextStyle(fontSize: 13, color: Color(0xFF786C65)),
                ),
                Text(
                  '${_formatTime(_startTime)} - ${_formatTime(_endTime)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C2A21),
                    fontFamily: 'Fredoka',
                  ),
                ),
              ],
            ),
          ),
          if (!isValidRange) ...[
            const SizedBox(height: 8),
            Text(
              'Giờ kết thúc không được trùng giờ bắt đầu.',
              key: const Key('study-time-range-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (shouldWarnAboutDuration) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('study-time-duration-warning'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D)),
              ),
              child: Text(
                'Khung giờ học khá dài '
                '(${_formatDurationHours(durationMinutes)} tiếng) — '
                'nhớ giữ gìn sức khỏe, nghỉ ngơi hợp lý nhé!',
                style: const TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('confirm-study-time-range'),
              onPressed: isValidRange
                  ? () {
                      Navigator.of(context).pop();
                      widget.onConfirm(_startTime, _endTime);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58CC02),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Xác nhận',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Fredoka',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTab extends StatelessWidget {
  const _TimeTab({
    required this.label,
    required this.time,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String time;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFFFF6DC) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF58CC02), width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF786C65),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3C2A21),
                  fontFamily: 'Fredoka',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
