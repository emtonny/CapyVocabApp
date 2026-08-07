import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/camera_capture_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cameraDescription = CameraDescription(
  name: 'webcam-1',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);

const _infraredCameraDescription = CameraDescription(
  name: 'Integrated IR Camera',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);

const _rgbCameraDescription = CameraDescription(
  name: 'Integrated RGB Camera',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);

void main() {
  testWidgets('hiển thị preview, chụp XFile và dispose khi đóng route',
      (tester) async {
    final session = _FakeCameraCaptureSession();
    XFile? capturedImage;

    await tester.pumpWidget(
      MaterialApp(
        home: _CameraTestHost(
          onCaptured: (image) => capturedImage = image,
          cameraView: CameraCaptureView(
            loadCameras: () async => const [_cameraDescription],
            createSession: (description) {
              expect(description, _cameraDescription);
              return session;
            },
          ),
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
    var loadCalls = 0;
    final session = _FakeCameraCaptureSession();

    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          loadCameras: () async {
            loadCalls++;
            if (loadCalls == 1) {
              throw CameraException('NotAllowedError', 'Permission denied');
            }
            return const [_cameraDescription];
          },
          createSession: (description) => session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cần cấp quyền camera để chụp ảnh.'), findsOneWidget);
    expect(find.byKey(const Key('web-camera-retry-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('web-camera-retry-button')));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.byKey(const Key('fake-live-preview')), findsOneWidget);
  });

  testWidgets('không có camera gợi ý dùng thư viện và không hiện thử lại',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          loadCameras: () async => const [],
          createSession: (description) => _FakeCameraCaptureSession(),
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

  testWidgets('lỗi kỹ thuật hiển thị mã và mô tả CameraException thật',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          loadCameras: () async => throw CameraException(
            'OverconstrainedError',
            'Requested resolution is not supported',
          ),
          createSession: (description) => _FakeCameraCaptureSession(),
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
      onInitialize: () => initialization.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _CameraTestHost(
          cameraView: CameraCaptureView(
            loadCameras: () async => const [_cameraDescription],
            createSession: (description) => session,
          ),
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

  testWidgets('log camera, bỏ qua IR và cho phép chọn camera khác',
      (tester) async {
    final debugMessages = <String>[];
    final originalDebugPrint = debugPrint;
    final sessions = <CameraDescription, _FakeCameraCaptureSession>{};
    debugPrint = (message, {wrapWidth}) {
      if (message != null) debugMessages.add(message);
    };

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: CameraCaptureView(
            loadCameras: () async => const [
              _infraredCameraDescription,
              _rgbCameraDescription,
            ],
            createSession: (description) => sessions.putIfAbsent(
              description,
              _FakeCameraCaptureSession.new,
            ),
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
    expect(sessions[_infraredCameraDescription], isNull);
    expect(sessions[_rgbCameraDescription]?.initializeCalls, 1);
    expect(find.byKey(const Key('camera-device-dropdown')), findsOneWidget);

    await tester.tap(find.byKey(const Key('camera-device-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Integrated IR Camera').last);
    await tester.pumpAndSettle();

    expect(sessions[_rgbCameraDescription]?.disposeCalls, 1);
    expect(sessions[_infraredCameraDescription]?.initializeCalls, 1);
  });

  testWidgets('fallback camera cuối khi mọi tên đều giống camera IR',
      (tester) async {
    const windowsHelloCamera = CameraDescription(
      name: 'Windows Hello Camera',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    );
    CameraDescription? initializedCamera;

    await tester.pumpWidget(
      MaterialApp(
        home: CameraCaptureView(
          loadCameras: () async => const [
            _infraredCameraDescription,
            windowsHelloCamera,
          ],
          createSession: (description) {
            initializedCamera = description;
            return _FakeCameraCaptureSession();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(initializedCamera, windowsHelloCamera);
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
  _FakeCameraCaptureSession({this.onInitialize});

  final Future<void> Function()? onInitialize;
  int initializeCalls = 0;
  int takePictureCalls = 0;
  int disposeCalls = 0;

  @override
  double get aspectRatio => 4 / 3;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    await onInitialize?.call();
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
