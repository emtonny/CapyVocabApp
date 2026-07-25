import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Pet Shop, Kho đồ (user_pet_inventory) & Giao dịch (shop_purchases)
class ShopSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  ShopSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _shopItemsTable = 'pet_items';
  static const String _userInventoryTable = 'user_pet_inventory';
  static const String _shopPurchasesTable = 'shop_purchases';
  static const String _usersTable = 'users';

  /// Lấy danh sách tất cả vật phẩm Pet Shop
  Future<List<Map<String, dynamic>>> getShopItems() async {
    final response = await _supabaseClient.from(_shopItemsTable).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Mua vật phẩm và ghi nhận giao dịch vào bảng shop_purchases & user_pet_inventory
  Future<void> purchaseItem({
    required String userId,
    required String itemId,
    required int itemPrice,
    String paymentMethod = 'coins',
    String? transactionId,
  }) async {
    // 1. Kiểm tra số dư xu của người dùng
    final userRes = await _supabaseClient
        .from(_usersTable)
        .select('total_coins')
        .eq('id', userId)
        .single();

    final int currentCoins = (userRes['total_coins'] as num?)?.toInt() ?? 0;
    if (paymentMethod == 'coins' && currentCoins < itemPrice) {
      throw Exception('Không đủ Capy Coins để mua vật phẩm này!');
    }

    // 2. Trừ coin nếu thanh toán bằng xu
    if (paymentMethod == 'coins') {
      await _supabaseClient.from(_usersTable).update({
        'total_coins': currentCoins - itemPrice,
      }).eq('id', userId);
    }

    // 3. Lưu vào kho đồ user (user_pet_inventory)
    await _supabaseClient.from(_userInventoryTable).upsert({
      'user_id': userId,
      'item_id': itemId,
      'purchased_at': DateTime.now().toIso8601String(),
      'is_equipped': false,
    });

    // 4. Lưu lịch sử giao dịch vào bảng shop_purchases
    await _supabaseClient.from(_shopPurchasesTable).insert({
      'user_id': userId,
      'item_id': itemId,
      'amount': itemPrice,
      'payment_method': paymentMethod,
      'transaction_id': transactionId ?? 'TX_${DateTime.now().millisecondsSinceEpoch}',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Trang bị vật phẩm cho mascot Capybara
  Future<void> equipItem({
    required String userId,
    required String itemId,
  }) async {
    await _supabaseClient
        .from(_userInventoryTable)
        .update({'is_equipped': true})
        .eq('user_id', userId)
        .eq('item_id', itemId);
  }

  /// Stream kho đồ của người dùng thời gian thực
  Stream<List<Map<String, dynamic>>> streamUserInventory(String userId) {
    return _supabaseClient
        .from(_userInventoryTable)
        .stream(primaryKey: ['user_id', 'item_id'])
        .eq('user_id', userId);
  }
}
