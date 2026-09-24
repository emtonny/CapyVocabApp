import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/friend_phone_verification_datasource.dart';
import '../../data/datasources/friends_supabase_datasource.dart';
import '../../data/friends_network_status_native.dart'
    if (dart.library.js_interop) '../../data/friends_network_status_web.dart'
    as network;
import '../../data/local/friends_database.dart';
import '../../data/local/friends_store.dart';
import '../../data/repositories/cached_friends_repository.dart';
import '../../domain/entities/friend_entity.dart';
import '../../domain/friend_phone_verification.dart';
import '../../domain/repositories/friends_repository.dart';

final friendsEnabledProvider = Provider<bool>(
    (_) => const bool.fromEnvironment('FRIENDS_ENABLED', defaultValue: false));

final friendsClientProvider =
    Provider<SupabaseClient>((_) => SupabaseService.client);

final friendsSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(friendsClientProvider);
  return Stream.multi((controller) {
    final subscription = client.auth.onAuthStateChange.listen(
      (state) => controller.add(state.session),
      onError: (Object _) => controller.add(null),
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    controller.add(client.auth.currentSession);
  });
});

final friendsOwnerProvider = Provider<FriendOwner?>((ref) {
  if (!ref.watch(friendsEnabledProvider)) return null;
  final client = ref.watch(friendsClientProvider);
  ref.watch(friendsSessionProvider);
  final url = Uri.tryParse(client.rest.url);
  if (url?.scheme != 'https' ||
      url?.host != '${FriendsSupabaseDataSource.stagingRef}.supabase.co') {
    return null;
  }
  final session = client.auth.currentSession;
  if (session == null) return null;
  return FriendOwner(
    projectRef: FriendsSupabaseDataSource.stagingRef,
    userId: session.user.id,
  );
});

final friendsNetworkProvider =
    Provider<Future<bool> Function()>((_) => network.friendsNetworkAvailable);

final friendsDatabaseProvider = FutureProvider<FriendsDatabase>((ref) async {
  var live = true;
  FriendsDatabase? resource;
  ref.onDispose(() {
    live = false;
    unawaited(resource?.close());
  });
  final database = await createFriendsDatabase();
  resource = database;
  if (!live) {
    await database.close();
    throw StateError('Friends database disposed.');
  }
  return database;
});

final friendsRepositoryProvider = FutureProvider.autoDispose
    .family<FriendsRepository?, FriendOwner>((ref, owner) async {
  if (ref.watch(friendsOwnerProvider) != owner) return null;
  final client = ref.watch(friendsClientProvider);
  ref.watch(friendsSessionProvider);
  final session = client.auth.currentSession;
  if (session == null || session.user.id != owner.userId) return null;
  var live = true;
  CachedFriendsRepository? resource;
  ref.onDispose(() {
    live = false;
    unawaited(resource?.dispose());
  });
  bool current() =>
      live &&
      ref.read(friendsOwnerProvider) == owner &&
      client.auth.currentSession?.user.id == owner.userId &&
      client.auth.currentSession?.accessToken == session.accessToken;
  final local = await ref.watch(friendsDatabaseProvider.future);
  if (!current()) return null;
  final database = await local.open();
  if (!current()) return null;
  final key = client.realtime.params['apikey'];
  if (key is! String || key.isEmpty) {
    throw StateError('Friends public key unavailable.');
  }
  final repository = CachedFriendsRepository(
    remote: FriendsSupabaseDataSource.staging(
      owner: owner,
      session: session,
      publishableKey: key,
      isCurrentSession: current,
    ),
    store: FriendsStore(database: database, owner: owner),
    isCurrentSession: current,
  );
  resource = repository;
  return repository;
});

