import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../domain/entities/library_enums.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/photo_note.dart';
import '../../domain/entities/photo_note_snapshot.dart';
import '../../domain/entities/scan_models.dart';
import '../../domain/repositories/library_repository.dart';
import '../../application/library_cloud_media_restore_service.dart';
import '../../application/library_media_recovery_service.dart';
import '../providers/library_media_integrity_provider.dart';
import '../providers/library_cloud_media_restore_provider.dart';
import '../providers/library_provider.dart';

/// Offline-first Library for saved scan aggregates.
class StorageAlbumScreen extends ConsumerWidget {
  const StorageAlbumScreen({this.onOpenPhotoNote, super.key});

  final ValueChanged<String>? onOpenPhotoNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(libraryPhotoNotesProvider);
    final mediaRecovery = ref.watch(libraryMediaRecoverySnapshotProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Text('📚', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thư viện của tôi',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3C2A21),
                                  ),
                        ),
                        Text(
                          notes.maybeWhen(
                            data: (items) => items.isEmpty
                                ? 'Các bài quét sẽ tự lưu tại đây'
                                : '${items.length} bài trong thư viện',
                            orElse: () => 'Đang đọc dữ liệu trên thiết bị',
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF786A61),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('library-open-trash'),
                    tooltip: 'Mở thùng rác',
                    onPressed: () => context.push('/storage/trash'),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  const _OfflineBadge(),
                ],
              ),
            ),
            const _LibraryStorageSummaryCard(),
            _MediaRecoveryBanner(
              recovery: mediaRecovery,
              onOpen: (snapshot) => _showMediaRecoverySheet(
                context,
                snapshot,
              ),
            ),
            Expanded(
              child: notes.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    key: Key('library-loading-indicator'),
                  ),
                ),
                error: (error, stackTrace) => _StateMessage(
                  key: const Key('library-error-state'),
                  icon: Icons.storage_rounded,
                  title: 'Không thể đọc thư viện',
                  message: 'Dữ liệu trên máy chưa tải được. Hãy thử lại.',
                  actionLabel: 'Thử lại',
                  onAction: () => ref.invalidate(libraryPhotoNotesProvider),
                ),
                data: (items) => items.isEmpty
                    ? _StateMessage(
                        key: const Key('library-empty-state'),
                        icon: Icons.photo_library_outlined,
                        title: 'Chưa có bài quét nào',
                        message:
                            'Quét một bức ảnh; kết quả sẽ tự lưu để bạn xem lại khi không có mạng.',
                        actionLabel: 'Quét ảnh đầu tiên',
                        onAction: () => context.push('/scan'),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(libraryPhotoNotesProvider);
                          await ref.read(libraryPhotoNotesProvider.future);
                        },
                        child: ListView.separated(
                          key: const Key('library-photo-note-list'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final note = items[index];
                            return _PhotoNoteCard(
                              note: note,
                              onMoveToTrash: () =>
                                  _movePhotoNoteToTrash(context, ref, note),
                              onTap: () {
                                final callback = onOpenPhotoNote;
                                if (callback != null) {
                                  callback(note.id);
                                } else {
                                  context.push('/storage/${note.id}');
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }

  Future<void> _movePhotoNoteToTrash(
    BuildContext context,
    WidgetRef ref,
    PhotoNote note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chuyển bài vào thùng rác?'),
        content: const Text(
          'Bài sẽ không còn trong Thư viện chính. Bạn có thể khôi phục trong 30 ngày trước khi yêu cầu xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('library-trash-confirm-action'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chuyển bài'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      await repository.movePhotoNotesToTrash(
        userId: note.userId,
        photoNoteIds: [note.id],
        deletedAt: DateTime.now().toUtc(),
      );
      _invalidateLibraryProviders(ref, note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chuyển bài vào thùng rác.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chuyển bài vào thùng rác.'),
          ),
        );
      }
    }
  }

  void _showMediaRecoverySheet(
    BuildContext context,
    LibraryMediaRecoverySnapshot snapshot,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: _MediaRecoverySheet(initialSnapshot: snapshot),
      ),
    );
  }
}

