import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../widgets/capy_video_header.dart';
import '../widgets/social_auth_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMessage});

  final String? initialMessage;

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
  bool _rememberAccount = false;
  String? _topMessage;
  bool _topMessageIsError = false;
  Timer? _topMessageTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRememberedEmail());
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showTopNotification(widget.initialMessage!);
      });
    }
  }

  void _showTopNotification(String message, {bool isError = false}) {
    _topMessageTimer?.cancel();
    setState(() {
      _topMessage = message;
      _topMessageIsError = isError;
    });

    _topMessageTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _topMessage = null;
      });
    });
  }

  void _dismissTopNotification() {
    _topMessageTimer?.cancel();
    if (mounted && _topMessage != null) {
      setState(() {
        _topMessage = null;
      });
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _loadRememberedEmail() async {
    try {
      final email = await LocalStorageService.getRememberedEmail();
      if (!mounted || email == null || email.isEmpty) return;

      if (_emailController.text.isEmpty) {
        _emailController.text = email;
      }
      setState(() => _rememberAccount = true);
    } catch (error) {
      debugPrint('Không thể tải tài khoản đã ghi nhớ: $error');
    }
  }

  void _setRememberAccount(bool? value) {
    final shouldRemember = value ?? false;
    setState(() => _rememberAccount = shouldRemember);

    if (!shouldRemember) {
      unawaited(_saveRememberedEmail(null));
    }
  }

  Future<void> _saveRememberedEmail(String? email) async {
    try {
      await LocalStorageService.setRememberedEmail(email);
    } catch (error) {
      debugPrint('Không thể lưu tài khoản ghi nhớ: $error');
    }
  }

  @override
  void dispose() {
    _topMessageTimer?.cancel();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _changeMode(bool isSignUp) {
    if (_isSignUp == isSignUp) return;

    _dismissTopNotification();
    setState(() {
      _isSignUp = isSignUp;
      _obscurePassword = true;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    _dismissTopNotification();

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

        final registeredEmail = _emailController.text.trim();
        await _saveRememberedEmail(registeredEmail);
        if (!mounted) return;

        _emailController.text = registeredEmail;
        _passwordController.clear();
        setState(() {
          _isSignUp = false;
          _rememberAccount = true;
        });
        _showTopNotification(
          'Đã gửi email xác nhận. Vui lòng kiểm tra hộp thư để hoàn tất đăng ký Deery Vocab.',
        );
      }
      return;
    }

    final shouldSaveAutofill = _rememberAccount;
    final rememberedEmail = shouldSaveAutofill ? _emailController.text : null;
    final session = await notifier.signInWithPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (session != null) {
      await _saveRememberedEmail(rememberedEmail);
      TextInput.finishAutofillContext(shouldSave: shouldSaveAutofill);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Session?>>(authProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          final message = error is AuthFailure
              ? error.message
              : 'Đã xảy ra lỗi xác thực. Vui lòng thử lại.';
          _showTopNotification(message, isError: true);
        },
      );
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8EE),
      body: GestureDetector(
        key: const Key('auth-dismiss-keyboard-area'),
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const GraphPaperBackground(),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _wideLayoutMinWidth;

                return SafeArea(
                  child: isWide
                      ? _buildWideScreenLayout(context, isLoading)
                      : _buildMobileScreenLayout(context, isLoading),
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.4),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          )),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _topMessage != null
                          ? _buildTopBannerNotification()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileScreenLayout(
    BuildContext context,
    bool isLoading,
  ) {
    return Center(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              _buildFormCard(isLoading),
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
  ) {
    return Center(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        _buildFormCard(isLoading),
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

  Widget _buildFormCard(bool isLoading) {
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
                  shadowKey: const Key('display-name-input-shadow'),
                  child: TextFormField(
                    key: const Key('sign-up-display-name-field'),
                    errorBuilder: _buildFieldError,
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
                shadowKey: const Key('email-input-shadow'),
                child: TextFormField(
                  key: const Key('email-field'),
                  errorBuilder: _buildFieldError,
                  controller: _emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
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
                      return 'Email chưa đúng định dạng. Ví dụ: ban@example.com';
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
                shadowKey: const Key('password-input-shadow'),
                child: TextFormField(
                  key: const Key('password-field'),
                  errorBuilder: _buildFieldError,
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  obscuringCharacter: '•',
                  autocorrect: false,
                  enableSuggestions: false,
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
                    if (!Validators.isValidPassword(value)) {
                      return 'Mật khẩu cần ít nhất ${Validators.minimumPasswordLength} ký tự.';
                    }
                    return null;
                  },
                  onFieldSubmitted: isLoading ? null : (_) => _submit(),
                ),
              ),
              if (!_isSignUp) ...[
                const SizedBox(height: 12),
                _buildRememberAndForgotPasswordRow(isLoading),
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
          color: AppColors.coral,
          width: 2.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.coral,
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildInputBox({
    required Key boxKey,
    required Key shadowKey,
    required Widget child,
  }) {
    return Stack(
      key: boxKey,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 3,
          top: 3,
          right: -3,
          height: 48,
          child: DecoratedBox(
            key: shadowKey,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildFieldError(BuildContext context, String message) {
    return _AutoDismissFieldError(
      key: ValueKey('auto-dismiss-field-error-$message'),
      message: message,
    );
  }

  Widget _buildRememberAndForgotPasswordRow(bool isLoading) {
    return Row(
      key: const Key('remember-and-forgot-password-row'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildRememberAccountOption(isLoading),
        ),
        const SizedBox(width: 8),
        _buildForgotPasswordButton(isLoading),
      ],
    );
  }

  Widget _buildRememberAccountOption(bool isLoading) {
    final onTap =
        isLoading ? null : () => _setRememberAccount(!_rememberAccount);

    return Semantics(
      container: true,
      label: 'Ghi nhớ tài khoản',
      checked: _rememberAccount,
      enabled: !isLoading,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          key: const Key('remember-account-box'),
          color: Colors.transparent,
          child: InkWell(
            key: const Key('remember-account-checkbox'),
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('remember-account-indicator'),
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _rememberAccount
                          ? AppColors.lime
                          : AppColors.softWhite,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.ink,
                        width: 2.0,
                      ),
                    ),
                    child: _rememberAccount
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: AppColors.ink,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Ghi nhớ tài khoản',
                      key: Key('remember-account-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton(bool isLoading) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('forgot-password-button'),
        borderRadius: BorderRadius.circular(6),
        onTap: isLoading ? null : _showForgotPasswordDialog,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            'Quên mật khẩu?',
            key: Key('forgot-password-label'),
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'Nunito',
              decoration: TextDecoration.underline,
              decorationColor: AppColors.ink,
              decorationThickness: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.softWhite,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: AppColors.ink,
                  width: 2.5,
                ),
              ),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.ink,
                        width: 1.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Khôi phục mật khẩu',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nhập email của bạn để nhận liên kết đặt lại mật khẩu.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedInk,
                          fontFamily: 'Nunito',
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildInputBox(
                        boxKey: const Key('reset-password-email-input-box'),
                        shadowKey:
                            const Key('reset-password-email-input-shadow'),
                        child: TextFormField(
                          key: const Key('reset-password-email-field'),
                          errorBuilder: _buildFieldError,
                          controller: resetEmailController,
                          enabled: !isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontFamily: 'Nunito',
                          ),
                          decoration: _inputDecoration(
                            hintText: 'Nhập email của bạn',
                            labelText: 'Email',
                          ),
                          validator: (value) {
                            if (!Validators.isNotEmpty(value)) {
                              return 'Vui lòng nhập email.';
                            }
                            if (!Validators.isEmail(value!.trim())) {
                              return 'Email chưa đúng định dạng. Ví dụ: ban@example.com';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const Key('reset-password-cancel-button'),
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: FilledButton(
                    key: const Key('reset-password-submit-button'),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            setDialogState(() {
                              isSubmitting = true;
                              dialogError = null;
                            });

                            final sent = await ref
                                .read(passwordRecoveryProvider.notifier)
                                .sendResetEmail(resetEmailController.text);

                            if (!sent) {
                              final error =
                                  ref.read(passwordRecoveryProvider).error;
                              setDialogState(() {
                                isSubmitting = false;
                                dialogError = error is AuthFailure
                                    ? error.message
                                    : 'Không thể gửi email lúc này. Vui lòng thử lại.';
                              });
                              return;
                            }

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();

                            if (!mounted) return;
                            _showTopNotification(
                              'Nếu tài khoản tồn tại, bạn sẽ nhận được liên kết đặt lại mật khẩu. Vui lòng kiểm tra cả thư rác.',
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                          color: AppColors.ink,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 48),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : const Text(
                            'Gửi liên kết',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildTopBannerNotification() {
    final isError = _topMessageIsError;
    final title = isError ? 'Chưa thể hoàn tất' : 'Tuyệt vời!';
    final bgColor = isError ? const Color(0xFFFFE9E4) : const Color(0xFFF2FFD9);
    final accentColor = isError ? AppColors.coral : AppColors.lime;
    final iconData =
        isError ? Icons.priority_high_rounded : Icons.check_rounded;

    return Semantics(
      liveRegion: true,
      label: '$title ${_topMessage ?? ''}',
      child: Container(
        key: const Key('top-notification-banner'),
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.ink,
            width: 2.6,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
                border: Border.all(
                  color: AppColors.ink,
                  width: 2.2,
                ),
              ),
              child: Icon(
                iconData,
                color: AppColors.ink,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: const Key('top-notification-title'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      fontFamily: 'Fredoka',
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _topMessage ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedInk,
                      fontFamily: 'Nunito',
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('top-notification-dismiss-button'),
              onPressed: _dismissTopNotification,
              tooltip: 'Đóng thông báo',
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.close_rounded,
                size: 21,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoDismissFieldError extends StatefulWidget {
  const _AutoDismissFieldError({
    super.key,
    required this.message,
  });

  final String message;

  @override
  State<_AutoDismissFieldError> createState() => _AutoDismissFieldErrorState();
}

class _AutoDismissFieldErrorState extends State<_AutoDismissFieldError> {
  Timer? _dismissTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isVisible = false);
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24, right: 3, bottom: 3),
      child: Transform.translate(
        offset: const Offset(-18, 0),
        child: Container(
          key: ValueKey('field-error-${widget.message}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: AppColors.ink,
              width: 2,
            ),
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
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppColors.softWhite,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: AppColors.softWhite,
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
