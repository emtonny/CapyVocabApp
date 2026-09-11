import 'package:capy_vocab/core/entitlements/entitlement_provider.dart';
import 'dart:async';

import 'package:capy_vocab/features/auth/domain/repositories/auth_repository.dart';
import 'package:capy_vocab/features/auth/presentation/providers/auth_provider.dart';
import 'package:capy_vocab/features/library/domain/entities/library_enums.dart';
import 'package:capy_vocab/features/library/domain/entities/local_account.dart';
import 'package:capy_vocab/features/settings/presentation/providers/cloud_backup_consent_provider.dart';
import 'package:capy_vocab/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
  });

  testWidgets('hủy dialog không reset onboarding', (tester) async {
    var resetCallCount = 0;
    final repository = _RecordingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async => resetCallCount++,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('reset-onboarding-debug-button')),
      160,
    );
    await tester.tap(find.byKey(const Key('reset-onboarding-debug-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bạn chắc chắn muốn reset onboarding?'), findsOneWidget);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(resetCallCount, 0);
    expect(repository.signOutCallCount, 0);
    expect(find.text('SettingsScreen'), findsOneWidget);
  });

  testWidgets('RPC lỗi hiển thị thông báo và không đăng xuất', (tester) async {
    final repository = _RecordingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async => throw Exception('RPC failed'),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('reset-onboarding-debug-button')),
      160,
    );
    await tester.tap(find.byKey(const Key('reset-onboarding-debug-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể reset onboarding. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(repository.signOutCallCount, 0);
    expect(find.text('SettingsScreen'), findsOneWidget);
  });

  testWidgets('reset thành công rồi đăng xuất và điều hướng về auth',
      (tester) async {
    final calls = <String>[];
    final repository = _RecordingAuthRepository(
      onSignOut: () => calls.add('signOut'),
    );
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async => calls.add('rpc'),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('reset-onboarding-debug-button')),
      160,
    );
    await tester.tap(find.byKey(const Key('reset-onboarding-debug-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(calls, ['rpc', 'signOut']);
    expect(find.text('AuthScreen'), findsOneWidget);
  });

  testWidgets('hủy dialog đăng xuất không gọi signOut', (tester) async {
    final repository = _RecordingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async {},
    );

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn có chắc chắn muốn đăng xuất khỏi DeerVocab?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(repository.signOutCallCount, 0);
    expect(find.text('SettingsScreen'), findsOneWidget);
  });

  testWidgets('xác nhận đăng xuất gọi signOut và điều hướng về auth',
      (tester) async {
    final repository = _RecordingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async {},
    );

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn có chắc chắn muốn đăng xuất khỏi DeerVocab?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('logout-confirm-button')));
    await tester.pumpAndSettle();

    expect(repository.signOutCallCount, 1);
    expect(find.text('AuthScreen'), findsOneWidget);
  });

  testWidgets('đăng xuất lỗi hiển thị SnackBar lỗi', (tester) async {
    final repository = _FailingAuthRepository();
    await _pumpSettingsScreen(
      tester,
      repository: repository,
      resetOnboarding: () async {},
    );

    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout-confirm-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể đăng xuất. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('SettingsScreen'), findsOneWidget);
  });

  testWidgets('badge Pro dùng capability tập trung', (tester) async {
    final entitlements = EntitlementNotifier(
      initialUserId: 'pro-user',
      authUserIds: const Stream.empty(),
      loadActiveSubscription: (userId) async => {
        'plan_type': 'capy_pro_monthly',
        'end_date': DateTime.now()
            .toUtc()
            .add(const Duration(days: 30))
            .toIso8601String(),
      },
    );
    await entitlements.refresh();

    await _pumpSettingsScreen(
      tester,
      repository: _RecordingAuthRepository(),
      resetOnboarding: () async {},
      entitlementNotifier: entitlements,
    );

    expect(find.byKey(const Key('pro-badge')), findsOneWidget);
  });

  testWidgets('bật cloud backup cần xác nhận rõ trước khi ghi consent',
      (tester) async {
    final changes = <bool>[];
    await _pumpSettingsScreen(
      tester,
      repository: _RecordingAuthRepository(),
      resetOnboarding: () async {},
      libraryUserId: _userId,
      cloudBackupAccount: _account(cloudBackupEnabled: false),
      setCloudBackupConsent: (enabled) async => changes.add(enabled),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('cloud-backup-switch')),
      160,
    );
    await tester.tap(find.byKey(const Key('cloud-backup-switch')));
    await tester.pumpAndSettle();

    expect(find.text('Bật sao lưu đám mây?'), findsOneWidget);
    expect(find.textContaining('không cho phép dùng dữ liệu'), findsOneWidget);
    expect(changes, isEmpty);

    await tester.tap(find.byKey(const Key('cloud-backup-confirm-button')));
    await tester.pumpAndSettle();

    expect(changes, [true]);
    expect(
      find.text('Đã bật sao lưu. Bài cũ chỉ tải lên khi bạn chọn.'),
      findsOneWidget,
    );
  });

  testWidgets('hủy xác nhận không bật cloud backup', (tester) async {
    final changes = <bool>[];
    await _pumpSettingsScreen(
      tester,
      repository: _RecordingAuthRepository(),
      resetOnboarding: () async {},
      libraryUserId: _userId,
      cloudBackupAccount: _account(cloudBackupEnabled: false),
      setCloudBackupConsent: (enabled) async => changes.add(enabled),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('cloud-backup-switch')),
      160,
    );
    await tester.tap(find.byKey(const Key('cloud-backup-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cloud-backup-cancel-button')));
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
  });

  testWidgets('tắt cloud backup ngay và giải thích dữ liệu cloud chưa bị xóa',
      (tester) async {
    final changes = <bool>[];
    await _pumpSettingsScreen(
      tester,
      repository: _RecordingAuthRepository(),
      resetOnboarding: () async {},
      libraryUserId: _userId,
      cloudBackupAccount: _account(cloudBackupEnabled: true),
      setCloudBackupConsent: (enabled) async => changes.add(enabled),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('cloud-backup-switch')),
      160,
    );
    await tester.tap(find.byKey(const Key('cloud-backup-switch')));
    await tester.pumpAndSettle();

    expect(find.text('Bật sao lưu đám mây?'), findsNothing);
    expect(changes, [false]);
    expect(
      find.text('Đã tắt tải lên. Dữ liệu cloud hiện có chưa bị xóa.'),
      findsOneWidget,
    );
  });

  testWidgets('backfill bài cũ cần xác nhận và báo số bài được xếp',
      (tester) async {
    final consentChanges = <bool>[];
    var backfillCalls = 0;
    final result = Completer<CloudBackupBackfillResult>();
    await _pumpSettingsScreen(
      tester,
      repository: _RecordingAuthRepository(),
      resetOnboarding: () async {},
      libraryUserId: _userId,
      cloudBackupAccount: _account(cloudBackupEnabled: true),
      setCloudBackupConsent: (enabled) async => consentChanges.add(enabled),
      backfillExistingPhotoNotes: () async {
        backfillCalls++;
        return result.future;
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('cloud-backup-backfill-button')),
      160,
    );
    await tester.tap(find.byKey(const Key('cloud-backup-backfill-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sao lưu các bài đã có?'), findsOneWidget);
    expect(find.textContaining('bài trong thùng rác sẽ được bỏ qua'),
        findsOneWidget);
    expect(backfillCalls, 0);

    await tester
        .tap(find.byKey(const Key('cloud-backup-backfill-confirm-button')));
    await tester.pump();

    expect(backfillCalls, 1);
    expect(consentChanges, isEmpty);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('cloud-backup-switch')),
          )
          .onChanged,
      isNull,
    );
    result.complete((queuedCount: 2, missingMediaCount: 1));
    await tester.pumpAndSettle();
    expect(
      find.text('Đã xếp 2 bài cũ để sao lưu; bỏ qua 1 bài thiếu ảnh.'),
      findsOneWidget,
    );
  });
}

