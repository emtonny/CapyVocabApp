import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/entities/language_profile.dart';

abstract class LanguageProfileRepository {
  Future<LanguageProfile?> load(String userId);

  Future<void> save(LanguageProfile profile);
}

class SupabaseLanguageProfileRepository implements LanguageProfileRepository {
  SupabaseLanguageProfileRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  @override
  Future<LanguageProfile?> load(String userId) async {
    final row = await _client
        .from('user_language_profiles')
        .select(
          'user_id, native_language_code, learning_language_code, '
          'proficiency_level',
        )
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? null
        : LanguageProfile.tryFromJson(row.cast<String, Object?>());
  }

  @override
  Future<void> save(LanguageProfile profile) async {
    if (!profile.isValid) {
      throw ArgumentError.value(profile, 'profile', 'Invalid language profile');
    }
    await _client.from('user_language_profiles').upsert(
      profile.toJson(),
      onConflict: 'user_id',
    );
  }
}