final friendDiscoverySettingsProvider = FutureProvider.autoDispose
    .family<FriendDiscoverySettings?, FriendOwner>((ref, owner) async {
  if (ref.watch(friendsOwnerProvider) != owner) return null;
  final repository = await ref.watch(friendsRepositoryProvider(owner).future);
  if (repository == null || ref.read(friendsOwnerProvider) != owner) {
    return null;
  }
  return repository.getDiscoverySettings();
});

final friendPhoneVerificationProvider = Provider.autoDispose
    .family<FriendPhoneVerificationGateway?, FriendOwner>((ref, owner) {
  if (ref.watch(friendsOwnerProvider) != owner) return null;
  final client = ref.watch(friendsClientProvider);
  ref.watch(friendsSessionProvider);
  final session = client.auth.currentSession;
  if (session == null || session.user.id != owner.userId) return null;
  bool current() =>
      ref.read(friendsOwnerProvider) == owner &&
      client.auth.currentSession?.user.id == owner.userId;
  return FriendPhoneVerificationDataSource(
    client: client,
    owner: owner,
    isCurrentSession: current,
  );
});

enum FriendSearchPhase {
  idle,
  invalid,
  waiting,
  searching,
  found,
  notFound,
  failure,
}

class FriendsState {
  const FriendsState({
    this.ready = false,
    this.method = FriendSearchMethod.username,
    this.query = '',
    this.phase = FriendSearchPhase.idle,
    this.validationMessage,
    this.result,
    this.message,
    this.isSending = false,
  });

  final bool ready;
  final FriendSearchMethod method;
  final String query;
  final FriendSearchPhase phase;
  final String? validationMessage;
  final FriendConnection? result;
  final String? message;
  final bool isSending;

  FriendsState copyWith({
    bool? ready,
    FriendSearchMethod? method,
    String? query,
    FriendSearchPhase? phase,
    Object? validationMessage = _unset,
    Object? result = _unset,
    Object? message = _unset,
    bool? isSending,
  }) {
    return FriendsState(
      ready: ready ?? this.ready,
      method: method ?? this.method,
      query: query ?? this.query,
      phase: phase ?? this.phase,
      validationMessage: identical(validationMessage, _unset)
          ? this.validationMessage
          : validationMessage as String?,
      result:
          identical(result, _unset) ? this.result : result as FriendConnection?,
      message: identical(message, _unset) ? this.message : message as String?,
      isSending: isSending ?? this.isSending,
    );
  }
}

const Object _unset = Object();

final friendsSearchProvider = StateNotifierProvider.autoDispose
    .family<FriendsNotifier, FriendsState, FriendOwner>((ref, owner) {
  final repository = ref.watch(friendsRepositoryProvider(owner)).asData?.value;
  final notifier = FriendsNotifier(
    owner: owner,
    repository: repository,
    networkAvailable: ref.watch(friendsNetworkProvider),
  );
  return notifier;
});

