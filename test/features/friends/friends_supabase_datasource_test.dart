import 'dart:async';
import 'dart:convert';

import 'package:capy_vocab/features/friends/data/datasources/friends_supabase_datasource.dart';
import 'package:capy_vocab/features/friends/domain/entities/friend_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const accountA = '10000000-0000-4000-8000-000000000001';
const accountB = '10000000-0000-4000-8000-000000000002';
String peer(int value) =>
    '20000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
final instant = DateTime.utc(2026, 9, 22, 10);

String token(String user) => '${base64Url.encode(utf8.encode('{}'))}.'
    '${base64Url.encode(utf8.encode(jsonEncode({
          'sub': user,
          'exp': 4102444800
        })))}.test';

Session session(String user) => Session(
      accessToken: token(user),
      tokenType: 'bearer',
      user: User(
        id: user,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: instant.toIso8601String(),
      ),
    );

Map<String, dynamic> profileRow(int value) => {
      'id': peer(value),
      'display_name': 'Friend $value',
      'username': 'friend$value',
      'avatar_url': null,
      'study_points': value,
      'streak_days': value,
      'user_level': 1,
      'relationship_state': 'none',
    };

Map<String, dynamic> acceptedRow(int value, DateTime at) => {
      ...profileRow(value),
      'peer_id': peer(value),
      'relationship_updated_at': at.toIso8601String(),
    }
      ..remove('id')
      ..remove('relationship_state');

http.Response jsonResponse(Object? value, [int status = 200]) => http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late FriendsSupabaseDataSource gateway;
  late MockClient client;
  late bool active;
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) handler;

  setUp(() {
    active = true;
    requests = [];
    handler = (_) => jsonResponse([]);
    client = MockClient((request) async {
      requests.add(request);
      final response = await handler(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    });
    gateway = FriendsSupabaseDataSource.staging(
      owner: FriendOwner(
        projectRef: FriendsSupabaseDataSource.stagingRef,
        userId: accountA,
      ),
      session: session(accountA),
      publishableKey: 'sb_publishable_test',
      isCurrentSession: () => active,
      httpClient: client,
    );
  });

  tearDown(() async {
    await gateway.dispose();
    client.close();
  });

  test('construction binds staging owner and immutable session token', () {
    expect(requests, isEmpty);
    expect(
      () => FriendsSupabaseDataSource.staging(
        owner: FriendOwner(projectRef: 'production-ref', userId: accountA),
        session: session(accountA),
        publishableKey: 'sb_publishable_test',
        isCurrentSession: () => true,
      ),
      throwsFormatException,
    );
    expect(
      () => FriendsSupabaseDataSource.staging(
        owner: FriendOwner(
          projectRef: FriendsSupabaseDataSource.stagingRef,
          userId: accountB,
        ),
        session: session(accountA),
        publishableKey: 'sb_publishable_test',
        isCurrentSession: () => true,
      ),
      throwsFormatException,
    );
  });

  test('search RPC sends contact only as input and decodes public profile',
      () async {
    handler = (_) => jsonResponse([profileRow(1)]);

    final result = await gateway.searchFriend(
      method: FriendSearchMethod.email,
      query: ' Friend@Example.com ',
    );

    final request = requests.single;
    expect(request.url.path, '/rest/v1/rpc/search_friend');
    expect(request.headers['Authorization'], 'Bearer ${token(accountA)}');
    expect(jsonDecode(request.body), {
      'p_method': 'email',
      'p_query': 'Friend@Example.com',
    });
    expect(result!.profile.id, peer(1));
    expect(profileRow(1).keys, isNot(contains('email')));
    expect(profileRow(1).keys, isNot(contains('phone')));
  });

  test('accepted pagination sends both cursor keys and validates order',
      () async {
    final newest = instant.add(const Duration(minutes: 2));
    final older = instant.add(const Duration(minutes: 1));
    handler = (_) => jsonResponse([
          acceptedRow(2, newest),
          acceptedRow(1, older),
        ]);
    final page = await gateway.listAccepted(limit: 2);
    expect(page.items.map((item) => item.profile.id), [peer(2), peer(1)]);

    handler = (_) => jsonResponse([]);
    await gateway.listAccepted(cursor: page.nextCursor, limit: 2);
    expect(jsonDecode(requests.last.body), {
      'p_cursor_updated_at': older.toIso8601String(),
      'p_cursor_peer_id': peer(1),
      'p_limit': 2,
    });

    handler = (_) => jsonResponse([
          acceptedRow(1, older),
          acceptedRow(2, newest),
        ]);
    await expectLater(
      gateway.listAccepted(limit: 2),
      throwsA(isA<FriendDataException>()),
    );
  });

  test('discovery update sends only user-controlled settings', () async {
    handler = (_) => jsonResponse([
          {
            'discoverable_by_email': true,
            'discoverable_by_phone': false,
            'email_confirmed': true,
            'phone_verified': true,
          }
        ]);

    final settings = await gateway.updateDiscoverySettings(
      discoverableByEmail: true,
      discoverableByPhone: false,
    );

    expect(jsonDecode(requests.single.body), {
      'p_discoverable_by_email': true,
      'p_discoverable_by_phone': false,
    });
    expect(settings.emailConfirmed, isTrue);
    expect(settings.phoneVerified, isTrue);
  });

  test('RPC failures expose only safe categories and messages', () async {
    handler = (_) => jsonResponse({
          'code': 'P0001',
          'message': 'private provider detail',
          'details': null,
          'hint': null,
        }, 429);

    await expectLater(
      gateway.searchFriend(
          method: FriendSearchMethod.username, query: 'friend'),
      throwsA(
        isA<FriendException>()
            .having(
                (error) => error.kind, 'kind', FriendFailureKind.rateLimited)
            .having(
              (error) => error.message,
              'safe message',
              isNot(contains('private provider detail')),
            ),
      ),
    );
  });

  test('inactive session rejects before and after an in-flight HTTP response',
      () async {
    active = false;
    await expectLater(
      gateway.sendRequest(peer(1)),
      throwsA(isA<FriendException>()),
    );
    expect(requests, isEmpty);

    active = true;
    final barrier = Completer<http.Response>();
    handler = (_) => barrier.future;
    final pending = gateway.sendRequest(peer(1));
    await Future<void>.delayed(Duration.zero);
    active = false;
    barrier.complete(jsonResponse('outgoing_pending'));
    await expectLater(
      pending,
      throwsA(
        isA<FriendException>().having(
          (error) => error.kind,
          'kind',
          FriendFailureKind.unauthenticated,
        ),
      ),
    );
  });
}
