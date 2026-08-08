class OnboardingData {
  const OnboardingData({
    this.displayName = '',
    this.username = '',
    this.age,
    this.phone = '',
    this.accountRole,
    this.reminderTime = '20:00',
    this.studyEndTime = '21:00',
    this.dailyTargetWords = 10,
  });

  static const Object _notProvided = Object();

  final String displayName;
  final String username;
  final int? age;
  final String phone;
  final String? accountRole;
  final String? reminderTime;
  final String? studyEndTime;
  final int? dailyTargetWords;

  OnboardingData copyWith({
    String? displayName,
    String? username,
    Object? age = _notProvided,
    String? phone,
    Object? accountRole = _notProvided,
    Object? reminderTime = _notProvided,
    Object? studyEndTime = _notProvided,
    Object? dailyTargetWords = _notProvided,
  }) {
    return OnboardingData(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      age: identical(age, _notProvided) ? this.age : age as int?,
      phone: phone ?? this.phone,
      accountRole: identical(accountRole, _notProvided)
          ? this.accountRole
          : accountRole as String?,
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
    );
  }
}
