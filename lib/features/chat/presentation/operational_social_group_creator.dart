import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_provider.dart';

Future<ChatConversation?> showOperationalSocialGroupCreator(
        BuildContext context,
        {required ChatOwner owner}) =>
    showDialog<ChatConversation>(
        context: context, builder: (_) => _SocialGroupCreator(owner: owner));

class _SocialGroupCreator extends ConsumerStatefulWidget {
  const _SocialGroupCreator({required this.owner});
  final ChatOwner owner;

  @override
  ConsumerState<_SocialGroupCreator> createState() =>
      _SocialGroupCreatorState();
}

class _SocialGroupCreatorState extends ConsumerState<_SocialGroupCreator> {
  final _title = TextEditingController();
  final _selected = <String>{};
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating ||
        _selected.isEmpty ||
        _selected.length > 19 ||
        ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty || title.runes.length > 80) {
      setState(() => _error = 'Tên nhóm cần từ 1 đến 80 ký tự.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final runtime =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (runtime == null) throw StateError('Chat unavailable.');
      final conversation = await runtime.createSocialChatGroup(
        title: title,
        memberIds: _selected.toList()..sort(),
      );
      if (!mounted || ref.read(operationalChatOwnerProvider) != widget.owner) {
        return;
      }
      Navigator.of(context).pop(conversation);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Chưa tạo được nhóm. Cần mạng và chỉ được chọn bạn bè đã chấp nhận.');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(operationalChatOwnerProvider) != widget.owner) {
      return const AlertDialog(
          content: Text('Phiên đăng nhập đã thay đổi. Hãy đóng cửa sổ này.'));
    }
    final runtime = ref.watch(operationalChatCoordinatorProvider);
    final source =
        ref.watch(operationalChatSourceProvider(widget.owner)).asData?.value;
    final profiles = ref
            .watch(operationalChatPeerProfilesProvider(widget.owner))
            .asData
            ?.value ??
        const <ChatPeerProfile>[];
    final profileById = {for (final profile in profiles) profile.id: profile};
    final ready = !_creating && runtime.asData?.value != null && source != null;
    return AlertDialog(
      title: const Text('Tạo nhóm chat'),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(children: [
          TextField(
            key: const Key('social-group-title'),
            controller: _title,
            maxLength: 80,
            enabled: !_creating,
            decoration: const InputDecoration(
              labelText: 'Tên nhóm',
              hintText: 'Ví dụ: Nhóm học cuối tuần',
            ),
          ),
          if (_error != null) Text(_error!),
          if (source == null)
            const Text('Cần cấu hình ngôn ngữ trong Cài đặt.'),
          if (runtime.hasError)
            const Text('Chat chưa sẵn sàng. Hãy mở lại sau.'),
          if (_creating) const LinearProgressIndicator(),
          Expanded(
            child: ref.watch(operationalChatFriendsProvider(widget.owner)).when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, stack) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(
                          operationalChatFriendsProvider(widget.owner)),
                      child: const Text('Không tải được danh sách. Thử lại'),
                    ),
                  ),
                  data: (ids) => ids.isEmpty
                      ? const Center(child: Text('Chưa có bạn đã chấp nhận.'))
                      : ListView.builder(
                          itemCount: ids.length,
                          itemBuilder: (context, index) {
                            final id = ids[index];
                            final selected = _selected.contains(id);
                            final profile = profileById[id];
                            return CheckboxListTile(
                              key: ValueKey('social-group-member-$id'),
                              value: selected,
                              title: Text(profile?.label ?? _peer(id)),
                              subtitle:
                                  profile?.username.trim().isEmpty == false
                                      ? Text('@${profile!.username}')
                                      : null,
                              onChanged: ready
                                  ? (checked) {
                                      setState(() {
                                        _error = null;
                                        if (checked == true) {
                                          if (_selected.length < 19) {
                                            _selected.add(id);
                                          } else {
                                            _error =
                                                'Một nhóm có tối đa 20 thành viên.';
                                          }
                                        } else {
                                          _selected.remove(id);
                                        }
                                      });
                                    }
                                  : null,
                            );
                          },
                        ),
                ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          key: const Key('social-group-create'),
          onPressed: ready ? _create : null,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Tạo nhóm'),
        ),
      ],
    );
  }
}

String _peer(String id) => 'Bạn · ${id.substring(id.length - 8)}';
