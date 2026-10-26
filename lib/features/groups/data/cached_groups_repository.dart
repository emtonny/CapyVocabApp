import '../domain/group_models.dart';
import '../domain/groups_repository.dart';
import 'local/groups_store.dart';

final class CachedGroupsRepository implements GroupsRepository {
  CachedGroupsRepository({
    required this.remote,
    required this.store,
    required bool Function() isCurrentSession,
    DateTime Function()? now,
  })  : _isCurrentSession = isCurrentSession,
        _now = now ?? DateTime.now;

  final GroupsRemoteGateway remote;
  final GroupsStore store;
  final bool Function() _isCurrentSession;
  final DateTime Function() _now;
  Future<void>? _refreshing;
  bool _closed = false;

  @override
  Stream<GroupRemoteSignal> get remoteSignals => remote.signals;

  @override
  Stream<List<LearningGroupSummary>> watchCached() => store.watch();

  @override
  Future<List<LearningGroupSummary>> readCached() => store.list();

  @override
  Future<DateTime?> refreshedAt() => store.refreshedAt();

  @override
  Future<GroupCapabilities> getCapabilities() {
    _checkCurrent();
    return remote.getCapabilities();
  }

  @override
  Future<void> refresh() {
    _checkCurrent();
    final active = _refreshing;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _refresh().whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
    _refreshing = operation;
    return operation;
  }

  Future<void> _refresh() async {
    final groups = await remote.listGroups();
    _checkCurrent();
    await store.reconcileSnapshot(
      groups: groups,
      completedAt: _now().toUtc(),
      isCurrent: _isUsable,
    );
  }

  @override
  Future<String> createGroup({
    required String title,
    required String description,
    required String requestId,
  }) async {
    _checkCurrent();
    final id = await remote.createGroup(
      title: title,
      description: description,
      requestId: requestId,
    );
    await refresh();
    return id;
  }

  @override
  Future<String> requestJoin({
    required String inviteToken,
    required String requestId,
  }) async {
    _checkCurrent();
    final id = await remote.requestJoin(
      inviteToken: inviteToken,
      requestId: requestId,
    );
    await refresh();
    return id;
  }

  @override
  Future<List<LearningGroupMember>> listMembers(String groupId) =>
      _remote(() => remote.listMembers(groupId));

  @override
  Future<List<LearningGroupAnnouncement>> listAnnouncements(String groupId) =>
      _remote(() => remote.listAnnouncements(groupId));

  @override
  Future<LearningGroupDetails> loadDetails(
    String groupId, {
    required bool includeManagement,
  }) async {
    _checkCurrent();
    final cached = await store.readDetails(groupId);
    final compatibleCache =
        cached != null && includeManagement == cached.includesManagement
            ? cached
            : null;
    try {
      final results = await Future.wait<Object?>([
        remote.listMembers(groupId),
        remote.listAnnouncements(groupId),
        if (includeManagement)
          remote.getInviteStatus(groupId)
        else
          Future<LearningGroupInviteStatus?>.value(),
        if (includeManagement)
          remote.listModerationEvents(groupId)
        else
          Future<List<LearningGroupModerationEvent>>.value(const []),
      ]);
      _checkCurrent();
      await store.reconcileDetails(
        groupId: groupId,
        members: results[0] as List<LearningGroupMember>,
        announcements: results[1] as List<LearningGroupAnnouncement>,
        inviteStatus: results[2] as LearningGroupInviteStatus?,
        moderationEvents: results[3] as List<LearningGroupModerationEvent>,
        includesManagement: includeManagement,
        completedAt: _now().toUtc(),
        isCurrent: _isUsable,
      );
      _checkCurrent();
      final committed = await store.readDetails(groupId);
      if (committed == null) {
        throw const GroupDataException('Group detail cache commit failed.');
      }
      return committed;
    } on GroupException catch (error) {
      if (error.kind == GroupFailureKind.denied ||
          error.kind == GroupFailureKind.unauthenticated ||
          error.kind == GroupFailureKind.notFound) {
        await store.purgeDetails(groupId);
      } else if (error.kind == GroupFailureKind.unavailable &&
          compatibleCache != null) {
        _checkCurrent();
        return compatibleCache.asOfflineFallback();
      }
      rethrow;
    }
  }

  @override
  Future<List<LearningGroupSystemTask>> listSystemTasks(String groupId) =>
      _remote(() => remote.listSystemTasks(groupId));

