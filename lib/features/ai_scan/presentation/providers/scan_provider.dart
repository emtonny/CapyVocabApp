import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/gemini_vision_service.dart';
import '../../../library/data/local/sqlite_library_store.dart';
import '../../../library/data/local/sqlite_library_store_factory.dart';
import '../../data/datasources/scan_result_local_datasource.dart';
import '../../data/services/scan_image_compressor.dart';
import '../../data/services/scan_image_picker.dart';
import '../../data/services/scan_image_storage.dart';
import '../../data/services/scan_image_storage_factory.dart';

final scanImagePickerProvider = Provider<ScanImagePicker>(
  (ref) => DeviceScanImagePicker(),
);

final scanImageCompressorProvider = Provider<ScanImageCompressor>(
  (ref) => FlutterScanImageCompressor(),
);

final scanImageStorageProvider = Provider<ScanImageStorage>(
  (ref) => createScanImageStorage(),
);

final visionScanClientProvider = Provider<VisionScanClient>(
  (ref) => GeminiVisionService(),
);

final libraryStoreProvider = FutureProvider<SqliteLibraryStore>((ref) async {
  final store = await createDefaultSqliteLibraryStore(
    idGenerator: createScanRequestId,
  );
  ref.onDispose(() => unawaited(store.dispose()));
  return store;
});

final scanResultStoreProvider = Provider<ScanResultStore>(
  (ref) => kIsWeb
      ? MemoryScanResultStore()
      : ScanResultLocalDataSource(
          openLibraryStore: () => ref.read(libraryStoreProvider.future),
        ),
);

class ScanNotifier extends StateNotifier<AsyncValue<ScanResultRecord?>> {
  ScanNotifier({
    required VisionScanClient visionClient,
    required ScanResultStore resultStore,
    required ScanImageStorage imageStorage,
    String Function()? requestIdGenerator,
    DateTime Function()? clock,
  })  : _visionClient = visionClient,
        _resultStore = resultStore,
        _imageStorage = imageStorage,
        _requestIdGenerator = requestIdGenerator ?? createScanRequestId,
        _clock = clock ?? (() => DateTime.now().toUtc()),
        super(const AsyncData(null));

  final VisionScanClient _visionClient;
  final ScanResultStore _resultStore;
  final ScanImageStorage _imageStorage;
  final String Function() _requestIdGenerator;
  final DateTime Function() _clock;
  String? _retryLocalPath;
  String? _retryRequestId;

  Future<ScanResultRecord> scanImage(
    String localPath, {
    Uint8List? imageBytes,
    ScanImageSource captureSource = ScanImageSource.gallery,
    String templateId = 'standard',
  }) async {
    if (state.isLoading) {
      throw StateError('A scan is already in progress.');
    }

    state = const AsyncLoading();
    final requestId = _retryLocalPath == localPath && _retryRequestId != null
        ? _retryRequestId!
        : _requestIdGenerator();
    final startedAt = _clock().toUtc();
    try {
      final bytes = imageBytes ?? await _imageStorage.readBytes(localPath);
      final result = await _visionClient.analyzeImageBytes(
        bytes,
        requestId: requestId,
      );
      final record = await _resultStore.save(ScanSaveRequest(
        localPath: localPath,
        imageBytes: bytes,
        result: result,
        requestId: requestId,
        captureSource: captureSource,
        templateId: templateId,
        startedAt: startedAt,
        completedAt: _clock().toUtc(),
      ));
      _retryLocalPath = null;
      _retryRequestId = null;
      state = AsyncData(record);
      return record;
    } catch (error, stackTrace) {
      _retryLocalPath = localPath;
      _retryRequestId = requestId;
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void clear() {
    _retryLocalPath = null;
    _retryRequestId = null;
    state = const AsyncData(null);
  }
}

final scanProvider =
    StateNotifierProvider<ScanNotifier, AsyncValue<ScanResultRecord?>>((ref) {
  return ScanNotifier(
    visionClient: ref.watch(visionScanClientProvider),
    resultStore: ref.watch(scanResultStoreProvider),
    imageStorage: ref.watch(scanImageStorageProvider),
  );
});
