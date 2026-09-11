import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/random_uuid.dart';
import '../../../ai_scan/presentation/providers/scan_provider.dart';
import '../../../library/application/library_media_loader.dart';
import '../../../library/data/local/sqlite_library_store.dart';
import '../../../library/domain/entities/consent_event.dart';
import '../../../library/domain/entities/library_enums.dart';
import '../../../library/domain/entities/local_account.dart';
import '../../../library/presentation/providers/library_provider.dart';

export '../../../library/presentation/providers/library_provider.dart'
    show currentLibraryUserIdProvider;

const cloudBackupPolicyVersion = 'privacy-v1';
const cloudBackupConsentSourceAction = 'settings_cloud_backup_toggle';

final cloudBackupConsentProvider = StreamProvider.autoDispose<LocalAccount?>((
  ref,
) async* {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) {
    yield null;
    return;
  }

  final store = await ref.watch(libraryStoreProvider.future);
  yield* store.watchLocalAccount(userId: userId);
});

final cloudBackupConsentControllerProvider =
    FutureProvider.autoDispose<CloudBackupConsentController?>((ref) async {
  final userId = ref.watch(currentLibraryUserIdProvider);
  if (userId == null) return null;

  return CloudBackupConsentController(
    userId: userId,
    store: await ref.watch(libraryStoreProvider.future),
    mediaLoader: ref.watch(libraryMediaLoaderProvider),
    idGenerator: createRandomUuidV4,
  );
});

typedef SetCloudBackupConsent = Future<void> Function(bool enabled);

final setCloudBackupConsentProvider =
    Provider.autoDispose<SetCloudBackupConsent>(
  (ref) => (enabled) async {
    final controller =
        await ref.read(cloudBackupConsentControllerProvider.future);
    if (controller == null) {
      throw StateError('Cloud backup requires an authenticated account');
    }
    await controller.setEnabled(enabled);
  },
);

typedef CloudBackupBackfillResult = ({
  int queuedCount,
  int missingMediaCount,
});
typedef BackfillExistingPhotoNotes = Future<CloudBackupBackfillResult>
    Function();

final backfillExistingPhotoNotesProvider =
    Provider.autoDispose<BackfillExistingPhotoNotes>(
  (ref) => () async {
    final controller =
        await ref.read(cloudBackupConsentControllerProvider.future);
    if (controller == null) {
      throw StateError(
          'Cloud backup backfill requires an authenticated account');
    }
    return controller.backfillExistingPhotoNotes();
  },
);

final class CloudBackupConsentController {
  CloudBackupConsentController({
    required this.userId,
    required SqliteLibraryStore store,
    required LibraryMediaLoader mediaLoader,
    required String Function() idGenerator,
    DateTime Function()? clock,
  })  : _store = store,
        _mediaLoader = mediaLoader,
        _idGenerator = idGenerator,
        _clock = clock ?? (() => DateTime.now().toUtc());

  final String userId;
  final SqliteLibraryStore _store;
  final LibraryMediaLoader _mediaLoader;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  Future<void> setEnabled(bool enabled) async {
    var account = await _store.watchLocalAccount(userId: userId).first;
    if (account == null) {
      final now = _clock().toUtc();
      await _store.ensureLocalAccount(
        LocalAccount(
          userId: userId,
          accountState: AccountState.active,
          cloudBackupEnabled: false,
          localPersonalizationEnabled: false,
          federatedContributionEnabled: false,
          lastAuthenticatedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      account = await _store.watchLocalAccount(userId: userId).first;
    }

    if (account == null) {
      throw StateError('Could not bootstrap the local account');
    }
    if (account.cloudBackupEnabled == enabled) return;

    await _store.recordChange(
      ConsentEvent(
        id: _idGenerator(),
        userId: userId,
        consentType: ConsentType.cloudBackup,
        oldValue: account.cloudBackupEnabled,
        newValue: enabled,
        policyVersion: cloudBackupPolicyVersion,
        sourceAction: cloudBackupConsentSourceAction,
        enforcementState: ConsentEnforcementState.applied,
        occurredAt: _clock().toUtc(),
      ),
    );
  }

  Future<CloudBackupBackfillResult> backfillExistingPhotoNotes() async {
    final account = await _store.watchLocalAccount(userId: userId).first;
    if (account?.cloudBackupEnabled != true) {
      throw StateError('Cloud backup consent is required for backfill');
    }

    final candidates = await _store.getCloudBackfillCandidates(userId: userId);
    final availableNoteIds = <String>[];
    var missingMediaCount = 0;
    for (final candidate in candidates) {
      if (!candidate.requiresMediaUpload) {
        availableNoteIds.add(candidate.photoNoteId);
        continue;
      }
      try {
        for (final path in candidate.requiredRelativePaths) {
          await _mediaLoader.sizeBytes(path);
        }
        availableNoteIds.add(candidate.photoNoteId);
      } on LibraryMediaLoadException {
        missingMediaCount++;
      }
    }
    final queuedCount = await _store.enqueueCloudBackfill(
      userId: userId,
      photoNoteIds: availableNoteIds,
    );
    return (
      queuedCount: queuedCount,
      missingMediaCount: missingMediaCount,
    );
  }
}
