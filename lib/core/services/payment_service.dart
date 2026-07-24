import 'package:flutter/foundation.dart';

/// Enum phân loại phương thức thanh toán
enum PaymentMethod {
  inAppPurchase,
  momo,
  zalopay,
  stripe,
}

/// Model giao dịch thanh toán
class PaymentTransaction {
  final String transactionId;
  final String productId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;

  PaymentTransaction({
    required this.transactionId,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.timestamp,
    required this.isSuccess,
    this.errorMessage,
  });
}

/// Service tích hợp cổng thanh toán (In-App Purchase, MoMo, ZaloPay, v.v.)
/// Xử lý thanh toán mua gói Pro & nạp Capy Coins trong Pet Shop.
class PaymentService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Khởi tạo cấu hình gateway thanh toán
  Future<void> initialize() async {
    // TODO: Kết nối SDK In-App Purchase / MoMo / ZaloPay
    _isInitialized = true;
    debugPrint('PaymentService đã được khởi tạo thành công.');
  }

  /// Khởi chạy giao dịch mua sản phẩm / gói dịch vụ
  Future<PaymentTransaction> processPayment({
    required String productId,
    required double amount,
    required PaymentMethod method,
    String currency = 'VND',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint(
        'Đang xử lý thanh toán sản phẩm $productId qua ${method.name}...');

    // Giả lập xử lý thanh toán API
    await Future.delayed(const Duration(seconds: 2));

    final String mockTxId =
        'TX_${DateTime.now().millisecondsSinceEpoch}_${productId.toUpperCase()}';

    return PaymentTransaction(
      transactionId: mockTxId,
      productId: productId,
      amount: amount,
      currency: currency,
      method: method,
      timestamp: DateTime.now(),
      isSuccess: true,
    );
  }

  /// Khôi phục các giao dịch đã mua (Restore Purchases)
  Future<List<String>> restorePurchases() async {
    debugPrint('Đang khôi phục các gói đã mua...');
    await Future.delayed(const Duration(seconds: 1));
    return ['capy_pro_monthly'];
  }
}
