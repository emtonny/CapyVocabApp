import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/sticker_button.dart';

/// Shared neo-brutalist dialog treatment for Settings flows.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.content,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: AppColors.softWhite,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.ink,
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.ink, width: 2.5),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
              ],
            ),
            child: Icon(icon, color: AppColors.ink, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedInk,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: content,
      ),
      actions: actions,
    );
  }
}

class SettingsDialogAction extends StatelessWidget {
  const SettingsDialogAction({
    super.key,
    this.actionKey,
    required this.label,
    required this.onPressed,
    this.icon,
    this.surfaceColor = AppColors.yellow,
    this.edgeColor,
  });

  final Key? actionKey;
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color surfaceColor;
  final Color? edgeColor;

  @override
  Widget build(BuildContext context) {
    return StickerButton(
      key: actionKey,
      label: label,
      onPressed: onPressed,
      icon: icon,
      surfaceColor: surfaceColor,
      edgeColor: edgeColor,
      minHeight: 48,
      radius: 13,
      fontSize: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }
}

InputDecoration settingsInputDecoration({
  required String label,
  String? hint,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: AppColors.ink, width: 2),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w800,
      color: AppColors.mutedInk,
    ),
    floatingLabelStyle: const TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w900,
      color: AppColors.ink,
    ),
    filled: true,
    fillColor: AppColors.cream,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.blue, width: 3),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.coral, width: 2.5),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.coral, width: 3),
    ),
  );
}
