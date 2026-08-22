import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 18),

        // Display Name Label & Field
        const Text(
          'Họ và tên của bạn',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('onboarding-display-name-field'),
          initialValue: state.data.displayName,
          enabled: !state.isBusy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3C2A21),
          ),
          decoration: _inputDecoration(
            hintText: 'Deer Mây',
            errorText: state.fieldErrors['displayName'],
          ),
          onChanged: notifier.updateDisplayName,
        ),

        const SizedBox(height: 16),

        // Username Label & Field
        const Text(
          'Biệt danh Username (@)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C2A21),
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 6),
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
            fontWeight: FontWeight.w600,
            color: Color(0xFF3C2A21),
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
                        strokeWidth: 2,
                        color: Color(0xFF58CC02),
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
