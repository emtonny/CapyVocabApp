import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage.dart';
import 'package:capy_vocab/features/ai_scan/presentation/providers/scan_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scan đọc ảnh, gọi Vision, rồi lưu SQLite theo đúng thứ tự', () async {
    final calls = <String>[];
    final imageBytes = Uint8List.fromList([1, 2, 3]);
    const result = GeminiVisionResult(detectedVocabulary: [_word]);
    final visionClient = _FakeVisionScanClient(
      onAnalyze: (bytes) async {
        calls.add('vision:${bytes.join(',')}');
        return result;
      },
    );
    final store = _FakeScanResultStore(
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

    final record =
        await container.read(scanProvider.notifier).scanImage('image.jpg');

    expect(calls, ['vision:1,2,3', 'sqlite:image.jpg']);
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
            onAnalyze: (bytes) async => throw const GeminiQuotaException(
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
}

const _word = VocabDetection(
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

  final Future<GeminiVisionResult> Function(Uint8List bytes) onAnalyze;

  @override
  Future<GeminiVisionResult> analyzeImageBytes(Uint8List compressedImageBytes) {
    return onAnalyze(compressedImageBytes);
  }
}

class _FakeScanImageStorage implements ScanImageStorage {
  const _FakeScanImageStorage({required this.bytes});

  final Uint8List bytes;

  @override
  Future<Uint8List> readBytes(String localPath) async => bytes;

  @override
  Future<String> saveJpeg(Uint8List bytes) => throw UnimplementedError();
}

class _FakeScanResultStore implements ScanResultStore {
  const _FakeScanResultStore({required this.onSave});

  final Future<ScanResultRecord> Function(
    String localPath,
    GeminiVisionResult result,
  ) onSave;

  @override
  Future<ScanResultRecord> save({
    required String localPath,
    required GeminiVisionResult result,
  }) {
    return onSave(localPath, result);
  }
}
