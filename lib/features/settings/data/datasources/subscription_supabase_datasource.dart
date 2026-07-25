import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Đăng ký gói Pro / Subscriptions
class SubscriptionSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  SubscriptionSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _subscriptionsTable = 'subscriptions';

  /// Lấy thông tin gói Pro hiện tại của User
  Future<Map<String, dynamic>?> getActiveSubscription(String userId) async {
    final response = await _supabaseClient
        .from(_subscriptionsTable)
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();

    return response;
  }

  /// Tạo hoặc gia hạn gói đăng ký Pro
  Future<void> createOrUpdateSubscription({
    required String userId,
    required String planType,
    required DateTime endDate,
  }) async {
    await _supabaseClient.from(_subscriptionsTable).insert({
      'user_id': userId,
      'plan_type': planType,
      'status': 'active',
      'start_date': DateTime.now().toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
