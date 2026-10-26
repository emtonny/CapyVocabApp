import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../domain/group_models.dart';

final class GroupsStore {
  GroupsStore({required this.database, required this.owner});

  final Database database;
  final GroupOwner owner;
  final _changes = StreamController<void>.broadcast(sync: true);

  Future<void> reconcileSnapshot({
    required List<LearningGroupSummary> groups,
    required DateTime completedAt,
    required bool Function() isCurrent,
  }) async {
    final ids = groups.map((group) => group.id).toSet();
    if (ids.length != groups.length) {
      throw const GroupDataException('Duplicate group in complete snapshot.');
    }
    final cachedAt = completedAt.toUtc().microsecondsSinceEpoch;
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      for (final group in groups) {
        await tx.rawInsert(
          '''INSERT INTO learning_group_summaries(
            project_ref,owner_id,group_id,title,description,group_status,
            member_role,membership_status,is_muted,active_student_count,
            pending_student_count,server_updated_at,cached_at
          ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
          ON CONFLICT(project_ref,owner_id,group_id) DO UPDATE SET
            title=excluded.title,
            description=excluded.description,
            group_status=excluded.group_status,
            member_role=excluded.member_role,
            membership_status=excluded.membership_status,
            is_muted=excluded.is_muted,
            active_student_count=excluded.active_student_count,
            pending_student_count=excluded.pending_student_count,
            server_updated_at=excluded.server_updated_at,
            cached_at=excluded.cached_at''',
          [
            owner.projectRef,
            owner.userId,
            group.id,
            group.title,
            group.description,
            group.status.wireValue,
            group.role.wireValue,
            group.membershipStatus.wireValue,
            group.isMuted ? 1 : 0,
            group.activeStudentCount,
            group.pendingStudentCount,
            group.updatedAt.microsecondsSinceEpoch,
            cachedAt,
          ],
        );
      }
      final where = StringBuffer('project_ref=? AND owner_id=?');
      final args = <Object?>[owner.projectRef, owner.userId];
      if (ids.isNotEmpty) {
        where.write(
            ' AND group_id NOT IN (${List.filled(ids.length, '?').join(',')})');
        args.addAll(ids);
      }
      await tx.delete(
        'learning_group_summaries',
        where: where.toString(),
        whereArgs: args,
      );
      await tx.rawInsert(
        '''INSERT INTO learning_group_sync_meta(project_ref,owner_id,refreshed_at)
        VALUES(?,?,?)
        ON CONFLICT(project_ref,owner_id) DO UPDATE SET
          refreshed_at=excluded.refreshed_at''',
        [owner.projectRef, owner.userId, cachedAt],
      );
      _guardCurrent(isCurrent);
    });
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> reconcileDetails({
    required String groupId,
    required List<LearningGroupMember> members,
    required List<LearningGroupAnnouncement> announcements,
    required LearningGroupInviteStatus? inviteStatus,
    required List<LearningGroupModerationEvent> moderationEvents,
    required bool includesManagement,
    required DateTime completedAt,
    required bool Function() isCurrent,
  }) async {
    final id = requireGroupUuid(groupId, 'groupId');
    if (members.map((item) => item.userId).toSet().length != members.length ||
        announcements.map((item) => item.id).toSet().length !=
            announcements.length ||
        moderationEvents.map((item) => item.id).toSet().length !=
            moderationEvents.length ||
        includesManagement != (inviteStatus != null)) {
      throw const GroupDataException('Invalid complete group detail snapshot.');
    }
    final scope = [owner.projectRef, owner.userId, id];
    final refreshedAt = completedAt.toUtc().microsecondsSinceEpoch;
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      final parent = await tx.query(
        'learning_group_summaries',
        columns: ['group_id'],
        where: 'project_ref=? AND owner_id=? AND group_id=?',
        whereArgs: scope,
        limit: 1,
      );
      if (parent.isEmpty) {
        throw const GroupException(
          GroupFailureKind.notFound,
          'Nhóm không còn trong danh sách trên máy.',
        );
      }
      for (final table in const [
        'learning_group_member_cache',
        'learning_group_announcement_cache',
        'learning_group_invite_status_cache',
        'learning_group_moderation_event_cache',
      ]) {
        await tx.delete(
          table,
          where: 'project_ref=? AND owner_id=? AND group_id=?',
          whereArgs: scope,
        );
      }
      for (final member in members) {
        await tx.insert('learning_group_member_cache', {
          'project_ref': owner.projectRef,
          'owner_id': owner.userId,
          'group_id': id,
          'user_id': member.userId,
          'display_name': member.displayName,
          'username': member.username,
          'avatar_url': member.avatarUrl,
          'member_role': member.role.wireValue,
          'membership_status': member.status.wireValue,
          'is_muted': member.isMuted ? 1 : 0,
          'server_updated_at': member.updatedAt.microsecondsSinceEpoch,
        });
      }
      for (final announcement in announcements) {
        await tx.insert('learning_group_announcement_cache', {
          'project_ref': owner.projectRef,
          'owner_id': owner.userId,
          'group_id': id,
          'announcement_id': announcement.id,
          'author_user_id': announcement.authorUserId,
          'author_display_name': announcement.authorDisplayName,
          'body': announcement.body,
          'is_pinned': announcement.isPinned ? 1 : 0,
          'created_at': announcement.createdAt.microsecondsSinceEpoch,
          'server_updated_at': announcement.updatedAt.microsecondsSinceEpoch,
        });
      }
      if (inviteStatus != null) {
        await tx.insert('learning_group_invite_status_cache', {
          'project_ref': owner.projectRef,
          'owner_id': owner.userId,
          'group_id': id,
          'has_active_invite': inviteStatus.hasActiveInvite ? 1 : 0,
          'expires_at': inviteStatus.expiresAt?.microsecondsSinceEpoch,
          'use_count': inviteStatus.useCount,
          'last_used_at': inviteStatus.lastUsedAt?.microsecondsSinceEpoch,
          'created_at': inviteStatus.createdAt?.microsecondsSinceEpoch,
        });
      }
      if (includesManagement) {
        for (final event in moderationEvents) {
          await tx.insert('learning_group_moderation_event_cache', {
            'project_ref': owner.projectRef,
            'owner_id': owner.userId,
            'group_id': id,
            'event_id': event.id,
            'actor_user_id': event.actorUserId,
            'actor_display_name': event.actorDisplayName,
            'target_user_id': event.targetUserId,
            'target_display_name': event.targetDisplayName,
            'target_message_id': event.targetMessageId,
            'action': event.action,
            'reason_code': event.reasonCode,
            'occurred_at': event.occurredAt.microsecondsSinceEpoch,
          });
        }
      }
      await tx.rawInsert(
        '''INSERT INTO learning_group_detail_sync(
          project_ref,owner_id,group_id,includes_management,refreshed_at
        ) VALUES(?,?,?,?,?)
        ON CONFLICT(project_ref,owner_id,group_id) DO UPDATE SET
          includes_management=excluded.includes_management,
          refreshed_at=excluded.refreshed_at''',
        [...scope, includesManagement ? 1 : 0, refreshedAt],
      );
      _guardCurrent(isCurrent);
    });
  }

  Future<LearningGroupDetails?> readDetails(String groupId) async {
    final id = requireGroupUuid(groupId, 'groupId');
    final scope = [owner.projectRef, owner.userId, id];
    final sync = await database.query(
      'learning_group_detail_sync',
      where: 'project_ref=? AND owner_id=? AND group_id=?',
      whereArgs: scope,
      limit: 1,
    );
    if (sync.isEmpty) return null;
    final members = await database.query(
      'learning_group_member_cache',
      where: 'project_ref=? AND owner_id=? AND group_id=?',
      whereArgs: scope,
      orderBy:
          "CASE member_role WHEN 'owner_teacher' THEN 0 ELSE 1 END, server_updated_at DESC, user_id",
    );
    final announcements = await database.query(
      'learning_group_announcement_cache',
      where: 'project_ref=? AND owner_id=? AND group_id=?',
      whereArgs: scope,
      orderBy: 'is_pinned DESC, created_at DESC, announcement_id DESC',
    );
    final invite = await database.query(
      'learning_group_invite_status_cache',
      where: 'project_ref=? AND owner_id=? AND group_id=?',
      whereArgs: scope,
      limit: 1,
    );
    final events = await database.query(
      'learning_group_moderation_event_cache',
      where: 'project_ref=? AND owner_id=? AND group_id=?',
      whereArgs: scope,
      orderBy: 'occurred_at DESC, event_id DESC',
    );
    return LearningGroupDetails(
      members: members.map(_decodeMember).toList(growable: false),
      announcements:
          announcements.map(_decodeAnnouncement).toList(growable: false),
      inviteStatus: invite.isEmpty ? null : _decodeInviteStatus(invite.single),
      moderationEvents: events.map(_decodeEvent).toList(growable: false),
      includesManagement: sync.single['includes_management'] == 1,
      refreshedAt: _time(sync.single['refreshed_at'] as int),
    );
  }

  Future<void> purgeDetails(String groupId) async {
    final id = requireGroupUuid(groupId, 'groupId');
    final scope = [owner.projectRef, owner.userId, id];
    await database.transaction((tx) async {
      for (final table in const [
        'learning_group_member_cache',
        'learning_group_announcement_cache',
        'learning_group_invite_status_cache',
        'learning_group_moderation_event_cache',
        'learning_group_detail_sync',
      ]) {
        await tx.delete(
          table,
          where: 'project_ref=? AND owner_id=? AND group_id=?',
          whereArgs: scope,
        );
      }
    });
  }

  Future<List<LearningGroupSummary>> list() async {
    final rows = await database.query(
      'learning_group_summaries',
      where: 'project_ref=? AND owner_id=?',
      whereArgs: [owner.projectRef, owner.userId],
      orderBy: 'server_updated_at DESC, group_id DESC',
    );
    return rows.map(_decode).toList(growable: false);
  }

  Stream<List<LearningGroupSummary>> watch() {
    return Stream.multi((controller) {
      var canceled = false;
      Future<void> tail = Future.value();
      void emit() {
        tail = tail.then((_) async {
          if (canceled) return;
          try {
            final groups = await list();
            if (!canceled) controller.add(groups);
          } catch (error, stack) {
            if (!canceled) controller.addError(error, stack);
          }
        });
      }

      final subscription = _changes.stream.listen((_) => emit());
      controller.onCancel = () {
        canceled = true;
        return subscription.cancel();
      };
      emit();
    });
  }

  Future<DateTime?> refreshedAt() async {
    final rows = await database.query(
      'learning_group_sync_meta',
      columns: ['refreshed_at'],
      where: 'project_ref=? AND owner_id=?',
      whereArgs: [owner.projectRef, owner.userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
      rows.single['refreshed_at'] as int,
      isUtc: true,
    );
  }

  LearningGroupSummary _decode(Map<String, Object?> row) {
    return LearningGroupSummary(
      id: row['group_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      status: LearningGroupStatus.fromWire(row['group_status']),
      role: LearningGroupRole.fromWire(row['member_role']),
      membershipStatus:
          LearningGroupMembershipStatus.fromWire(row['membership_status']),
      isMuted: row['is_muted'] == 1,
      activeStudentCount: row['active_student_count'] as int,
      pendingStudentCount: row['pending_student_count'] as int,
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(
        row['server_updated_at'] as int,
        isUtc: true,
      ),
    );
  }

  LearningGroupMember _decodeMember(Map<String, Object?> row) =>
      LearningGroupMember(
        userId: row['user_id'] as String,
        displayName: row['display_name'] as String,
        username: row['username'] as String,
        avatarUrl: row['avatar_url'] as String?,
        role: LearningGroupRole.fromWire(row['member_role']),
        status: LearningGroupMembershipStatus.fromWire(
          row['membership_status'],
        ),
        isMuted: row['is_muted'] == 1,
        updatedAt: _time(row['server_updated_at'] as int),
      );

  LearningGroupAnnouncement _decodeAnnouncement(Map<String, Object?> row) =>
      LearningGroupAnnouncement(
        id: row['announcement_id'] as String,
        authorUserId: row['author_user_id'] as String,
        authorDisplayName: row['author_display_name'] as String,
        body: row['body'] as String,
        isPinned: row['is_pinned'] == 1,
        createdAt: _time(row['created_at'] as int),
        updatedAt: _time(row['server_updated_at'] as int),
      );

  LearningGroupInviteStatus _decodeInviteStatus(Map<String, Object?> row) =>
      LearningGroupInviteStatus(
        hasActiveInvite: row['has_active_invite'] == 1,
        expiresAt: _optionalTime(row['expires_at']),
        useCount: row['use_count'] as int,
        lastUsedAt: _optionalTime(row['last_used_at']),
        createdAt: _optionalTime(row['created_at']),
      );

  LearningGroupModerationEvent _decodeEvent(Map<String, Object?> row) =>
      LearningGroupModerationEvent(
        id: row['event_id'] as int,
        actorUserId: row['actor_user_id'] as String,
        actorDisplayName: row['actor_display_name'] as String,
        targetUserId: row['target_user_id'] as String?,
        targetDisplayName: row['target_display_name'] as String?,
        targetMessageId: row['target_message_id'] as String?,
        action: row['action'] as String,
        reasonCode: row['reason_code'] as String?,
        occurredAt: _time(row['occurred_at'] as int),
      );

  DateTime _time(int micros) =>
      DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);

  DateTime? _optionalTime(Object? micros) =>
      micros == null ? null : _time(micros as int);

  void _guardCurrent(bool Function() isCurrent) {
    if (!isCurrent()) throw const GroupSessionChanged();
  }

  Future<void> dispose() => _changes.close();
}
