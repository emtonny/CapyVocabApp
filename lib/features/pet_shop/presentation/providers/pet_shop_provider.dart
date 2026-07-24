// FR-SHOP-01, FR-SHOP-02, UC-SHOP: mua + trang bị
// TODO: Sinh bởi scaffold tự động từ FRD/Use Case. Cần hiện thực hoá chi tiết.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State + logic cho FR-SHOP-01, FR-SHOP-02, UC-SHOP: mua + trang bị
class PetShopState {
  const PetShopState();
}

class PetShopNotifier extends StateNotifier<PetShopState> {
  PetShopNotifier() : super(const PetShopState());

  // TODO: các action nghiệp vụ theo luồng chính trong FR-SHOP-01, FR-SHOP-02, UC-SHOP: mua + trang bị
}

final petShopProvider =
    StateNotifierProvider<PetShopNotifier, PetShopState>(
  (ref) => PetShopNotifier(),
);
