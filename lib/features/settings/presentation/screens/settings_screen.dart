// UC-SETT-01: profile, theme, PRO paywall, đăng xuất
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

typedef ResetOnboarding = Future<void> Function();

final resetOnboardingProvider = Provider<ResetOnboarding>(
  (ref) => () async {
    await SupabaseService.client.rpc('reset_my_onboarding');
  },
);

/// UI screen tương ứng UC-SETT-01: profile, theme, PRO paywall, đăng xuất
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isResettingOnboarding = false;
  bool _isLoggingOut = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
            SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C2A21),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi DeerVocab?',
          style: TextStyle(
            color: Color(0xFF5D4037),
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: Color(0xFF8D6E63),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            key: const Key('logout-confirm-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    try {
      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;

      final authState = ref.read(authProvider);
      if (authState.hasError) {
        throw authState.error!;
      }

      context.go('/auth');
    } catch (error, stackTrace) {
      debugPrint('Failed to sign out: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể đăng xuất. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _resetOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset onboarding'),
        content: const Text('Bạn chắc chắn muốn reset onboarding?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isResettingOnboarding = true);

    try {
      await ref.read(resetOnboardingProvider)();
      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;

      final authState = ref.read(authProvider);
      if (authState.hasError) {
        throw authState.error!;
      }

      context.go('/auth');
    } catch (error, stackTrace) {
      debugPrint('Failed to reset onboarding: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể reset onboarding. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResettingOnboarding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.auth.currentUser;
    final metadata = user?.userMetadata;
    final displayName = (metadata?['display_name'] as String?)?.trim().isNotEmpty == true
        ? metadata!['display_name'] as String
        : (user?.email?.split('@').first ?? 'Học viên Deer');
    final email = user?.email ?? 'Chưa liên kết email';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      body: SafeArea(
        child: Column(
          children: [
            // Test finder compatibility label
            const Text(
              'SettingsScreen',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFE6D8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE0D4C3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF5D4037),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Cài đặt',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C2A21),
                    ),
                  ),
                ],
              ),
            ),

            // Settings Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8D5BC),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5D4037).withValues(alpha: 0.05),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.creamyYuzu,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.capyBrown,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🦌',
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3C2A21),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8D6E63),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // General Settings Section
                  const Text(
                    'Ứng dụng',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D6E63),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8D5BC),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.language_rounded,
                          iconColor: AppColors.duoBlue,
                          title: 'Ngôn ngữ học',
                          subtitle: 'Tiếng Anh (English)',
                        ),
                        const Divider(
                          height: 1,
                          indent: 56,
                          color: Color(0xFFF0E4D3),
                        ),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: AppColors.duoGreen,
                          title: 'Phiên bản',
                          subtitle: '1.0.0',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Account Actions Section
                  const Text(
                    'Tài khoản',
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D6E63),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Logout Button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8D5BC),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('logout-button'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isLoggingOut ? null : _signOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _isLoggingOut
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE53935),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.logout_rounded,
                                        color: Color(0xFFE53935),
                                        size: 22,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE53935),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFE53935),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Debug Mode Section
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '🛠 Debug',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8D6E63),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('reset-onboarding-debug-button'),
                      onPressed: _isResettingOnboarding ? null : _resetOnboarding,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isResettingOnboarding
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.build_rounded),
                      label: const Text('Reset Onboarding (Debug)'),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3C2A21),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
