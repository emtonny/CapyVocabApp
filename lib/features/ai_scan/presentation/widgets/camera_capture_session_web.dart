import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

import 'camera_capture_session.dart';

final _infraredCameraNamePattern = RegExp(
  r'(^|[^a-z0-9])ir([^a-z0-9]|$)|infrared|windows\s*hello',
  caseSensitive: false,
);

class BrowserCameraCaptureSession implements CameraCaptureSession {
  BrowserCameraCaptureSession()
      : _viewType = 'capy-web-camera-${_nextViewId++}';

  static int _nextViewId = 0;

  final String _viewType;
  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  List<WebCameraDevice> _devices = const [];
  WebCameraDevice? _selectedDevice;
  double _aspectRatio = 4 / 3;
  bool _viewFactoryRegistered = false;

  @override
  double get aspectRatio => _aspectRatio;

  @override
  List<WebCameraDevice> get devices => _devices;

  @override
  WebCameraDevice? get selectedDevice => _selectedDevice;

  @override
  Future<void> initialize({String? deviceId}) async {
    await dispose();

    try {
      var stream = await _openStream(deviceId);
      _stream = stream;
      var devices = await _loadVideoDevices();
      var activeDevice = _resolveActiveDevice(stream, devices, deviceId);

      if (deviceId == null &&
          activeDevice != null &&
          _infraredCameraNamePattern.hasMatch(activeDevice.label)) {
        final regularDevice = devices.cast<WebCameraDevice?>().firstWhere(
              (device) =>
                  device != null &&
                  !_infraredCameraNamePattern.hasMatch(device.label),
              orElse: () => null,
            );
        if (regularDevice != null &&
            regularDevice.deviceId != activeDevice.deviceId) {
          _stopStream(stream);
          _stream = null;
          stream = await _openStream(regularDevice.deviceId);
          _stream = stream;
          devices = await _loadVideoDevices();
          activeDevice = _resolveActiveDevice(
            stream,
            devices,
            regularDevice.deviceId,
          );
        }
      }

      final video = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..playsInline = true
        ..srcObject = stream
        ..setAttribute('aria-label', 'Camera preview');
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain'
        ..backgroundColor = 'black'
        // HtmlElementView participates in the DOM hit-test above Flutter's
        // canvas. The preview is display-only, so pointer events must pass
        // through to the capture/close/dropdown controls drawn by Flutter.
        ..pointerEvents = 'none';

      await video.play().toDart;

      final width = video.videoWidth;
      final height = video.videoHeight;
      if (width > 0 && height > 0) {
        _aspectRatio = width / height;
      }

      _video = video;
      _devices = devices;
      _selectedDevice = activeDevice;
      _registerViewFactory(video);
    } catch (error) {
      await dispose();
      if (error is CameraCaptureException) rethrow;
      throw _toCameraException(error);
    }
  }

  Future<web.MediaStream> _openStream(String? deviceId) {
    final videoConstraints = deviceId == null
        ? true.toJS
        : web.MediaTrackConstraints(
            deviceId: web.ConstrainDOMStringParameters(
              exact: deviceId.toJS,
            ),
          );
    final constraints = web.MediaStreamConstraints(
      video: videoConstraints,
      audio: false.toJS,
    );
    return web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
  }

  Future<List<WebCameraDevice>> _loadVideoDevices() async {
    final mediaDevices =
        await web.window.navigator.mediaDevices.enumerateDevices().toDart;
    final videoInputs = mediaDevices.toDart
        .where((device) => device.kind == 'videoinput')
        .toList();

    return [
      for (var index = 0; index < videoInputs.length; index++)
        WebCameraDevice(
          deviceId: videoInputs[index].deviceId,
          label: videoInputs[index].label.trim().isEmpty
              ? 'Camera ${index + 1}'
              : videoInputs[index].label.trim(),
        ),
    ];
  }

  WebCameraDevice? _resolveActiveDevice(
    web.MediaStream stream,
    List<WebCameraDevice> devices,
    String? requestedDeviceId,
  ) {
    final tracks = stream.getVideoTracks().toDart;
    if (tracks.isEmpty) {
      throw const CameraCaptureException(
        'NotFoundError',
        'No video track was returned by getUserMedia.',
      );
    }

    final activeDeviceId =
        requestedDeviceId ?? tracks.first.getSettings().deviceId;
    for (final device in devices) {
      if (device.deviceId == activeDeviceId) return device;
    }
    return devices.isEmpty ? null : devices.first;
  }

  void _registerViewFactory(web.HTMLVideoElement video) {
    if (_viewFactoryRegistered) return;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId, {Object? params}) => video,
    );
    _viewFactoryRegistered = true;
  }

  @override
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  @override
  Future<XFile> takePicture() async {
    final video = _video;
    if (video == null || video.videoWidth <= 0 || video.videoHeight <= 0) {
      throw const CameraCaptureException(
        'InvalidStateError',
        'Camera preview is not ready.',
      );
    }

    try {
      final canvas = web.HTMLCanvasElement()
        ..width = video.videoWidth
        ..height = video.videoHeight;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (context == null) {
        throw const CameraCaptureException(
          'CanvasError',
          'Could not create a 2D canvas context.',
        );
      }
      context.drawImage(video, 0, 0, canvas.width, canvas.height);

      final blob = await _canvasToJpegBlob(canvas);
      final buffer = await blob.arrayBuffer().toDart;
      final bytes = Uint8List.fromList(buffer.toDart.asUint8List());
      return XFile.fromData(
        bytes,
        name: 'camera-${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
      );
    } catch (error) {
      if (error is CameraCaptureException) rethrow;
      throw _toCameraException(error);
    }
  }

  Future<web.Blob> _canvasToJpegBlob(web.HTMLCanvasElement canvas) {
    final completer = Completer<web.Blob>();
    canvas.toBlob(
      ((web.Blob? blob) {
        if (blob == null) {
          completer.completeError(
            const CameraCaptureException(
              'EncodingError',
              'The browser could not encode the captured frame.',
            ),
          );
        } else {
          completer.complete(blob);
        }
      }).toJS,
      'image/jpeg',
      0.92.toJS,
    );
    return completer.future;
  }

  CameraCaptureException _toCameraException(Object error) {
    final text = error.toString();
    final browserError = RegExp(r'^([A-Za-z]+Error):\s*(.*)$').firstMatch(text);
    if (browserError != null) {
      return CameraCaptureException(
        browserError.group(1)!,
        browserError.group(2)!.trim(),
      );
    }
    return CameraCaptureException('UnknownError', text);
  }

  void _stopStream(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  @override
  Future<void> dispose() async {
    final video = _video;
    _video = null;
    if (video != null) {
      video.pause();
      video.srcObject = null;
    }

    final stream = _stream;
    _stream = null;
    if (stream != null) _stopStream(stream);

    _devices = const [];
    _selectedDevice = null;
  }
}

CameraCaptureSession createWebCameraCaptureSession() {
  return BrowserCameraCaptureSession();
}
