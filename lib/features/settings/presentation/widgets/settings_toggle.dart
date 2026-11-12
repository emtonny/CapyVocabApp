import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Tactile neo-brutalist switch used by Settings rows.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!value) : null,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 64,
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: 58,
                  height: 34,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: value ? AppColors.mint : AppColors.cream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.ink, width: 2.2),
                    boxShadow: const [
                      BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
                    ],
                  ),
                  child: AnimatedAlign(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    alignment:
                        value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: value ? AppColors.ink : AppColors.softWhite,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
