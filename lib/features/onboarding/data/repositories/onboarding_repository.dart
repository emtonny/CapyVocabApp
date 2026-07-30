import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/onboarding_data.dart';

abstract class OnboardingRepository {
  Future<OnboardingData> loadDraft();

  Future<bool> isUsernameAvailable(String username);

  Future<void> completeOnboarding(OnboardingData data);
}

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  User get _currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const OnboardingRepositoryException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    return user;
  }

  @override
  Future<OnboardingData> loadDraft() async {
    try {
      final user = _currentUser;
      final profile = await _client
          .from('users')
          .select('display_name, username, age, phone, account_role')
          .eq('id', user.id)
          .single();
      final settings = await _client
          .from('user_settings')
          .select('reminder_time, daily_target_words')
          .eq('user_id', user.id)
          .maybeSingle();

      return OnboardingData(
        displayName: profile['display_name'] as String? ?? '',
        username: profile['username'] as String? ?? '',
        age: (profile['age'] as num?)?.toInt(),
        phone: profile['phone'] as String? ?? '',
        accountRole: profile['account_role'] as String?,
        reminderTime: settings?['reminder_time'] as String? ?? '20:00',
        dailyTargetWords:
            (settings?['daily_target_words'] as num?)?.toInt() ?? 10,
      );
    } on OnboardingRepositoryException {
      rethrow;
    } catch (error) {
      throw OnboardingRepositoryException(
        'Không thể tải thông tin thiết lập. Vui lòng thử lại.',
        cause: error,
      );
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final user = _currentUser;
      final response = await _client
          .from('users')
          .select('id')
          .eq('username', username.trim().toLowerCase())
          .neq('id', user.id)
          .count(CountOption.exact);

      return response.count == 0;
    } on OnboardingRepositoryException {
      rethrow;
    } catch (error) {
      throw OnboardingRepositoryException(
        'Không thể kiểm tra tên đăng nhập. Vui lòng thử lại.',
        cause: error,
      );
    }
  }

  @override
  Future<void> completeOnboarding(OnboardingData data) async {
    final normalized = data.normalized();

    try {
      final result = await _client.rpc(
        'complete_onboarding',
        params: {
          'p_display_name': normalized.displayName,
          'p_username': normalized.username,
          'p_age': normalized.age,
          'p_phone': normalized.phone,
          'p_account_role': normalized.accountRole,
          'p_reminder_time': normalized.reminderTime,
          'p_daily_target_words': normalized.dailyTargetWords,
        },
      );

      if (result != true) {
        throw const OnboardingRepositoryException(
          'Máy chủ chưa xác nhận hoàn tất thiết lập. Vui lòng thử lại.',
        );
      }
    } on OnboardingRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw OnboardingRepositoryException(
          'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.',
          cause: error,
        );
      }
      throw OnboardingRepositoryException(
        'Không thể lưu thông tin thiết lập. Vui lòng thử lại.',
        cause: error,
      );
    } catch (error) {
      throw OnboardingRepositoryException(
        'Không thể lưu thông tin thiết lập. Vui lòng thử lại.',
        cause: error,
      );
    }
  }
}

class OnboardingRepositoryException implements Exception {
  const OnboardingRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
