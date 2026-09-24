import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/friend_entity.dart';
import '../../domain/repositories/friends_repository.dart';
import 'friends_provider.dart';

class FriendRequestsState {
  const FriendRequestsState({
    this.ready = false,
    this.incomingCacheLoaded = false,
    this.outgoingCacheLoaded = false,
    this.incoming = const [],
    this.outgoing = const [],
    this.refreshing = const {},
    this.responding = const {},
    this.incomingError,
    this.outgoingError,
    this.message,
  });

  final bool ready;
  final bool incomingCacheLoaded;
  final bool outgoingCacheLoaded;
  final List<FriendConnection> incoming;
  final List<FriendConnection> outgoing;
  final Set<FriendListKind> refreshing;
  final Map<String, FriendDecision> responding;
  final String? incomingError;
  final String? outgoingError;
  final String? message;

  int get incomingCount => incoming.length;

  FriendRequestsState copyWith({
    bool? ready,
    bool? incomingCacheLoaded,
    bool? outgoingCacheLoaded,
    List<FriendConnection>? incoming,
    List<FriendConnection>? outgoing,
    Set<FriendListKind>? refreshing,
    Map<String, FriendDecision>? responding,
    Object? incomingError = _unset,
    Object? outgoingError = _unset,
    Object? message = _unset,
  }) {
    return FriendRequestsState(
      ready: ready ?? this.ready,
      incomingCacheLoaded: incomingCacheLoaded ?? this.incomingCacheLoaded,
      outgoingCacheLoaded: outgoingCacheLoaded ?? this.outgoingCacheLoaded,
      incoming: incoming ?? this.incoming,
      outgoing: outgoing ?? this.outgoing,
      refreshing: refreshing ?? this.refreshing,
      responding: responding ?? this.responding,
      incomingError: identical(incomingError, _unset)
          ? this.incomingError
          : incomingError as String?,
      outgoingError: identical(outgoingError, _unset)
          ? this.outgoingError
          : outgoingError as String?,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }
}

const Object _unset = Object();

final friendRequestsProvider = StateNotifierProvider.autoDispose
    .family<FriendRequestsNotifier, FriendRequestsState, FriendOwner>(
        (ref, owner) {
  final repository = ref.watch(friendsRepositoryProvider(owner)).asData?.value;
  return FriendRequestsNotifier(
    owner: owner,
    repository: repository,
    networkAvailable: ref.watch(friendsNetworkProvider),
  );
});

class FriendRequestsNotifier extends StateNotifier<FriendRequestsState> {
  FriendRequestsNotifier({
    required this.owner,
    required FriendsRepository? repository,
    required Future<bool> Function() networkAvailable,
  })  : _repository = repository,
        _networkAvailable = networkAvailable,
        super(FriendRequestsState(ready: repository != null)) {
    if (repository != null) unawaited(_start());
  }

  final FriendOwner owner;
  final FriendsRepository? _repository;
  final Future<bool> Function() _networkAvailable;
  final Map<FriendListKind, Future<void>> _refreshes = {};
  final Set<String> _resolvedIncoming = {};
  final List<StreamSubscription<List<FriendConnection>>> _cacheSubscriptions =
      [];
  StreamSubscription<FriendRemoteSignal>? _remoteSubscription;

  Future<void> _start() async {
    await Future.wait([
      _hydrate(FriendListKind.incoming),
      _hydrate(FriendListKind.outgoing),
    ]);
    if (!mounted) return;
    final repository = _repository!;
    try {
      _remoteSubscription = repository.remoteSignals.listen(
        (signal) {
          if (signal != FriendRemoteSignal.disconnected) {
            unawaited(refreshAll());
          }
        },
        onError: (Object error) {
          if (mounted) _setBothErrors(friendErrorMessage(error));
        },
      );
    } catch (error) {
      if (mounted) _setBothErrors(friendErrorMessage(error));
      return;
    }
    await refreshAll();
  }

