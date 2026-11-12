import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_user_avatar.dart';
import '../../domain/entities/friend_entity.dart';

/// Public-profile-only accepted friend card with the supported Chat action.
class FriendListItem extends StatelessWidget {
  const FriendListItem({
    super.key,
    required this.rank,
    required this.connection,
    required this.opening,
    required this.onOpenChat,
    this.onViewContact,
  });

  final int rank;
  final FriendConnection connection;
  final bool opening;
  final VoidCallback? onOpenChat;
  final VoidCallback? onViewContact;

  @override
  Widget build(BuildContext context) {
    final profile = connection.profile;
    final displayName = profile.displayName.trim().isEmpty
        ? '@${profile.username}'
        : profile.displayName;
    final avatar = profile.avatarUrl?.trim();

    return Semantics(
      key: ValueKey('accepted-friend-${profile.id}'),
      container: true,
      label:
          '$displayName, hạng $rank, username ${profile.username}, ${profile.studyPoints} điểm học, streak ${profile.streakDays} ngày, cấp ${profile.userLevel}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final identity = Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '#$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: rank == 1 ? AppColors.duoOrange : AppColors.mutedInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AppUserAvatar(
                avatarUrl: avatar,
                size: 44,
                backgroundColor:
                    rank == 1 ? AppColors.paleGold : const Color(0xFFFFF5DA),
                borderWidth: 0,
              ),
              const SizedBox(width: 8),
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
                        fontSize: 15,
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '🔥 ${profile.streakDays} ngày · ⭐ ${profile.studyPoints} điểm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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
              _FriendCardAction(
                actionKey: ValueKey('accepted-friend-chat-${profile.id}'),
                label: 'Chat',
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                ),
                loading: opening,
                onPressed: opening ? null : onOpenChat,
              ),
              const SizedBox(width: 6),
              _FriendCardAction(
                actionKey: ValueKey('accepted-friend-solo-${profile.id}'),
                label: 'Solo',
                icon: const Text('⚔️', style: TextStyle(fontSize: 16)),
                onPressed: () => context.push('/solo-arena'),
                fillColor: const Color(0xFFFF9600),
              ),
            ],
          );

          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF3C2A21), width: 2.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF3C2A21),
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 4),
                      actions,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _FriendCardAction extends StatelessWidget {
  const _FriendCardAction({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.fillColor,
  });

  final Key actionKey;
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: switch (label) {
        'Xem' => 'Xem thông tin bạn bè',
        'Solo' => 'Thi đấu cùng bạn bè',
        _ => 'Mở Chat',
      },
      child: Container(
        width: 62,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF3C2A21),
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: fillColor == null
            ? OutlinedButton.icon(
                key: actionKey,
                onPressed: onPressed,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : icon,
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3C2A21),
                  side: const BorderSide(
                    color: Color(0xFF3C2A21),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              )
            : FilledButton.icon(
                key: actionKey,
                onPressed: onPressed,
                icon: icon,
                label: Text(label),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  backgroundColor: fillColor,
                  foregroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color(0xFF3C2A21),
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
      ),
    );
  }
}
