import 'dart:async';
import 'dart:developer' as developer;

import '../data/operational_chat_store.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_relay.dart';

enum ChatSyncOutcome { idle, offline, synchronized, superseded, failed }

/// Session-bound background work. Local reads/enqueue never await this flight.
/// Timers run only while started, foreground, and still the captured session.
final class OperationalChatCoordinator {
  OperationalChatCoordinator({
    required this.store,
    required this.remote,
    required this.isCurrentSession,
    required this.networkAvailable,
    required this.cachedSourceLanguageCode,
    DateTime Function()? clock,
    this.repairInterval = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now {
    if (repairInterval <= Duration.zero) {
      throw ArgumentError('Invalid chat repair interval.');
    }
    _relay = _newRelay();
  }

  final OperationalChatStore store;
  final OperationalChatGateway remote;
  final bool Function() isCurrentSession;
  final Future<bool> Function() networkAvailable;
  final String? Function() cachedSourceLanguageCode;
  final Duration repairInterval;
  final DateTime Function() _clock;
  late OperationalChatRelay _relay;
  StreamSubscription<ChatRemoteSignal>? _subscription;
  Future<ChatSyncOutcome>? _flight;
  Future<void>? _disposal;
  Timer? _timer;
  bool _closed = false;
  bool _foreground = true;
  bool _started = false;
  bool _online = false;
  bool _refreshRequested = true;
  bool _repairSocket = false;
  int _epoch = 0;
  int _invalidation = 0;
  int _refreshVersion = 0;
  int _socketRevision = 0;
  int _scheduleGeneration = 0;
  int _failures = 0;
  String _syncStage = 'idle';
  DateTime? _retryAt;
  DateTime? _nextRepairAt;
  DateTime? _nextWakeAt;
  DateTime? get nextWakeAt => _nextWakeAt;
  bool get _active => !_closed && _foreground && isCurrentSession();
  DateTime get _now => _clock().toUtc();
  bool _valid(int epoch) => _active && epoch == _epoch;

  String? get _source {
    final code = cachedSourceLanguageCode();
    return {'vi', 'en'}.contains(code) ? code : null;
  }

  OperationalChatRelay _newRelay() {
    final epoch = _epoch;
    return OperationalChatRelay(
        store: store,
        transport: remote,
        isCurrentOwner: () => _valid(epoch),
        canReachNetwork: () => _online,
        cachedSourceLanguageCode: () => _source,
        clock: _clock);
  }

  void start() {
    if (_closed || _started) return;
    _started = true;
    requestRefresh();
    unawaited(synchronize());
  }

  void requestRefresh({bool supersede = true}) {
    if (_closed) return;
    _refreshVersion++;
    if (supersede) _invalidation++;
    _refreshRequested = true;
    _scheduleSafely();
  }

  void setForeground(bool foreground) {
    if (_closed || _foreground == foreground) return;
    _foreground = foreground;
    _epoch++;
    _relay.dispose();
    _relay = _newRelay();
    _online = false;
    _timer?.cancel();
    _nextWakeAt = null;
    _scheduleGeneration++;
    unawaited(_detachRealtime());
    if (foreground) {
      _retryAt = null;
      requestRefresh();
    }
  }

  Future<OperationalChatMessage> enqueue(
      {required String conversationId, required String rawText}) async {
    final code = _source;
    if (!_active || code == null) {
      throw StateError('Chat language profile required.');
    }
    final message = await _relay.enqueue(
        conversationId: conversationId,
        rawText: rawText,
        sourceLanguageCode: code);
    _scheduleSafely();
    return message;
  }

  Future<ChatConversation> openDirectChat(String peerId) async {
    if (!_active || _source == null) {
      throw StateError('Chat language profile required.');
    }
    final epoch = _epoch;
    if (!await networkAvailable().timeout(const Duration(seconds: 3)) ||
        !_valid(epoch)) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
    final conversation = await remote.openDirectChat(peerId);
    if (!_valid(epoch)) throw const ChatRefreshSuperseded();
    final revision = store.revision;
    await store.applyConversationRefresh(
        conversations: [conversation],
        capturedIds: {},
        visibleIds: {conversation.id},
        expectedRevision: revision,
        isCurrent: () => _valid(epoch));
    requestRefresh();
    return conversation;
  }

  Future<ChatSyncOutcome> synchronize() {
    if (!_active || (_retryAt != null && _now.isBefore(_retryAt!))) {
      return Future.value(ChatSyncOutcome.idle);
    }
    return _flight ??= _run(_epoch).whenComplete(() {
      _flight = null;
      _scheduleSafely();
    });
  }

  Future<ChatSyncOutcome> _run(int epoch) async {
    try {
      _syncStage = 'network';
      final available =
          await networkAvailable().timeout(const Duration(seconds: 3));
      if (!_valid(epoch)) return ChatSyncOutcome.idle;
      _online = available;
      if (!available) {
        await _detachRealtime();
        _backoff();
        return ChatSyncOutcome.offline;
      }
      if (_subscription == null) {
        _syncStage = 'realtime_attach';
        _subscription = remote.signals.listen(_onSignal,
            onError: (Object _) => _onSignal(ChatRemoteSignal.disconnected),
            onDone: () => _onSignal(ChatRemoteSignal.disconnected));
      } else if (_repairSocket) {
        _syncStage = 'realtime_restart';
        final socketRevision = _socketRevision;
        await remote.restartRealtime();
        if (!_valid(epoch)) return ChatSyncOutcome.idle;
        _repairSocket = socketRevision != _socketRevision;
      }

      _syncStage = 'outbox';
      await _relay.synchronize(); // raw outbox before potentially slow history
      if (!_valid(epoch)) return ChatSyncOutcome.idle;
      if (_refreshRequested ||
          _nextRepairAt == null ||
          !_now.isBefore(_nextRepairAt!)) {
        final refreshVersion = _refreshVersion;
        await _refresh(epoch);
        if (!_valid(epoch)) return ChatSyncOutcome.idle;
        _refreshRequested = refreshVersion != _refreshVersion;
        _nextRepairAt = _now.add(repairInterval);
      }
      if (!_repairSocket) {
        _retryAt = null;
        _failures = 0;
      }
      _syncStage = 'idle';
      return ChatSyncOutcome.synchronized;
    } on ChatRefreshSuperseded {
      _refreshRequested = true;
      return ChatSyncOutcome.superseded;
    } catch (error) {
      _debug('failed_$_syncStage (${error.runtimeType})');
      if (_valid(epoch)) {
        _refreshRequested = true;
        _backoff();
      }
      return ChatSyncOutcome.failed;
    }
  }

  void _debug(String event) {
    assert(() {
      developer.log('Operational chat sync: $event', name: 'capy.chat.sync');
      return true;
    }());
  }

  Future<void> _refresh(int epoch) async {
    final invalidation = _invalidation;
    bool current() => _valid(epoch) && invalidation == _invalidation;
    var revision = store.revision;
    _syncStage = 'conversation_cache_read';
    final captured = (await store.conversations()).map((c) => c.id).toSet();
    _syncStage = 'conversation_fetch';
    final inventory = await remote.fetchConversations();
    if (!current()) throw const ChatRefreshSuperseded();
    _syncStage = 'conversation_visibility';
    final visible = await remote.visibleConversationIds(
        captured.union(inventory.map((c) => c.id).toSet()));
    _syncStage = 'conversation_commit';
    await store.applyConversationRefresh(
        conversations: inventory,
        capturedIds: captured,
        visibleIds: visible,
        expectedRevision: revision,
        isCurrent: current);
    for (final conversation in await store.conversations()) {
      if (!current()) throw const ChatRefreshSuperseded();
      revision = store.revision;
      _syncStage = 'history_cache_read';
      final cachedIds = (await store.messages(conversation.id))
          .where((m) => m.sendStatus == ChatSendStatus.sent)
          .map((m) => m.id)
          .toSet();
      _syncStage = 'history_fetch';
      final history = await remote.fetchHistory(conversation.id);
      if (!current()) throw const ChatRefreshSuperseded();
      _syncStage = 'history_visibility';
      final visibleIds = await remote.visibleCachedIds(
          conversation.id, cachedIds.union(history.map((m) => m.id).toSet()));
      _syncStage = 'history_commit';
      await store.applyHistoryRefresh(
          conversationId: conversation.id,
          messages: history,
          capturedSentIds: cachedIds,
          visibleIds: visibleIds,
          expectedRevision: revision,
          isCurrent: current);
    }
    if (!current()) throw const ChatRefreshSuperseded();
  }

  void _onSignal(ChatRemoteSignal signal) {
    if (!_active || !_online) return;
    if (signal == ChatRemoteSignal.disconnected) {
      _socketRevision++;
      _repairSocket = true;
      _backoff();
    } else if (signal == ChatRemoteSignal.connected) {
      _repairSocket = false;
      _retryAt = null;
      _failures = 0;
    }
    requestRefresh(supersede: signal == ChatRemoteSignal.changed);
  }

  void _backoff() {
    _retryAt =
        _now.add(Duration(seconds: (2 << _failures.clamp(0, 7)).clamp(2, 300)));
    _failures = (_failures + 1).clamp(0, 8);
  }

  Future<void> _detachRealtime() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _scheduleSafely() {
    unawaited(_schedule().catchError((Object _) {
      if (!_active || !_started) return;
      _backoff();
      _timer?.cancel();
      _nextWakeAt = _retryAt;
      _timer =
          Timer(_retryAt!.difference(_now), () => unawaited(synchronize()));
    }));
  }

  Future<void> _schedule() async {
    final generation = ++_scheduleGeneration;
    _timer?.cancel();
    _nextWakeAt = null;
    if (!_started || !_active || _flight != null) return;
    final now = _now;
    var deadline = _refreshRequested
        ? now.add(const Duration(milliseconds: 150))
        : (_nextRepairAt ?? now);
    final source = _source;
    if (source != null) {
      final pending =
          await store.nextPendingAt(now, sourceLanguageCode: source);
      if (pending != null && pending.isBefore(deadline)) deadline = pending;
    }
    if (generation != _scheduleGeneration ||
        !_started ||
        !_active ||
        _flight != null) {
      return;
    }
    if (_retryAt != null && deadline.isBefore(_retryAt!)) deadline = _retryAt!;
    final minimum = _now.add(const Duration(milliseconds: 10));
    if (deadline.isBefore(minimum)) deadline = minimum;
    _nextWakeAt = deadline;
    _timer = Timer(deadline.difference(_now), () => unawaited(synchronize()));
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _closed = true;
    _epoch++;
    _scheduleGeneration++;
    _relay.dispose();
    _timer?.cancel();
    _nextWakeAt = null;
    await _detachRealtime();
    await _flight;
    await remote.dispose();
  }
}
