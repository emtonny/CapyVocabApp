import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/entitlements/entitlement_provider.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Đăng ký gói Pro / Subscriptions
class SubscriptionSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  SubscriptionSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  /// Lấy thông tin gói Pro hiện tại của User
  Future<Map<String, dynamic>?> getActiveSubscription(String userId) {
    return loadActiveSubscriptionForUser(_supabaseClient, userId);
  }
}
