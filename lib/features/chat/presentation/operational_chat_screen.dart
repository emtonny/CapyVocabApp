import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/graph_paper_background.dart';
import '../../library/domain/entities/local_vocabulary_match.dart';
import '../../library/presentation/providers/library_provider.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_dictionary_sheet.dart';
import 'operational_chat_correction_panel.dart';
import 'operational_chat_message_body.dart';
import 'operational_chat_provider.dart';
import 'operational_social_group_sheet.dart';

/// Operational Chat reads local raw/translation caches; Training stays separate.
class OperationalChatScreen extends ConsumerWidget {
  const OperationalChatScreen({super.key, this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(operationalChatEnabledProvider);
    final owner = enabled ? ref.watch(operationalChatOwnerProvider) : null;
    if (owner != null) {
      ref.watch(operationalChatProfileRefreshProvider(owner));
    }
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
                  child: Text('Trò chuyện · Beta',
                      style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 22,
                          fontWeight: FontWeight.bold))),
              if (owner != null && conversationId == null)
                IconButton(
                    key: const Key('chat-new'),
                    tooltip: 'Chat riêng mới',
                    icon: const Icon(Icons.edit_square),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _FriendPicker(owner: owner))),
              if (owner != null && conversationId == null)
                IconButton(
                    key: const Key('chat-new-group'),
                    tooltip: 'Tạo nhóm chat',
                    icon: const Icon(Icons.group_add_outlined),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _SocialGroupCreator(owner: owner))),
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
    final profiles =
        ref.watch(operationalChatPeerProfilesProvider(owner)).asData?.value ??
            const <ChatPeerProfile>[];
    final profileById = {for (final profile in profiles) profile.id: profile};
    return ref.watch(operationalChatInboxProvider(owner)).when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, stack) =>
              const _Notice('Không đọc được lịch sử trên máy.'),
          data: (rows) => rows.isEmpty
              ? const _Notice(
                  'Chưa có cuộc trò chuyện. Hãy bắt đầu chat riêng hoặc tạo nhóm với bạn bè đã chấp nhận.')
              : ListView.builder(
                  itemCount: rows.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                        child: ListTile(
                            key: ValueKey(row.id),
                            leading: Icon(row.isGroup
                                ? Icons.groups_outlined
                                : Icons.person_outline),
                            title: Text(_conversationLabel(row, profileById)),
                            subtitle: Text(_conversationSubtitle(row)),
                            trailing: row.unreadCount == 0
                                ? const Icon(Icons.chevron_right)
                                : Badge(label: Text('${row.unreadCount}')),
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
  bool _markingRead = false;
  String? _speakingLineKey;
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

  Future<void> _markRead() async {
    if (_markingRead ||
        ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    _markingRead = true;
    try {
      final store =
          await ref.read(operationalChatStoreProvider(widget.owner).future);
      await store?.markConversationRead(widget.conversationId);
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _speak(
    OperationalChatMessage message,
    String text,
    String languageCode,
  ) async {
    if (_speakingLineKey != null ||
        ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    final lineKey = '${message.id}:$languageCode';
    setState(() => _speakingLineKey = lineKey);
    try {
      await ref
          .read(operationalChatTtsProvider)
          .speak(text, languageCode: languageCode);
    } catch (_) {
      if (mounted && ref.read(operationalChatOwnerProvider) == widget.owner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thiết bị chưa phát được nội dung này. Hãy kiểm tra giọng đọc.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && _speakingLineKey == lineKey) {
        setState(() => _speakingLineKey = null);
      }
    }
  }

  Future<void> _lookupVocabulary(
      String selectedText, String languageCode) async {
    final query = normalizeLocalVocabularyQuery(selectedText);
    if (languageCode != 'en' ||
        query.isEmpty ||
        query.runes.length > 80 ||
        ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }

    Future<List<LocalVocabularyMatch>> lookup() async {
      if (ref.read(operationalChatOwnerProvider) != widget.owner) {
        throw StateError('Chat owner changed.');
      }
      final repository =
          await ref.read(localVocabularyLookupRepositoryProvider.future);
      if (ref.read(operationalChatOwnerProvider) != widget.owner) {
        throw StateError('Chat owner changed.');
      }
      final matches = await repository.lookupLocalVocabulary(
        userId: widget.owner.userId,
        query: query,
      );
      if (ref.read(operationalChatOwnerProvider) != widget.owner) {
        throw StateError('Chat owner changed.');
      }
      return matches;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, child) {
          if (ref.watch(operationalChatOwnerProvider) != widget.owner) {
            return const SafeArea(
              child: _Notice('Phiên đăng nhập đã thay đổi. Hãy đóng tra từ.'),
            );
          }
          return OperationalChatDictionarySheet(query: query, lookup: lookup);
        },
      ),
    );
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
    final current = conversation;
    if (inbox.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (current == null) {
      return const _Notice(
          'Cuộc trò chuyện chưa có trên máy hoặc bạn không còn quyền truy cập.');
    }
    if (current.unreadCount > 0 && !_markingRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    }
    final source =
        ref.watch(operationalChatSourceProvider(widget.owner)).asData?.value;
    final runtime = ref.watch(operationalChatCoordinatorProvider);
    final ready = source != null &&
        runtime.asData?.value != null &&
        current.canSend &&
        !_saving;
    final messages = ref.watch(
        operationalChatMessagesProvider((widget.owner, widget.conversationId)));
    final translations = ref.watch(operationalChatTranslationsProvider(
        (widget.owner, widget.conversationId)));
    final translationsByMessage = {
      for (final row
          in translations.asData?.value ?? <OperationalChatTranslation>[])
        row.messageId: row,
    };
    final profiles = ref
            .watch(operationalChatPeerProfilesProvider(widget.owner))
            .asData
            ?.value ??
        const <ChatPeerProfile>[];
    final profileById = {for (final profile in profiles) profile.id: profile};
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text(
                    '${_conversationLabel(current, profileById)} · tin gốc luôn được giữ · bản dịch theo hồ sơ'),
              ),
              if (current.isSocialGroup)
                IconButton(
                  key: const Key('social-group-manage'),
                  tooltip: 'Thông tin và quản lý nhóm',
                  onPressed: () => showOperationalSocialGroupSheet(
                    context,
                    owner: widget.owner,
                    conversation: current,
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
            ]),
            const Text(
              'Bôi đen từ tiếng Anh để Tra từ trong Library trên máy.',
              key: Key('chat-dictionary-hint'),
              style: TextStyle(fontSize: 12, color: Color(0xFF665952)),
            ),
          ])),
      Expanded(
          child: messages.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, stack) => const _Notice('Không đọc được tin nhắn trên máy.'),
        data: (rows) => rows.isEmpty
            ? _Notice(current.isGroup
                ? 'Chưa có tin nhắn trong nhóm.'
                : 'Bắt đầu trò chuyện với bạn.')
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
                              if (current.isGroup && !mine)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    profileById[message.senderId]?.label ??
                                        _member(message.senderId),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkGreen,
                                    ),
                                  ),
                                ),
                              OperationalChatMessageBody(
                                message: message,
                                viewerNativeLanguageCode: source,
                                translation: translationsByMessage[message.id],
                                translationCacheLoading: translations.isLoading,
                                translationCacheError: translations.hasError,
                                speakingLineKey: _speakingLineKey,
                                onSpeak: (text, languageCode) =>
                                    _speak(message, text, languageCode),
                                onLookup: (text, languageCode) =>
                                    _lookupVocabulary(text, languageCode),
                              ),
                              if (current.isDirect)
                                OperationalChatCorrectionPanel(
                                  owner: widget.owner,
                                  conversationId: widget.conversationId,
                                  message: message,
                                  viewerNativeLanguageCode: source,
                                ),
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
      if (!current.canSend)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            current.groupArchived
                ? current.isSocialGroup
                    ? 'Nhóm đã đóng · lịch sử chỉ đọc.'
                    : 'Nhóm đã lưu trữ · lịch sử chỉ đọc.'
                : 'Bạn đang bị tắt quyền gửi trong nhóm này.',
            key: const Key('chat-group-read-only'),
          ),
        ),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
                    key: const Key('chat-compose'),
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !_saving && current.canSend,
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
    final profiles = ref
            .watch(operationalChatPeerProfilesProvider(widget.owner))
            .asData
            ?.value ??
        const <ChatPeerProfile>[];
    final profileById = {for (final profile in profiles) profile.id: profile};
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
                                itemBuilder: (context, index) {
                                  final id = ids[index];
                                  final profile = profileById[id];
                                  return ListTile(
                                    title: Text(profile?.label ?? _peer(id)),
                                    subtitle:
                                        profile?.username.trim().isEmpty ==
                                                false
                                            ? Text('@${profile!.username}')
                                            : null,
                                    onTap: ready ? () => _open(id) : null,
                                  );
                                }),
                      )),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'))
        ]);
  }
}

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
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push('/chat/${conversation.id}');
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
                      ? const _Notice('Chưa có bạn đã chấp nhận.')
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
String _member(String id) => 'Thành viên · ${id.substring(id.length - 8)}';
String _conversationLabel(
  ChatConversation conversation, [
  Map<String, ChatPeerProfile> profileById = const {},
]) =>
    conversation.isGroup
        ? conversation.title!
        : profileById[conversation.peerId]?.label ?? _peer(conversation.peerId);
String _conversationSubtitle(ChatConversation conversation) {
  final activity = conversation.lastMessageAt == null
      ? 'Chưa có tin nhắn'
      : 'Hoạt động: ${_time(conversation.lastMessageAt!)}';
  if (conversation.isDirect) return activity;
  final access = conversation.groupArchived
      ? 'đã lưu trữ'
      : conversation.groupMuted
          ? 'chỉ đọc'
          : '${conversation.memberCount} thành viên';
  return '$access · $activity';
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _status(ChatSendStatus status) => switch (status) {
      ChatSendStatus.pending => 'Đã lưu trên máy · chờ gửi',
      ChatSendStatus.sent => 'Server đã nhận',
      ChatSendStatus.blocked => 'Không gửi được · bản local được giữ',
    };
