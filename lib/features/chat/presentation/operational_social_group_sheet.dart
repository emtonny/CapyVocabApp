import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_provider.dart';

Future<void> showOperationalSocialGroupSheet(
  BuildContext context, {
  required ChatOwner owner,
  required ChatConversation conversation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => OperationalSocialGroupSheet(
      owner: owner,
      conversation: conversation,
    ),
  );
}

class OperationalSocialGroupSheet extends ConsumerStatefulWidget {
  const OperationalSocialGroupSheet({
    super.key,
    required this.owner,
    required this.conversation,
  });

  final ChatOwner owner;
  final ChatConversation conversation;

  @override
  ConsumerState<OperationalSocialGroupSheet> createState() =>
      _OperationalSocialGroupSheetState();
}

class _OperationalSocialGroupSheetState
    extends ConsumerState<OperationalSocialGroupSheet> {
  bool _working = false;
  String? _error;

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working || ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Chưa cập nhật được nhóm. Kiểm tra mạng và quyền của bạn rồi thử lại.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _rename() async {
    var pendingTitle = widget.conversation.title ?? '';
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextFormField(
          key: const Key('social-group-rename-input'),
          initialValue: pendingTitle,
          onChanged: (value) => pendingTitle = value,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Tên nhóm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('social-group-rename-confirm'),
            onPressed: () {
              final value = pendingTitle.trim();
              if (value.isNotEmpty && value.runes.length <= 80) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (title == null || title == widget.conversation.title) return;
    await _run(() async {
      final runtime =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (runtime == null) throw StateError('Chat unavailable.');
      await runtime.renameSocialChatGroup(widget.conversation.id, title);
    });
  }

  Future<void> _close() async {
    if (!await _confirm(
      'Đóng nhóm?',
      'Mọi thành viên vẫn đọc được lịch sử nhưng không thể gửi tin nhắn mới.',
    )) {
      return;
    }
    await _run(() async {
      final runtime =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (runtime == null) throw StateError('Chat unavailable.');
      await runtime.closeSocialChatGroup(widget.conversation.id);
    });
  }

  Future<void> _leave() async {
    if (!await _confirm(
      'Rời nhóm?',
      'Bạn sẽ mất quyền xem lịch sử nhóm ngay sau khi rời.',
    )) {
      return;
    }
    await _run(() async {
      final runtime =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (runtime == null) throw StateError('Chat unavailable.');
      await runtime.leaveSocialChatGroup(widget.conversation.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.conversation.isSocialGroup ||
        ref.watch(operationalChatOwnerProvider) != widget.owner) {
      return const Center(child: Text('Nhóm không còn khả dụng.'));
    }
    final isOwner = widget.conversation.isSocialOwner(widget.owner.userId);
    final members = ref.watch(operationalSocialChatMembersProvider(
        (widget.owner, widget.conversation.id)));
    return FractionallySizedBox(
      heightFactor: .82,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.mint,
                    child: Icon(Icons.groups_outlined, color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(widget.conversation.groupArchived
                            ? 'Nhóm đã đóng · chỉ đọc'
                            : '${widget.conversation.memberCount} thành viên'),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed:
                        _working ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_working) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFE94141)),
                  ),
                ),
              const SizedBox(height: 12),
              Flexible(
                child: members.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(
                          operationalSocialChatMembersProvider(
                              (widget.owner, widget.conversation.id))),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Không tải được thành viên. Thử lại'),
                    ),
                  ),
                  data: (rows) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final member = rows[index];
                      return ListTile(
                        key: ValueKey(
                            'social-group-profile-${member.profile.id}'),
                        minVerticalPadding: 10,
                        leading: _SocialMemberAvatar(profile: member.profile),
                        title: Text(member.profile.label),
                        subtitle: member.profile.username.trim().isEmpty
                            ? null
                            : Text('@${member.profile.username}'),
                        trailing: member.isOwner
                            ? const Chip(label: Text('Chủ nhóm'))
                            : null,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isOwner && !widget.conversation.groupArchived)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('social-group-rename'),
                        onPressed: _working ? null : _rename,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Đổi tên'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('social-group-close'),
                        onPressed: _working ? null : _close,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Đóng nhóm'),
                      ),
                    ),
                  ],
                ),
              if (!isOwner)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('social-group-leave'),
                    onPressed: _working ? null : _leave,
                    icon: const Icon(Icons.logout),
                    label: const Text('Rời nhóm'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialMemberAvatar extends StatelessWidget {
  const _SocialMemberAvatar({required this.profile});

  final ChatPeerProfile profile;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        profile.label.characters.first.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
    return CircleAvatar(
      backgroundColor: AppColors.creamyYuzu,
      foregroundImage: profile.avatarUrl.trim().isEmpty
          ? null
          : NetworkImage(profile.avatarUrl),
      child: fallback,
    );
  }
}