  Future<void> _hydrate(FriendListKind kind) async {
    final repository = _repository!;
    try {
      final cached = await repository.readCached(kind);
      if (!mounted) return;
      _applyItems(kind, cached, cacheLoaded: true);
    } catch (error) {
      if (!mounted) return;
      _setError(kind, friendErrorMessage(error), cacheLoaded: true);
    }
    if (!mounted) return;
    final subscription = repository.watchCached(kind).listen(
      (items) {
        if (mounted) _applyItems(kind, items, cacheLoaded: true);
      },
      onError: (Object error) {
        if (mounted) {
          _setError(kind, friendErrorMessage(error), cacheLoaded: true);
        }
      },
    );
    _cacheSubscriptions.add(subscription);
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refresh(FriendListKind.incoming),
      refresh(FriendListKind.outgoing),
    ]);
  }

  Future<void> refresh(FriendListKind kind) {
    if (kind == FriendListKind.accepted) {
      return _repository?.refresh(kind) ?? Future.value();
    }
    final active = _refreshes[kind];
    if (active != null) return active;
    late final Future<void> operation;
    operation = _refresh(kind).whenComplete(() {
      if (identical(_refreshes[kind], operation)) _refreshes.remove(kind);
    });
    _refreshes[kind] = operation;
    return operation;
  }

  Future<void> _refresh(FriendListKind kind) async {
    final repository = _repository;
    if (repository == null || !mounted) return;
    state = state.copyWith(
      refreshing: {...state.refreshing, kind},
      incomingError:
          kind == FriendListKind.incoming ? null : state.incomingError,
      outgoingError:
          kind == FriendListKind.outgoing ? null : state.outgoingError,
    );
    try {
      if (!await _networkAvailable()) {
        throw const FriendException(
          FriendFailureKind.offline,
          'Bạn đang offline. Hãy kết nối mạng và thử lại.',
        );
      }
      if (!mounted) return;
      await repository.refresh(kind);
      if (!mounted) return;
      if (kind == FriendListKind.incoming) _resolvedIncoming.clear();
      _setError(kind, null);
    } catch (error) {
      if (mounted) _setError(kind, friendErrorMessage(error));
    } finally {
      if (mounted) {
        final refreshing = {...state.refreshing}..remove(kind);
        state = state.copyWith(refreshing: refreshing);
      }
    }
  }

  Future<void> respond(String peerId, FriendDecision decision) async {
    final repository = _repository;
    if (repository == null || state.responding.containsKey(peerId)) return;
    final request = state.incoming
        .where((connection) => connection.profile.id == peerId)
        .firstOrNull;
    if (request == null) return;
    state = state.copyWith(
      responding: {...state.responding, peerId: decision},
      message: null,
    );
    try {
      if (!await _networkAvailable()) {
        throw const FriendException(
          FriendFailureKind.offline,
          'Bạn đang offline. Hãy kết nối mạng và thử lại.',
        );
      }
      if (!mounted) return;
      final result = await repository.respondToRequest(
        requesterId: peerId,
        decision: decision,
      );
      if (!mounted) return;
      final valid = decision == FriendDecision.accept
          ? result == FriendMutationResult.accepted ||
              result == FriendMutationResult.alreadyAccepted
          : result == FriendMutationResult.rejected;
      if (!valid) {
        throw const FriendDataException(
          'The server returned an invalid friend response state.',
        );
      }
      _resolvedIncoming.add(peerId);
      state = state.copyWith(
        incoming: state.incoming
            .where((connection) => connection.profile.id != peerId)
            .toList(growable: false),
        message: decision == FriendDecision.accept
            ? 'Đã chấp nhận lời mời kết bạn.'
            : 'Đã từ chối lời mời kết bạn.',
      );
      await refresh(FriendListKind.incoming);
      if (decision == FriendDecision.accept && mounted) {
        try {
          await repository.refresh(FriendListKind.accepted);
        } catch (_) {
          // The mutation is already authoritative. Realtime or F5 will retry
          // the optional accepted-list cache reconciliation.
        }
      }
    } catch (error) {
      if (mounted) state = state.copyWith(message: friendErrorMessage(error));
    } finally {
      if (mounted) {
        final responding = {...state.responding}..remove(peerId);
        state = state.copyWith(responding: responding);
      }
    }
  }

  void clearMessage() {
    if (state.message != null) state = state.copyWith(message: null);
  }

  void _applyItems(
    FriendListKind kind,
    List<FriendConnection> items, {
    required bool cacheLoaded,
  }) {
    if (kind == FriendListKind.incoming) {
      state = state.copyWith(
        incoming: items
            .where(
              (connection) =>
                  !_resolvedIncoming.contains(connection.profile.id),
            )
            .toList(growable: false),
        incomingCacheLoaded: cacheLoaded,
      );
    } else if (kind == FriendListKind.outgoing) {
      state = state.copyWith(
        outgoing: List.unmodifiable(items),
        outgoingCacheLoaded: cacheLoaded,
      );
    }
  }

  void _setError(
    FriendListKind kind,
    String? error, {
    bool? cacheLoaded,
  }) {
    if (kind == FriendListKind.incoming) {
      state = state.copyWith(
        incomingError: error,
        incomingCacheLoaded: cacheLoaded,
      );
    } else if (kind == FriendListKind.outgoing) {
      state = state.copyWith(
        outgoingError: error,
        outgoingCacheLoaded: cacheLoaded,
      );
    }
  }

  void _setBothErrors(String error) {
    state = state.copyWith(
      incomingError: error,
      outgoingError: error,
    );
  }

  @override
  void dispose() {
    for (final subscription in _cacheSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_remoteSubscription?.cancel());
    super.dispose();
  }
}
