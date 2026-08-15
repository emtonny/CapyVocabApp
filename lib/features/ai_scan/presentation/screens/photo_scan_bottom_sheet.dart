import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../../core/services/gemini_vision_service.dart';
import '../../data/datasources/scan_result_local_datasource.dart';
import '../../data/services/scan_image_compressor.dart';
import '../../data/services/scan_image_picker.dart';
import '../../data/services/scan_image_storage.dart';
import '../controllers/scan_flow_controller.dart';
import '../providers/scan_provider.dart';
import '../widgets/camera_capture_view.dart';
import '../widgets/scan_loading_overlay.dart';
import '../widgets/vocab_canvas_overlay.dart';

typedef WebCameraCaptureBuilder = Widget Function(BuildContext context);

Widget _buildDefaultWebCameraCaptureView(BuildContext context) {
  return const CameraCaptureView();
}

class PhotoScanBottomSheet extends ConsumerStatefulWidget {
  const PhotoScanBottomSheet({
    super.key,
    this.debugIsWebOverride,
    this.webCameraCaptureBuilder = _buildDefaultWebCameraCaptureView,
  });

  final bool? debugIsWebOverride;
  final WebCameraCaptureBuilder webCameraCaptureBuilder;

  /// Static helper to open as a standard modal bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PhotoScanBottomSheet(),
    );
  }

  @override
  ConsumerState<PhotoScanBottomSheet> createState() =>
      _PhotoScanBottomSheetState();
}

class _PhotoScanBottomSheetState extends ConsumerState<PhotoScanBottomSheet> {
  Uint8List? _previewBytes;
  double? _imageAspectRatio;
  ScanResultRecord? _scanRecord;
  bool _isProcessing = false;
  String _processingStatus = 'Đang chuẩn bị ảnh...';
  int _selectedTemplateIndex = 0; // 0: Mặc định, 1: Tối giản, 2: Tự thiết kế

  final List<Map<String, dynamic>> _noteTemplates = [
    {
      'title': 'Mặc định',
      'subtitle': 'Khung chuẩn',
      'icon': Icons.push_pin_rounded,
      'color': const Color(0xFFE57373),
    },
    {
      'title': 'Tối giản',
      'subtitle': 'Gọn gàng',
      'icon': Icons.notes_rounded,
      'color': const Color(0xFF64B5F6),
    },
    {
      'title': 'Tự thiết kế',
      'subtitle': 'Tùy biến',
      'icon': Icons.palette_outlined,
      'color': const Color(0xFFBA68C8),
    },
  ];

  void _updateImageDimensions(Uint8List bytes) {
    ui.instantiateImageCodec(bytes).then((codec) {
      return codec.getNextFrame();
    }).then((frame) {
      final image = frame.image;
      if (image.width > 0 && image.height > 0 && mounted) {
        setState(() {
          _imageAspectRatio = image.width / image.height;
        });
      }
    }).catchError((_) {});
  }

