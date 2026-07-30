import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';

class Step5DailyTarget extends ConsumerStatefulWidget {
  const Step5DailyTarget({super.key});

  @override
  ConsumerState<Step5DailyTarget> createState() => _Step5DailyTargetState();
}

class _Step5DailyTargetState extends ConsumerState<Step5DailyTarget> {
  late final TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    final target = ref.read(onboardingProvider).data.dailyTargetWords;
    _targetController = TextEditingController(text: target?.toString() ?? '');
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mục tiêu từ vựng mỗi ngày',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nhập số từ hoặc chọn nhanh một mục tiêu bên dưới.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextFormField(
          key: const Key('daily-target-field'),
          controller: _targetController,
          enabled: !state.isBusy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: 'Số từ mỗi ngày',
            suffixText: 'từ/ngày',
            prefixIcon: const Icon(Icons.track_changes_outlined),
            border: const OutlineInputBorder(),
            errorText: state.fieldErrors['dailyTargetWords'],
          ),
          onChanged: (value) {
            notifier.updateDailyTargetWords(int.tryParse(value));
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Chọn nhanh',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [5, 10, 15, 20, 30].map((target) {
            final selected = state.data.dailyTargetWords == target;
            return SizedBox(
              height: 48,
              child: ChoiceChip(
                label: Text('$target từ'),
                selected: selected,
                selectedColor: AppColors.duoGreen,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: state.isBusy
                    ? null
                    : (_) {
                        _targetController.text = target.toString();
                        notifier.updateDailyTargetWords(target);
                      },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
