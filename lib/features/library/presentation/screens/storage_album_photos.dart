part of 'storage_album_screen.dart';

class _NeoDateFilterButton extends StatelessWidget {
  const _NeoDateFilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _libraryToolbarButtonSize,
      child: StickerButton(
        key: const Key('library-date-filter-button'),
        onPressed: onTap,
        icon: const Text('🗓️', style: TextStyle(fontSize: 12)),
        text: 'Lọc ngày',
        fontSize: 12,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        expand: true,
      ),
    );
  }
}

class _PhotoLibraryToolbar extends StatelessWidget {
  const _PhotoLibraryToolbar({
    required this.filteredCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onFilter,
  });

  final int filteredCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Tất cả ảnh ($filteredCount)',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.mutedInk,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NeoSelectAllButton(allSelected: allSelected, onTap: onSelectAll),
        const SizedBox(width: 8),
        _NeoDateFilterButton(onTap: onFilter),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
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

class _FilteredLibraryEmptyState extends StatelessWidget {
  const _FilteredLibraryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Không có ảnh trong khoảng ngày đã chọn.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedInk,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LibraryDateFilterDialog extends StatefulWidget {
  const _LibraryDateFilterDialog({required this.initial});

  final _LibraryDateFilter initial;

  @override
  State<_LibraryDateFilterDialog> createState() =>
      _LibraryDateFilterDialogState();
}

class _LibraryDateFilterDialogState extends State<_LibraryDateFilterDialog> {
  late _LibraryDatePreset _preset;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial.preset;
    final initialDate = widget.initial.date?.toLocal() ?? DateTime.now();
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('library-date-filter-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      backgroundColor: AppColors.softWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.ink, width: 2.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('🗓️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chọn Ngày Lọc Ảnh',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StickerButton(
                    key: const Key('library-date-filter-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    semanticLabel: 'Đóng',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: const EdgeInsets.all(7),
                    radius: 10,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final presetWidth =
                      constraints.maxWidth < 400 ? 108.0 : 122.0;
                  final presets = _buildPresetButtons(presetWidth);
                  final calendar = CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    onDateChanged: (value) {
                      setState(() {
                        _selectedDate = value;
                        _preset = _LibraryDatePreset.custom;
                      });
                    },
                  );
                  return SizedBox(
                    height: 275,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: presetWidth,
                          child: Column(
                            children: presets
                                .map(
                                  (button) => Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: button,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 275,
                          color: const Color(0xFFD8CFC6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: 300,
                                height: 300,
                                child: calendar,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StickerButton(
                      key: const Key('library-date-filter-clear'),
                      onPressed: () => Navigator.of(context).pop(
                        const _LibraryDateFilter.all(),
                      ),
                      text: 'Bỏ lọc',
                      fontSize: 13,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StickerButton(
                      key: const Key('library-date-filter-apply'),
                      onPressed: () => Navigator.of(context).pop(
                        _LibraryDateFilter(
                          _preset,
                          _preset == _LibraryDatePreset.custom
                              ? _selectedDate
                              : null,
                        ),
                      ),
                      surfaceColor: AppColors.duoGreen,
                      textColor: Colors.white,
                      text: 'Áp dụng 🎯',
                      fontSize: 13,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 16,
                      ),
                      expand: true,
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

  List<Widget> _buildPresetButtons(double width) {
    const presets = [
      (_LibraryDatePreset.all, 'Tất cả'),
      (_LibraryDatePreset.today, 'Hôm nay'),
      (_LibraryDatePreset.yesterday, 'Hôm qua'),
      (_LibraryDatePreset.last7Days, '7 ngày qua'),
      (_LibraryDatePreset.last30Days, '1 tháng qua'),
    ];
    return presets.map((item) {
      final selected = _preset == item.$1;
      return SizedBox(
        width: width,
        height: 48,
        child: StickerButton(
          key: Key('library-date-filter-${item.$1.name}'),
          onPressed: () => setState(() => _preset = item.$1),
          surfaceColor: selected ? AppColors.duoOrange : Colors.white,
          textColor: selected ? Colors.white : AppColors.ink,
          text: item.$2,
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          expand: true,
        ),
      );
    }).toList(growable: false);
  }
}

class _NeoSelectAllButton extends StatelessWidget {
  const _NeoSelectAllButton({
    required this.allSelected,
    required this.onTap,
  });

  final bool allSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _libraryToolbarButtonSize,
      child: StickerButton(
        key: const Key('library-select-all-photos-button'),
        label: allSelected ? 'Bỏ chọn' : 'Chọn tất cả',
        onPressed: onTap,
        expand: true,
      ),
    );
  }
}

class _PhotoSelectionAction extends StatelessWidget {
  const _PhotoSelectionAction({
    required this.selectedCount,
    required this.busy,
    required this.onViewVocabulary,
    required this.onAddToAlbum,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback? onViewVocabulary;
  final VoidCallback? onAddToAlbum;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('library-photo-selection-action-bar'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: StickerButton(
              key: const Key('library-view-selected-vocabulary'),
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
              text: 'Xem từ vựng ($selectedCount)',
              fontSize: 13,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              expand: true,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
            child: StickerButton(
              key: const Key('library-add-selected-photos-to-album'),
              onPressed: busy ? null : onAddToAlbum,
              surfaceColor: const Color(0xFFFF9800),
              textColor: Colors.white,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.folder_rounded, size: 16),
              text: 'Thêm vào Album',
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

class _CreateAlbumChoice {
  const _CreateAlbumChoice();
}

class _NeoActionCard extends StatefulWidget {
  const _NeoActionCard({
    super.key,
    required this.onTap,
    required this.surfaceColor,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final VoidCallback onTap;
  final Color surfaceColor;
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  State<_NeoActionCard> createState() => _NeoActionCardState();
}

class _NeoActionCardState extends State<_NeoActionCard> {
  bool _isPressed = false;

  void _handleTapDown() {
    if (mounted) setState(() => _isPressed = true);
  }

  void _handleTapUp() {
    if (mounted) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (mounted) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _handleTapDown(),
        onTapUp: (_) => _handleTapUp(),
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          transform: Matrix4.translationValues(0, _isPressed ? 2.5 : 0, 0),
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ink, width: 2.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(0, _isPressed ? 1.0 : 3.5),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.title,
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      widget.subtitle!,
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumPickerSheet extends StatelessWidget {
  const _AlbumPickerSheet({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.ink, width: 2.8),
          left: BorderSide(color: AppColors.ink, width: 2.8),
          right: BorderSide(color: AppColors.ink, width: 2.8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(0, -4),
            blurRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thêm ảnh vào Album',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Chọn Album để tiếp tục',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Đóng',
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.ink, width: 2.2),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.ink,
                                offset: Offset(0, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.ink,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _NeoActionCard(
                  key: const Key('library-create-album-from-selected-photos'),
                  onTap: () => Navigator.of(context).pop(
                    const _CreateAlbumChoice(),
                  ),
                  surfaceColor: AppColors.yellow,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: const Icon(
                      Icons.create_new_folder_outlined,
                      color: AppColors.ink,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Tạo Album mới',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  subtitle: const Text(
                    'Dùng các ảnh đang chọn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  trailing: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.ink,
                      size: 20,
                    ),
                  ),
                ),
                if (albums.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      itemCount: albums.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _NeoActionCard(
                          key: Key('library-select-album-${album.id}'),
                          onTap: () => Navigator.of(context).pop(album),
                          surfaceColor: Colors.white,
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.softWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.ink, width: 2),
                            ),
                            child: Text(
                              album.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          title: Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          trailing: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.softWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.ink, width: 2),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.ink,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({this.notes});

  final AsyncValue<List<PhotoNote>>? notes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Thư viện ảnh',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          const _OfflineBadge(),
        ],
      ),
    );
  }
}

class _AlbumSelectionButton extends StatelessWidget {
  const _AlbumSelectionButton({
    required this.selecting,
    required this.onTap,
  });

  final bool selecting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: SizedBox.fromSize(
        size: _libraryToolbarButtonSize,
        child: StickerButton(
          key: const Key('library-album-start-selection'),
          onPressed: onTap,
          text: selecting ? 'Bỏ chọn Album' : 'Chọn Album',
          fontSize: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          expand: true,
        ),
      ),
    );
  }
}

class _LibrarySubviewSwitcher extends StatelessWidget {
  const _LibrarySubviewSwitcher({
    required this.selected,
    required this.onSelected,
  });

  final _LibrarySubview selected;
  final ValueChanged<_LibrarySubview> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        key: const Key('library-subview-switcher'),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.ink, width: 2.2),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _SubviewButton(
                key: const Key('library-photos-tab'),
                emoji: '🖼️',
                icon: Icons.photo_library_outlined,
                label: 'Ảnh',
                selected: selected == _LibrarySubview.photos,
                onTap: () => onSelected(_LibrarySubview.photos),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SubviewButton(
                key: const Key('library-albums-tab'),
                emoji: '📁',
                icon: Icons.folder_copy_outlined,
                label: 'Album',
                selected: selected == _LibrarySubview.albums,
                onTap: () => onSelected(_LibrarySubview.albums),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _SubviewButton(
                key: const Key('library-trash-tab'),
                emoji: '🗑️',
                icon: Icons.delete_outline_rounded,
                label: 'Ảnh đã xóa',
                selected: selected == _LibrarySubview.trash,
                onTap: () => onSelected(_LibrarySubview.trash),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubviewButton extends StatelessWidget {
  const _SubviewButton({
    required this.emoji,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String emoji;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
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
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            selected ? AppColors.ink : const Color(0xFFA09C96),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AppColors.ink
                              : const Color(0xFFA09C96),
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 12,
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
      ),
    );
  }
}
