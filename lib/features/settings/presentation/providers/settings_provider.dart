// FR-SETT-01, FR-SETT-02, UC-SETT-01
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-SETT-01, FR-SETT-02, UC-SETT-01
class SettingsState {
  const SettingsState();
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-SETT-01, FR-SETT-02, UC-SETT-01
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
