import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/navigation/bottom_nav_bar.dart';
import '../../../shared/widgets/graph_paper_background.dart';
import '../domain/group_models.dart';
import 'group_management_sheet.dart';
import 'groups_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(groupsOwnerProvider);
    return GraphPaperScaffold(
      body: SafeArea(
        child: owner == null
            ? const _GroupsUnavailable()
            : _GroupsWorkspace(
                key: ValueKey('groups-${owner.scope}'),
                owner: owner,
              ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class _GroupsWorkspace extends ConsumerWidget {
  const _GroupsWorkspace({super.key, required this.owner});
  final GroupOwner owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupsWorkspaceProvider(owner));
    final notifier = ref.read(groupsWorkspaceProvider(owner).notifier);
    final capability = state.capabilities;
    final isTeacher = capability?.accountRole == 'teacher';
    final title = state.canManageGroups ? 'Quản lý lớp' : 'Nhóm của tôi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: const Key('groups-back'),
                  tooltip: 'Quay lại Bạn bè',
                  onPressed: () => context.go('/friends'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  key: const Key('groups-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: const Key('groups-refresh'),
                  tooltip: 'Làm mới nhóm học',
                  onPressed: state.isRefreshing ? null : notifier.refresh,
                  icon: state.isRefreshing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (state.canManageGroups)
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('groups-create'),
                    onPressed: state.isMutating
                        ? null
                        : () => _showCreateGroupDialog(context, notifier),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Tạo lớp'),
                  ),
                ),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const Key('groups-join'),
                  onPressed: state.isMutating
                      ? null
                      : () => _showJoinGroupDialog(context, notifier),
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Nhập mã mời'),
                ),
              ),
            ],
          ),
        ),
        if (isTeacher && !state.canManageGroups)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Tài khoản giáo viên đang chờ hoặc chưa đạt xác minh. '
              'Bạn vẫn có thể tham gia lớp bằng mã mời.',
              key: Key('groups-teacher-pending-message'),
              style: TextStyle(color: AppColors.ink, height: 1.35),
            ),
          ),
        if (state.message != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                state.message!,
                key: const Key('groups-message'),
                style: const TextStyle(color: Color(0xFF9B2C2C)),
              ),
            ),
          ),
        Expanded(child: _GroupsList(owner: owner, state: state)),
      ],
    );
  }
}

class _GroupsList extends StatelessWidget {
  const _GroupsList({required this.owner, required this.state});

  final GroupOwner owner;
  final GroupsState state;

  @override
  Widget build(BuildContext context) {
    if (!state.ready) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chưa có nhóm học.\nTạo lớp hoặc nhập mã mời để bắt đầu.',
            key: Key('groups-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.45),
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('groups-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: state.groups.length + 1,
      itemBuilder: (context, index) {
        if (index == state.groups.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              state.refreshedAt == null
                  ? 'Dữ liệu lưu trên máy'
                  : 'Đã cập nhật ${_formatTime(state.refreshedAt!.toLocal())}',
              key: const Key('groups-cache-time'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6D625B)),
            ),
          );
        }
        return _GroupCard(owner: owner, group: state.groups[index]);
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.owner, required this.group});

  final GroupOwner owner;
  final LearningGroupSummary group;

  @override
  Widget build(BuildContext context) {
    final pending =
        group.membershipStatus == LearningGroupMembershipStatus.pending;
    final isOwner = group.role == LearningGroupRole.ownerTeacher;
    final archived = group.status == LearningGroupStatus.archived;
    final status = pending
        ? 'Chờ giáo viên duyệt'
        : archived
            ? 'Đã lưu trữ'
            : isOwner
                ? '${group.activeStudentCount}/50 học viên · ${group.pendingStudentCount} chờ duyệt'
                : 'Đang tham gia';
    return Card(
      key: ValueKey('group-card-${group.id}'),
      color: AppColors.softWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.ink, width: 2),
      ),
      child: ListTile(
        minVerticalPadding: 14,
        onTap: pending
            ? null
            : () => showGroupManagementSheet(
                  context,
                  owner: owner,
                  group: group,
                ),
        leading: Icon(isOwner ? Icons.school_outlined : Icons.groups_rounded),
        title: Text(
          group.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(status),
        trailing: pending
            ? const Icon(Icons.hourglass_top_rounded)
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _GroupsUnavailable extends StatelessWidget {
  const _GroupsUnavailable();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nhóm học chưa sẵn sàng cho tài khoản hoặc môi trường này.',
            key: Key('groups-unavailable'),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

Future<void> _showCreateGroupDialog(
  BuildContext context,
  GroupsNotifier notifier,
) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tạo lớp học'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('group-title-input'),
              controller: title,
              maxLength: 80,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên lớp'),
            ),
            TextField(
              key: const Key('group-description-input'),
              controller: description,
              maxLength: 500,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Mô tả (không bắt buộc)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => context.pop(false), child: const Text('Hủy')),
        FilledButton(
          key: const Key('group-create-submit'),
          onPressed: () => context.pop(true),
          child: const Text('Tạo lớp'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    final success = await notifier.createGroup(
      title: title.text,
      description: description.text,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo lớp học.')),
      );
    }
  }
  title.dispose();
  description.dispose();
}

Future<void> _showJoinGroupDialog(
  BuildContext context,
  GroupsNotifier notifier,
) async {
  final token = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tham gia nhóm học'),
      content: TextField(
        key: const Key('group-invite-input'),
        controller: token,
        maxLength: 64,
        autofocus: true,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Mã mời'),
      ),
      actions: [
        TextButton(
            onPressed: () => context.pop(false), child: const Text('Hủy')),
        FilledButton(
          key: const Key('group-join-submit'),
          onPressed: () => context.pop(true),
          child: const Text('Gửi yêu cầu'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    final success = await notifier.requestJoin(token.text);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu tham gia.')),
      );
    }
  }
  token.dispose();
}

String _formatTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} '
      '${two(value.day)}/${two(value.month)}';
}
