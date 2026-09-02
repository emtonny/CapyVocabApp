import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/gemini_vision_service.dart';
import '../../data/datasources/scan_result_local_datasource.dart';
import '../../data/services/scan_image_compressor.dart';
import '../../data/services/scan_image_picker.dart';
import '../../data/services/scan_image_storage.dart';
import '../controllers/scan_flow_controller.dart';
import '../label_visual_style.dart';
import '../providers/scan_provider.dart';
import '../widgets/camera_capture_view.dart';
import '../widgets/neo_scan_decorations.dart';
import '../widgets/note_template_selector.dart';
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
  NoteLabelTemplate _selectedTemplate = NoteLabelTemplate.standard;
  LabelVisualStyle _customLabelStyle = LabelVisualStyle.customDefault;

  LabelVisualStyle get _selectedLabelStyle => switch (_selectedTemplate) {
        NoteLabelTemplate.standard => LabelVisualStyle.standard,
        NoteLabelTemplate.minimal => LabelVisualStyle.minimal,
        NoteLabelTemplate.custom => _customLabelStyle,
      };

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
        backgroundColor: AppColors.softWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.ink, width: 2.8),
        ),
        title: const Text('Không thể chuẩn bị ảnh'),
        content: Text(message),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(96, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.ink, width: 2.4),
              ),
            ),
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
                          visualStyle: _selectedLabelStyle,
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
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.ink,
          width: 2.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(4.0, 4.0),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
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
                      visualStyle: _selectedLabelStyle,
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
                    padding: EdgeInsets.all(14),
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxSheetHeight = screenHeight * 0.88;

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

            // Bottom Sheet Card pinned to bottom with natural content fit
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
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: maxSheetHeight,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      border: Border.all(
                        color: AppColors.ink,
                        width: 2.8,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          blurRadius: 0,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Top-Left Neon Triangle (Restrained Memphis Accent)
                        const Positioned(
                          top: 0,
                          left: 0,
                          child: IgnorePointer(
                            child: NeoCornerTriangle(size: 44),
                          ),
                        ),
                        // Top-Left Dot Matrix (3x3)
                        const Positioned(
                          top: 36,
                          left: 32,
                          child: IgnorePointer(
                            child: NeoDotMatrix(
                              rows: 3,
                              columns: 3,
                              dotSize: 3.5,
                              spacing: 4.5,
                            ),
                          ),
                        ),

                        // Main Scrollable Content (Takes only the exact height needed)
                        ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              20,
                              12,
                              20,
                              20 + bottomPadding,
                            ),
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
                                      color: AppColors.ink,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Title & Close Button Header Row
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Center(
                                      child: Text(
                                        'Quét từ vựng qua ảnh',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'Fredoka',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.ink,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      child: NeoCloseButton(
                                        onTap: () {
                                          if (Navigator.of(context).canPop()) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Dynamic Image Preview & Labeled Result Widget
                                _buildImagePreviewWidget(),

                                // 2 Main Action Cards: "CHỤP ẢNH THÔ" & "TẢI ẢNH LÊN"
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(2, 4, 8, 8),
                                  child: Row(
                                    children: [
                                      // Option 1: Chụp ảnh thô
                                      Expanded(
                                        child: _buildMainActionButton(
                                          buttonKey:
                                              const Key('pick-camera-button'),
                                          label: 'CHỤP ẢNH THÔ',
                                          backgroundColor: AppColors.yellow,
                                          iconWidget:
                                              const NeoCameraIcon(size: 38),
                                          onTap: _isProcessing
                                              ? null
                                              : _captureAndScan,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Option 2: Tải ảnh lên
                                      Expanded(
                                        child: _buildMainActionButton(
                                          buttonKey:
                                              const Key('pick-gallery-button'),
                                          label: 'TẢI ẢNH LÊN',
                                          backgroundColor: AppColors.mint,
                                          iconWidget:
                                              const NeoPhotoIcon(size: 36),
                                          onTap: _isProcessing
                                              ? null
                                              : () => _pickAndScan(
                                                  ScanImageSource.gallery),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),

                                NoteTemplateSelector(
                                  selectedTemplate: _selectedTemplate,
                                  customStyle: _customLabelStyle,
                                  onTemplateChanged: (template) {
                                    setState(
                                        () => _selectedTemplate = template);
                                  },
                                  onCustomStyleChanged: (style) {
                                    setState(() => _customLabelStyle = style);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
    required Color backgroundColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.ink,
          width: 2.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(
                7.0, 7.0), // Bóng cứng chuẩn 7px không blur lệch xuống phải
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 42,
                  child: Center(child: iconWidget),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
