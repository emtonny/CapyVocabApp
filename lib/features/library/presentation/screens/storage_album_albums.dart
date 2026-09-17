part of 'storage_album_screen.dart';

class _AlbumsView extends ConsumerWidget {
  const _AlbumsView({
    required this.onCreate,
    required this.onOpen,
    required this.selectedAlbumIds,
    required this.selecting,
    required this.busy,
    required this.onStartAlbumSelection,
    required this.onToggleAlbumSelection,
    required this.onCancelAlbumSelection,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onDeleteSelected,
  });

  final VoidCallback onCreate;
  final ValueChanged<Album> onOpen;
  final Set<String> selectedAlbumIds;
  final bool selecting;
  final bool busy;
  final VoidCallback onStartAlbumSelection;
  final ValueChanged<Album> onToggleAlbumSelection;
  final VoidCallback onCancelAlbumSelection;
  final ValueChanged<Album> onToggleFavorite;
  final ValueChanged<Album> onDelete;
  final ValueChanged<List<Album>> onDeleteSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(libraryAlbumsProvider);
    return albums.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: CircularProgressIndicator(
            key: Key('library-albums-loading'),
          ),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: _StateMessage(
          key: const Key('library-albums-error'),
          icon: Icons.folder_off_outlined,
          title: 'Không thể đọc Album',
          message: 'Album trên thiết bị chưa tải được. Hãy thử lại.',
          actionLabel: 'Thử lại',
          onAction: () => ref.invalidate(libraryAlbumsProvider),
        ),
      ),
      data: (items) {
        final selectedCount =
            items.where((album) => selectedAlbumIds.contains(album.id)).length;
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _AlbumToolbar(
                selecting: selecting,
                selectedCount: selectedCount,
                busy: busy,
                onCreate: onCreate,
                onStartSelection: onStartAlbumSelection,
                onCancelSelection: onCancelAlbumSelection,
                hasAlbums: items.isNotEmpty,
              ),
            ),
            items.isEmpty
                ? SliverToBoxAdapter(
                    child: _AlbumEmptyState(onCreate: onCreate),
                  )
                : SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final largeText = _usesLargeText(context);
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: SliverGrid(
                          key: const Key('library-album-grid'),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _albumGridColumnCount(
                              constraints.crossAxisExtent,
                              largeText: largeText,
                            ),
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 10,
                            mainAxisExtent:
                                (largeText ? 162 : 138) + (selecting ? 8 : 0),
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final album = items[index];
                              return _AlbumFolderCard(
                                album: album,
                                selectionMode: selecting,
                                selected: selectedAlbumIds.contains(album.id),
                                busy: busy,
                                onOpen: () => selecting
                                    ? onToggleAlbumSelection(album)
                                    : onOpen(album),
                                onToggleFavorite: () => onToggleFavorite(album),
                                onDelete: () => onDelete(album),
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      );
                    },
                  ),
            SliverToBoxAdapter(
              child: SizedBox(height: selecting ? 184 : 112),
            ),
          ],
        );
      },
    );
  }
}

class _AlbumToolbar extends StatelessWidget {
  const _AlbumToolbar({
    required this.selecting,
    required this.selectedCount,
    required this.busy,
    required this.onCreate,
    required this.onStartSelection,
    required this.onCancelSelection,
    this.hasAlbums = true,
  });

  final bool selecting;
  final int selectedCount;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onStartSelection;
  final VoidCallback onCancelSelection;
  final bool hasAlbums;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      selecting ? '$selectedCount Album đã chọn' : 'Danh sách Album của bạn',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.mutedInk,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAlbums) ...[
          _AlbumSelectionButton(
            selecting: selecting,
            onTap: busy
                ? null
                : selecting
                    ? onCancelSelection
                    : onStartSelection,
          ),
          const SizedBox(width: 8),
        ],
        _CreateAlbumButton(onTap: busy ? null : onCreate),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _CreateAlbumButton extends StatelessWidget {
  const _CreateAlbumButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: SizedBox.fromSize(
        size: _libraryToolbarButtonSize,
        child: StickerButton(
          key: const Key('library-create-album'),
          onPressed: onTap,
          surfaceColor: AppColors.duoOrange,
          textColor: Colors.white,
          text: '+ Tạo Album',
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          expand: true,
        ),
      ),
    );
  }
}

class _AlbumFolderCard extends ConsumerWidget {
  const _AlbumFolderCard({
    required this.album,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.selectionMode,
    required this.selected,
    required this.busy,
  });

