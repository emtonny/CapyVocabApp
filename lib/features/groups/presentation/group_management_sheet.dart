import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/group_models.dart';
import 'group_learning_provider.dart';
import 'group_management_provider.dart';

Future<void> showGroupManagementSheet(
  BuildContext context, {
  required GroupOwner owner,
  required LearningGroupSummary group,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.softWhite,
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: _GroupManagementSheet(owner: owner, group: group),
      ),
    );

class _GroupManagementSheet extends ConsumerWidget {
  const _GroupManagementSheet({required this.owner, required this.group});

  final GroupOwner owner;
  final LearningGroupSummary group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = group.role == LearningGroupRole.ownerTeacher;
    final key = (
      owner: owner,
      groupId: group.id,
      includeManagement: isOwner,
    );
    final state = ref.watch(groupManagementProvider(key));
    final notifier = ref.read(groupManagementProvider(key).notifier);
    final learningKey = (owner: owner, groupId: group.id, isOwner: isOwner);
    final learning = ref.watch(groupLearningProvider(learningKey));
    final learningNotifier =
        ref.read(groupLearningProvider(learningKey).notifier);
    final canManage = isOwner && group.status == LearningGroupStatus.active;
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.softWhite,
        title: Text(
          group.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              key: const Key('group-dashboard-chat'),
              tooltip: 'Mở chat nhóm',
              onPressed: state.isMutating
                  ? null
                  : () async {
                      final id = await notifier.getConversationId();
                      if (id != null && context.mounted) {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/chat/$id');
                      }
                    },
              icon: const Icon(Icons.forum_outlined),
            ),
          ),
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              key: const Key('group-dashboard-close'),
              tooltip: 'Đóng bảng quản lý',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          notifier.refresh(),
          learningNotifier.refresh(),
        ]),
        child: !state.ready
            ? ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                key: const Key('group-dashboard-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (group.status == LearningGroupStatus.archived)
                    const _DashboardNotice(
                      text:
                          'Lớp đã lưu trữ. Chat và thao tác quản lý ở chế độ chỉ đọc.',
                    ),
                  if (state.message != null)
                    _DashboardNotice(text: state.message!, isError: true),
                  if (learning.message != null)
                    _DashboardNotice(text: learning.message!, isError: true),
                  if (state.offlineFallback)
                    _DashboardNotice(
                      text: state.refreshedAt == null
                          ? 'Đang xem dữ liệu đã lưu trên máy.'
                          : 'Đang xem dữ liệu đã lưu lúc '
                              '${_dateTime(state.refreshedAt!.toLocal())}.',
                    ),
                  _StatsCard(state: state),
                  const SizedBox(height: 12),
                  if (isOwner) _InviteStatusCard(status: state.inviteStatus),
                  if (isOwner) const SizedBox(height: 12),
                  if (canManage)
                    _InviteActions(
                      busy: state.isMutating,
                      onRotate: () => _rotateInvite(context, notifier),
                      onRevoke: () => _revokeInvite(context, notifier),
                    ),
                  if (canManage) const SizedBox(height: 12),
                  if (!isOwner) ...[
                    _LearningSharingCard(
                      enabled: learning.sharingEnabled,
                      busy: learning.isMutating,
                      canEnable: group.status == LearningGroupStatus.active,
                      onChanged: learningNotifier.setVocabularySharing,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SectionHeader(
                    title: 'Nhiệm vụ hệ thống',
                    trailing: canManage
                        ? SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              key: const Key('group-learning-task-create'),
                              onPressed: learning.isMutating
                                  ? null
                                  : () => _createSystemTask(
                                        context,
                                        learningNotifier,
                                      ),
                              icon: const Icon(Icons.add_task_rounded),
                              label: const Text('Giao bài'),
                            ),
                          )
                        : learning.isRefreshing
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : null,
                  ),
                  if (!learning.ready ||
                      learning.isRefreshing && learning.tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (learning.tasks.isEmpty)
                    const _EmptySection(text: 'Chưa có nhiệm vụ học từ nào.')
                  else
                    for (final task in learning.tasks)
                      _SystemTaskCard(
                        task: task,
                        isOwner: isOwner,
                        canManage: canManage,
                        busy: learning.isMutating,
                        onClose: () =>
                            learningNotifier.closeSystemTask(task.id),
                      ),
                  if (isOwner) ...[
                    const SizedBox(height: 16),
                    const _SectionHeader(title: 'Tổng quan học tập'),
                    if (!learning.ready ||
                        learning.isRefreshing && learning.students.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (learning.students.isEmpty)
                      const _EmptySection(
                          text: 'Chưa có học viên đang hoạt động.')
                    else
                      for (final student in learning.students)
                        _StudentLearningCard(
                          student: student,
                          busy: learning.isMutating,
                          onViewWords: () => _showStudentVocabulary(
                            context,
                            learningNotifier,
                            student,
                          ),
                        ),
                  ],
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'Thành viên',
                    trailing: state.isRefreshing
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : null,
                  ),
                  if (state.members.isEmpty)
                    const _EmptySection(
                        text: 'Chưa tải được danh sách thành viên.')
                  else
                    for (final member in state.members)
                      _MemberCard(
                        member: member,
                        canManage: canManage,
                        busy: state.isMutating,
                        onApprove: () => notifier.respondJoin(
                          member.userId,
                          approve: true,
                        ),
                        onReject: () => notifier.respondJoin(
                          member.userId,
                          approve: false,
                        ),
                        onMute: () => notifier.setMuted(
                          member.userId,
                          muted: !member.isMuted,
                        ),
                        onRemove: () => _confirmRemove(
                          context,
                          notifier,
                          member,
                        ),
                      ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'Thông báo',
                    trailing: canManage
                        ? SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              key: const Key('group-announcement-create'),
                              onPressed: state.isMutating
                                  ? null
                                  : () =>
                                      _createAnnouncement(context, notifier),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Soạn'),
                            ),
                          )
                        : null,
                  ),
                  if (state.announcements.isEmpty)
                    const _EmptySection(text: 'Chưa có thông báo nào.')
                  else
                    for (final announcement in state.announcements)
                      _AnnouncementCard(
                        announcement: announcement,
                        canManage: canManage,
                        busy: state.isMutating,
                        onPin: () => notifier.setAnnouncementPinned(
                          announcement.id,
                          pinned: !announcement.isPinned,
                        ),
                      ),
                  if (canManage) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('group-archive'),
                        onPressed: state.isMutating
                            ? null
                            : () => _confirmArchive(context, notifier),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Lưu trữ lớp'),
                      ),
                    ),
                  ],
                  if (isOwner) ...[
                    const SizedBox(height: 20),
                    const _SectionHeader(title: 'Nhật ký quản trị'),
                    if (state.moderationEvents.isEmpty)
                      const _EmptySection(text: 'Chưa có hoạt động quản trị.')
                    else
                      for (final event in state.moderationEvents)
                        _ModerationEventCard(event: event),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.state});

  final GroupManagementState state;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tổng quan lớp học',
        child: Card(
          color: const Color(0xFFFFF3C4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip('Đang học', state.activeStudents),
                _StatChip('Chờ duyệt', state.pendingStudents),
                _StatChip('Đang tắt chat', state.mutedStudents),
              ],
            ),
          ),
        ),
      );
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$label: $value'),
        side: const BorderSide(color: AppColors.ink),
        backgroundColor: AppColors.softWhite,
      );
}

