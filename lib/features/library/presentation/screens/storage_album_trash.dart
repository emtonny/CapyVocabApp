part of 'storage_album_screen.dart';

class LibraryTrashScreen extends ConsumerWidget {
  const LibraryTrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(libraryTrashPhotoNotesProvider);
    return GraphPaperScaffold(
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
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: Color(0xFFFFF3D6),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Bài trong thùng rác được giữ 30 ngày. Xóa vĩnh viễn có thể cần chờ đồng bộ cloud khi thiết bị có mạng.',
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          key: const Key('library-trash-list'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          gridDelegate:
                              _trashGridDelegate(constraints.maxWidth),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final note = items[index];
                            return _TrashPhotoNoteCard(
                              note: note,
                              onRestore: () =>
                                  _restorePhotoNote(context, ref, note),
                              onDelete: () =>
                                  _requestPermanentDelete(context, ref, note),
                            );
                          },
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

Future<void> _restorePhotoNote(
  BuildContext context,
  WidgetRef ref,
  PhotoNote note,
) async {
  final confirmed = await _showLibraryConfirmation(
    context: context,
    title: 'Khôi phục ảnh?',
    message: 'Bài và ảnh sẽ được khôi phục về danh sách Thư viện của bạn.',
    confirmLabel: 'Khôi phục',
    confirmKey: const Key('library-restore-confirm-action'),
    confirmColor: AppColors.duoGreen,
  );
  if (!confirmed || !context.mounted) return;

  try {
    final repository = await ref.read(libraryRepositoryProvider.future);
    await repository.restorePhotoNotes(
      userId: note.userId,
      photoNoteIds: [note.id],
      restoredAt: DateTime.now().toUtc(),
    );
    _invalidateLibraryProviders(ref, note.id);
    if (context.mounted) {
      showTopNotification(
        context,
        const SnackBar(content: Text('Đã khôi phục bài vào Thư viện.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      showTopNotification(
        context,
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
  final confirmed = await _showLibraryConfirmation(
    context: context,
    title: 'Yêu cầu xóa vĩnh viễn?',
    message:
        'Bài, ảnh và dữ liệu nguồn sẽ bị xóa khỏi thiết bị và không thể khôi phục. Nếu đã sao lưu, bản cloud cũng được đưa vào hàng chờ xóa kể cả khi Cloud Backup đang tắt.',
    confirmLabel: 'Xóa vĩnh viễn',
    confirmKey: const Key('library-permanent-delete-confirm-action'),
    confirmColor: _libraryDangerColor,
  );
  if (!confirmed || !context.mounted) return;

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
      showTopNotification(
        context,
        const SnackBar(
          content: Text(
            'Đã xóa khỏi thiết bị. Nếu có bản cloud, app sẽ tiếp tục xóa khi có mạng.',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      showTopNotification(
        context,
        const SnackBar(content: Text('Không thể tạo yêu cầu xóa.')),
      );
    }
  }
}

const _trashActionButtonSize = 48.0;

class _TrashPhotoNoteCard extends ConsumerWidget {
  const _TrashPhotoNoteCard({
    required this.note,
    required this.onRestore,
    required this.onDelete,
  });

  final PhotoNote note;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedAt = note.deletedAt!;
    final purgeAt = deletedAt.add(const Duration(days: 30));
    final daysLeft = purgeAt.difference(DateTime.now().toUtc()).inDays + 1;
    final snapshot = ref.watch(libraryPhotoNoteSnapshotProvider(note.id));
    return Container(
      key: Key('library-trash-note-${note.id}'),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(
                  color: const Color(0xFFF6F3EE),
                  child: snapshot.when(
                    loading: () => const _ImagePlaceholder(isLoading: true),
                    error: (_, __) => Center(
                      child: Text(
                        note.emoji ?? '📝',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    data: (value) => value == null
                        ? Center(
                            child: Text(
                              note.emoji ?? '📝',
                              style: const TextStyle(fontSize: 24),
                            ),
                          )
                        : _LocalLibraryImage(
                            mediaAsset: value.mediaAsset,
                            semanticLabel: 'Ảnh đã xóa ${note.title}',
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 12,
              child: Row(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      key: Key('library-trash-days-left-${note.id}'),
                      daysLeft > 0 ? 'Còn $daysLeft ngày' : 'Đã hết hạn',
                      style: const TextStyle(
                        color: Color(0xFFE55353),
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        key: Key('library-trash-deleted-at-${note.id}'),
                        'Đã xóa ${_formatDate(deletedAt)}',
                        style: const TextStyle(
                          color: Color(0xFF786A61),
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: _trashActionButtonSize,
                    child: StickerButton(
                      key: Key('library-trash-restore-${note.id}'),
                      onPressed: onRestore,
                      text: 'Khôi phục',
                      semanticLabel: 'Khôi phục',
                      surfaceColor: const Color(0xFFEAF9DF),
                      textColor: AppColors.ink,
                      edgeColor: const Color(0xFFB7DFA3),
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 13,
                        color: AppColors.ink,
                      ),
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      radius: 8,
                      flat: true,
                      expand: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: _trashActionButtonSize,
                    child: StickerButton(
                      key: Key('library-trash-delete-${note.id}'),
                      onPressed: onDelete,
                      text: 'Xóa vĩnh viễn',
                      semanticLabel: 'Xóa vĩnh viễn',
                      surfaceColor: const Color(0xFFFFECEB),
                      textColor: AppColors.ink,
                      edgeColor: const Color(0xFFE5B5B5),
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        size: 13,
                        color: AppColors.ink,
                      ),
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      radius: 8,
                      flat: true,
                      expand: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
