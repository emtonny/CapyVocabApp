import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';

/// Firestore Datasource cho Solo Arena (Thách đấu từ vựng 1v1 Real-time)
class SoloArenaFirestoreDataSource {
  final FirestoreService _firestoreService;

  SoloArenaFirestoreDataSource({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _matchesCollection = 'solo_matches';

  /// Tạo phòng thách đấu 1v1 mới
  Future<String> createMatch({
    required String hostUserId,
    required int betCoins,
    required String topicId,
  }) async {
    final docRef = _firestoreService.collection(_matchesCollection).doc();

    await docRef.set({
      'matchId': docRef.id,
      'hostUserId': hostUserId,
      'guestUserId': null,
      'betCoins': betCoins,
      'topicId': topicId,
      'status': 'waiting', // waiting, in_progress, completed, cancelled
      'hostScore': 0,
      'guestScore': 0,
      'winnerUserId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Tham gia vào phòng đấu có sẵn
  Future<void> joinMatch({
    required String matchId,
    required String guestUserId,
  }) async {
    await _firestoreService.setDocument(
      path: '$_matchesCollection/$matchId',
      data: {
        'guestUserId': guestUserId,
        'status': 'in_progress',
        'startedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Cập nhật điểm số khi trả lời câu hỏi trong trận đấu
  Future<void> updateMatchScore({
    required String matchId,
    required bool isHost,
    required int newScore,
  }) async {
    final fieldToUpdate = isHost ? 'hostScore' : 'guestScore';

    await _firestoreService.setDocument(
      path: '$_matchesCollection/$matchId',
      data: {
        fieldToUpdate: newScore,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Hoàn tất trận đấu và chốt người chiến thắng
  Future<void> finishMatch({
    required String matchId,
    required String? winnerUserId,
  }) async {
    await _firestoreService.setDocument(
      path: '$_matchesCollection/$matchId',
      data: {
        'status': 'completed',
        'winnerUserId': winnerUserId,
        'finishedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
  }

  /// Stream thông tin trận đấu theo thời gian thực (để đồng bộ điểm số 2 người chơi)
  Stream<Map<String, dynamic>?> streamMatchState(String matchId) {
    return _firestoreService
        .streamDocument('$_matchesCollection/$matchId')
        .map((snapshot) => snapshot.data());
  }
}
