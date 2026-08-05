import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/capy_video_header.dart';
import '../widgets/social_auth_button.dart';

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

    if (_isSignUp) {
      final session = await notifier.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
      );

      if (!mounted) return;

      final authState = ref.read(authProvider);
      if (!authState.hasError) {
        if (session != null) {
          await notifier.signOut();
        }
        _passwordController.clear();
        setState(() {
          _isSignUp = false;
          _infoMessage =
              'Đăng ký tài khoản thành công! Vui lòng nhập mật khẩu để đăng nhập.';
        });
      }
      return;
    }

    final session = await notifier.signInWithPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (session != null) {
      return;
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
      backgroundColor: const Color(0xFFFAF6EE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Video Header
                  const CapyVideoHeader(),

                  const SizedBox(height: 6),

                  // Segmented Switcher (Đăng Nhập / Đăng Ký)
                  _buildTabSwitcher(isLoading),

                  const SizedBox(height: 6),

                  // Main Form Card Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF3C2A21),
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF3C2A21),
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sign Up Name Field
                            if (_isSignUp) ...[
                              _buildFieldLabel('👤 Họ tên'),
                              const SizedBox(height: 6),
                              TextFormField(
                                key: const Key('sign-up-display-name-field'),
                                controller: _displayNameController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3C2A21),
                                ),
                                decoration: _inputDecoration(
                                  labelText: 'Họ tên',
                                  hintText: 'Nguyễn Văn An',
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

                            // Email Field
                            _buildFieldLabel('📨 Email / Tên đăng nhập'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3C2A21),
                              ),
                              decoration: _inputDecoration(
                                labelText: 'Email',
                                hintText: 'user@capyvocab.com',
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

                            // Password Field
                            _buildFieldLabel('🔒 Mật khẩu'),
                            const SizedBox(height: 6),
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
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3C2A21),
                              ),
                              decoration: _inputDecoration(
                                labelText: 'Mật khẩu',
                                hintText: '••••••',
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
                                    color: const Color(0xFF786C65),
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

                            // Error or Info Messages
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

                            const SizedBox(height: 20),

                            // Rocket Submit Button
                            _buildSubmitButton(isLoading),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider "HOẶC TIẾP TỤC BẰNG"
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(
                          color: Color(0xFFE2D6C5),
                          thickness: 1.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'HOẶC TIẾP TỤC BẰNG',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9E8F85),
                            letterSpacing: 0.8,
                            fontFamily: 'Fredoka',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Color(0xFFE2D6C5),
                          thickness: 1.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Social Auth Demo Buttons
                  SocialAuthButton(
                    provider: SocialProvider.google,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đăng nhập Google (Demo)'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SocialAuthButton(
                    provider: SocialProvider.facebook,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đăng nhập Facebook (Demo)'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF3C2A21),
        fontFamily: 'Fredoka',
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFAFA49C),
        fontWeight: FontWeight.normal,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF3C2A21),
          width: 2.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF58CC02),
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildTabSwitcher(bool isLoading) {
    return Container(
      width: double.infinity,
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3C2A21),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3C2A21),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              title: 'Đăng nhập',
              isSelected: !_isSignUp,
              onTap: isLoading ? null : () => _changeMode(false),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              title: 'Đăng ký',
              isSelected: _isSignUp,
              onTap: isLoading ? null : () => _changeMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF58CC02) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF3C2A21),
                  width: 2.0,
                )
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Fredoka',
            color: isSelected ? Colors.white : const Color(0xFF3C2A21),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF3C2A21),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF58CC02),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(
              color: Color(0xFF3C2A21),
              width: 2.5,
            ),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚀 ', style: TextStyle(fontSize: 16)),
                  Text(
                    _isSignUp ? 'Đăng ký' : 'Đăng nhập',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Fredoka',
                    ),
                  ),
                ],
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
