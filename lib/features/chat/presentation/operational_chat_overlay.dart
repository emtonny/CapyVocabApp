import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../ai_scan/presentation/widgets/scan_paper_background.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_provider.dart';

const _bubbleSize = 64.0;
const _edgeInset = 8.0;
const _idleDelay = Duration(seconds: 5);

/// Global AssistiveTouch-style entry point for operational chat.
class OperationalChatOverlay extends ConsumerStatefulWidget {
  const OperationalChatOverlay({
    required this.child,
    this.openConversation,
    super.key,
  });

  final Widget child;
  final ValueChanged<String>? openConversation;

  @override
  ConsumerState<OperationalChatOverlay> createState() =>
      _OperationalChatOverlayState();
}

class _OperationalChatOverlayState
    extends ConsumerState<OperationalChatOverlay> {
  Offset? _position;
  Timer? _idleTimer;
  bool _panelOpen = false;
  bool _peeking = false;
  bool _dockRight = true;
  bool _isDraggingBubble = false;
  Offset _mailboxDragOffset = Offset.zero;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (_panelOpen || _isDraggingBubble) return;
    _idleTimer = Timer(_idleDelay, () {
      if (mounted) setState(() => _peeking = true);
    });
  }

  Offset _clamp(Offset value, Size size, EdgeInsets safe) => Offset(
        value.dx.clamp(
          safe.left + _edgeInset,
          math.max(safe.left + _edgeInset,
              size.width - safe.right - _bubbleSize - _edgeInset),
        ),
        value.dy.clamp(
          safe.top + _edgeInset,
          math.max(safe.top + _edgeInset,
              size.height - safe.bottom - _bubbleSize - 88),
        ),
      );

  void _openPanel() {
    _idleTimer?.cancel();
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _isDraggingBubble = false;
      _peeking = false;
      _panelOpen = true;
    });
  }

  void _closePanel() {
    setState(() {
      _panelOpen = false;
      _isDraggingBubble = false;
      _mailboxDragOffset = Offset.zero;
    });
    _restartIdleTimer();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(operationalChatEnabledProvider);
    final owner = enabled ? ref.watch(operationalChatOwnerProvider) : null;
    if (owner == null) {
      _idleTimer?.cancel();
      return widget.child;
    }
    final inbox = ref.watch(operationalChatInboxProvider(owner));
    final unread = inbox.asData?.value.fold<int>(
            0, (total, conversation) => total + conversation.unreadCount) ??
        0;
    if (!_panelOpen && !_peeking && !_isDraggingBubble && _idleTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _idleTimer == null &&
            !_panelOpen &&
            !_peeking &&
            !_isDraggingBubble) {
          _restartIdleTimer();
        }
      });
    }

    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final safe = MediaQuery.paddingOf(context);
      final viewInsets = MediaQuery.viewInsetsOf(context);
      final initial = Offset(
        size.width - safe.right - _bubbleSize - 14,
        size.height - safe.bottom - _bubbleSize - 116,
      );
      final position = _clamp(_position ?? initial, size, safe);
      final hiddenOffset = _peeking
          ? Offset(_dockRight ? _bubbleSize - 25 : -(_bubbleSize - 25), 0)
          : Offset.zero;

      return Stack(clipBehavior: Clip.none, children: [
        widget.child,
        if (_panelOpen) ...[
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Đóng hộp thư chat',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
                child: const ColoredBox(color: Color(0x33000000)),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: SafeArea(
                minimum: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(410.0, constraints.maxWidth);
                    final height = math.min(620.0, constraints.maxHeight);
                    final initialLeft = constraints.maxWidth - width;
                    final initialTop = (constraints.maxHeight - height) / 2;

                    final left = (initialLeft + _mailboxDragOffset.dx)
                        .clamp(0.0, initialLeft)
                        .toDouble();
                    final top = (initialTop + _mailboxDragOffset.dy)
                        .clamp(0.0, math.max(0.0, constraints.maxHeight - 70.0))
                        .toDouble();

                    return Stack(
                      children: [
                        Positioned(
                          left: left,
                          top: top,
                          width: width,
                          height: height,
                          child: _ChatMailbox(
                            key: ValueKey(owner.scope),
                            owner: owner,
                            onClose: _closePanel,
                            onOpenConversation: widget.openConversation,
                            onDragUpdate: (details) {
                              setState(() {
                                _mailboxDragOffset += details.delta;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ] else
          AnimatedPositioned(
            duration: _isDraggingBubble
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: position.dx + (_isDraggingBubble ? 0 : hiddenOffset.dx),
            top: position.dy + (_isDraggingBubble ? 0 : hiddenOffset.dy),
            width: _bubbleSize,
            height: _bubbleSize,
            child: Semantics(
              key: const Key('operational-chat-bubble'),
              button: true,
              label: unread == 0
                  ? 'Mở hộp thư chat'
                  : 'Mở hộp thư chat, $unread tin nhắn chưa đọc',
              child: MouseRegion(
                cursor: _isDraggingBubble
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openPanel,
                  onPanStart: (_) {
                    _idleTimer?.cancel();
                    setState(() {
                      _isDraggingBubble = true;
                      _peeking = false;
                      _position = position;
                    });
                  },
                  onPanUpdate: (details) {
                    final current = _position ?? position;
                    setState(() {
                      _position = _clamp(current + details.delta, size, safe);
                    });
                  },
                  onPanEnd: (_) {
                    final current = _clamp(_position ?? position, size, safe);
                    final center = current.dx + _bubbleSize / 2;
                    _dockRight = center >= size.width / 2;
                    setState(() {
                      _isDraggingBubble = false;
                      _position = Offset(
                        _dockRight
                            ? size.width - safe.right - _bubbleSize - _edgeInset
                            : safe.left + _edgeInset,
                        current.dy,
                      );
                    });
                    _restartIdleTimer();
                  },
                  onPanCancel: () {
                    if (_isDraggingBubble) {
                      setState(() => _isDraggingBubble = false);
                      _restartIdleTimer();
                    }
                  },
                  child: _ChatBubble(
                    unread: unread,
                    isDragging: _isDraggingBubble,
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.unread, this.isDragging = false});
  final int unread;
  final bool isDragging;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: isDragging ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Stack(clipBehavior: Clip.none, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.capyBrown,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink,
                  offset: isDragging ? const Offset(4, 6) : const Offset(3, 4),
                  blurRadius: isDragging ? 4 : 0,
                )
              ],
            ),
            child: const ClipOval(
              child: Image(
                image: AssetImage('assets/images/deery-email-avatar.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        if (unread > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE94141),
                border: Border.all(color: AppColors.softWhite, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ]),
    );
}

class _ChatMailbox extends ConsumerStatefulWidget {
  const _ChatMailbox({
    required this.owner,
    required this.onClose,
    this.onOpenConversation,
    this.onDragUpdate,
    super.key,
  });

  final ChatOwner owner;
  final VoidCallback onClose;
  final ValueChanged<String>? onOpenConversation;
  final GestureDragUpdateCallback? onDragUpdate;

  @override
  ConsumerState<_ChatMailbox> createState() => _ChatMailboxState();
}

class _ChatMailboxState extends ConsumerState<_ChatMailbox> {
  final _search = TextEditingController();
  String? _activeConversationId;
  String? _activePeerId;
  String? _openingPeer;
  bool _showAiNotice = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(String peerId, ChatConversation? conversation) async {
    if (_openingPeer != null) return;
    unawaited(HapticFeedback.selectionClick());
    if (conversation != null) {
      widget.onOpenConversation?.call(conversation.id);
      setState(() {
        _activeConversationId = conversation.id;
        _activePeerId = conversation.peerId;
      });
      return;
    }
    setState(() => _openingPeer = peerId);
    try {
      final coordinator =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (coordinator == null) throw StateError('Chat unavailable.');
      final opened = await coordinator.openDirectChat(peerId);
      if (mounted && ref.read(operationalChatOwnerProvider) == widget.owner) {
        widget.onOpenConversation?.call(opened.id);
        setState(() {
          _activeConversationId = opened.id;
          _activePeerId = peerId;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Chưa mở được cuộc trò chuyện. Kiểm tra mạng và hồ sơ ngôn ngữ.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingPeer = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(operationalChatProfileRefreshProvider(widget.owner));
    final inbox = ref.watch(operationalChatInboxProvider(widget.owner));
    final friends = ref.watch(operationalChatFriendsProvider(widget.owner));
    final profiles = ref
            .watch(operationalChatPeerProfilesProvider(widget.owner))
            .asData
            ?.value ??
        const <ChatPeerProfile>[];
    final profileById = {for (final profile in profiles) profile.id: profile};
    final conversations = inbox.asData?.value ?? const <ChatConversation>[];
    final conversationByPeer = {
      for (final conversation in conversations)
        conversation.peerId: conversation
    };
    final peerIds = <String>{
      ...conversationByPeer.keys,
      ...?friends.asData?.value,
    };
    final query = _search.text.trim().toLowerCase();
    final entries = peerIds.where((id) {
      if (query.isEmpty) return true;
      final profile = profileById[id];
      return id.toLowerCase().contains(query) ||
          (profile?.label.toLowerCase().contains(query) ?? false) ||
          (profile?.username.toLowerCase().contains(query) ?? false);
    }).toList()
      ..sort((a, b) {
        final left = conversationByPeer[a];
        final right = conversationByPeer[b];
        final unread =
            (right?.unreadCount ?? 0).compareTo(left?.unreadCount ?? 0);
        if (unread != 0) return unread;
        final leftAt = left?.lastMessageAt;
        final rightAt = right?.lastMessageAt;
        if (leftAt != null || rightAt != null) {
          if (leftAt == null) return 1;
          if (rightAt == null) return -1;
          final recent = rightAt.compareTo(leftAt);
          if (recent != 0) return recent;
        }
        return (profileById[a]?.label ?? a)
            .compareTo(profileById[b]?.label ?? b);
      });
    final totalUnread = conversations.fold<int>(
        0, (total, conversation) => total + conversation.unreadCount);

    Widget content;
    if (_activeConversationId != null) {
      final activePeerId = _activePeerId ??
          conversationByPeer.entries
              .firstWhere(
                (e) => e.value.id == _activeConversationId,
                orElse: () => MapEntry(
                  '',
                  ChatConversation(id: _activeConversationId!, peerId: ''),
                ),
              )
              .value
              .peerId;
      final activeProfile = profileById[activePeerId];
      content = _MailboxConversationView(
        key: ValueKey('mailbox-conv-$_activeConversationId'),
        owner: widget.owner,
        conversationId: _activeConversationId!,
        peerId: activePeerId,
        profile: activeProfile,
        onBack: () => setState(() {
          _activeConversationId = null;
          _activePeerId = null;
        }),
        onClose: widget.onClose,
        onDragUpdate: widget.onDragUpdate,
      );
    } else {
      content = Column(children: [
        _MailboxHeader(
          activeCount: peerIds.length,
          unreadCount: totalUnread,
          onClose: widget.onClose,
          onDragUpdate: widget.onDragUpdate,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(children: [
              TextField(
                key: const Key('chat-mailbox-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bạn bè...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.blue),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                        color: Color(0xFF3E322E), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                        color: Color(0xFF3E322E), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _AiCard(
                showNotice: _showAiNotice,
                onTap: () => setState(() => _showAiNotice = true),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'TRÒ CHUYỆN BẠN BÈ',
                  style: TextStyle(
                    color: Color(0xFF9B877D),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _MailboxList(
                  loading: inbox.isLoading && friends.isLoading,
                  hasError: inbox.hasError && friends.hasError,
                  peerIds: entries,
                  profileById: profileById,
                  conversationByPeer: conversationByPeer,
                  openingPeer: _openingPeer,
                  onOpen: _open,
                  onRetry: () {
                    ref.invalidate(
                        operationalChatFriendsProvider(widget.owner));
                    ref.invalidate(operationalChatProfileRefreshProvider(
                        widget.owner));
                  },
                ),
              ),
            ]),
          ),
        ),
      ]);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF3E322E), width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0xFF3E322E), offset: Offset(0, 10))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: ScanPaperBackground(),
              ),
            ),
            content,
          ],
        ),
      ),
    );
  }
}

class _MailboxHeader extends StatelessWidget {
  const _MailboxHeader({
    required this.activeCount,
    required this.unreadCount,
    required this.onClose,
    this.onDragUpdate,
  });
  final int activeCount;
  final int unreadCount;
  final VoidCallback onClose;
  final GestureDragUpdateCallback? onDragUpdate;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onDragUpdate,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1C7),
              border:
                  Border(bottom: BorderSide(color: Color(0xFF3E322E), width: 3)),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: const Icon(Icons.forum_rounded,
                    color: AppColors.blue, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Hộp Thư Chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.drag_indicator_rounded,
                          size: 14, color: Color(0xFF9B877D)),
                    ],
                  ),
                  Text(
                    unreadCount > 0
                        ? '$unreadCount chưa đọc · $activeCount bạn'
                        : '$activeCount bạn bè',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.darkGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
              IconButton(
                key: const Key('chat-mailbox-close'),
                tooltip: 'Đóng hộp thư',
                onPressed: onClose,
                icon: const Icon(Icons.close, color: AppColors.ink),
              ),
            ]),
          ),
        ),
      );
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.showNotice, required this.onTap});
  final bool showNotice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: const Key('chat-ai-card'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2CC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.duoOrange, width: 2.5),
            boxShadow: const [
              BoxShadow(color: AppColors.duoOrange, offset: Offset(0, 5))
            ],
          ),
          child: Row(children: [
            const CircleAvatar(
              radius: 23,
              backgroundImage:
                  AssetImage('assets/images/deery-email-avatar.jpg'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Deery-sensei AI ✨',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      showNotice
                          ? 'Chat với AI chưa mở. Bạn quay lại sau nhé!'
                          : 'Trợ lý học từ vựng · Sắp ra mắt',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ]),
            ),
            const Icon(Icons.lock_clock_outlined, color: AppColors.duoOrange),
          ]),
        ),
      );
}

