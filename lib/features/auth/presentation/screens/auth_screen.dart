import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _infoMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _changeMode(bool isSignUp) {
    if (_isSignUp == isSignUp) return;

    setState(() {
      _isSignUp = isSignUp;
      _infoMessage = null;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _infoMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(authProvider.notifier);
    final session = _isSignUp
        ? await notifier.signUp(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _displayNameController.text,
          )
        : await notifier.signInWithPassword(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (!mounted) return;

    if (session != null) {
      context.go('/home');
      return;
    }

    final authState = ref.read(authProvider);
    if (_isSignUp && !authState.hasError) {
      setState(() {
        _infoMessage =
            'Đăng ký thành công. Vui lòng xác nhận email trước khi đăng nhập.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.maybeWhen(
      error: (error, _) => error is AuthFailure
          ? error.message
          : 'Đã xảy ra lỗi xác thực. Vui lòng thử lại.',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: AppColors.creamyYuzu,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.auto_stories_rounded,
                            size: 56,
                            color: AppColors.duoGreen,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Capy Vocab',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSignUp
                                ? 'Tạo tài khoản để bắt đầu học'
                                : 'Chào mừng bạn quay trở lại',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Đăng nhập'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Đăng ký'),
                              ),
                            ],
                            selected: {_isSignUp},
                            onSelectionChanged: isLoading
                                ? null
                                : (selection) => _changeMode(selection.first),
                          ),
                          const SizedBox(height: 24),
                          if (_isSignUp) ...[
                            TextFormField(
                              key: const Key('sign-up-display-name-field'),
                              controller: _displayNameController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Họ tên',
                                hintText: 'Nguyễn Văn An',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (!Validators.isNotEmpty(value)) {
                                  return 'Vui lòng nhập họ tên.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'ban@example.com',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!Validators.isNotEmpty(value)) {
                                return 'Vui lòng nhập email.';
                              }
                              if (!Validators.isEmail(value!.trim())) {
                                return 'Email không đúng định dạng.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !isLoading,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: [
                              _isSignUp
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: isLoading
                                    ? null
                                    : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (!Validators.isNotEmpty(value)) {
                                return 'Vui lòng nhập mật khẩu.';
                              }
                              if (value!.length < 6) {
                                return 'Mật khẩu phải có ít nhất 6 ký tự.';
                              }
                              return null;
                            },
                            onFieldSubmitted:
                                isLoading ? null : (_) => _submit(),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageBox(
                              message: errorMessage,
                              isError: true,
                            ),
                          ],
                          if (_infoMessage != null) ...[
                            const SizedBox(height: 16),
                            _MessageBox(message: _infoMessage!),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: AppColors.duoGreen,
                            ),
                            child: isLoading
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(_isSignUp ? 'Đăng ký' : 'Đăng nhập'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    this.isError = false,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? Theme.of(context).colorScheme.error : AppColors.duoBlue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
