import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/friend_entity.dart';

/// Public-profile-only accepted friend card with the supported Chat action.
class FriendListItem extends StatelessWidget {
  const FriendListItem({
    super.key,
    required this.connection,
    required this.opening,
    required this.onOpenChat,
    required this.onViewContact,
  });

  final FriendConnection connection;
  final bool opening;
  final VoidCallback? onOpenChat;
  final VoidCallback onViewContact;

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
          '$displayName, username ${profile.username}, ${profile.studyPoints} điểm, streak ${profile.streakDays} ngày, cấp ${profile.userLevel}',
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
                        '⭐ ${profile.studyPoints} điểm · 🔥 ${profile.streakDays} ngày · Cấp ${profile.userLevel}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: ValueKey('accepted-friend-contact-${profile.id}'),
                      onPressed: onViewContact,
                      icon: const Icon(Icons.contact_phone_outlined),
                      label: const Text(
                        'Liên hệ',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      key: ValueKey('accepted-friend-chat-${profile.id}'),
                      onPressed: opening ? null : onOpenChat,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: opening
                          ? const SizedBox.square(
                              dimension: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(
                        opening ? 'Đang mở…' : 'Nhắn tin',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