class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier({
    required this.owner,
    required FriendsRepository? repository,
    required Future<bool> Function() networkAvailable,
    Duration debounce = const Duration(milliseconds: 350),
  })  : _repository = repository,
        _networkAvailable = networkAvailable,
        _debounce = debounce,
        super(FriendsState(ready: repository != null)) {
    if (repository != null) {
      _signalSubscription = repository.remoteSignals.listen((signal) {
        if (signal != FriendRemoteSignal.disconnected &&
            state.result != null &&
            !state.isSending) {
          retrySearch();
        }
      });
    }
  }

  final FriendOwner owner;
  final FriendsRepository? _repository;
  final Future<bool> Function() _networkAvailable;
  final Duration _debounce;
  Timer? _timer;
  StreamSubscription<FriendRemoteSignal>? _signalSubscription;
  int _generation = 0;

  void selectMethod(FriendSearchMethod method) {
    if (state.method == method || state.isSending) return;
    _cancelPending();
    state = FriendsState(ready: state.ready, method: method);
  }

  void queryChanged(String value) {
    _cancelPending();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        query: value,
        phase: FriendSearchPhase.idle,
        validationMessage: null,
        result: null,
        message: null,
      );
      return;
    }
    final validation = validateFriendSearchQuery(state.method, value);
    if (validation != null) {
      state = state.copyWith(
        query: value,
        phase: FriendSearchPhase.invalid,
        validationMessage: validation,
        result: null,
        message: null,
      );
      return;
    }
    state = state.copyWith(
      query: value,
      phase: FriendSearchPhase.waiting,
      validationMessage: null,
      result: null,
      message: null,
    );
    final generation = _generation;
    _timer = Timer(_debounce, () => _search(generation));
  }

  void searchNow() {
    if (validateFriendSearchQuery(state.method, state.query) != null ||
        state.query.trim().isEmpty ||
        state.isSending) {
      return;
    }
    _timer?.cancel();
    final generation = ++_generation;
    unawaited(_search(generation));
  }

  void retrySearch() {
    if (state.query.trim().isEmpty || state.isSending) return;
    searchNow();
  }

  Future<void> _search(int generation) async {
    if (generation != _generation || !mounted) return;
    final repository = _repository;
    if (repository == null) {
      if (generation == _generation) {
        state = state.copyWith(
          phase: FriendSearchPhase.failure,
          result: null,
          message: 'Chức năng Bạn bè chưa sẵn sàng. Hãy thử lại sau.',
        );
      }
      return;
    }
    final method = state.method;
    final query = normalizeFriendSearchQuery(method, state.query);
    state = state.copyWith(
      phase: FriendSearchPhase.searching,
      result: null,
      message: null,
    );
    try {
      if (!await _networkAvailable()) {
        throw const FriendException(
          FriendFailureKind.offline,
          'Bạn đang offline. Hãy kết nối mạng và thử lại.',
        );
      }
      if (generation != _generation || !mounted) return;
      final result = await repository.searchFriend(
        method: method,
        query: query,
      );
      if (generation != _generation || !mounted) return;
      state = state.copyWith(
        phase: result == null
            ? FriendSearchPhase.notFound
            : FriendSearchPhase.found,
        result: result,
        message: result == null ? 'Không tìm thấy tài khoản phù hợp.' : null,
      );
    } catch (error) {
      if (generation != _generation || !mounted) return;
      state = state.copyWith(
        phase: FriendSearchPhase.failure,
        result: null,
        message: friendErrorMessage(error),
      );
    }
  }

  Future<void> sendRequest() async {
    final repository = _repository;
    final result = state.result;
    if (repository == null ||
        result == null ||
        result.state != FriendRelationshipState.none ||
        state.isSending) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isSending: true, message: null);
    try {
      if (!await _networkAvailable()) {
        throw const FriendException(
          FriendFailureKind.offline,
          'Bạn đang offline. Hãy kết nối mạng và thử lại.',
        );
      }
      if (generation != _generation || !mounted) return;
      final mutation = await repository.sendRequest(result.profile.id);
      if (generation != _generation || !mounted) return;
      final relationship = switch (mutation) {
        FriendMutationResult.outgoingPending =>
          FriendRelationshipState.outgoingPending,
        FriendMutationResult.incomingPending =>
          FriendRelationshipState.incomingPending,
        FriendMutationResult.alreadyAccepted ||
        FriendMutationResult.accepted =>
          FriendRelationshipState.accepted,
        FriendMutationResult.rejected => FriendRelationshipState.rejected,
      };
      state = state.copyWith(
        isSending: false,
        phase: FriendSearchPhase.found,
        result: FriendConnection(
          profile: result.profile,
          state: relationship,
          updatedAt: result.updatedAt,
        ),
        message: relationship == FriendRelationshipState.outgoingPending
            ? 'Đã gửi lời mời kết bạn.'
            : null,
      );
      try {
        final kind = switch (relationship) {
          FriendRelationshipState.outgoingPending => FriendListKind.outgoing,
          FriendRelationshipState.incomingPending => FriendListKind.incoming,
          FriendRelationshipState.accepted => FriendListKind.accepted,
          _ => null,
        };
        if (kind != null) await repository.refresh(kind);
      } catch (_) {
        // The mutation result is authoritative. Realtime or the next explicit
        // refresh will reconcile the optional local list cache.
      }
    } catch (error) {
      if (generation != _generation || !mounted) return;
      state = state.copyWith(
        isSending: false,
        message: friendErrorMessage(error),
      );
    }
  }

  void _cancelPending() {
    _timer?.cancel();
    _generation++;
  }

  @override
  void dispose() {
    _cancelPending();
    unawaited(_signalSubscription?.cancel());
    super.dispose();
  }
}

