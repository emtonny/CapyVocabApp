import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../data/cached_groups_repository.dart';
import '../data/groups_supabase_gateway.dart';
import '../data/local/groups_database.dart';
import '../data/local/groups_store.dart';
import '../domain/group_models.dart';
import '../domain/groups_repository.dart';

final groupsEnabledProvider = Provider<bool>(
  (_) => const bool.fromEnvironment('GROUPS_ENABLED', defaultValue: true),
);

final groupsClientProvider = Provider<SupabaseClient>(
  (_) => SupabaseService.client,
);

final groupsSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(groupsClientProvider);
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

final groupsOwnerProvider = Provider<GroupOwner?>((ref) {
  if (!ref.watch(groupsEnabledProvider)) return null;
  final client = ref.watch(groupsClientProvider);
  ref.watch(groupsSessionProvider);
  final url = Uri.tryParse(client.rest.url);
  if (url?.scheme != 'https' ||
      url?.host != '${GroupsSupabaseGateway.stagingRef}.supabase.co') {
    return null;
  }
  final session = client.auth.currentSession;
  if (session == null) return null;
  return GroupOwner(
    projectRef: GroupsSupabaseGateway.stagingRef,
    userId: session.user.id,
  );
});

final groupsDatabaseProvider = FutureProvider<GroupsDatabase>((ref) async {
  var live = true;
  GroupsDatabase? resource;
  ref.onDispose(() {
    live = false;
    unawaited(resource?.close());
  });
  final database = await createGroupsDatabase();
  resource = database;
  if (!live) {
    await database.close();
    throw StateError('Groups database disposed.');
  }
  return database;
});

final groupsRepositoryProvider = FutureProvider.autoDispose
    .family<GroupsRepository?, GroupOwner>((ref, owner) async {
  if (ref.watch(groupsOwnerProvider) != owner) return null;
  final client = ref.watch(groupsClientProvider);
  ref.watch(groupsSessionProvider);
  final session = client.auth.currentSession;
  if (session == null || session.user.id != owner.userId) return null;
  var live = true;
  CachedGroupsRepository? resource;
  ref.onDispose(() {
    live = false;
    unawaited(resource?.dispose());
  });
  bool current() =>
      live &&
      ref.read(groupsOwnerProvider) == owner &&
      client.auth.currentSession?.user.id == owner.userId &&
      client.auth.currentSession?.accessToken == session.accessToken;
  final local = await ref.watch(groupsDatabaseProvider.future);
  if (!current()) return null;
  final database = await local.open();
  if (!current()) return null;
  final key = client.realtime.params['apikey'];
  if (key is! String || key.isEmpty) {
    throw StateError('Groups public key unavailable.');
  }
  final repository = CachedGroupsRepository(
    remote: GroupsSupabaseGateway.staging(
      owner: owner,
      session: session,
      publishableKey: key,
      isCurrentSession: current,
    ),
    store: GroupsStore(database: database, owner: owner),
    isCurrentSession: current,
  );
  resource = repository;
  return repository;
});

final groupsWorkspaceProvider = StateNotifierProvider.autoDispose
    .family<GroupsNotifier, GroupsState, GroupOwner>((ref, owner) {
  final repository = ref.watch(groupsRepositoryProvider(owner)).asData?.value;
  return GroupsNotifier(owner: owner, repository: repository);
});

final class GroupsState {
  const GroupsState({
    this.ready = false,
    this.groups = const [],
    this.capabilities,
    this.refreshedAt,
    this.isRefreshing = false,
    this.isMutating = false,
    this.message,
  });

  final bool ready;
  final List<LearningGroupSummary> groups;
  final GroupCapabilities? capabilities;
  final DateTime? refreshedAt;
  final bool isRefreshing;
  final bool isMutating;
  final String? message;

  bool get canManageGroups => capabilities?.canManageGroups ?? false;

