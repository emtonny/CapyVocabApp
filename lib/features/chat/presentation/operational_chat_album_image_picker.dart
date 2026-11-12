import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/gemini_vision_service.dart' as scan_model;
import '../../ai_scan/presentation/widgets/scan_paper_background.dart';
import '../../ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import '../../library/domain/entities/album_models.dart';
import '../../library/domain/entities/photo_note.dart';
import '../../library/domain/entities/photo_note_snapshot.dart';
import '../../library/presentation/providers/library_provider.dart';
import '../domain/operational_chat.dart';

const _allLibraryPhotos = '__all_library_photos__';

final class OperationalChatAlbumImageSelection {
  const OperationalChatAlbumImageSelection({
    required this.photoNoteId,
    required this.title,
    required this.localRelativePath,
    required this.mimeType,
    required this.byteSize,
    required this.previewBytes,
    required this.labels,
  });

  final String photoNoteId;
  final String title;
  final String localRelativePath;
  final String mimeType;
  final int byteSize;
  final Uint8List previewBytes;
  final List<OperationalChatImageLabel> labels;
}

Future<OperationalChatAlbumImageSelection?> showChatAlbumImagePicker(
  BuildContext context,
) {
  return showModalBottomSheet<OperationalChatAlbumImageSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: .45),
    elevation: 0,
    showDragHandle: false,
    builder: (_) => const Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: FractionallySizedBox(
        heightFactor: .88,
        child: OperationalChatAlbumImagePicker(),
      ),
    ),
  );
}

class OperationalChatAlbumImagePicker extends ConsumerStatefulWidget {
  const OperationalChatAlbumImagePicker({super.key});

  @override
  ConsumerState<OperationalChatAlbumImagePicker> createState() =>
      _OperationalChatAlbumImagePickerState();
}