String normalizeFriendSearchQuery(FriendSearchMethod method, String value) {
  final trimmed = value.trim();
  return switch (method) {
    FriendSearchMethod.username ||
    FriendSearchMethod.email =>
      trimmed.toLowerCase(),
    FriendSearchMethod.phone => () {
        var normalized = trimmed.replaceAll(RegExp(r'[\s().-]'), '');
        if (normalized.startsWith('+84') && normalized.length == 12) {
          normalized = '0${normalized.substring(3)}';
        }
        return normalized;
      }(),
  };
}

String? validateFriendSearchQuery(FriendSearchMethod method, String value) {
  final normalized = normalizeFriendSearchQuery(method, value);
  return switch (method) {
    FriendSearchMethod.username =>
      RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(normalized)
          ? null
          : 'Username gồm 3–20 ký tự: chữ thường, số hoặc dấu gạch dưới.',
    FriendSearchMethod.email => normalized.length <= 320 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)
        ? null
        : 'Email chưa đúng định dạng. Ví dụ: ban@example.com',
    FriendSearchMethod.phone =>
      RegExp(r'^[+0-9\s().-]+$').hasMatch(value.trim()) &&
              RegExp(r'^0[0-9]{9}$').hasMatch(normalized)
          ? null
          : 'Nhập số Việt Nam gồm 10 số hoặc dạng +84.',
  };
}

String friendErrorMessage(Object error) {
  if (error is FriendException) {
    return switch (error.kind) {
      FriendFailureKind.offline =>
        'Bạn đang offline. Hãy kết nối mạng và thử lại.',
      FriendFailureKind.rateLimited =>
        'Bạn tìm kiếm quá nhanh. Hãy chờ một phút rồi thử lại.',
      FriendFailureKind.unauthenticated =>
        'Phiên đăng nhập đã thay đổi. Hãy mở lại mục Bạn bè.',
      FriendFailureKind.selfRequest => 'Bạn không thể tự kết bạn với mình.',
      FriendFailureKind.contactNotVerified =>
        'Thông tin liên hệ chưa được xác minh.',
      FriendFailureKind.phoneConflict =>
        'Số điện thoại tài khoản khác số đã lưu trong hồ sơ.',
      FriendFailureKind.alreadyAccepted => 'Hai bạn đã là bạn bè.',
      FriendFailureKind.incomingPending => 'Người này đã gửi lời mời cho bạn.',
      FriendFailureKind.staleRequest ||
      FriendFailureKind.conflict =>
        'Trạng thái lời mời đã thay đổi. Hãy tìm lại.',
      FriendFailureKind.invalidUsername ||
      FriendFailureKind.invalidEmail ||
      FriendFailureKind.invalidPhone ||
      FriendFailureKind.invalidInput =>
        'Thông tin tìm kiếm chưa hợp lệ.',
      FriendFailureKind.userNotFound ||
      FriendFailureKind.notFound =>
        'Không tìm thấy tài khoản phù hợp.',
      _ => 'Chưa thể kết nối dịch vụ Bạn bè. Hãy thử lại.',
    };
  }
  return 'Chưa thể kết nối dịch vụ Bạn bè. Hãy thử lại.';
}
