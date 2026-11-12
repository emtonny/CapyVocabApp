import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/gemini_vision_service.dart' as scan_model;
import '../../ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_provider.dart';

class OperationalChatAlbumImageMessage extends ConsumerWidget {
  const OperationalChatAlbumImageMessage({
    super.key,
    required this.owner,
    required this.message,
    this.onZoom,
  });

  final ChatOwner owner;
  final OperationalChatMessage message;
  final VoidCallback? onZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = message.albumImage;
    if (image == null) return const SizedBox.shrink();
    if (!image.available) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              operationalChatUnavailableImageText,
              key: Key('chat-album-image-unavailable'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    final key = (owner, image);
    final bytes = ref.watch(operationalChatAlbumImageBytesProvider(key));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh từ Album',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260, maxHeight: 300),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: bytes.when(
              loading: () => const SizedBox(
                width: 180,
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => SizedBox(
                width: 220,
                height: 120,
                child: Center(
                  child: TextButton.icon(
                    key: const Key('chat-album-image-retry'),
                    onPressed: () => ref.invalidate(
                      operationalChatAlbumImageBytesProvider(key),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tải lại ảnh'),
                  ),
                ),
              ),
              data: (data) => Stack(
                children: [
                  _ChatAlbumImageCanvas(
                    data: data,
                    image: image,
                    maxWidth: 260,
                    maxHeight: 300,
                  ),
                  if (onZoom != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _ImageActionButton(
                        key: const Key('chat-album-image-zoom'),
                        visualKey: const Key('chat-album-image-zoom-visual'),
                        visualSize: 36,
                        tooltip: 'Phóng to ảnh trong hộp chat',
                        icon: Icons.zoom_out_map_rounded,
                        onPressed: onZoom,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OperationalChatAlbumImageViewer extends ConsumerWidget {
  const OperationalChatAlbumImageViewer({
    super.key,
    required this.owner,
    required this.message,
    required this.onClose,
  });

  final ChatOwner owner;
  final OperationalChatMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = message.albumImage;
    if (image == null || !image.available) return const SizedBox.shrink();
    final providerKey = (owner, image);
    final bytes =
        ref.watch(operationalChatAlbumImageBytesProvider(providerKey));
    return Material(
      key: const Key('chat-album-image-viewer'),
      color: const Color(0xFFFFFCF5),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: bytes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(
                      operationalChatAlbumImageBytesProvider(providerKey),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tải lại ảnh'),
                  ),
                ),
                data: (data) => LayoutBuilder(
                  builder: (context, constraints) => Center(
                    key: const Key('chat-album-image-fixed-viewer'),
                    child: _ChatAlbumImageCanvas(
                      data: data,
                      image: image,
                      maxWidth: constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _ImageActionButton(
              key: const Key('chat-album-image-viewer-close'),
              tooltip: 'Đóng ảnh phóng to',
              icon: Icons.close_rounded,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAlbumImageCanvas extends StatelessWidget {
  const _ChatAlbumImageCanvas({
    required this.data,
    required this.image,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Uint8List data;
  final OperationalChatAlbumImage image;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (image.labels.isEmpty) {
      return Image.memory(
        data,
        key: const Key('chat-album-image'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: _readImageAspectRatio(data) ?? 1,
        child: VocabCanvasOverlay(
          key: const Key('chat-album-image-with-labels'),
          imageProvider: MemoryImage(data),
          words: image.labels
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
              .toList(growable: false),
          showLabels: true,
          showWord: true,
          showPhonetic: true,
          showMeaning: true,
          fitCanvasToImage: true,
        ),
      ),
    );
  }
}

double? _readImageAspectRatio(Uint8List data) {
  if (data.length >= 24 &&
      data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4E &&
      data[3] == 0x47) {
    final bytes = ByteData.sublistView(data);
    return _validAspectRatio(
      bytes.getUint32(16, Endian.big),
      bytes.getUint32(20, Endian.big),
    );
  }
  if (data.length >= 4 && data[0] == 0xFF && data[1] == 0xD8) {
    var offset = 2;
    while (offset + 8 < data.length) {
      while (offset < data.length && data[offset] != 0xFF) {
        offset++;
      }
      while (offset < data.length && data[offset] == 0xFF) {
        offset++;
      }
      if (offset >= data.length) break;
      final marker = data[offset++];
      if (marker == 0xD9 || marker == 0xDA) break;
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) continue;
      if (offset + 1 >= data.length) break;
      final segmentLength = (data[offset] << 8) | data[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > data.length) break;
      final isStartOfFrame = marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isStartOfFrame && segmentLength >= 7) {
        final height = (data[offset + 3] << 8) | data[offset + 4];
        final width = (data[offset + 5] << 8) | data[offset + 6];
        return _validAspectRatio(width, height);
      }
      offset += segmentLength;
    }
  }
  if (data.length >= 30 &&
      String.fromCharCodes(data.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(data.sublist(8, 12)) == 'WEBP') {
    final chunk = String.fromCharCodes(data.sublist(12, 16));
    if (chunk == 'VP8X') {
      final width = 1 + data[24] + (data[25] << 8) + (data[26] << 16);
      final height = 1 + data[27] + (data[28] << 8) + (data[29] << 16);
      return _validAspectRatio(width, height);
    }
    if (chunk == 'VP8L' && data[20] == 0x2F) {
      final width = 1 + data[21] + ((data[22] & 0x3F) << 8);
      final height =
          1 + (data[22] >> 6) + (data[23] << 2) + ((data[24] & 0x0F) << 10);
      return _validAspectRatio(width, height);
    }
    if (chunk == 'VP8 ' &&
        data[23] == 0x9D &&
        data[24] == 0x01 &&
        data[25] == 0x2A) {
      final width = (data[26] | (data[27] << 8)) & 0x3FFF;
      final height = (data[28] | (data[29] << 8)) & 0x3FFF;
      return _validAspectRatio(width, height);
    }
  }
  return null;
}

double? _validAspectRatio(int width, int height) =>
    width > 0 && height > 0 ? width / height : null;

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    super.key,
    this.visualKey,
    this.visualSize = 48,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key? visualKey;
  final double visualSize;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 48,
        child: Center(
          child: SizedBox.square(
            key: visualKey,
            dimension: visualSize,
            child: Material(
              color: Colors.white.withValues(alpha: .92),
              shape: CircleBorder(
                side: BorderSide(
                  color: Colors.black.withValues(alpha: .72),
                  width: 2,
                ),
              ),
              child: IconButton(
                tooltip: tooltip,
                constraints: BoxConstraints.tightFor(
                  width: visualSize,
                  height: visualSize,
                ),
                padding: EdgeInsets.zero,
                onPressed: onPressed,
                icon: Icon(
                  icon,
                  size: visualSize <= 36 ? 18 : 22,
                  color: const Color(0xFF3E322E),
                ),
              ),
            ),
          ),
        ),
      );
}