class _InviteActions extends StatelessWidget {
  const _InviteActions({
    required this.busy,
    required this.onRotate,
    required this.onRevoke,
  });

  final bool busy;
  final VoidCallback onRotate;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const Key('group-invite-rotate'),
              onPressed: busy ? null : onRotate,
              icon: const Icon(Icons.vpn_key_outlined),
              label: const Text('Tạo mã 7 ngày'),
            ),
          ),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('group-invite-revoke'),
              onPressed: busy ? null : onRevoke,
              icon: const Icon(Icons.key_off_outlined),
              label: const Text('Thu hồi mã'),
            ),
          ),
        ],
      );
}

class _InviteStatusCard extends StatelessWidget {
  const _InviteStatusCard({required this.status});

  final LearningGroupInviteStatus? status;

  @override
  Widget build(BuildContext context) {
    final invite = status;
    final active = invite?.hasActiveInvite ?? false;
    return Card(
      key: const Key('group-invite-status'),
      color: AppColors.softWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.ink),
      ),
      child: ListTile(
        leading: Icon(active ? Icons.key_rounded : Icons.key_off_outlined),
        title: Text(
            active ? 'Mã mời đang hoạt động' : 'Không có mã mời hoạt động'),
        subtitle: active
            ? Text(
                'Hết hạn ${_dateTime(invite!.expiresAt!.toLocal())} · '
                'đã dùng ${invite.useCount} lần',
              )
            : null,
      ),
    );
  }
}

