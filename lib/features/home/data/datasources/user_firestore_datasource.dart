import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';

/// Firestore Datasource cho dữ liệu User Profile, Streak, XP, và Tiến trình học
class UserFirestoreDataSource {
  final FirestoreService _firestoreService;

  UserFirestoreDataSource({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _usersCollection = 'users';

  /// Lấy thông tin User Profile theo userId
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestoreService.getDocument('$_usersCollection/$userId');
    return doc.data();
  }

  /// Cập nhật / Tạo mới User Profile
  Future<void> saveUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    await _firestoreService.setDocument(
      path: '$_usersCollection/$userId',
      data: {
        ...userData,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Cập nhật Streak ngọn lửa học tập
  Future<void> updateStreak({
    required String userId,
    required int streakCount,
    required DateTime lastStudyDate,
  }) async {
    await _firestoreService.setDocument(
      path: '$_usersCollection/$userId',
      data: {
        'streakCount': streakCount,
        'lastStudyDate': Timestamp.fromDate(lastStudyDate),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Cộng điểm kinh nghiệm XP & Tiền Capy Coins
  Future<void> addXpAndCoins({
    required String userId,
    required int xpGained,
    required int coinsGained,
  }) async {
    await _firestoreService.setDocument(
      path: '$_usersCollection/$userId',
      data: {
        'xp': FieldValue.increment(xpGained),
        'coins': FieldValue.increment(coinsGained),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Stream thông tin User theo thời gian thực
  Stream<Map<String, dynamic>?> streamUserProfile(String userId) {
    return _firestoreService
        .streamDocument('$_usersCollection/$userId')
        .map((snapshot) => snapshot.data());
  }
}
