class AccountContactSettings {
  const AccountContactSettings({
    required this.email,
    required this.phone,
    required this.emailConfirmed,
    required this.phoneConfirmed,
    required this.showEmailToFriends,
    required this.showPhoneToFriends,
  });

  final String email;
  final String? phone;
  final bool emailConfirmed;
  final bool phoneConfirmed;
  final bool showEmailToFriends;
  final bool showPhoneToFriends;

  factory AccountContactSettings.fromJson(Map<String, dynamic> json) {
    return AccountContactSettings(
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      emailConfirmed: json['email_confirmed'] as bool? ?? false,
      phoneConfirmed: json['phone_confirmed'] as bool? ?? false,
      showEmailToFriends: json['show_email_to_friends'] as bool? ?? false,
      showPhoneToFriends: json['show_phone_to_friends'] as bool? ?? false,
    );
  }
}
