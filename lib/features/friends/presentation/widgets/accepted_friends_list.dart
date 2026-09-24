import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/friend_entity.dart';
import '../providers/accepted_friends_provider.dart';
import '../providers/friends_provider.dart';
import 'friend_list_item.dart';

class AcceptedFriendsList extends ConsumerWidget {
  const AcceptedFriendsList({super.key, required this.owner});

  final FriendOwner owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(friendsOwnerProvider) != owner) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(acceptedFriendsProvider(owner));
    final chat = ref.watch(friendChatAccessProvider(owner));
    final notifier = ref.read(acceptedFriendsProvider(owner).notifier);

    if (!state.ready || !state.cacheLoaded) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('accepted-friends-loading'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Bạn bè đã chấp nhận',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (state.refreshing)
                const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else
                IconButton(
                  key: const Key('accepted-friends-refresh'),
                  tooltip: 'Làm mới bạn bè',
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  onPressed: notifier.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
        if (chat.availability != FriendChatAvailability.ready)
          _ChatAvailabilityBanner(availability: chat.availability),
        if (state.error != null)
          _AcceptedNotice(
            key: const Key('accepted-friends-error'),
            message: state.error!,
            actionLabel: 'Thử lại',
            onAction: notifier.refresh,
          ),
        if (state.message != null)
          _AcceptedNotice(
            key: const Key('accepted-friends-message'),
            message: state.message!,
            actionLabel: 'Đóng',
            onAction: notifier.clearMessage,
          ),
        Expanded(
          child: state.items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Bạn chưa có bạn bè đã chấp nhận.',
                      key: Key('accepted-friends-empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: ListView.separated(
                    key: const Key('accepted-friends-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 112),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      final opening = state.openingPeerId == item.profile.id;
                      return FriendListItem(
                        connection: item,
                        opening: opening,
                        onOpenChat: chat.canOpen && state.openingPeerId == null
                            ? () async {
                                final openDirect = chat.openDirectChat;
                                if (openDirect == null) return;
                                final conversationId = await notifier.openChat(
                                  peerId: item.profile.id,
                                  openDirectChat: openDirect,
                                );
                                if (conversationId != null &&
                                    context.mounted &&
                                    ref.read(friendsOwnerProvider) == owner) {
                                  context.push('/chat/$conversationId');
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChatAvailabilityBanner extends StatelessWidget {
  const _ChatAvailabilityBanner({required this.availability});

  final FriendChatAvailability availability;

  @override
  Widget build(BuildContext context) {
    final needsProfile =
        availability == FriendChatAvailability.ownLanguageProfileRequired;
    return _AcceptedNotice(
      key: const Key('accepted-friends-chat-gate'),
      message: needsProfile
          ? 'Thiết lập hồ sơ ngôn ngữ để bắt đầu Chat.'
          : 'Chat đang chuẩn bị. Danh sách bạn bè vẫn dùng được.',
      actionLabel: needsProfile ? 'Mở Cài đặt' : null,
      onAction: needsProfile ? () => context.push('/settings') : null,
    );
  }
}

class _AcceptedNotice extends StatelessWidget {
  const _AcceptedNotice({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.yellow.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