class _MailboxList extends StatelessWidget {
  const _MailboxList({
    required this.loading,
    required this.hasError,
    required this.peerIds,
    required this.profileById,
    required this.conversationByPeer,
    required this.openingPeer,
    required this.onOpen,
    required this.onRetry,
  });

  final bool loading;
  final bool hasError;
  final List<String> peerIds;
  final Map<String, ChatPeerProfile> profileById;
  final Map<String, ChatConversation> conversationByPeer;
  final String? openingPeer;
  final void Function(String, ChatConversation?) onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && peerIds.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasError && peerIds.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Không tải được danh sách. Thử lại'),
        ),
      );
    }
    if (peerIds.isEmpty) {
      return const Center(
        child: Text('Không tìm thấy bạn bè hoặc cuộc trò chuyện.',
            textAlign: TextAlign.center),
      );
    }
    return ListView.builder(
      key: const Key('chat-mailbox-friends'),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: peerIds.length,
      itemBuilder: (context, index) {
        final peerId = peerIds[index];
        final profile = profileById[peerId];
        final conversation = conversationByPeer[peerId];
        return _FriendRow(
          key: ValueKey('chat-mailbox-peer-$peerId'),
          profile: profile,
          fallbackId: peerId,
          conversation: conversation,
          opening: openingPeer == peerId,
          onTap: () => onOpen(peerId, conversation),
        );
      },
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.profile,
    required this.fallbackId,
    required this.conversation,
    required this.opening,
    required this.onTap,
    super.key,
  });
  final ChatPeerProfile? profile;
  final String fallbackId;
  final ChatConversation? conversation;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile?.label ??
        'Bạn · ${fallbackId.substring(fallbackId.length - 8)}';
    final text = conversation?.lastMessageText?.trim();
    final subtitle = text?.isNotEmpty == true
        ? text!
        : conversation == null
            ? 'Bắt đầu cuộc trò chuyện'
            : 'Chưa có tin nhắn';
    final unread = conversation?.unreadCount ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3E322E), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF3E322E), offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          minVerticalPadding: 10,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: _PeerAvatar(profile: profile, label: name),
          title: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF9B877D), fontSize: 12)),
          trailing: opening
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (conversation?.lastMessageAt != null)
                    Text(_relativeTime(conversation!.lastMessageAt!),
                        style: const TextStyle(
                            color: Color(0xFF9B877D), fontSize: 12)),
                  if (unread > 0) ...[
                    const SizedBox(width: 7),
                    Container(
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE94141),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ]),
          onTap: opening ? null : onTap,
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.profile, required this.label});
  final ChatPeerProfile? profile;
  final String label;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl.trim() ?? '';
    final fallback = Center(
      child: Text(label.isEmpty ? '?' : label.characters.first.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900)),
    );
    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.creamyYuzu,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: avatarUrl.isEmpty
          ? fallback
          : Image.network(avatarUrl,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'vừa xong';
  if (difference.inMinutes < 60) return '${difference.inMinutes}p';
  if (difference.inHours < 24) return '${difference.inHours}g';
  if (difference.inDays < 7) return '${difference.inDays}n';
  final local = value.toLocal();
  return '${local.day}/${local.month}';
}

