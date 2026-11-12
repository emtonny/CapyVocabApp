import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CurrentUserProfile {
  const CurrentUserProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
  });

  factory CurrentUserProfile.fromRemote(
    Map<String, dynamic> row, {
    required String expectedUserId,
  }) {
    final id = row['id'];
    if (id is! String || id != expectedUserId) {
      throw const FormatException('Invalid current-user profile identity.');
    }
    final rawDisplayName = row['display_name'];
    final rawAvatarUrl = row['avatar_url'];
    if (rawDisplayName != null && rawDisplayName is! String ||
        rawAvatarUrl != null && rawAvatarUrl is! String) {
      throw const FormatException('Invalid current-user profile fields.');
    }
    final avatarUrl = (rawAvatarUrl as String?)?.trim();
    return CurrentUserProfile(
      id: id,
      displayName: (rawDisplayName as String?)?.trim() ?? '',
      avatarUrl: avatarUrl == null || avatarUrl.isEmpty ? null : avatarUrl,
    );
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
}

final currentUserProfileProvider =
    FutureProvider.autoDispose<CurrentUserProfile?>((ref) async {
  final session = ref.watch(authProvider).asData?.value;
  if (session == null) return null;

  final row = await SupabaseService.client
      .from('users')
      .select('id, display_name, avatar_url')
      .eq('id', session.user.id)
      .maybeSingle();
  if (row == null) return null;
  return CurrentUserProfile.fromRemote(row, expectedUserId: session.user.id);
});
