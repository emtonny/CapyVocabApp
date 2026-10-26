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
      'id,kind,participant_low,participant_high,learning_group_id,'
      'last_message_at';
  static const _socialKind = 'social';
  static const _translationColumns =
      'id,message_id,target_language_code,translated_text,provider,model,'
      'prompt_version,translator_version,status,attempt_count,next_attempt_at,'
      'error_code,created_at,completed_at,updated_at,'
      'chat_operational_messages!inner(conversation_id)';
  static const _correctionColumns =
      'id,message_id,author_id,target_language_code,proposed_text,status,'
      'accepted_by,accepted_at,rejected_by,rejected_at,created_at,updated_at,'
      'chat_operational_messages!inner(conversation_id)';
  static const _annotationColumns =
      'id,message_id,correction_id,created_by,span_text,span_start,span_end,'
      'tag_type,normalized_source,annotator_role,status,created_at,'
      'chat_operational_messages!inner(conversation_id)';

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

  DateTime? _conversationTime(Object? rawAt) {
    if (rawAt == null) return null;
    DateTime? at;
    if (rawAt is! String ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(rawAt) ||
        (at = DateTime.tryParse(rawAt)) == null) {
      throw const FormatException('Invalid conversation timestamp.');
    }
    return at!.toUtc();
  }

  ChatConversation _conversation(
    Map<String, dynamic> row, [
    Map<String, dynamic>? group,
    Map<String, dynamic>? socialGroup,
  ]) {
    final id = row['id'];
    final kind = row['kind'];
    final low = row['participant_low'];
    final high = row['participant_high'];
    if (id is! String) {
      throw const FormatException('Invalid owner conversation.');
    }
    final at = _conversationTime(row['last_message_at']);
    if (kind == ChatConversationKind.group.name) {
      final groupId = row['learning_group_id'];
      if (groupId is! String ||
          low != null ||
          high != null ||
          group == null ||
          group['group_id'] != groupId ||
          group['membership_status'] != 'active' ||
          group['title'] is! String ||
          group['is_muted'] is! bool ||
          group['active_student_count'] is! int ||
          !{'active', 'archived'}.contains(group['group_status'])) {
        throw const FormatException('Invalid group conversation.');
      }
      return ChatConversation.group(
        id: id,
        groupId: groupId,
        title: group['title'] as String,
        memberCount: (group['active_student_count'] as int) + 1,
        groupMuted: group['is_muted'] as bool,
        groupArchived: group['group_status'] == 'archived',
        lastMessageAt: at,
      );
    }
    if (kind == _socialKind) {
      final title = socialGroup?['title'];
      final socialOwnerId = socialGroup?['owner_user_id'];
      final memberCount = socialGroup?['member_count'];
      final status = socialGroup?['status'];
      if (row['learning_group_id'] != null ||
          low != null ||
          high != null ||
          socialGroup == null ||
          socialGroup['conversation_id'] != id ||
          title is! String ||
          title != title.trim() ||
          title.runes.isEmpty ||
          title.runes.length > 80 ||
          socialOwnerId is! String ||
          !{'active', 'closed'}.contains(status) ||
          memberCount is! int ||
          memberCount < 2 ||
          memberCount > 20) {
        throw const FormatException('Invalid social group conversation.');
      }
      validateChatUuid(socialOwnerId);
      return ChatConversation.group(
        id: id,
        groupId: id,
        title: title,
        socialOwnerId: socialOwnerId,
        memberCount: memberCount,
        groupArchived: status == 'closed',
        lastMessageAt: at,
      );
    }
    if (kind != ChatConversationKind.direct.name ||
        low is! String ||
        high is! String ||
        row['learning_group_id'] != null ||
        low.compareTo(high) >= 0 ||
        !{low, high}.contains(owner.userId)) {
      throw const FormatException('Invalid owner conversation.');
    }
    validateChatUuid(low);
    validateChatUuid(high);
    return ChatConversation(
        id: id, peerId: low == owner.userId ? high : low, lastMessageAt: at);
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

  @override
  Future<ChatConversation> createSocialChatGroup({
    required String title,
    required List<String> memberIds,
    required String requestId,
  }) {
    final normalizedTitle = title.trim();
    validateChatUuid(requestId);
    for (final id in memberIds) {
      validateChatUuid(id);
    }
    if (normalizedTitle.isEmpty ||
        normalizedTitle.runes.length > 80 ||
        memberIds.isEmpty ||
        memberIds.length > 19 ||
        memberIds.toSet().length != memberIds.length ||
        memberIds.contains(owner.userId)) {
      throw const FormatException('Invalid social group request.');
    }
    return _request(() async {
      final id = await _client.rpc('create_social_chat_group', params: {
        'p_title': normalizedTitle,
        'p_member_ids': memberIds,
        'p_request_id': requestId,
      });
      if (id is! String) {
        throw const FormatException('Invalid social group RPC result.');
      }
      validateChatUuid(id);
      final metadata = await _socialGroups({id});
      final result = _conversation(
        await _client
            .from('chat_conversations')
            .select(_conversationColumns)
            .eq('id', id)
            .single(),
        null,
        metadata[id],
      );
      if (result.id != id || result.title != normalizedTitle) {
        throw const FormatException('Conflicting social group result.');
      }
      return result;
    });
  }

  Future<ChatConversation> _socialConversation(String conversationId) async {
    validateChatUuid(conversationId);
    final metadata = await _socialGroups({conversationId});
    return _conversation(
      await _request(() => _client
          .from('chat_conversations')
          .select(_conversationColumns)
          .eq('id', conversationId)
          .single()),
      null,
      metadata[conversationId],
    );
  }

  @override
  Future<ChatConversation> renameSocialChatGroup(
      String conversationId, String title) async {
    validateChatUuid(conversationId);
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty || normalizedTitle.runes.length > 80) {
      throw const FormatException('Invalid social group title.');
    }
    final result = await _request(() => _client.rpc(
          'rename_social_chat_group',
          params: {
            'p_conversation_id': conversationId,
            'p_title': normalizedTitle,
          },
        ));
    if (result != conversationId) {
      throw const FormatException('Invalid social group mutation result.');
    }
    return _socialConversation(conversationId);
  }

  @override
  Future<ChatConversation> closeSocialChatGroup(String conversationId) async {
    validateChatUuid(conversationId);
    final result = await _request(() => _client.rpc(
          'close_social_chat_group',
          params: {'p_conversation_id': conversationId},
        ));
    if (result != conversationId) {
      throw const FormatException('Invalid social group mutation result.');
    }
    return _socialConversation(conversationId);
  }

  @override
  Future<void> leaveSocialChatGroup(String conversationId) async {
    validateChatUuid(conversationId);
    final result = await _request(() => _client.rpc(
          'leave_social_chat_group',
          params: {'p_conversation_id': conversationId},
        ));
    if (result != conversationId) {
      throw const FormatException('Invalid social group mutation result.');
    }
  }

  @override
  Future<List<SocialChatMember>> fetchSocialChatGroupMembers(
      Set<String> conversationIds) async {
    if (conversationIds.isEmpty || conversationIds.length > 50) {
      throw const FormatException('Invalid social group member request.');
    }
    for (final id in conversationIds) {
      validateChatUuid(id);
    }
    final response = await _request(() => _client.rpc(
          'list_social_chat_group_members',
          params: {'p_conversation_ids': conversationIds.toList()..sort()},
        ));
    if (response is! List) {
      throw const FormatException('Invalid social group members.');
    }
    final members = <SocialChatMember>[];
    final identities = <String>{};
    for (final value in response) {
      if (value is! Map) {
        throw const FormatException('Invalid social group member.');
      }
      final member =
          SocialChatMember.fromRemote(Map<String, dynamic>.from(value));
      if (!conversationIds.contains(member.conversationId) ||
          !identities.add('${member.conversationId}:${member.profile.id}')) {
        throw const FormatException('Invalid social group member identity.');
      }
      members.add(member);
    }
    return members;
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
    final groupIds = rows
        .where((row) => row['kind'] == ChatConversationKind.group.name)
        .map((row) => row['learning_group_id'])
        .whereType<String>()
        .toSet();
    final groups = <String, Map<String, dynamic>>{};
    if (groupIds.isNotEmpty) {
      final response =
          await _request(() => _client.rpc('list_my_learning_groups'));
      if (response is! List) {
        throw const FormatException('Invalid learning group inventory.');
      }
      for (final value in response) {
        if (value is! Map) {
          throw const FormatException('Invalid learning group metadata.');
        }
        final row = Map<String, dynamic>.from(value);
        final id = row['group_id'];
        if (id is String && groupIds.contains(id)) groups[id] = row;
      }
      if (!groups.keys.toSet().containsAll(groupIds)) {
        throw const FormatException('Missing learning group metadata.');
      }
    }
    final socialIds = rows
        .where((row) => row['kind'] == _socialKind)
        .map((row) => row['id'])
        .whereType<String>()
        .toSet();
    final socialGroups = await _socialGroups(socialIds);
    return rows.map((row) {
      final groupId = row['learning_group_id'];
      final id = row['id'];
      return _conversation(
        row,
        groupId is String ? groups[groupId] : null,
        id is String ? socialGroups[id] : null,
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _socialGroups(
      Set<String> conversationIds) async {
    if (conversationIds.isEmpty) return const {};
    final response =
        await _request(() => _client.rpc('list_my_social_chat_groups'));
    if (response is! List) {
      throw const FormatException('Invalid social group inventory.');
    }
    final groups = <String, Map<String, dynamic>>{};
    for (final value in response) {
      if (value is! Map) {
        throw const FormatException('Invalid social group metadata.');
      }
      final row = Map<String, dynamic>.from(value);
      final id = row['conversation_id'];
      if (id is String && conversationIds.contains(id)) groups[id] = row;
    }
    if (!groups.keys.toSet().containsAll(conversationIds)) {
      throw const FormatException('Missing social group metadata.');
    }
    return groups;
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

  /// Merge-only paged pull. C4F must apply raw history before these rows.
  @override
  Future<List<OperationalChatTranslation>> fetchTranslations(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await _pages((cursor) {
      var query = _client
          .from('chat_translations')
          .select(_translationColumns)
          .inFilter(
              'translator_version', operationalChatSupportedTranslatorVersions)
          .eq('chat_operational_messages.conversation_id', conversationId);
      if (cursor != null) query = query.gt('id', cursor);
      return query.order('id', ascending: true).limit(100);
    });
    return rows.map((row) {
      final message = row['chat_operational_messages'];
      if (message is! Map || message['conversation_id'] != conversationId) {
        throw const FormatException('Translation outside requested chat.');
      }
      return OperationalChatTranslation.fromRemote(row);
    }).toList();
  }

  @override
  Future<OperationalChatCorrection> proposeCorrection(
      OperationalChatCorrection correction) {
    if (correction.authorId != owner.userId ||
        correction.syncStatus != ChatCorrectionSyncStatus.proposalPending) {
      throw const FormatException('Invalid owner correction proposal.');
    }
    return _request(() async {
      Map<String, dynamic>? row;
      try {
        row = await _client
            .from('chat_corrections')
            .insert(correction.insertPayload)
            .select(_correctionColumns)
            .single();
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        _checkSession();
        row = await _client
            .from('chat_corrections')
            .select(_correctionColumns)
            .eq('id', correction.id)
            .maybeSingle();
      }
      if (row == null) {
        throw const ChatRelayException(ChatRelayFailureKind.denied);
      }
      final ack = OperationalChatCorrection.fromRemote(row);
      if (!ack.hasSameProposal(correction)) {
        throw const FormatException('Conflicting correction acknowledgement.');
      }
      return ack;
    });
  }

  @override
  Future<OperationalChatCorrection> resolveCorrection(
      String correctionId, ChatCorrectionDecision decision) {
    validateChatUuid(correctionId);
    return _request(() async {
      final raw = await _client.rpc('resolve_chat_correction', params: {
        'p_correction_id': correctionId,
        'p_decision': decision.name,
      });
      final Map<String, dynamic> row;
      if (raw is Map<String, dynamic>) {
        row = raw;
      } else if (raw is List &&
          raw.length == 1 &&
          raw.single is Map<String, dynamic>) {
        row = raw.single as Map<String, dynamic>;
      } else {
        throw const FormatException('Invalid correction RPC result.');
      }
      final result = OperationalChatCorrection.fromRemote(row);
      if (result.id != correctionId || result.status.name != decision.name) {
        throw const FormatException('Conflicting correction decision.');
      }
      return result;
    });
  }

  @override
  Future<List<OperationalChatCorrection>> fetchCorrections(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await _pages((cursor) {
      var query = _client
          .from('chat_corrections')
          .select(_correctionColumns)
          .eq('chat_operational_messages.conversation_id', conversationId);
      if (cursor != null) query = query.gt('id', cursor);
      return query.order('id', ascending: true).limit(100);
    });
    return rows.map((row) {
      final message = row['chat_operational_messages'];
      if (message is! Map || message['conversation_id'] != conversationId) {
        throw const FormatException('Correction outside requested chat.');
      }
      return OperationalChatCorrection.fromRemote(row);
    }).toList();
  }

  @override
  Future<OperationalChatAnnotation> proposeAnnotation(
      OperationalChatAnnotation annotation) {
    if (annotation.createdBy != owner.userId ||
        annotation.syncStatus != ChatAnnotationSyncStatus.pending) {
      throw const FormatException('Invalid owner annotation proposal.');
    }
    return _request(() async {
      Map<String, dynamic>? row;
      try {
        row = await _client
            .from('chat_slang_annotations')
            .insert(annotation.insertPayload)
            .select(_annotationColumns)
            .single();
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        _checkSession();
        row = await _client
            .from('chat_slang_annotations')
            .select(_annotationColumns)
            .eq('id', annotation.id)
            .maybeSingle();
      }
      if (row == null) {
        throw const ChatRelayException(ChatRelayFailureKind.denied);
      }
      final ack = OperationalChatAnnotation.fromRemote(row);
      if (!ack.hasSameTag(annotation)) {
        throw const FormatException('Conflicting annotation acknowledgement.');
      }
      return ack;
    });
  }

  @override
  Future<List<OperationalChatAnnotation>> fetchAnnotations(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await _pages((cursor) {
      var query = _client
          .from('chat_slang_annotations')
          .select(_annotationColumns)
          .eq('chat_operational_messages.conversation_id', conversationId);
      if (cursor != null) query = query.gt('id', cursor);
      return query.order('id', ascending: true).limit(100);
    });
    return rows.map((row) {
      final message = row['chat_operational_messages'];
      if (message is! Map || message['conversation_id'] != conversationId) {
        throw const FormatException('Annotation outside requested chat.');
      }
      return OperationalChatAnnotation.fromRemote(row);
    }).toList();
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
        'chat_operational_messages',
        'chat_translations',
        'chat_corrections',
        'chat_slang_annotations',
        'learning_groups',
        'learning_group_members'
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
