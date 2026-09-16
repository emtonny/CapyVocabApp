import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/gemini_vision_service.dart' as scan_model;
import '../../../../core/utils/random_uuid.dart';
import '../../../../shared/navigation/bottom_nav_bar.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../../../../shared/widgets/top_notification.dart';
import '../../domain/entities/album_models.dart';
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
import '../../../ai_scan/presentation/widgets/emoji_picker_dialog.dart';
import '../../../ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
part 'storage_album_photos.dart';
part 'storage_album_albums.dart';
part 'storage_album_recovery.dart';
part 'storage_album_trash.dart';
part 'storage_album_detail.dart';

/// Offline-first Library for saved scan aggregates and personal Albums.
class StorageAlbumScreen extends ConsumerStatefulWidget {
  const StorageAlbumScreen({this.onOpenPhotoNote, super.key});

  final ValueChanged<String>? onOpenPhotoNote;

  @override
  ConsumerState<StorageAlbumScreen> createState() => _StorageAlbumScreenState();
}

/// Shows the selected Photo Notes in selection order and reveals each note's
/// vocabulary only after its image is tapped.
class SelectedPhotoVocabularyScreen extends ConsumerStatefulWidget {
  const SelectedPhotoVocabularyScreen({required this.notes, super.key});

  final List<PhotoNote> notes;

  @override
  ConsumerState<SelectedPhotoVocabularyScreen> createState() =>
      _SelectedPhotoVocabularyScreenState();
}

