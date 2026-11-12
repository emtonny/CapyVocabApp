import 'group_models.dart';

abstract interface class GroupsRemoteGateway {
  Stream<GroupRemoteSignal> get signals;
  Future<GroupCapabilities> getCapabilities();
  Future<List<LearningGroupSummary>> listGroups();
  Future<String> createGroup({
    required String title,
    required String description,
    required String requestId,
  });
  Future<String> requestJoin({
    required String inviteToken,
    required String requestId,
  });
  Future<List<LearningGroupMember>> listMembers(String groupId);
  Future<List<LearningGroupAnnouncement>> listAnnouncements(String groupId);
  Future<LearningGroupInviteStatus> getInviteStatus(String groupId);
  Future<List<LearningGroupModerationEvent>> listModerationEvents(
    String groupId, {
    int limit = 100,
  });
  Future<List<LearningGroupSystemTask>> listSystemTasks(String groupId);
  Future<bool> getVocabularySharing(String groupId);
  Future<void> setVocabularySharing({
    required String groupId,
    required bool enabled,
  });
  Future<String> createSystemTask({
    required String groupId,
    required String title,
    required int targetWordCount,
    required DateTime dueAt,
    required String requestId,
  });
  Future<void> closeSystemTask({
    required String groupId,
    required String taskId,
    required String requestId,
  });
  Future<List<LearningGroupStudentOverview>> listLearningOverview(
    String groupId,
  );
  Future<List<LearningGroupSharedVocabulary>> listStudentVocabulary({
    required String groupId,
    required String studentUserId,
    int limit = 200,
  });
  Future<void> respondJoin({
    required String groupId,
    required String studentUserId,
    required bool approve,
    required String requestId,
  });
  Future<void> setMemberMute({
    required String groupId,
    required String studentUserId,
    required bool muted,
    required String requestId,
  });
  Future<void> removeMember({
    required String groupId,
    required String studentUserId,
    required String requestId,
  });
  Future<void> archiveGroup({
    required String groupId,
    required String requestId,
  });
  Future<LearningGroupInviteSecret> rotateInvite({
    required String groupId,
    required DateTime expiresAt,
    required String requestId,
  });
  Future<void> revokeInvite({
    required String groupId,
    required String requestId,
  });
  Future<void> createAnnouncement({
    required String groupId,
    required String body,
    required String requestId,
  });
  Future<void> setAnnouncementPinned({
    required String groupId,
    required String announcementId,
    required bool pinned,
    required String requestId,
  });
  Future<String> getGroupConversationId(String groupId);
  Future<void> dispose();
}

abstract interface class GroupsRepository {
  Stream<GroupRemoteSignal> get remoteSignals;
  Stream<List<LearningGroupSummary>> watchCached();
  Future<List<LearningGroupSummary>> readCached();
  Future<DateTime?> refreshedAt();
  Future<GroupCapabilities> getCapabilities();
  Future<void> refresh();
  Future<String> createGroup({
    required String title,
    required String description,
    required String requestId,
  });
  Future<String> requestJoin({
    required String inviteToken,
    required String requestId,
  });
  Future<List<LearningGroupMember>> listMembers(String groupId);
  Future<List<LearningGroupAnnouncement>> listAnnouncements(String groupId);
  Future<LearningGroupDetails> loadDetails(
    String groupId, {
    required bool includeManagement,
  });
  Future<List<LearningGroupSystemTask>> listSystemTasks(String groupId);
  Future<bool> getVocabularySharing(String groupId);
  Future<void> setVocabularySharing({
    required String groupId,
    required bool enabled,
  });
  Future<String> createSystemTask({
    required String groupId,
    required String title,
    required int targetWordCount,
    required DateTime dueAt,
    required String requestId,
  });
  Future<void> closeSystemTask({
    required String groupId,
    required String taskId,
    required String requestId,
  });
  Future<List<LearningGroupStudentOverview>> listLearningOverview(
    String groupId,
  );
  Future<List<LearningGroupSharedVocabulary>> listStudentVocabulary({
    required String groupId,
    required String studentUserId,
    int limit = 200,
  });
  Future<void> respondJoin({
    required String groupId,
    required String studentUserId,
    required bool approve,
    required String requestId,
  });
  Future<void> setMemberMute({
    required String groupId,
    required String studentUserId,
    required bool muted,
    required String requestId,
  });
  Future<void> removeMember({
    required String groupId,
    required String studentUserId,
    required String requestId,
  });
  Future<void> archiveGroup({
    required String groupId,
    required String requestId,
  });
  Future<LearningGroupInviteSecret> rotateInvite({
    required String groupId,
    required DateTime expiresAt,
    required String requestId,
  });
  Future<void> revokeInvite({
    required String groupId,
    required String requestId,
  });
  Future<void> createAnnouncement({
    required String groupId,
    required String body,
    required String requestId,
  });
  Future<void> setAnnouncementPinned({
    required String groupId,
    required String announcementId,
    required bool pinned,
    required String requestId,
  });
  Future<String> getGroupConversationId(String groupId);
  Future<void> dispose();
}
