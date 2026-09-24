import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/friends_provider.dart';
import 'add_friend_sheet.dart';

/// Compatibility entry point for callers that embed the add-friend content.
/// The route-level action uses [showAddFriendSheet] for keyboard-aware sizing.
class AddFriendModal extends ConsumerWidget {
  const AddFriendModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(friendsOwnerProvider);
    if (owner == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Đăng nhập vào Staging để thêm bạn.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return AddFriendSheet(owner: owner);
  }
}
