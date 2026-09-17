import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../language_profile/domain/entities/language_profile.dart';
import '../providers/onboarding_provider.dart';

class Step4LanguageProfile extends ConsumerWidget {
  const Step4LanguageProfile({super.key});

  static const _languages = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
    DropdownMenuItem(value: 'en', child: Text('Tiếng Anh')),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ngôn ngữ của bạn',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Thông tin này giúp sắp xếp câu gốc và câu dịch đúng cho riêng bạn.',
          style: TextStyle(color: AppColors.mutedInk, height: 1.35),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          key: const Key('native-language-field'),
          initialValue: state.data.nativeLanguageCode,
          decoration: InputDecoration(
            labelText: 'Ngôn ngữ gốc',
            errorText: state.fieldErrors['nativeLanguageCode'],
          ),
          items: _languages,
          onChanged: (value) {
            if (value != null) notifier.updateNativeLanguage(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('learning-language-field'),
          initialValue: state.data.learningLanguageCode,
          decoration: InputDecoration(
            labelText: 'Ngôn ngữ muốn học',
            errorText: state.fieldErrors['learningLanguageCode'],
          ),
          items: _languages,
          onChanged: (value) {
            if (value != null) notifier.updateLearningLanguage(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('proficiency-level-field'),
          initialValue: supportedProficiencyLevels.contains(
            state.data.proficiencyLevel,
          )
              ? state.data.proficiencyLevel
              : 'beginner',
          decoration: InputDecoration(
            labelText: 'Trình độ hiện tại',
            errorText: state.fieldErrors['proficiencyLevel'],
          ),
          items: supportedProficiencyLevels
              .map(
                (level) => DropdownMenuItem(
                  value: level,
                  child: Text(proficiencyLabel(level)),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) notifier.updateProficiencyLevel(value);
          },
        ),
      ],
    );
  }
}
