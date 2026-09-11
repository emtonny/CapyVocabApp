import '../../../../core/services/supabase_service.dart';

Future<bool> loadSupabaseOnboardingStatus(String userId) async {
  final profile = await SupabaseService.client
      .from('users')
      .select('onboarding_completed')
      .eq('id', userId)
      .maybeSingle();
  return profile?['onboarding_completed'] == true;
}
