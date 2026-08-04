// UC-SETT-01: profile, theme, PRO paywall, đăng xuất
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Text('SettingsScreen'),
              ),
            ),
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('reset-onboarding-debug-button'),
                    onPressed: _isResettingOnboarding ? null : _resetOnboarding,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
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
                    label: const Text('🔧 Reset Onboarding (Debug)'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
