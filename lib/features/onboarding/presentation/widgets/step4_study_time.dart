import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';

class Step4StudyTime extends ConsumerWidget {
  const Step4StudyTime({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final reminderTime = state.data.reminderTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Chọn giờ học hằng ngày',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn chính xác giờ và phút phù hợp với lịch của bạn.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Semantics(
          button: true,
          label: reminderTime == null
              ? 'Chọn giờ học'
              : 'Giờ học đã chọn $reminderTime',
          child: Material(
            color: AppColors.creamyYuzu,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const Key('study-time-picker-button'),
              onTap: state.isBusy
                  ? null
                  : () => _pickTime(
                        context,
                        reminderTime,
                        notifier.updateReminderTime,
                      ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(minHeight: 88),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.capyBrown, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.capyBrown,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.alarm_rounded,
                      color: AppColors.duoOrange,
                      size: 36,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Giờ học của bạn'),
                          const SizedBox(height: 2),
                          Text(
                            reminderTime ?? 'Chạm để chọn giờ',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined),
                  ],
                ),
              ),
            ),
          ),
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

  Future<void> _pickTime(
    BuildContext context,
    String? currentValue,
    ValueChanged<String> onSelected,
  ) async {
    final initialTime =
        _parseTime(currentValue) ?? const TimeOfDay(hour: 20, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (selected == null || !context.mounted) return;
    onSelected(
      '${selected.hour.toString().padLeft(2, '0')}:'
      '${selected.minute.toString().padLeft(2, '0')}',
    );
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}
