// FR-FRND-01: xếp hạng tuần + danh sách bạn bè

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../chat/domain/operational_chat.dart';
import '../../../chat/presentation/operational_chat_provider.dart';
import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../providers/friends_provider.dart';
import '../widgets/accepted_friends_list.dart';
import '../widgets/add_friend_sheet.dart';
import '../widgets/friend_requests_workspace.dart';

/// Friends management screen. Weekly ranking has its own future data milestone.
class FriendsLeaderboardScreen extends ConsumerWidget {
  const FriendsLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatOwner = ref.watch(operationalChatEnabledProvider)
        ? ref.watch(operationalChatOwnerProvider)
        : null;
    final friendOwner = ref.watch(friendsOwnerProvider);
    final legacyBody = chatOwner != null
        ? _AcceptedFriendsView(
            key: ValueKey(chatOwner.scope),
            owner: chatOwner,
          )
        : const _FriendsUnavailableView();
    return GraphPaperScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '👥',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bạn bè',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C2A21),
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton.filledTonal(
                      key: const Key('friends-open-groups'),
                      tooltip: 'Mở nhóm học',
                      onPressed: () => context.go('/groups'),
                      icon: const Icon(Icons.school_outlined),
                    ),
                  ),
                ],
              ),
            ),
            if (friendOwner != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (chatOwner != null) ...[
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton.filledTonal(
                          key: const Key('friends-open-chat'),
                          tooltip: 'Mở trang Chat',
                          onPressed: () => context.go('/chat'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const Key('open-add-friend'),
                        onPressed: () => showAddFriendSheet(
                          context,
                          owner: friendOwner,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: AppColors.ink,
                              width: 2,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text(
                          'Thêm bạn',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: friendOwner == null
                  ? legacyBody
                  : FriendRequestsWorkspace(
                      key: ValueKey('friend-requests-${friendOwner.scope}'),
                      owner: friendOwner,
                      acceptedChild: AcceptedFriendsList(owner: friendOwner),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
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
class _AcceptedFriendsView extends ConsumerWidget {
  const _AcceptedFriendsView({super.key, required this.owner});
  final ChatOwner owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(operationalChatOwnerProvider) != owner) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Expanded(
                child: Text('Bạn bè đã chấp nhận',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
            IconButton(
                key: const Key('friends-open-chat'),
                tooltip: 'Mở trang Chat',
                onPressed: () => context.go('/chat'),
                icon: const Icon(Icons.chat_bubble_outline_rounded)),
            IconButton(
                tooltip: 'Làm mới bạn bè',
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.invalidate(operationalChatFriendsProvider(owner))),
          ])),
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
                            textAlign: TextAlign.center))),
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
                                      color: AppColors.ink, width: 2)),
                              child: ListTile(
                                key: ValueKey('accepted-friend-$id'),
                                leading: const Icon(Icons.person_outline),
                                title: Text(
                                    'Bạn · ${id.substring(id.length - 8)}'),
                                subtitle: Text(id,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                trailing: const Tooltip(
                                    message: 'Đã chấp nhận',
                                    child: Icon(Icons.check_circle_outline,
                                        color: AppColors.darkGreen)),
                              ));
                        }),
              )),
    ]);
  }
}