  GroupsState copyWith({
    bool? ready,
    List<LearningGroupSummary>? groups,
    Object? capabilities = _unset,
    Object? refreshedAt = _unset,
    bool? isRefreshing,
    bool? isMutating,
    Object? message = _unset,
  }) {
    return GroupsState(
      ready: ready ?? this.ready,
      groups: groups ?? this.groups,
      capabilities: identical(capabilities, _unset)
          ? this.capabilities
          : capabilities as GroupCapabilities?,
      refreshedAt: identical(refreshedAt, _unset)
          ? this.refreshedAt
          : refreshedAt as DateTime?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isMutating: isMutating ?? this.isMutating,
      message: identical(message, _unset) ? this.message : message as String?,
    );
  }
}

const Object _unset = Object();

final class GroupsNotifier extends StateNotifier<GroupsState> {
  GroupsNotifier({required this.owner, required GroupsRepository? repository})
      : _repository = repository,
        super(GroupsState(ready: repository != null)) {
    if (repository != null) unawaited(_start());
  }

  final GroupOwner owner;
  final GroupsRepository? _repository;
  StreamSubscription<List<LearningGroupSummary>>? _cacheSubscription;
  StreamSubscription<GroupRemoteSignal>? _remoteSubscription;
  bool _disposed = false;

  Future<void> _start() async {
    final repository = _repository!;
    _cacheSubscription = repository.watchCached().listen(
      (groups) {
        if (!_disposed) state = state.copyWith(ready: true, groups: groups);
      },
      onError: (Object _) {
        if (!_disposed) {
          state = state.copyWith(
            ready: true,
            message: 'Không đọc được cache nhóm học trên máy.',
          );
        }
      },
    );
    _remoteSubscription = repository.remoteSignals.listen((signal) {
      if (signal == GroupRemoteSignal.changed && !_disposed) {
        unawaited(refresh());
      }
    });
    final refreshed = await repository.refreshedAt();
    if (!_disposed) state = state.copyWith(refreshedAt: refreshed);
    await refresh();
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null || _disposed || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, message: null);
    try {
      final capabilities = await repository.getCapabilities();
      await repository.refresh();
      final refreshedAt = await repository.refreshedAt();
      if (!_disposed) {
        state = state.copyWith(
          ready: true,
          capabilities: capabilities,
          refreshedAt: refreshedAt,
          isRefreshing: false,
        );
      }
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          ready: true,
          capabilities: null,
          isRefreshing: false,
          message: error.message,
        );
      }
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          ready: true,
          capabilities: null,
          isRefreshing: false,
          message: 'Chưa thể làm mới nhóm học.',
        );
      }
    }
  }

  Future<bool> createGroup({
    required String title,
    required String description,
  }) async {
    final repository = _repository;
    if (repository == null || _disposed || state.isMutating) return false;
    if (!state.canManageGroups) {
      state = state.copyWith(
          message: 'Tài khoản chưa có quyền giáo viên đã xác minh.');
      return false;
    }
    state = state.copyWith(isMutating: true, message: null);
    try {
      await repository.createGroup(
        title: title,
        description: description,
        requestId: createGroupRequestId(),
      );
      if (!_disposed) state = state.copyWith(isMutating: false);
      return true;
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(isMutating: false, message: error.message);
      }
      return false;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          isMutating: false,
          message: 'Không thể tạo lớp lúc này.',
        );
      }
      return false;
    }
  }

  Future<bool> requestJoin(String inviteToken) async {
    final repository = _repository;
    if (repository == null || _disposed || state.isMutating) return false;
    state = state.copyWith(isMutating: true, message: null);
    try {
      await repository.requestJoin(
        inviteToken: inviteToken,
        requestId: createGroupRequestId(),
      );
      if (!_disposed) state = state.copyWith(isMutating: false);
      return true;
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(isMutating: false, message: error.message);
      }
      return false;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          isMutating: false,
          message: 'Không thể gửi yêu cầu tham gia lúc này.',
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_cacheSubscription?.cancel());
    unawaited(_remoteSubscription?.cancel());
    super.dispose();
  }
}

String createGroupRequestId([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
