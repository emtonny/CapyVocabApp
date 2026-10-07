import 'dart:async';

import 'lesson_completion_sync_store.dart';
import 'lesson_completion_sync_worker.dart';

typedef LessonSyncDrain = Future<LessonSyncDrainResult> Function({
  required String userId,
  int limit,
});
typedef LessonSyncNetworkAvailability = Future<bool> Function();
typedef LessonSyncErrorReporter = void Function(
  Object error,
  StackTrace stackTrace,
);

final class LessonCompletionSyncCoordinator {
  LessonCompletionSyncCoordinator({
    required LessonCompletionSyncStore store,
    required LessonSyncDrain drain,
    required LessonSyncNetworkAvailability networkAvailable,
    required LessonSyncErrorReporter onError,
    DateTime Function()? clock,
    this.minimumWakeDelay = const Duration(milliseconds: 100),
    this.failureWakeDelay = const Duration(seconds: 30),
    this.maximumFailureWakeDelay = const Duration(minutes: 15),
  })  : _store = store,
        _drain = drain,
        _networkAvailable = networkAvailable,
        _onError = onError,
        _clock = clock ?? (() => DateTime.now().toUtc()) {
    if (minimumWakeDelay < Duration.zero ||
        failureWakeDelay <= Duration.zero ||
        maximumFailureWakeDelay < failureWakeDelay) {
      throw ArgumentError('Invalid lesson sync wake delays');
    }
  }

  final LessonCompletionSyncStore _store;
  final LessonSyncDrain _drain;
  final LessonSyncNetworkAvailability _networkAvailable;
  final LessonSyncErrorReporter _onError;
  final DateTime Function() _clock;
  final Duration minimumWakeDelay;
  final Duration failureWakeDelay;
  final Duration maximumFailureWakeDelay;

  StreamSubscription<void>? _changeSubscription;
  Timer? _wakeTimer;
  String? _userId;
  bool _draining = false;
  bool _drainAgain = false;
  bool _disposed = false;
  int _transition = 0;
  int _consecutiveNetworkFailures = 0;

  Future<void> setUser(String? userId) async {
    if (_disposed) return;
    final transition = ++_transition;
    _cancelWake();
    final previous = _changeSubscription;
    _changeSubscription = null;
    _userId = userId;
    _consecutiveNetworkFailures = 0;
    await previous?.cancel();
    if (_disposed || transition != _transition || userId == null) return;
    _changeSubscription = _store.watchChanges(userId).listen(
          (_) => triggerNow(),
          onError: _onError,
        );
  }

  void triggerNow() {
    if (_disposed || _userId == null) return;
    _cancelWake();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_draining) {
      _drainAgain = true;
      return;
    }
    final userId = _userId;
    if (_disposed || userId == null) return;
    _draining = true;
    var networkUnavailable = false;
    var failed = false;
    try {
      networkUnavailable = !await _networkAvailable();
      if (!networkUnavailable) {
        do {
          _drainAgain = false;
          await _drain(userId: userId, limit: 20);
        } while (_drainAgain && !_disposed && _userId == userId);
      }
    } catch (error, stackTrace) {
      failed = true;
      _onError(error, stackTrace);
    } finally {
      _draining = false;
    }
    if (_disposed || _userId != userId) return;
    if (networkUnavailable || failed) {
      _scheduleNetworkRetry();
      return;
    }
    _consecutiveNetworkFailures = 0;
    try {
      final outstanding = await _store.outstandingSyncCount(userId);
      if (outstanding == 0) return;
      final next = await _store.nextSyncAttemptAt(userId);
      if (next == null) return;
      final remaining = next.difference(_clock().toUtc());
      final delay = remaining > minimumWakeDelay ? remaining : minimumWakeDelay;
      _wakeTimer = Timer(delay, triggerNow);
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
      _scheduleNetworkRetry();
    }
  }

  void _scheduleNetworkRetry() {
    var delay = failureWakeDelay;
    for (var attempt = 0;
        attempt < _consecutiveNetworkFailures &&
            delay < maximumFailureWakeDelay;
        attempt++) {
      final doubled = delay + delay;
      delay =
          doubled > maximumFailureWakeDelay ? maximumFailureWakeDelay : doubled;
    }
    _consecutiveNetworkFailures++;
    _cancelWake();
    _wakeTimer = Timer(delay, triggerNow);
  }

  void _cancelWake() {
    _wakeTimer?.cancel();
    _wakeTimer = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _transition++;
    _cancelWake();
    await _changeSubscription?.cancel();
  }
}
