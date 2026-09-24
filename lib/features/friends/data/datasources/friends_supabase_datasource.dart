import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/friend_entity.dart';
import '../../domain/repositories/friends_repository.dart';

/// Uses a private Supabase client whose access token cannot change while a
/// request is in flight. Recreate this gateway after token or account changes.
final class FriendsSupabaseDataSource implements FriendsRemoteGateway {
  static const stagingRef = 'nxteaznowkfennxpqjmt';

  factory FriendsSupabaseDataSource.staging({
    required FriendOwner owner,
    required Session session,
    required String publishableKey,
    required bool Function() isCurrentSession,
    Duration requestTimeout = const Duration(seconds: 12),
    http.Client? httpClient,
    RealtimeClientOptions realtimeOptions = const RealtimeClientOptions(),
  }) {
    if (owner.projectRef != stagingRef ||
        session.user.id != owner.userId ||
        session.accessToken.isEmpty ||
        publishableKey.trim().isEmpty ||
        requestTimeout <= Duration.zero) {
      throw const FormatException('Invalid Staging friends session.');
    }
    final token = session.accessToken;
    final client = SupabaseClient(
      'https://$stagingRef.supabase.co',
      publishableKey,
      accessToken: () async => token,
      headers: {'Authorization': 'Bearer $token'},
      httpClient: httpClient,
      realtimeClientOptions: realtimeOptions,
    );
    client.realtime.customAccessToken = null;
    return FriendsSupabaseDataSource._(
      owner,
      client,
      isCurrentSession,
      requestTimeout,
    );
  }

  FriendsSupabaseDataSource._(
    this.owner,
    this._client,
    this._isCurrentSession,
    this._timeout,
  );

  final FriendOwner owner;
  final SupabaseClient _client;
  final bool Function() _isCurrentSession;
  final Duration _timeout;
  bool _closed = false;
  StreamController<FriendRemoteSignal>? _signals;
  RealtimeChannel? _channel;
  Future<void> _channelTail = Future.value();
  Future<void>? _disposal;
  int _channelGeneration = 0;

  void _checkSession() {
    if (_closed || !_isCurrentSession()) {
      throw const FriendException(
        FriendFailureKind.unauthenticated,
        'The active session changed. Please try again.',
      );
    }
  }

  Future<T> _request<T>(Future<T> Function() action) async {
    _checkSession();
    try {
      final result = await action().timeout(_timeout);
      _checkSession();
      return result;
    } on PostgrestException catch (error) {
      final kind = _failureKind(error.code, error.message);
      throw FriendException(kind, _safeMessage(kind));
    } on FriendException {
      rethrow;
    } on ArgumentError {
      throw const FriendDataException(
        'The friends service returned an invalid response.',
      );
    } on FormatException {
      throw const FriendDataException(
        'The friends service returned an invalid response.',
      );
    } catch (_) {
      throw const FriendException(
        FriendFailureKind.unavailable,
        'The friends service is temporarily unavailable.',
      );
    }
  }