  @override
  Future<bool> getVocabularySharing(String groupId) =>
      _remote(() => remote.getVocabularySharing(groupId));

  @override
  Future<void> setVocabularySharing({
    required String groupId,
    required bool enabled,
  }) =>
      _remote(() => remote.setVocabularySharing(
            groupId: groupId,
            enabled: enabled,
          ));

  @override
  Future<String> createSystemTask({
    required String groupId,
    required String title,
    required int targetWordCount,
    required DateTime dueAt,
    required String requestId,
  }) =>
      _remote(() => remote.createSystemTask(
            groupId: groupId,
            title: title,
            targetWordCount: targetWordCount,
            dueAt: dueAt,
            requestId: requestId,
          ));

  @override
  Future<void> closeSystemTask({
    required String groupId,
    required String taskId,
    required String requestId,
  }) =>
      _remote(() => remote.closeSystemTask(
            groupId: groupId,
            taskId: taskId,
            requestId: requestId,
          ));

  @override
  Future<List<LearningGroupStudentOverview>> listLearningOverview(
    String groupId,
  ) =>
      _remote(() => remote.listLearningOverview(groupId));

  @override
  Future<List<LearningGroupSharedVocabulary>> listStudentVocabulary({
    required String groupId,
    required String studentUserId,
    int limit = 200,
  }) =>
      _remote(() => remote.listStudentVocabulary(
            groupId: groupId,
            studentUserId: studentUserId,
            limit: limit,
          ));

  @override
  Future<void> respondJoin({
    required String groupId,
    required String studentUserId,
    required bool approve,
    required String requestId,
  }) =>
      _mutateAndRefresh(() => remote.respondJoin(
            groupId: groupId,
            studentUserId: studentUserId,
            approve: approve,
            requestId: requestId,
          ));

  @override
  Future<void> setMemberMute({
    required String groupId,
    required String studentUserId,
    required bool muted,
    required String requestId,
  }) =>
      _mutateAndRefresh(() => remote.setMemberMute(
            groupId: groupId,
            studentUserId: studentUserId,
            muted: muted,
            requestId: requestId,
          ));

  @override
  Future<void> removeMember({
    required String groupId,
    required String studentUserId,
    required String requestId,
  }) =>
      _mutateAndRefresh(() => remote.removeMember(
            groupId: groupId,
            studentUserId: studentUserId,
            requestId: requestId,
          ));

  @override
  Future<void> archiveGroup({
    required String groupId,
    required String requestId,
  }) =>
      _mutateAndRefresh(() => remote.archiveGroup(
            groupId: groupId,
            requestId: requestId,
          ));

  @override
  Future<LearningGroupInviteSecret> rotateInvite({
    required String groupId,
    required DateTime expiresAt,
    required String requestId,
  }) =>
      _remote(() => remote.rotateInvite(
            groupId: groupId,
            expiresAt: expiresAt,
            requestId: requestId,
          ));

  @override
  Future<void> revokeInvite({
    required String groupId,
    required String requestId,
  }) =>
      _remote(() => remote.revokeInvite(
            groupId: groupId,
            requestId: requestId,
          ));

  @override
  Future<void> createAnnouncement({
    required String groupId,
    required String body,
    required String requestId,
  }) =>
      _remote(() => remote.createAnnouncement(
            groupId: groupId,
            body: body,
            requestId: requestId,
          ));

  @override
  Future<void> setAnnouncementPinned({
    required String groupId,
    required String announcementId,
    required bool pinned,
    required String requestId,
  }) =>
      _remote(() => remote.setAnnouncementPinned(
            groupId: groupId,
            announcementId: announcementId,
            pinned: pinned,
            requestId: requestId,
          ));

  @override
  Future<String> getGroupConversationId(String groupId) =>
      _remote(() => remote.getGroupConversationId(groupId));

  Future<T> _remote<T>(Future<T> Function() action) async {
    _checkCurrent();
    final result = await action();
    _checkCurrent();
    return result;
  }

  Future<void> _mutateAndRefresh(Future<void> Function() action) async {
    await _remote(action);
    await refresh();
  }

  bool _isUsable() => !_closed && _isCurrentSession();

  void _checkCurrent() {
    if (!_isUsable()) throw const GroupSessionChanged();
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await remote.dispose();
    await store.dispose();
  }
}
