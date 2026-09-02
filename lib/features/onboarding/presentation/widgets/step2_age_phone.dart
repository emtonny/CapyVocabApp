import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';

class Step2AgePhone extends ConsumerWidget {
  const Step2AgePhone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 0,
          child:
              Text('Độ tuổi và số điện thoại', style: TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '2. Độ tuổi & Số điện thoại 📱',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 18),

        // Age Label & Field
        _buildFieldLabel(
          label: 'Tuổi của bạn',
          icon: Icons.cake_outlined,
          badgeColor: AppColors.yellow,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('onboarding-age-field'),
          initialValue: state.data.age?.toString() ?? '',
          enabled: !state.isBusy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFamily: 'Nunito',
          ),
          decoration: _inputDecoration(
            hintText: '20',
            errorText: state.fieldErrors['age'],
          ),
          onChanged: (value) => notifier.updateAge(int.tryParse(value)),
        ),

        const SizedBox(height: 16),

        // Phone Label & Field
        _buildFieldLabel(
          label: 'Số điện thoại liên hệ',
          icon: Icons.phone_iphone_rounded,
          badgeColor: AppColors.lime,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('onboarding-phone-field'),
          initialValue: state.data.phone,
          enabled: !state.isBusy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFamily: 'Nunito',
          ),
          decoration: _inputDecoration(
            hintText: '0987654321',
            errorText: state.fieldErrors['phone'],
            suffixIcon: state.isCheckingPhone
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
          onChanged: notifier.updatePhone,
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
