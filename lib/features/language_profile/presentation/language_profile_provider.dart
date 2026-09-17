import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../application/language_profile_store.dart';
import '../data/language_profile_repository.dart';
import '../domain/entities/language_profile.dart';

final languageProfileStoreProvider = Provider<LanguageProfileStore>((ref) {
  final store = MemoryLanguageProfileStore();
  ref.onDispose(store.dispose);
  return store;
});

final languageProfileRepositoryProvider = Provider<LanguageProfileRepository>(
  (ref) => SupabaseLanguageProfileRepository(),
);

final currentLanguageProfileUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.valueOrNull?.user.id ??
      SupabaseService.auth.currentSession?.user.id;
});

class LanguageProfileState {
  const LanguageProfileState({
    this.profile,
    this.isRefreshing = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final LanguageProfile? profile;
  final bool isRefreshing;
  final bool isSaving;
  final String? errorMessage;

  LanguageProfileState copyWith({
    LanguageProfile? profile,
    bool? isRefreshing,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LanguageProfileState(
      profile: profile ?? this.profile,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LanguageProfileNotifier extends StateNotifier<LanguageProfileState> {
  LanguageProfileNotifier({
    required String? userId,
    required LanguageProfileStore store,
    required LanguageProfileRepository repository,
  })  : _userId = userId,
        _store = store,
        _repository = repository,
        super(LanguageProfileState(
          profile: userId == null ? null : store.profileFor(userId),
        )) {
    if (userId != null) unawaited(refresh());
  }

  final String? _userId;
  final LanguageProfileStore _store;
  final LanguageProfileRepository _repository;

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final profile = await _repository.load(userId);
      if (profile == null) {
        await _store.removeProfile(userId);
      } else {
        await _store.setProfile(profile);
      }
      state = LanguageProfileState(profile: profile);
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: 'Không thể tải hồ sơ ngôn ngữ.',
      );
    }
  }

  Future<bool> save({
    required String nativeLanguageCode,
    required String learningLanguageCode,
    required String proficiencyLevel,
  }) async {
    final userId = _userId;
    if (userId == null || state.isSaving) return false;
    final profile = LanguageProfile(
      userId: userId,
      nativeLanguageCode: nativeLanguageCode,
      learningLanguageCode: learningLanguageCode,
      proficiencyLevel: proficiencyLevel,
    );
    if (!profile.isValid) {
      state = state.copyWith(
        errorMessage: 'Ngôn ngữ gốc và ngôn ngữ học phải khác nhau.',
      );
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repository.save(profile);
      await _store.setProfile(profile);
      state = LanguageProfileState(profile: profile);
      return true;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Không thể lưu hồ sơ ngôn ngữ. Vui lòng thử lại.',
      );
      return false;
    }
  }
}

final languageProfileProvider =
    StateNotifierProvider<LanguageProfileNotifier, LanguageProfileState>((ref) {
  return LanguageProfileNotifier(
    userId: ref.watch(currentLanguageProfileUserIdProvider),
    store: ref.watch(languageProfileStoreProvider),
    repository: ref.watch(languageProfileRepositoryProvider),
  );
});
