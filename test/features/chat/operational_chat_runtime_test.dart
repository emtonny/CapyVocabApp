import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_runtime.dart';
import 'package:capy_vocab/features/language_profile/application/language_profile_store.dart';
import 'package:capy_vocab/features/language_profile/data/language_profile_repository.dart';
import 'package:capy_vocab/features/language_profile/domain/entities/language_profile.dart';
import 'package:capy_vocab/features/language_profile/presentation/language_profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the signed-in language profile without opening Settings',
      (tester) async {
    final store = MemoryLanguageProfileStore();
    final repository = _FakeLanguageProfileRepository();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLanguageProfileUserIdProvider.overrideWithValue('user-a'),
          languageProfileStoreProvider.overrideWithValue(store),
          languageProfileRepositoryProvider.overrideWithValue(repository),
          operationalChatCoordinatorProvider.overrideWith((_) async => null),
        ],
        child: const OperationalChatRuntime(
          child: MaterialApp(home: SizedBox()),
        ),
      ),
    );
    await tester.pump();

    expect(repository.loadedUserIds, ['user-a']);
    expect(store.profileFor('user-a')?.nativeLanguageCode, 'en');
  });
}

class _FakeLanguageProfileRepository implements LanguageProfileRepository {
  final List<String> loadedUserIds = [];

  @override
  Future<LanguageProfile?> load(String userId) async {
    loadedUserIds.add(userId);
    return LanguageProfile(
      userId: userId,
      nativeLanguageCode: 'en',
      learningLanguageCode: 'vi',
    );
  }

  @override
  Future<void> save(LanguageProfile profile) => throw UnimplementedError();
}
