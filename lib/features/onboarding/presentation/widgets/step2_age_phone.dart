import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';

class Step2AgePhone extends ConsumerStatefulWidget {
  const Step2AgePhone({super.key});

  @override
  ConsumerState<Step2AgePhone> createState() => _Step2AgePhoneState();
}

class _Step2AgePhoneState extends ConsumerState<Step2AgePhone> {
  final _codeController = TextEditingController();
  Timer? _timer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
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
          '3. Độ tuổi & Số điện thoại 📱',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Nunito',
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
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s().-]')),
            LengthLimitingTextInputFormatter(24),
          ],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFamily: 'Nunito',
          ),
          decoration: _inputDecoration(
            hintText: '+84987654321',
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
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('onboarding-request-phone-code'),
            onPressed: state.isBusy || _resendSeconds > 0 || state.phoneVerified
                ? null
                : () async {
                    final sent = await notifier.requestPhoneCode();
                    if (sent &&
                        mounted &&
                        !ref.read(onboardingProvider).phoneVerified) {
                      _startCooldown();
                    }
                  },
            icon: state.phoneVerified
                ? const Icon(Icons.verified_rounded)
                : const Icon(Icons.sms_outlined),
            label: Text(
              state.phoneVerified
                  ? 'Số điện thoại đã xác nhận'
                  : _resendSeconds > 0
                      ? 'Gửi lại mã sau ${_resendSeconds}s'
                      : state.phoneVerificationSent
                          ? 'Gửi lại mã SMS'
                          : 'Gửi mã SMS',
            ),
          ),
        ),
        if (state.phoneVerificationSent && !state.phoneVerified) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('onboarding-phone-code-field'),
            controller: _codeController,
            enabled: !state.isBusy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: _inputDecoration(
              hintText: 'Mã xác nhận gồm 6 số',
              errorText: state.fieldErrors['phoneCode'],
            ),
            onFieldSubmitted: state.isBusy
                ? null
                : (value) => notifier.verifyPhoneCode(value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('onboarding-verify-phone-code'),
              onPressed: state.isBusy
                  ? null
                  : () => notifier.verifyPhoneCode(_codeController.text),
              child: Text(
                state.isVerifyingPhone
                    ? 'Đang xác nhận...'
                    : 'Xác nhận số điện thoại',
              ),
            ),
          ),
        ],
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
            fontFamily: 'Nunito',
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
