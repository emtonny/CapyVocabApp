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
      'time': '07:30',
    },
    {
      'icon': '☀️',
      'title': 'Trưa nghỉ',
      'range': '12:00 - 13:00',
      'time': '12:30',
    },
    {
      'icon': '🌆',
      'title': 'Chiều tối',
      'range': '17:30 - 18:30',
      'time': '18:00',
    },
    {
      'icon': '🌙',
      'title': 'Buổi tối',
      'range': '20:00 - 21:00',
      'time': '20:00',
    },
  ];

  static const _presetTimes = {'07:30', '12:30', '18:00', '20:00'};

  String? _customRange;

  Future<void> _pickCustomTimeRange(
    BuildContext context,
    WidgetRef ref,
    String currentTime,
  ) async {
    int startHour = 9;
    int startMinute = 0;
    if (!_presetTimes.contains(currentTime) && currentTime.contains(':')) {
      final parts = currentTime.split(':');
      startHour = int.tryParse(parts[0]) ?? 9;
      startMinute = int.tryParse(parts[1]) ?? 0;
    }

    final initialStart = TimeOfDay(hour: startHour, minute: startMinute);
    final initialEnd = TimeOfDay(hour: (startHour + 1) % 24, minute: startMinute);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _CustomTimePickerBottomSheet(
          initialStart: initialStart,
          initialEnd: initialEnd,
          onConfirm: (startTime, endTime) {
            final startStr =
                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
            final endStr =
                '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

            setState(() {
              _customRange = '$startStr - $endStr';
            });

            ref.read(onboardingProvider.notifier).updateReminderTime(startStr);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final currentTime = state.data.reminderTime ?? '20:00';
    final isCustomSelected = !_presetTimes.contains(currentTime);
    final customDisplayRange = _customRange ??
        (isCustomSelected ? '$currentTime (Tùy chỉnh)' : 'Tự chọn giờ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 0,
          child: Text('Chọn giờ học hằng ngày', style: TextStyle(fontSize: 0)),
        ),
        SizedBox(
          height: 0,
          child: Text(currentTime, style: const TextStyle(fontSize: 0)),
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
            final slotTime = slot['time']!;
            final isSelected = currentTime == slotTime;

            return _TimeSlotCard(
              key: index == 3 ? const Key('study-time-picker-button') : null,
              icon: slot['icon']!,
              title: slot['title']!,
              range: slot['range']!,
              isSelected: isSelected,
              enabled: !state.isBusy,
              onTap: () => notifier.updateReminderTime(slotTime),
            );
          },
        ),

        const SizedBox(height: 12),

        // Custom Time Range Selection Option Card
        _CustomTimeSlotCard(
          key: const Key('custom-study-time-card'),
          range: customDisplayRange,
          isSelected: isCustomSelected,
          enabled: !state.isBusy,
          onTap: () => _pickCustomTimeRange(context, ref, currentTime),
        ),

        if (state.fieldErrors['reminderTime'] case final error?) ...[
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
    required this.range,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

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
                        range,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C2A21),
                    fontFamily: 'Fredoka',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  range,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF786C65),
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
  int _activeTab = 0; // 0 for Start Time, 1 for End Time

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentActiveTime = _activeTab == 0 ? _startTime : _endTime;
    final pickerDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      currentActiveTime.hour,
      currentActiveTime.minute,
    );

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

          // Segmented Tab for Start Time / End Time
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
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 0
                            ? const Color(0xFFFFF6DC)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: _activeTab == 0
                            ? Border.all(
                                color: const Color(0xFF58CC02), width: 1.5)
                            : null,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Giờ bắt đầu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF786C65),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(_startTime),
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
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 1
                            ? const Color(0xFFFFF6DC)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: _activeTab == 1
                            ? Border.all(
                                color: const Color(0xFF58CC02), width: 1.5)
                            : null,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Giờ kết thúc',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF786C65),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(_endTime),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cupertino Scroll Wheel Time Picker
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              key: ValueKey(_activeTab),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: pickerDateTime,
              onDateTimeChanged: (DateTime newDateTime) {
                setState(() {
                  final newTod = TimeOfDay(
                    hour: newDateTime.hour,
                    minute: newDateTime.minute,
                  );
                  if (_activeTab == 0) {
                    _startTime = newTod;
                  } else {
                    _endTime = newTod;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 12),

          // Selected Time Range Display Summary
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
          const SizedBox(height: 18),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onConfirm(_startTime, _endTime);
              },
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