class _OperationalChatAlbumImagePickerState
    extends ConsumerState<OperationalChatAlbumImagePicker> {
  String _sourceId = _allLibraryPhotos;

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(libraryAlbumsProvider);
    final allPhotos = ref.watch(libraryPhotoNotesProvider);
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('chat-album-picker-shell'),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: ScanPaperBackground()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PickerHeader(),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn trong tất cả ảnh hoặc lọc theo Album. Mỗi tin nhắn chỉ gửi một ảnh.',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 14),
                  albums.when(
                    loading: () => const LinearProgressIndicator(
                      color: AppColors.duoOrange,
                      backgroundColor: AppColors.paleGold,
                    ),
                    error: (_, __) => const _PickerMessage(
                      icon: Icons.cloud_off_rounded,
                      text: 'Không đọc được Album trên máy.',
                    ),
                    data: (rows) => _AlbumSelector(
                      albums: rows,
                      allPhotoCount: allPhotos.asData?.value.length,
                      selectedId: _sourceId,
                      onSelected: (id) => setState(() => _sourceId = id),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildPhotos(
                      albums.valueOrNull ?? const [],
                      allPhotos,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotos(
    List<Album> albums,
    AsyncValue<List<PhotoNote>> allPhotos,
  ) {
    final selectedAlbum = albums.any((row) => row.id == _sourceId)
        ? _sourceId
        : _allLibraryPhotos;
    final notes = selectedAlbum == _allLibraryPhotos
        ? allPhotos
        : ref.watch(libraryAlbumPhotoNotesProvider(selectedAlbum));
    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: _PickerMessage(
          icon: Icons.broken_image_outlined,
          text: 'Không đọc được ảnh trong Album.',
        ),
      ),
      data: (rows) => rows.isEmpty
          ? Center(
              child: _PickerMessage(
                icon: Icons.photo_library_outlined,
                text: selectedAlbum == _allLibraryPhotos
                    ? 'Thư viện chưa có ảnh từ vựng để chia sẻ.'
                    : 'Album này chưa có ảnh từ vựng.',
              ),
            )
          : GridView.builder(
              key: const Key('chat-album-image-grid'),
              padding: const EdgeInsets.only(bottom: 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemCount: rows.length,
              itemBuilder: (_, index) => _PhotoNoteTile(note: rows[index]),
            ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(Icons.photo_library_rounded, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Chọn một ảnh từ Thư viện',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(0, 3)),
            ],
          ),
          child: IconButton(
            key: const Key('chat-album-picker-close'),
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.ink, width: 2),
              ),
            ),
            icon: const Icon(Icons.close_rounded, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.paleGold,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumSelector extends StatelessWidget {
  const _AlbumSelector({
    required this.albums,
    required this.allPhotoCount,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Album> albums;
  final int? allPhotoCount;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final value = selectedId == _allLibraryPhotos ||
            albums.any((row) => row.id == selectedId)
        ? selectedId
        : _allLibraryPhotos;
    return DropdownButtonFormField<String>(
      key: const Key('chat-album-selector'),
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      dropdownColor: AppColors.softWhite,
      borderRadius: BorderRadius.circular(14),
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        labelText: 'Nguồn ảnh trong Thư viện',
        labelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w800,
          color: AppColors.darkGreen,
        ),
        prefixIcon: const Icon(
          Icons.collections_bookmark_rounded,
          color: AppColors.duoOrange,
        ),
        filled: true,
        fillColor: AppColors.softWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.duoOrange, width: 3),
        ),
      ),
      items: [
        DropdownMenuItem(
          value: _allLibraryPhotos,
          child: Text(
            allPhotoCount == null
                ? '🖼️ Tất cả ảnh'
                : '🖼️ Tất cả ảnh ($allPhotoCount)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final album in albums)
          DropdownMenuItem(
            value: album.id,
            child: Text(
              '${album.icon} ${album.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) {
        if (id != null) onSelected(id);
      },
    );
  }
}

class _PhotoNoteTile extends ConsumerWidget {
  const _PhotoNoteTile({required this.note});

  final PhotoNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(libraryPhotoNoteSnapshotProvider(note.id));
    return snapshot.when(
      loading: () => const _PhotoTileFrame(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _UnavailableTile(title: note.title),
      data: (value) {
        if (value == null) return _UnavailableTile(title: note.title);
        final asset = value.mediaAsset;
        final labels = _imageLabels(value);
        final bytes =
            ref.watch(libraryMediaBytesProvider(asset.displayRelativePath));
        return _PhotoTileFrame(
          child: Semantics(
            button: true,
            label: 'Chọn ảnh ${note.title}',
            child: InkWell(
              key: ValueKey('chat-album-photo-${note.id}'),
              onTap: bytes.hasValue
                  ? () => Navigator.of(context).pop(
                        OperationalChatAlbumImageSelection(
                          photoNoteId: note.id,
                          title: note.title,
                          localRelativePath: asset.displayRelativePath,
                          mimeType: asset.mimeType,
                          byteSize: bytes.requireValue.length,
                          previewBytes: bytes.requireValue,
                          labels: labels,
                        ),
                      )
                  : null,
              child: bytes.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.duoOrange,
                  ),
                ),
                error: (_, __) => const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 34,
                    color: AppColors.mutedInk,
                  ),
                ),
                data: (data) => labels.isEmpty
                    ? Image.memory(
                        data,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : VocabCanvasOverlay(
                        key: ValueKey('chat-album-labels-${note.id}'),
                        imageProvider: MemoryImage(data),
                        words: _overlayWords(labels),
                        showLabels: true,
                        showWord: true,
                        showPhonetic: true,
                        showMeaning: true,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoTileFrame extends StatelessWidget {
  const _PhotoTileFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return Container(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: AppColors.softWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.ink, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

List<OperationalChatImageLabel> _imageLabels(PhotoNoteSnapshot snapshot) {
  final annotations = snapshot.annotationsByDetectionId;
  final labels = <OperationalChatImageLabel>[];
  for (final detection in snapshot.detections) {
    final active = annotations[detection.id]
        ?.where((annotation) => annotation.deletedAt == null)
        .lastOrNull;
    final box = active?.correctedBoundingBox ?? detection.boundingBox;
    if (box == null) continue;
    labels.add(
      OperationalChatImageLabel(
        number: labels.length + 1,
        word: active?.correctedWord ?? detection.wordRaw,
        phonetic: active?.correctedPhonetic ?? detection.phonetic ?? '',
        meaning: active?.correctedMeaningVi ?? detection.meaningVi ?? '',
        partOfSpeech: detection.partOfSpeech ?? '',
        x: box.x,
        y: box.y,
        width: box.width,
        height: box.height,
      ),
    );
    if (labels.length == operationalChatMaximumImageLabels) break;
  }
  return List.unmodifiable(labels);
}

List<scan_model.VocabDetection> _overlayWords(
  List<OperationalChatImageLabel> labels,
) =>
    labels
        .map(
          (label) => scan_model.VocabDetection(
            number: label.number,
            word: label.word,
            phonetic: label.phonetic,
            meaning: label.meaning,
            partOfSpeech: label.partOfSpeech,
            x: label.x,
            y: label.y,
            w: label.width,
            h: label.height,
          ),
        )
        .toList(growable: false);

class _UnavailableTile extends StatelessWidget {
  const _UnavailableTile({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => _PhotoTileFrame(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_not_supported_outlined,
                  size: 34,
                  color: AppColors.mutedInk,
                ),
                const SizedBox(height: 8),
                Text(
                  '$title\nẢnh không có trên máy này.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