class _LearningSharingCard extends StatelessWidget {
  const _LearningSharingCard({
    required this.enabled,
    required this.busy,
    required this.canEnable,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final bool canEnable;
  final Future<bool> Function(bool enabled) onChanged;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFE8F7FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
        child: SwitchListTile(
          key: const Key('group-vocabulary-sharing'),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          minTileHeight: 56,
          title: const Text(
            'Chia sẻ tiến độ từ vựng',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text(
            'Giáo viên chỉ thấy từ đã học và tổng tiến độ; không thấy ảnh, vị trí ảnh hoặc dữ liệu Vision.',
          ),
          value: enabled,
          onChanged: busy || !canEnable && !enabled
              ? null
              : (value) => onChanged(value),
        ),
      );
}

class _SystemTaskCard extends StatelessWidget {
  const _SystemTaskCard({
    required this.task,
    required this.isOwner,
    required this.canManage,
    required this.busy,
    required this.onClose,
  });

  final LearningGroupSystemTask task;
  final bool isOwner;
  final bool canManage;
  final bool busy;
  final Future<bool> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final subtitle = isOwner
        ? '${task.completedStudentCount}/${task.assignedStudentCount} học viên hoàn thành'
        : task.progressStatus == 'sharing_off'
            ? 'Bật chia sẻ tiến độ để hệ thống tự cập nhật.'
            : '${task.learnedWordCount}/${task.targetWordCount} từ · ${task.masteryPercent}%';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (canManage && task.status == 'active')
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      key: Key('group-learning-task-close-${task.id}'),
                      onPressed: busy ? null : onClose,
                      child: const Text('Đóng'),
                    ),
                  ),
              ],
            ),
            Text(
                'Mục tiêu ${task.targetWordCount} từ · hạn ${_dateTime(task.dueAt.toLocal())}'),
            const SizedBox(height: 8),
            Text(subtitle),
            if (!isOwner) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.masteryPercent / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentLearningCard extends StatelessWidget {
  const _StudentLearningCard({
    required this.student,
    required this.busy,
    required this.onViewWords,
  });

  final LearningGroupStudentOverview student;
  final bool busy;
  final Future<void> Function() onViewWords;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.ink, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.displayName,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                student.sharingEnabled
                    ? '${student.totalLearnedWordCount} từ đã học · '
                        '${student.completedTaskCount}/${student.activeTaskCount} nhiệm vụ · '
                        '${student.averageMasteryPercent}%'
                    : 'Học viên chưa bật chia sẻ tiến độ.',
              ),
              if (student.sharingEnabled) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: student.averageMasteryPercent / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: Key('group-student-vocabulary-${student.userId}'),
                    onPressed: busy ? null : onViewWords,
                    icon: const Icon(Icons.spellcheck_rounded),
                    label: const Text('Xem từ đã học'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.canManage,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onMute,
    required this.onRemove,
  });

  final LearningGroupMember member;
  final bool canManage;
  final bool busy;
  final Future<bool> Function() onApprove;
  final Future<bool> Function() onReject;
  final Future<bool> Function() onMute;
  final Future<bool> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final pending = member.status == LearningGroupMembershipStatus.pending;
    final student = member.role == LearningGroupRole.student;
    return Card(
      key: ValueKey('group-member-${member.userId}'),
      color: AppColors.softWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.ink),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                    student ? Icons.person_outline : Icons.school_outlined),
              ),
              title: Text(
                member.displayName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                member.username.isEmpty
                    ? (student ? 'Học viên' : 'Giáo viên')
                    : '@${member.username}',
              ),
              trailing: member.isMuted
                  ? const Tooltip(
                      message: 'Đã tắt quyền gửi chat',
                      child: Icon(Icons.volume_off_outlined),
                    )
                  : null,
            ),
            if (canManage && student && pending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: ValueKey('group-member-reject-${member.userId}'),
                      onPressed: busy ? null : onReject,
                      child: const Text('Từ chối'),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: ValueKey('group-member-approve-${member.userId}'),
                      onPressed: busy ? null : onApprove,
                      child: const Text('Duyệt'),
                    ),
                  ),
                ],
              )
            else if (canManage && student)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: ValueKey('group-member-mute-${member.userId}'),
                      onPressed: busy ? null : onMute,
                      icon: Icon(member.isMuted
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined),
                      label: Text(member.isMuted ? 'Bật chat' : 'Tắt chat'),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: ValueKey('group-member-remove-${member.userId}'),
                      onPressed: busy ? null : onRemove,
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Loại'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.canManage,
    required this.busy,
    required this.onPin,
  });

  final LearningGroupAnnouncement announcement;
  final bool canManage;
  final bool busy;
  final Future<bool> Function() onPin;

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('group-announcement-${announcement.id}'),
        color: announcement.isPinned
            ? const Color(0xFFFFF3C4)
            : AppColors.softWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.ink),
        ),
        child: ListTile(
          minVerticalPadding: 12,
          leading: Icon(
              announcement.isPinned ? Icons.push_pin : Icons.campaign_outlined),
          title: Text(announcement.body),
          subtitle: Text(announcement.authorDisplayName),
          trailing: canManage
              ? SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: ValueKey('group-announcement-pin-${announcement.id}'),
                    tooltip: announcement.isPinned ? 'Bỏ ghim' : 'Ghim',
                    onPressed: busy ? null : onPin,
                    icon: Icon(announcement.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin),
                  ),
                )
              : null,
        ),
      );
}