  Future<void> _pickAndScan(
    ScanImageSource source, {
    Future<PickedScanImage?> Function()? pickOverride,
  }) async {
    if (_isProcessing) return;

    setState(() {
      _previewBytes = null;
      _imageAspectRatio = null;
      _scanRecord = null;
      _processingStatus = 'Đang chuẩn bị ảnh...';
    });

    final PickedScanImage? pickedImage;
    try {
      pickedImage = pickOverride == null
          ? await ref.read(scanImagePickerProvider).pick(source)
          : await pickOverride();
    } catch (error, stackTrace) {
      await _handlePreparationError(
        stage: 'pick',
        error: error,
        stackTrace: stackTrace,
        fallbackMessage: source == ScanImageSource.camera
            ? 'Không thể mở camera. Vui lòng kiểm tra quyền truy cập.'
            : 'Không thể chọn ảnh. Vui lòng thử lại.',
      );
      return;
    }
    if (pickedImage == null || !mounted) return;
    final selectedImage = pickedImage;

    _updateImageDimensions(selectedImage.bytes);

    setState(() {
      _previewBytes = selectedImage.bytes;
      _isProcessing = true;
      _processingStatus = 'Đang nén ảnh...';
    });

    try {
      final Uint8List compressedBytes;
      try {
        compressedBytes = await ref
            .read(scanImageCompressorProvider)
            .compress(selectedImage.bytes);
      } catch (error, stackTrace) {
        await _handlePreparationError(
          stage: 'compress',
          error: error,
          stackTrace: stackTrace,
          fallbackMessage: 'Không thể xử lý ảnh đã chọn. Vui lòng thử lại.',
        );
        return;
      }
      if (!mounted) return;

      _updateImageDimensions(compressedBytes);

      setState(() {
        _previewBytes = compressedBytes;
        _processingStatus = 'Đang nhận diện từ vựng...';
      });

      final String localPath;
      try {
        localPath =
            await ref.read(scanImageStorageProvider).saveJpeg(compressedBytes);
      } catch (error, stackTrace) {
        await _handlePreparationError(
          stage: 'store',
          error: error,
          stackTrace: stackTrace,
          fallbackMessage: 'Không thể lưu ảnh đã chọn. Vui lòng thử lại.',
        );
        return;
      }
      if (!mounted) return;

      final record = await ScanFlowController.scan(
        context,
        ref,
        localPath: localPath,
      );
      if (!mounted) return;
      if (record == null) return;

      setState(() {
        _scanRecord = record;
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handlePreparationError({
    required String stage,
    required Object error,
    required StackTrace stackTrace,
    required String fallbackMessage,
  }) async {
    debugPrint('AI scan failed during $stage: $error');
    debugPrintStack(
      label: 'AI scan $stage stack trace',
      stackTrace: stackTrace,
    );
    if (!mounted) return;

    final message = switch (error) {
      ScanImagePickerException() => error.message,
      ScanImagePreparationException() => error.message,
      ScanImageStorageException() => error.message,
      _ => fallbackMessage,
    };
    await _showPreparationError(message);
  }

  Future<PickedScanImage?> _captureWithWebCamera() async {
    final image = await Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(
        fullscreenDialog: true,
        builder: widget.webCameraCaptureBuilder,
      ),
    );
    if (image == null || !mounted) return null;

    return PickedScanImage(
      bytes: await image.readAsBytes(),
      name: image.name,
    );
  }

  Future<void> _captureAndScan() {
    final useWebCamera = widget.debugIsWebOverride ?? kIsWeb;
    if (useWebCamera) {
      return _pickAndScan(
        ScanImageSource.camera,
        pickOverride: _captureWithWebCamera,
      );
    }

    return _pickAndScan(ScanImageSource.camera);
  }

  Future<void> _showPreparationError(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Không thể chuẩn bị ảnh'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _openFullscreenZoom(
    BuildContext context,
    Uint8List bytes,
    List<VocabDetection> words,
    List<VocabDetection> sceneWords,
    double aspectRatio,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: words.isNotEmpty
                      ? VocabCanvasOverlay(
                          imageProvider: MemoryImage(bytes),
                          words: words,
                          sceneWords: sceneWords,
                        )
                      : Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  tooltip: 'Đóng',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewWidget() {
    final bytes = _previewBytes;
    if (bytes == null) return const SizedBox.shrink();

    final aspectRatio = _imageAspectRatio ?? (4 / 3);
    final words = _scanRecord?.result.detectedVocabulary ?? [];
    final sceneWords = _scanRecord?.result.placementContext ?? words;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.36,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEFE6D8),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dynamic aspect ratio image / canvas overlay
            AspectRatio(
              aspectRatio: aspectRatio,
              child: words.isNotEmpty
                  ? VocabCanvasOverlay(
                      key: const Key('scan-image-preview'),
                      imageProvider: MemoryImage(bytes),
                      words: words,
                      sceneWords: sceneWords,
                    )
                  : Image.memory(
                      bytes,
                      key: const Key('scan-image-preview'),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
            ),

            // Zoom In / Fullscreen Button on Top-Right Corner
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: const Color(0x99000000),
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('zoom-image-button'),
                  customBorder: const CircleBorder(),
                  onTap: () => _openFullscreenZoom(
                    context,
                    bytes,
                    words,
                    sceneWords,
                    aspectRatio,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isPreviewActive = _previewBytes != null || _isProcessing;
    final maxSheetHeight =
        isPreviewActive ? screenHeight * 0.82 : screenHeight * 0.55;

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Transparent tap-outside area to close (barrier handled by route)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                behavior: HitTestBehavior.translucent,
              ),
            ),

            // Half-screen Bottom Sheet Card pinned to bottom
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // Prevent tap through
                onVerticalDragEnd: (details) {
                  // Drag down to close
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 200 &&
                      Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: maxSheetHeight,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        spreadRadius: 4,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Drag Handle Bar
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2D6C5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          const Text(
                            'Quét từ vựng qua ảnh',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3C2A21),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dynamic Image Preview & Labeled Result Widget
                          _buildImagePreviewWidget(),

                          // 2 Main Options: "Chụp ảnh thô" & "Tải ảnh lên"
                          Row(
                            children: [
                              // Option 1: Chụp ảnh thô
                              Expanded(
                                child: _buildMainActionButton(
                                  buttonKey: const Key('pick-camera-button'),
                                  label: 'Chụp ảnh thô',
                                  iconWidget: const Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        Icons.photo_camera_rounded,
                                        size: 38,
                                        color: Color(0xFF5D4037),
                                      ),
                                      Positioned(
                                        top: -4,
                                        right: -6,
                                        child: Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                          color: Color(0xFFFFB300),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: _isProcessing ? null : _captureAndScan,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Option 2: Tải ảnh lên
                              Expanded(
                                child: _buildMainActionButton(
                                  buttonKey: const Key('pick-gallery-button'),
                                  label: 'Tải ảnh lên',
                                  iconWidget: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.insert_photo_rounded,
                                      size: 34,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                  onTap: _isProcessing
                                      ? null
                                      : () =>
                                          _pickAndScan(ScanImageSource.gallery),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Section Header: "CHỌN MẪU NOTE GHIM 🦫"
                          const Row(
                            children: [
                              Text(
                                'CHỌN MẪU NOTE GHIM',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9E8F85),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '🦫',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Fit all 3 template cards neatly in 1 horizontal row
                          Row(
                            children:
                                List.generate(_noteTemplates.length, (index) {
                              final template = _noteTemplates[index];
                              final isSelected =
                                  _selectedTemplateIndex == index;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index < _noteTemplates.length - 1
                                        ? 8.0
                                        : 0.0,
                                  ),
                                  child: _buildTemplateCard(
                                    title: template['title'] as String,
                                    subtitle: template['subtitle'] as String,
                                    icon: template['icon'] as IconData,
                                    color: template['color'] as Color,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(
                                          () => _selectedTemplateIndex = index);
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Processing Overlay
            if (_isProcessing)
              Positioned.fill(
                child: ScanLoadingOverlay(status: _processingStatus),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionButton({
    required Key buttonKey,
    required String label,
    required Widget iconWidget,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEFE6D8),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 44,
                child: Center(child: iconWidget),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3C2A21),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFFFF9F2) : const Color(0xFFFAF6F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7CB342)
                  : const Color(0xFFEFE6D8),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Color(0x337CB342),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? const Color(0xFF3C2A21)
                        : const Color(0xFF6D5D53),
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
