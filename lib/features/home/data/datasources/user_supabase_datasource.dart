import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho User Profile, Streak, Study Points, và Capy Coins
class UserSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  UserSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _usersTable = 'users';

  /// Lấy thông tin User Profile theo userId
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _supabaseClient
        .from(_usersTable)
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  /// Cập nhật / Tạo mới User Profile
  Future<void> saveUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    await _supabaseClient.from(_usersTable).upsert({
      'id': userId,
      ...userData,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Cập nhật Streak ngọn lửa học tập
  Future<void> updateStreak({
    required String userId,
    required int streakCount,
  }) async {
    await _supabaseClient.from(_usersTable).update({
      'streak_days': streakCount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Cộng điểm kinh nghiệm (study_points) & Capy Coins (total_coins)
  Future<void> addXpAndCoins({
    required String userId,
    required int xpGained,
    required int coinsGained,
  }) async {
    final currentData = await getUserProfile(userId);
    final currentPoints = (currentData?['study_points'] as num?)?.toInt() ?? 0;
    final currentCoins = (currentData?['total_coins'] as num?)?.toInt() ?? 0;

    await _supabaseClient.from(_usersTable).update({
      'study_points': currentPoints + xpGained,
      'total_coins': currentCoins + coinsGained,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Stream thông tin User theo thời gian thực (Supabase Realtime Stream)
  Stream<Map<String, dynamic>?> streamUserProfile(String userId) {
    return _supabaseClient
        .from(_usersTable)
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }
}
