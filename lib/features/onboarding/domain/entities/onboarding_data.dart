class OnboardingData {
  const OnboardingData({
    this.displayName = '',
    this.username = '',
    this.age,
    this.phone = '',
    this.interfaceLocale = 'vi-VN',
    this.learningLocale = 'en-US',
    this.accountRole,
    this.nativeLanguageCode,
    this.learningLanguageCode,
    this.proficiencyLevel = 'beginner',
    this.reminderTime = '20:00',
    this.studyEndTime = '21:00',
    this.dailyTargetWords = 10,
  });

  static const Object _notProvided = Object();

  final String displayName;
  final String username;
  final int? age;
  final String phone;
  final String interfaceLocale;
  final String learningLocale;
  final String? accountRole;
  final String? nativeLanguageCode;
  final String? learningLanguageCode;
  final String proficiencyLevel;
  final String? reminderTime;
  final String? studyEndTime;
  final int? dailyTargetWords;

  OnboardingData copyWith({
    String? displayName,
    String? username,
    Object? age = _notProvided,
    String? phone,
    String? interfaceLocale,
    String? learningLocale,
    Object? accountRole = _notProvided,
    Object? nativeLanguageCode = _notProvided,
    Object? learningLanguageCode = _notProvided,
    String? proficiencyLevel,
    Object? reminderTime = _notProvided,
    Object? studyEndTime = _notProvided,
    Object? dailyTargetWords = _notProvided,
  }) {
    return OnboardingData(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      age: identical(age, _notProvided) ? this.age : age as int?,
      phone: phone ?? this.phone,
      interfaceLocale: interfaceLocale ?? this.interfaceLocale,
      learningLocale: learningLocale ?? this.learningLocale,
      accountRole: identical(accountRole, _notProvided)
          ? this.accountRole
          : accountRole as String?,
      nativeLanguageCode: identical(nativeLanguageCode, _notProvided)
          ? this.nativeLanguageCode
          : nativeLanguageCode as String?,
      learningLanguageCode: identical(learningLanguageCode, _notProvided)
          ? this.learningLanguageCode
          : learningLanguageCode as String?,
      proficiencyLevel: proficiencyLevel ?? this.proficiencyLevel,
      reminderTime: identical(reminderTime, _notProvided)
          ? this.reminderTime
          : reminderTime as String?,
      studyEndTime: identical(studyEndTime, _notProvided)
          ? this.studyEndTime
          : studyEndTime as String?,
      dailyTargetWords: identical(dailyTargetWords, _notProvided)
          ? this.dailyTargetWords
          : dailyTargetWords as int?,
    );
  }

  OnboardingData normalized() {
    return copyWith(
      displayName: displayName.trim(),
      username: username.trim().toLowerCase(),
      phone: phone.trim(),
      interfaceLocale: interfaceLocale.trim(),
      learningLocale: learningLocale.trim(),
    );
  }
}
