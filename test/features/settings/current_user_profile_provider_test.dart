import 'package:capy_vocab/features/settings/presentation/providers/current_user_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = '10000000-0000-4000-8000-000000000001';

  test('maps the authenticated user profile and trims avatar URL', () {
    final profile = CurrentUserProfile.fromRemote(
      const {
        'id': userId,
        'display_name': ' Capy ',
        'avatar_url': ' https://cdn.example.com/capy.png ',
      },
      expectedUserId: userId,
    );

    expect(profile.displayName, 'Capy');
    expect(profile.avatarUrl, 'https://cdn.example.com/capy.png');
  });

  test('normalizes an empty database avatar to null', () {
    final profile = CurrentUserProfile.fromRemote(
      const {'id': userId, 'display_name': 'Capy', 'avatar_url': '   '},
      expectedUserId: userId,
    );

    expect(profile.avatarUrl, isNull);
  });

  test('rejects a profile belonging to another user', () {
    expect(
      () => CurrentUserProfile.fromRemote(
        const {
          'id': '20000000-0000-4000-8000-000000000002',
          'display_name': 'Other',
          'avatar_url': null,
        },
        expectedUserId: userId,
      ),
      throwsFormatException,
    );
  });
}
