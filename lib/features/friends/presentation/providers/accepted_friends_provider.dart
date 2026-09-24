import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/operational_chat_provider.dart';
import '../../domain/entities/friend_entity.dart';
import '../../domain/repositories/friends_repository.dart';
import 'friends_provider.dart';

enum FriendChatAvailability {
  ready,
  ownLanguageProfileRequired,
  unavailable,
}

class FriendChatAccess {
  const FriendChatAccess._(this.availability, this.openDirectChat);

  const FriendChatAccess.ready(Future<String> Function(String) openDirectChat)
      : this._(FriendChatAvailability.ready, openDirectChat);

  const FriendChatAccess.ownLanguageProfileRequired()
      : this._(FriendChatAvailability.ownLanguageProfileRequired, null);

  const FriendChatAccess.unavailable()
      : this._(FriendChatAvailability.unavailable, null);

  final FriendChatAvailability availability;
  final Future<String> Function(String peerId)? openDirectChat;

  bool get canOpen =>
      availability == FriendChatAvailability.ready && openDirectChat != null;
}

final friendChatAccessProvider = Provider.autoDispose
    .family<FriendChatAccess, FriendOwner>((ref, friendOwner) {
  final chatOwner = ref.watch(operationalChatOwnerProvider);
  if (chatOwner == null ||
      chatOwner.projectRef != friendOwner.projectRef ||
      chatOwner.userId != friendOwner.userId) {
    return const FriendChatAccess.unavailable();
  }
  final source = ref.watch(operationalChatSourceProvider(chatOwner));
  if (source.isLoading || source.hasError) {
    return const FriendChatAccess.unavailable();
  }
  if (source.asData?.value == null) {
    return const FriendChatAccess.ownLanguageProfileRequired();
  }
  return FriendChatAccess.ready((peerId) async {
    if (ref.read(friendsOwnerProvider) != friendOwner ||
        ref.read(operationalChatOwnerProvider) != chatOwner) {
      throw const FriendRefreshSuperseded();
    }
    final coordinator =
        await ref.read(operationalChatCoordinatorProvider.future);
    if (coordinator == null ||
        ref.read(friendsOwnerProvider) != friendOwner ||
        ref.read(operationalChatOwnerProvider) != chatOwner) {
      throw const FriendRefreshSuperseded();
    }
    return (await coordinator.openDirectChat(peerId)).id;
  });
});

class AcceptedFriendsState {
  const AcceptedFriendsState({
    this.ready = false,
    this.cacheLoaded = false,
    this.items = const [],
    this.refreshing = false,
    this.openingPeerId,
    this.error,
    this.message,
  });

  final bool ready;
  final bool cacheLoaded;
  final List<FriendConnection> items;
  final bool refreshing;
  final String? openingPeerId;
  final String? error;
  final String? message;

  AcceptedFriendsState copyWith({
    bool? ready,
    bool? cacheLoaded,
    List<FriendConnection>? items,
    bool? refreshing,
    Object? openingPeerId = _unset,
    Object? error = _unset,
    Object? message = _unset,
  }) {
    return AcceptedFriendsState(
      ready: ready ?? this.ready,
      cacheLoaded: cacheLoaded ?? this.cacheLoaded,
      items: items ?? this.items,
      refreshing: refreshing ?? this.refreshing,
      openingPeerId: identical(openingPeerId, _unset)
          ? this.openingPeerId
          : openingPeerId as String?,
      error: identical(error, _unset) ? this.error : error as String?,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }
}

const Object _unset = Object();

final acceptedFriendsProvider = StateNotifierProvider.autoDispose
    .family<AcceptedFriendsNotifier, AcceptedFriendsState, FriendOwner>(
        (ref, owner) {
  final repository = ref.watch(friendsRepositoryProvider(owner)).asData?.value;
  return AcceptedFriendsNotifier(
    owner: owner,
    repository: repository,
    networkAvailable: ref.watch(friendsNetworkProvider),
  );
});

class AcceptedFriendsNotifier extends StateNotifier<AcceptedFriendsState> {
  AcceptedFriendsNotifier({
    required this.owner,
    required FriendsRepository? repository,
    required Future<bool> Function() networkAvailable,
  })  : _repository = repository,
        _networkAvailable = networkAvailable,
        super(AcceptedFriendsState(ready: repository != null)) {
    if (repository != null) unawaited(_start());
  }

  final FriendOwner owner;
  final FriendsRepository? _repository;
  final Future<bool> Function() _networkAvailable;
  StreamSubscription<List<FriendConnection>>? _cacheSubscription;
  StreamSubscription<FriendRemoteSignal>? _remoteSubscription;
  Future<void>? _activeRefresh;

