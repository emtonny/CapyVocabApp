import 'dart:async';
import 'dart:typed_data';

import 'package:capy_vocab/features/ai_scan/presentation/widgets/camera_capture_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

const _cameraDevice = WebCameraDevice(
  deviceId: 'webcam-1',
  label: 'Integrated RGB Camera',
);

const _infraredCameraDevice = WebCameraDevice(
  deviceId: 'webcam-ir',
  label: 'Integrated IR Camera',
);

void main() {
  testWidgets('hiển thị preview, chụp XFile và dispose khi đóng route',
      (tester) async {
    final session = _FakeCameraCaptureSession(
      devices: const [_cameraDevice],
      selectedDevice: _cameraDevice,
    );
    XFile? capturedImage;

    await tester.pumpWidget(
      MaterialApp(
        home: _CameraTestHost(
          onCaptured: (image) => capturedImage = image,
          cameraView: CameraCaptureView(createSession: () => session),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-web-camera')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-live-preview')), findsOneWidget);
    expect(session.initializeCalls, 1);

    await tester.tap(find.byKey(const Key('web-camera-capture-button')));
    await tester.pumpAndSettle();

    expect(capturedImage, isNotNull);
    expect(await capturedImage!.readAsBytes(), orderedEquals([1, 2, 3]));
    expect(session.takePictureCalls, 1);
    expect(session.disposeCalls, 1);
  });

  testWidgets('từ chối quyền hiển thị thông báo rõ và thử lại được',
      (tester) async {
    var createCalls = 0;
    final successfulSession = _FakeCameraCaptureSession(
      devices: const [_cameraDevice],
      selectedDevice: _cameraDevice,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          createSession: () {
            createCalls++;
            if (createCalls == 1) {
              return _FakeCameraCaptureSession(
                onInitialize: (deviceId) async =>
                    throw const CameraCaptureException(
                  'NotAllowedError',
                  'Permission denied',
                ),
              );
            }
            return successfulSession;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cần cấp quyền camera để chụp ảnh.'), findsOneWidget);
    expect(find.byKey(const Key('web-camera-retry-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('web-camera-retry-button')));
    await tester.pumpAndSettle();

    expect(createCalls, 2);
    expect(find.byKey(const Key('fake-live-preview')), findsOneWidget);
  });

  testWidgets('không có camera gợi ý dùng thư viện và không hiện thử lại',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          createSession: () => _FakeCameraCaptureSession(
            onInitialize: (deviceId) async =>
                throw const CameraCaptureException(
              'NotFoundError',
              'No camera found',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('dùng "Chọn từ thư viện" thay thế'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('web-camera-retry-button')), findsNothing);
    expect(find.text('Đóng để chọn từ thư viện'), findsOneWidget);
  });

  testWidgets('lỗi kỹ thuật hiển thị mã và mô tả lỗi browser thật',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          createSession: () => _FakeCameraCaptureSession(
            onInitialize: (deviceId) async =>
                throw const CameraCaptureException(
              'OverconstrainedError',
              'Requested resolution is not supported',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'OverconstrainedError: Requested resolution is not supported',
      ),
      findsOneWidget,
    );
  });

  testWidgets('đóng khi đang khởi tạo vẫn dispose session đúng một lần',
      (tester) async {
    final initialization = Completer<void>();
    final session = _FakeCameraCaptureSession(
      onInitialize: (deviceId) => initialization.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _CameraTestHost(
          cameraView: CameraCaptureView(createSession: () => session),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-web-camera')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('web-camera-close-button')));
    await tester.pumpAndSettle();

    initialization.complete();
    await tester.pump();

    expect(session.disposeCalls, 1);
  });

  testWidgets('log thiết bị và cho phép đổi camera', (tester) async {
    final debugMessages = <String>[];
    final originalDebugPrint = debugPrint;
    final sessions = <_FakeCameraCaptureSession>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) debugMessages.add(message);
    };

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: CameraCaptureView(
            createSession: () {
              final session = _FakeCameraCaptureSession(
                devices: const [_infraredCameraDevice, _cameraDevice],
                selectedDevice: _cameraDevice,
              );
              sessions.add(session);
              return session;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      debugPrint = originalDebugPrint;
    }

    expect(
      debugMessages,
      containsAll([
        'Available camera [0]: Integrated IR Camera',
        'Available camera [1]: Integrated RGB Camera',
      ]),
    );
    expect(find.byKey(const Key('camera-device-dropdown')), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera-device-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Integrated IR Camera').last);
    await tester.pumpAndSettle();

    expect(sessions, hasLength(2));
    expect(sessions.first.disposeCalls, 1);
    expect(sessions.last.requestedDeviceId, _infraredCameraDevice.deviceId);
    expect(sessions.last.initializeCalls, 1);
  });
}

class _CameraTestHost extends StatefulWidget {
  const _CameraTestHost({required this.cameraView, this.onCaptured});

  final Widget cameraView;
  final ValueChanged<XFile>? onCaptured;

  @override
  State<_CameraTestHost> createState() => _CameraTestHostState();
}

class _CameraTestHostState extends State<_CameraTestHost> {
  String? _capturedName;

  Future<void> _openCamera() async {
    final image = await Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(builder: (context) => widget.cameraView),
    );
    if (!mounted || image == null) return;
    widget.onCaptured?.call(image);
    setState(() => _capturedName = image.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            key: const Key('open-web-camera'),
            onPressed: _openCamera,
            child: const Text('Open camera'),
          ),
          if (_capturedName case final name?) Text('Captured: $name'),
        ],
      ),
    );
  }
}

class _FakeCameraCaptureSession implements CameraCaptureSession {
  _FakeCameraCaptureSession({
    this.onInitialize,
    this.devices = const [],
    WebCameraDevice? selectedDevice,
  }) : _selectedDevice = selectedDevice;

  final Future<void> Function(String? deviceId)? onInitialize;
  @override
  final List<WebCameraDevice> devices;
  WebCameraDevice? _selectedDevice;
  String? requestedDeviceId;
  int initializeCalls = 0;
  int takePictureCalls = 0;
  int disposeCalls = 0;

  @override
  double get aspectRatio => 4 / 3;

  @override
  WebCameraDevice? get selectedDevice => _selectedDevice;

  @override
  Future<void> initialize({String? deviceId}) async {
    initializeCalls++;
    requestedDeviceId = deviceId;
    await onInitialize?.call(deviceId);
    if (deviceId != null) {
      _selectedDevice = null;
      for (final device in devices) {
        if (device.deviceId == deviceId) {
          _selectedDevice = device;
          break;
        }
      }
    }
  }

  @override
  Widget buildPreview() {
    return const ColoredBox(
      key: Key('fake-live-preview'),
      color: Colors.blue,
    );
  }

  @override
  Future<XFile> takePicture() async {
    takePictureCalls++;
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'captured.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
