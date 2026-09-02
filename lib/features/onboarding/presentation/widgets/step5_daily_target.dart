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

  static const _presets = <Map<String, dynamic>>[
    {'target': 5, 'label': '5 từ (Nhẹ nhàng)'},
    {'target': 10, 'label': '10 từ (Tiêu chuẩn)'},
    {'target': 15, 'label': '15 từ (Tăng tốc)'},
    {'target': 20, 'label': '20 từ (Thử thách)'},
    {'target': 30, 'label': '30 từ (Siêu cấp)'},
  ];

  @override
  void initState() {
    super.initState();
    final target = ref.read(onboardingProvider).data.dailyTargetWords ?? 10;
    _targetController = TextEditingController(text: target.toString());
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
    final currentTarget = state.data.dailyTargetWords ?? 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 0,
          child:
              Text('Mục tiêu từ vựng mỗi ngày', style: TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '5. Số lượng từ vựng bạn muốn học mỗi ngày? 📚',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 10),

        const Text(
          'Tự nhập số lượng từ vựng bạn đặt mục tiêu chinh phục mỗi ngày hoặc chọn nhanh bên dưới:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedInk,
            fontFamily: 'Nunito',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 16),

        // Large Target Display Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF08A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.ink,
              width: 2.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    key: const Key('daily-target-field'),
                    controller: _targetController,
                    enabled: !state.isBusy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      fontFamily: 'Fredoka',
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      notifier.updateDailyTargetWords(int.tryParse(value));
                    },
                  ),
                ),
              ),
              const Text(
                'từ / ngày',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  fontFamily: 'Fredoka',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Gợi ý chọn nhanh:',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 12),

        // Quick Select Buttons Grid (2 columns)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _presets.length,
          itemBuilder: (context, index) {
            final preset = _presets[index];
            final targetValue = preset['target'] as int;
            final label = preset['label'] as String;
            final isSelected = currentTarget == targetValue;

            return _PresetChipButton(
              label: label,
              isSelected: isSelected,
              enabled: !state.isBusy,
              onTap: () {
                _targetController.text = targetValue.toString();
                notifier.updateDailyTargetWords(targetValue);
              },
            );
          },
        ),

        if (state.fieldErrors['dailyTargetWords'] case final error?) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ],
    );
  }
}

class _PresetChipButton extends StatelessWidget {
  const _PresetChipButton({
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.lime : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.ink,
          width: isSelected ? 2.2 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink,
            offset:
                isSelected ? const Offset(2.8, 2.8) : const Offset(2.0, 2.0),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                fontFamily: 'Fredoka',
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
