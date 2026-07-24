// FR-GAME1-01, FR-GAME1-02
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-GAME1-01, FR-GAME1-02
class PhotoOrderQuizState {
  const PhotoOrderQuizState();
}

class PhotoOrderQuizNotifier extends StateNotifier<PhotoOrderQuizState> {
  PhotoOrderQuizNotifier() : super(const PhotoOrderQuizState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-GAME1-01, FR-GAME1-02
}

final photoOrderQuizProvider =
    StateNotifierProvider<PhotoOrderQuizNotifier, PhotoOrderQuizState>(
  (ref) => PhotoOrderQuizNotifier(),
);
