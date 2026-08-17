import 'dart:typed_data';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:capy_vocab/features/ai_scan/data/datasources/scan_result_local_datasource.dart';
import 'package:capy_vocab/features/ai_scan/data/services/scan_image_storage.dart';
import 'package:capy_vocab/features/ai_scan/presentation/controllers/scan_flow_controller.dart';
import 'package:capy_vocab/features/ai_scan/presentation/providers/scan_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('chỉ điều hướng đến overlay sau khi Vision và SQLite thành công',
      (tester) async {
    final calls = <String>[];
    const result = GeminiVisionResult(detectedVocabulary: [_word]);
    final record = ScanResultRecord(
      id: 1,
      localPath: 'compressed.jpg',
      vocabJson: '{}',
      result: result,
      createdAt: DateTime.utc(2026, 8, 4),
    );

    await _pumpHarness(
      tester,
      visionClient: _FakeVisionScanClient((bytes) async {
        calls.add('vision');
        return result;
      }),
      resultStore: _FakeScanResultStore((localPath, receivedResult) async {
        calls.add('sqlite');
        return record;
      }),
    );

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(calls, ['vision', 'sqlite']);
    expect(find.text('Overlay: 1'), findsOneWidget);
  });

  testWidgets('hiển thị đúng dialog lỗi và không điều hướng', (tester) async {
    await _pumpHarness(
      tester,
      visionClient: _FakeVisionScanClient(
        (bytes) async => throw const GeminiQuotaException(
          'Hệ thống đang bận, thử lại sau',
        ),
      ),
      resultStore: _FakeScanResultStore(
        (localPath, result) => throw UnimplementedError(),
      ),
    );

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Hệ thống đang bận, thử lại sau'), findsOneWidget);
    expect(find.text('Overlay: 1'), findsNothing);
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required VisionScanClient visionClient,
  required ScanResultStore resultStore,
}) async {
  final router = GoRouter(
    initialLocation: '/scan',
    routes: [
      GoRoute(
        path: '/scan',
        builder: (context, state) => const _ScanHarness(),
      ),
      GoRoute(
        path: '/scan-overlay',
        builder: (context, state) {
          final record = state.extra! as ScanResultRecord;
          return Scaffold(body: Text('Overlay: ${record.id}'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanImageStorageProvider.overrideWithValue(
          _FakeScanImageStorage(),
        ),
        visionScanClientProvider.overrideWithValue(visionClient),
        scanResultStoreProvider.overrideWithValue(resultStore),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _ScanHarness extends ConsumerWidget {
  const _ScanHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: FilledButton(
        onPressed: () => ScanFlowController.scanAndNavigate(
          context,
          ref,
          localPath: 'compressed.jpg',
        ),
        child: const Text('Scan'),
      ),
    );
  }
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
  const _FakeVisionScanClient(this.onAnalyze);

  final Future<GeminiVisionResult> Function(Uint8List bytes) onAnalyze;

  @override
  Future<GeminiVisionResult> analyzeImageBytes(Uint8List compressedImageBytes) {
    return onAnalyze(compressedImageBytes);
  }
}

class _FakeScanImageStorage implements ScanImageStorage {
  @override
  Future<Uint8List> readBytes(String localPath) async => Uint8List(1);

  @override
  Future<String> saveJpeg(Uint8List bytes) => throw UnimplementedError();
}

class _FakeScanResultStore implements ScanResultStore {
  const _FakeScanResultStore(this.onSave);

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
