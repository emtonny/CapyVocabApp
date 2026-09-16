part of 'storage_album_screen.dart';

class LibraryPhotoNoteDetailScreen extends ConsumerWidget {
  const LibraryPhotoNoteDetailScreen({required this.photoNoteId, super.key});

  final String photoNoteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      libraryPhotoNoteSnapshotProvider(photoNoteId),
    );
    return GraphPaperScaffold(
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

enum _LibraryLabelField { word, phonetic, meaning }

class _SelectedPhotoVocabularyCard extends ConsumerStatefulWidget {
  const _SelectedPhotoVocabularyCard({
    required this.note,
    required this.position,
    required this.total,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final PhotoNote note;
  final int position;
  final int total;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  ConsumerState<_SelectedPhotoVocabularyCard> createState() =>
      _SelectedPhotoVocabularyCardState();
}

class _SelectedPhotoVocabularyCardState
    extends ConsumerState<_SelectedPhotoVocabularyCard> {
  bool _showLabels = false;
  bool _showWord = false;
  bool _showPhonetic = false;
  bool _showMeaning = false;
  bool _hasExplicitLabelSelection = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final snapshotProvider = libraryPhotoNoteSnapshotProvider(note.id);
    final snapshot = ref.watch(snapshotProvider);
    final media = snapshot.valueOrNull?.mediaAsset;
    final imageRatio =
        media == null ? 1.25 : (media.width / media.height).clamp(0.65, 1.8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: widget.expanded
                  ? 'Đóng từ vựng của ảnh ${widget.position} trên ${widget.total}'
                  : 'Mở từ vựng của ảnh ${widget.position} trên ${widget.total}',
              child: InkWell(
                key: Key('library-selected-vocabulary-toggle-${note.id}'),
                onTap: widget.onToggle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: AspectRatio(
                        aspectRatio: imageRatio,
                        child: snapshot.when(
                          loading: () =>
                              const _ImagePlaceholder(isLoading: true),
                          error: (_, __) => Center(
                            child: Text(
                              note.emoji ?? '📷',
                              style: const TextStyle(fontSize: 42),
                            ),
                          ),
                          data: (value) {
                            if (value == null) {
                              return Center(
                                child: Text(
                                  note.emoji ?? '📷',
                                  style: const TextStyle(fontSize: 42),
                                ),
                              );
                            }
                            return _LocalLibraryImage(
                              mediaAsset: value.mediaAsset,
                              semanticLabel:
                                  'Ảnh đã chọn ${widget.position} của ${note.title}',
                              showRetry: true,
                              allowCloudRestore: true,
                              overlayWords: _libraryOverlayWords(value),
                              showLabels: _showLabels,
                              showWord: _showWord,
                              showPhonetic: _showPhonetic,
                              showMeaning: _showMeaning,
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ảnh ${widget.position}/${widget.total}',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            widget.expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.ink,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.expanded) _buildVocabulary(context, ref, snapshot),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabulary(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PhotoNoteSnapshot?> snapshot,
  ) {
    return snapshot.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text('Không thể đọc danh sách từ vựng.'),
            Align(
              alignment: Alignment.centerLeft,
              child: StickerButton(
                onPressed: () => ref.invalidate(
                  libraryPhotoNoteSnapshotProvider(widget.note.id),
                ),
                text: 'Thử lại',
              ),
            ),
          ],
        ),
      ),
      data: (value) {
        if (value == null) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text('Không tìm thấy dữ liệu từ vựng.'),
          );
        }
        return Padding(
          key: Key('library-selected-vocabulary-words-${widget.note.id}'),
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildLabelControls(),
              const SizedBox(height: 18),
              Text(
                'Từ vựng nhận diện',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              if (value.detections.isEmpty)
                const Text('Ảnh này không có từ vựng được nhận diện.')
              else
                ...value.detections.map(
                  (detection) => _DetectionCard(
                    detection: detection,
                    annotations: value.annotationsByDetectionId[detection.id] ??
                        const [],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabelControls() {
    return Container(
      key: Key('library-label-controls-${widget.note.id}'),
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: _buildLabelControlButton(
              buttonKey: Key('library-toggle-labels-${widget.note.id}'),
              label: _showLabels ? 'ẨN LABEL' : 'HIỆN LABEL',
              activeColor: const Color(0xFFFDE047),
              isActive: !_showLabels,
              onTap: _showLabels ? _hideAllLabels : _setAllLabelsVisible,
            ),
          ),
          const _LibraryLabelControlDivider(),
          Expanded(
            child: _buildLabelControlButton(
              buttonKey: Key('library-toggle-word-${widget.note.id}'),
              label: 'TỪ VỰNG',
              activeColor: const Color(0xFFBBF7D0),
              isActive: _hasExplicitLabelSelection && _showLabels && _showWord,
              onTap: () => _toggleLabelField(_LibraryLabelField.word),
            ),
          ),
          const _LibraryLabelControlDivider(),
          Expanded(
            child: _buildLabelControlButton(
              buttonKey: Key('library-toggle-phonetic-${widget.note.id}'),
              label: 'PHIÊN ÂM',
              activeColor: const Color(0xFFBAE6FD),
              isActive:
                  _hasExplicitLabelSelection && _showLabels && _showPhonetic,
              onTap: () => _toggleLabelField(_LibraryLabelField.phonetic),
            ),
          ),
          const _LibraryLabelControlDivider(),
          Expanded(
            child: _buildLabelControlButton(
              buttonKey: Key('library-toggle-meaning-${widget.note.id}'),
              label: 'DỊCH',
              activeColor: const Color(0xFFFBCFE8),
              isActive:
                  _hasExplicitLabelSelection && _showLabels && _showMeaning,
              onTap: () => _toggleLabelField(_LibraryLabelField.meaning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelControlButton({
    required Key buttonKey,
    required String label,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isActive ? activeColor : const Color(0xFFE2E8F0),
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isActive ? AppColors.ink : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setAllLabelsVisible() {
    setState(() {
      _showLabels = true;
      _showWord = true;
      _showPhonetic = true;
      _showMeaning = true;
      _hasExplicitLabelSelection = false;
    });
  }

  void _hideAllLabels() {
    setState(() {
      _showLabels = false;
      _showWord = false;
      _showPhonetic = false;
      _showMeaning = false;
      _hasExplicitLabelSelection = false;
    });
  }

  void _toggleLabelField(_LibraryLabelField field) {
    setState(() {
      if (!_hasExplicitLabelSelection || !_showLabels) {
        _showWord = field == _LibraryLabelField.word;
        _showPhonetic = field == _LibraryLabelField.phonetic;
        _showMeaning = field == _LibraryLabelField.meaning;
        _showLabels = true;
        _hasExplicitLabelSelection = true;
        return;
      }

      switch (field) {
        case _LibraryLabelField.word:
          _showWord = !_showWord;
        case _LibraryLabelField.phonetic:
          _showPhonetic = !_showPhonetic;
        case _LibraryLabelField.meaning:
          _showMeaning = !_showMeaning;
      }

      final hasVisibleField = _showWord || _showPhonetic || _showMeaning;
      _showLabels = hasVisibleField;
      _hasExplicitLabelSelection = hasVisibleField;
    });
  }
}

class _LibraryLabelControlDivider extends StatelessWidget {
  const _LibraryLabelControlDivider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 2, child: ColoredBox(color: AppColors.ink));
}

List<scan_model.VocabDetection> _libraryOverlayWords(
  PhotoNoteSnapshot snapshot,
) {
  return snapshot.detections.indexed
      .map((entry) {
        final (index, detection) = entry;
        final annotation = snapshot.annotationsByDetectionId[detection.id]
            ?.where((item) => item.deletedAt == null)
            .lastOrNull;
        final box = annotation?.correctedBoundingBox ?? detection.boundingBox;
        if (box == null) return null;

        return scan_model.VocabDetection(
          number: index + 1,
          word: annotation?.correctedWord ?? detection.wordRaw,
          phonetic: annotation?.correctedPhonetic ?? detection.phonetic ?? '',
          meaning: annotation?.correctedMeaningVi ?? detection.meaningVi ?? '',
          partOfSpeech: detection.partOfSpeech ?? '',
          x: box.x,
          y: box.y,
          w: box.width,
          h: box.height,
        );
      })
      .nonNulls
      .toList(growable: false);
}

class _PhotoNoteCard extends ConsumerWidget {
  const _PhotoNoteCard({
    required this.note,
    required this.onTap,
    this.onMoveToTrash,
    this.onRemoveFromAlbum,
    this.selectionMode = false,
    this.selected = false,
  });

  final PhotoNote note;
  final VoidCallback onTap;
  final VoidCallback? onMoveToTrash;
  final VoidCallback? onRemoveFromAlbum;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(libraryPhotoNoteSnapshotProvider(note.id));
    final snapshotData = snapshot.valueOrNull;
    final vocabCount = snapshotData?.vocabCount ?? 1;

    final cardSurface = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(selected ? 9 : 16),
        border: Border.all(
          color: AppColors.ink,
          width: selected ? 1.6 : 2.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(selected ? 9 : 16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(selected ? 9 : 16),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Square photo preview (1:1 aspect ratio, auto fit)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      width: double.infinity,
                      color: const Color(0xFFF6F3EE),
                      child: snapshot.when(
                        loading: () => const _ImagePlaceholder(isLoading: true),
                        error: (_, __) => Center(
                          child: Text(
                            note.emoji ?? '📝',
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        data: (value) {
                          if (value == null) {
                            return Center(
                              child: Text(
                                note.emoji ?? '📝',
                                style: const TextStyle(fontSize: 32),
                              ),
                            );
                          }
                          return _LocalLibraryImage(
                            mediaAsset: value.mediaAsset,
                            semanticLabel: 'Ảnh của ${note.title}',
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Word count with tag icon
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3EB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.ink,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏷️', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              '$vocabCount từ',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selectionMode)
                        SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected ? AppColors.coral : AppColors.ink,
                              size: 24,
                            ),
                          ),
                        )
                      else
                        Semantics(
                          key: Key('library-note-menu-${note.id}'),
                          button: true,
                          label: onRemoveFromAlbum != null
                              ? 'Gỡ khỏi Album'
                              : 'Xóa bài',
                          excludeSemantics: true,
                          onTap: () {
                            if (onRemoveFromAlbum != null) {
                              onRemoveFromAlbum?.call();
                            } else if (onMoveToTrash != null) {
                              onMoveToTrash?.call();
                            }
                          },
                          child: SizedBox.square(
                            dimension: 48,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (onRemoveFromAlbum != null) {
                                  onRemoveFromAlbum?.call();
                                } else if (onMoveToTrash != null) {
                                  onMoveToTrash?.call();
                                }
                              },
                              child: Center(
                                child: IgnorePointer(
                                  child: SizedBox.square(
                                    dimension: 32,
                                    child: StickerButton(
                                      semanticLabel: onRemoveFromAlbum != null
                                          ? 'Gỡ khỏi Album'
                                          : 'Xóa bài',
                                      onPressed: () {},
                                      surfaceColor: const Color(0xFFFFECEB),
                                      edgeColor: const Color(0xFFE5B5B5),
                                      padding: EdgeInsets.zero,
                                      radius: 8,
                                      expand: true,
                                      flat: true,
                                      icon: Icon(
                                        onRemoveFromAlbum != null
                                            ? Icons.folder_off_outlined
                                            : Icons.delete_outline_rounded,
                                        color: AppColors.ink,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
    );

    final card = Container(
      key: Key('library-photo-note-${note.id}'),
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
              borderRadius: BorderRadius.all(Radius.circular(14)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(0, 3.5),
                  blurRadius: 0,
                ),
              ],
            ),
      padding: selected ? const EdgeInsets.all(3.5) : EdgeInsets.zero,
      child: cardSurface,
    );

    return Semantics(
      button: true,
      label: 'Mở bài đã lưu ${note.title}',
      child: card,
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount _photoNoteGridDelegate(
  double maxWidth, {
  required bool largeText,
}) {
  const horizontalPadding = 32.0;
  const crossAxisSpacing = 12.0;
  const mainAxisSpacing = 14.0;
  const footerHeight = 48.0;
  const imageFooterGap = 4.0;

  final crossAxisCount =
      largeText ? (maxWidth >= 720 ? 2 : 1) : (maxWidth >= 720 ? 4 : 2);
  final cardWidth = (maxWidth -
          horizontalPadding -
          ((crossAxisCount - 1) * crossAxisSpacing)) /
      crossAxisCount;

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing,
    mainAxisExtent: cardWidth + footerHeight + imageFooterGap,
  );
}

bool _usesLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= 1.5;

int _albumGridColumnCount(double maxWidth, {required bool largeText}) {
  if (largeText) return maxWidth >= 720 ? 3 : 2;
  if (maxWidth < 350) return 2;
  return maxWidth >= 720 ? 4 : 3;
}

SliverGridDelegateWithFixedCrossAxisCount _trashGridDelegate(double maxWidth) {
  const horizontalPadding = 32.0;
  const crossAxisSpacing = 12.0;
  const mainAxisSpacing = 14.0;
  final crossAxisCount = maxWidth >= 720 ? 4 : 2;
  final cardWidth = (maxWidth -
          horizontalPadding -
          ((crossAxisCount - 1) * crossAxisSpacing)) /
      crossAxisCount;
  const detailsAndActionsHeight = 70.0;

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing,
    mainAxisExtent: cardWidth + detailsAndActionsHeight,
  );
}

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
    return Container(
      key: Key('library-detection-${detection.id}'),
      margin: const EdgeInsets.only(bottom: 10),
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
    this.overlayWords = const [],
    this.showLabels = false,
    this.showWord = false,
    this.showPhonetic = false,
    this.showMeaning = false,
  });

  final MediaAsset mediaAsset;
  final String semanticLabel;
  final bool showRetry;
  final bool allowCloudRestore;
  final List<scan_model.VocabDetection> overlayWords;
  final bool showLabels;
  final bool showWord;
  final bool showPhonetic;
  final bool showMeaning;

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
      data: (value) => widget.overlayWords.isEmpty || !widget.showLabels
          ? Image.memory(
              value,
              key: Key('library-media-$relativePath'),
              fit: BoxFit.cover,
              semanticLabel: widget.semanticLabel,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _ImagePlaceholder(
                message: widget.showRetry ? 'Ảnh local không đọc được' : null,
              ),
            )
          : Semantics(
              image: true,
              label: widget.semanticLabel,
              child: VocabCanvasOverlay(
                key: Key('library-media-overlay-$relativePath'),
                imageProvider: MemoryImage(value),
                words: widget.overlayWords,
                showLabels: widget.showLabels,
                showWord: widget.showWord,
                showPhonetic: widget.showPhonetic,
                showMeaning: widget.showMeaning,
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
        showTopNotification(
          context,
          const SnackBar(content: Text('Đã tải ảnh về thiết bị.')),
        );
      }
    } catch (_) {
      if (mounted) {
        showTopNotification(
          context,
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
                    StickerButton(
                      onPressed: onAction,
                      text: actionLabel!,
                      fontSize: 12,
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8D0),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.ink, width: 1.8),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.offline_pin_rounded, size: 15, color: AppColors.ink),
            SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: [
          Icon(icon, size: 14, color: color),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
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
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2.2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 34, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedInk,
                  height: 1.4,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 20),
                StickerButton(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  text: actionLabel!,
                  surfaceColor: AppColors.duoOrange,
                  textColor: Colors.white,
                  fontSize: 13.5,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
              ],
            ],
          ),
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
