import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';

/// Firestore Datasource cho tính năng Mạng xã hội bạn bè & Bảng xếp hạng Leaderboard
class FriendsFirestoreDataSource {
  final FirestoreService _firestoreService;

  FriendsFirestoreDataSource({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _usersCollection = 'users';

  /// Lấy danh sách bạn bè của User
  Future<List<Map<String, dynamic>>> getFriendsList(String userId) async {
    final querySnapshot = await _firestoreService
        .getCollection('$_usersCollection/$userId/friends');

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Gửi lời mời kết bạn
  Future<void> sendFriendRequest({
    required String currentUserId,
    required String targetUserId,
  }) async {
    await _firestoreService.setDocument(
      path: '$_usersCollection/$targetUserId/friend_requests/$currentUserId',
      data: {
        'fromUserId': currentUserId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Chấp nhận lời mời kết bạn
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    final batch = _firestoreService.db.batch();

    final userFriendRef = _firestoreService
        .doc('$_usersCollection/$currentUserId/friends/$friendUserId');
    final friendUserRef = _firestoreService
        .doc('$_usersCollection/$friendUserId/friends/$currentUserId');
    final requestRef = _firestoreService
        .doc('$_usersCollection/$currentUserId/friend_requests/$friendUserId');

    batch.set(userFriendRef, {
      'friendId': friendUserId,
      'addedAt': FieldValue.serverTimestamp(),
    });

    batch.set(friendUserRef, {
      'friendId': currentUserId,
      'addedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(requestRef);

    await batch.commit();
  }

  /// Lấy Bảng xếp hạng tuần (Top XP)
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 20}) async {
    final querySnapshot = await _firestoreService.getCollection(
      _usersCollection,
      queryBuilder: (query) => query
          .orderBy('xp', descending: true)
          .limit(limit),
    );

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['userId'] = doc.id;
      return data;
    }).toList();
  }

  /// Stream Leaderboard thời gian thực
  Stream<List<Map<String, dynamic>>> streamWeeklyLeaderboard({int limit = 20}) {
    return _firestoreService
        .streamCollection(
          _usersCollection,
          queryBuilder: (query) => query
              .orderBy('xp', descending: true)
              .limit(limit),
        )
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['userId'] = doc.id;
              return data;
            }).toList());
  }
}
