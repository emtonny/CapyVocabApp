// FR-SOLO-01, FR-SOLO-02, FR-SOLO-03
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-SOLO-01, FR-SOLO-02, FR-SOLO-03
class SoloArenaState {
  const SoloArenaState();
}

class SoloArenaNotifier extends StateNotifier<SoloArenaState> {
  SoloArenaNotifier() : super(const SoloArenaState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-SOLO-01, FR-SOLO-02, FR-SOLO-03
}

final soloArenaProvider =
    StateNotifierProvider<SoloArenaNotifier, SoloArenaState>(
  (ref) => SoloArenaNotifier(),
);
