import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../providers/auth_provider.dart';
import '../widgets/capy_video_header.dart';
import '../widgets/social_auth_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _wideLayoutMinWidth = 760.0;

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
      backgroundColor: const Color(0xFFFBF8EE),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GraphPaperBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideLayoutMinWidth;

              return SafeArea(
                child: isWide
                    ? _buildWideScreenLayout(context, isLoading, errorMessage)
                    : _buildMobileScreenLayout(
                        context, isLoading, errorMessage),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScreenLayout(
    BuildContext context,
    bool isLoading,
    String? errorMessage,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CapyVideoHeader(),
              const SizedBox(height: 14),
              _buildTabSwitcher(isLoading),
              const SizedBox(height: 14),
              _buildFormCard(isLoading, errorMessage),
              const SizedBox(height: 22),
              _buildSocialSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideScreenLayout(
    BuildContext context,
    bool isLoading,
    String? errorMessage,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Prominent Banner Header for Web/PC & Tablet
              Container(
                key: const Key('auth-wide-header-box'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.ink,
                    width: 2.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Deery Vocab',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoCondensed(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: -0.6,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Học tiếng cùng Deery, đi khắp thế giới',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedInk,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ],
                ),
              ),

              // Dual-Pane Layout: Full Video Card + Right Form
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 315,
                    child: CapyVideoHeader(
                      showText: false,
                      videoHeight: 520,
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Pane - Auth Form & Social Logins
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabSwitcher(isLoading),
                        const SizedBox(height: 14),
                        _buildFormCard(isLoading, errorMessage),
                        const SizedBox(height: 22),
                        _buildSocialSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(bool isLoading, String? errorMessage) {
    return Container(
      key: const Key('auth-form-box'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.ink,
          width: 2.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(4, 4),
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
              if (_isSignUp) ...[
                _buildFieldLabel(
                  label: 'Họ tên',
                  icon: Icons.person_outline_rounded,
                  badgeColor: const Color(0xFFDDD6FE),
                ),
                const SizedBox(height: 8),
                _buildInputBox(
                  boxKey: const Key('display-name-input-box'),
                  child: TextFormField(
                    key: const Key('sign-up-display-name-field'),
                    controller: _displayNameController,
                    enabled: !isLoading,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFamily: 'Nunito',
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
                ),
                const SizedBox(height: 16),
              ],
              _buildFieldLabel(
                label: 'Email / Tên đăng nhập',
                icon: Icons.email_outlined,
                badgeColor: const Color(0xFF7DD3FC),
              ),
              const SizedBox(height: 8),
              _buildInputBox(
                boxKey: const Key('email-input-box'),
                child: TextFormField(
                  key: const Key('email-field'),
                  controller: _emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFamily: 'Nunito',
                  ),
                  decoration: _inputDecoration(
                    labelText: 'Email',
                    hintText: 'Email',
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
              ),
              const SizedBox(height: 16),
              _buildFieldLabel(
                label: 'Mật khẩu',
                icon: Icons.lock_rounded,
                badgeColor: AppColors.yellow,
              ),
              const SizedBox(height: 8),
              _buildInputBox(
                boxKey: const Key('password-input-box'),
                child: TextFormField(
                  key: const Key('password-field'),
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  obscuringCharacter: '•',
                  textInputAction: TextInputAction.done,
                  autofillHints: [
                    _isSignUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFamily: _obscurePassword ? null : 'Nunito',
                    letterSpacing: _obscurePassword ? 1.5 : 0.0,
                  ),
                  decoration: _inputDecoration(
                    labelText: 'Mật khẩu',
                    hintText: 'Mật khẩu',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        tooltip:
                            _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: isLoading
                            ? null
                            : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                        icon: Container(
                          width: 34,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.softWhite,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.ink,
                              width: 1.8,
                            ),
                          ),
                          child: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.ink,
                          ),
                        ),
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
                  onFieldSubmitted: isLoading ? null : (_) => _submit(),
                ),
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
              const SizedBox(height: 20),
              _buildSubmitButton(isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Divider(
                color: AppColors.ink,
                thickness: 2.0,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'HOẶC TIẾP TỤC BẰNG',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 0.8,
                  fontFamily: 'Fredoka',
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.ink,
                thickness: 2.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
    );
  }

  Widget _buildFieldLabel({
    required String label,
    required IconData icon,
    required Color badgeColor,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.ink,
              width: 1.8,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                fontFamily: 'Fredoka',
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Color(0xFF666666),
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w700,
      ),
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF888888),
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: AppColors.softWhite,
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: 2.4,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: 2.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildInputBox({required Key boxKey, required Widget child}) {
    return Container(
      key: boxKey,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTabSwitcher(bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: _buildTabItem(
            title: 'Đăng nhập',
            isSelected: !_isSignUp,
            onTap: isLoading ? null : () => _changeMode(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTabItem(
            title: 'Đăng ký',
            isSelected: _isSignUp,
            onTap: isLoading ? null : () => _changeMode(true),
          ),
        ),
      ],
    );
  }

  Widget _buildTabItem({
    required String title,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return Container(
      key: Key(isSelected ? 'selected-auth-tab-box' : 'idle-auth-tab-box'),
      height: 50,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.lime : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.ink,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Fredoka',
                color: AppColors.ink,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return Container(
      key: const Key('auth-submit-shadow-box'),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(
              color: AppColors.ink,
              width: 2.4,
            ),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.ink,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚀 ', style: TextStyle(fontSize: 16)),
                  Text(
                    _isSignUp ? 'Đăng ký' : 'Đăng nhập',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      fontFamily: 'Fredoka',
                      letterSpacing: 0.3,
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
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
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
