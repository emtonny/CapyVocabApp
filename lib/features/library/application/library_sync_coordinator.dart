import 'dart:async';

import '../domain/entities/local_account.dart';
import '../domain/repositories/consent_repository.dart';
import '../domain/repositories/sync_repository.dart';
import 'library_sync_worker.dart';

typedef SyncDrain = Future<SyncDrainResult> Function({
  required String userId,
  int limit,
});

/// Returns whether more server-side pages remain after this bounded pull.
typedef SyncPull = Future<bool> Function({required String userId});
typedef SyncErrorReporter = void Function(Object error, StackTrace stackTrace);
typedef SyncNetworkAvailability = Future<bool> Function();

/// Keeps one authenticated account's outbox moving while the app is alive.
final class LibrarySyncCoordinator {
  LibrarySyncCoordinator({
    required SyncRepository operations,
    required ConsentRepository consent,
    required SyncDrain drain,
    SyncPull? pull,
    required SyncErrorReporter onError,
    SyncNetworkAvailability? networkAvailable,
    DateTime Function()? clock,
    this.minimumWakeDelay = const Duration(milliseconds: 100),
    this.failureWakeDelay = const Duration(seconds: 30),
    this.maximumFailureWakeDelay = const Duration(minutes: 15),
  })  : _operations = operations,
        _consent = consent,
        _drain = drain,
        _pull = pull,
        _onError = onError,
        _networkAvailable = networkAvailable ?? (() async => true),
        _clock = clock ?? (() => DateTime.now().toUtc()) {
    if (minimumWakeDelay < Duration.zero ||
        failureWakeDelay <= Duration.zero ||
        maximumFailureWakeDelay < failureWakeDelay) {
      throw ArgumentError.value(
        (
          minimumWakeDelay,
          failureWakeDelay,
          maximumFailureWakeDelay,
        ),
        'wake delays',
        'minimum must not be negative; failure delay must be positive and '
            'not exceed its maximum',
      );
    }
  }

  final SyncRepository _operations;
  final ConsentRepository _consent;
  final SyncDrain _drain;
  final SyncPull? _pull;
  final SyncErrorReporter _onError;
  final SyncNetworkAvailability _networkAvailable;
  final DateTime Function() _clock;
  final Duration minimumWakeDelay;
  final Duration failureWakeDelay;
  final Duration maximumFailureWakeDelay;

  StreamSubscription<int>? _operationSubscription;
  StreamSubscription<int>? _purgeOperationSubscription;
  StreamSubscription<LocalAccount?>? _accountSubscription;
  Timer? _wakeTimer;
  String? _userId;
  bool _cloudBackupEnabled = false;
  bool _draining = false;
  bool _drainAgain = false;
  bool _disposed = false;
  int _outstandingCount = 0;
  int _outstandingPurgeCount = 0;
  int _userTransition = 0;
  int _consecutiveFailures = 0;

  Future<void> setUser(String? userId) async {
    if (_disposed) return;
    final transition = ++_userTransition;
    _cancelWake();
    final previousOperationSubscription = _operationSubscription;
    final previousPurgeOperationSubscription = _purgeOperationSubscription;
    final previousAccountSubscription = _accountSubscription;
    _operationSubscription = null;
    _purgeOperationSubscription = null;
    _accountSubscription = null;
    _userId = userId;
    _cloudBackupEnabled = false;
    _outstandingCount = 0;
    _outstandingPurgeCount = 0;
    _consecutiveFailures = 0;
    await previousOperationSubscription?.cancel();
    await previousPurgeOperationSubscription?.cancel();
    await previousAccountSubscription?.cancel();
    if (_disposed || transition != _userTransition || userId == null) return;

    _accountSubscription =
        _consent.watchLocalAccount(userId: userId).listen(_onAccountChanged);
    _operationSubscription = _operations
        .watchOperationCount(userId: userId)
        .listen(_onOperationCountChanged);
    _purgeOperationSubscription = _operations
        .watchPendingPurgeCount(userId: userId)
        .listen(_onPurgeOperationCountChanged);
  }

  void triggerNow() {
    if (_disposed ||
        _userId == null ||
        !_cloudBackupEnabled && _outstandingPurgeCount == 0) {
      return;
    }
    _cancelWake();
    unawaited(_run());
  }

  void _onAccountChanged(LocalAccount? account) {
    _cloudBackupEnabled = account?.cloudBackupEnabled == true;
    if (!_cloudBackupEnabled) {
      _cancelWake();
      if (_outstandingPurgeCount > 0) triggerNow();
      return;
    }
    if (_pull != null || _outstandingCount > 0) triggerNow();
  }

  void _onOperationCountChanged(int count) {
    _outstandingCount = count;
    if (count == 0) {
      _cancelWake();
      return;
    }
    if (_cloudBackupEnabled) triggerNow();
  }

  void _onPurgeOperationCountChanged(int count) {
    _outstandingPurgeCount = count;
    if (count > 0) triggerNow();
  }

  Future<void> _run() async {
    if (_draining) {
      _drainAgain = true;
      return;
    }
    final userId = _userId;
    if (userId == null ||
        _disposed ||
        !_cloudBackupEnabled && _outstandingPurgeCount == 0) {
      return;
    }
    _draining = true;
    var failed = false;
    var networkUnavailable = false;
    try {
      networkUnavailable = !await _networkAvailable();
      if (!networkUnavailable) {
        do {
          _drainAgain = false;
          final result = await _drain(userId: userId, limit: 100);
          if (result.skippedForConsent) {
            _cloudBackupEnabled = false;
            break;
          }
          if (await _pull?.call(userId: userId) == true) {
            _drainAgain = true;
          }
        } while (_drainAgain &&
            !_disposed &&
            _userId == userId &&
            _cloudBackupEnabled);
      }
    } catch (error, stackTrace) {
      failed = true;
      _onError(error, stackTrace);
    } finally {
      _draining = false;
    }
    if (!_disposed && _userId == userId && _cloudBackupEnabled) {
      if (failed || networkUnavailable) {
        _scheduleFailureWake();
      } else if (_outstandingCount > 0) {
        _consecutiveFailures = 0;
        try {
          await _scheduleNextRetry(userId);
        } catch (error, stackTrace) {
          _onError(error, stackTrace);
          _scheduleFailureWake();
        }
      } else {
        _consecutiveFailures = 0;
      }
    }
  }

  void _scheduleFailureWake() {
    var delay = failureWakeDelay;
    for (var i = 0;
        i < _consecutiveFailures && delay < maximumFailureWakeDelay;
        i++) {
      final doubled = delay + delay;
      delay =
          doubled > maximumFailureWakeDelay ? maximumFailureWakeDelay : doubled;
    }
    _consecutiveFailures++;
    _cancelWake();
    _wakeTimer = Timer(delay, triggerNow);
  }

  Future<void> _scheduleNextRetry(String userId) async {
    final nextRetryAt = await _operations.getNextRetryAt(userId: userId);
    if (nextRetryAt == null || _disposed || _userId != userId) return;
    final remaining = nextRetryAt.difference(_clock().toUtc());
    final delay = remaining > minimumWakeDelay ? remaining : minimumWakeDelay;
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
    _userTransition++;
    _cancelWake();
    await _operationSubscription?.cancel();
    await _purgeOperationSubscription?.cancel();
    await _accountSubscription?.cancel();
  }
}
