import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          child: Text('Độ tuổi và số điện thoại', style: TextStyle(fontSize: 0)),
        ),
        // Step Title Header
        const Text(
          '2. Độ tuổi & Số điện thoại 📱',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 18),

        // Age Label & Field
        const Text(
          'Tuổi của bạn',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 6),
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
            fontWeight: FontWeight.w600,
            color: Color(0xFF3C2A21),
          ),
          decoration: _inputDecoration(
            hintText: '20',
            errorText: state.fieldErrors['age'],
          ),
          onChanged: (value) => notifier.updateAge(int.tryParse(value)),
        ),

        const SizedBox(height: 16),

        // Phone Label & Field
        const Text(
          'Số điện thoại liên hệ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 6),
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
            fontWeight: FontWeight.w600,
            color: Color(0xFF3C2A21),
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
                        strokeWidth: 2,
                        color: Color(0xFF58CC02),
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

  InputDecoration _inputDecoration({
    required String hintText,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      hintStyle: const TextStyle(
        color: Color(0xFFAFA49C),
        fontWeight: FontWeight.normal,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF3C2A21),
          width: 2.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF58CC02),
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.5,
        ),
      ),
    );
  }
}
