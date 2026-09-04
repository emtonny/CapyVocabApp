import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.canResetPassword,
  });

  final bool canResetPassword;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(passwordRecoveryProvider.notifier).clear);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _returnToLogin() async {
    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go('/auth');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final updated = await ref
        .read(passwordRecoveryProvider.notifier)
        .updatePassword(_passwordController.text);
    if (!mounted || !updated) return;

    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go('/auth?passwordReset=success');
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final recoveryState = ref.watch(passwordRecoveryProvider);
    final isLoading = recoveryState.isLoading;
    final error = recoveryState.error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_returnToLogin());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBF8EE),
        body: GestureDetector(
          key: const Key('reset-password-dismiss-keyboard-area'),
          behavior: HitTestBehavior.translucent,
          onTap: _dismissKeyboard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const GraphPaperBackground(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.ink, width: 2.8),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.ink,
                              offset: Offset(4, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: widget.canResetPassword
                            ? _buildResetForm(isLoading, error)
                            : _buildInvalidLink(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm(bool isLoading, Object? error) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset_rounded, size: 54, color: AppColors.ink),
          const SizedBox(height: 12),
          const Text(
            'Đặt mật khẩu mới',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mật khẩu mới cần có ít nhất ${Validators.minimumPasswordLength} ký tự.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('new-password-field'),
            controller: _passwordController,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              label: 'Mật khẩu mới',
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (!Validators.isValidPassword(value)) {
                return 'Mật khẩu phải có ít nhất ${Validators.minimumPasswordLength} ký tự.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('confirm-new-password-field'),
            controller: _confirmationController,
            enabled: !isLoading,
            obscureText: _obscureConfirmation,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: isLoading ? null : (_) => _submit(),
            decoration: _decoration(
              label: 'Nhập lại mật khẩu mới',
              obscure: _obscureConfirmation,
              onToggle: () => setState(
                () => _obscureConfirmation = !_obscureConfirmation,
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Mật khẩu nhập lại không khớp.';
              }
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error is AuthFailure
                  ? error.message
                  : 'Không thể đổi mật khẩu. Vui lòng thử lại.',
              key: const Key('reset-password-error'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              key: const Key('update-password-button'),
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.ink,
                      ),
                    )
                  : const Text(
                      'Đổi mật khẩu',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvalidLink() {
    return Column(
      children: [
        const Icon(Icons.link_off_rounded, size: 54, color: AppColors.ink),
        const SizedBox(height: 12),
        const Text(
          'Liên kết không còn hiệu lực',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Liên kết có thể đã hết hạn, đã được sử dụng hoặc được mở trên thiết bị khác. Hãy yêu cầu một liên kết mới.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            key: const Key('invalid-reset-back-button'),
            onPressed: _returnToLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.ink, width: 2),
              ),
            ),
            child: const Text('Quay lại đăng nhập'),
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.softWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
      ),
      suffixIcon: IconButton(
        tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }
}