  Future<void> _start() async {
    final repository = _repository!;
    try {
      final cached = await repository.readCached(FriendListKind.accepted);
      if (!mounted) return;
      _applyItems(cached, cacheLoaded: true);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        cacheLoaded: true,
        error: friendErrorMessage(error),
      );
    }
    if (!mounted) return;
    _cacheSubscription = repository.watchCached(FriendListKind.accepted).listen(
      (items) {
        if (mounted) _applyItems(items, cacheLoaded: true);
      },
      onError: (Object error) {
        if (mounted) state = state.copyWith(error: friendErrorMessage(error));
      },
    );
    try {
      _remoteSubscription = repository.remoteSignals.listen(
        (signal) {
          if (signal != FriendRemoteSignal.disconnected) {
            unawaited(refresh());
          }
        },
        onError: (Object error) {
          if (mounted) state = state.copyWith(error: friendErrorMessage(error));
        },
      );
    } catch (error) {
      if (mounted) state = state.copyWith(error: friendErrorMessage(error));
      return;
    }
    await refresh();
  }

  Future<void> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _refresh().whenComplete(() {
      if (identical(_activeRefresh, operation)) _activeRefresh = null;
    });
    _activeRefresh = operation;
    return operation;
  }

  Future<void> _refresh() async {
    final repository = _repository;
    if (repository == null || !mounted) return;
    state = state.copyWith(refreshing: true, error: null);
    try {
      await _requireNetwork();
      if (!mounted) return;
      await repository.refresh(FriendListKind.accepted);
      if (mounted) state = state.copyWith(error: null);
    } catch (error) {
      if (mounted) state = state.copyWith(error: friendErrorMessage(error));
    } finally {
      if (mounted) state = state.copyWith(refreshing: false);
    }
  }

  Future<String?> openChat({
    required String peerId,
    required Future<String> Function(String peerId) openDirectChat,
  }) async {
    final repository = _repository;
    if (repository == null || state.openingPeerId != null) return null;
    final normalizedPeer = validateFriendUuid(peerId, field: 'peerId');
    if (!_containsAccepted(normalizedPeer)) return null;
    state = state.copyWith(openingPeerId: normalizedPeer, message: null);
    try {
      await _requireNetwork();
      if (!mounted) return null;
      await repository.refresh(FriendListKind.accepted);
      if (!mounted) return null;
      final current = await repository.readCached(FriendListKind.accepted);
      if (!mounted) return null;
      _applyItems(current, cacheLoaded: true);
      if (!_containsAccepted(normalizedPeer)) {
        throw const FriendException(
          FriendFailureKind.staleRequest,
          'The accepted relationship is no longer active.',
        );
      }
      final conversationId = await openDirectChat(normalizedPeer);
      if (!mounted) return null;
      return validateFriendUuid(conversationId, field: 'conversationId');
    } catch (error) {
      if (mounted) {
        state = state.copyWith(message: friendChatErrorMessage(error));
      }
      return null;
    } finally {
      if (mounted) state = state.copyWith(openingPeerId: null);
    }
  }

  Future<void> _requireNetwork() async {
    if (!await _networkAvailable()) {
      throw const FriendException(
        FriendFailureKind.offline,
        'Bạn đang offline. Hãy kết nối mạng và thử lại.',
      );
    }
  }

  bool _containsAccepted(String peerId) => state.items.any(
        (item) =>
            item.profile.id == peerId &&
            item.state == FriendRelationshipState.accepted,
      );

  void _applyItems(
    List<FriendConnection> items, {
    required bool cacheLoaded,
  }) {
    state = state.copyWith(
      items: List.unmodifiable(items.where(
        (item) => item.state == FriendRelationshipState.accepted,
      )),
      cacheLoaded: cacheLoaded,
    );
  }

  void clearMessage() {
    if (state.message != null) state = state.copyWith(message: null);
  }

  @override
  void dispose() {
    unawaited(_cacheSubscription?.cancel());
    unawaited(_remoteSubscription?.cancel());
    super.dispose();
  }
}

String friendChatErrorMessage(Object error) {
  if (error is FriendException) {
    return switch (error.kind) {
      FriendFailureKind.offline =>
        'Bạn đang offline. Hãy kết nối mạng rồi thử mở Chat lại.',
      FriendFailureKind.staleRequest ||
      FriendFailureKind.notFound =>
        'Quan hệ bạn bè đã thay đổi. Danh sách vừa được cập nhật.',
      FriendFailureKind.unauthenticated =>
        'Phiên đăng nhập đã thay đổi. Hãy mở lại mục Bạn bè.',
      _ =>
        'Chưa mở được Chat. Cần mạng, hồ sơ ngôn ngữ của cả hai và quan hệ bạn bè đang hoạt động.',
    };
  }
  return 'Chưa mở được Chat. Cần mạng, hồ sơ ngôn ngữ của cả hai và quan hệ bạn bè đang hoạt động.';
}
