// UC-ONBD-01: wizard 5 bước
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho UC-ONBD-01: wizard 5 bước
class OnboardingState {
  const OnboardingState();
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  // TODO: các action nghiệp vụ theo luồng chính trong UC-ONBD-01: wizard 5 bước
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
