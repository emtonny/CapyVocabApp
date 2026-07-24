import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';

/// Firestore Datasource cho Pet Shop, Trang phục Capybara và Kho đồ
class PetShopFirestoreDataSource {
  final FirestoreService _firestoreService;

  PetShopFirestoreDataSource({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _shopItemsCollection = 'shop_items';
  static const String _usersCollection = 'users';

  /// Lấy danh sách vật phẩm đang bán trong Shop
  Future<List<Map<String, dynamic>>> getShopItems() async {
    final querySnapshot =
        await _firestoreService.getCollection(_shopItemsCollection);
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Mua vật phẩm và thêm vào kho đồ user (inventory)
  Future<void> purchaseItem({
    required String userId,
    required String itemId,
    required int itemPrice,
  }) async {
    final userDocRef = _firestoreService.doc('$_usersCollection/$userId');
    final inventoryRef = _firestoreService
        .collection('$_usersCollection/$userId/inventory')
        .doc(itemId);

    await _firestoreService.db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocRef);
      if (!userSnapshot.exists) {
        throw Exception('User không tồn tại!');
      }

      final int currentCoins = (userSnapshot.data()?['coins'] as num?)?.toInt() ?? 0;
      if (currentCoins < itemPrice) {
        throw Exception('Không đủ Capy Coins để mua vật phẩm này!');
      }

      // Trừ coin
      transaction.update(userDocRef, {
        'coins': FieldValue.increment(-itemPrice),
      });

      // Thêm item vào kho đồ
      transaction.set(inventoryRef, {
        'itemId': itemId,
        'purchasedAt': FieldValue.serverTimestamp(),
        'isEquipped': false,
      });
    });
  }

  /// Trang bị vật phẩm cho Capybara mascot
  Future<void> equipItem({
    required String userId,
    required String itemId,
    required String itemCategory,
  }) async {
    await _firestoreService.setDocument(
      path: '$_usersCollection/$userId',
      data: {
        'equippedPetItems.$itemCategory': itemId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Stream danh sách vật phẩm đã sở hữu trong kho đồ của User
  Stream<List<Map<String, dynamic>>> streamUserInventory(String userId) {
    return _firestoreService
        .streamCollection('$_usersCollection/$userId/inventory')
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
