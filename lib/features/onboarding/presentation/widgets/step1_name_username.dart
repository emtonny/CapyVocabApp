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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Họ tên và tên đăng nhập',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bạn có thể chỉnh lại họ tên và chọn username duy nhất.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextFormField(
          key: const Key('onboarding-display-name-field'),
          initialValue: state.data.displayName,
          enabled: !state.isBusy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: 'Họ tên',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
            errorText: state.fieldErrors['displayName'],
          ),
          onChanged: notifier.updateDisplayName,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('onboarding-username-field'),
          initialValue: state.data.username,
          enabled: !state.isBusy,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Username',
            hintText: 'capy_may',
            prefixIcon: const Icon(Icons.alternate_email),
            border: const OutlineInputBorder(),
            helperText: '3-20 ký tự: chữ, số hoặc dấu gạch dưới',
            errorText: state.fieldErrors['username'],
            suffixIcon: state.isCheckingUsername
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: notifier.updateUsername,
        ),
      ],
    );
  }
}