  @override
  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || normalizedQuery.length > 320) {
      throw const FriendException(
        FriendFailureKind.invalidInput,
        'Enter a valid search value.',
      );
    }
    return _request(() async {
      final rows = _rows(await _client.rpc('search_friend', params: {
        'p_method': method.wireValue,
        'p_query': normalizedQuery,
      }));
      if (rows.length > 1) {
        throw const FriendDataException(
          'The friends service returned more than one search result.',
        );
      }
      return rows.isEmpty
          ? null
          : FriendConnection.fromSearchRemote(rows.single);
    });
  }

  @override
  Future<FriendDiscoverySettings> getDiscoverySettings() {
    return _request(() async {
      final row = _singleRow(
        await _client.rpc('get_my_friend_discovery_settings'),
      );
      return FriendDiscoverySettings.fromRemote(row);
    });
  }

  @override
  Future<FriendDiscoverySettings> updateDiscoverySettings({
    required bool discoverableByEmail,
    required bool discoverableByPhone,
  }) {
    return _request(() async {
      final row = _singleRow(
        await _client.rpc('update_my_friend_discovery_settings', params: {
          'p_discoverable_by_email': discoverableByEmail,
          'p_discoverable_by_phone': discoverableByPhone,
        }),
      );
      return FriendDiscoverySettings.fromRemote(row);
    });
  }

  @override
  Future<void> syncVerifiedPhone() {
    return _request(() async {
      final result = await _client.rpc('sync_my_verified_friend_phone');
      if (result != true) {
        throw const FriendDataException(
          'The friends service did not confirm phone verification.',
        );
      }
    });
  }

  @override
  Future<FriendMutationResult> sendRequest(String targetUserId) {
    final target = validateFriendUuid(targetUserId, field: 'targetUserId');
    if (target == owner.userId) {
      throw const FriendException(
        FriendFailureKind.invalidInput,
        'You cannot send a friend request to yourself.',
      );
    }
    return _request(() async {
      final result = await _client.rpc(
        'send_friend_request',
        params: {'p_target_user_id': target},
      );
      return FriendMutationResult.fromWire(result);
    });
  }

  @override
  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  }) {
    final requester = validateFriendUuid(requesterId, field: 'requesterId');
    if (requester == owner.userId) {
      throw const FriendException(
        FriendFailureKind.invalidInput,
        'You cannot respond to your own friend request.',
      );
    }
    return _request(() async {
      final result = await _client.rpc('respond_friend_request', params: {
        'p_requester_id': requester,
        'p_decision': decision.wireValue,
      });
      return FriendMutationResult.fromWire(result);
    });
  }

  @override
  Future<FriendPage> listRequests({
    required FriendRequestDirection direction,
    FriendCursor? cursor,
    int limit = 100,
  }) {
    _validateLimit(limit);
    return _request(() async {
      final rows = _rows(await _client.rpc('list_friend_requests', params: {
        'p_direction': direction.wireValue,
        'p_cursor_updated_at': cursor?.updatedAt.toIso8601String(),
        'p_cursor_peer_id': cursor?.peerId,
        'p_limit': limit,
      }));
      final items = rows
          .map(
            (row) => FriendConnection.fromRequestRemote(
              row,
              expectedDirection: direction,
            ),
          )
          .toList();
      _validatePage(items, cursor);
      return FriendPage(items: items);
    });
  }

  @override
  Future<FriendPage> listAccepted({
    FriendCursor? cursor,
    int limit = 100,
  }) {
    _validateLimit(limit);
    return _request(() async {
      final rows = _rows(await _client.rpc('list_accepted_friends', params: {
        'p_cursor_updated_at': cursor?.updatedAt.toIso8601String(),
        'p_cursor_peer_id': cursor?.peerId,
        'p_limit': limit,
      }));
      final items = rows.map(FriendConnection.fromAcceptedRemote).toList();
      _validatePage(items, cursor);
      return FriendPage(items: items);
    });
  }

  @override
  Stream<FriendRemoteSignal> get signals {
    _checkSession();
    return (_signals ??= StreamController<FriendRemoteSignal>.broadcast(
      onListen: () => _queueChannel(true),
      onCancel: () => _queueChannel(false),
    ))
        .stream;
  }

  void _queueChannel(bool attach) {
    final generation = ++_channelGeneration;
    _channelTail = _channelTail.then((_) async {
      final previous = _channel;
      _channel = null;
      if (previous != null) await _client.removeChannel(previous);
      if (!attach ||
          _closed ||
          !_isCurrentSession() ||
          generation != _channelGeneration ||
          !_signals!.hasListener) {
        return;
      }
      final channel = _client.channel('friends:${owner.userId}');
      _channel = channel;
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friends',
        callback: (_) => _emit(FriendRemoteSignal.changed, generation),
      );
      channel.subscribe((status, _) {
        _emit(
          status == RealtimeSubscribeStatus.subscribed
              ? FriendRemoteSignal.connected
              : FriendRemoteSignal.disconnected,
          generation,
        );
      });
    }).catchError((Object _) {
      _emit(FriendRemoteSignal.disconnected, generation);
    });
  }

  void _emit(FriendRemoteSignal signal, int generation) {
    if (!_closed &&
        _isCurrentSession() &&
        generation == _channelGeneration &&
        _signals != null &&
        !_signals!.isClosed &&
        _signals!.hasListener) {
      _signals!.add(signal);
    }
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    _channelGeneration++;
    await _channelTail;
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    await _client.dispose();
    await _signals?.close();
  }
}

