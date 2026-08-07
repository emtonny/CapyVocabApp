import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

typedef CameraListLoader = Future<List<CameraDescription>> Function();
typedef CameraCaptureSessionFactory = CameraCaptureSession Function(
  CameraDescription description,
);

abstract interface class CameraCaptureSession {
  double get aspectRatio;

  Future<void> initialize();

  Widget buildPreview();

  Future<XFile> takePicture();

  Future<void> dispose();
}

class PluginCameraCaptureSession implements CameraCaptureSession {
  PluginCameraCaptureSession(CameraDescription description)
      : _controller = CameraController(
          description,
          ResolutionPreset.medium,
          enableAudio: false,
        );

  final CameraController _controller;

  @override
  double get aspectRatio => _controller.value.aspectRatio;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<XFile> takePicture() => _controller.takePicture();

  @override
  Future<void> dispose() => _controller.dispose();
}

CameraCaptureSession createPluginCameraCaptureSession(
  CameraDescription description,
) {
  return PluginCameraCaptureSession(description);
}

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({
    super.key,
    this.loadCameras = availableCameras,
    this.createSession = createPluginCameraCaptureSession,
  });

  final CameraListLoader loadCameras;
  final CameraCaptureSessionFactory createSession;

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

enum _CameraErrorKind { permissionDenied, noCamera, unavailable }

final _infraredCameraNamePattern = RegExp(
  r'(^|[^a-z0-9])ir([^a-z0-9]|$)|infrared|windows\s*hello',
  caseSensitive: false,
);