  final Album album;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final bool selectionMode;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(libraryAlbumMembershipsProvider(album.id));
    final count =
        memberships.valueOrNull?.where((item) => item.isActive).length;

    return Semantics(
      button: true,
      label: selectionMode
          ? '${selected ? 'Bỏ chọn' : 'Chọn'} Album ${album.name}'
          : 'Mở Album ${album.name}',
      child: Container(
        key: Key('library-album-${album.id}'),
        decoration: selected
            ? BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.ink, width: 2.4),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              )
            : const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(14)),
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.ink, width: 2.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
        padding: selected ? const EdgeInsets.all(3.5) : EdgeInsets.zero,
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.ink, width: 1.6),
                )
              : null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(selected ? 9 : 14),
            child: InkWell(
              onTap: busy ? null : onOpen,
              borderRadius: BorderRadius.circular(selected ? 9 : 14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 2, 3, 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 48,
                      child: selectionMode
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: selected
                                    ? AppColors.coral
                                    : AppColors.mutedInk,
                                size: 22,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox.square(
                                  dimension: 48,
                                  child: StickerButton(
                                    key: Key(
                                      'library-album-favorite-${album.id}',
                                    ),
                                    semanticLabel: album.isFavorite
                                        ? 'Bỏ yêu thích ${album.name}'
                                        : 'Yêu thích ${album.name}',
                                    onPressed: busy ? null : onToggleFavorite,
                                    padding: EdgeInsets.zero,
                                    radius: 8,
                                    expand: true,
                                    flat: true,
                                    showShadow: false,
                                    borderColor: Colors.transparent,
                                    surfaceColor: Colors.transparent,
                                    icon: Icon(
                                      album.isFavorite
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      color: album.isFavorite
                                          ? const Color(0xFFFFB800)
                                          : AppColors.ink,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                SizedBox.square(
                                  dimension: 48,
                                  child: PopupMenuButton<_AlbumAction>(
                                    key: Key('library-album-menu-${album.id}'),
                                    tooltip: 'Tùy chọn Album ${album.name}',
                                    enabled: !busy,
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.more_horiz_rounded,
                                      color: AppColors.ink,
                                      size: 20,
                                    ),
                                    onSelected: (_) => onDelete(),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: _AlbumAction.delete,
                                        child: Text('Xóa Album'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7DC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.ink, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        album.icon,
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        album.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 10,
                            color: AppColors.mutedInk,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            count == null ? 'Đang đếm…' : '$count ảnh',
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AlbumAction { delete }

class _AlbumSelectionAction extends StatelessWidget {
  const _AlbumSelectionAction({
    required this.selectedCount,
    required this.busy,
    required this.onViewVocabulary,
    required this.onDelete,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback? onViewVocabulary;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('library-album-selection-action-bar'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: StickerButton(
              key: const Key('library-view-selected-album-vocabulary'),
              onPressed: busy ? null : onViewVocabulary,
              surfaceColor: const Color(0xFF52B21A),
              textColor: Colors.white,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.menu_book_rounded, size: 16),
              text: 'Xem từ vựng ($selectedCount Album)',
              fontSize: 12,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              expand: true,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: StickerButton(
              key: const Key('library-delete-selected-albums'),
              onPressed: busy ? null : onDelete,
              surfaceColor: Colors.white,
              textColor: AppColors.coral,
              edgeColor: const Color(0xFFE5B5B5),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.coral,
              ),
              text: 'Xóa Album',
              fontSize: 13,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              expand: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumEmptyState extends StatelessWidget {
  const _AlbumEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(
      key: const Key('library-albums-empty'),
      icon: Icons.create_new_folder_outlined,
      title: 'Chưa có Album nào',
      message: 'Tạo thư mục đầu tiên để gom các Photo Note theo chủ đề.',
      actionLabel: 'Tạo Album đầu tiên',
      onAction: onCreate,
    );
  }
}

class _CompactLibraryActionButton extends StatelessWidget {
  const _CompactLibraryActionButton({
    required this.actionKey,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    this.prefix,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      key: actionKey,
      size: _libraryToolbarButtonSize,
      child: StickerButton(
        onPressed: onTap,
        surfaceColor: backgroundColor,
        textColor: foregroundColor,
        icon: prefix != null
            ? Text(
                prefix!,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              )
            : null,
        text: label,
        fontSize: 12,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        expand: true,
      ),
    );
  }
}

class _AlbumDetailView extends ConsumerWidget {
  const _AlbumDetailView({
    required this.album,
    required this.onBack,
    required this.onAddPhotos,
    required this.onOpenPhotoNote,
    required this.onRemovePhoto,
  });

  final Album album;
  final VoidCallback onBack;
  final VoidCallback onAddPhotos;
  final ValueChanged<String> onOpenPhotoNote;
  final ValueChanged<PhotoNote> onRemovePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(libraryAlbumPhotoNotesProvider(album.id));
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Row(
              children: [
                _CompactLibraryActionButton(
                  actionKey: const Key('library-album-detail-back'),
                  onTap: onBack,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  prefix: '←',
                  label: 'Tất cả Album',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Container(
                      key: const Key('library-album-detail-title'),
                      width: double.infinity,
                      height: 60,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.ink, width: 2.2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              album.icon,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                album.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CompactLibraryActionButton(
                  actionKey: const Key('library-album-add-photos'),
                  onTap: onAddPhotos,
                  backgroundColor: AppColors.duoOrange,
                  foregroundColor: Colors.white,
                  label: '+ Thêm ảnh',
                ),
              ],
            ),
          ),
        ),
        notes.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => SliverToBoxAdapter(
            child: _StateMessage(
              icon: Icons.folder_off_outlined,
              title: 'Không thể mở Album',
              message: 'Danh sách ảnh trong Album chưa tải được.',
              actionLabel: 'Thử lại',
              onAction: () =>
                  ref.invalidate(libraryAlbumPhotoNotesProvider(album.id)),
            ),
          ),
          data: (items) => items.isEmpty
              ? SliverToBoxAdapter(
                  child: _StateMessage(
                    key: const Key('library-album-detail-empty'),
                    icon: Icons.photo_library_outlined,
                    title: 'Album đang trống',
                    message: 'Thêm Photo Note từ Thư viện vào Album này.',
                    actionLabel: 'Thêm ảnh',
                    onAction: onAddPhotos,
                  ),
                )
              : SliverMainAxisGroup(
                  slivers: [
                    SliverLayoutBuilder(
                      builder: (context, constraints) => SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: SliverGrid(
                          key: const Key('library-album-photo-list'),
                          gridDelegate: _photoNoteGridDelegate(
                            constraints.crossAxisExtent,
                            largeText: _usesLargeText(context),
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final note = items[index];
                              return _PhotoNoteCard(
                                note: note,
                                onTap: () => onOpenPhotoNote(note.id),
                                onRemoveFromAlbum: () => onRemovePhoto(note),
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 112)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AlbumAssignmentBanner extends StatelessWidget {
  const _AlbumAssignmentBanner({
    required this.album,
    required this.selectedCount,
    required this.onCancel,
  });

  final Album album;
  final int selectedCount;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('library-album-assignment-banner'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chọn ảnh cho ${album.icon} ${album.name} • $selectedCount đã chọn',
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          StickerButton(
            key: const Key('library-album-assignment-cancel'),
            onPressed: onCancel,
            semanticLabel: 'Hủy thêm ảnh',
            icon: const Icon(Icons.close_rounded, size: 18),
            padding: const EdgeInsets.all(7),
            radius: 10,
          ),
        ],
      ),
    );
  }
}

class _AlbumAssignmentAction extends StatelessWidget {
  const _AlbumAssignmentAction({
    required this.selectedCount,
    required this.busy,
    required this.onConfirm,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: StickerButton(
        key: const Key('library-album-assignment-confirm'),
        onPressed: busy ? null : onConfirm,
        surfaceColor: AppColors.lime,
        textColor: AppColors.ink,
        icon: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.drive_file_move_outline, size: 16),
        text: selectedCount == 0
            ? 'Chọn ít nhất 1 ảnh'
            : 'Thêm $selectedCount ảnh vào Album',
        fontSize: 14,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        expand: true,
      ),
    );
  }
}

typedef _NewAlbumDraft = ({String name, String icon});

class _CreateAlbumDialog extends StatefulWidget {
  const _CreateAlbumDialog();

  @override
  State<_CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<_CreateAlbumDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _gridScrollController = ScrollController();
  String _selectedCategory = 'Gợi ý';
  String _searchQuery = '';
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    _selectedIcon = '📁';
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _openEmojiPicker() async {
    final emoji = await EmojiPickerDialog.show(
      context,
      title: 'Kho Sticker Album',
      currentEmoji: _selectedIcon,
      controlKey: 'album-emoji-picker',
    );
    if (emoji != null && emoji.isNotEmpty && mounted) {
      setState(() {
        _selectedIcon = emoji;
      });
    }
  }

  String _normalize(String input) {
    var result = input.toLowerCase();
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  List<EmojiItem> _getFilteredEmojis() {
    if (_searchQuery.isNotEmpty) {
      final normalizedQuery = _normalize(_searchQuery);
      final seen = <String>{};
      final results = <EmojiItem>[];
      for (final item in kAllEmojis) {
        if (seen.contains(item.emoji)) continue;
        final normName = _normalize(item.name);
        final normKeywords = _normalize(item.keywords);
        if (normName.contains(normalizedQuery) ||
            normKeywords.contains(normalizedQuery) ||
            item.emoji == _searchQuery) {
          seen.add(item.emoji);
          results.add(item);
        }
      }
      return results;
    }

    if (_selectedCategory == 'Gợi ý') {
      final items =
          kAllEmojis.where((item) => item.category == 'Gợi ý').toList();
      if (!items.any((i) => i.emoji == _selectedIcon)) {
        items.insert(
          0,
          EmojiItem(
            emoji: _selectedIcon,
            name: 'Đã chọn',
            category: 'Gợi ý',
            keywords: '',
          ),
        );
      }
      return items;
    }

    return kAllEmojis
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredEmojis();

    return AlertDialog(
      key: const Key('library-create-album-dialog'),
      backgroundColor: AppColors.softWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.ink, width: 2.8),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.ink, width: 1.8),
            ),
            child: const Icon(
              Icons.create_new_folder_rounded,
              color: AppColors.ink,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tạo Album mới',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Kho sticker sắc màu theo chủ đề',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11.5,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(1.5, 1.5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              _selectedIcon,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('library-album-name-field'),
                controller: _nameController,
                autofocus: true,
                maxLength: 60,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Tên Album',
                  hintText: 'Ví dụ: Đồ ăn quanh mình',
                  labelStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedInk,
                  ),
                  hintStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    color: AppColors.mutedInk,
                  ),
                  counterText: '',
                  prefixIcon: const Icon(
                    Icons.drive_file_rename_outline_rounded,
                    size: 20,
                    color: AppColors.mutedInk,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 1.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2.2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn biểu tượng album',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  InkWell(
                    key: const Key('library-album-open-emoji-picker'),
                    onTap: _openEmojiPicker,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppColors.duoOrange,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Kho Sticker',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.mutedInk,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded,
                                size: 16, color: AppColors.mutedInk),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    hintText: 'Tìm kiếm: mèo, cờ vn, sách, tim, bơ, sao...',
                    hintStyle: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppColors.mutedInk,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_searchQuery.isEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          key: const Key('library-album-more-stickers-button'),
                          onTap: _openEmojiPicker,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.softWhite,
                              border:
                                  Border.all(color: AppColors.ink, width: 1.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    color: AppColors.ink, size: 14),
                                SizedBox(width: 2),
                                Text(
                                  'Thêm',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (final category in kEmojiCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            selectedColor: AppColors.lime,
                            backgroundColor: Colors.white,
                            checkmarkColor: AppColors.darkGreen,
                            labelStyle: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: _selectedCategory == category
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: _selectedCategory == category
                                  ? AppColors.darkGreen
                                  : AppColors.ink,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: AppColors.ink,
                                width: _selectedCategory == category ? 2 : 1.5,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategory = category);
                                if (_gridScrollController.hasClients) {
                                  _gridScrollController.jumpTo(0);
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔍', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(
                                'Không tìm thấy sticker nào cho "$_searchQuery"',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12.5,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          controller: _gridScrollController,
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: constraints.maxWidth < 232
                                ? 3
                                : constraints.maxWidth < 340
                                    ? 4
                                    : 5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            final isSelected = item.emoji == _selectedIcon;

                            return Tooltip(
                              message: item.name,
                              child: Material(
                                color: isSelected
                                    ? AppColors.yellow
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: AppColors.ink,
                                    width: isSelected ? 2.6 : 1.5,
                                  ),
                                ),
                                child: InkWell(
                                  key: Key('library-album-icon-${item.emoji}'),
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(
                                      () => _selectedIcon = item.emoji),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: isSelected
                                          ? const [
                                              BoxShadow(
                                                color: AppColors.ink,
                                                offset: Offset(1.5, 1.5),
                                                blurRadius: 0,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.emoji,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      actions: [
        StickerButton(
          onPressed: () => Navigator.of(context).pop(),
          text: 'Hủy',
          fontSize: 13,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        StickerButton(
          key: const Key('library-create-album-confirm'),
          onPressed: _submit,
          surfaceColor: AppColors.duoOrange,
          textColor: Colors.white,
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          text: 'Tạo Album',
          fontSize: 13,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, icon: _selectedIcon));
  }
}
