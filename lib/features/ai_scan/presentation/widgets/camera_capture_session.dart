import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

class WebCameraDevice {
  const WebCameraDevice({required this.deviceId, required this.label});

  final String deviceId;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is WebCameraDevice && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

class CameraCaptureException implements Exception {
  const CameraCaptureException(this.code, [this.description]);

  final String code;
  final String? description;

  @override
  String toString() => description == null ? code : '$code: $description';
}

abstract interface class CameraCaptureSession {
  double get aspectRatio;

  List<WebCameraDevice> get devices;

  WebCameraDevice? get selectedDevice;

  Future<void> initialize({String? deviceId});

  Widget buildPreview();

  Future<XFile> takePicture();

  Future<void> dispose();
}

typedef CameraCaptureSessionFactory = CameraCaptureSession Function();
