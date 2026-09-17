const supportedLanguageCodes = <String>{'vi', 'en'};
const supportedProficiencyLevels = <String>{
  'beginner',
  'intermediate',
  'advanced',
};

class LanguageProfile {
  const LanguageProfile({
    required this.userId,
    required this.nativeLanguageCode,
    required this.learningLanguageCode,
    this.proficiencyLevel = 'beginner',
  });

  final String userId;
  final String nativeLanguageCode;
  final String learningLanguageCode;
  final String proficiencyLevel;

  bool get isValid =>
      userId.isNotEmpty &&
      supportedLanguageCodes.contains(nativeLanguageCode) &&
      supportedLanguageCodes.contains(learningLanguageCode) &&
      nativeLanguageCode != learningLanguageCode &&
      supportedProficiencyLevels.contains(proficiencyLevel);

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'native_language_code': nativeLanguageCode,
        'learning_language_code': learningLanguageCode,
        'proficiency_level': proficiencyLevel,
      };

  static LanguageProfile? tryFromJson(Map<String, Object?> json) {
    final profile = LanguageProfile(
      userId: json['user_id'] as String? ?? '',
      nativeLanguageCode: json['native_language_code'] as String? ?? '',
      learningLanguageCode: json['learning_language_code'] as String? ?? '',
      proficiencyLevel: json['proficiency_level'] as String? ?? 'beginner',
    );
    return profile.isValid ? profile : null;
  }
}

String languageLabel(String? code) => switch (code) {
      'vi' => 'Tiếng Việt',
      'en' => 'Tiếng Anh',
      _ => 'Chưa thiết lập',
    };

String proficiencyLabel(String code) => switch (code) {
      'intermediate' => 'Trung cấp',
      'advanced' => 'Nâng cao',
      _ => 'Mới bắt đầu',
    };
