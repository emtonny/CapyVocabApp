import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../application/lesson_completion_sync_coordinator.dart';
import '../../application/lesson_completion_sync_worker.dart';
import '../../data/remote/supabase_lesson_completion_sync_gateway.dart';
import 'lesson_session_provider.dart';

const lessonResultSyncEnabled = bool.fromEnvironment(
  'LESSON_RESULT_SYNC_ENABLED',
  defaultValue: true,
);

const _networkStatusChannel = MethodChannel(
  'com.capyvocab.app/network_status',
);

Future<bool> _isNetworkAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    return await _networkStatusChannel.invokeMethod<bool>(
          'isNetworkAvailable',
        ) ??
        false;
  } on PlatformException catch (error) {
    debugPrint('Lesson sync network status unavailable: ${error.code}');
    return false;
  } on MissingPluginException {
    debugPrint('Lesson sync network status channel is not registered.');
    return false;
  }
}

final lessonCompletionSyncCoordinatorProvider =
    FutureProvider<LessonCompletionSyncCoordinator?>((ref) async {
  if (!lessonResultSyncEnabled) return null;
  final store = await ref.watch(lessonSessionStoreProvider.future);
  final worker = LessonCompletionSyncWorker(
    store: store,
    gateway: SupabaseLessonCompletionSyncGateway(SupabaseService.client),
  );
  final coordinator = LessonCompletionSyncCoordinator(
    store: store,
    drain: worker.drainOnce,
    networkAvailable: _isNetworkAvailable,
    onError: (error, stackTrace) {
      debugPrint('Lesson completion sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
  ref.onDispose(() => unawaited(coordinator.dispose()));
  return coordinator;
});

Future<void> retryLessonCompletionSync(
  WidgetRef ref, {
  required String userId,
  required String resultId,
}) async {
  final store = await ref.read(lessonSessionStoreProvider.future);
  await store.retryFailed(
    userId: userId,
    resultId: resultId,
    now: DateTime.now().toUtc(),
  );
  final coordinator =
      await ref.read(lessonCompletionSyncCoordinatorProvider.future);
  coordinator?.triggerNow();
}
