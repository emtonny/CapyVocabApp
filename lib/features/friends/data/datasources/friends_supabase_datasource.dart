import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Mạng xã hội bạn bè & Bảng xếp hạng Leaderboard
class FriendsSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  FriendsSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _friendsTable = 'friends';
  static const String _usersTable = 'users';

  /// Lấy danh sách bạn bè đã chấp nhận
  Future<List<Map<String, dynamic>>> getFriendsList(String userId) async {
    final response = await _supabaseClient
        .from(_friendsTable)
        .select('*, friend:users!friend_id(*)')
        .eq('user_id', userId)
        .eq('status', 'accepted');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Gửi lời mời kết bạn
  Future<void> sendFriendRequest({
    required String currentUserId,
    required String targetUserId,
  }) async {
    await _supabaseClient.from(_friendsTable).insert({
      'user_id': currentUserId,
      'friend_id': targetUserId,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Chấp nhận lời mời kết bạn
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String friendUserId,
  }) async {
    // 1. Cập nhật bản ghi lời mời từ friendUserId gửi tới currentUserId
    await _supabaseClient
        .from(_friendsTable)
        .update({'status': 'accepted'})
        .eq('user_id', friendUserId)
        .eq('friend_id', currentUserId);

    // 2. Tạo chiều ngược lại
    await _supabaseClient.from(_friendsTable).upsert({
      'user_id': currentUserId,
      'friend_id': friendUserId,
      'status': 'accepted',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Lấy Bảng xếp hạng tuần (Top Study Points & Streak)
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({
    int limit = 20,
  }) async {
    final response = await _supabaseClient
        .from(_usersTable)
        .select()
        .order('study_points', ascending: false)
        .order('streak_days', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Stream Leaderboard thời gian thực
  Stream<List<Map<String, dynamic>>> streamWeeklyLeaderboard({
    int limit = 20,
  }) {
    return _supabaseClient
        .from(_usersTable)
        .stream(primaryKey: ['id'])
        .order('study_points', ascending: false)
        .limit(limit);
  }
}
