import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/onboarding_data.dart';

abstract class OnboardingRepository {
  Future<OnboardingData> loadDraft();

  Future<bool> isUsernameAvailable(String username);

  Future<bool> isPhoneAvailable(String phone);

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
          .select('reminder_time, study_end_time, daily_target_words')
          .eq('user_id', user.id)
          .maybeSingle();

      return OnboardingData(
        displayName: profile['display_name'] as String? ?? '',
        username: profile['username'] as String? ?? '',
        age: (profile['age'] as num?)?.toInt(),
        phone: profile['phone'] as String? ?? '',
        accountRole: profile['account_role'] as String?,
        reminderTime: settings?['reminder_time'] as String? ?? '20:00',
        studyEndTime: settings?['study_end_time'] as String? ?? '21:00',
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
      final response = await _client.rpc(
        'check_username_available',
        params: {'p_username': username.trim().toLowerCase()},
      );
      if (response is bool) return response;

      throw const OnboardingRepositoryException(
        'Không thể kiểm tra tên đăng nhập. Vui lòng thử lại.',
      );
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
  Future<bool> isPhoneAvailable(String phone) async {
    try {
      final response = await _client.rpc(
        'check_phone_available',
        params: {'p_phone': phone.trim()},
      );
      if (response is bool) return response;

      throw const OnboardingRepositoryException(
        'Không thể kiểm tra số điện thoại. Vui lòng thử lại.',
      );
    } on OnboardingRepositoryException {
      rethrow;
    } catch (error) {
      throw OnboardingRepositoryException(
        'Không thể kiểm tra số điện thoại. Vui lòng thử lại.',
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
          'p_study_end_time': normalized.studyEndTime,
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
        throw _mapUniqueViolation(error);
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

  OnboardingRepositoryException _mapUniqueViolation(
    PostgrestException error,
  ) {
    final message = error.message.toLowerCase();
    final details = error.details?.toString().toLowerCase() ?? '';

    if (message.contains('users_username_key') ||
        details.contains('key (username)')) {
      return OnboardingRepositoryException(
        'Tên đăng nhập đã được sử dụng. Vui lòng chọn tên khác.',
        cause: error,
        conflictingField: OnboardingConflictField.username,
      );
    }
    if (message.contains('users_phone_key') ||
        details.contains('key (phone)')) {
      return OnboardingRepositoryException(
        'Số điện thoại đã được sử dụng. Vui lòng dùng số khác.',
        cause: error,
        conflictingField: OnboardingConflictField.phone,
      );
    }
    if (message.contains('users_email_key') ||
        details.contains('key (email)')) {
      return OnboardingRepositoryException(
        'Email đã được sử dụng. Vui lòng dùng email khác.',
        cause: error,
        conflictingField: OnboardingConflictField.email,
      );
    }

    return OnboardingRepositoryException(
      'Thông tin tài khoản đã được sử dụng. Vui lòng kiểm tra lại.',
      cause: error,
    );
  }
}

enum OnboardingConflictField { username, phone, email }

class OnboardingRepositoryException implements Exception {
  const OnboardingRepositoryException(
    this.message, {
    this.cause,
    this.conflictingField,
  });

  final String message;
  final Object? cause;
  final OnboardingConflictField? conflictingField;

  @override
  String toString() => message;
}