class _MailboxConversationView extends ConsumerStatefulWidget {
  const _MailboxConversationView({
    super.key,
    required this.owner,
    required this.conversationId,
    required this.peerId,
    required this.profile,
    required this.onBack,
    required this.onClose,
    this.onDragUpdate,
  });

  final ChatOwner owner;
  final String conversationId;
  final String peerId;
  final ChatPeerProfile? profile;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final GestureDragUpdateCallback? onDragUpdate;

  @override
  ConsumerState<_MailboxConversationView> createState() =>
      _MailboxConversationViewState();
}

class _MailboxConversationViewState
    extends ConsumerState<_MailboxConversationView> {
  static final Map<String, Uint8List> _localImageAttachments = {};
  final _text = TextEditingController();
  Uint8List? _attachedImageBytes;
  String? _attachedImageName;
  bool _saving = false;
  bool _markingRead = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachedImageBytes = bytes;
        _attachedImageName = picked.name;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chọn ảnh từ thư viện thiết bị.'),
          ),
        );
      }
    }
  }

  Future<void> _send() async {
    if (_saving || ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    final imageBytes = _attachedImageBytes;
    final imageName = _attachedImageName;
    var raw = _text.text.trim();
    if (imageBytes != null) {
      final label = '📷 [Ảnh: ${imageName ?? 'image.jpg'}]';
      raw = raw.isEmpty ? label : '$label\n$raw';
    }
    if (raw.isEmpty || raw.runes.length > 4000) return;
    final coordinator =
        ref.read(operationalChatCoordinatorProvider).asData?.value;
    if (coordinator == null) return;
    setState(() => _saving = true);
    try {
      final sent = await coordinator.enqueue(
          conversationId: widget.conversationId, rawText: raw);
      if (!mounted || ref.read(operationalChatOwnerProvider) != widget.owner) {
        return;
      }
      if (imageBytes != null) {
        _localImageAttachments[sent.id] = imageBytes;
        _localImageAttachments[sent.clientGeneratedId] = imageBytes;
      }
      _text.clear();
      setState(() {
        _attachedImageBytes = null;
        _attachedImageName = null;
      });
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

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(operationalChatInboxProvider(widget.owner));
    final rows = inbox.asData?.value;
    ChatConversation? conversation;
    for (final row in rows ?? <ChatConversation>[]) {
      if (row.id == widget.conversationId) conversation = row;
    }

    if (conversation != null && conversation.unreadCount > 0 && !_markingRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    }

    final source =
        ref.watch(operationalChatSourceProvider(widget.owner)).asData?.value;
    final runtime = ref.watch(operationalChatCoordinatorProvider);
    final ready = source != null && runtime.asData?.value != null && !_saving;
    final messages = ref.watch(
        operationalChatMessagesProvider((widget.owner, widget.conversationId)));

    final peerName = widget.profile?.label ??
        (widget.peerId.length >= 8
            ? 'Bạn · ${widget.peerId.substring(widget.peerId.length - 8)}'
            : (widget.peerId.isNotEmpty ? widget.peerId : 'Bạn'));

    return Column(
      children: [
        _ConversationHeader(
          profile: widget.profile,
          peerName: peerName,
          onBack: widget.onBack,
          onClose: widget.onClose,
          onDragUpdate: widget.onDragUpdate,
        ),
        Expanded(
          child: messages.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Không đọc được tin nhắn trên máy.')),
            data: (msgList) => msgList.isEmpty
                ? const Center(
                    child: Text(
                      'Bắt đầu trò chuyện với bạn.',
                      style: TextStyle(
                        color: Color(0xFF9B877D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const Key('chat-mailbox-messages-list'),
                    reverse: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: msgList.length,
                    itemBuilder: (context, index) {
                      final message = msgList[msgList.length - index - 1];
                      final mine = message.senderId == widget.owner.userId;
                      final localAttachment =
                          _localImageAttachments[message.id] ??
                              _localImageAttachments[message.clientGeneratedId];
                      final hasPhotoTag = message.rawText.contains('📷 [Ảnh:');
                      String displayText = message.rawText;
                      String? photoName;
                      if (hasPhotoTag) {
                        final match = RegExp(r'📷 \[Ảnh:\s*([^\]]+)\]')
                            .firstMatch(message.rawText);
                        photoName = match?.group(1);
                        final lines = message.rawText.split('\n');
                        if (lines.length > 1) {
                          displayText = lines.sublist(1).join('\n').trim();
                        } else {
                          displayText = '';
                        }
                      }

                      final statusText =
                          mine ? _status(message.sendStatus) : null;
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                key: ValueKey(message.id),
                                constraints:
                                    const BoxConstraints(maxWidth: 280),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: mine ? AppColors.mint : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF3E322E), width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFF3E322E),
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: mine
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (localAttachment != null)
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                          child: Image.memory(
                                            localAttachment,
                                            width: 220,
                                            height: 140,
                                            fit: BoxFit.cover,
                                          ),
                                      )
                                    else if (hasPhotoTag)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: mine
                                              ? const Color(0xFF56CFA9)
                                              : const Color(0xFFF3ECE4),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.image_outlined,
                                                size: 18,
                                                color: AppColors.ink),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                photoName ?? 'Hình ảnh',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: AppColors.ink,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (displayText.isNotEmpty) ...[
                                      if (hasPhotoTag)
                                        const SizedBox(height: 6),
                                      SelectableText(
                                        displayText,
                                        style: const TextStyle(
                                          color: AppColors.ink,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '${_time(message.sentAt ?? message.clientCreatedAt)}${statusText != null ? ' · $statusText' : ''}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF7A6B63),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        if (source == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Cần cấu hình ngôn ngữ trong Cài đặt trước khi gửi.',
              style: TextStyle(fontSize: 11, color: Color(0xFFE94141)),
            ),
          ),
        _ConversationInput(
          controller: _text,
          saving: _saving,
          ready: ready,
          onSend: _send,
          onChanged: () => setState(() {}),
          onPickImage: _pickImage,
          attachedImageBytes: _attachedImageBytes,
          attachedImageName: _attachedImageName,
          onRemoveAttachedImage: () => setState(() {
            _attachedImageBytes = null;
            _attachedImageName = null;
          }),
        ),
      ],
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.profile,
    required this.peerName,
    required this.onBack,
    required this.onClose,
    this.onDragUpdate,
  });

  final ChatPeerProfile? profile;
  final String peerName;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final GestureDragUpdateCallback? onDragUpdate;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onDragUpdate,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1C7),
              border:
                  Border(bottom: BorderSide(color: Color(0xFF3E322E), width: 3)),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const Key('chat-mailbox-back'),
                  tooltip: 'Quay lại danh sách',
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  onPressed: onBack,
                ),
                _PeerAvatar(profile: profile, label: peerName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.drag_indicator_rounded,
                              size: 14, color: Color(0xFF9B877D)),
                        ],
                      ),
                      const Text(
                        'Chỉ text gốc, chưa dịch',
                        style: TextStyle(
                          color: Color(0xFF9B877D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('chat-mailbox-close-conv'),
                  tooltip: 'Đóng hộp thư',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ConversationInput extends StatelessWidget {
  const _ConversationInput({
    required this.controller,
    required this.saving,
    required this.ready,
    required this.onSend,
    required this.onChanged,
    required this.onPickImage,
    this.attachedImageBytes,
    this.attachedImageName,
    this.onRemoveAttachedImage,
  });

  final TextEditingController controller;
  final bool saving;
  final bool ready;
  final VoidCallback onSend;
  final VoidCallback onChanged;
  final VoidCallback onPickImage;
  final Uint8List? attachedImageBytes;
  final String? attachedImageName;
  final VoidCallback? onRemoveAttachedImage;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty &&
        controller.text.runes.length <= 4000;
    final hasImage = attachedImageBytes != null;
    final canSend = ready && (hasText || hasImage);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(
          top: BorderSide(color: Color(0xFF3E322E), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachedImageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3E322E), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF3E322E), offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      attachedImageBytes!,
                      width: 38,
                      height: 38,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Đã đính kèm ảnh',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          attachedImageName ?? 'anh_album.jpg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9B877D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Hủy đính kèm ảnh',
                    child: InkWell(
                      key: const Key('chat-remove-attached-image'),
                      onTap: onRemoveAttachedImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF1EAE4),
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                button: true,
                label: 'Chọn ảnh từ album gửi bạn bè',
                child: InkWell(
                  key: const Key('chat-pick-image'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: saving ? null : onPickImage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: const Color(0xFF3E322E), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF3E322E),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.ink,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: const Color(0xFF3E322E), width: 2),
                  ),
                  child: TextField(
                    key: const Key('chat-compose'),
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !saving,
                    onChanged: (_) => onChanged(),
                    style:
                        const TextStyle(fontSize: 14, color: AppColors.ink),
                    decoration: const InputDecoration(
                      hintText: 'Tin nhắn gốc (chưa dịch)...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Color(0xFF9B877D)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Gửi tin nhắn',
                child: InkWell(
                  key: const Key('chat-send'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: canSend ? onSend : null,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: canSend
                          ? AppColors.mint
                          : const Color(0xFFE0D8CE),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF3E322E), width: 2),
                      boxShadow: canSend
                          ? const [
                              BoxShadow(
                                color: Color(0xFF3E322E),
                                offset: Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF3E322E),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Color(0xFF3E322E),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _status(ChatSendStatus status) => switch (status) {
      ChatSendStatus.pending => 'Đang gửi...',
      ChatSendStatus.sent => null,
      ChatSendStatus.blocked => 'Không gửi được',
    };

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
