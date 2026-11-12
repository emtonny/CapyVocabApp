import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/daily_mission.dart';
import '../providers/daily_mission_provider.dart';

/// Keeps the account's immutable daily mission current without blocking UI.
class DailyMissionRuntime extends ConsumerStatefulWidget {
  const DailyMissionRuntime({
    required this.child,
    this.currentUserId,
    this.authUserIds,
    super.key,
  });

  final Widget child;
  final String? Function()? currentUserId;
  final Stream<String?>? authUserIds;

  @override
  ConsumerState<DailyMissionRuntime> createState() =>
      _DailyMissionRuntimeState();
}

class _DailyMissionRuntimeState extends ConsumerState<DailyMissionRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<String?>? _authSubscription;
  Timer? _midnightTimer;
  String? _requestedUserId;

  String? get _currentUserId =>
      widget.currentUserId?.call() ?? SupabaseService.auth.currentUser?.id;

  Stream<String?> get _authUserIds =>
      widget.authUserIds ??
      SupabaseService.auth.onAuthStateChange
          .map((state) => state.session?.user.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _authUserIds.listen(
      (userId) => unawaited(_setUser(userId)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Daily mission auth stream failed: $error');
      },
    );
    unawaited(_setUser(_currentUserId));
  }

  Future<void> _setUser(String? userId) async {
    _requestedUserId = userId;
    _midnightTimer?.cancel();
    _midnightTimer = null;
    final current = ref.read(currentDailyMissionProvider);
    if (userId == null || current?.userId != userId) {
      ref.read(currentDailyMissionProvider.notifier).state = null;
    }
    if (userId == null) return;
    await _ensure(userId);
  }

  Future<void> _ensure(String userId) async {
    try {
      final coordinator =
          await ref.read(dailyMissionCoordinatorProvider.future);
      if (!mounted || _requestedUserId != userId) return;
      final mission = await coordinator.ensureCurrent(userId);
      if (!mounted || _requestedUserId != userId || mission == null) return;
      ref.read(currentDailyMissionProvider.notifier).state = mission;
      _scheduleNextBoundary(userId, mission);
    } catch (error, stackTrace) {
      debugPrint('Daily mission refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _scheduleNextBoundary(String userId, DailyMission mission) {
    _midnightTimer?.cancel();
    final delay = mission.endsAt.difference(DateTime.now().toUtc());
    _midnightTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_ensure(userId)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final userId = _currentUserId;
      if (userId != null) unawaited(_setUser(userId));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
