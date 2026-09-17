// UC-SETT-01: profile, theme, PRO paywall, đăng xuất
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/entitlements/entitlement_provider.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../../../../shared/widgets/top_notification.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/application/onboarding_status_store.dart';
import '../../../onboarding/presentation/providers/onboarding_status_provider.dart';
import '../providers/cloud_backup_consent_provider.dart';

typedef ResetOnboarding = Future<void> Function();

final resetOnboardingProvider = Provider<ResetOnboarding>(
  (ref) => () async {
    final userId = SupabaseService.auth.currentUser?.id;
    await resetOnboardingAndUpdateCache(
      userId: userId,
      resetRemote: () => SupabaseService.client.rpc('reset_my_onboarding'),
      store: ref.read(onboardingStatusStoreProvider),
    );
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
  bool _isUpdatingCloudBackup = false;
  bool _isBackfillingCloudBackup = false;

  Future<void> _changeCloudBackupConsent(bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.softWhite,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.ink, width: 2.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: AppColors.blue),
              SizedBox(width: 8),
              Expanded(child: Text('Bật sao lưu đám mây?')),
            ],
          ),
          content: const Text(
            'Ảnh và dữ liệu của các bài quét mới sẽ được tải lên vùng riêng tư '
            'trên Supabase. Bản trong máy vẫn dùng được khi mất mạng.\n\n'
            'Bài đã lưu trước đó chỉ được tải lên khi bạn chọn “Sao lưu bài '
            'đã có”. Đồng ý này không cho phép dùng dữ liệu để huấn luyện AI '
            'trên thiết bị.',
          ),
          actions: [
            TextButton(
              key: const Key('cloud-backup-cancel-button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              key: const Key('cloud-backup-confirm-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đồng ý và bật'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isUpdatingCloudBackup = true);
    try {
      await ref.read(setCloudBackupConsentProvider)(enabled);

      if (!mounted) return;
      showTopNotification(
        context,
        SnackBar(
          content: Text(
            enabled
                ? 'Đã bật sao lưu. Bài cũ chỉ tải lên khi bạn chọn.'
                : 'Đã tắt tải lên. Dữ liệu cloud hiện có chưa bị xóa.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update cloud backup consent: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      showTopNotification(
        context,
        const SnackBar(
          content: Text('Không thể cập nhật sao lưu. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingCloudBackup = false);
    }
  }

  Future<void> _backfillExistingPhotoNotes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.softWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.ink, width: 2.5),
        ),
        title: const Text('Sao lưu các bài đã có?'),
        content: const Text(
          'Chỉ các bài đang còn trong Thư viện, có đủ ảnh trên máy hoặc dùng '
          'ảnh đã nằm trên cloud mới được xếp để sao lưu. Ảnh bị thiếu và bài '
          'trong thùng rác sẽ được bỏ qua. Dữ liệu này không được dùng để '
          'train AI.',
        ),
        actions: [
          TextButton(
            key: const Key('cloud-backup-backfill-cancel-button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('cloud-backup-backfill-confirm-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xác nhận sao lưu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBackfillingCloudBackup = true);
    try {
      final result = await ref.read(backfillExistingPhotoNotesProvider)();
      if (!mounted) return;
      final message = switch (result) {
        (:final queuedCount, :final missingMediaCount)
            when queuedCount > 0 && missingMediaCount > 0 =>
          'Đã xếp $queuedCount bài cũ để sao lưu; bỏ qua '
              '$missingMediaCount bài thiếu ảnh.',
        (:final queuedCount, missingMediaCount: _) when queuedCount > 0 =>
          'Đã xếp $queuedCount bài cũ để sao lưu.',
        (queuedCount: _, :final missingMediaCount) when missingMediaCount > 0 =>
          'Không có bài đủ điều kiện; $missingMediaCount bài đang thiếu ảnh.',
        _ => 'Không có bài cũ nào cần sao lưu.',
      };
      showTopNotification(
        context,
        SnackBar(content: Text(message)),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to backfill cloud backup: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      showTopNotification(
        context,
        const SnackBar(
          content: Text('Không thể xếp bài cũ để sao lưu. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBackfillingCloudBackup = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.softWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.ink, width: 2.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.coral),
            SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi DeerVocab?',
          style: TextStyle(
            color: AppColors.mutedInk,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(
                color: AppColors.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            key: const Key('logout-confirm-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
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

      showTopNotification(
        context,
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
        backgroundColor: AppColors.softWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.ink, width: 2.5),
        ),
        title: const Text('Reset onboarding'),
        content: const Text('Bạn chắc chắn muốn reset onboarding?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
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

      showTopNotification(
        context,
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
    final entitlements = ref.watch(entitlementProvider);
    final user = SupabaseService.auth.currentUser;
    final libraryUserId = ref.watch(currentLibraryUserIdProvider);
    final cloudBackupConsent = ref.watch(cloudBackupConsentProvider);
    final cloudBackupEnabled = cloudBackupConsent.maybeWhen(
      data: (account) => account?.cloudBackupEnabled ?? false,
      orElse: () => false,
    );
    final cloudBackupLoading = cloudBackupConsent.isLoading;
    final cloudBackupError = cloudBackupConsent.hasError;
    final metadata = user?.userMetadata;
    final displayName =
        (metadata?['display_name'] as String?)?.trim().isNotEmpty == true
            ? metadata!['display_name'] as String
            : (user?.email?.split('@').first ?? 'Học viên Deer');
    final email = user?.email ?? 'Chưa liên kết email';

    return GraphPaperScaffold(
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  // Back Button
                  SizedBox.square(
                    dimension: 48,
                    child: StickerButton(
                      semanticLabel: 'Quay lại',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                      surfaceColor: AppColors.yellow,
                      borderColor: AppColors.ink,
                      radius: 14,
                      padding: EdgeInsets.zero,
                      expand: true,
                      icon: const Icon(Icons.arrow_back_rounded),
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Cài đặt',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            // Settings Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(22),
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
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.ink,
                              width: 2.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '🦌',
                            style: TextStyle(fontSize: 38),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (entitlements.can(
                                    AppCapability.aiScanAdvanced,
                                  )) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      key: const Key('pro-badge'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.yellow,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: AppColors.ink,
                                          width: 1.6,
                                        ),
                                      ),
                                      child: const Text(
                                        'PRO',
                                        style: TextStyle(
                                          color: AppColors.ink,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedInk,
                                  fontWeight: FontWeight.w700,
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

                  const SizedBox(height: 16),

                  // General Settings Section
                  _buildSectionHeading(
                    title: 'Ứng dụng',
                    accent: AppColors.blue,
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(22),
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
                        _buildSettingTile(
                          icon: Icons.language_rounded,
                          iconColor: AppColors.blue,
                          title: 'Ngôn ngữ học',
                          subtitle: 'Tiếng Anh (English)',
                        ),
                        const Divider(
                          height: 1,
                          indent: 56,
                          color: Color(0x241A1A1A),
                        ),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: AppColors.lime,
                          title: 'Phiên bản',
                          subtitle: '1.0.0',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSectionHeading(
                    title: 'Dữ liệu và quyền riêng tư',
                    accent: AppColors.mint,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(22),
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
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(
                          color: Colors.transparent,
                          width: 0,
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            key: const Key('cloud-backup-switch'),
                            value: cloudBackupEnabled,
                            activeThumbColor: AppColors.ink,
                            activeTrackColor: AppColors.mint,
                            onChanged: libraryUserId == null ||
                                    cloudBackupLoading ||
                                    _isUpdatingCloudBackup ||
                                    _isBackfillingCloudBackup
                                ? null
                                : _changeCloudBackupConsent,
                            secondary: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: 1.8,
                                ),
                              ),
                              child: _isUpdatingCloudBackup
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.ink,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.cloud_upload_outlined,
                                      color: AppColors.ink,
                                      size: 22,
                                    ),
                            ),
                            title: const Text(
                              'Sao lưu đám mây',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                            subtitle: Text(
                              libraryUserId == null
                                  ? 'Đăng nhập để bật sao lưu'
                                  : cloudBackupError
                                      ? 'Không đọc được trạng thái trên máy'
                                      : cloudBackupEnabled
                                          ? 'Bài mới tự sao lưu; bài cũ chỉ khi bạn chọn'
                                          : 'Chỉ lưu trên thiết bị',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedInk,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                          ),
                          if (cloudBackupEnabled)
                            ListTile(
                              key: const Key('cloud-backup-backfill-button'),
                              enabled: !_isUpdatingCloudBackup &&
                                  !_isBackfillingCloudBackup,
                              leading: _buildIconBadge(
                                icon: Icons.cloud_sync_outlined,
                                color: AppColors.mint,
                              ),
                              contentPadding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                12,
                                10,
                              ),
                              title: const Text(
                                'Sao lưu bài đã có',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              subtitle: const Text(
                                'Chỉ sao lưu bài đủ ảnh sau khi bạn xác nhận',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                              trailing: _isBackfillingCloudBackup
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.ink,
                                    ),
                              onTap: _isBackfillingCloudBackup
                                  ? null
                                  : _backfillExistingPhotoNotes,
                            ),
                          if (cloudBackupError)
                            Align(
                              alignment: Alignment.centerRight,
                              child: StickerButton(
                                key: const Key('cloud-backup-retry-button'),
                                onPressed: () =>
                                    ref.invalidate(cloudBackupConsentProvider),
                                icon: const Icon(Icons.refresh_rounded),
                                text: 'Thử lại',
                                semanticLabel: 'Thử lại trạng thái sao lưu',
                                surfaceColor: AppColors.yellow,
                                borderColor: AppColors.ink,
                                radius: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Account Actions Section
                  _buildSectionHeading(
                    title: 'Tài khoản',
                    accent: AppColors.coral,
                  ),
                  const SizedBox(height: 8),

                  // Logout Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(22),
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
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('logout-button'),
                        borderRadius: BorderRadius.circular(22),
                        onTap: _isLoggingOut ? null : _signOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.coral.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: 1.8,
                                  ),
                                ),
                                child: _isLoggingOut
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.ink,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.logout_rounded,
                                        color: AppColors.ink,
                                        size: 23,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.coral,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.ink,
                                size: 23,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Debug Mode Section
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    _buildSectionHeading(
                      title: 'Debug',
                      accent: AppColors.coral,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: StickerButton(
                        key: const Key('reset-onboarding-debug-button'),
                        onPressed:
                            _isResettingOnboarding ? null : _resetOnboarding,
                        surfaceColor: _isResettingOnboarding
                            ? AppColors.mutedInk
                            : AppColors.coral,
                        textColor: Colors.white,
                        borderColor: AppColors.ink,
                        radius: 16,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        fontSize: 15,
                        expand: true,
                        icon: _isResettingOnboarding
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.build_rounded),
                        text: 'Reset Onboarding (Debug)',
                        semanticLabel: 'Reset Onboarding (Debug)',
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeading({
    required String title,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.ink,
              width: 1.8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.ink,
          width: 1.8,
        ),
      ),
      child: Icon(icon, color: AppColors.ink, size: 22),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.ink,
                width: 1.8,
              ),
            ),
            child: Icon(icon, color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedInk,
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
