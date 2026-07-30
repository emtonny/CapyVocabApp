import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';

class Step3RoleSelector extends ConsumerWidget {
  const Step3RoleSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bạn sử dụng ứng dụng với vai trò nào?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn một vai trò phù hợp nhất với bạn.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _RoleCard(
          key: const Key('role-personal-card'),
          title: 'Cá nhân học tập',
          subtitle: 'Tự luyện từ vựng, chơi game và kết bạn.',
          icon: Icons.school_outlined,
          selected: state.data.accountRole == 'personal',
          enabled: !state.isBusy,
          onTap: () => notifier.updateAccountRole('personal'),
        ),
        const SizedBox(height: 16),
        _RoleCard(
          key: const Key('role-parent-card'),
          title: 'Phụ huynh giám sát',
          subtitle: 'Theo dõi tiến độ và đồng hành cùng người học.',
          icon: Icons.family_restroom_outlined,
          selected: state.data.accountRole == 'parent',
          enabled: !state.isBusy,
          onTap: () => notifier.updateAccountRole('parent'),
        ),
        if (state.fieldErrors['accountRole'] case final error?) ...[
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.duoGreen
        : Theme.of(context).colorScheme.outlineVariant;
    final backgroundColor =
        selected ? AppColors.creamyYuzu : Theme.of(context).colorScheme.surface;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width: selected ? 2.5 : 1.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: selected
                      ? AppColors.duoGreen
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.duoGreen,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
