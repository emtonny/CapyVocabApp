import '../entities/consent_event.dart';
import '../entities/library_enums.dart';
import '../entities/local_account.dart';

abstract interface class ConsentRepository {
  Stream<LocalAccount?> watchLocalAccount({required String userId});

  Stream<List<ConsentEvent>> watchConsentHistory({required String userId});

  /// Appends the audit event and updates LocalAccount's materialized consent
  /// flag in the same local transaction.
  Future<void> recordChange(ConsentEvent event);

  Future<List<ConsentEvent>> getPendingEnforcement({
    required String userId,
    ConsentType? consentType,
  });

  Future<void> updateEnforcementState({
    required String userId,
    required String eventId,
    required ConsentEnforcementState state,
  });
}
