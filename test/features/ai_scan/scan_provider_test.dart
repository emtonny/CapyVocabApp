import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_picker.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage.dart';
import 'package:capy_vocab/features/ai_scan/presentation/providers/scan_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan đọc ảnh, gọi Vision, rồi lưu SQLite theo đúng thứ tự', () async {
    final calls = <String>[];
    final imageBytes = Uint8List.fromList([1, 2, 3]);
    const result = GeminiVisionResult(detectedVocabulary: [_word]);
    late ScanSaveRequest saveRequest;
    final visionClient = _FakeVisionScanClient(
      onAnalyze: (bytes, requestId) async {
        calls.add('vision:${bytes.join(',')}');
        expect(requestId, isNotEmpty);
        return result;
      },
    );
    final store = _FakeScanResultStore(
      onRequest: (request) => saveRequest = request,
      onSave: (localPath, receivedResult) async {
        calls.add('sqlite:$localPath');
        expect(receivedResult, same(result));
        return ScanResultRecord(
          id: 7,
          localPath: localPath,
          vocabJson: '{}',
          result: receivedResult,
          createdAt: DateTime.utc(2026, 8, 4),
        );
      },
    );
    final container = ProviderContainer(
      overrides: [
        scanImageStorageProvider.overrideWithValue(
          _FakeScanImageStorage(bytes: imageBytes),
        ),
        visionScanClientProvider.overrideWithValue(visionClient),
        scanResultStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    final record = await container.read(scanProvider.notifier).scanImage(
          'image.jpg',
          imageBytes: imageBytes,
          captureSource: ScanImageSource.camera,
          templateId: 'minimal',
        );

    expect(calls, ['vision:1,2,3', 'sqlite:image.jpg']);
    expect(saveRequest.imageBytes, same(imageBytes));
    expect(saveRequest.requestId, isNotEmpty);
    expect(saveRequest.captureSource, ScanImageSource.camera);
    expect(saveRequest.templateId, 'minimal');
    expect(record.id, 7);
    expect(container.read(scanProvider).value, same(record));
  });

  test('không lưu SQLite khi Vision trả lỗi', () async {
    var saveCount = 0;
    final container = ProviderContainer(
      overrides: [
        scanImageStorageProvider.overrideWithValue(
          _FakeScanImageStorage(bytes: Uint8List(1)),
        ),
        visionScanClientProvider.overrideWithValue(
          _FakeVisionScanClient(
            onAnalyze: (bytes, requestId) async =>
                throw const GeminiQuotaException(
              'Hệ thống đang bận, thử lại sau',
            ),
          ),
        ),
        scanResultStoreProvider.overrideWithValue(
          _FakeScanResultStore(
            onSave: (localPath, result) async {
              saveCount++;
              throw UnimplementedError();
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(scanProvider.notifier).scanImage('image.jpg'),
      throwsA(isA<GeminiQuotaException>()),
    );

    expect(saveCount, 0);
    expect(container.read(scanProvider).hasError, isTrue);
  });

  test('buffer nén có sẵn được gửi thẳng tới Vision, không đọc lại file',
      () async {
    final compressedBytes = Uint8List.fromList([4, 5, 6]);
    var storageReadCount = 0;
    final storage = _FakeScanImageStorage(
      bytes: Uint8List(1),
      onRead: () => storageReadCount++,
    );
    late Uint8List receivedBytes;
    final container = ProviderContainer(
      overrides: [
        scanImageStorageProvider.overrideWithValue(storage),
        visionScanClientProvider.overrideWithValue(
          _FakeVisionScanClient(
            onAnalyze: (bytes, requestId) async {
              receivedBytes = bytes;
              return const GeminiVisionResult(detectedVocabulary: []);
            },
          ),
        ),
        scanResultStoreProvider.overrideWithValue(
          _FakeScanResultStore(
            onSave: (localPath, result) async => ScanResultRecord(
              id: 8,
              localPath: localPath,
              vocabJson: '{}',
              result: result,
              createdAt: DateTime.utc(2026, 8, 24),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(scanProvider.notifier).scanImage(
          'image.jpg',
          imageBytes: compressedBytes,
        );

    expect(storageReadCount, 0);
    expect(receivedBytes, same(compressedBytes));
  });

  test('manual retry cùng ảnh giữ request ID, ảnh mới tạo ID khác', () async {
    final requestIds = <String>[];
    final container = ProviderContainer(
      overrides: [
        scanImageStorageProvider.overrideWithValue(
          _FakeScanImageStorage(bytes: Uint8List(1)),
        ),
        visionScanClientProvider.overrideWithValue(
          _FakeVisionScanClient(
            onAnalyze: (bytes, requestId) async {
              requestIds.add(requestId);
              throw const GeminiQuotaException('quota');
            },
          ),
        ),
        scanResultStoreProvider.overrideWithValue(
          _FakeScanResultStore(
            onSave: (localPath, result) => throw UnimplementedError(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    for (final path in ['same.jpg', 'same.jpg', 'new.jpg']) {
      await expectLater(
        container.read(scanProvider.notifier).scanImage(path),
        throwsA(isA<GeminiQuotaException>()),
      );
    }

    expect(requestIds, hasLength(3));
    expect(requestIds[0], requestIds[1]);
    expect(requestIds[2], isNot(requestIds[0]));
    expect(
      requestIds.every(
        (id) => RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
      ),
      isTrue,
    );
  });
}

const _word = VocabDetection(
  number: 1,
  word: 'apple',
  phonetic: '/ˈæp.əl/',
  meaning: 'quả táo',
  x: 0.1,
  y: 0.2,
  w: 0.3,
  h: 0.1,
);

class _FakeVisionScanClient implements VisionScanClient {
  const _FakeVisionScanClient({required this.onAnalyze});

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

class _FakeScanImageStorage implements ScanImageStorage {
  const _FakeScanImageStorage({required this.bytes, this.onRead});

  final Uint8List bytes;
  final void Function()? onRead;

  @override
  Future<void> delete(String localPath) async {}

  @override
  Future<Uint8List> readBytes(String localPath) async {
    onRead?.call();
    return bytes;
  }

  @override
  Future<String> saveJpeg(Uint8List bytes) => throw UnimplementedError();
}

class _FakeScanResultStore implements ScanResultStore {
  const _FakeScanResultStore({required this.onSave, this.onRequest});

  final Future<ScanResultRecord> Function(
    String localPath,
    GeminiVisionResult result,
  ) onSave;
  final void Function(ScanSaveRequest request)? onRequest;

  @override
  Future<ScanResultRecord> save(ScanSaveRequest request) {
    onRequest?.call(request);
    return onSave(request.localPath, request.result);
  }
}
