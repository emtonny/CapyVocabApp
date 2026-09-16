part of 'storage_album_screen.dart';

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
                child: StickerButton(
                  key: Key('library-quarantine-$path'),
                  onPressed: _busy ? null : () => _confirmQuarantine(path),
                  icon: const Icon(Icons.inventory_2_outlined, size: 14),
                  text: 'Cách ly',
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                    StickerButton(
                      key: Key('library-restore-${entry.relativePath}'),
                      onPressed:
                          _busy ? null : () => _restore(entry.relativePath),
                      surfaceColor: const Color(0xFFEAF9DF),
                      textColor: AppColors.duoGreen,
                      icon: const Icon(Icons.restore_rounded, size: 14),
                      text: 'Khôi phục',
                      fontSize: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    StickerButton(
                      key: Key('library-delete-${entry.relativePath}'),
                      onPressed: _busy
                          ? null
                          : () => _confirmDelete(entry.relativePath),
                      surfaceColor: const Color(0xFFFFEEF0),
                      textColor: const Color(0xFFB3261E),
                      icon: const Icon(Icons.delete_forever_outlined, size: 14),
                      text: 'Xóa ngay',
                      fontSize: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              StickerButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                text: 'Hủy',
                fontSize: 13,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              StickerButton(
                key: const Key('library-recovery-confirm-action'),
                onPressed: () => Navigator.pop(dialogContext, true),
                surfaceColor:
                    destructive ? const Color(0xFFE55353) : AppColors.duoGreen,
                textColor: Colors.white,
                text: actionLabel,
                fontSize: 13,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
      showTopNotification(
        context,
        SnackBar(content: Text(successMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      showTopNotification(
        context,
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

String _mediaFilename(String relativePath) =>
    relativePath.replaceAll('\\', '/').split('/').last;
