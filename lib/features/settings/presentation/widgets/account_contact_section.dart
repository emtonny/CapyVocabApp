import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/account_phone.dart';
import '../providers/account_contact_provider.dart';

class AccountContactSection extends ConsumerStatefulWidget {
  const AccountContactSection({super.key});

  @override
  ConsumerState<AccountContactSection> createState() =>
      _AccountContactSectionState();
}

class _AccountContactSectionState extends ConsumerState<AccountContactSection> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() => ref.read(accountContactProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountContactProvider);
    final settings = state.settings;

    if (state.isLoading && settings == null) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (settings == null) {
      return _ContactError(
        message: state.error ?? 'Không thể tải thông tin liên hệ.',
        onRetry: ref.read(accountContactProvider.notifier).load,
      );
    }

    return Container(
      key: const Key('account-contact-section'),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink, width: 2.8),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            key: const Key('change-email-tile'),
            leading: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Email'),
            subtitle: Text(
              '${settings.email}\n${settings.emailConfirmed ? 'Đã xác nhận' : 'Chưa xác nhận'}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.edit_outlined),
            onTap: state.isSaving ? null : _showChangeEmailDialog,
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile.adaptive(
            key: const Key('show-email-to-friends-switch'),
            value: settings.showEmailToFriends,
            onChanged: state.isSaving || !settings.emailConfirmed
                ? null
                : (value) => ref
                    .read(accountContactProvider.notifier)
                    .updateVisibility(email: value),
            title: const Text('Cho phép bạn bè xem email'),
            subtitle: const Text('Chỉ bạn bè đã chấp nhận mới xem được'),
          ),
          if (accountSmsVerificationEnabled) ...[
            const Divider(height: 1, indent: 56),
            ListTile(
              key: const Key('change-phone-tile'),
              leading: const Icon(Icons.phone_iphone_rounded),
              title: const Text('Số điện thoại'),
              subtitle: Text(
                settings.phone == null
                    ? 'Chưa thiết lập'
                    : '${maskAccountPhone(settings.phone!)}\n${settings.phoneConfirmed ? 'Đã xác nhận' : 'Chưa xác nhận'}',
              ),
              isThreeLine: settings.phone != null,
              trailing: const Icon(Icons.edit_outlined),
              onTap: state.isSaving ? null : _showChangePhoneDialog,
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile.adaptive(
              key: const Key('show-phone-to-friends-switch'),
              value: settings.showPhoneToFriends,
              onChanged: state.isSaving || !settings.phoneConfirmed
                  ? null
                  : (value) => ref
                      .read(accountContactProvider.notifier)
                      .updateVisibility(phone: value),
              title: const Text('Cho phép bạn bè xem số điện thoại'),
              subtitle: const Text('Mặc định ẩn; tắt có hiệu lực ngay'),
            ),
          ],
          if (state.error case final error?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                error,
                key: const Key('account-contact-error'),
                style: const TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? error;
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: !busy,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đổi email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Email cũ vẫn hoạt động cho tới khi bạn xác nhận email mới.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('new-email-field'),
                controller: emailController,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email mới'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('current-password-for-email-field'),
                controller: passwordController,
                enabled: !busy,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Mật khẩu hiện tại'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.coral)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('submit-email-change'),
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final sent = await ref
                          .read(accountContactProvider.notifier)
                          .requestEmailChange(
                            email: emailController.text,
                            currentPassword: passwordController.text,
                          );
                      if (!dialogContext.mounted) return;
                      if (sent) {
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã gửi thư xác nhận tới email mới.',
                            ),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          busy = false;
                          error = ref.read(accountContactProvider).error;
                        });
                      }
                    },
              child: Text(busy ? 'Đang gửi...' : 'Gửi thư xác nhận'),
            ),
          ],
        ),
      ),
    );
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _showChangePhoneDialog() async {
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    String? error;
    var busy = false;
    var codeSent = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đổi số điện thoại'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('new-phone-field'),
                controller: phoneController,
                enabled: !busy && !codeSent,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s().-]')),
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số mới có mã quốc gia',
                  hintText: '+84987654321',
                ),
              ),
              if (!codeSent) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('current-password-for-phone-field'),
                  controller: passwordController,
                  enabled: !busy,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Mật khẩu hiện tại'),
                ),
              ],
              if (codeSent) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('phone-change-code-field'),
                  controller: codeController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Mã SMS gồm 6 số',
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.coral)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: Key(
                  codeSent ? 'verify-phone-change' : 'request-phone-change'),
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      final notifier =
                          ref.read(accountContactProvider.notifier);
                      final success = codeSent
                          ? await notifier
                              .verifyPhoneChange(codeController.text)
                          : await notifier.requestPhoneChange(
                              phone: phoneController.text,
                              currentPassword: passwordController.text,
                            );
                      if (!dialogContext.mounted) return;
                      if (!success) {
                        setDialogState(() {
                          busy = false;
                          error = ref.read(accountContactProvider).error;
                        });
                        return;
                      }
                      if (!codeSent) {
                        setDialogState(() {
                          busy = false;
                          codeSent = true;
                        });
                        return;
                      }
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã đổi và xác nhận số điện thoại.'),
                        ),
                      );
                    },
              child: Text(
                busy
                    ? 'Đang xử lý...'
                    : codeSent
                        ? 'Xác nhận số mới'
                        : 'Gửi mã SMS',
              ),
            ),
          ],
        ),
      ),
    );
    phoneController.dispose();
    passwordController.dispose();
    codeController.dispose();
  }
}

class _ContactError extends StatelessWidget {
  const _ContactError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          SizedBox(
            height: 48,
            child: TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ),
        ],
      ),
    );
  }
}
