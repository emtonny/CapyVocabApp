import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../ai_scan/presentation/providers/scan_provider.dart';
import '../../application/library_sync_coordinator.dart';
import '../../application/library_cloud_pull_worker.dart';
import '../../application/library_sync_worker.dart';
import '../../data/remote/library_sync_gateway_factory.dart';
import 'library_media_integrity_provider.dart';

const librarySyncEnabled = bool.fromEnvironment(
  'LIBRARY_SYNC_ENABLED',
  defaultValue: false,
);

const _networkStatusChannel = MethodChannel(
  'com.capyvocab.app/network_status',
);

Future<bool> _isLibrarySyncNetworkAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    return await _networkStatusChannel.invokeMethod<bool>(
          'isNetworkAvailable',
        ) ??
        false;
  } on PlatformException catch (error) {
    debugPrint('Library network status unavailable: ${error.code}');
    return false;
  } on MissingPluginException {
    debugPrint('Library network status channel is not registered.');
    return false;
  }
}

final librarySyncCoordinatorProvider =
    FutureProvider<LibrarySyncCoordinator?>((ref) async {
  if (!librarySyncEnabled) return null;
  final gateway = createLibrarySyncGateway(SupabaseService.client);
  if (gateway == null) return null;

  final store = await ref.watch(libraryStoreProvider.future);
  final worker = LibrarySyncWorker(
    operations: store,
    local: store,
    remote: gateway,
  );
  final pullWorker = LibraryCloudPullWorker(local: store, remote: gateway);
  final coordinator = LibrarySyncCoordinator(
    operations: store,
    consent: store,
    drain: worker.drainOnce,
    pull: ({required userId}) async {
      final result = await pullWorker.pull(userId: userId);
      if (result.deletions > 0) {
        final deletionService =
            await ref.read(libraryPhotoNoteDeletionServiceProvider.future);
        await deletionService?.maintain(
          userId: userId,
          now: DateTime.now().toUtc(),
        );
      }
      return result.hasMore;
    },
    networkAvailable: _isLibrarySyncNetworkAvailable,
    onError: (error, stackTrace) {
      debugPrint('Library sync coordinator failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
  ref.onDispose(() => unawaited(coordinator.dispose()));
  return coordinator;
});
