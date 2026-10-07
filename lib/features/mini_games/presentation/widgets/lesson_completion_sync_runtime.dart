import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../providers/lesson_completion_sync_provider.dart';

class LessonCompletionSyncRuntime extends ConsumerStatefulWidget {
  const LessonCompletionSyncRuntime({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LessonCompletionSyncRuntime> createState() =>
      _LessonCompletionSyncRuntimeState();
}

class _LessonCompletionSyncRuntimeState
    extends ConsumerState<LessonCompletionSyncRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  String? _requestedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = SupabaseService.auth.onAuthStateChange.listen(
      (state) => unawaited(_setUser(state.session?.user.id)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Lesson sync auth stream failed: $error');
      },
    );
    unawaited(_setUser(SupabaseService.auth.currentUser?.id));
  }

  Future<void> _setUser(String? userId) async {
    _requestedUserId = userId;
    try {
      final coordinator =
          await ref.read(lessonCompletionSyncCoordinatorProvider.future);
      if (!mounted || _requestedUserId != userId) return;
      await coordinator?.setUser(userId);
      coordinator?.triggerNow();
    } catch (error, stackTrace) {
      debugPrint('Lesson sync runtime failed to start: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeSync());
    }
  }

  Future<void> _resumeSync() async {
    final coordinator =
        await ref.read(lessonCompletionSyncCoordinatorProvider.future);
    coordinator?.triggerNow();
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