class _ModerationEventCard extends StatelessWidget {
  const _ModerationEventCard({required this.event});

  final LearningGroupModerationEvent event;

  @override
  Widget build(BuildContext context) => Card(
        key: ValueKey('group-audit-${event.id}'),
        color: AppColors.softWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.ink),
        ),
        child: ListTile(
          minVerticalPadding: 12,
          leading: const Icon(Icons.history_rounded),
          title: Text(_auditAction(event)),
          subtitle: Text(
            '${event.actorDisplayName} · '
            '${_dateTime(event.occurredAt.toLocal())}',
          ),
        ),
      );
}

class _DashboardNotice extends StatelessWidget {
  const _DashboardNotice({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFE1E1) : const Color(0xFFE8F3FF),
            border: Border.all(color: AppColors.ink),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text),
        ),
      );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, textAlign: TextAlign.center),
      );
}

Future<void> _createSystemTask(
  BuildContext context,
  GroupLearningNotifier notifier,
) async {
  final titleController = TextEditingController(text: 'Học từ mới');
  var targetWords = 10;
  var dueDays = 7;
  String? error;
  try {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Giao nhiệm vụ hệ thống'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('group-learning-task-title'),
                  controller: titleController,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: 'Tên nhiệm vụ',
                    errorText: error,
                  ),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const Key('group-learning-task-target'),
                  initialValue: targetWords,
                  decoration: const InputDecoration(labelText: 'Mục tiêu'),
                  items: const [5, 10, 20, 30]
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value từ mới'),
                          ))
                      .toList(),
                  onChanged: (value) => targetWords = value ?? targetWords,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const Key('group-learning-task-due'),
                  initialValue: dueDays,
                  decoration: const InputDecoration(labelText: 'Thời hạn'),
                  items: const [3, 7, 14, 30]
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value ngày'),
                          ))
                      .toList(),
                  onChanged: (value) => dueDays = value ?? dueDays,
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Hủy'),
              ),
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('group-learning-task-submit'),
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    setState(() => error = 'Nhập tên nhiệm vụ.');
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Giao nhiệm vụ'),
              ),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await notifier.createSystemTask(
        title: titleController.text,
        targetWordCount: targetWords,
        dueDays: dueDays,
      );
    }
  } finally {
    titleController.dispose();
  }
}

