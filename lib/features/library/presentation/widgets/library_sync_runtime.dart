import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../ai_scan/presentation/providers/scan_provider.dart';
import '../../application/library_sync_coordinator.dart';
import '../providers/library_media_integrity_provider.dart';
import '../providers/library_sync_provider.dart';

/// Activates native Library sync for the signed-in account while keeping the
/// child application available when the network is down.
class LibrarySyncRuntime extends ConsumerStatefulWidget {
  const LibrarySyncRuntime({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LibrarySyncRuntime> createState() => _LibrarySyncRuntimeState();
}

class _LibrarySyncRuntimeState extends ConsumerState<LibrarySyncRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  LibrarySyncCoordinator? _coordinator;
  String? _requestedUserId;
  bool _mediaAuditStarted = false;
  final Map<String, Future<void>> _deletionMaintenance = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = SupabaseService.auth.onAuthStateChange.listen(
      (state) => unawaited(_setUser(state.session?.user.id)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Library sync auth stream failed: $error');
      },
    );
    unawaited(_setUser(SupabaseService.auth.currentUser?.id));
  }

  Future<void> _auditLocalMediaOnce() async {
    if (_mediaAuditStarted) return;
    _mediaAuditStarted = true;
    try {
      final recovery =
          await ref.read(libraryMediaRecoveryServiceProvider.future);
      final purged = await recovery?.purgeExpired(now: DateTime.now().toUtc());
      final report = await recovery?.audit();
      if (report == null) return;
      if (report.missingRelativePaths.isNotEmpty) {
        final store = await ref.read(libraryStoreProvider.future);
        await store.quarantineTrainingDataForMissingMediaPaths(
          report.missingRelativePaths,
          detectedAt: DateTime.now().toUtc(),
        );
      }
      debugPrint(
        'Library media audit: '
        '${report.orphanRelativePaths.length} orphan, '
        '${report.missingRelativePaths.length} missing, '
        '${purged ?? 0} expired quarantine purged.',
      );
    } catch (error, stackTrace) {
      debugPrint('Library media audit failed (${error.runtimeType}).');
      debugPrintStack(
        label: 'Library media audit stack trace',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _setUser(String? userId) async {
    _requestedUserId = userId;
    try {
      if (userId == null) {
        await _coordinator?.setUser(null);
        return;
      }
      unawaited(_maintainPhotoNoteDeletions(userId));
      unawaited(_auditLocalMediaOnce());
      final coordinator = await ref.read(librarySyncCoordinatorProvider.future);
      if (!mounted || _requestedUserId != userId) return;
      _coordinator = coordinator;
      await coordinator?.setUser(userId);
      coordinator?.triggerNow();
    } catch (error, stackTrace) {
      debugPrint('Library sync runtime failed to start: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _maintainPhotoNoteDeletions(String userId) {
    return _deletionMaintenance.putIfAbsent(userId, () async {
      try {
        final service =
            await ref.read(libraryPhotoNoteDeletionServiceProvider.future);
        final result = await service?.maintain(
          userId: userId,
          now: DateTime.now().toUtc(),
        );
        if (result != null && (result.promoted > 0 || result.localPurged > 0)) {
          debugPrint(
            'Library deletion maintenance: ${result.promoted} promoted, '
            '${result.localPurged} local purged.',
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Library deletion maintenance failed (${error.runtimeType}).',
        );
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        _deletionMaintenance.remove(userId);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId != null) unawaited(_maintainPhotoNoteDeletions(userId));
      _coordinator?.triggerNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
