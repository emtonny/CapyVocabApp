// FR-FRND-01: Bảng xếp hạng bạn bè + danh sách bạn bè

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../../../shared/widgets/app_user_avatar.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../../../chat/domain/operational_chat.dart';
import '../../../chat/presentation/operational_chat_provider.dart';
import '../../domain/entities/friend_entity.dart';
import '../providers/accepted_friends_provider.dart';
import '../providers/friends_provider.dart';
import '../widgets/add_friend_sheet.dart';

/// Friends & Leaderboard screen matching the Neo-brutalist EdTech presentation.
class FriendsLeaderboardScreen extends ConsumerWidget {
  const FriendsLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatOwner = ref.watch(operationalChatEnabledProvider)
        ? ref.watch(operationalChatOwnerProvider)
        : null;
    final friendOwner = ref.watch(friendsOwnerProvider);

    if (friendOwner == null) {
      return GraphPaperScaffold(
        body: SafeArea(
          child: chatOwner != null
              ? _AcceptedFriendsLegacyView(owner: chatOwner)
              : const _FriendsUnavailableView(),
        ),
        bottomNavigationBar: const BottomNavBar(),
      );
    }

    final acceptedState = ref.watch(acceptedFriendsProvider(friendOwner));
    final chatAccess = ref.watch(friendChatAccessProvider(friendOwner));
    final friendsNotifier =
        ref.read(acceptedFriendsProvider(friendOwner).notifier);

    // Only real friends befriended on DB
    final realFriends = acceptedState.items;
    final totalDisplayCount = realFriends.length;