Future<void> _showStudentVocabulary(
  BuildContext context,
  GroupLearningNotifier notifier,
  LearningGroupStudentOverview student,
) async {
  final future = notifier.loadStudentVocabulary(student.userId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Từ đã học · ${student.displayName}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: FutureBuilder<List<LearningGroupSharedVocabulary>?>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final words = snapshot.data;
            if (words == null) {
              return const Center(child: Text('Không tải được danh sách từ.'));
            }
            if (words.isEmpty) {
              return const Center(
                  child: Text('Chưa có từ đã học được chia sẻ.'));
            }
            return ListView.separated(
              itemCount: words.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = words[index];
                return ListTile(
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.word,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Học gần nhất ${_dateTime(item.lastLearnedAt.toLocal())}',
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ),
      ],
    ),
  );
}

Future<void> _rotateInvite(
  BuildContext context,
  GroupManagementNotifier notifier,
) async {
  final invite = await notifier.rotateInvite();
  if (invite == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Mã mời mới'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mã chỉ hiển thị lần này. Hãy gửi qua kênh an toàn.'),
          const SizedBox(height: 12),
          SelectableText(invite.token, key: const Key('group-invite-token')),
          const SizedBox(height: 8),
          Text('Hết hạn: ${_dateTime(invite.expiresAt.toLocal())}'),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite.token));
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Sao chép'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

Future<void> _revokeInvite(
  BuildContext context,
  GroupManagementNotifier notifier,
) async {
  if (await notifier.revokeInvite() && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã thu hồi mã mời đang hoạt động.')),
    );
  }
}

Future<void> _createAnnouncement(
  BuildContext context,
  GroupManagementNotifier notifier,
) async {
  final controller = TextEditingController();
  final submit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Soạn thông báo'),
      content: TextField(
        key: const Key('group-announcement-input'),
        controller: controller,
        maxLength: 2000,
        maxLines: 5,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nội dung'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('group-announcement-submit'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Đăng'),
        ),
      ],
    ),
  );
  if (submit == true) await notifier.createAnnouncement(controller.text);
  controller.dispose();
}

Future<bool> _confirmRemove(
  BuildContext context,
  GroupManagementNotifier notifier,
  LearningGroupMember member,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Loại học viên?'),
      content:
          Text('${member.displayName} sẽ mất quyền vào lớp và group chat.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Loại'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  return notifier.removeMember(member.userId);
}

Future<void> _confirmArchive(
  BuildContext context,
  GroupManagementNotifier notifier,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Lưu trữ lớp?'),
      content: const Text(
        'Mã mời sẽ bị thu hồi và group chat chuyển sang chỉ đọc.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Lưu trữ'),
        ),
      ],
    ),
  );
  if (confirmed == true && await notifier.archiveGroup() && context.mounted) {
    Navigator.of(context).pop();
  }
}

String _dateTime(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')} '
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _auditAction(LearningGroupModerationEvent event) {
  final target = event.targetDisplayName;
  return switch (event.action) {
    'group_created' => 'Đã tạo lớp',
    'group_updated' => 'Đã cập nhật lớp',
    'group_archived' => 'Đã lưu trữ lớp',
    'invite_rotated' => 'Đã tạo mã mời mới',
    'invite_revoked' => 'Đã thu hồi mã mời',
    'join_requested' => '${target ?? 'Học viên'} đã xin tham gia',
    'join_approved' => 'Đã duyệt ${target ?? 'học viên'}',
    'join_rejected' => 'Đã từ chối ${target ?? 'học viên'}',
    'member_left' => '${target ?? 'Học viên'} đã rời lớp',
    'member_removed' => 'Đã loại ${target ?? 'học viên'}',
    'member_muted' => 'Đã tắt chat của ${target ?? 'học viên'}',
    'member_unmuted' => 'Đã bật chat của ${target ?? 'học viên'}',
    'announcement_created' => 'Đã đăng thông báo',
    'announcement_pinned' => 'Đã ghim thông báo',
    'announcement_unpinned' => 'Đã bỏ ghim thông báo',
    'message_hidden' => 'Đã ẩn tin nhắn nhóm',
    'message_restored' => 'Đã khôi phục tin nhắn nhóm',
    _ => event.action,
  };
}
