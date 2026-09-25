import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/account_phone.dart';
import '../../domain/entities/friend_entity.dart';
import '../../domain/friend_shared_contact.dart';
import '../providers/friend_contact_provider.dart';

Future<void> showFriendContactDialog(
  BuildContext context, {
  required FriendOwner owner,
  required FriendPublicProfile profile,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FriendContactDialog(owner: owner, profile: profile),
  );
}

class _FriendContactDialog extends ConsumerWidget {
  const _FriendContactDialog({required this.owner, required this.profile});

  final FriendOwner owner;
  final FriendPublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = FriendSharedContactRequest(
      owner: owner,
      friendId: profile.id,
    );
    final contact = ref.watch(friendContactProvider(request));
    return AlertDialog(
      title: Text(
        profile.displayName.trim().isEmpty
            ? '@${profile.username}'
            : profile.displayName,
      ),
      content: contact.when(
        loading: () => const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Không thể tải liên hệ. Quan hệ bạn bè có thể đã thay đổi.',
              key: Key('friend-contact-error'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => ref.invalidate(friendContactProvider(request)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ),
          ],
        ),
        data: (value) => _ContactContent(contact: value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _ContactContent extends StatelessWidget {
  const _ContactContent({required this.contact});

  final FriendSharedContact contact;

  @override
  Widget build(BuildContext context) {
    if (contact.email == null &&
        (!accountSmsVerificationEnabled || contact.phone == null)) {
      return const Text(
        accountSmsVerificationEnabled
            ? 'Người bạn này đang ẩn email và số điện thoại.'
            : 'Người bạn này đang ẩn email.',
        key: Key('friend-contact-hidden'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (contact.email case final email?)
          ListTile(
            key: const Key('friend-contact-email'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined, color: AppColors.blue),
            title: const Text('Email'),
            subtitle: SelectableText(email),
          ),
        if (accountSmsVerificationEnabled && contact.phone != null)
          ListTile(
            key: const Key('friend-contact-phone'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined, color: AppColors.mint),
            title: const Text('Số điện thoại'),
            subtitle: SelectableText(contact.phone!),
          ),
      ],
    );
  }
}