class _CameraCaptureViewState extends State<CameraCaptureView> {
  CameraCaptureSession? _session;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  _CameraErrorKind? _errorKind;
  String? _errorMessage;
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  int _initializationAttempt = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera([CameraDescription? requestedCamera]) async {
    final attempt = ++_initializationAttempt;
    await _disposeSession();
    if (!mounted || attempt != _initializationAttempt) return;

    setState(() {
      _isInitializing = true;
      _errorKind = null;
      _errorMessage = null;
    });

    try {
      // Web camera access requires a secure context. Browsers allow localhost
      // during development, but a deployed domain MUST use HTTPS or camera
      // permission/getUserMedia will fail.
      final cameras =
          requestedCamera == null ? await widget.loadCameras() : _cameras;
      if (!mounted || attempt != _initializationAttempt) return;

      if (requestedCamera == null) {
        for (var index = 0; index < cameras.length; index++) {
          debugPrint('Available camera [$index]: ${cameras[index].name}');
        }
      }

      if (cameras.isEmpty) {
        setState(() {
          _cameras = const [];
          _selectedCamera = null;
        });
        _showError(
          _CameraErrorKind.noCamera,
          'Không tìm thấy camera trên thiết bị này. '
          'Vui lòng đóng màn hình và dùng "Chọn từ thư viện" thay thế.',
        );
        return;
      }

      final selectedCamera = requestedCamera ?? _chooseDefaultCamera(cameras);
      setState(() {
        _cameras = cameras;
        _selectedCamera = selectedCamera;
      });

      final session = widget.createSession(selectedCamera);
      _session = session;
      await session.initialize();

      if (!mounted || attempt != _initializationAttempt) {
        if (identical(_session, session)) {
          _session = null;
          await session.dispose();
        }
        return;
      }

      setState(() => _isInitializing = false);
    } on CameraException catch (error) {
      _logCameraException('initialize', error);
      if (!mounted || attempt != _initializationAttempt) return;
      await _disposeSession();
      if (!mounted || attempt != _initializationAttempt) return;

      if (_isPermissionError(error.code)) {
        _showError(
          _CameraErrorKind.permissionDenied,
          'Cần cấp quyền camera để chụp ảnh.',
        );
      } else {
        _showError(
          _CameraErrorKind.unavailable,
          _cameraErrorMessage('Không thể mở camera', error),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unexpected camera initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || attempt != _initializationAttempt) return;
      await _disposeSession();
      if (!mounted || attempt != _initializationAttempt) return;
      _showError(
        _CameraErrorKind.unavailable,
        'Không thể mở camera. Vui lòng thử lại.',
      );
    }
  }

  CameraDescription _chooseDefaultCamera(List<CameraDescription> cameras) {
    final regularCameras = cameras
        .where((camera) => !_infraredCameraNamePattern.hasMatch(camera.name))
        .toList();
    return regularCameras.isNotEmpty ? regularCameras.first : cameras.last;
  }

  void _selectCamera(CameraDescription? camera) {
    if (camera == null || camera == _selectedCamera || _isInitializing) return;
    unawaited(_initializeCamera(camera));
  }

  bool _isPermissionError(String code) {
    final normalized = code.toLowerCase();
    return normalized.contains('denied') ||
        normalized.contains('permission') ||
        normalized.contains('access') ||
        normalized.contains('notallowed');
  }

  void _logCameraException(String operation, CameraException error) {
    debugPrint(
      'Camera $operation failed: '
      'code=${error.code}, description=${error.description ?? '(none)'}',
    );
  }

  String _cameraErrorMessage(String prefix, CameraException error) {
    final description = error.description?.trim();
    final detail = description == null || description.isEmpty
        ? error.code
        : '${error.code}: $description';
    return '$prefix ($detail). Vui lòng thử lại.';
  }

  void _showError(_CameraErrorKind kind, String message) {
    if (!mounted) return;
    setState(() {
      _errorKind = kind;
      _errorMessage = message;
      _isInitializing = false;
    });
  }

  Future<void> _takePicture() async {
    final session = _session;
    if (session == null || _isTakingPicture) return;

    setState(() {
      _isTakingPicture = true;
      _errorMessage = null;
    });

    try {
      final image = await session.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(image);
    } on CameraException catch (error) {
      _logCameraException('capture', error);
      if (!mounted) return;
      setState(() {
        _isTakingPicture = false;
        _errorMessage = _cameraErrorMessage('Không thể chụp ảnh', error);
      });
    } catch (error, stackTrace) {
      debugPrint('Unexpected camera capture error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isTakingPicture = false;
        _errorMessage = 'Không thể chụp ảnh. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _disposeSession() async {
    final session = _session;
    _session = null;
    if (session != null) {
      await session.dispose();
    }
  }

  void _close() => Navigator.of(context).pop();

  @override
  void dispose() {
    _initializationAttempt++;
    final session = _session;
    _session = null;
    if (session != null) {
      unawaited(session.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isInitializing)
              const Center(
                child: CircularProgressIndicator(
                  key: Key('web-camera-loading'),
                ),
              )
            else if (_errorKind != null || session == null)
              _CameraErrorContent(
                kind: _errorKind ?? _CameraErrorKind.unavailable,
                message: _errorMessage ?? 'Không thể mở camera.',
                onRetry: () => unawaited(_initializeCamera()),
                onClose: _close,
              )
            else ...[
              Center(
                child: AspectRatio(
                  aspectRatio: session.aspectRatio,
                  child: session.buildPreview(),
                ),
              ),
              if (_errorMessage case final message?)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 128,
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Chụp',
                      child: IconButton.filled(
                        key: const Key('web-camera-capture-button'),
                        onPressed: _isTakingPicture ? null : _takePicture,
                        tooltip: 'Chụp',
                        iconSize: 38,
                        padding: const EdgeInsets.all(18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white54,
                        ),
                        icon: _isTakingPicture
                            ? const SizedBox.square(
                                dimension: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chụp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filledTonal(
                key: const Key('web-camera-close-button'),
                onPressed: _close,
                tooltip: 'Hủy/Đóng',
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (_cameras.length > 1)
              Positioned(
                top: 8,
                left: 64,
                right: 8,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CameraDescription>(
                        key: const Key('camera-device-dropdown'),
                        value: _selectedCamera,
                        isExpanded: true,
                        dropdownColor: Colors.grey.shade900,
                        iconEnabledColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        onChanged: _isInitializing ? null : _selectCamera,
                        items: [
                          for (final camera in _cameras)
                            DropdownMenuItem(
                              value: camera,
                              child: Text(
                                camera.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
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
}

class _CameraErrorContent extends StatelessWidget {
  const _CameraErrorContent({
    required this.kind,
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final _CameraErrorKind kind;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final canRetry = kind != _CameraErrorKind.noCamera;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind == _CameraErrorKind.permissionDenied
                  ? Icons.no_photography_rounded
                  : Icons.videocam_off_rounded,
              size: 72,
              color: Colors.white70,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              key: const Key('web-camera-error-message'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (canRetry)
              FilledButton.icon(
                key: const Key('web-camera-retry-button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            if (canRetry) const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('web-camera-error-close-button'),
              onPressed: onClose,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: Text(
                kind == _CameraErrorKind.noCamera
                    ? 'Đóng để chọn từ thư viện'
                    : 'Hủy/Đóng',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
