import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          child: Text('Bạn sử dụng ứng dụng với vai trò nào?', style: TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '3. Bạn sử dụng app với vai trò nào? 👥',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
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
          iconColor: const Color(0xFF6B429C),
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
          iconColor: const Color(0xFFD97706),
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

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
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
          color: selected ? const Color(0xFFFFF6DC) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF58CC02) : const Color(0xFFEADECF),
            width: selected ? 2.5 : 2.0,
          ),
          boxShadow: selected
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
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // Icon Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: iconColor,
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
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3C2A21),
                            fontFamily: 'Fredoka',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF786C65),
                          ),
                        ),
                      ],
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
