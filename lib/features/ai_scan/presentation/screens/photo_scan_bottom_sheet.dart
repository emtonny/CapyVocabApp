import 'dart:typed_data';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/scan_image_compressor.dart';
import '../../data/services/scan_image_picker.dart';
import '../controllers/scan_flow_controller.dart';
import '../providers/scan_provider.dart';
import '../widgets/camera_capture_view.dart';
import '../widgets/scan_loading_overlay.dart';

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

  @override
  ConsumerState<PhotoScanBottomSheet> createState() =>
      _PhotoScanBottomSheetState();
}

class _PhotoScanBottomSheetState extends ConsumerState<PhotoScanBottomSheet> {
  Uint8List? _previewBytes;
  bool _isProcessing = false;
  String _processingStatus = 'Đang chuẩn bị ảnh...';

  Future<void> _pickAndScan(
    ScanImageSource source, {
    Future<PickedScanImage?> Function()? pickOverride,
  }) async {
    if (_isProcessing) return;

    try {
      final pickedImage = pickOverride == null
          ? await ref.read(scanImagePickerProvider).pick(source)
          : await pickOverride();
      if (pickedImage == null || !mounted) return;

      setState(() {
        _previewBytes = pickedImage.bytes;
        _isProcessing = true;
        _processingStatus = 'Đang nén ảnh...';
      });

      final compressedBytes = await ref
          .read(scanImageCompressorProvider)
          .compress(pickedImage.bytes);
      if (!mounted) return;

      setState(() {
        _previewBytes = compressedBytes;
        _processingStatus = 'Đang nhận diện từ vựng...';
      });

      final localPath =
          await ref.read(scanImageStorageProvider).saveJpeg(compressedBytes);
      if (!mounted) return;

      await ScanFlowController.scanAndNavigate(
        context,
        ref,
        localPath: localPath,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is ScanImagePreparationException
          ? error.message
          : source == ScanImageSource.camera
              ? 'Không thể mở camera. Vui lòng kiểm tra quyền truy cập.'
              : 'Không thể chọn ảnh. Vui lòng thử lại.';
      await _showPreparationError(message);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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

    // Mobile keeps image_picker so the native OS camera experience remains
    // unchanged (ScanImageSource.camera -> ImageSource.camera).
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

  @override
  Widget build(BuildContext context) {
    final previewBytes = _previewBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Quét ảnh từ vựng')),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: previewBytes == null
                            ? const Center(
                                child: Icon(
                                  Icons.image_search_rounded,
                                  size: 64,
                                ),
                              )
                            : Image.memory(
                                previewBytes,
                                key: const Key('scan-image-preview'),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('pick-gallery-button'),
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndScan(ScanImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn từ thư viện'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('pick-camera-button'),
                    onPressed: _isProcessing ? null : _captureAndScan,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ],
              ),
            ),
            if (_isProcessing)
              Positioned.fill(
                child: ScanLoadingOverlay(status: _processingStatus),
              ),
          ],
        ),
      ),
    );
  }
}
