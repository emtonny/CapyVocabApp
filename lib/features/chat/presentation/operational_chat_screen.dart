import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/graph_paper_background.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_provider.dart';

/// Operational raw text only. No translation or Training reads/writes here.
class OperationalChatScreen extends ConsumerWidget {
  const OperationalChatScreen({super.key, this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(operationalChatEnabledProvider);
    final owner = enabled ? ref.watch(operationalChatOwnerProvider) : null;
    var valid = true;
    try {
      if (conversationId != null) validateChatUuid(conversationId!);
    } on FormatException {
      valid = false;
    }
    return GraphPaperScaffold(
      maxContentWidth: 720,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/friends')),
              const Expanded(
                  child: Text('Trò chuyện · Staging',
                      style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 22,
                          fontWeight: FontWeight.bold))),
              if (owner != null && conversationId == null)
                IconButton(
                    key: const Key('chat-new'),
                    tooltip: 'Chat mới',
                    icon: const Icon(Icons.edit_square),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _FriendPicker(owner: owner))),
            ]),
          ),
          Expanded(
              child: owner == null
                  ? const _Notice(
                      'Chat chỉ bật trong build Staging có relay và phiên đăng nhập.')
                  : !valid
                      ? const _Notice('Không tìm thấy cuộc trò chuyện.')
                      : conversationId == null
                          ? _Inbox(owner: owner)
                          : _Detail(
                              key: ValueKey('${owner.scope}:$conversationId'),
                              owner: owner,
                              conversationId: conversationId!)),
        ]),
      ),
    );
  }
}

class _Inbox extends ConsumerWidget {
  const _Inbox({required this.owner});
  final ChatOwner owner;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(operationalChatInboxProvider(owner)).when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, stack) =>
              const _Notice('Không đọc được lịch sử trên máy.'),
          data: (rows) => rows.isEmpty
              ? const _Notice(
                  'Chưa có cuộc trò chuyện. Bấm Chat mới để chọn bạn đã chấp nhận.')
              : ListView.builder(
                  itemCount: rows.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                        child: ListTile(
                            key: ValueKey(row.id),
                            leading: const Icon(Icons.person_outline),
                            title: Text(_peer(row.peerId)),
                            subtitle: Text(row.lastMessageAt == null
                                ? 'Chưa có tin nhắn'
                                : 'Hoạt động: ${_time(row.lastMessageAt!)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/chat/${row.id}')));
                  }),
        );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({super.key, required this.owner, required this.conversationId});
  final ChatOwner owner;
  final String conversationId;
  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  final _text = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_saving || ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    final raw = _text.text;
    if (raw.trim().isEmpty || raw.runes.length > 4000) return;
    final coordinator =
        ref.read(operationalChatCoordinatorProvider).asData?.value;
    if (coordinator == null) return;
    setState(() => _saving = true);
    try {
      await coordinator.enqueue(
          conversationId: widget.conversationId, rawText: raw);
      if (!mounted || ref.read(operationalChatOwnerProvider) != widget.owner) {
        return;
      }
      if (_text.text == raw) _text.clear();
    } catch (_) {
      if (mounted && ref.read(operationalChatOwnerProvider) == widget.owner) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Chưa lưu được tin nhắn. Nội dung nhập vẫn được giữ.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(operationalChatInboxProvider(widget.owner));
    // An absent/inactive conversation cannot compose, including stale deep links.
    final rows = inbox.asData?.value;
    ChatConversation? conversation;
    for (final row in rows ?? <ChatConversation>[]) {
      if (row.id == widget.conversationId) conversation = row;
    }
    if (inbox.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (conversation == null) {
      return const _Notice(
          'Cuộc trò chuyện chưa có trên máy hoặc bạn không còn quyền truy cập.');
    }
    final source =
        ref.watch(operationalChatSourceProvider(widget.owner)).asData?.value;
    final runtime = ref.watch(operationalChatCoordinatorProvider);
    final ready = source != null && runtime.asData?.value != null && !_saving;
    final messages = ref.watch(
        operationalChatMessagesProvider((widget.owner, widget.conversationId)));
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Text('${_peer(conversation.peerId)} · chỉ text gốc, chưa dịch')),
      Expanded(
          child: messages.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, stack) => const _Notice('Không đọc được tin nhắn trên máy.'),
        data: (rows) => rows.isEmpty
            ? const _Notice('Bắt đầu trò chuyện với bạn.')
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final message = rows[rows.length - index - 1];
                  final mine = message.senderId == widget.owner.userId;
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                        key: ValueKey(message.id),
                        constraints: const BoxConstraints(maxWidth: 520),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: mine ? AppColors.mint : AppColors.softWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.ink, width: 2)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(message.rawText),
                              const SizedBox(height: 6),
                              Text(
                                  '${_time(message.sentAt ?? message.clientCreatedAt)} · ${_status(message.sendStatus)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.ink)),
                            ])),
                  );
                }),
      )),
      if (source == null)
        const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Cần cấu hình ngôn ngữ trong Cài đặt trước khi gửi.')),
      if (runtime.hasError)
        const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Chat chưa sẵn sàng. Lịch sử local vẫn đọc được.')),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
                    key: const Key('chat-compose'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_saving,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Tin nhắn gốc',
                        hintText: 'Offline: lưu chờ, gửi khi có mạng',
                        border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            IconButton.filled(
                key: const Key('chat-send'),
                tooltip: 'Gửi tin nhắn',
                onPressed: ready &&
                        _text.text.trim().isNotEmpty &&
                        _text.text.runes.length <= 4000
                    ? _send
                    : null,
                icon: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send)),
          ])),
    ]);
  }
}

