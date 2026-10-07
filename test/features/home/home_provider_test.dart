import 'package:capy_vocab/features/home/presentation/providers/home_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('maps the confirmed Supabase profile to Yuzu state', () {
    final state = HomeState.fromProfile(
      userId: 'owner-a',
      profile: {
        'display_name': 'Demo 1',
        'total_coins': 420,
        'streak_days': 7,
        'updated_at': '2026-09-27T01:30:00Z',
      },
    );

    expect(state.displayName, 'Demo 1');
    expect(state.yuzuBalance, 420);
    expect(state.pendingYuzu, 0);
    expect(state.streakDays, 7);
    expect(state.isOffline, isFalse);
  });

  test('restores the same account balance without leaking to another account',
      () async {
    final firstStore = SharedPreferencesHomeSummaryCache();
    await firstStore.write(
      HomeState(
        userId: 'owner-a',
        displayName: 'Demo 1',
        yuzuBalance: 420,
        pendingYuzu: 35,
        streakDays: 7,
        updatedAt: DateTime.utc(2026, 9, 27, 1, 30),
      ),
    );

    final reopenedStore = SharedPreferencesHomeSummaryCache();
    final restored = await reopenedStore.read('owner-a');

    expect(restored?.yuzuBalance, 420);
    expect(restored?.pendingYuzu, 35);
    expect(restored?.isOffline, isTrue);
    expect(await reopenedStore.read('owner-b'), isNull);
  });

  test('rejects negative money from remote and cached data', () async {
    expect(
      () => HomeState.fromProfile(
        userId: 'owner-a',
        profile: {
          'display_name': 'Demo 1',
          'total_coins': -1,
          'streak_days': 7,
          'updated_at': '2026-09-27T01:30:00Z',
        },
      ),
      throwsFormatException,
    );

    SharedPreferences.setMockInitialValues({
      'home_summary_v1_owner-a': '{"user_id":"owner-a","display_name":"Demo 1",'
          '"yuzu_balance":-1,"pending_yuzu":0,"streak_days":7,'
          '"updated_at":"2026-09-27T01:30:00Z"}',
    });
    expect(
      await SharedPreferencesHomeSummaryCache().read('owner-a'),
      isNull,
    );
  });

  test('reconnects after a transient profile stream failure', () async {
    final cache = _MemoryHomeSummaryCache(
      HomeState(
        userId: 'owner-a',
        displayName: 'Cached Demo',
        yuzuBalance: 100,
        pendingYuzu: 0,
        streakDays: 0,
        updatedAt: DateTime.utc(2026, 10, 1, 1, 5),
        isOffline: true,
      ),
    );
    var attempts = 0;
    final delays = <Duration>[];

    final states = await streamHomeState(
      userId: 'owner-a',
      cache: cache,
      profiles: (_) {
        attempts++;
        if (attempts == 1) {
          return Stream.error(StateError('temporary startup race'));
        }
        return Stream.value({
          'display_name': 'Fresh Demo',
          'total_coins': 130,
          'streak_days': 1,
          'updated_at': '2026-10-04T10:00:00Z',
        });
      },
      retryDelay: (duration) async => delays.add(duration),
    ).toList();

    expect(attempts, 2);
    expect(delays, const [Duration(seconds: 2)]);
    expect(states, hasLength(3));
    expect(states[0].isOffline, isTrue);
    expect(states[1].isOffline, isTrue);
    expect(states[2].isOffline, isFalse);
    expect(states[2].displayName, 'Fresh Demo');
    expect(states[2].yuzuBalance, 130);
    expect(cache.value?.displayName, 'Fresh Demo');
  });
}

class _MemoryHomeSummaryCache implements HomeSummaryCache {
  _MemoryHomeSummaryCache(this.value);

  HomeState? value;

  @override
  Future<HomeState?> read(String userId) async =>
      value?.userId == userId ? value : null;

  @override
  Future<void> write(HomeState state) async {
    value = state;
  }
}
