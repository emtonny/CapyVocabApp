import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/data/datasources/notification_supabase_datasource.dart';
import '../../data/datasources/user_supabase_datasource.dart';

typedef HomeProfileStream = Stream<Map<String, dynamic>?> Function(
  String userId,
);

typedef HomeNotificationStream = Stream<List<Map<String, dynamic>>> Function(
  String userId,
);

typedef HomeRetryDelay = Future<void> Function(Duration duration);

const _homeRetryDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

class HomeState {
  const HomeState({
    required this.userId,
    required this.displayName,
    required this.yuzuBalance,
    required this.pendingYuzu,
    required this.streakDays,
    required this.updatedAt,
    this.isOffline = false,
  });

  factory HomeState.fromProfile({
    required String userId,
    required Map<String, dynamic> profile,
  }) {
    final displayName = profile['display_name'];
    final updatedAt = DateTime.tryParse('${profile['updated_at'] ?? ''}');
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const FormatException('Hồ sơ chưa có tên hiển thị hợp lệ.');
    }
    if (updatedAt == null) {
      throw const FormatException('Hồ sơ chưa có thời gian cập nhật hợp lệ.');
    }
    return HomeState(
      userId: userId,
      displayName: displayName.trim(),
      yuzuBalance: _nonNegativeInt(profile['total_coins'], 'total_coins'),
      pendingYuzu: 0,
      streakDays: _nonNegativeInt(profile['streak_days'], 'streak_days'),
      updatedAt: updatedAt.toLocal(),
    );
  }

  final String userId;
  final String displayName;
  final int yuzuBalance;
  final int pendingYuzu;
  final int streakDays;
  final DateTime updatedAt;
  final bool isOffline;

  HomeState copyWith({
    int? pendingYuzu,
    bool? isOffline,
  }) {
    return HomeState(
      userId: userId,
      displayName: displayName,
      yuzuBalance: yuzuBalance,
      pendingYuzu: pendingYuzu ?? this.pendingYuzu,
      streakDays: streakDays,
      updatedAt: updatedAt,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'yuzu_balance': yuzuBalance,
        'pending_yuzu': pendingYuzu,
        'streak_days': streakDays,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static HomeState? fromJson(Map<String, dynamic> json, String ownerId) {
    if (json['user_id'] != ownerId) return null;
    final displayName = json['display_name'];
    final updatedAt = DateTime.tryParse('${json['updated_at'] ?? ''}');
    if (displayName is! String ||
        displayName.trim().isEmpty ||
        updatedAt == null) {
      return null;
    }
    try {
      return HomeState(
        userId: ownerId,
        displayName: displayName.trim(),
        yuzuBalance: _nonNegativeInt(json['yuzu_balance'], 'yuzu_balance'),
        pendingYuzu: _nonNegativeInt(json['pending_yuzu'], 'pending_yuzu'),
        streakDays: _nonNegativeInt(json['streak_days'], 'streak_days'),
        updatedAt: updatedAt.toLocal(),
        isOffline: true,
      );
    } on FormatException {
      return null;
    }
  }
}

abstract interface class HomeSummaryCache {
  Future<HomeState?> read(String userId);

  Future<void> write(HomeState state);
}

class SharedPreferencesHomeSummaryCache implements HomeSummaryCache {
  static const _keyPrefix = 'home_summary_v1_';

  @override
  Future<HomeState?> read(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_keyPrefix$userId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? HomeState.fromJson(decoded, userId)
          : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(HomeState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_keyPrefix${state.userId}',
      jsonEncode(state.toJson()),
    );
  }
}

final homeSummaryCacheProvider = Provider<HomeSummaryCache>(
  (_) => SharedPreferencesHomeSummaryCache(),
);

final homeProfileStreamProvider = Provider<HomeProfileStream>((_) {
  final source = UserSupabaseDataSource();
  return source.streamUserProfile;
});

final homeNotificationStreamProvider = Provider<HomeNotificationStream>((_) {
  final source = NotificationSupabaseDataSource();
  return source.streamNotifications;
});

final homeProvider = StreamProvider.autoDispose<HomeState>((ref) async* {
  final session = ref.watch(authProvider).asData?.value;
  if (session == null) {
    throw StateError('Bạn cần đăng nhập để mở Trang chủ.');
  }

  yield* streamHomeState(
    userId: session.user.id,
    cache: ref.watch(homeSummaryCacheProvider),
    profiles: ref.watch(homeProfileStreamProvider),
  );
});

Stream<HomeState> streamHomeState({
  required String userId,
  required HomeSummaryCache cache,
  required HomeProfileStream profiles,
  HomeRetryDelay? retryDelay,
}) async* {
  final wait = retryDelay ?? Future<void>.delayed;
  HomeState? cached;
  try {
    cached = await cache.read(userId);
  } catch (_) {
    // A broken local cache must not block fresh profile data.
  }
  HomeState? latest = cached;
  if (cached != null) yield cached;

  var retryIndex = 0;
  while (true) {
    try {
      await for (final profile in profiles(userId)) {
        if (profile == null) continue;
        final next = HomeState.fromProfile(
          userId: userId,
          profile: profile,
        );
        latest = next;
        retryIndex = 0;
        try {
          await cache.write(next);
        } catch (_) {
          // The confirmed server value remains usable when persistence fails.
        }
        yield next;
      }
      return;
    } catch (error, stackTrace) {
      final fallback = latest;
      if (fallback == null) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      latest = fallback.copyWith(isOffline: true);
      yield latest;

      final delayIndex = retryIndex.clamp(0, _homeRetryDelays.length - 1);
      final delay = _homeRetryDelays[delayIndex];
      if (retryIndex < _homeRetryDelays.length - 1) retryIndex++;
      await wait(delay);
    }
  }
}

final homeUnreadNotificationsProvider = StreamProvider.autoDispose<int>((ref) {
  final session = ref.watch(authProvider).asData?.value;
  if (session == null) return Stream.value(0);
  return ref.watch(homeNotificationStreamProvider)(session.user.id).map(
        (rows) => rows.where((row) => row['is_read'] == false).length,
      );
});

int _nonNegativeInt(Object? value, String field) {
  if (value is num) {
    final integer = value.toInt();
    if (integer >= 0 && integer == value) return integer;
  }
  throw FormatException('$field phải là số nguyên không âm.');
}
