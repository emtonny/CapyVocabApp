import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/gemini_vision_service.dart';
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

final scanResultStoreProvider = Provider<ScanResultStore>(
  (ref) => kIsWeb ? MemoryScanResultStore() : ScanResultLocalDataSource(),
);

class ScanNotifier extends StateNotifier<AsyncValue<ScanResultRecord?>> {
  ScanNotifier({
    required VisionScanClient visionClient,
    required ScanResultStore resultStore,
    required ScanImageStorage imageStorage,
  })  : _visionClient = visionClient,
        _resultStore = resultStore,
        _imageStorage = imageStorage,
        super(const AsyncData(null));

  final VisionScanClient _visionClient;
  final ScanResultStore _resultStore;
  final ScanImageStorage _imageStorage;

  Future<ScanResultRecord> scanImage(String localPath) async {
    if (state.isLoading) {
      throw StateError('A scan is already in progress.');
    }

    state = const AsyncLoading();
    try {
      final imageBytes = await _imageStorage.readBytes(localPath);
      final result = await _visionClient.analyzeImageBytes(imageBytes);
      final record = await _resultStore.save(
        localPath: localPath,
        result: result,
      );
      state = AsyncData(record);
      return record;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void clear() => state = const AsyncData(null);
}

final scanProvider =
    StateNotifierProvider<ScanNotifier, AsyncValue<ScanResultRecord?>>((ref) {
  return ScanNotifier(
    visionClient: ref.watch(visionScanClientProvider),
    resultStore: ref.watch(scanResultStoreProvider),
    imageStorage: ref.watch(scanImageStorageProvider),
  );
});