const _userId = '10000000-0000-4000-8000-000000000001';

LocalAccount _account({required bool cloudBackupEnabled}) {
  final timestamp = DateTime.utc(2026, 9, 4, 12);
  return LocalAccount(
    userId: _userId,
    accountState: AccountState.active,
    cloudBackupEnabled: cloudBackupEnabled,
    localPersonalizationEnabled: false,
    federatedContributionEnabled: false,
    lastAuthenticatedAt: timestamp,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  required AuthRepository repository,
  required ResetOnboarding resetOnboarding,
  EntitlementNotifier? entitlementNotifier,
  String? libraryUserId,
  LocalAccount? cloudBackupAccount,
  SetCloudBackupConsent? setCloudBackupConsent,
  BackfillExistingPhotoNotes? backfillExistingPhotoNotes,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const Scaffold(body: Text('AuthScreen')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        resetOnboardingProvider.overrideWithValue(resetOnboarding),
        if (entitlementNotifier != null)
          entitlementProvider.overrideWith((ref) => entitlementNotifier),
        if (libraryUserId != null)
          currentLibraryUserIdProvider.overrideWithValue(libraryUserId),
        if (cloudBackupAccount != null)
          cloudBackupConsentProvider.overrideWith(
            (ref) => Stream.value(cloudBackupAccount),
          ),
        if (setCloudBackupConsent != null)
          setCloudBackupConsentProvider.overrideWithValue(
            setCloudBackupConsent,
          ),
        if (backfillExistingPhotoNotes != null)
          backfillExistingPhotoNotesProvider.overrideWithValue(
            backfillExistingPhotoNotes,
          ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.onSignOut});

  final void Function()? onSignOut;
  int signOutCallCount = 0;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    onSignOut?.call();
  }

  @override
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> signInWithOAuth(OAuthProvider provider) {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }

  @override
  Future<void> updatePassword(String password) {
    throw UnimplementedError();
  }
}

class _FailingAuthRepository extends _RecordingAuthRepository {
  @override
  Future<void> signOut() async {
    throw Exception('Sign out failed');
  }
}
