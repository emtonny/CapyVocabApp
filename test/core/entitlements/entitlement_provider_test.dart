import 'dart:async';

import 'package:capy_vocab/core/entitlements/entitlement_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 28, 12);

  test('không đăng nhập mặc định Free và không đọc subscription', () async {
    var loadCount = 0;
    final notifier = EntitlementNotifier(
      initialUserId: null,
      authUserIds: const Stream.empty(),
      loadActiveSubscription: (userId) async {
        loadCount++;
        return null;
      },
      now: () => now,
    );
    addTearDown(notifier.dispose);

    await notifier.refresh();

    expect(loadCount, 0);
    expect(notifier.state.serviceTier, AppServiceTier.free);
    expect(notifier.state.can(AppCapability.aiScanBasic), isTrue);
    expect(notifier.state.can(AppCapability.aiScanAdvanced), isFalse);
    expect(notifier.state.isPro, isFalse);
  });

  test('subscription Pro hợp lệ cấp đúng capability', () async {
    final notifier = EntitlementNotifier(
      initialUserId: 'user-1',
      authUserIds: const Stream.empty(),
      loadActiveSubscription: (userId) async => {
        'plan_type': 'capy_pro_monthly',
        'end_date': now.add(const Duration(days: 30)).toIso8601String(),
      },
      now: () => now,
    );
    addTearDown(notifier.dispose);

    await notifier.refresh();

    expect(notifier.state.serviceTier, AppServiceTier.pro);
    expect(notifier.state.isPro, isTrue);
    expect(notifier.state.can(AppCapability.aiScanBasic), isTrue);
    expect(notifier.state.can(AppCapability.aiScanAdvanced), isTrue);
    expect(notifier.state.can(AppCapability.unlimitedScan), isFalse);
  });

  test('plan không hỗ trợ hoặc đã hết hạn vẫn là Free', () async {
    for (final subscription in [
      {
        'plan_type': 'unknown_plan',
        'end_date': now.add(const Duration(days: 30)).toIso8601String(),
      },
      {
        'plan_type': 'capy_pro_monthly',
        'end_date': now.subtract(const Duration(seconds: 1)).toIso8601String(),
      },
    ]) {
      final notifier = EntitlementNotifier(
        initialUserId: 'user-1',
        authUserIds: const Stream.empty(),
        loadActiveSubscription: (userId) async => subscription,
        now: () => now,
      );
      await notifier.refresh();

      expect(notifier.state.serviceTier, AppServiceTier.free);
      expect(notifier.state.can(AppCapability.aiScanAdvanced), isFalse);
      notifier.dispose();
    }
  });

  test('refresh sau thanh toán tải lại quyền từ server', () async {
    var paid = false;
    final notifier = EntitlementNotifier(
      initialUserId: 'user-1',
      authUserIds: const Stream.empty(),
      loadActiveSubscription: (userId) async => paid
          ? {
              'plan_type': 'capy_pro_monthly',
              'end_date': now.add(const Duration(days: 30)).toIso8601String(),
            }
          : null,
      now: () => now,
    );
    addTearDown(notifier.dispose);

    await notifier.refresh();
    expect(notifier.state.isPro, isFalse);

    paid = true;
    await notifier.refresh();

    expect(notifier.state.isPro, isTrue);
    expect(notifier.state.can(AppCapability.aiScanAdvanced), isTrue);
  });

  test('auth stream khôi phục Pro trên thiết bị mới và xóa quyền khi logout',
      () async {
    final authUserIds = StreamController<String?>.broadcast();
    final notifier = EntitlementNotifier(
      initialUserId: null,
      authUserIds: authUserIds.stream,
      loadActiveSubscription: (userId) async => {
        'plan_type': 'capy_pro_monthly',
        'end_date': now.add(const Duration(days: 30)).toIso8601String(),
      },
      now: () => now,
    );
    addTearDown(() async {
      notifier.dispose();
      await authUserIds.close();
    });

    final restored = _nextStateWhere(notifier, (state) => state.isPro);
    authUserIds.add('restored-user');
    expect((await restored).can(AppCapability.aiScanAdvanced), isTrue);

    final signedOut = _nextStateWhere(
      notifier,
      (state) => state.serviceTier == AppServiceTier.free && !state.isLoading,
    );
    authUserIds.add(null);
    expect((await signedOut).can(AppCapability.aiScanAdvanced), isFalse);
  });

  test('subscription lỗi fail closed về Free', () async {
    final notifier = EntitlementNotifier(
      initialUserId: 'user-1',
      authUserIds: const Stream.empty(),
      loadActiveSubscription: (userId) async => throw Exception('offline'),
      now: () => now,
    );
    addTearDown(notifier.dispose);

    await notifier.refresh();

    expect(notifier.state.hasError, isTrue);
    expect(notifier.state.serviceTier, AppServiceTier.free);
    expect(notifier.state.can(AppCapability.aiScanAdvanced), isFalse);
  });

  test('kết quả tải cũ không thể cấp lại Pro sau khi logout', () async {
    final authUserIds = StreamController<String?>.broadcast();
    final delayedSubscription = Completer<Map<String, dynamic>?>();
    final notifier = EntitlementNotifier(
      initialUserId: 'user-1',
      authUserIds: authUserIds.stream,
      loadActiveSubscription: (userId) => delayedSubscription.future,
      now: () => now,
    );
    addTearDown(() async {
      notifier.dispose();
      await authUserIds.close();
    });

    final signedOut = _nextStateWhere(
      notifier,
      (state) => state.serviceTier == AppServiceTier.free && !state.isLoading,
    );
    authUserIds.add(null);
    await signedOut;

    delayedSubscription.complete({
      'plan_type': 'capy_pro_monthly',
      'end_date': now.add(const Duration(days: 30)).toIso8601String(),
    });
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.serviceTier, AppServiceTier.free);
    expect(notifier.state.can(AppCapability.aiScanAdvanced), isFalse);
  });
}

Future<AppEntitlements> _nextStateWhere(
  EntitlementNotifier notifier,
  bool Function(AppEntitlements state) predicate,
) {
  if (predicate(notifier.state)) return Future.value(notifier.state);

  final completer = Completer<AppEntitlements>();
  late final void Function() removeListener;
  removeListener = notifier.addListener(
    (state) {
      if (!predicate(state) || completer.isCompleted) return;
      completer.complete(state);
    },
    fireImmediately: false,
  );
  return completer.future
      .timeout(const Duration(seconds: 2))
      .whenComplete(removeListener);
}
