import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/core/constants/app_colors.dart';
import 'package:capy_vocab/core/entitlements/entitlement_provider.dart';
import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_compressor.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_picker.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage.dart';
import 'package:capy_vocab/features/ai_scan/presentation/label_visual_style.dart';
import 'package:capy_vocab/features/ai_scan/presentation/providers/scan_provider.dart';
import 'package:capy_vocab/features/ai_scan/presentation/screens/photo_scan_bottom_sheet.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/scan_paper_background.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/vocab_canvas_overlay.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/scan_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('AI Scan uses its dedicated micro linen-paper background',
      (tester) async {
    await _pumpScreen(
      tester,
      picker: _FakePicker(onPick: (_) async => null),
      compressor: _FakeCompressor(
        onCompress: (_) => throw UnimplementedError(),
      ),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (_, __) => throw UnimplementedError(),
      ),
    );

    expect(find.byType(ScanPaperBackground), findsOneWidget);
    final backgroundPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(ScanPaperBackground),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = backgroundPaint.painter! as ScanPaperBackgroundPainter;

    expect(painter.backgroundColor, AppColors.cream);
    expect(painter.fiberColor, const Color(0xFF887866));
    expect(painter.verticalFiberSpacing, 2.7);
    expect(painter.horizontalFiberSpacing, 3.2);
    expect(painter.secondaryVerticalSpacing, 7.4);
    expect(painter.secondaryHorizontalSpacing, 8.6);
    expect(
      painter.verticalFiberOpacity,
      greaterThan(painter.horizontalFiberOpacity),
    );
    expect(painter.verticalFiberOpacity, inInclusiveRange(0.05, 0.08));
    expect(painter.horizontalFiberOpacity, inInclusiveRange(0.05, 0.08));
    expect(painter.secondaryFiberOpacity, lessThan(0.04));
  });

  test('device picker ánh xạ đúng gallery và camera sang image_picker',
      () async {
    final imagePicker = _FakeDeviceImagePicker();
    final picker = DeviceScanImagePicker(imagePicker: imagePicker);

    await picker.pick(ScanImageSource.gallery);
    await picker.pick(ScanImageSource.camera);

    expect(
      imagePicker.sources,
      [ImageSource.gallery, ImageSource.camera],
    );
    expect(imagePicker.requestFullMetadataValues, [false, false]);
  });

  testWidgets('chọn ảnh, nén, lưu tạm, scan rồi mở overlay', (tester) async {
    final sourceBytes = _testImageBytes();
    final compressedBytes = _testImageBytes();
    final compression = Completer<Uint8List>();
    final vision = Completer<GeminiVisionResult>();
    final picker = _FakePicker(
      onPick: (source) async => PickedScanImage(
        bytes: sourceBytes,
        name: 'source.png',
      ),
    );
    final compressor = _FakeCompressor(
      onCompress: (bytes) {
        expect(bytes, same(sourceBytes));
        return compression.future;
      },
    );
    final storage = _FakeStorage();
    final visionClient = _FakeVisionClient(
      onAnalyze: (bytes, requestId) {
        expect(bytes, same(compressedBytes));
        return vision.future;
      },
    );

    await _pumpScreen(
      tester,
      picker: picker,
      compressor: compressor,
      storage: storage,
      visionClient: visionClient,
      debugIsWebOverride: true,
    );

    final galleryButton = find.byKey(const Key('pick-gallery-button'));
    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pump();

    expect(picker.lastSource, ScanImageSource.gallery);
    expect(find.byKey(const Key('scan-image-preview')), findsOneWidget);
    expect(find.byType(ScanLoadingOverlay), findsOneWidget);
    expect(find.text('Đang nén ảnh...'), findsOneWidget);

    compression.complete(compressedBytes);
    await tester.pump();
    await tester.pump();

    expect(storage.savedBytes, same(compressedBytes));
    expect(find.text('Đang nhận diện từ vựng...'), findsOneWidget);

    const result = GeminiVisionResult(detectedVocabulary: []);
    vision.complete(result);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('zoom-image-button')), findsOneWidget);
    expect(storage.deletedPaths, isEmpty);
  });

  testWidgets('nút Chụp ảnh dùng camera source', (tester) async {
    final picker = _FakePicker(onPick: (source) async => null);
    await _pumpScreen(
      tester,
      picker: picker,
      compressor: _FakeCompressor(
        onCompress: (bytes) => throw UnimplementedError(),
      ),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (bytes, requestId) => throw UnimplementedError(),
      ),
      debugIsWebOverride: false,
    );

    final cameraButton = find.byKey(const Key('pick-camera-button'));
    await tester.ensureVisible(cameraButton);
    await tester.tap(cameraButton);
    await tester.pump();

    expect(picker.lastSource, ScanImageSource.camera);
    expect(find.byType(ScanLoadingOverlay), findsNothing);
  });

  testWidgets('template Tự thiết kế đọc capability Free từ provider', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      picker: _FakePicker(onPick: (_) async => null),
      compressor: _FakeCompressor(onCompress: (_) async => _testImageBytes()),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (_, __) async => const GeminiVisionResult(
          detectedVocabulary: [],
        ),
      ),
    );

    final customTemplate = find.byKey(const Key('label-template-custom'));
    await tester.ensureVisible(customTemplate);
    await tester.tap(customTemplate);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('label-template-pro-limit-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('custom-label-editor')), findsNothing);
  });

  testWidgets('template Tự thiết kế mở cho capability Pro từ provider', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 1);
    final entitlements = EntitlementNotifier(
      initialUserId: 'pro-user',
      authUserIds: const Stream.empty(),
      loadActiveSubscription: (_) async => {
        'plan_type': 'capy_pro_monthly',
        'end_date': now.add(const Duration(days: 30)).toIso8601String(),
      },
      now: () => now,
    );
    await entitlements.refresh();

    await _pumpScreen(
      tester,
      picker: _FakePicker(onPick: (_) async => null),
      compressor: _FakeCompressor(onCompress: (_) async => _testImageBytes()),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (_, __) async => const GeminiVisionResult(
          detectedVocabulary: [],
        ),
      ),
      entitlementNotifier: entitlements,
    );

    final customTemplate = find.byKey(const Key('label-template-custom'));
    await tester.ensureVisible(customTemplate);
    await tester.tap(customTemplate);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('custom-label-editor')), findsOneWidget);
    expect(
      find.byKey(const Key('label-template-pro-limit-dialog')),
      findsNothing,
    );
  });

  testWidgets(
      'lỗi Gemini từ scanProvider được phân loại là lỗi quét, không phải picker',
      (tester) async {
    final storage = _FakeStorage();
    await _pumpScreen(
      tester,
      picker: _FakePicker(
        onPick: (source) async => PickedScanImage(
          bytes: _testImageBytes(),
          name: 'source.png',
        ),
      ),
      compressor: _FakeCompressor(onCompress: (source) async => source),
      storage: storage,
      visionClient: _FakeVisionClient(
        onAnalyze: (source, requestId) async =>
            throw const GeminiQuotaException(
          'Hệ thống đang bận, thử lại sau',
        ),
      ),
    );

    final galleryButton = find.byKey(const Key('pick-gallery-button'));
    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Không thể quét ảnh'), findsOneWidget);
    expect(find.text('Hệ thống đang bận, thử lại sau'), findsOneWidget);
    expect(find.text('Không thể chọn ảnh. Vui lòng thử lại.'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Đóng'));
    await tester.pumpAndSettle();

    expect(storage.deletedPaths, ['memory://scan.jpg']);
  });

  testWidgets('lỗi dọn ảnh không che lỗi scan gốc', (tester) async {
    final storage = _FakeStorage(
      onDelete: (_) async => throw StateError('cleanup failed'),
    );
    await _pumpScreen(
      tester,
      picker: _FakePicker(
        onPick: (_) async => PickedScanImage(
          bytes: _testImageBytes(),
          name: 'source.png',
        ),
      ),
      compressor: _FakeCompressor(onCompress: (source) async => source),
      storage: storage,
      visionClient: _FakeVisionClient(
        onAnalyze: (_, __) async => throw const GeminiQuotaException(
          'Lỗi scan gốc',
        ),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('pick-gallery-button')));
    await tester.tap(find.byKey(const Key('pick-gallery-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Lỗi scan gốc'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Đóng'));
    await tester.pumpAndSettle();

    expect(storage.deletedPaths, ['memory://scan.jpg']);
    expect(find.byType(ScanLoadingOverlay), findsNothing);
  });

  testWidgets('chọn ảnh lần hai xóa preview cũ trước khi picker hoàn tất',
      (tester) async {
    var pickCount = 0;
    final secondPick = Completer<PickedScanImage?>();
    await _pumpScreen(
      tester,
      picker: _FakePicker(
        onPick: (source) {
          pickCount++;
          if (pickCount == 1) {
            return Future.value(
              PickedScanImage(
                bytes: _testImageBytes(),
                name: 'first.png',
              ),
            );
          }
          return secondPick.future;
        },
      ),
      compressor: _FakeCompressor(onCompress: (source) async => source),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (source, requestId) async => const GeminiVisionResult(
          detectedVocabulary: [],
        ),
      ),
    );

    final galleryButton = find.byKey(const Key('pick-gallery-button'));
    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('scan-image-preview')), findsOneWidget);

    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pump();
    expect(find.byKey(const Key('scan-image-preview')), findsNothing);

    secondPick.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('picker ném lỗi được giữ đúng loại và hiện thông báo picker',
      (tester) async {
    await _pumpScreen(
      tester,
      picker: DeviceScanImagePicker(
        imagePicker: _FakeDeviceImagePicker(
          error: StateError('native picker failed'),
        ),
      ),
      compressor: _FakeCompressor(
        onCompress: (source) => throw UnimplementedError(),
      ),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (source, requestId) => throw UnimplementedError(),
      ),
    );

    final galleryButton = find.byKey(const Key('pick-gallery-button'));
    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pumpAndSettle();

    expect(find.text('Không thể chuẩn bị ảnh'), findsOneWidget);
    expect(find.text('Không thể chọn ảnh. Vui lòng thử lại.'), findsOneWidget);
    expect(find.byType(ScanLoadingOverlay), findsNothing);
  });

  testWidgets('lỗi lưu ảnh giữ đúng thông báo storage và không gọi scan',
      (tester) async {
    var visionCallCount = 0;
    await _pumpScreen(
      tester,
      picker: _FakePicker(
        onPick: (source) async => PickedScanImage(
          bytes: _testImageBytes(),
          name: 'source.png',
        ),
      ),
      compressor: _FakeCompressor(onCompress: (source) async => source),
      storage: _FakeStorage(
        onSave: (bytes) async => throw const ScanImageStorageException(
          'Không thể lưu ảnh quét trên thiết bị.',
        ),
      ),
      visionClient: _FakeVisionClient(
        onAnalyze: (source, requestId) async {
          visionCallCount++;
          return const GeminiVisionResult(detectedVocabulary: []);
        },
      ),
    );

    final galleryButton = find.byKey(const Key('pick-gallery-button'));
    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Không thể lưu ảnh quét trên thiết bị.'), findsOneWidget);
    expect(find.text('Không thể chọn ảnh. Vui lòng thử lại.'), findsNothing);
    expect(visionCallCount, 0);
  });

  testWidgets('mẫu tối giản áp dụng cho preview và fullscreen overlay', (
    tester,
  ) async {
    final bytes = _testImageBytes();
    await _pumpScreen(
      tester,
      picker: _FakePicker(
        onPick: (source) async => PickedScanImage(
          bytes: bytes,
          name: 'source.png',
        ),
      ),
      compressor: _FakeCompressor(onCompress: (source) async => source),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (source, requestId) async => const GeminiVisionResult(
          detectedVocabulary: [
            VocabDetection(
              word: 'apple',
              phonetic: '/ˈæp.əl/',
              meaning: 'quả táo',
              x: 0.1,
              y: 0.2,
              w: 0.3,
              h: 0.2,
            ),
            VocabDetection(
              word: 'basket',
              phonetic: '/ˈbɑː.skɪt/',
              meaning: 'cái giỏ đựng trái cây',
              x: 0.55,
              y: 0.5,
              w: 0.3,
              h: 0.35,
            ),
          ],
        ),
      ),
    );

    await tester.runAsync(
      () => precacheImage(
        MemoryImage(bytes),
        tester.element(find.byType(PhotoScanBottomSheet)),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('pick-gallery-button')));
    await tester.tap(find.byKey(const Key('pick-gallery-button')));
    await tester.pumpAndSettle();

    final minimalTemplate = find.byKey(const Key('label-template-minimal'));
    await tester.ensureVisible(minimalTemplate);
    await tester.tap(minimalTemplate);
    await tester.pumpAndSettle();

    final previewOverlay = find.byKey(const Key('scan-image-preview'));
    final previewPaint = find.descendant(
      of: previewOverlay,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is VocabOverlayPainter,
      ),
    );
    final previewPainter = tester.widget<CustomPaint>(previewPaint).painter!
        as VocabOverlayPainter;
    expect(previewPainter.visualStyle, LabelVisualStyle.minimal);
    expect(previewPainter.visualStyle.connectorHaloColor, Colors.white);
    expect(previewPainter.fullStyleConfig.wordStyle.color, Colors.black);
    expect(previewPainter.fullStyleConfig.meaningStyle.color, Colors.black);
    expect(previewPainter.fullStyleConfig.deerStickerSize, Size.zero);
    expect(previewPainter.fullStyleConfig.cookieIconSize, Size.zero);

    await tester.ensureVisible(find.byKey(const Key('zoom-image-button')));
    await tester.tap(find.byKey(const Key('zoom-image-button')));
    await tester.pumpAndSettle();

    final interactiveViewer = find.byType(InteractiveViewer);
    expect(interactiveViewer, findsOneWidget);
    expect(
      find.descendant(
        of: interactiveViewer,
        matching: find.byType(VocabCanvasOverlay),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: interactiveViewer,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is VocabOverlayPainter,
        ),
      ),
      findsOneWidget,
    );

    final fullscreenPaint = find.descendant(
      of: interactiveViewer,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is VocabOverlayPainter,
      ),
    );
    final fullscreenPainter = tester
        .widget<CustomPaint>(fullscreenPaint)
        .painter! as VocabOverlayPainter;
    expect(fullscreenPainter.visualStyle, LabelVisualStyle.minimal);
    expect(fullscreenPainter.boxes, hasLength(previewPainter.boxes.length));
    for (var index = 0; index < previewPainter.boxes.length; index++) {
      expect(
        _normalizedRect(
          previewPainter.boxes[index],
          previewPainter.imageRect,
        ),
        _rectCloseTo(
          _normalizedRect(
            fullscreenPainter.boxes[index],
            fullscreenPainter.imageRect,
          ),
        ),
      );
      expect(
        previewPainter.imageRect
                .inflate(0.001)
                .contains(previewPainter.boxes[index].topLeft) &&
            previewPainter.imageRect
                .inflate(0.001)
                .contains(previewPainter.boxes[index].bottomRight),
        isTrue,
      );
      expect(
        fullscreenPainter.imageRect
                .inflate(0.001)
                .contains(fullscreenPainter.boxes[index].topLeft) &&
            fullscreenPainter.imageRect
                .inflate(0.001)
                .contains(fullscreenPainter.boxes[index].bottomRight),
        isTrue,
      );
    }
  });

  testWidgets('Web camera trả XFile vào đúng pipeline scan', (tester) async {
    final sourceBytes = _testImageBytes();
    final compressedBytes = _testImageBytes();
    final picker = _FakePicker(
      onPick: (source) => throw StateError(
        'Web camera must not use the image_picker camera branch.',
      ),
    );
    final storage = _FakeStorage();

    await _pumpScreen(
      tester,
      picker: picker,
      compressor: _FakeCompressor(
        onCompress: (bytes) async {
          expect(bytes, orderedEquals(sourceBytes));
          return compressedBytes;
        },
      ),
      storage: storage,
      visionClient: _FakeVisionClient(
        onAnalyze: (bytes, requestId) async {
          expect(bytes, same(compressedBytes));
          return const GeminiVisionResult(detectedVocabulary: []);
        },
      ),
      debugIsWebOverride: true,
      webCameraCaptureBuilder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const Key('fake-web-camera-capture'),
            onPressed: () => Navigator.of(context).pop(
              XFile.fromData(
                sourceBytes,
                name: 'web-camera.jpg',
                mimeType: 'image/jpeg',
              ),
            ),
            child: const Text('Chụp'),
          ),
        ),
      ),
    );

    final cameraButton = find.byKey(const Key('pick-camera-button'));
    await tester.ensureVisible(cameraButton);
    await tester.tap(cameraButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-web-camera-capture')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fake-web-camera-capture')));
    await tester.pumpAndSettle();

    expect(picker.lastSource, isNull);
    expect(storage.savedBytes, same(compressedBytes));
    expect(find.byKey(const Key('zoom-image-button')), findsOneWidget);
  });

  testWidgets('lỗi nén hiển thị dialog và không gọi scan', (tester) async {
    var visionCallCount = 0;
    await _pumpScreen(
      tester,
      picker: _FakePicker(
        onPick: (source) async => PickedScanImage(
          bytes: _testImageBytes(),
          name: 'source.png',
        ),
      ),
      compressor: _FakeCompressor(
        onCompress: (bytes) async =>
            throw const ScanImagePreparationException('Ảnh quá lớn.'),
      ),
      storage: _FakeStorage(),
      visionClient: _FakeVisionClient(
        onAnalyze: (bytes, requestId) async {
          visionCallCount++;
          return const GeminiVisionResult(detectedVocabulary: []);
        },
      ),
    );

    final galleryButton = find.byKey(const Key('pick-gallery-button'));
    await tester.ensureVisible(galleryButton);
    await tester.tap(galleryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ảnh quá lớn.'), findsOneWidget);
    expect(visionCallCount, 0);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ScanImagePicker picker,
  required ScanImageCompressor compressor,
  required ScanImageStorage storage,
  required VisionScanClient visionClient,
  EntitlementNotifier? entitlementNotifier,
  bool? debugIsWebOverride,
  WebCameraCaptureBuilder? webCameraCaptureBuilder,
}) async {
  final entitlements = entitlementNotifier ??
      EntitlementNotifier(
        initialUserId: null,
        authUserIds: const Stream.empty(),
        loadActiveSubscription: (_) async => null,
      );
  final router = GoRouter(
    initialLocation: '/scan',
    routes: [
      GoRoute(
        path: '/scan',
        builder: (context, state) => webCameraCaptureBuilder == null
            ? PhotoScanBottomSheet(
                debugIsWebOverride: debugIsWebOverride,
              )
            : PhotoScanBottomSheet(
                debugIsWebOverride: debugIsWebOverride,
                webCameraCaptureBuilder: webCameraCaptureBuilder,
              ),
      ),
      GoRoute(
        path: '/scan-overlay',
        builder: (context, state) {
          final record = state.extra! as ScanResultRecord;
          return Scaffold(body: Text('Overlay: ${record.localPath}'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanImagePickerProvider.overrideWithValue(picker),
        scanImageCompressorProvider.overrideWithValue(compressor),
        scanImageStorageProvider.overrideWithValue(storage),
        visionScanClientProvider.overrideWithValue(visionClient),
        scanResultStoreProvider.overrideWithValue(MemoryScanResultStore()),
        entitlementProvider.overrideWith((ref) => entitlements),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Uint8List _testImageBytes() => Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      ),
    );

Rect _normalizedRect(Rect rect, Rect container) => Rect.fromLTRB(
      (rect.left - container.left) / container.width,
      (rect.top - container.top) / container.height,
      (rect.right - container.left) / container.width,
      (rect.bottom - container.top) / container.height,
    );

Matcher _rectCloseTo(Rect expected) => predicate<Rect>(
      (actual) =>
          (actual.left - expected.left).abs() < 0.000001 &&
          (actual.top - expected.top).abs() < 0.000001 &&
          (actual.right - expected.right).abs() < 0.000001 &&
          (actual.bottom - expected.bottom).abs() < 0.000001,
      'Rect gần bằng $expected',
    );

class _FakePicker implements ScanImagePicker {
  _FakePicker({required this.onPick});

  final Future<PickedScanImage?> Function(ScanImageSource source) onPick;
  ScanImageSource? lastSource;

  @override
  Future<PickedScanImage?> pick(ScanImageSource source) {
    lastSource = source;
    return onPick(source);
  }
}

class _FakeDeviceImagePicker extends ImagePicker {
  _FakeDeviceImagePicker({this.error});

  final Object? error;
  final List<ImageSource> sources = [];
  final List<bool> requestFullMetadataValues = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    requestFullMetadataValues.add(requestFullMetadata);
    if (error != null) throw error!;
    return null;
  }
}

class _FakeCompressor implements ScanImageCompressor {
  const _FakeCompressor({required this.onCompress});

  final Future<Uint8List> Function(Uint8List bytes) onCompress;

  @override
  Future<Uint8List> compress(Uint8List sourceBytes) {
    return onCompress(sourceBytes);
  }
}

class _FakeStorage implements ScanImageStorage {
  _FakeStorage({this.onSave, this.onDelete});

  final Future<String> Function(Uint8List bytes)? onSave;
  final Future<void> Function(String localPath)? onDelete;
  Uint8List? savedBytes;
  final deletedPaths = <String>[];

  @override
  Future<void> delete(String localPath) async {
    deletedPaths.add(localPath);
    await onDelete?.call(localPath);
  }

  @override
  Future<String> saveJpeg(Uint8List bytes) async {
    savedBytes = bytes;
    final save = onSave;
    if (save != null) return save(bytes);
    return 'memory://scan.jpg';
  }

  @override
  Future<Uint8List> readBytes(String localPath) async => savedBytes!;
}

class _FakeVisionClient implements VisionScanClient {
  const _FakeVisionClient({required this.onAnalyze});

  final Future<GeminiVisionResult> Function(
    Uint8List bytes,
    String requestId,
  ) onAnalyze;

  @override
  Future<GeminiVisionResult> analyzeImageBytes(
    Uint8List compressedImageBytes, {
    required String requestId,
  }) {
    return onAnalyze(compressedImageBytes, requestId);
  }
}