class _LibraryStorageSummaryCard extends ConsumerWidget {
  const _LibraryStorageSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(libraryStorageSummaryProvider);
    return summary.maybeWhen(
      data: (value) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          key: const Key('library-storage-summary'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5EFE7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.sd_storage_outlined, color: Color(0xFF786A61)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${value.localMediaCount}/${value.totalMediaCount} ảnh trên máy • '
                  '${_formatBytes(value.localMediaBytes)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _storageSecondarySummary(value),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF786A61),
                    ),
              ),
            ],
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MediaRecoveryBanner extends StatelessWidget {
  const _MediaRecoveryBanner({
    required this.recovery,
    required this.onOpen,
  });

  final AsyncValue<LibraryMediaRecoverySnapshot?> recovery;
  final ValueChanged<LibraryMediaRecoverySnapshot> onOpen;

  @override
  Widget build(BuildContext context) {
    final snapshot = recovery.valueOrNull;
    if (snapshot == null || !snapshot.hasFindings) {
      return const SizedBox.shrink();
    }
    final count = snapshot.integrity.orphanRelativePaths.length +
        snapshot.integrity.missingRelativePaths.length +
        snapshot.quarantined.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        key: const Key('library-media-recovery-banner'),
        margin: EdgeInsets.zero,
        color: const Color(0xFFFFF3D6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpen(snapshot),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    color: Color(0xFF9A5B00),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kiểm tra ảnh trên máy',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF5D3A00),
                                  ),
                        ),
                        Text(
                          '$count mục cần xử lý hoặc có thể khôi phục',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: const Color(0xFF6B460B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaRecoverySheet extends ConsumerStatefulWidget {
  const _MediaRecoverySheet({required this.initialSnapshot});

  final LibraryMediaRecoverySnapshot initialSnapshot;

  @override
  ConsumerState<_MediaRecoverySheet> createState() =>
      _MediaRecoverySheetState();
}

class _MediaRecoverySheetState extends ConsumerState<_MediaRecoverySheet> {
  late LibraryMediaRecoverySnapshot _snapshot = widget.initialSnapshot;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final orphans = _snapshot.integrity.orphanRelativePaths.toList()..sort();
    final missingCount = _snapshot.integrity.missingRelativePaths.length;
    return SafeArea(
      top: false,
      child: ListView(
        key: const Key('library-media-recovery-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            'Khôi phục ảnh cục bộ',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chỉ quản lý ảnh trong vùng riêng của ứng dụng. Bài học, JSON và từ vựng không bị xóa ở đây.',
          ),
          if (missingCount > 0) ...[
            const SizedBox(height: 16),
            _RecoveryInfoCard(
              key: const Key('library-media-missing-info'),
              icon: Icons.broken_image_outlined,
              title: '$missingCount ảnh được tham chiếu đang thiếu',
              message:
                  'Bài và từ vựng vẫn dùng offline. Mẫu liên quan bị loại khỏi tập train để AI không học từ dữ liệu thiếu.',
            ),
          ],
          if (orphans.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RecoveryHeading(
              title: 'Ảnh chưa gắn với bài (${orphans.length})',
              description:
                  'Cách ly để giữ ảnh thêm 30 ngày trước khi ứng dụng xóa.',
            ),
            ...orphans.map(
              (path) => _RecoveryFileCard(
                key: Key('library-orphan-$path'),
                filename: _mediaFilename(path),
                child: FilledButton.icon(
                  key: Key('library-quarantine-$path'),
                  onPressed: _busy ? null : () => _confirmQuarantine(path),
                  style: _recoveryButtonStyle(),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Cách ly'),
                ),
              ),
            ),
          ],
          if (_snapshot.quarantined.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RecoveryHeading(
              title: 'Đang cách ly (${_snapshot.quarantined.length})',
              description: 'Có thể khôi phục hoặc xóa vĩnh viễn ngay.',
            ),
            ..._snapshot.quarantined.map(
              (entry) => _RecoveryFileCard(
                key: Key('library-quarantined-${entry.relativePath}'),
                filename: _mediaFilename(entry.relativePath),
                subtitle:
                    'Giữ đến ${_formatDate(entry.purgeEligibleAt.toLocal())}',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: Key('library-restore-${entry.relativePath}'),
                      onPressed:
                          _busy ? null : () => _restore(entry.relativePath),
                      style: _recoveryButtonStyle(),
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Khôi phục'),
                    ),
                    TextButton.icon(
                      key: Key('library-delete-${entry.relativePath}'),
                      onPressed: _busy
                          ? null
                          : () => _confirmDelete(entry.relativePath),
                      style: _recoveryButtonStyle(
                        foregroundColor: const Color(0xFFB3261E),
                      ),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Xóa ngay'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!_snapshot.hasFindings) ...[
            const SizedBox(height: 36),
            const _RecoveryInfoCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'Ảnh cục bộ đang ổn',
              message: 'Không còn mục nào cần xử lý.',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmQuarantine(String path) async {
    final confirmed = await _confirm(
      title: 'Cách ly ảnh này?',
      message:
          'Ảnh chưa gắn với bài sẽ được chuyển sang vùng cách ly. Bạn có 30 ngày để khôi phục trước khi ảnh bị xóa tự động.',
      actionLabel: 'Cách ly',
    );
    if (confirmed) {
      await _runAction(
        (service) => service.quarantineOrphan(
          path,
          now: DateTime.now().toUtc(),
        ),
        successMessage: 'Đã cách ly ảnh trong 30 ngày.',
      );
    }
  }

  Future<void> _restore(String path) => _runAction(
        (service) => service.restore(path),
        successMessage: 'Đã khôi phục ảnh về bộ nhớ ứng dụng.',
      );

  Future<void> _confirmDelete(String path) async {
    final confirmed = await _confirm(
      title: 'Xóa ảnh vĩnh viễn?',
      message:
          'Ảnh này sẽ bị xóa khỏi thiết bị và không thể khôi phục. Bài học và từ vựng không bị ảnh hưởng.',
      actionLabel: 'Xóa vĩnh viễn',
      destructive: true,
    );
    if (confirmed) {
      await _runAction(
        (service) => service.deleteQuarantined(path),
        successMessage: 'Đã xóa ảnh khỏi thiết bị.',
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                key: const Key('library-recovery-confirm-action'),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB3261E),
                        minimumSize: const Size(0, 48),
                      )
                    : _recoveryButtonStyle(),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _runAction(
    Future<void> Function(LibraryMediaRecoveryService service) action, {
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      final service =
          await ref.read(libraryMediaRecoveryServiceProvider.future);
      if (service == null) throw StateError('Recovery is unavailable');
      await action(service);
      ref.invalidate(libraryMediaIntegrityAuditProvider);
      ref.invalidate(libraryMediaRecoverySnapshotProvider);
      final refreshed =
          await ref.read(libraryMediaRecoverySnapshotProvider.future);
      if (!mounted) return;
      if (refreshed != null) setState(() => _snapshot = refreshed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xử lý ảnh lúc này. Hãy thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RecoveryHeading extends StatelessWidget {
  const _RecoveryHeading({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(description),
          ],
        ),
      );
}

class _RecoveryInfoCard extends StatelessWidget {
  const _RecoveryInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF9A5B00)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _RecoveryFileCard extends StatelessWidget {
  const _RecoveryFileCard({
    required this.filename,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String filename;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!),
              ],
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: child),
            ],
          ),
        ),
      );
}

ButtonStyle _recoveryButtonStyle({Color? foregroundColor}) =>
    FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: foregroundColor,
    );

String _mediaFilename(String relativePath) =>
    relativePath.replaceAll('\\', '/').split('/').last;

class LibraryTrashScreen extends ConsumerWidget {
  const LibraryTrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(libraryTrashPhotoNotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thùng rác')),
      body: SafeArea(
        child: notes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _StateMessage(
            key: const Key('library-trash-error'),
            icon: Icons.delete_outline_rounded,
            title: 'Không thể đọc thùng rác',
            message: 'Dữ liệu local chưa đọc được. Hãy thử lại.',
            actionLabel: 'Thử lại',
            onAction: () => ref.invalidate(libraryTrashPhotoNotesProvider),
          ),
          data: (items) => items.isEmpty
              ? const _StateMessage(
                  key: Key('library-trash-empty'),
                  icon: Icons.delete_sweep_outlined,
                  title: 'Thùng rác đang trống',
                  message:
                      'Bài đã chuyển vào đây có thể khôi phục trong 30 ngày.',
                )
              : ListView(
                  key: const Key('library-trash-list'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    const Card(
                      color: Color(0xFFFFF3D6),
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Bài trong thùng rác được giữ 30 ngày. Xóa vĩnh viễn có thể cần chờ đồng bộ cloud khi thiết bị có mạng.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map(
                      (note) => _TrashPhotoNoteCard(
                        note: note,
                        onRestore: () => _restorePhotoNote(context, ref, note),
                        onDelete: () =>
                            _requestPermanentDelete(context, ref, note),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _restorePhotoNote(
    BuildContext context,
    WidgetRef ref,
    PhotoNote note,
  ) async {
    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      await repository.restorePhotoNotes(
        userId: note.userId,
        photoNoteIds: [note.id],
        restoredAt: DateTime.now().toUtc(),
      );
      _invalidateLibraryProviders(ref, note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã khôi phục bài vào Thư viện.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể khôi phục bài.')),
        );
      }
    }
  }

  Future<void> _requestPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    PhotoNote note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yêu cầu xóa vĩnh viễn?'),
        content: const Text(
          'Bài, ảnh và dữ liệu nguồn sẽ bị xóa khỏi thiết bị và không thể khôi phục. Nếu đã sao lưu, bản cloud cũng được đưa vào hàng chờ xóa kể cả khi Cloud Backup đang tắt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('library-permanent-delete-confirm-action'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      await repository.requestPermanentDeletion(
        userId: note.userId,
        photoNoteIds: [note.id],
        requestedAt: DateTime.now().toUtc(),
      );
      final deletionService =
          await ref.read(libraryPhotoNoteDeletionServiceProvider.future);
      await deletionService?.maintain(
        userId: note.userId,
        now: DateTime.now().toUtc(),
      );
      _invalidateLibraryProviders(ref, note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã xóa khỏi thiết bị. Nếu có bản cloud, app sẽ tiếp tục xóa khi có mạng.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo yêu cầu xóa.')),
        );
      }
    }
  }
}

class _TrashPhotoNoteCard extends StatelessWidget {
  const _TrashPhotoNoteCard({
    required this.note,
    required this.onRestore,
    required this.onDelete,
  });

  final PhotoNote note;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final deletedAt = note.deletedAt!;
    final purgeAt = deletedAt.add(const Duration(days: 30));
    final daysLeft = purgeAt.difference(DateTime.now().toUtc()).inDays + 1;
    return Card(
      key: Key('library-trash-note-${note.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${note.emoji ?? '📝'}  ${note.title}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              daysLeft > 0
                  ? 'Còn $daysLeft ngày • xóa lúc ${_formatDate(purgeAt)}'
                  : 'Đã đến hạn xóa vĩnh viễn',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF786A61),
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: Key('library-trash-restore-${note.id}'),
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Khôi phục'),
                ),
                TextButton.icon(
                  key: Key('library-trash-delete-${note.id}'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Xóa vĩnh viễn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryPhotoNoteDetailScreen extends ConsumerWidget {
  const LibraryPhotoNoteDetailScreen({required this.photoNoteId, super.key});

  final String photoNoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      libraryPhotoNoteSnapshotProvider(photoNoteId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Bài đã lưu')),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              key: Key('library-detail-loading-indicator'),
            ),
          ),
          error: (error, stackTrace) => _StateMessage(
            key: const Key('library-detail-error-state'),
            icon: Icons.menu_book_rounded,
            title: 'Không thể mở bài đã lưu',
            message: 'Dữ liệu trên máy chưa đọc được. Hãy thử lại.',
            actionLabel: 'Thử lại',
            onAction: () =>
                ref.invalidate(libraryPhotoNoteSnapshotProvider(photoNoteId)),
          ),
          data: (value) => value == null
              ? const _StateMessage(
                  key: Key('library-detail-missing-state'),
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy bài này',
                  message: 'Bài có thể đã bị xóa khỏi thư viện trên thiết bị.',
                )
              : _PhotoNoteDetail(snapshot: value),
        ),
      ),
    );
  }
}

class _PhotoNoteCard extends ConsumerWidget {
  const _PhotoNoteCard({
    required this.note,
    required this.onTap,
    required this.onMoveToTrash,
  });

  final PhotoNote note;
  final VoidCallback onTap;
  final VoidCallback onMoveToTrash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(libraryPhotoNoteSnapshotProvider(note.id));
    return Card(
      key: Key('library-photo-note-${note.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: 'Mở bài đã lưu ${note.title}',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 84,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: snapshot.when(
                      loading: () => const _ImagePlaceholder(isLoading: true),
                      error: (_, __) => const _ImagePlaceholder(),
                      data: (value) => value == null
                          ? const _ImagePlaceholder()
                          : _LocalLibraryImage(
                              mediaAsset: value.mediaAsset,
                              semanticLabel: 'Ảnh của ${note.title}',
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${note.emoji ?? '📝'}  ${note.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3C2A21),
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.maybeWhen(
                          data: (value) => value == null
                              ? 'Không tìm thấy dữ liệu chi tiết'
                              : '${value.vocabCount} từ vựng • ${_formatDate(note.createdAt)}',
                          orElse: () => _formatDate(note.createdAt),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF786A61),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _SyncStatusChip(status: note.syncStatus),
                          snapshot.maybeWhen(
                            data: (value) => value == null
                                ? const SizedBox.shrink()
                                : _MediaAvailabilityChip(
                                    mediaAsset: value.mediaAsset,
                                  ),
                            orElse: () => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_PhotoNoteAction>(
                  key: Key('library-note-menu-${note.id}'),
                  tooltip: 'Tùy chọn bài đã lưu',
                  onSelected: (action) {
                    if (action == _PhotoNoteAction.moveToTrash) {
                      onMoveToTrash();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _PhotoNoteAction.moveToTrash,
                      child: Text('Đưa vào thùng rác'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhotoNoteAction { moveToTrash }

class _PhotoNoteDetail extends StatelessWidget {
  const _PhotoNoteDetail({required this.snapshot});

  final PhotoNoteSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final note = snapshot.photoNote;
    final media = snapshot.mediaAsset;
    final imageRatio = (media.width / media.height).clamp(0.65, 1.8);
    return ListView(
      key: const Key('library-photo-note-detail'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: imageRatio,
            child: _LocalLibraryImage(
              mediaAsset: media,
              semanticLabel: 'Ảnh đã lưu của ${note.title}',
              showRetry: true,
              allowCloudRestore: true,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${note.emoji ?? '📝'}  ${note.title}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3C2A21),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            _SyncStatusChip(status: note.syncStatus),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${snapshot.vocabCount} từ vựng • ${_formatDateTime(note.createdAt)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF786A61),
              ),
        ),
        const SizedBox(height: 12),
        _OfflineNotice(mediaAsset: media),
        const SizedBox(height: 22),
        Text(
          'Từ vựng nhận diện',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (snapshot.detections.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bài quét này không có từ vựng được nhận diện.'),
            ),
          )
        else
          ...snapshot.detections.map(
            (detection) => _DetectionCard(
              detection: detection,
              annotations:
                  snapshot.annotationsByDetectionId[detection.id] ?? const [],
            ),
          ),
        if (snapshot.primaryScanRun != null) ...[
          const SizedBox(height: 14),
          Text(
            'Nguồn nhận diện: ${snapshot.primaryScanRun!.modelName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF786A61),
                ),
          ),
        ],
      ],
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.detection,
    required this.annotations,
  });

  final VocabDetection detection;
  final List<VocabAnnotation> annotations;

  @override
  Widget build(BuildContext context) {
    final annotation =
        annotations.where((item) => item.deletedAt == null).lastOrNull;
    final word = annotation?.correctedWord ?? detection.wordRaw;
    final phonetic = annotation?.correctedPhonetic ?? detection.phonetic;
    final meaning = annotation?.correctedMeaningVi ?? detection.meaningVi;
    return Card(
      key: Key('library-detection-${detection.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.duoBlue,
                        ),
                  ),
                ),
                if (detection.partOfSpeech != null)
                  Text(
                    detection.partOfSpeech!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF786A61),
                        ),
                  ),
              ],
            ),
            if (phonetic != null) ...[
              const SizedBox(height: 2),
              Text(phonetic),
            ],
            if (meaning != null) ...[
              const SizedBox(height: 8),
              Text(
                meaning,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (detection.exampleEn != null) ...[
              const SizedBox(height: 8),
              Text('“${detection.exampleEn}”'),
            ],
            if (detection.exampleVi != null)
              Text(
                detection.exampleVi!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _LocalLibraryImage extends ConsumerStatefulWidget {
  const _LocalLibraryImage({
    required this.mediaAsset,
    required this.semanticLabel,
    this.showRetry = false,
    this.allowCloudRestore = false,
  });

  final MediaAsset mediaAsset;
  final String semanticLabel;
  final bool showRetry;
  final bool allowCloudRestore;

  @override
  ConsumerState<_LocalLibraryImage> createState() => _LocalLibraryImageState();
}

class _LocalLibraryImageState extends ConsumerState<_LocalLibraryImage> {
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final relativePath = widget.mediaAsset.displayRelativePath;
    final bytes = ref.watch(libraryMediaBytesProvider(relativePath));
    return bytes.when(
      loading: () => const _ImagePlaceholder(isLoading: true),
      error: (error, stackTrace) {
        final restoreService =
            ref.watch(libraryCloudMediaRestoreServiceProvider);
        final canRestore = widget.allowCloudRestore &&
            widget.mediaAsset.remoteDisplayPath != null &&
            restoreService != null;
        return _ImagePlaceholder(
          isLoading: _restoring,
          message: widget.showRetry
              ? canRestore
                  ? 'Ảnh đang có trên Cloud Backup'
                  : 'Không tìm thấy ảnh local'
              : null,
          actionLabel: canRestore ? 'Tải ảnh từ cloud' : 'Thử lại',
          onAction: widget.showRetry && !_restoring
              ? canRestore
                  ? () => _restoreFromCloud(restoreService)
                  : () =>
                      ref.invalidate(libraryMediaBytesProvider(relativePath))
              : null,
        );
      },
      data: (value) => Image.memory(
        value,
        key: Key('library-media-$relativePath'),
        fit: BoxFit.cover,
        semanticLabel: widget.semanticLabel,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _ImagePlaceholder(
          message: widget.showRetry ? 'Ảnh local không đọc được' : null,
        ),
      ),
    );
  }

  Future<void> _restoreFromCloud(
    LibraryCloudMediaRestoreService restoreService,
  ) async {
    setState(() => _restoring = true);
    try {
      await restoreService.restoreDisplay(widget.mediaAsset);
      ref.invalidate(
        libraryMediaBytesProvider(widget.mediaAsset.displayRelativePath),
      );
      ref.invalidate(libraryStorageSummaryProvider);
      ref.invalidate(libraryMediaRecoverySnapshotProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tải ảnh về thiết bị.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải ảnh từ Cloud Backup.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    this.isLoading = false,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final bool isLoading;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFE6D8),
      child: Center(
        child: isLoading
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF786A61),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(message!, textAlign: TextAlign.center),
                  ],
                  if (onAction != null && actionLabel != null)
                    TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dữ liệu có thể xem khi không có mạng',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.duoGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.offline_pin_rounded, size: 17, color: Color(0xFF3F8F00)),
            SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(
                color: Color(0xFF3F8F00),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaAvailabilityChip extends ConsumerWidget {
  const _MediaAvailabilityChip({required this.mediaAsset});

  final MediaAsset mediaAsset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(
      libraryMediaBytesProvider(mediaAsset.displayRelativePath),
    );
    return bytes.when(
      loading: () => const _AvailabilityChip(
        label: 'Đang kiểm tra ảnh',
        icon: Icons.hourglass_top_rounded,
        color: Color(0xFF786A61),
      ),
      data: (_) => const _AvailabilityChip(
        label: 'Ảnh trên máy',
        icon: Icons.phone_android_rounded,
        color: Color(0xFF3F8F00),
      ),
      error: (_, __) => mediaAsset.remoteDisplayPath == null
          ? const _AvailabilityChip(
              label: 'Thiếu ảnh',
              icon: Icons.broken_image_outlined,
              color: Color(0xFFB5483A),
            )
          : const _AvailabilityChip(
              label: 'Ảnh trên cloud',
              icon: Icons.cloud_outlined,
              color: Color(0xFF2879A7),
            ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNotice extends ConsumerWidget {
  const _OfflineNotice({required this.mediaAsset});

  final MediaAsset mediaAsset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(
      libraryMediaBytesProvider(mediaAsset.displayRelativePath),
    );
    final (icon, color, message) = bytes.when(
      loading: () => (
        Icons.hourglass_top_rounded,
        const Color(0xFF786A61),
        'Từ vựng đã lưu trên máy. Đang kiểm tra ảnh local.',
      ),
      data: (_) => (
        Icons.phone_android_rounded,
        const Color(0xFF3F8F00),
        'Ảnh và từ vựng này được đọc từ bộ nhớ trên máy, không cần mạng.',
      ),
      error: (_, __) => mediaAsset.remoteDisplayPath == null
          ? (
              Icons.broken_image_outlined,
              const Color(0xFFB5483A),
              'Từ vựng đã lưu trên máy và vẫn xem offline. Ảnh local đang bị thiếu.',
            )
          : (
              Icons.cloud_outlined,
              const Color(0xFF2879A7),
              'Từ vựng đã lưu trên máy. Ảnh vẫn ở Cloud Backup và chỉ tải khi bạn chọn.',
            ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      SyncStatus.synced => (
          'Đã sao lưu',
          Icons.cloud_done_rounded,
          const Color(0xFF2879A7),
        ),
      SyncStatus.pending || SyncStatus.syncing => (
          'Đang sao lưu',
          Icons.cloud_upload_rounded,
          const Color(0xFFE07B00),
        ),
      SyncStatus.failedRetryable => (
          'Sẽ thử lại',
          Icons.cloud_sync_rounded,
          const Color(0xFFE07B00),
        ),
      SyncStatus.blockedAuth || SyncStatus.blockedContract => (
          'Chưa sao lưu',
          Icons.cloud_off_rounded,
          const Color(0xFFB5483A),
        ),
      SyncStatus.quarantined => (
          'Cần kiểm tra',
          Icons.warning_amber_rounded,
          const Color(0xFFB5483A),
        ),
      SyncStatus.localOnly => (
          'Chỉ trên máy',
          Icons.phone_android_rounded,
          const Color(0xFF786A61),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF9E8F85)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF786A61),
                  ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_formatDate(value)} lúc ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

void _invalidateLibraryProviders(WidgetRef ref, String photoNoteId) {
  ref.invalidate(libraryPhotoNotesProvider);
  ref.invalidate(libraryTrashPhotoNotesProvider);
  ref.invalidate(libraryStorageSummaryProvider);
  ref.invalidate(libraryPhotoNoteSnapshotProvider(photoNoteId));
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(1)} GB';
}

String _storageSecondarySummary(LibraryStorageSummary summary) {
  final parts = <String>[
    if (summary.cloudOnlyMediaCount > 0)
      '${summary.cloudOnlyMediaCount} trên cloud',
    if (summary.missingMediaCount > 0) '${summary.missingMediaCount} bị thiếu',
    '${summary.trashCount} trong rác',
  ];
  return parts.join('\n');
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