    return GraphPaperScaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: friendsNotifier.refresh,
          child: SingleChildScrollView(
            key: const Key('accepted-friends-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // 1. Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bạn Bè & Xếp Hạng 👥',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3C2A21),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const Key('friends-open-groups'),
                        tooltip: 'Mở nhóm học',
                        onPressed: () => context.go('/groups'),
                        icon: const Icon(Icons.school_outlined),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Ranking Section: left blank / empty state because coins are not integrated yet
                _buildEmptyLeaderboardCard(),

                const SizedBox(height: 20),

                // 3. Section Header: "Danh sách Bạn Bè (X)" + "+ Thêm bạn"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Danh sách Bạn Bè ($totalDisplayCount)',
                          key: const Key('friend-list-heading'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3C2A21),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StickerButton(
                        key: const Key('open-add-friend'),
                        onPressed: () => showAddFriendSheet(
                          context,
                          owner: friendOwner,
                        ),
                        label: 'Thêm bạn',
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        surfaceColor: AppColors.yellow,
                        edgeColor: AppColors.duoOrange,
                        fontSize: 13,
                        minHeight: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 4. Friend items list (only real friends from DB)
                if (realFriends.isEmpty)
                  _buildEmptyFriendsList()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: realFriends.length,
                    itemBuilder: (context, index) {
                      final conn = realFriends[index];
                      final isOpening =
                          acceptedState.openingPeerId == conn.profile.id;

                      return _buildFriendCard(
                        context: context,
                        ref: ref,
                        owner: friendOwner,
                        connection: conn,
                        isOpening: isOpening,
                        onOpenChat: (chatAccess.canOpen &&
                                acceptedState.openingPeerId == null)
                            ? () async {
                                final openDirect = chatAccess.openDirectChat;
                                if (openDirect == null) return;
                                final conversationId =
                                    await friendsNotifier.openChat(
                                  peerId: conn.profile.id,
                                  openDirectChat: openDirect,
                                );
                                if (conversationId != null &&
                                    context.mounted &&
                                    ref.read(friendsOwnerProvider) ==
                                        friendOwner) {
                                  final owner = ref.read(
                                    operationalChatOwnerProvider,
                                  );
                                  if (owner != null) {
                                    ref
                                        .read(
                                          operationalChatMailboxControllerProvider
                                              .notifier,
                                        )
                                        .open(
                                          owner: owner,
                                          conversationId: conversationId,
                                          peerId: conn.profile.id,
                                        );
                                  }
                                }
                              }
                            : null,
                      );
                    },
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  /// Builds an empty leaderboard card when coins are not integrated yet.
  Widget _buildEmptyLeaderboardCard() {
    return Container(
      key: const Key('friends-leaderboard-podium'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3C2A21), width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3C2A21),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3C2A21), width: 2),
              ),
              child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bảng xếp hạng đang để trống',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3C2A21),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chưa có dữ liệu xếp hạng vì tính năng xu chưa được tích hợp.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF786F66),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an empty state container when user has no accepted friends yet.
  Widget _buildEmptyFriendsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3C2A21), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3C2A21),
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👥', style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(
              'Chưa có bạn bè nào',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3C2A21),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Nhấn "+ Thêm bạn" để tìm kiếm và kết bạn nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF786F66),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a card for a real accepted friend.
  Widget _buildFriendCard({
    required BuildContext context,
    required WidgetRef ref,
    required FriendOwner owner,
    required FriendConnection connection,
    required bool isOpening,
    required VoidCallback? onOpenChat,
  }) {
    final profile = connection.profile;
    final displayName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : '@${profile.username}';

    return Semantics(
      key: ValueKey('accepted-friend-${profile.id}'),
      container: true,
      label:
          '$displayName, username ${profile.username}, ${profile.studyPoints} điểm, streak ${profile.streakDays} ngày, cấp ${profile.userLevel}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          final identity = Row(
            children: [
              AppUserAvatar(
                avatarUrl: profile.avatarUrl,
                size: 44,
                backgroundColor: const Color(0xFFFFF9E6),
                borderColor: const Color(0xFF3C2A21),
                borderWidth: 1.5,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3C2A21),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🔥 ${profile.streakDays} ngày streak · ⭐ ${profile.studyPoints} điểm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF786F66),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button 1: Chat
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF3C2A21),
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: OutlinedButton.icon(
                  key: ValueKey('accepted-friend-chat-${profile.id}'),
                  onPressed: isOpening ? null : onOpenChat,
                  icon: isOpening
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3C2A21),
                    side: const BorderSide(
                      color: Color(0xFF3C2A21),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Button 2: Solo
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF3C2A21),
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  key: ValueKey('accepted-friend-solo-${profile.id}'),
                  onPressed: () => context.push('/solo-arena'),
                  icon: const Text('⚔️', style: TextStyle(fontSize: 16)),
                  label: const Text('Solo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: AppColors.duoOrange,
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFF3C2A21),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3C2A21), width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF3C2A21),
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actions,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 8),
                      actions,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _FriendsUnavailableView extends StatelessWidget {
  const _FriendsUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFE6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE2D6C5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('👥', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bạn bè chưa sẵn sàng',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C2A21),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tính năng Bạn bè chưa được bật cho môi trường này.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9E8F85),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explicit Friends navigation only; default/Production UI stays unchanged.
class _AcceptedFriendsLegacyView extends ConsumerWidget {
  const _AcceptedFriendsLegacyView({required this.owner});
  final ChatOwner owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(operationalChatOwnerProvider) != owner) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn bè',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bạn bè đã chấp nhận',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 14,
                        color: Color(0xFF786F66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StickerButton(
                semanticLabel: 'Làm mới bạn bè',
                icon: const Icon(Icons.refresh_rounded),
                minHeight: 48,
                onPressed: () =>
                    ref.invalidate(operationalChatFriendsProvider(owner)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ref.watch(operationalChatFriendsProvider(owner)).when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, stack) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Chưa tải được bạn bè. Cần mạng; bấm làm mới để thử lại.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (ids) => ids.isEmpty
                    ? const Center(child: Text('Chưa có bạn bè đã chấp nhận.'))
                    : ListView.builder(
                        key: const Key('accepted-friends-list'),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
                        itemCount: ids.length,
                        itemBuilder: (context, index) {
                          final id = ids[index];
                          return Card(
                            color: AppColors.softWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppColors.ink,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              key: ValueKey('accepted-friend-$id'),
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                'Bạn · ${id.substring(id.length - 8)}',
                              ),
                              subtitle: Text(
                                id,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Tooltip(
                                message: 'Đã chấp nhận',
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
        ),
      ],
    );
  }
}
