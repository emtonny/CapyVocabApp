// FR-GAME2-01, FR-GAME2-02
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-GAME2-01, FR-GAME2-02
class PhotoLetterFillState {
  const PhotoLetterFillState();
}

class PhotoLetterFillNotifier extends StateNotifier<PhotoLetterFillState> {
  PhotoLetterFillNotifier() : super(const PhotoLetterFillState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-GAME2-01, FR-GAME2-02
}

final photoLetterFillProvider =
    StateNotifierProvider<PhotoLetterFillNotifier, PhotoLetterFillState>(
  (ref) => PhotoLetterFillNotifier(),
);
