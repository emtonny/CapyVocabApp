import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStatus { unknown, incomplete, complete }

/// Owner-scoped, synchronously readable onboarding cache.
///
/// This cache only controls navigation UX. Supabase remains authoritative and
/// server-side RLS remains the authorization boundary.
abstract class OnboardingStatusStore extends ChangeNotifier {
  OnboardingStatus statusFor(String userId);

  Future<void> setStatus(String userId, OnboardingStatus status);
}

class MemoryOnboardingStatusStore extends OnboardingStatusStore {
  final Map<String, OnboardingStatus> _statuses = {};

  @override
  OnboardingStatus statusFor(String userId) =>
      _statuses[userId] ?? OnboardingStatus.unknown;

  @override
  Future<void> setStatus(String userId, OnboardingStatus status) async {
    if (_statuses[userId] == status) return;
    if (status == OnboardingStatus.unknown) {
      _statuses.remove(userId);
    } else {
      _statuses[userId] = status;
    }
    notifyListeners();
  }
}

class SharedPreferencesOnboardingStatusStore extends OnboardingStatusStore {
  SharedPreferencesOnboardingStatusStore._(this._preferences);

  static const _keyPrefix = 'onboarding_status_v1.';
  static const _completeValue = 'complete';
  static const _incompleteValue = 'incomplete';

  final SharedPreferences _preferences;
  final Map<String, OnboardingStatus> _statuses = {};

  static Future<SharedPreferencesOnboardingStatusStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesOnboardingStatusStore._(preferences);
    store._hydrate();
    return store;
  }

  void _hydrate() {
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final userId = key.substring(_keyPrefix.length);
      if (userId.isEmpty) continue;
      switch (_preferences.getString(key)) {
        case _completeValue:
          _statuses[userId] = OnboardingStatus.complete;
          break;
        case _incompleteValue:
          _statuses[userId] = OnboardingStatus.incomplete;
          break;
      }
    }
  }

  @override
  OnboardingStatus statusFor(String userId) =>
      _statuses[userId] ?? OnboardingStatus.unknown;

  @override
  Future<void> setStatus(String userId, OnboardingStatus status) async {
    if (_statuses[userId] == status) return;

    final key = '$_keyPrefix$userId';
    if (status == OnboardingStatus.unknown) {
      _statuses.remove(userId);
      notifyListeners();
      try {
        await _preferences.remove(key);
      } catch (_) {
        debugPrint('Unable to persist onboarding status cache.');
      }
      return;
    }

    _statuses[userId] = status;
    notifyListeners();
    try {
      await _preferences.setString(
        key,
        status == OnboardingStatus.complete ? _completeValue : _incompleteValue,
      );
    } catch (_) {
      // Server success must not be presented as an auth/onboarding failure.
      // The in-memory status remains valid and unknown fails open after restart.
      debugPrint('Unable to persist onboarding status cache.');
    }
  }
}

typedef LoadRemoteOnboardingStatus = Future<bool> Function(String userId);
typedef OnboardingRefreshClock = DateTime Function();

Future<void> resetOnboardingAndUpdateCache({
  required String? userId,
  required Future<void> Function() resetRemote,
  required OnboardingStatusStore store,
}) async {
  await resetRemote();
  if (userId != null) {
    await store.setStatus(userId, OnboardingStatus.incomplete);
  }
}

/// Refreshes the cache away from routing, deduplicating concurrent requests
/// and suppressing repeated offline attempts with exponential backoff.
class OnboardingStatusRefresher {
  OnboardingStatusRefresher({
    required OnboardingStatusStore store,
    required LoadRemoteOnboardingStatus loadRemoteStatus,
    OnboardingRefreshClock? clock,
    this.initialBackoff = const Duration(seconds: 30),
    this.maximumBackoff = const Duration(minutes: 15),
  })  : _store = store,
        _loadRemoteStatus = loadRemoteStatus,
        _clock = clock ?? DateTime.now;

  final OnboardingStatusStore _store;
  final LoadRemoteOnboardingStatus _loadRemoteStatus;
  final OnboardingRefreshClock _clock;
  final Duration initialBackoff;
  final Duration maximumBackoff;
  final Map<String, Future<void>> _inFlight = {};
  final Map<String, DateTime> _retryAfter = {};
  final Map<String, Duration> _nextBackoff = {};

  Future<void> refresh(String userId, {bool force = false}) {
    final existing = _inFlight[userId];
    if (existing != null) return existing;

    final retryAfter = _retryAfter[userId];
    if (!force && retryAfter != null && _clock().isBefore(retryAfter)) {
      return Future<void>.value();
    }

    final operation = _performRefresh(userId);
    _inFlight[userId] = operation;
    operation.whenComplete(() => _inFlight.remove(userId));
    return operation;
  }

  Future<void> _performRefresh(String userId) async {
    try {
      final completed = await _loadRemoteStatus(userId);
      await _store.setStatus(
        userId,
        completed ? OnboardingStatus.complete : OnboardingStatus.incomplete,
      );
      _retryAfter.remove(userId);
      _nextBackoff.remove(userId);
    } catch (_) {
      final delay = _nextBackoff[userId] ?? initialBackoff;
      _retryAfter[userId] = _clock().add(delay);
      _nextBackoff[userId] = _doubleCapped(delay);
    }
  }

  Duration _doubleCapped(Duration duration) {
    final doubled = Duration(microseconds: duration.inMicroseconds * 2);
    return doubled > maximumBackoff ? maximumBackoff : doubled;
  }
}