class _SelectedPhotoVocabularyScreenState
    extends ConsumerState<SelectedPhotoVocabularyScreen> {
  final Set<String> _expandedPhotoNoteIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return GraphPaperScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _SelectedPhotoVocabularyHeader(count: widget.notes.length),
            Expanded(
              child: widget.notes.isEmpty
                  ? const _StateMessage(
                      key: Key('library-selected-vocabulary-empty'),
                      icon: Icons.menu_book_outlined,
                      title: 'Chưa có ảnh được chọn',
                      message: 'Quay lại Thư viện và chọn ít nhất một ảnh.',
                    )
                  : ListView.separated(
                      key: const Key('library-selected-vocabulary-list'),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: widget.notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final note = widget.notes[index];
                        return _SelectedPhotoVocabularyCard(
                          key: Key(
                              'library-selected-vocabulary-card-${note.id}'),
                          note: note,
                          position: index + 1,
                          total: widget.notes.length,
                          expanded: _expandedPhotoNoteIds.contains(note.id),
                          onToggle: () => _toggleExpanded(note.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleExpanded(String photoNoteId) {
    setState(() {
      if (!_expandedPhotoNoteIds.add(photoNoteId)) {
        _expandedPhotoNoteIds.remove(photoNoteId);
      }
    });
  }
}

class _SelectedPhotoVocabularyHeader extends StatelessWidget {
  const _SelectedPhotoVocabularyHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Xem từ vựng ($count ảnh)',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Container(
          key: const Key('library-selected-vocabulary-header'),
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: StickerButton(
                      key: const Key('library-selected-vocabulary-back'),
                      semanticLabel: 'Quay lại Thư viện',
                      icon: const Icon(Icons.arrow_back_rounded, size: 22),
                      surfaceColor: Colors.white,
                      padding: const EdgeInsets.all(10),
                      radius: 10,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/storage');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Xem từ vựng ($count)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontFamily: 'Fredoka',
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.ink, width: 1.8),
                    ),
                    child: Text(
                      '$count ảnh',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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
}

enum _LibrarySubview { photos, albums, trash }

enum _LibraryDatePreset { all, today, yesterday, last7Days, last30Days, custom }

class _LibraryDateFilter {
  const _LibraryDateFilter(this.preset, [this.date]);

  const _LibraryDateFilter.all()
      : preset = _LibraryDatePreset.all,
        date = null;

  final _LibraryDatePreset preset;
  final DateTime? date;

  bool get isActive => preset != _LibraryDatePreset.all;
}

List<PhotoNote> _filterNotesByDate(
  List<PhotoNote> notes,
  _LibraryDateFilter filter,
  DateTime? Function(PhotoNote note) dateOf,
) {
  if (!filter.isActive) return notes;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  bool isSameDay(DateTime value, DateTime day) {
    final local = value.toLocal();
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  return notes.where((note) {
    final value = dateOf(note);
    if (value == null) return false;
    final local = value.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return switch (filter.preset) {
      _LibraryDatePreset.all => true,
      _LibraryDatePreset.today => isSameDay(local, today),
      _LibraryDatePreset.yesterday =>
        isSameDay(local, today.subtract(const Duration(days: 1))),
      _LibraryDatePreset.last7Days =>
        !day.isBefore(today.subtract(const Duration(days: 6))) &&
            !day.isAfter(today),
      _LibraryDatePreset.last30Days =>
        !day.isBefore(today.subtract(const Duration(days: 29))) &&
            !day.isAfter(today),
      _LibraryDatePreset.custom =>
        filter.date != null && isSameDay(local, filter.date!),
    };
  }).toList(growable: false);
}

class _StorageAlbumScreenState extends ConsumerState<StorageAlbumScreen> {
  _LibrarySubview _subview = _LibrarySubview.photos;
  Album? _openedAlbum;
  Album? _assignmentTarget;
  final Set<String> _selectedForAssignment = {};
  final Set<String> _selectedAlbumIds = {};
  final List<String> _selectedPhotoIds = [];
  bool _selectingAlbums = false;
  bool _selectingPhotos = false;
  bool _albumActionBusy = false;
  _LibraryDateFilter _photoDateFilter = const _LibraryDateFilter.all();
  _LibraryDateFilter _trashDateFilter = const _LibraryDateFilter.all();

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(libraryPhotoNotesProvider);
    final mediaRecovery = ref.watch(libraryMediaRecoverySnapshotProvider);
    final openedAlbum = _openedAlbum;

    return GraphPaperScaffold(
      extendBody: false,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshLibrary,
          child: CustomScrollView(
            key: const Key('library-page-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (openedAlbum == null)
                SliverToBoxAdapter(child: _LibraryHeader(notes: notes)),
              if (openedAlbum == null)
                SliverToBoxAdapter(
                  child: _LibrarySubviewSwitcher(
                    selected: _subview,
                    onSelected: _switchSubview,
                  ),
                ),
              if (openedAlbum == null &&
                  _subview == _LibrarySubview.photos) ...[
                const SliverToBoxAdapter(
                  child: Offstage(
                    child: _LibraryStorageSummaryCard(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MediaRecoveryBanner(
                    recovery: mediaRecovery,
                    onOpen: (snapshot) =>
                        _showMediaRecoverySheet(context, snapshot),
                  ),
                ),
              ],
              openedAlbum != null
                  ? _AlbumDetailView(
                      album: openedAlbum,
                      onBack: () => setState(() => _openedAlbum = null),
                      onAddPhotos: () => _startAssigningPhotos(openedAlbum),
                      onOpenPhotoNote: _openPhotoNote,
                      onRemovePhoto: (note) =>
                          _removePhotoFromAlbum(openedAlbum, note),
                    )
                  : _subview == _LibrarySubview.albums
                      ? _AlbumsView(
                          onCreate: _createAlbum,
                          onOpen: (album) =>
                              setState(() => _openedAlbum = album),
                          selectedAlbumIds: _selectedAlbumIds,
                          selecting: _selectingAlbums,
                          busy: _albumActionBusy,
                          onStartAlbumSelection: _startAlbumSelection,
                          onToggleAlbumSelection: _toggleAlbumSelection,
                          onCancelAlbumSelection: _cancelAlbumSelection,
                          onToggleFavorite: _toggleFavorite,
                          onDelete: _deleteAlbum,
                          onDeleteSelected: _deleteSelectedAlbums,
                        )
                      : _subview == _LibrarySubview.trash
                          ? _buildTrash()
                          : _buildPhotos(notes),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(notes),
    );
  }

  Future<void> _refreshLibrary() async {
    final openedAlbum = _openedAlbum;
    if (openedAlbum != null) {
      final provider = libraryAlbumPhotoNotesProvider(openedAlbum.id);
      ref.invalidate(provider);
      await ref.read(provider.future);
      return;
    }

    switch (_subview) {
      case _LibrarySubview.photos:
        ref.invalidate(libraryPhotoNotesProvider);
        await ref.read(libraryPhotoNotesProvider.future);
      case _LibrarySubview.albums:
        ref.invalidate(libraryAlbumsProvider);
        await ref.read(libraryAlbumsProvider.future);
      case _LibrarySubview.trash:
        ref.invalidate(libraryTrashPhotoNotesProvider);
        await ref.read(libraryTrashPhotoNotesProvider.future);
    }
  }

  Widget _buildBottomNavigation(AsyncValue<List<PhotoNote>> notes) {
    final showPhotoActions =
        _openedAlbum == null && _subview == _LibrarySubview.photos;
    final showAlbumActions =
        _openedAlbum == null && _subview == _LibrarySubview.albums;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPhotoActions && _assignmentTarget != null)
          _AlbumAssignmentAction(
            selectedCount: _selectedForAssignment.length,
            busy: _albumActionBusy,
            onConfirm:
                _selectedForAssignment.isEmpty ? null : _confirmPhotoAssignment,
          )
        else if (showPhotoActions && _selectingPhotos)
          _PhotoSelectionAction(
            selectedCount: _selectedPhotoIds.length,
            busy: _albumActionBusy,
            onViewVocabulary: _selectedPhotoIds.isEmpty
                ? null
                : () => _openSelectedPhotoVocabulary(
                      notes.valueOrNull ?? const [],
                    ),
            onAddToAlbum: _selectedPhotoIds.isEmpty
                ? null
                : _chooseAlbumForSelectedPhotos,
          )
        else if (showAlbumActions && _selectingAlbums)
          _AlbumSelectionAction(
            selectedCount: _selectedAlbumIds.length,
            busy: _albumActionBusy,
            onViewVocabulary: _selectedAlbumIds.isEmpty
                ? null
                : () => _openSelectedAlbumVocabulary(
                      ref.read(libraryAlbumsProvider).valueOrNull ?? const [],
                    ),
            onDelete: _selectedAlbumIds.isEmpty
                ? null
                : () => _deleteSelectedAlbums(
                      ref
                              .read(libraryAlbumsProvider)
                              .valueOrNull
                              ?.where((album) =>
                                  _selectedAlbumIds.contains(album.id))
                              .toList(growable: false) ??
                          const [],
                    ),
          ),
        const BottomNavBar(),
      ],
    );
  }

  Widget _buildPhotos(AsyncValue<List<PhotoNote>> notes) {
    final assignmentTarget = _assignmentTarget;
    return SliverMainAxisGroup(
      slivers: [
        if (assignmentTarget != null)
          SliverToBoxAdapter(
            child: _AlbumAssignmentBanner(
              album: assignmentTarget,
              selectedCount: _selectedForAssignment.length,
              onCancel: _cancelAssignment,
            ),
          ),
        notes.when(
          loading: () => const SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: Center(
                child: CircularProgressIndicator(
                  key: Key('library-loading-indicator'),
                ),
              ),
            ),
          ),
          error: (error, stackTrace) => SliverToBoxAdapter(
            child: _StateMessage(
              key: const Key('library-error-state'),
              icon: Icons.storage_rounded,
              title: 'Không thể đọc thư viện',
              message: 'Dữ liệu trên máy chưa tải được. Hãy thử lại.',
              actionLabel: 'Thử lại',
              onAction: () => ref.invalidate(libraryPhotoNotesProvider),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: _StateMessage(
                  key: const Key('library-empty-state'),
                  icon: Icons.photo_library_outlined,
                  title: 'Chưa có bài quét nào',
                  message:
                      'Quét một bức ảnh; kết quả sẽ tự lưu để bạn xem lại khi không có mạng.',
                  actionLabel: 'Quét ảnh đầu tiên',
                  onAction: () => context.push('/scan'),
                ),
              );
            }
            final filteredItems = _filterNotesByDate(
              items,
              _photoDateFilter,
              (note) => note.createdAt,
            );
            final bottomPadding = assignmentTarget != null
                ? 184.0
                : (_selectingPhotos ? 194.0 : 112.0);
            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _PhotoLibraryToolbar(
                    filteredCount: filteredItems.length,
                    allSelected: filteredItems.isNotEmpty &&
                        (assignmentTarget != null
                            ? filteredItems.every(
                                (note) =>
                                    _selectedForAssignment.contains(note.id),
                              )
                            : (_selectingPhotos &&
                                filteredItems.every(
                                  (note) => _selectedPhotoIds.contains(note.id),
                                ))),
                    onSelectAll: () => assignmentTarget != null
                        ? _toggleSelectAllForAssignment(filteredItems)
                        : _toggleSelectAllPhotos(filteredItems),
                    onFilter: _showPhotoDateFilter,
                  ),
                ),
                filteredItems.isEmpty
                    ? const SliverToBoxAdapter(
                        child: _FilteredLibraryEmptyState(),
                      )
                    : SliverLayoutBuilder(
                        builder: (context, constraints) => SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                          sliver: SliverGrid(
                            key: const Key('library-photo-note-list'),
                            gridDelegate: _photoNoteGridDelegate(
                              constraints.crossAxisExtent,
                              largeText: _usesLargeText(context),
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final note = filteredItems[index];
                                return _PhotoNoteCard(
                                  note: note,
                                  selectionMode: assignmentTarget != null ||
                                      _selectingPhotos,
                                  selected: assignmentTarget != null
                                      ? _selectedForAssignment.contains(note.id)
                                      : _selectedPhotoIds.contains(note.id),
                                  onMoveToTrash: () =>
                                      _movePhotoNoteToTrash(context, note),
                                  onTap: () {
                                    if (assignmentTarget != null) {
                                      _togglePhotoForAssignment(note.id);
                                    } else if (_selectingPhotos) {
                                      _togglePhotoSelection(note.id);
                                    } else {
                                      _startPhotoSelection(note.id);
                                    }
                                  },
                                );
                              },
                              childCount: filteredItems.length,
                            ),
                          ),
                        ),
                      ),
                SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrash() {
    final trashNotes = ref.watch(libraryTrashPhotoNotesProvider);
    final filteredTrashCount = trashNotes.valueOrNull == null
        ? 0
        : _filterNotesByDate(
            trashNotes.valueOrNull!,
            _trashDateFilter,
            (note) => note.deletedAt,
          ).length;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ảnh đã xóa ($filteredTrashCount)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _NeoDateFilterButton(onTap: _showTrashDateFilter),
              ],
            ),
          ),
        ),
        trashNotes.when(
          loading: () => const SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => SliverToBoxAdapter(
            child: _StateMessage(
              key: const Key('library-trash-error'),
              icon: Icons.delete_outline_rounded,
              title: 'Không thể đọc thùng rác',
              message: 'Dữ liệu local chưa đọc được. Hãy thử lại.',
              actionLabel: 'Thử lại',
              onAction: () => ref.invalidate(libraryTrashPhotoNotesProvider),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'Chưa có ảnh nào trong Thùng rác 🧹',
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
            final filteredItems = _filterNotesByDate(
              items,
              _trashDateFilter,
              (note) => note.deletedAt,
            );
            if (filteredItems.isEmpty) {
              return const SliverToBoxAdapter(
                child: _FilteredLibraryEmptyState(),
              );
            }
            return SliverMainAxisGroup(
              slivers: [
                SliverLayoutBuilder(
                  builder: (context, constraints) => SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverGrid(
                      key: const Key('library-trash-list'),
                      gridDelegate:
                          _trashGridDelegate(constraints.crossAxisExtent),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = filteredItems[index];
                          return _TrashPhotoNoteCard(
                            note: note,
                            onRestore: () =>
                                _restorePhotoNote(context, ref, note),
                            onDelete: () =>
                                _requestPermanentDelete(context, ref, note),
                          );
                        },
                        childCount: filteredItems.length,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 112)),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showPhotoDateFilter() async {
    final result = await showDialog<_LibraryDateFilter>(
      context: context,
      builder: (_) => _LibraryDateFilterDialog(initial: _photoDateFilter),
    );
    if (result != null && mounted) {
      setState(() => _photoDateFilter = result);
    }
  }

  Future<void> _showTrashDateFilter() async {
    final result = await showDialog<_LibraryDateFilter>(
      context: context,
      builder: (_) => _LibraryDateFilterDialog(initial: _trashDateFilter),
    );
    if (result != null && mounted) {
      setState(() => _trashDateFilter = result);
    }
  }

  void _switchSubview(_LibrarySubview value) {
    setState(() {
      _subview = value;
      _assignmentTarget = null;
      _selectedForAssignment.clear();
      _selectedAlbumIds.clear();
      _selectingAlbums = false;
      _selectedPhotoIds.clear();
      _selectingPhotos = false;
    });
  }

  void _startAlbumSelection() {
    if (_albumActionBusy) return;
    setState(() => _selectingAlbums = true);
  }

  void _toggleAlbumSelection(Album album) {
    if (_albumActionBusy) return;
    setState(() {
      if (!_selectedAlbumIds.add(album.id)) {
        _selectedAlbumIds.remove(album.id);
      }
    });
  }

  void _cancelAlbumSelection() {
    if (_albumActionBusy) return;
    setState(() {
      _selectedAlbumIds.clear();
      _selectingAlbums = false;
    });
  }

  void _toggleSelectAllForAssignment(List<PhotoNote> items) {
    if (_albumActionBusy) return;
    setState(() {
      final allIds = items.map((e) => e.id).toSet();
      if (allIds.isNotEmpty && _selectedForAssignment.containsAll(allIds)) {
        _selectedForAssignment.clear();
      } else {
        _selectedForAssignment
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  void _toggleSelectAllPhotos(List<PhotoNote> items) {
    if (_albumActionBusy) return;
    setState(() {
      final allIds = items.map((e) => e.id).toList(growable: false);
      final allSelected = allIds.isNotEmpty &&
          _selectedPhotoIds.length == allIds.length &&
          _selectedPhotoIds.toSet().containsAll(allIds);
      if (allSelected) {
        _selectedPhotoIds.clear();
        _selectingPhotos = false;
      } else {
        _selectingPhotos = true;
        _selectedPhotoIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  void _startPhotoSelection(String noteId) {
    if (_albumActionBusy) return;
    setState(() {
      _selectingPhotos = true;
      _selectedPhotoIds.add(noteId);
    });
  }

  void _togglePhotoSelection(String noteId) {
    if (_albumActionBusy) return;
    setState(() {
      final index = _selectedPhotoIds.indexOf(noteId);
      if (index == -1) {
        _selectedPhotoIds.add(noteId);
      } else {
        _selectedPhotoIds.removeAt(index);
        if (_selectedPhotoIds.isEmpty) {
          _selectingPhotos = false;
        }
      }
    });
  }

  void _cancelPhotoSelection() {
    if (_albumActionBusy) return;
    setState(() {
      _selectedPhotoIds.clear();
      _selectingPhotos = false;
    });
  }

  void _openSelectedPhotoVocabulary(List<PhotoNote> items) {
    final notesById = <String, PhotoNote>{
      for (final note in items) note.id: note,
    };
    final selectedNotes = _selectedPhotoIds
        .map((noteId) => notesById[noteId])
        .whereType<PhotoNote>()
        .toList(growable: false);
    if (selectedNotes.isEmpty) return;

    _cancelPhotoSelection();
    context.push('/storage/vocabulary', extra: selectedNotes);
  }

  Future<void> _openSelectedAlbumVocabulary(List<Album> albums) async {
    if (_albumActionBusy || _selectedAlbumIds.isEmpty) return;
    final selectedAlbums = albums
        .where((album) => _selectedAlbumIds.contains(album.id))
        .toList(growable: false);
    if (selectedAlbums.isEmpty) return;

    setState(() => _albumActionBusy = true);
    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      final notesByAlbum = await Future.wait(
        selectedAlbums.map(
          (album) => repository
              .watchPhotoNotes(
                PhotoNoteQuery(
                  userId: album.userId,
                  albumId: album.id,
                  limit: 500,
                ),
              )
              .first,
        ),
      );
      final seenPhotoNoteIds = <String>{};
      final selectedNotes = notesByAlbum
          .expand((notes) => notes)
          .where((note) => seenPhotoNoteIds.add(note.id))
          .toList(growable: false);
      if (!mounted) return;
      if (selectedNotes.isEmpty) {
        showTopNotification(
          context,
          const SnackBar(
            content: Text('Các Album đã chọn chưa có ảnh để xem từ vựng.'),
          ),
        );
        return;
      }

      setState(() {
        _selectedAlbumIds.clear();
        _selectingAlbums = false;
        _albumActionBusy = false;
      });
      context.push('/storage/vocabulary', extra: selectedNotes);
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(
            content: Text('Không thể mở từ vựng của các Album đã chọn.'),
          ),
        );
      }
    } finally {
      if (mounted && _albumActionBusy) {
        setState(() => _albumActionBusy = false);
      }
    }
  }

  Future<void> _chooseAlbumForSelectedPhotos() async {
    if (_albumActionBusy || _selectedPhotoIds.isEmpty) return;

    setState(() => _albumActionBusy = true);
    try {
      final albums = await ref.read(libraryAlbumsProvider.future);
      if (!mounted) return;
      setState(() => _albumActionBusy = false);

      final selection = await showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _AlbumPickerSheet(albums: albums),
      );
      if (!mounted || selection == null) return;

      if (selection is _CreateAlbumChoice) {
        await _createAlbum(
          selectedPhotoNoteIds: List<String>.of(_selectedPhotoIds),
        );
        return;
      }
      if (selection is! Album) return;
      final selectedAlbum = selection;

      setState(() {
        _assignmentTarget = selectedAlbum;
        _selectedForAssignment
          ..clear()
          ..addAll(_selectedPhotoIds);
        _selectedPhotoIds.clear();
        _selectingPhotos = false;
      });
      await _confirmPhotoAssignment();
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(content: Text('Không thể đọc danh sách Album.')),
        );
      }
    } finally {
      if (mounted && _albumActionBusy) {
        setState(() => _albumActionBusy = false);
      }
    }
  }

  void _openPhotoNote(String noteId) {
    final callback = widget.onOpenPhotoNote;
    if (callback != null) {
      callback(noteId);
    } else {
      context.push('/storage/$noteId');
    }
  }

  void _startAssigningPhotos(Album album) {
    setState(() {
      _openedAlbum = null;
      _subview = _LibrarySubview.photos;
      _assignmentTarget = album;
      _selectedForAssignment.clear();
    });
  }

  void _cancelAssignment() {
    final album = _assignmentTarget;
    setState(() {
      _assignmentTarget = null;
      _selectedForAssignment.clear();
      _subview = _LibrarySubview.albums;
      _openedAlbum = album;
    });
  }

  void _togglePhotoForAssignment(String noteId) {
    setState(() {
      if (!_selectedForAssignment.add(noteId)) {
        _selectedForAssignment.remove(noteId);
      }
    });
  }

  Future<void> _confirmPhotoAssignment() async {
    final album = _assignmentTarget;
    if (_albumActionBusy || album == null || _selectedForAssignment.isEmpty) {
      return;
    }
    setState(() => _albumActionBusy = true);
    try {
      final repository = await ref.read(albumRepositoryProvider.future);
      await repository.addPhotoNotes(
        userId: album.userId,
        albumId: album.id,
        photoNoteIds: _selectedForAssignment,
        addedAt: DateTime.now().toUtc(),
        operationId: createRandomUuidV4(),
      );
      if (!mounted) return;
      final count = _selectedForAssignment.length;
      setState(() {
        _albumActionBusy = false;
        _assignmentTarget = null;
        _selectedForAssignment.clear();
        _subview = _LibrarySubview.albums;
        _openedAlbum = album;
      });
      showTopNotification(
        context,
        SnackBar(content: Text('Đã thêm $count ảnh vào ${album.name}.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _albumActionBusy = false);
      showTopNotification(
        context,
        const SnackBar(content: Text('Không thể thêm ảnh vào Album.')),
      );
    }
  }

  Future<void> _createAlbum({
    Iterable<String> selectedPhotoNoteIds = const <String>[],
  }) async {
    final draft = await showDialog<_NewAlbumDraft>(
      context: context,
      builder: (_) => const _CreateAlbumDialog(),
    );
    final userId = ref.read(currentLibraryUserIdProvider);
    if (draft == null || userId == null || !mounted) return;
    if (_albumActionBusy) return;
    final selectedIds = selectedPhotoNoteIds.toList(growable: false);
    setState(() => _albumActionBusy = true);
    try {
      final repository = await ref.read(albumRepositoryProvider.future);
      final now = DateTime.now().toUtc();
      final album = Album(
        id: createRandomUuidV4(),
        userId: userId,
        name: draft.name,
        icon: draft.icon,
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.localOnly,
      );
      if (selectedIds.isEmpty) {
        await repository.saveAlbum(album);
      } else {
        await repository.createAlbumWithPhotoNotes(
          album: album,
          photoNoteIds: selectedIds,
          addedAt: now,
          operationId: createRandomUuidV4(),
        );
      }
      if (mounted) {
        setState(() {
          _albumActionBusy = false;
          if (selectedIds.isNotEmpty) {
            _selectedPhotoIds.clear();
            _selectingPhotos = false;
            _subview = _LibrarySubview.albums;
            _openedAlbum = album;
          }
        });
        showTopNotification(
          context,
          SnackBar(
            content: Text(
              selectedIds.isEmpty
                  ? 'Đã tạo Album “${draft.name}”.'
                  : 'Đã tạo Album “${draft.name}” và thêm '
                      '${selectedIds.length} ảnh.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _albumActionBusy = false);
        showTopNotification(
          context,
          const SnackBar(content: Text('Không thể tạo Album.')),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Album album) async {
    if (_albumActionBusy) return;
    setState(() => _albumActionBusy = true);
    try {
      final repository = await ref.read(albumRepositoryProvider.future);
      await repository.setFavorite(
        userId: album.userId,
        albumId: album.id,
        isFavorite: !album.isFavorite,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(content: Text('Không thể cập nhật Album yêu thích.')),
        );
      }
    } finally {
      if (mounted) setState(() => _albumActionBusy = false);
    }
  }

  Future<void> _deleteAlbum(Album album) async {
    await _deleteAlbums([album]);
  }

  Future<void> _deleteSelectedAlbums(List<Album> albums) async {
    final selected = albums
        .where((album) => _selectedAlbumIds.contains(album.id))
        .toList(growable: false);
    await _deleteAlbums(selected);
  }

  Future<void> _deleteAlbums(List<Album> albums) async {
    if (_albumActionBusy || albums.isEmpty) return;
    final albumLabel = albums.length == 1
        ? 'Album “${albums.single.name}”'
        : '${albums.length} Album đã chọn';
    final confirmed = await _showLibraryConfirmation(
      context: context,
      title: 'Xóa $albumLabel?',
      message:
          'Album sẽ bị xóa nhưng các Photo Note bên trong vẫn được giữ trong Thư viện.',
      confirmLabel: 'Xóa Album',
      confirmKey: const Key('library-delete-album-confirm'),
      confirmColor: _libraryDangerColor,
    );
    if (!confirmed || !mounted) return;
    setState(() => _albumActionBusy = true);
    try {
      final repository = await ref.read(albumRepositoryProvider.future);
      await repository.deleteAlbums(
        userId: albums.first.userId,
        albumIds: albums.map((album) => album.id),
        deletedAt: DateTime.now().toUtc(),
      );
      if (mounted) {
        setState(() {
          _selectedAlbumIds.clear();
          _selectingAlbums = false;
        });
        showTopNotification(
          context,
          SnackBar(content: Text('Đã xóa $albumLabel.')),
        );
      }
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(content: Text('Không thể xóa Album.')),
        );
      }
    } finally {
      if (mounted) setState(() => _albumActionBusy = false);
    }
  }

  Future<void> _removePhotoFromAlbum(Album album, PhotoNote note) async {
    if (_albumActionBusy) return;
    setState(() => _albumActionBusy = true);
    try {
      final repository = await ref.read(albumRepositoryProvider.future);
      await repository.removePhotoNotes(
        userId: album.userId,
        albumId: album.id,
        photoNoteIds: [note.id],
        removedAt: DateTime.now().toUtc(),
        operationId: createRandomUuidV4(),
      );
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(
            content: Text('Đã gỡ ảnh khỏi Album; ảnh vẫn còn trong Thư viện.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
          const SnackBar(content: Text('Không thể gỡ ảnh khỏi Album.')),
        );
      }
    } finally {
      if (mounted) setState(() => _albumActionBusy = false);
    }
  }

  Future<void> _movePhotoNoteToTrash(
    BuildContext context,
    PhotoNote note,
  ) async {
    final confirmed = await _showLibraryConfirmation(
      context: context,
      title: 'Chuyển bài vào thùng rác?',
      message:
          'Bài sẽ không còn trong Thư viện chính. Bạn có thể khôi phục trong 30 ngày trước khi yêu cầu xóa vĩnh viễn.',
      confirmLabel: 'Xác nhận',
      confirmKey: const Key('library-trash-confirm-action'),
      confirmColor: _libraryDangerColor,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      await repository.movePhotoNotesToTrash(
        userId: note.userId,
        photoNoteIds: [note.id],
        deletedAt: DateTime.now().toUtc(),
      );
      _invalidateLibraryProviders(ref, note.id);
      if (context.mounted) {
        showTopNotification(
          context,
          const SnackBar(content: Text('Đã chuyển bài vào thùng rác.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showTopNotification(
          context,
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

const _libraryToolbarButtonSize = Size(120, 48);
const _libraryDangerColor = Color(0xFFE55353);
const _libraryDialogBodyColor = Color(0xFF554A42);

Future<bool> _showLibraryConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
  required Color confirmColor,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.ink, width: 2.5),
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: _libraryDialogBodyColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            StickerButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              text: 'Hủy',
              fontSize: 13,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            StickerButton(
              key: confirmKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              surfaceColor: confirmColor,
              textColor: Colors.white,
              text: confirmLabel,
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
