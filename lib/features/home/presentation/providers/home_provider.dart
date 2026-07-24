// FR-HOME-02, FR-HOME-03
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-HOME-02, FR-HOME-03
class HomeState {
  const HomeState();
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-HOME-02, FR-HOME-03
}

final homeProvider =
    StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);
