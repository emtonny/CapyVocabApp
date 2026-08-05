import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_compressor.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_picker.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage.dart';
import 'package:capy_vocab/features/ai_scan/presentation/providers/scan_provider.dart';
import 'package:capy_vocab/features/ai_scan/presentation/screens/photo_scan_bottom_sheet.dart';
import 'package:capy_vocab/features/ai_scan/presentation/widgets/scan_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
      onAnalyze: (bytes) {
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

    expect(find.text('Overlay: memory://scan.jpg'), findsOneWidget);
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
        onAnalyze: (bytes) => throw UnimplementedError(),
      ),
    );

    final cameraButton = find.byKey(const Key('pick-camera-button'));
    await tester.ensureVisible(cameraButton);
    await tester.tap(cameraButton);
    await tester.pump();

    expect(picker.lastSource, ScanImageSource.camera);
    expect(find.byType(ScanLoadingOverlay), findsNothing);
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
        onAnalyze: (bytes) async {
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
}) async {
  final router = GoRouter(
    initialLocation: '/scan',
    routes: [
      GoRoute(
        path: '/scan',
        builder: (context, state) => const PhotoScanBottomSheet(),
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

class _FakeCompressor implements ScanImageCompressor {
  const _FakeCompressor({required this.onCompress});

  final Future<Uint8List> Function(Uint8List bytes) onCompress;

  @override
  Future<Uint8List> compress(Uint8List sourceBytes) {
    return onCompress(sourceBytes);
  }
}

class _FakeStorage implements ScanImageStorage {
  Uint8List? savedBytes;

  @override
  Future<String> saveJpeg(Uint8List bytes) async {
    savedBytes = bytes;
    return 'memory://scan.jpg';
  }

  @override
  Future<Uint8List> readBytes(String localPath) async => savedBytes!;
}

class _FakeVisionClient implements VisionScanClient {
  const _FakeVisionClient({required this.onAnalyze});

  final Future<GeminiVisionResult> Function(Uint8List bytes) onAnalyze;

  @override
  Future<GeminiVisionResult> analyzeImageBytes(Uint8List compressedImageBytes) {
    return onAnalyze(compressedImageBytes);
  }
}
