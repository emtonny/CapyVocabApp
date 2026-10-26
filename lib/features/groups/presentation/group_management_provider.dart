import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/group_models.dart';
import '../domain/groups_repository.dart';
import 'groups_provider.dart';

typedef GroupManagementKey = ({
  GroupOwner owner,
  String groupId,
  bool includeManagement,
});

final groupManagementProvider = StateNotifierProvider.autoDispose
    .family<GroupManagementNotifier, GroupManagementState, GroupManagementKey>(
  (ref, key) {
    final repository =
        ref.watch(groupsRepositoryProvider(key.owner)).asData?.value;
    return GroupManagementNotifier(
      groupId: key.groupId,
      includeManagement: key.includeManagement,
      repository: repository,
    );
  },
);

final class GroupManagementState {
  const GroupManagementState({
    this.ready = false,
    this.members = const [],
    this.announcements = const [],
    this.inviteStatus,
    this.moderationEvents = const [],
    this.offlineFallback = false,
    this.refreshedAt,
    this.isRefreshing = false,
    this.isMutating = false,
    this.message,
  });

  final bool ready;
  final List<LearningGroupMember> members;
  final List<LearningGroupAnnouncement> announcements;
  final LearningGroupInviteStatus? inviteStatus;
  final List<LearningGroupModerationEvent> moderationEvents;
  final bool offlineFallback;
  final DateTime? refreshedAt;
  final bool isRefreshing;
  final bool isMutating;
  final String? message;

  int get activeStudents => members
      .where((member) =>
          member.role == LearningGroupRole.student &&
          member.status == LearningGroupMembershipStatus.active)
      .length;
  int get pendingStudents => members
      .where((member) =>
          member.role == LearningGroupRole.student &&
          member.status == LearningGroupMembershipStatus.pending)
      .length;
  int get mutedStudents => members
      .where((member) =>
          member.role == LearningGroupRole.student && member.isMuted)
      .length;

  GroupManagementState copyWith({
    bool? ready,
    List<LearningGroupMember>? members,
    List<LearningGroupAnnouncement>? announcements,
    Object? inviteStatus = _unsetManagement,
    List<LearningGroupModerationEvent>? moderationEvents,
    bool? offlineFallback,
    Object? refreshedAt = _unsetManagement,
    bool? isRefreshing,
    bool? isMutating,
    Object? message = _unsetManagement,
  }) =>
      GroupManagementState(
        ready: ready ?? this.ready,
        members: members ?? this.members,
        announcements: announcements ?? this.announcements,
        inviteStatus: identical(inviteStatus, _unsetManagement)
            ? this.inviteStatus
            : inviteStatus as LearningGroupInviteStatus?,
        moderationEvents: moderationEvents ?? this.moderationEvents,
        offlineFallback: offlineFallback ?? this.offlineFallback,
        refreshedAt: identical(refreshedAt, _unsetManagement)
            ? this.refreshedAt
            : refreshedAt as DateTime?,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isMutating: isMutating ?? this.isMutating,
        message: identical(message, _unsetManagement)
            ? this.message
            : message as String?,
      );
}

const Object _unsetManagement = Object();

