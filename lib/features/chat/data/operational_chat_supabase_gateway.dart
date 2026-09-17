import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/operational_chat.dart';

export '../domain/operational_chat.dart' show ChatRemoteSignal;

/// A private SDK client with an immutable token. Never borrow the global
/// client's mutable auth headers: an in-flight A request must not become B's.
/// Runtime must dispose/recreate this gateway on token refresh/account change.
final class OperationalChatSupabaseGateway implements OperationalChatGateway {
  static const stagingRef = 'nxteaznowkfennxpqjmt';
  static const _messageColumns =
      'id,conversation_id,sender_id,raw_text,source_language_code,'
      'client_generated_id,client_created_at,sent_at,deleted_at,moderation_state';
  static const _conversationColumns =
      'id,kind,participant_low,participant_high,last_message_at';

  factory OperationalChatSupabaseGateway.staging({
    required ChatOwner owner,
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
        publishableKey.isEmpty ||
        requestTimeout <= Duration.zero) {
      throw const FormatException('Invalid Staging chat session.');
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
    // realtime_client 2.13.0 resolves custom tokens by force-rejoining an
    // already timed joining Push, producing an empty ref in the first join.
    // This private client's token is already fixed in its headers: no resolver
    // is necessary. Token refresh always recreates the gateway/channel.
    client.realtime.customAccessToken = null;
    return OperationalChatSupabaseGateway._(
      owner,
      client,
      isCurrentSession,
      requestTimeout,
    );
  }

  OperationalChatSupabaseGateway._(
      this.owner, this._client, this._isCurrentSession, this._timeout);
  final ChatOwner owner;
  final SupabaseClient _client;
  final bool Function() _isCurrentSession;
  final Duration _timeout;
  bool _closed = false;
  StreamController<ChatRemoteSignal>? _signals;
  RealtimeChannel? _channel;
  Future<void> _channelTail = Future.value();
  Future<void>? _disposal;
  int _channelGeneration = 0;

  void _checkSession() {
    if (_closed || !_isCurrentSession()) {
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
  }

  Future<T> _request<T>(Future<T> Function() action) async {
    _checkSession();
    try {
      final result = await action().timeout(_timeout);
      _checkSession();
      return result;
    } on PostgrestException catch (error) {
      // Expired JWT/401/5xx are retryable; never discard unsent text on refresh.
      final denied = {'42501', '22023', '23503', '23514'}.contains(error.code);
      throw ChatRelayException(denied
          ? ChatRelayFailureKind.denied
          : ChatRelayFailureKind.retryable);
    } on FormatException {
      rethrow;
    } on ChatRelayException {
      rethrow;
    } catch (_) {
      // No provider payload, token or raw text in exceptions/logs.
      throw const ChatRelayException(ChatRelayFailureKind.retryable);
    }
  }

  @override
  Future<OperationalChatMessage> send(OperationalChatMessage message) {
    if (message.senderId != owner.userId ||
        message.sendStatus != ChatSendStatus.pending) {
      throw const FormatException('Invalid owner outbox message.');
    }
    return _request(() async {
      Map<String, dynamic>? row;
      try {
        row = await _client
            .from('chat_operational_messages')
            .insert(message.insertPayload)
            .select(_messageColumns)
            .single();
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        _checkSession();
        // Read canonical row after lost ACK; never UPSERT immutable raw text.
        row = await _client
            .from('chat_operational_messages')
            .select(_messageColumns)
            .eq('sender_id', owner.userId)
            .eq('client_generated_id', message.clientGeneratedId)
            .maybeSingle();
      }
      if (row == null) {
        throw const ChatRelayException(ChatRelayFailureKind.denied);
      }
      final ack = OperationalChatMessage.fromRemote(row);
      if (!ack.hasSameRawIdentity(message)) {
        throw const FormatException('Conflicting chat acknowledgement.');
      }
      return ack;
    });
  }

  ChatConversation _conversation(Map<String, dynamic> row) {
    final id = row['id'];
    final low = row['participant_low'];
    final high = row['participant_high'];
    final rawAt = row['last_message_at'];
    if (id is! String ||
        low is! String ||
        high is! String ||
        row['kind'] != 'direct' ||
        low.compareTo(high) >= 0 ||
        !{low, high}.contains(owner.userId)) {
      throw const FormatException('Invalid owner conversation.');
    }
    validateChatUuid(low);
    validateChatUuid(high);
    DateTime? at;
    if (rawAt != null) {
      if (rawAt is! String ||
          !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(rawAt) ||
          (at = DateTime.tryParse(rawAt)) == null) {
        throw const FormatException('Invalid conversation timestamp.');
      }
    }
    return ChatConversation(
        id: id,
        peerId: low == owner.userId ? high : low,
        lastMessageAt: at?.toUtc());
  }

  @override
  Future<ChatConversation> openDirectChat(String peerId) {
    validateChatUuid(peerId);
    if (peerId == owner.userId) {
      throw const FormatException('Invalid chat peer.');
    }
    return _request(() async {
      final id =
          await _client.rpc('open_direct_chat', params: {'p_peer_id': peerId});
      if (id is! String) {
        throw const FormatException('Invalid chat RPC result.');
      }
      validateChatUuid(id);
      final result = _conversation(await _client
          .from('chat_conversations')
          .select(_conversationColumns)
          .eq('id', id)
          .single());
      if (result.peerId != peerId) {
        throw const FormatException('Conflicting chat peer.');
      }
      return result;
    });
  }

  /// Complete paged RLS inventory, but NOT a transaction snapshot. Runtime
  /// must fence concurrent membership/open-chat changes before deactivating cache.
  @override
  Future<List<ChatConversation>> fetchConversations() async {
    final rows = await _pages((cursor) {
      var query =
          _client.from('chat_conversations').select(_conversationColumns);
      if (cursor != null) query = query.gt('id', cursor);
      return query.order('id', ascending: true).limit(100);
    });
    return rows.map(_conversation).toList();
  }

  /// Merge-only paged pull. NEVER pass this list to reconcileHistory: concurrent
  /// inserts mean even exhausted pages aren't an atomic complete snapshot.
  @override
  Future<List<OperationalChatMessage>> fetchHistory(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await _pages((cursor) {
      var query = _client
          .from('chat_operational_messages')
          .select(_messageColumns)
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .eq('moderation_state', 'visible');
      if (cursor != null) query = query.gt('id', cursor);
      return query.order('id', ascending: true).limit(100);
    });
    final result = rows.map(OperationalChatMessage.fromRemote).toList();
    if (result.any((m) => m.conversationId != conversationId)) {
      throw const FormatException('Message outside requested chat.');
    }
    return result;
  }

  /// Verify ONLY the cached sent IDs captured before a refresh. The runtime may
  /// prune captured IDs absent here after every chunk succeeds, never newer ACKs.
  @override
  Future<Set<String>> visibleCachedIds(
      String conversationId, Set<String> cachedSentIds) async {
    _checkSession();
    validateChatUuid(conversationId);
    for (final id in cachedSentIds) {
      validateChatUuid(id);
    }
    final ids = cachedSentIds.toList()..sort();
    final visible = <String>{};
    for (var start = 0; start < ids.length; start += 50) {
      final chunk = ids.skip(start).take(50).toList();
      final rows = await _pages((cursor) {
        var query = _client
            .from('chat_operational_messages')
            .select('id')
            .eq('conversation_id', conversationId)
            .inFilter('id', chunk)
            .isFilter('deleted_at', null)
            .eq('moderation_state', 'visible');
        if (cursor != null) query = query.gt('id', cursor);
        return query.order('id', ascending: true).limit(50);
      });
      for (final row in rows) {
        final id = row['id'] as String;
        if (!chunk.contains(id)) {
          throw const FormatException('Unexpected visibility identity.');
        }
        visible.add(id);
      }
    }
    _checkSession();
    return visible;
  }

  @override
  Future<Set<String>> visibleConversationIds(Set<String> ids) async {
    _checkSession();
    for (final id in ids) {
      validateChatUuid(id);
    }
    final sorted = ids.toList()..sort();
    final visible = <String>{};
    for (var start = 0; start < sorted.length; start += 50) {
      final chunk = sorted.skip(start).take(50).toList();
      final rows = await _pages((cursor) {
        var query = _client
            .from('chat_conversations')
            .select('id')
            .inFilter('id', chunk);
        if (cursor != null) query = query.gt('id', cursor);
        return query.order('id', ascending: true).limit(50);
      });
      for (final row in rows) {
        final id = row['id'] as String;
        if (!chunk.contains(id)) {
          throw const FormatException('Unexpected membership identity.');
        }
        visible.add(id);
      }
    }
    _checkSession();
    return visible;
  }

  @override
  Future<void> restartRealtime() {
    _checkSession();
    if (_signals?.hasListener ?? false) _queueChannel(true, restart: true);
    return _channelTail;
  }

  Future<List<Map<String, dynamic>>> _pages(
      Future<List<Map<String, dynamic>>> Function(String?) page) async {
    final rows = <Map<String, dynamic>>[];
    String? cursor;
    // Bounded fail-closed guard; never return a partial list as complete.
    for (var count = 0; count < 1000; count++) {
      final batch = await _request(() => page(cursor));
      if (batch.isEmpty) return rows;
      for (final row in batch) {
        final id = row['id'];
        if (id is! String) {
          throw const FormatException('Invalid page identity.');
        }
        validateChatUuid(id);
        if (cursor != null && id.compareTo(cursor) <= 0) {
          throw const FormatException('Non-advancing chat page.');
        }
        rows.add(row);
        cursor = id;
      }
      // Continue until EMPTY, not length<limit: PostgREST may cap page size.
    }
    throw const ChatRelayException(ChatRelayFailureKind.retryable);
  }

  /// One broadcast channel per gateway. Events are invalidations ONLY, not a
  /// trusted cache snapshot. Connected/reconnected must trigger a guarded pull.
  @override
  Stream<ChatRemoteSignal> get signals {
    _checkSession();
    return (_signals ??= StreamController<ChatRemoteSignal>.broadcast(
      onListen: () => _queueChannel(true),
      onCancel: () => _queueChannel(false),
    ))
        .stream;
  }

  void _queueChannel(bool attach, {bool restart = false}) {
    final generation = ++_channelGeneration;
    _channelTail = _channelTail.then((_) async {
      final previous = _channel;
      _channel = null;
      if (previous != null) await _client.removeChannel(previous);
      if (restart && !_closed) await _client.realtime.disconnect();
      if (!attach ||
          _closed ||
          !_isCurrentSession() ||
          generation != _channelGeneration ||
          !_signals!.hasListener) {
        return;
      }
      final channel = _client.channel('operational-chat:${owner.userId}');
      _channel = channel;
      for (final table in [
        'chat_conversations',
        'chat_members',
        'chat_operational_messages'
      ]) {
        channel.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => _emit(ChatRemoteSignal.changed, generation));
      }
      channel.subscribe((status, _) => _emit(
          status == RealtimeSubscribeStatus.subscribed
              ? ChatRemoteSignal.connected
              : ChatRemoteSignal.disconnected,
          generation));
    }).catchError((Object _) {
      _emit(ChatRemoteSignal.disconnected, generation);
    });
  }

  void _emit(ChatRemoteSignal signal, int generation) {
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