List<Map<String, dynamic>> _rows(Object? raw) {
  if (raw is! List) {
    throw const FriendDataException(
      'The friends service returned an invalid row set.',
    );
  }
  return raw.map((item) {
    if (item is! Map) {
      throw const FriendDataException(
        'The friends service returned an invalid row.',
      );
    }
    return Map<String, dynamic>.from(item);
  }).toList();
}

Map<String, dynamic> _singleRow(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  final rows = _rows(raw);
  if (rows.length != 1) {
    throw const FriendDataException(
      'The friends service returned an invalid settings result.',
    );
  }
  return rows.single;
}

void _validateLimit(int limit) {
  if (limit < 1 || limit > 100) {
    throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
  }
}

void _validatePage(List<FriendConnection> items, FriendCursor? cursor) {
  var previousAt = cursor?.updatedAt;
  var previousPeer = cursor?.peerId;
  final peers = <String>{};
  for (final item in items) {
    final at = item.updatedAt;
    if (at == null || !peers.add(item.profile.id)) {
      throw const FriendDataException(
        'The friends service returned a duplicate or incomplete page.',
      );
    }
    if (previousAt != null) {
      final advances = at.isBefore(previousAt) ||
          (at.isAtSameMomentAs(previousAt) &&
              item.profile.id.compareTo(previousPeer!) < 0);
      if (!advances) {
        throw const FriendDataException(
          'The friends service returned a non-advancing page.',
        );
      }
    }
    previousAt = at;
    previousPeer = item.profile.id;
  }
}

FriendFailureKind _failureKind(String? code, String message) {
  final knownMessage = switch (message) {
    'invalid_username' => FriendFailureKind.invalidUsername,
    'invalid_email' => FriendFailureKind.invalidEmail,
    'invalid_phone' => FriendFailureKind.invalidPhone,
    'contact_not_verified' => FriendFailureKind.contactNotVerified,
    'user_not_found' || 'profile_not_found' => FriendFailureKind.userNotFound,
    'self_request' => FriendFailureKind.selfRequest,
    'already_accepted' ||
    'request_already_resolved' =>
      FriendFailureKind.alreadyAccepted,
    'incoming_pending' => FriendFailureKind.incomingPending,
    'stale_request' => FriendFailureKind.staleRequest,
    _ => null,
  };
  if (knownMessage != null) return knownMessage;
  return switch (code) {
    '22023' => FriendFailureKind.invalidInput,
    '42501' => FriendFailureKind.denied,
    'P0001' => FriendFailureKind.rateLimited,
    'P0002' => FriendFailureKind.notFound,
    '55000' => FriendFailureKind.conflict,
    _ => FriendFailureKind.unavailable,
  };
}

String _safeMessage(FriendFailureKind kind) {
  return switch (kind) {
    FriendFailureKind.invalidUsername => 'Username chưa đúng định dạng.',
    FriendFailureKind.invalidEmail => 'Email chưa đúng định dạng.',
    FriendFailureKind.invalidPhone => 'Số điện thoại chưa đúng định dạng.',
    FriendFailureKind.contactNotVerified =>
      'Thông tin liên hệ này chưa được xác minh.',
    FriendFailureKind.userNotFound => 'Không tìm thấy người dùng.',
    FriendFailureKind.selfRequest => 'Bạn không thể tự kết bạn với mình.',
    FriendFailureKind.alreadyAccepted => 'Hai bạn đã là bạn bè.',
    FriendFailureKind.incomingPending => 'Người này đã gửi lời mời cho bạn.',
    FriendFailureKind.staleRequest => 'Lời mời không còn hiệu lực.',
    FriendFailureKind.offline =>
      'Bạn đang offline. Hãy kết nối mạng và thử lại.',
    FriendFailureKind.invalidInput => 'The request is invalid.',
    FriendFailureKind.denied => 'You are not allowed to perform this action.',
    FriendFailureKind.rateLimited =>
      'Too many friend searches. Please wait and try again.',
    FriendFailureKind.notFound => 'The friend request was not found.',
    FriendFailureKind.conflict =>
      'The friend relationship changed. Refresh it.',
    _ => 'The friends service is temporarily unavailable.',
  };
}
