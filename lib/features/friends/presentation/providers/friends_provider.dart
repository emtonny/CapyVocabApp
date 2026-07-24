// FR-FRND-01, FR-FRND-02, UC-FRND-01
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-FRND-01, FR-FRND-02, UC-FRND-01
class FriendsState {
  const FriendsState();
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier() : super(const FriendsState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-FRND-01, FR-FRND-02, UC-FRND-01
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>(
  (ref) => FriendsNotifier(),
);
