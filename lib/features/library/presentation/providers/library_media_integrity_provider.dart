import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_scan/presentation/providers/scan_provider.dart';
import '../../application/library_media_integrity_auditor.dart';
import '../../application/library_media_recovery_service.dart';
import '../../application/library_photo_note_deletion_service.dart';
import '../../data/local/library_media_inventory_factory.dart';
import '../../data/local/library_managed_media_purger_factory.dart';

final libraryMediaRecoveryServiceProvider =
    FutureProvider<LibraryMediaRecoveryService?>((ref) async {
  final recoveryStore = createLibraryMediaRecoveryStore();
  if (recoveryStore == null) return null;

  final store = await ref.watch(libraryStoreProvider.future);
  return LibraryMediaRecoveryService(
    loadReferencedPaths: store.listReferencedMediaPaths,
    store: recoveryStore,
  );
});

final libraryMediaIntegrityAuditProvider =
    FutureProvider<LibraryMediaIntegrityReport?>((ref) async {
  final service = await ref.watch(libraryMediaRecoveryServiceProvider.future);
  return service?.audit();
});

final libraryMediaRecoverySnapshotProvider =
    FutureProvider<LibraryMediaRecoverySnapshot?>((ref) async {
  final service = await ref.watch(libraryMediaRecoveryServiceProvider.future);
  return service?.inspect();
});

final libraryPhotoNoteDeletionServiceProvider =
    FutureProvider<LibraryPhotoNoteDeletionService?>((ref) async {
  final mediaPurger = createLibraryManagedMediaPurger();
  if (mediaPurger == null) return null;
  final store = await ref.watch(libraryStoreProvider.future);
  return LibraryPhotoNoteDeletionService(
    repository: store,
    mediaPurger: mediaPurger,
  );
});
