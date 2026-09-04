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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 0,
          child: Text('Bạn sử dụng ứng dụng với vai trò nào?',
              style: TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '3. Bạn sử dụng app với vai trò nào? 👥',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 18),

        // Role Option 1: Personal
        _RoleOptionCard(
          key: const Key('role-personal-card'),
          title: 'Cá nhân học tập',
          subtitle: 'Tự luyện từ vựng, chơi game & kết bạn',
          icon: Icons.person_rounded,
          iconBadgeColor: const Color(0xFFDDD6FE),
          selected: state.data.accountRole == 'personal',
          enabled: !state.isBusy,
          onTap: () => notifier.updateAccountRole('personal'),
        ),

        const SizedBox(height: 14),

        // Role Option 2: Parent
        _RoleOptionCard(
          key: const Key('role-parent-card'),
          title: 'Phụ huynh / Giám sát',
          subtitle: 'Theo dõi tiến độ học & nhận báo cáo',
          icon: Icons.groups_rounded,
          iconBadgeColor: AppColors.yellow,
          selected: state.data.accountRole == 'parent',
          enabled: !state.isBusy,
          onTap: () => notifier.updateAccountRole('parent'),
        ),

        if (state.fieldErrors['accountRole'] case final error?) ...[
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

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBadgeColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBadgeColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFEF08A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.ink,
            width: selected ? 2.5 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink,
              offset: selected
                  ? const Offset(1.75, 1.75)
                  : const Offset(1.25, 1.25),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon Avatar Badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBadgeColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.ink,
                        width: 1.8,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            fontFamily: 'Fredoka',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedInk,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.ink, width: 1.8),
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 15,
                        color: AppColors.ink,
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