class _FriendPicker extends ConsumerStatefulWidget {
  const _FriendPicker({required this.owner});
  final ChatOwner owner;
  @override
  ConsumerState<_FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends ConsumerState<_FriendPicker> {
  bool _opening = false;
  String? _error;
  Future<void> _open(String peer) async {
    if (_opening || ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final runtime =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (runtime == null) throw StateError('Chat unavailable.');
      final conversation = await runtime.openDirectChat(peer);
      if (!mounted || ref.read(operationalChatOwnerProvider) != widget.owner) {
        return;
      }
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/chat/${conversation.id}');
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Chưa mở được chat. Cần mạng, hai profile ngôn ngữ và quan hệ bạn bè hai chiều đã chấp nhận.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
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
    final ready = !_opening && runtime.asData?.value != null && source != null;
    return AlertDialog(
        title: const Text('Chọn bạn đã chấp nhận'),
        content: SizedBox(
            width: 420,
            height: 320,
            child: Column(children: [
              if (_error != null) Text(_error!),
              if (source == null)
                const Text('Cần cấu hình ngôn ngữ trong Cài đặt.'),
              if (runtime.hasError)
                const Text('Chat chưa sẵn sàng. Hãy mở lại sau.'),
              if (_opening) const LinearProgressIndicator(),
              Expanded(
                  child: ref
                      .watch(operationalChatFriendsProvider(widget.owner))
                      .when(
                        skipLoadingOnRefresh: false,
                        skipLoadingOnReload: false,
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, stack) => Center(
                            child: TextButton(
                                onPressed: () => ref.invalidate(
                                    operationalChatFriendsProvider(
                                        widget.owner)),
                                child: const Text(
                                    'Không tải được danh sách. Thử lại'))),
                        data: (ids) => ids.isEmpty
                            ? const _Notice('Chưa có bạn đã chấp nhận.')
                            : ListView.builder(
                                itemCount: ids.length,
                                itemBuilder: (context, index) => ListTile(
                                    title: Text(_peer(ids[index])),
                                    subtitle: Text(ids[index]),
                                    onTap: ready
                                        ? () => _open(ids[index])
                                        : null)),
                      )),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'))
        ]);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center)));
}

String _peer(String id) => 'Bạn · ${id.substring(id.length - 8)}';
String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _status(ChatSendStatus status) => switch (status) {
      ChatSendStatus.pending => 'Đã lưu trên máy · chờ gửi',
      ChatSendStatus.sent => 'Server đã nhận',
      ChatSendStatus.blocked => 'Không gửi được · bản local được giữ',
    };
