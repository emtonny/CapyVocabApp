import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../../../auth/domain/account_phone.dart';
import '../providers/account_contact_provider.dart';
import 'settings_dialog.dart';
import 'settings_toggle.dart';

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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              key: const Key('change-email-tile'),
              onTap: state.isSaving ? null : _showChangeEmailDialog,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ContactIconBadge(
                      icon: Icons.mark_email_read_outlined,
                      color: AppColors.yellow,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EMAIL TÀI KHOẢN',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: AppColors.mutedInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            settings.email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _VerificationBadge(
                            confirmed: settings.emailConfirmed,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StickerButton(
                      semanticLabel: 'Đổi email',
                      onPressed: state.isSaving ? null : _showChangeEmailDialog,
                      icon: const Icon(Icons.edit_rounded),
                      surfaceColor: AppColors.yellow,
                      minHeight: 48,
                      radius: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _ContactVisibilityRow(
              toggleKey: const Key('show-email-to-friends-switch'),
              icon: Icons.shield_outlined,
              iconColor: AppColors.mint,
              value: settings.showEmailToFriends,
              onChanged: state.isSaving || !settings.emailConfirmed
                  ? null
                  : (value) => ref
                      .read(accountContactProvider.notifier)
                      .updateVisibility(email: value),
              title: 'Cho phép bạn bè xem email',
              subtitle: settings.emailConfirmed
                  ? 'Chỉ bạn bè đã chấp nhận mới xem được'
                  : 'Xác nhận email trước khi bật quyền này',
            ),
            if (accountSmsVerificationEnabled) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
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
              const Divider(height: 1, indent: 16, endIndent: 16),
              _ContactVisibilityRow(
                toggleKey: const Key('show-phone-to-friends-switch'),
                icon: Icons.phone_locked_outlined,
                iconColor: AppColors.mint,
                value: settings.showPhoneToFriends,
                onChanged: state.isSaving || !settings.phoneConfirmed
                    ? null
                    : (value) => ref
                        .read(accountContactProvider.notifier)
                        .updateVisibility(phone: value),
                title: 'Cho phép bạn bè xem số điện thoại',
                subtitle: 'Mặc định ẩn; tắt có hiệu lực ngay',
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
        builder: (context, setDialogState) => SettingsDialog(
          title: 'Đổi email',
          icon: Icons.alternate_email_rounded,
          accentColor: AppColors.blue,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                decoration: settingsInputDecoration(label: 'Email mới'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('current-password-for-email-field'),
                controller: passwordController,
                enabled: !busy,
                obscureText: true,
                decoration: settingsInputDecoration(label: 'Mật khẩu hiện tại'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: AppColors.coral)),
              ],
            ],
          ),
          actions: [
            SettingsDialogAction(
              label: 'Hủy',
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              surfaceColor: AppColors.softWhite,
            ),
            SettingsDialogAction(
              actionKey: const Key('submit-email-change'),
              label: busy ? 'Đang gửi...' : 'Gửi thư xác nhận',
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
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              surfaceColor: AppColors.blue,
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
        builder: (context, setDialogState) => SettingsDialog(
          title: 'Đổi số điện thoại',
          icon: Icons.phone_android_rounded,
          accentColor: AppColors.mint,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                decoration: settingsInputDecoration(
                  label: 'Số mới có mã quốc gia',
                  hint: '+84987654321',
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
                      settingsInputDecoration(label: 'Mật khẩu hiện tại'),
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
                  decoration: settingsInputDecoration(
                    label: 'Mã SMS gồm 6 số',
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
            SettingsDialogAction(
              label: 'Hủy',
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              surfaceColor: AppColors.softWhite,
            ),
            SettingsDialogAction(
              actionKey: Key(
                  codeSent ? 'verify-phone-change' : 'request-phone-change'),
              label: busy
                  ? 'Đang xử lý...'
                  : codeSent
                      ? 'Xác nhận số mới'
                      : 'Gửi mã SMS',
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
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(codeSent ? Icons.verified_rounded : Icons.sms_rounded),
              surfaceColor: AppColors.mint,
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

class _ContactIconBadge extends StatelessWidget {
  const _ContactIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 1.8),
      ),
      child: Icon(icon, color: AppColors.ink, size: 22),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: confirmed
            ? AppColors.mint.withValues(alpha: 0.42)
            : AppColors.coral.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed ? Icons.verified_rounded : Icons.error_outline_rounded,
            size: 14,
            color: AppColors.ink,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              confirmed ? 'Đã xác nhận' : 'Chưa xác nhận',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactVisibilityRow extends StatelessWidget {
  const _ContactVisibilityRow({
    required this.toggleKey,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final Key toggleKey;
  final IconData icon;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
        child: Row(
          children: [
            _ContactIconBadge(icon: icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IgnorePointer(
              child: SettingsToggle(
                key: toggleKey,
                value: value,
                onChanged: onChanged,
                semanticLabel: title,
              ),
            ),
          ],
        ),
      ),
    );
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
