import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/friend_entity.dart';
import '../providers/friend_requests_provider.dart';
import '../providers/friends_provider.dart';

class FriendRequestsWorkspace extends ConsumerWidget {
  const FriendRequestsWorkspace({
    super.key,
    required this.owner,
    required this.acceptedChild,
  });

  final FriendOwner owner;
  final Widget acceptedChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(friendsOwnerProvider) != owner) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(friendRequestsProvider(owner));
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.softWhite,
            child: TabBar(
              key: const Key('friend-requests-tabs'),
              labelColor: AppColors.ink,
              unselectedLabelColor: AppColors.mutedInk,
              indicatorColor: AppColors.blue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
              tabs: [
                Tab(
                  key: const Key('friend-incoming-tab'),
                  height: 48,
                  child: Semantics(
                    label: 'Lời mời, ${state.incomingCount} lời mời đang chờ',
                    excludeSemantics: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Lời mời',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.incomingCount > 0) ...[
                          const SizedBox(width: 4),
                          Badge.count(
                            key: const Key('friend-incoming-badge'),
                            count: state.incomingCount,
                            backgroundColor: AppColors.coral,
                            textColor: AppColors.ink,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Tab(
                  key: Key('friend-outgoing-tab'),
                  height: 48,
                  text: 'Đã gửi',
                ),
                const Tab(
                  key: Key('friend-accepted-tab'),
                  height: 48,
                  text: 'Bạn bè',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestPane(
                  owner: owner,
                  kind: FriendListKind.incoming,
                  state: state,
                ),
                _RequestPane(
                  owner: owner,
                  kind: FriendListKind.outgoing,
                  state: state,
                ),
                acceptedChild,
              ],
            ),
          ),
          if (state.message != null)
            Semantics(
              liveRegion: true,
              child: Material(
                color: AppColors.yellow,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.message!,
                            key: const Key('friend-request-message'),
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('friend-request-message-close'),
                          tooltip: 'Đóng thông báo',
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          onPressed: ref
                              .read(friendRequestsProvider(owner).notifier)
                              .clearMessage,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestPane extends ConsumerWidget {
  const _RequestPane({
    required this.owner,
    required this.kind,
    required this.state,
  });

  final FriendOwner owner;
  final FriendListKind kind;
  final FriendRequestsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = kind == FriendListKind.incoming;
    final loaded =
        incoming ? state.incomingCacheLoaded : state.outgoingCacheLoaded;
    final items = incoming ? state.incoming : state.outgoing;
    final error = incoming ? state.incomingError : state.outgoingError;
    final refreshing = state.refreshing.contains(kind);
    final notifier = ref.read(friendRequestsProvider(owner).notifier);

    if (!state.ready || !loaded) {
      return const Center(
        child: _PaneStatus(
          key: Key('friend-requests-loading'),
          icon: Icons.hourglass_top_rounded,
          text: 'Đang đọc lời mời đã lưu…',
          progress: true,
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
              Expanded(
                child: Text(
                  incoming ? 'Lời mời đang chờ' : 'Lời mời bạn đã gửi',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (refreshing)
                const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else
                IconButton(
                  key: Key('friend-refresh-${kind.name}'),
                  tooltip: 'Làm mới',
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  onPressed: () => notifier.refresh(kind),
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
        if (error != null)
          _ErrorBanner(
            message: error,
            onRetry: () => notifier.refresh(kind),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: _PaneStatus(
                    key: Key('friend-${kind.name}-empty'),
                    icon: incoming
                        ? Icons.mark_email_read_outlined
                        : Icons.outbox_outlined,
                    text: incoming
                        ? 'Bạn chưa có lời mời đang chờ.'
                        : 'Bạn chưa gửi lời mời nào.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => notifier.refresh(kind),
                  child: ListView.separated(
                    key: Key('friend-${kind.name}-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 112),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _RequestCard(
                      connection: items[index],
                      decision: state.responding[items[index].profile.id],
                      onRespond: (decision) => notifier.respond(
                        items[index].profile.id,
                        decision,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.connection,
    required this.decision,
    required this.onRespond,
  });

  final FriendConnection connection;
  final FriendDecision? decision;
  final ValueChanged<FriendDecision> onRespond;

  @override
  Widget build(BuildContext context) {
    final profile = connection.profile;
    final incoming =
        connection.state == FriendRelationshipState.incomingPending;
    final displayName = profile.displayName.trim().isEmpty
        ? '@${profile.username}'
        : profile.displayName;
    final avatar = profile.avatarUrl?.trim();
    return Semantics(
      key: ValueKey('friend-request-${profile.id}'),
      container: true,
      label:
          '$displayName, username ${profile.username}, streak ${profile.streakDays} ngày, cấp ${profile.userLevel}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink, width: 2),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.mint,
                  foregroundImage: avatar == null || avatar.isEmpty
                      ? null
                      : NetworkImage(avatar),
                  child: const Icon(Icons.person_rounded, color: AppColors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '🔥 ${profile.streakDays} ngày · Cấp ${profile.userLevel}',
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (incoming)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: ValueKey('friend-accept-${profile.id}'),
                        onPressed: decision == null
                            ? () => onRespond(FriendDecision.accept)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                        ),
                        child: decision == FriendDecision.accept
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text(
                                'Chấp nhận',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: ValueKey('friend-reject-${profile.id}'),
                        onPressed: decision == null
                            ? () => onRespond(FriendDecision.reject)
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(
                            color: AppColors.ink,
                            width: 2,
                          ),
                        ),
                        child: decision == FriendDecision.reject
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const Text(
                                'Từ chối',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.schedule_send_rounded),
                  label: const Text(
                    'Đã gửi · đang chờ phản hồi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('friend-requests-error'),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.yellow.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.ink),
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
            TextButton(
              key: const Key('friend-requests-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneStatus extends StatelessWidget {
  const _PaneStatus({
    super.key,
    required this.icon,
    required this.text,
    this.progress = false,
  });

  final IconData icon;
  final String text;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress)
              const SizedBox.square(
                dimension: 30,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(icon, size: 42, color: AppColors.mutedInk),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
