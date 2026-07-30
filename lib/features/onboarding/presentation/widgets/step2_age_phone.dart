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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Độ tuổi và số điện thoại',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Thông tin này giúp cá nhân hóa trải nghiệm học tập.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
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
          decoration: InputDecoration(
            labelText: 'Tuổi',
            hintText: '20',
            prefixIcon: const Icon(Icons.cake_outlined),
            border: const OutlineInputBorder(),
            errorText: state.fieldErrors['age'],
          ),
          onChanged: (value) => notifier.updateAge(int.tryParse(value)),
        ),
        const SizedBox(height: 16),
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
          decoration: InputDecoration(
            labelText: 'Số điện thoại',
            hintText: '0987654321',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: const OutlineInputBorder(),
            helperText: 'Đúng 10 chữ số và bắt đầu bằng 0',
            errorText: state.fieldErrors['phone'],
          ),
          onChanged: notifier.updatePhone,
        ),
      ],
    );
  }
}
