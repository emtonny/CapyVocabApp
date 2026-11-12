final RegExp _groupUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String requireGroupUuid(String value, String field) {
  final normalized = value.trim().toLowerCase();
  if (!_groupUuidPattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'must be a valid UUID');
  }
  return normalized;
}

final class GroupOwner {
  GroupOwner({required String projectRef, required String userId})
      : projectRef = projectRef.trim().toLowerCase(),
        userId = requireGroupUuid(userId, 'userId') {
    if (this.projectRef.isEmpty) {
      throw ArgumentError.value(projectRef, 'projectRef', 'must not be empty');
    }
  }

  final String projectRef;
  final String userId;
  String get scope => '$projectRef:$userId';

  @override
  bool operator ==(Object other) => other is GroupOwner && other.scope == scope;

  @override
  int get hashCode => scope.hashCode;
}

enum LearningGroupStatus {
  active('active'),
  archived('archived');

  const LearningGroupStatus(this.wireValue);
  final String wireValue;

  static LearningGroupStatus fromWire(Object? value) => values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const GroupDataException('Invalid group status.'),
      );
}

enum LearningGroupRole {
  ownerTeacher('owner_teacher'),
  student('student');

  const LearningGroupRole(this.wireValue);
  final String wireValue;

  static LearningGroupRole fromWire(Object? value) => values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const GroupDataException('Invalid group role.'),
      );
}

enum LearningGroupMembershipStatus {
  pending('pending'),
  active('active');

  const LearningGroupMembershipStatus(this.wireValue);
  final String wireValue;

  static LearningGroupMembershipStatus fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () =>
            throw const GroupDataException('Invalid membership status.'),
      );
}

final class GroupCapabilities {
  const GroupCapabilities({
    required this.accountRole,
    required this.teacherVerificationStatus,
    required this.canManageGroups,
  });

  factory GroupCapabilities.fromRemote(Map<String, dynamic> row) {
    final role = row['account_role'];
    final verification = row['teacher_verification_status'];
    final canManage = row['can_manage_groups'];
    if (role != null && role is! String ||
        verification != null && verification is! String ||
        canManage is! bool) {
      throw const GroupDataException('Invalid group capabilities response.');
    }
    return GroupCapabilities(
      accountRole: role as String?,
      teacherVerificationStatus: verification as String?,
      canManageGroups: canManage,
    );
  }

  final String? accountRole;
  final String? teacherVerificationStatus;
  final bool canManageGroups;
}

final class LearningGroupSummary {
  LearningGroupSummary({
    required String id,
    required String title,
    required this.description,
    required this.status,
    required this.role,
    required this.membershipStatus,
    required this.isMuted,
    required this.activeStudentCount,
    required this.pendingStudentCount,
    required DateTime updatedAt,
  })  : id = requireGroupUuid(id, 'id'),
        title = title.trim(),
        updatedAt = updatedAt.toUtc() {
    if (this.title.isEmpty ||
        this.title.length > 80 ||
        description.length > 500 ||
        activeStudentCount < 0 ||
        activeStudentCount > 50 ||
        pendingStudentCount < 0) {
      throw const GroupDataException('Invalid group summary values.');
    }
  }

  factory LearningGroupSummary.fromRemote(Map<String, dynamic> row) {
    final active = row['active_student_count'];
    final pending = row['pending_student_count'];
    final muted = row['is_muted'];
    final updated = row['updated_at'];
    if (active is! num ||
        pending is! num ||
        muted is! bool ||
        updated is! String) {
      throw const GroupDataException('Invalid group summary response.');
    }
    return LearningGroupSummary(
      id: row['group_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      status: LearningGroupStatus.fromWire(row['group_status']),
      role: LearningGroupRole.fromWire(row['member_role']),
      membershipStatus:
          LearningGroupMembershipStatus.fromWire(row['membership_status']),
      isMuted: muted,
      activeStudentCount: active.toInt(),
      pendingStudentCount: pending.toInt(),
      updatedAt: DateTime.parse(updated),
    );
  }

  final String id;
  final String title;
  final String description;
  final LearningGroupStatus status;
  final LearningGroupRole role;
  final LearningGroupMembershipStatus membershipStatus;
  final bool isMuted;
  final int activeStudentCount;
  final int pendingStudentCount;
  final DateTime updatedAt;
}

final class LearningGroupMember {
  LearningGroupMember({
    required String userId,
    required String displayName,
    required String username,
    required this.avatarUrl,
    required this.role,
    required this.status,
    required this.isMuted,
    required DateTime updatedAt,
  })  : userId = requireGroupUuid(userId, 'userId'),
        displayName = displayName.trim(),
        username = username.trim(),
        updatedAt = updatedAt.toUtc() {
    if (this.displayName.isEmpty || this.username.length > 40) {
      throw const GroupDataException('Invalid group member values.');
    }
  }

