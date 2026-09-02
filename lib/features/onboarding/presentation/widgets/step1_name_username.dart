import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';

class Step1NameUsername extends ConsumerWidget {
  const Step1NameUsername({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 0,
          child: Text('Họ tên và tên đăng nhập', style: TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '1. Họ tên & Biệt danh Username 👤',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 18),

        // Display Name Label & Field
        _buildFieldLabel(
          label: 'Họ và tên của bạn',
          icon: Icons.person_outline_rounded,
          badgeColor: const Color(0xFFDDD6FE),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('onboarding-display-name-field'),
          initialValue: state.data.displayName,
          enabled: !state.isBusy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFamily: 'Nunito',
          ),
          decoration: _inputDecoration(
            hintText: 'Deer Mây',
            errorText: state.fieldErrors['displayName'],
          ),
          onChanged: notifier.updateDisplayName,
        ),

        const SizedBox(height: 16),

        // Username Label & Field
        _buildFieldLabel(
          label: 'Biệt danh Username (@)',
          icon: Icons.alternate_email_rounded,
          badgeColor: const Color(0xFF7DD3FC),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('onboarding-username-field'),
          initialValue: state.data.username,
          enabled: !state.isBusy,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFamily: 'Nunito',
          ),
          decoration: _inputDecoration(
            hintText: 'capy_may',
            errorText: state.fieldErrors['username'],
            suffixIcon: state.isCheckingUsername
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.ink,
                      ),
                    ),
                  )
                : null,
          ),
          onChanged: notifier.updateUsername,
        ),
      ],
    );
  }

  Widget _buildFieldLabel({
    required String label,
    required IconData icon,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.ink,
              width: 1.8,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      hintStyle: const TextStyle(
        color: Color(0xFF888888),
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: AppColors.softWhite,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: 2.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.5,
        ),
      ),
    );
  }
}
