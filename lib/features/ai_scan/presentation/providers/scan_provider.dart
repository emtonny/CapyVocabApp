// FR-SCAN-01, FR-SCAN-02 (quét vô hạn), UC-SCAN-01
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-SCAN-01, FR-SCAN-02 (quét vô hạn), UC-SCAN-01
class ScanState {
  const ScanState();
}

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(const ScanState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-SCAN-01, FR-SCAN-02 (quét vô hạn), UC-SCAN-01
}

final scanProvider =
    StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
