import 'domain_validation.dart';
import 'library_enums.dart';

/// Append-only audit evidence for one account-scoped consent change.
final class ConsentEvent {
  ConsentEvent({
    required String id,
    required String userId,
    required this.consentType,
    required this.oldValue,
    required this.newValue,
    required String policyVersion,
    required String sourceAction,
    required this.enforcementState,
    required DateTime occurredAt,
  })  : id = requireUuid(id, 'id'),
        userId = requireUuid(userId, 'userId'),
        policyVersion = requireNonEmpty(policyVersion, 'policyVersion'),
        sourceAction = requireNonEmpty(sourceAction, 'sourceAction'),
        occurredAt = requireUtc(occurredAt, 'occurredAt') {
    if (oldValue == newValue) {
      throw ArgumentError('a consent event must change the consent value');
    }
  }

  final String id;
  final String userId;
  final ConsentType consentType;
  final bool oldValue;
  final bool newValue;
  final String policyVersion;
  final String sourceAction;
  final ConsentEnforcementState enforcementState;
  final DateTime occurredAt;
}