  factory LearningGroupMember.fromRemote(Map<String, dynamic> row) {
    final userId = row['user_id'];
    final displayName = row['display_name'];
    final username = row['username'];
    final avatarUrl = row['avatar_url'];
    final muted = row['is_muted'];
    final updated = row['updated_at'];
    if (userId is! String ||
        displayName is! String ||
        username is! String ||
        avatarUrl != null && avatarUrl is! String ||
        muted is! bool ||
        updated is! String) {
      throw const GroupDataException('Invalid group member response.');
    }
    return LearningGroupMember(
      userId: userId,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl as String?,
      role: LearningGroupRole.fromWire(row['member_role']),
      status: LearningGroupMembershipStatus.fromWire(
        row['membership_status'],
      ),
      isMuted: muted,
      updatedAt: DateTime.parse(updated),
    );
  }

  final String userId;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final LearningGroupRole role;
  final LearningGroupMembershipStatus status;
  final bool isMuted;
  final DateTime updatedAt;
}

final class LearningGroupAnnouncement {
  LearningGroupAnnouncement({
    required String id,
    required String authorUserId,
    required String authorDisplayName,
    required String body,
    required this.isPinned,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : id = requireGroupUuid(id, 'id'),
        authorUserId = requireGroupUuid(authorUserId, 'authorUserId'),
        authorDisplayName = authorDisplayName.trim(),
        body = body.trim(),
        createdAt = createdAt.toUtc(),
        updatedAt = updatedAt.toUtc() {
    if (this.authorDisplayName.isEmpty ||
        this.body.isEmpty ||
        this.body.length > 2000) {
      throw const GroupDataException('Invalid group announcement values.');
    }
  }

  factory LearningGroupAnnouncement.fromRemote(Map<String, dynamic> row) {
    final id = row['announcement_id'];
    final authorId = row['author_user_id'];
    final authorName = row['author_display_name'];
    final body = row['body'];
    final pinned = row['is_pinned'];
    final created = row['created_at'];
    final updated = row['updated_at'];
    if (id is! String ||
        authorId is! String ||
        authorName is! String ||
        body is! String ||
        pinned is! bool ||
        created is! String ||
        updated is! String) {
      throw const GroupDataException('Invalid announcement response.');
    }
    return LearningGroupAnnouncement(
      id: id,
      authorUserId: authorId,
      authorDisplayName: authorName,
      body: body,
      isPinned: pinned,
      createdAt: DateTime.parse(created),
      updatedAt: DateTime.parse(updated),
    );
  }

  final String id;
  final String authorUserId;
  final String authorDisplayName;
  final String body;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class LearningGroupInviteSecret {
  LearningGroupInviteSecret(
      {required String token, required DateTime expiresAt})
      : token = token.trim().toLowerCase(),
        expiresAt = expiresAt.toUtc() {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(this.token) ||
        !this.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const GroupDataException('Invalid group invite secret.');
    }
  }

  final String token;
  final DateTime expiresAt;
}

final class LearningGroupInviteStatus {
  LearningGroupInviteStatus({
    required this.hasActiveInvite,
    required DateTime? expiresAt,
    required this.useCount,
    required DateTime? lastUsedAt,
    required DateTime? createdAt,
  })  : expiresAt = expiresAt?.toUtc(),
        lastUsedAt = lastUsedAt?.toUtc(),
        createdAt = createdAt?.toUtc() {
    if (useCount < 0 ||
        hasActiveInvite && this.expiresAt == null ||
        this.expiresAt == null &&
            (useCount != 0 ||
                this.lastUsedAt != null ||
                this.createdAt != null)) {
      throw const GroupDataException('Invalid group invite status.');
    }
  }

  factory LearningGroupInviteStatus.fromRemote(Map<String, dynamic> row) {
    final active = row['has_active_invite'];
    final expiry = row['expires_at'];
    final count = row['use_count'];
    final lastUsed = row['last_used_at'];
    final created = row['created_at'];
    if (active is! bool ||
        expiry != null && expiry is! String ||
        count != null && count is! num ||
        lastUsed != null && lastUsed is! String ||
        created != null && created is! String) {
      throw const GroupDataException('Invalid invite status response.');
    }
    return LearningGroupInviteStatus(
      hasActiveInvite: active,
      expiresAt: expiry == null ? null : DateTime.parse(expiry as String),
      useCount: count?.toInt() ?? 0,
      lastUsedAt: lastUsed == null ? null : DateTime.parse(lastUsed as String),
      createdAt: created == null ? null : DateTime.parse(created as String),
    );
  }

  final bool hasActiveInvite;
  final DateTime? expiresAt;
  final int useCount;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
}

final class LearningGroupModerationEvent {
  LearningGroupModerationEvent({
    required this.id,
    required String actorUserId,
    required String actorDisplayName,
    required String? targetUserId,
    required String? targetDisplayName,
    required String? targetMessageId,
    required String action,
    required String? reasonCode,
    required DateTime occurredAt,
  })  : actorUserId = requireGroupUuid(actorUserId, 'actorUserId'),
        actorDisplayName = actorDisplayName.trim(),
        targetUserId = targetUserId == null
            ? null
            : requireGroupUuid(targetUserId, 'targetUserId'),
        targetDisplayName = targetDisplayName?.trim(),
        targetMessageId = targetMessageId == null
            ? null
            : requireGroupUuid(targetMessageId, 'targetMessageId'),
        action = action.trim(),
        reasonCode = reasonCode?.trim(),
        occurredAt = occurredAt.toUtc() {
    if (id <= 0 ||
        this.actorDisplayName.isEmpty ||
        !_actions.contains(this.action) ||
        (this.targetUserId == null) != (this.targetDisplayName == null) ||
        this.targetDisplayName?.isEmpty == true ||
        this.reasonCode != null &&
            !RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(this.reasonCode!)) {
      throw const GroupDataException('Invalid moderation event values.');
    }
  }

  factory LearningGroupModerationEvent.fromRemote(Map<String, dynamic> row) {
    final id = row['event_id'];
    final actorId = row['actor_user_id'];
    final actorName = row['actor_display_name'];
    final targetId = row['target_user_id'];
    final targetName = row['target_display_name'];
    final messageId = row['target_message_id'];
    final action = row['action'];
    final reason = row['reason_code'];
    final occurred = row['occurred_at'];
    if (id is! num ||
        actorId is! String ||
        actorName is! String ||
        targetId != null && targetId is! String ||
        targetName != null && targetName is! String ||
        messageId != null && messageId is! String ||
        action is! String ||
        reason != null && reason is! String ||
        occurred is! String) {
      throw const GroupDataException('Invalid moderation event response.');
    }
    return LearningGroupModerationEvent(
      id: id.toInt(),
      actorUserId: actorId,
      actorDisplayName: actorName,
      targetUserId: targetId as String?,
      targetDisplayName: targetName as String?,
      targetMessageId: messageId as String?,
      action: action,
      reasonCode: reason as String?,
      occurredAt: DateTime.parse(occurred),
    );
  }

  static const _actions = {
    'group_created',
    'group_updated',
    'group_archived',
    'invite_rotated',
    'invite_revoked',
    'join_requested',
    'join_approved',
    'join_rejected',
    'member_left',
    'member_removed',
    'member_muted',
    'member_unmuted',
    'announcement_created',
    'announcement_pinned',
    'announcement_unpinned',
    'message_hidden',
    'message_restored',
    'system_task_created',
    'system_task_closed',
  };

  final int id;
  final String actorUserId;
  final String actorDisplayName;
  final String? targetUserId;
  final String? targetDisplayName;
  final String? targetMessageId;
  final String action;
  final String? reasonCode;
  final DateTime occurredAt;
}

final class LearningGroupSystemTask {
  LearningGroupSystemTask({
    required String id,
    required String title,
    required this.targetWordCount,
    required DateTime dueAt,
    required String status,
    required DateTime createdAt,
    required this.learnedWordCount,
    required this.masteryPercent,
    required String progressStatus,
    required this.sharingEnabled,
    required this.assignedStudentCount,
    required this.completedStudentCount,
  })  : id = requireGroupUuid(id, 'id'),
        title = title.trim(),
        dueAt = dueAt.toUtc(),
        status = status.trim(),
        createdAt = createdAt.toUtc(),
        progressStatus = progressStatus.trim() {
    if (this.title.isEmpty ||
        this.title.length > 120 ||
        targetWordCount < 1 ||
        targetWordCount > 100 ||
        !_statuses.contains(this.status) ||
        learnedWordCount < 0 ||
        masteryPercent < 0 ||
        masteryPercent > 100 ||
        !_progressStatuses.contains(this.progressStatus) ||
        assignedStudentCount < 0 ||
        completedStudentCount < 0 ||
        completedStudentCount > assignedStudentCount) {
      throw const GroupDataException('Invalid learning task values.');
    }
  }

  factory LearningGroupSystemTask.fromRemote(Map<String, dynamic> row) {
    final target = row['target_word_count'];
    final learned = row['learned_word_count'];
    final mastery = row['mastery_percent'];
    final sharing = row['sharing_enabled'];
    final assigned = row['assigned_student_count'];
    final completed = row['completed_student_count'];
    if (target is! num ||
        learned is! num ||
        mastery is! num ||
        sharing is! bool ||
        assigned is! num ||
        completed is! num) {
      throw const GroupDataException('Invalid learning task response.');
    }
    return LearningGroupSystemTask(
      id: row['task_id'] as String,
      title: row['title'] as String,
      targetWordCount: target.toInt(),
      dueAt: DateTime.parse(row['due_at'] as String),
      status: row['task_status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      learnedWordCount: learned.toInt(),
      masteryPercent: mastery.toInt(),
      progressStatus: row['progress_status'] as String,
      sharingEnabled: sharing,
      assignedStudentCount: assigned.toInt(),
      completedStudentCount: completed.toInt(),
    );
  }

  static const _statuses = {'active', 'closed'};
  static const _progressStatuses = {
    'owner_view',
    'sharing_off',
    'not_started',
    'in_progress',
    'completed',
    'overdue',
  };

  final String id;
  final String title;
  final int targetWordCount;
  final DateTime dueAt;
  final String status;
  final DateTime createdAt;
  final int learnedWordCount;
  final int masteryPercent;
  final String progressStatus;
  final bool sharingEnabled;
  final int assignedStudentCount;
  final int completedStudentCount;
}

final class LearningGroupStudentOverview {
  LearningGroupStudentOverview({
    required String userId,
    required String displayName,
    required this.sharingEnabled,
    required this.totalLearnedWordCount,
    required this.activeTaskCount,
    required this.completedTaskCount,
    required this.averageMasteryPercent,
    required DateTime? lastLearnedAt,
  })  : userId = requireGroupUuid(userId, 'userId'),
        displayName = displayName.trim(),
        lastLearnedAt = lastLearnedAt?.toUtc() {
    if (this.displayName.isEmpty ||
        totalLearnedWordCount < 0 ||
        activeTaskCount < 0 ||
        completedTaskCount < 0 ||
        completedTaskCount > activeTaskCount ||
        averageMasteryPercent < 0 ||
        averageMasteryPercent > 100) {
      throw const GroupDataException('Invalid student learning overview.');
    }
  }

  factory LearningGroupStudentOverview.fromRemote(Map<String, dynamic> row) {
    final shared = row['sharing_enabled'];
    final words = row['total_learned_word_count'];
    final active = row['active_task_count'];
    final completed = row['completed_task_count'];
    final mastery = row['average_mastery_percent'];
    final lastLearned = row['last_learned_at'];
    if (shared is! bool ||
        words is! num ||
        active is! num ||
        completed is! num ||
        mastery is! num ||
        lastLearned != null && lastLearned is! String) {
      throw const GroupDataException('Invalid student overview response.');
    }
    return LearningGroupStudentOverview(
      userId: row['student_user_id'] as String,
      displayName: row['display_name'] as String,
      sharingEnabled: shared,
      totalLearnedWordCount: words.toInt(),
      activeTaskCount: active.toInt(),
      completedTaskCount: completed.toInt(),
      averageMasteryPercent: mastery.toInt(),
      lastLearnedAt:
          lastLearned == null ? null : DateTime.parse(lastLearned as String),
    );
  }

  final String userId;
  final String displayName;
  final bool sharingEnabled;
  final int totalLearnedWordCount;
  final int activeTaskCount;
  final int completedTaskCount;
  final int averageMasteryPercent;
  final DateTime? lastLearnedAt;
}

final class LearningGroupSharedVocabulary {
  LearningGroupSharedVocabulary({
    required String word,
    required DateTime firstLearnedAt,
    required DateTime lastLearnedAt,
  })  : word = word.trim(),
        firstLearnedAt = firstLearnedAt.toUtc(),
        lastLearnedAt = lastLearnedAt.toUtc() {
    if (this.word.isEmpty ||
        this.word.length > 120 ||
        this.lastLearnedAt.isBefore(this.firstLearnedAt)) {
      throw const GroupDataException('Invalid shared vocabulary value.');
    }
  }

  factory LearningGroupSharedVocabulary.fromRemote(Map<String, dynamic> row) {
    return LearningGroupSharedVocabulary(
      word: row['word'] as String,
      firstLearnedAt: DateTime.parse(row['first_learned_at'] as String),
      lastLearnedAt: DateTime.parse(row['last_learned_at'] as String),
    );
  }

  final String word;
  final DateTime firstLearnedAt;
  final DateTime lastLearnedAt;
}

final class LearningGroupDetails {
  const LearningGroupDetails({
    required this.members,
    required this.announcements,
    required this.inviteStatus,
    required this.moderationEvents,
    required this.includesManagement,
    required this.refreshedAt,
    this.offlineFallback = false,
  });

  final List<LearningGroupMember> members;
  final List<LearningGroupAnnouncement> announcements;
  final LearningGroupInviteStatus? inviteStatus;
  final List<LearningGroupModerationEvent> moderationEvents;
  final bool includesManagement;
  final DateTime refreshedAt;
  final bool offlineFallback;

  LearningGroupDetails asOfflineFallback() => LearningGroupDetails(
        members: members,
        announcements: announcements,
        inviteStatus: inviteStatus,
        moderationEvents: moderationEvents,
        includesManagement: includesManagement,
        refreshedAt: refreshedAt,
        offlineFallback: true,
      );
}

enum GroupRemoteSignal { connected, changed, disconnected }

enum GroupFailureKind {
  invalidInput,
  unauthenticated,
  denied,
  notFound,
  conflict,
  rateLimited,
  unavailable,
  invalidResponse,
}

class GroupException implements Exception {
  const GroupException(this.kind, this.message);
  final GroupFailureKind kind;
  final String message;

  @override
  String toString() => 'GroupException($kind, $message)';
}

class GroupDataException extends GroupException {
  const GroupDataException(String message)
      : super(GroupFailureKind.invalidResponse, message);
}

class GroupSessionChanged extends GroupException {
  const GroupSessionChanged()
      : super(
          GroupFailureKind.unauthenticated,
          'Tài khoản đã thay đổi. Hãy thử lại.',
        );
}
