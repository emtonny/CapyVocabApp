import 'package:capy_vocab/features/language_profile/application/language_profile_store.dart';
import 'package:capy_vocab/features/language_profile/domain/entities/language_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cache persists profiles without mixing users', () async {
    final store = await SharedPreferencesLanguageProfileStore.create();
    await store.setProfile(
      const LanguageProfile(
        userId: 'user-a',
        nativeLanguageCode: 'vi',
        learningLanguageCode: 'en',
      ),
    );
    await store.setProfile(
      const LanguageProfile(
        userId: 'user-b',
        nativeLanguageCode: 'en',
        learningLanguageCode: 'vi',
        proficiencyLevel: 'advanced',
      ),
    );

    final restored = await SharedPreferencesLanguageProfileStore.create();
    expect(restored.profileFor('user-a')?.nativeLanguageCode, 'vi');
    expect(restored.profileFor('user-a')?.learningLanguageCode, 'en');
    expect(restored.profileFor('user-b')?.nativeLanguageCode, 'en');
    expect(restored.profileFor('user-b')?.proficiencyLevel, 'advanced');
    expect(restored.profileFor('unknown-user'), isNull);
  });

  test('invalid or mismatched cached profile fails closed', () async {
    SharedPreferences.setMockInitialValues({
      'language_profile_v1.user-a':
          '{"user_id":"user-b","native_language_code":"vi",'
              '"learning_language_code":"en"}',
      'language_profile_v1.user-c':
          '{"user_id":"user-c","native_language_code":"vi",'
              '"learning_language_code":"vi"}',
    });

    final store = await SharedPreferencesLanguageProfileStore.create();
    expect(store.profileFor('user-a'), isNull);
    expect(store.profileFor('user-b'), isNull);
    expect(store.profileFor('user-c'), isNull);
  });

  test('remove clears only the requested owner', () async {
    final store = await SharedPreferencesLanguageProfileStore.create();
    await store.setProfile(
      const LanguageProfile(
        userId: 'user-a',
        nativeLanguageCode: 'vi',
        learningLanguageCode: 'en',
      ),
    );
    await store.setProfile(
      const LanguageProfile(
        userId: 'user-b',
        nativeLanguageCode: 'en',
        learningLanguageCode: 'vi',
      ),
    );

    await store.removeProfile('user-a');
    final restored = await SharedPreferencesLanguageProfileStore.create();
    expect(restored.profileFor('user-a'), isNull);
    expect(restored.profileFor('user-b'), isNotNull);
  });
}
