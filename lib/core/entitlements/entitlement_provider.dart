import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

enum AppServiceTier { free, pro }

enum AppCapability {
  aiScanBasic,
  aiScanAdvanced,
  unlimitedScan,
  advancedStatistics,
  premiumGames,
  cloudBackup,
  priorityProcessing,
}

enum AppEntitlementStatus { loading, ready, error }

class AppEntitlements {
  const AppEntitlements._({
    required this.serviceTier,
    required this.capabilities,
    required this.status,
    this.subscriptionEndDate,
    this.error,
  });

  static const free = AppEntitlements._(
    serviceTier: AppServiceTier.free,
    capabilities: {AppCapability.aiScanBasic},
    status: AppEntitlementStatus.ready,
  );

  static const loading = AppEntitlements._(
    serviceTier: AppServiceTier.free,
    capabilities: {AppCapability.aiScanBasic},
    status: AppEntitlementStatus.loading,
  );

  factory AppEntitlements.pro(DateTime subscriptionEndDate) {
    return AppEntitlements._(
      serviceTier: AppServiceTier.pro,
      capabilities: const {
        AppCapability.aiScanBasic,
        AppCapability.aiScanAdvanced,
      },
      status: AppEntitlementStatus.ready,
      subscriptionEndDate: subscriptionEndDate,
    );
  }

  factory AppEntitlements.failed(Object error) {
    return AppEntitlements._(
      serviceTier: AppServiceTier.free,
      capabilities: const {AppCapability.aiScanBasic},
      status: AppEntitlementStatus.error,
      error: error,
    );
  }

  final AppServiceTier serviceTier;
  final Set<AppCapability> capabilities;
  final AppEntitlementStatus status;
  final DateTime? subscriptionEndDate;
  final Object? error;

  bool can(AppCapability capability) => capabilities.contains(capability);
  bool get isPro => serviceTier == AppServiceTier.pro;
  bool get isLoading => status == AppEntitlementStatus.loading;
  bool get hasError => status == AppEntitlementStatus.error;
}

typedef ActiveSubscriptionLoader = Future<Map<String, dynamic>?> Function(
  String userId,
);

Future<Map<String, dynamic>?> loadActiveSubscriptionForUser(
  SupabaseClient client,
  String userId, {
  DateTime? now,
}) {
  final currentTime = (now ?? DateTime.now()).toUtc();
  return client
      .from('subscriptions')
      .select('plan_type,end_date')
      .eq('user_id', userId)
      .eq('status', 'active')
      .gt('end_date', currentTime.toIso8601String())
      .order('end_date', ascending: false)
      .limit(1)
      .maybeSingle();
}

class EntitlementNotifier extends StateNotifier<AppEntitlements> {
  EntitlementNotifier({
    required String? initialUserId,
    required Stream<String?> authUserIds,
    required ActiveSubscriptionLoader loadActiveSubscription,
    DateTime Function()? now,
  })  : _currentUserId = initialUserId,
        _loadActiveSubscription = loadActiveSubscription,
        _now = now ?? DateTime.now,
        super(
          initialUserId == null
              ? AppEntitlements.free
              : AppEntitlements.loading,
        ) {
    _authSubscription = authUserIds.distinct().listen(
          _handleAuthUser,
          onError: _handleAuthError,
        );
    if (initialUserId != null) unawaited(_load(initialUserId));
  }

  final ActiveSubscriptionLoader _loadActiveSubscription;
  final DateTime Function() _now;
  late final StreamSubscription<String?> _authSubscription;

  String? _currentUserId;
  int _loadVersion = 0;
  bool _disposed = false;

  Future<void> refresh() => _load(_currentUserId);

  void _handleAuthUser(String? userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    unawaited(_load(userId));
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    _loadVersion++;
    state = AppEntitlements.failed(error);
  }

  Future<void> _load(String? userId) async {
    final loadVersion = ++_loadVersion;
    if (userId == null) {
      if (!_disposed) state = AppEntitlements.free;
      return;
    }

    state = AppEntitlements.loading;
    try {
      final subscription = await _loadActiveSubscription(userId);
      if (_disposed || loadVersion != _loadVersion) return;
      state = _resolve(subscription, _now().toUtc());
    } catch (error) {
      if (_disposed || loadVersion != _loadVersion) return;
      state = AppEntitlements.failed(error);
    }
  }

  static AppEntitlements _resolve(
    Map<String, dynamic>? subscription,
    DateTime now,
  ) {
    if (subscription?['plan_type'] != 'capy_pro_monthly') {
      return AppEntitlements.free;
    }
    final rawEndDate = subscription?['end_date'];
    final endDate = rawEndDate is String ? DateTime.tryParse(rawEndDate) : null;
    if (endDate == null || !endDate.toUtc().isAfter(now)) {
      return AppEntitlements.free;
    }
    return AppEntitlements.pro(endDate.toUtc());
  }

  @override
  void dispose() {
    _disposed = true;
    _loadVersion++;
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}

final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, AppEntitlements>((ref) {
  DateTime now() => DateTime.now().toUtc();

  return EntitlementNotifier(
    initialUserId: SupabaseService.auth.currentUser?.id,
    authUserIds: SupabaseService.auth.onAuthStateChange.map(
      (authState) => authState.session?.user.id,
    ),
    loadActiveSubscription: (userId) => loadActiveSubscriptionForUser(
      SupabaseService.client,
      userId,
      now: now(),
    ),
    now: now,
  );
});
