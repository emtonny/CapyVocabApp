import 'domain_validation.dart';
import 'library_enums.dart';

final class LocalAccount {
  LocalAccount({
    required String userId,
    required this.accountState,
    required this.cloudBackupEnabled,
    required this.localPersonalizationEnabled,
    required this.federatedContributionEnabled,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? lastAuthenticatedAt,
  })  : userId = requireUuid(userId, 'userId'),
        lastAuthenticatedAt = requireNullableUtc(
          lastAuthenticatedAt,
          'lastAuthenticatedAt',
        ),
        createdAt = requireUtc(createdAt, 'createdAt'),
        updatedAt = requireUtc(updatedAt, 'updatedAt') {
    if (this.updatedAt.isBefore(this.createdAt)) {
      throw ArgumentError('updatedAt must not be before createdAt');
    }
  }

  final String userId;
  final AccountState accountState;
  final bool cloudBackupEnabled;
  final bool localPersonalizationEnabled;
  final bool federatedContributionEnabled;
  final DateTime? lastAuthenticatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