final class GroupManagementNotifier
    extends StateNotifier<GroupManagementState> {
  GroupManagementNotifier({
    required this.groupId,
    required this.includeManagement,
    required GroupsRepository? repository,
  })  : _repository = repository,
        super(const GroupManagementState()) {
    requireGroupUuid(groupId, 'groupId');
    if (repository != null) unawaited(refresh());
  }

  final String groupId;
  final bool includeManagement;
  final GroupsRepository? _repository;
  bool _disposed = false;

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null || _disposed || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, message: null);
    try {
      final details = await repository.loadDetails(
        groupId,
        includeManagement: includeManagement,
      );
      if (!_disposed) {
        state = state.copyWith(
          ready: true,
          members: details.members,
          announcements: details.announcements,
          inviteStatus: details.inviteStatus,
          moderationEvents: details.moderationEvents,
          offlineFallback: details.offlineFallback,
          refreshedAt: details.refreshedAt,
          isRefreshing: false,
        );
      }
    } on GroupException catch (error) {
      if (!_disposed) {
        final revoke = error.kind == GroupFailureKind.denied ||
            error.kind == GroupFailureKind.unauthenticated ||
            error.kind == GroupFailureKind.notFound;
        state = state.copyWith(
          ready: true,
          members: revoke ? const [] : null,
          announcements: revoke ? const [] : null,
          inviteStatus: revoke ? null : _unsetManagement,
          moderationEvents: revoke ? const [] : null,
          offlineFallback: revoke ? false : null,
          isRefreshing: false,
          message: error.message,
        );
      }
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          ready: true,
          isRefreshing: false,
          message: 'Chưa tải được bảng quản lý lớp.',
        );
      }
    }
  }

  Future<bool> respondJoin(String userId, {required bool approve}) => _mutate(
        () => _repository!.respondJoin(
          groupId: groupId,
          studentUserId: userId,
          approve: approve,
          requestId: createGroupRequestId(),
        ),
      );

  Future<bool> setMuted(String userId, {required bool muted}) => _mutate(
        () => _repository!.setMemberMute(
          groupId: groupId,
          studentUserId: userId,
          muted: muted,
          requestId: createGroupRequestId(),
        ),
      );

  Future<bool> removeMember(String userId) => _mutate(
        () => _repository!.removeMember(
          groupId: groupId,
          studentUserId: userId,
          requestId: createGroupRequestId(),
        ),
      );

  Future<bool> createAnnouncement(String body) => _mutate(
        () => _repository!.createAnnouncement(
          groupId: groupId,
          body: body,
          requestId: createGroupRequestId(),
        ),
      );

  Future<bool> setAnnouncementPinned(
    String announcementId, {
    required bool pinned,
  }) =>
      _mutate(
        () => _repository!.setAnnouncementPinned(
          groupId: groupId,
          announcementId: announcementId,
          pinned: pinned,
          requestId: createGroupRequestId(),
        ),
      );

  Future<LearningGroupInviteSecret?> rotateInvite() async {
    final repository = _repository;
    if (repository == null || _disposed || state.isMutating) return null;
    state = state.copyWith(isMutating: true, message: null);
    try {
      final result = await repository.rotateInvite(
        groupId: groupId,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
        requestId: createGroupRequestId(),
      );
      if (!_disposed) state = state.copyWith(isMutating: false);
      await refresh();
      return result;
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(isMutating: false, message: error.message);
      }
      return null;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          isMutating: false,
          message: 'Không thể xoay mã mời lúc này.',
        );
      }
      return null;
    }
  }

  Future<bool> revokeInvite() => _mutate(
        () => _repository!.revokeInvite(
          groupId: groupId,
          requestId: createGroupRequestId(),
        ),
      );

  Future<bool> archiveGroup() => _mutate(
        () => _repository!.archiveGroup(
          groupId: groupId,
          requestId: createGroupRequestId(),
        ),
        refreshAfter: false,
      );

  Future<String?> getConversationId() async {
    final repository = _repository;
    if (repository == null || _disposed || state.isMutating) return null;
    state = state.copyWith(isMutating: true, message: null);
    try {
      final id = await repository.getGroupConversationId(groupId);
      if (!_disposed) state = state.copyWith(isMutating: false);
      return id;
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(isMutating: false, message: error.message);
      }
      return null;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          isMutating: false,
          message: 'Không mở được chat nhóm lúc này.',
        );
      }
      return null;
    }
  }

  Future<bool> _mutate(
    Future<void> Function() action, {
    bool refreshAfter = true,
  }) async {
    if (_repository == null || _disposed || state.isMutating) return false;
    state = state.copyWith(isMutating: true, message: null);
    try {
      await action();
      if (!_disposed) state = state.copyWith(isMutating: false);
      if (refreshAfter) await refresh();
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
          message: 'Không thể cập nhật lớp lúc này.',
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
