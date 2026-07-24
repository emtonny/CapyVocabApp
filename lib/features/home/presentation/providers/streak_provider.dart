// FR-HOME-01, UC-HOME-01: isStreakCompleted, streakCount
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-HOME-01, UC-HOME-01: isStreakCompleted, streakCount
class StreakState {
  const StreakState();
}

class StreakNotifier extends StateNotifier<StreakState> {
  StreakNotifier() : super(const StreakState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-HOME-01, UC-HOME-01: isStreakCompleted, streakCount
}

final streakProvider =
    StateNotifierProvider<StreakNotifier, StreakState>(
  (ref) => StreakNotifier(),
);
