import 'dart:async';

import 'package:capy_vocab/features/language_profile/application/language_profile_store.dart';
import 'package:capy_vocab/features/language_profile/data/language_profile_repository.dart';
import 'package:capy_vocab/features/language_profile/domain/entities/language_profile.dart';
import 'package:capy_vocab/features/language_profile/presentation/language_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached profile is available before background refresh finishes',
      () async {
    final store = MemoryLanguageProfileStore();
    await store.setProfile(_profileA);
    final remote = Completer<LanguageProfile?>();
    final repository = _FakeRepository(onLoad: (_) => remote.future);
    final notifier = LanguageProfileNotifier(
      userId: 'user-a',
      store: store,
      repository: repository,
    );
    addTearDown(notifier.dispose);
    addTearDown(store.dispose);

    expect(notifier.state.profile?.nativeLanguageCode, 'vi');
    expect(notifier.state.isRefreshing, isTrue);

    remote.complete(_profileA);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isRefreshing, isFalse);
  });

  test('failed refresh keeps owner cache and save writes remote before cache',
      () async {
    final store = MemoryLanguageProfileStore();
    await store.setProfile(_profileA);
    final repository = _FakeRepository(
      onLoad: (_) async => throw StateError('offline'),
    );
    final notifier = LanguageProfileNotifier(
      userId: 'user-a',
      store: store,
      repository: repository,
    );
    addTearDown(notifier.dispose);
    addTearDown(store.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.profile?.userId, 'user-a');
    expect(notifier.state.errorMessage, isNotNull);

    repository.saveError = StateError('server rejected');
    expect(
      await notifier.save(
        nativeLanguageCode: 'en',
        learningLanguageCode: 'vi',
        proficiencyLevel: 'advanced',
      ),
      isFalse,
    );
    expect(store.profileFor('user-a')?.nativeLanguageCode, 'vi');

    repository.saveError = null;
    expect(
      await notifier.save(
        nativeLanguageCode: 'en',
        learningLanguageCode: 'vi',
        proficiencyLevel: 'advanced',
      ),
      isTrue,
    );
    expect(store.profileFor('user-a')?.nativeLanguageCode, 'en');
    expect(repository.savedProfiles.single.userId, 'user-a');
  });

  test('same source and learning language is rejected before remote write',
      () async {
    final store = MemoryLanguageProfileStore();
    final repository = _FakeRepository(onLoad: (_) async => null);
    final notifier = LanguageProfileNotifier(
      userId: 'user-a',
      store: store,
      repository: repository,
    );
    addTearDown(notifier.dispose);
    addTearDown(store.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(
      await notifier.save(
        nativeLanguageCode: 'vi',
        learningLanguageCode: 'vi',
        proficiencyLevel: 'beginner',
      ),
      isFalse,
    );
    expect(repository.savedProfiles, isEmpty);
  });
}

const _profileA = LanguageProfile(
  userId: 'user-a',
  nativeLanguageCode: 'vi',
  learningLanguageCode: 'en',
);

class _FakeRepository implements LanguageProfileRepository {
  _FakeRepository({required this.onLoad});

  final Future<LanguageProfile?> Function(String userId) onLoad;
  final List<LanguageProfile> savedProfiles = [];
  Object? saveError;

  @override
  Future<LanguageProfile?> load(String userId) => onLoad(userId);

  @override
  Future<void> save(LanguageProfile profile) async {
    if (saveError case final error?) throw error;
    savedProfiles.add(profile);
  }
}
