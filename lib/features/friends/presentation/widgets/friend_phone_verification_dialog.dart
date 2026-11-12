import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/friend_phone_verification.dart';
import '../providers/friends_provider.dart';

Future<bool> showFriendPhoneVerificationDialog(
  BuildContext context, {
  required FriendPhoneVerificationGateway gateway,
}) async {
  final verified = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FriendPhoneVerificationDialog(gateway: gateway),
  );
  return verified == true;
}

class FriendPhoneVerificationDialog extends StatefulWidget {
  const FriendPhoneVerificationDialog({
    super.key,
    required this.gateway,
  });

  final FriendPhoneVerificationGateway gateway;

  @override
  State<FriendPhoneVerificationDialog> createState() =>
      _FriendPhoneVerificationDialogState();
}

class _FriendPhoneVerificationDialogState
    extends State<FriendPhoneVerificationDialog> {
  final _otpController = TextEditingController();
  FriendPhoneChallenge? _challenge;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await widget.gateway.requestVerification();
      if (!mounted) return;
      if (challenge == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _challenge = challenge);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (_busy || challenge == null) return;
    final token = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      setState(() => _error = 'Mã xác minh gồm đúng 6 chữ số.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gateway.verify(challenge: challenge, token: token);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return AlertDialog(
      backgroundColor: AppColors.softWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.ink, width: 2.5),
      ),
      title: const Text('Xác minh số điện thoại'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              challenge == null
                  ? 'Mã OTP sẽ được gửi đến số điện thoại đã lưu trong hồ sơ của bạn.'
                  : 'Nhập mã OTP đã gửi đến ${challenge.maskedPhone}.',
            ),
            if (challenge != null) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('friend-phone-otp-field'),
                controller: _otpController,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mã xác minh',
                  hintText: '000000',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _verify(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('friend-phone-verification-error'),
                style: const TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                key: Key('friend-phone-verification-progress'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('friend-phone-verification-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: Key(
            challenge == null
                ? 'friend-phone-request-otp'
                : 'friend-phone-submit-otp',
          ),
          onPressed: _busy
              ? null
              : challenge == null
                  ? _requestCode
                  : _verify,
          child: Text(challenge == null ? 'Gửi mã OTP' : 'Xác minh'),
        ),
      ],
    );
  }
}
