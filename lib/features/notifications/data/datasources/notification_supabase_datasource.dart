import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Thông báo (notifications)
class NotificationSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  NotificationSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _notificationsTable = 'notifications';

  /// Lấy danh sách thông báo của người dùng
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final response = await _supabaseClient
        .from(_notificationsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Đánh dấu thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _supabaseClient
        .from(_notificationsTable)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Stream thông báo mới theo thời gian thực
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return _supabaseClient
        .from(_notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }
}
