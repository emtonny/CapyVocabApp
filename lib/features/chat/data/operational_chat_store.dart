import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../domain/operational_chat.dart';

/// Every query is scoped to project AND authenticated owner, never a global inbox.
final class OperationalChatStore {
  OperationalChatStore({required this.database, required this.owner});
  final Database database;
  final ChatOwner owner;
  final _changes = StreamController<void>.broadcast(sync: true);
  int _revision = 0;
  int get revision => _revision;

  void _guardCurrent(bool Function()? isCurrent) {
    if (isCurrent != null && !isCurrent()) {
      throw const ChatRefreshSuperseded();
    }
  }

  void _guard(int expectedRevision, bool Function() isCurrent) {
    if (_revision != expectedRevision || !isCurrent()) {
      throw const ChatRefreshSuperseded();
    }
  }

  /// Exhausted inventory plus separate per-ID verification, never a broad sweep.
  Future<void> applyConversationRefresh({
    required List<ChatConversation> conversations,
    required Set<String> capturedIds,
    required Set<String> visibleIds,
    required int expectedRevision,
    required bool Function() isCurrent,
  }) async {
    final incomingIds = conversations.map((c) => c.id).toSet();
    if (incomingIds.length != conversations.length ||
        !capturedIds.union(incomingIds).containsAll(visibleIds)) {
      throw const FormatException('Invalid membership verification.');
    }
    for (final id in capturedIds.union(visibleIds)) {
      validateChatUuid(id);
    }
    await database.transaction((tx) async {
      _guard(expectedRevision, isCurrent);
      for (final conversation in conversations) {
        if (visibleIds.contains(conversation.id)) {
          await _conversation(tx, conversation);
        }
      }
      for (final id in capturedIds.difference(visibleIds)) {
        await tx.update('chat_conversations', {'active': 0},
            where: 'owner_scope=? AND id=?', whereArgs: [owner.scope, id]);
        await tx.update('chat_messages',
            {'send_status': 'blocked', 'next_attempt_at': null},
            where:
                "owner_scope=? AND conversation_id=? AND send_status='pending'",
            whereArgs: [owner.scope, id]);
      }
      _guard(expectedRevision, isCurrent);
    });
    _notify();
  }

  /// Merge a non-atomic pull; prune only captured SENT IDs verified absent.
  /// A local mutation or invalidation during refresh rejects the entire commit.
  Future<void> applyHistoryRefresh({
    required String conversationId,
    required List<OperationalChatMessage> messages,
    required Set<String> capturedSentIds,
    required Set<String> visibleIds,
    required int expectedRevision,
    required bool Function() isCurrent,
  }) async {
    validateChatUuid(conversationId);
    final incomingIds = messages.map((m) => m.id).toSet();
    if (incomingIds.length != messages.length ||
        !incomingIds.union(capturedSentIds).containsAll(visibleIds) ||
        messages.any((m) =>
            m.conversationId != conversationId ||
            m.sendStatus != ChatSendStatus.sent)) {
      throw const FormatException('Invalid history verification.');
    }
    for (final id in capturedSentIds.union(visibleIds)) {
      validateChatUuid(id);
    }
    await database.transaction((tx) async {
      _guard(expectedRevision, isCurrent);
      for (final message in messages) {
        if (visibleIds.contains(message.id)) await _merge(tx, message);
      }
      for (final id in capturedSentIds.difference(visibleIds)) {
        await tx.delete('chat_messages',
            where:
                "owner_scope=? AND conversation_id=? AND id=? AND send_status='sent'",
            whereArgs: [owner.scope, conversationId, id]);
      }
      _guard(expectedRevision, isCurrent);
    });
    _notify();
  }

  Future<void> cacheConversation(ChatConversation conversation) async {
    await database.transaction((tx) => _conversation(tx, conversation));
    _notify();
  }

  Future<void> _conversation(DatabaseExecutor tx, ChatConversation c) async {
    if (c.peerId == owner.userId) throw const FormatException('Invalid peer.');
    final existing = await tx.query('chat_conversations',
        where: 'owner_scope=? AND id=?', whereArgs: [owner.scope, c.id]);
    if (existing.isNotEmpty && existing.single['peer_id'] != c.peerId) {
      throw const FormatException('Conversation identity changed.');
    }
    final previousAt =
        existing.isEmpty ? null : existing.single['last_message_at'] as int?;
    final incomingAt = c.lastMessageAt?.microsecondsSinceEpoch;
    final lastAt = previousAt == null
        ? incomingAt
        : incomingAt == null || previousAt > incomingAt
            ? previousAt
            : incomingAt;
    final row = {
      'owner_scope': owner.scope,
      'id': c.id,
      'peer_id': c.peerId,
      'last_message_at': lastAt,
      'active': 1
    };
    if (existing.isEmpty) {
      await tx.insert('chat_conversations', row);
    } else {
      await tx.update('chat_conversations', row,
          where: 'owner_scope=? AND id=?', whereArgs: [owner.scope, c.id]);
    }
  }

  /// Only pass a COMPLETE authoritative membership inventory, never one page.
  Future<void> reconcileConversations(
      List<ChatConversation> conversations) async {
    if (conversations.map((c) => c.id).toSet().length != conversations.length) {
      throw const FormatException('Duplicate conversation inventory.');
    }
    await database.transaction((tx) async {
      await tx.update('chat_conversations', {'active': 0},
          where: 'owner_scope=?', whereArgs: [owner.scope]);
      for (final c in conversations) {
        await _conversation(tx, c);
      }
      await tx.rawUpdate(
          '''UPDATE chat_messages SET send_status='blocked',next_attempt_at=NULL
        WHERE owner_scope=? AND send_status='pending' AND conversation_id IN
        (SELECT id FROM chat_conversations WHERE owner_scope=? AND active=0)''',
          [owner.scope, owner.scope]);
    });
    _notify();
  }

  Future<List<ChatConversation>> conversations() async {
    final rows = await database.rawQuery('''SELECT c.*,
      (SELECT m.raw_text FROM chat_messages m
       WHERE m.owner_scope=c.owner_scope AND m.conversation_id=c.id
       ORDER BY coalesce(m.sent_at,m.client_created_at) DESC,m.id DESC LIMIT 1)
       AS last_message_text,
      (SELECT count(*) FROM chat_messages m
       WHERE m.owner_scope=c.owner_scope AND m.conversation_id=c.id
       AND m.sender_id<>? AND m.send_status='sent'
       AND (c.last_read_at IS NULL OR coalesce(m.sent_at,m.client_created_at)>c.last_read_at))
       AS unread_count
      FROM chat_conversations c
      WHERE c.owner_scope=? AND c.active=1
      ORDER BY unread_count DESC,c.last_message_at DESC,c.id''',
        [owner.userId, owner.scope]);
    return rows
        .map((row) => ChatConversation(
            id: row['id'] as String,
            peerId: row['peer_id'] as String,
            lastMessageAt: _time(row['last_message_at']),
            lastMessageText: row['last_message_text'] as String?,
            unreadCount: row['unread_count'] as int))
        .toList();
  }

  Future<void> markConversationRead(String conversationId) async {
    validateChatUuid(conversationId);
    await database.rawUpdate('''UPDATE chat_conversations SET last_read_at=(
      SELECT max(coalesce(sent_at,client_created_at)) FROM chat_messages
      WHERE owner_scope=? AND conversation_id=? AND sender_id<>?
      AND send_status='sent')
      WHERE owner_scope=? AND id=? AND active=1''', [
      owner.scope,
      conversationId,
      owner.userId,
      owner.scope,
      conversationId,
    ]);
    _notify();
  }

  Future<List<ChatPeerProfile>> profiles() async {
    final rows = await database.query('chat_peer_profiles',
        where: 'owner_scope=?', whereArgs: [owner.scope]);
    return rows
        .map((row) => ChatPeerProfile(
              id: row['peer_id'] as String,
              displayName: row['display_name'] as String,
              username: row['username'] as String,
              avatarUrl: row['avatar_url'] as String,
            ))
        .toList();
  }

  Future<void> cacheProfiles(List<ChatPeerProfile> profiles) async {
    await database.transaction((tx) async {
      final now = DateTime.now().toUtc().microsecondsSinceEpoch;
      for (final profile in profiles) {
        if (profile.id == owner.userId) continue;
        await tx.insert(
            'chat_peer_profiles',
            {
              'owner_scope': owner.scope,
              'peer_id': profile.id,
              'display_name': profile.displayName,
              'username': profile.username,
              'avatar_url': profile.avatarUrl,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    _notify();
  }

  Stream<List<ChatPeerProfile>> watchProfiles() => _watch(profiles);

  Future<void> _member(
      DatabaseExecutor tx, OperationalChatMessage message) async {
    final rows = await tx.query('chat_conversations',
        where: 'owner_scope=? AND id=? AND active=1',
        whereArgs: [owner.scope, message.conversationId]);
    if (rows.length != 1 ||
        !{owner.userId, rows.single['peer_id']}.contains(message.senderId)) {
      throw const FormatException(
          'Message is not in an active owner conversation.');
    }
  }

  Future<void> enqueue(OperationalChatMessage message,
      {bool Function()? isCurrent}) async {
    if (message.senderId != owner.userId ||
        message.sendStatus != ChatSendStatus.pending ||
        message.sentAt != null ||
        message.attemptCount != 0) {
      throw const FormatException('Invalid local outbox message.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await _member(tx, message);
      await tx.insert('chat_messages', _row(message));
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> mergeRemote(OperationalChatMessage message,
      {bool Function()? isCurrent}) async {
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await _merge(tx, message);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> _merge(
      DatabaseExecutor tx, OperationalChatMessage message) async {
    if (message.sendStatus != ChatSendStatus.sent) {
      throw const FormatException('Missing server acknowledgement.');
    }
    await _member(tx, message);
    final rows = await tx.query('chat_messages',
        where:
            'owner_scope=? AND (id=? OR (sender_id=? AND client_generated_id=?))',
        whereArgs: [
          owner.scope,
          message.id,
          message.senderId,
          message.clientGeneratedId
        ]);
    if (rows.length > 1 ||
        (rows.isNotEmpty &&
            !_decode(rows.single).hasSameRawIdentity(message))) {
      throw const FormatException(
          'Server acknowledgement conflicts with immutable raw message.');
    }
    if (rows.isNotEmpty) {
      final old = _decode(rows.single);
      if (old.sentAt != null &&
          !old.sentAt!.isAtSameMomentAs(message.sentAt!)) {
        throw const FormatException('Server message timestamp changed.');
      }
      await tx.delete('chat_messages',
          where: 'owner_scope=? AND id=?', whereArgs: [owner.scope, old.id]);
    }
    await tx.insert('chat_messages', _row(message));
    await tx.rawUpdate('''UPDATE chat_conversations SET last_message_at=
      CASE WHEN last_message_at IS NULL OR last_message_at<? THEN ? ELSE last_message_at END
      WHERE owner_scope=? AND id=?''', [
      message.sentAt!.microsecondsSinceEpoch,
      message.sentAt!.microsecondsSinceEpoch,
      owner.scope,
      message.conversationId
    ]);
  }

  /// Complete visible history only. Reconciles held/deleted server rows without
  /// deleting local pending messages; partial pages must use mergeRemote instead.
  Future<void> reconcileHistory(
      String conversationId, List<OperationalChatMessage> messages) async {
    validateChatUuid(conversationId);
    if (messages.any((m) =>
            m.conversationId != conversationId ||
            m.sendStatus != ChatSendStatus.sent) ||
        messages.map((m) => m.id).toSet().length != messages.length) {
      throw const FormatException('Invalid complete chat history.');
    }
    await database.transaction((tx) async {
      final rows = await tx.query('chat_messages',
          where: 'owner_scope=? AND conversation_id=? AND send_status=?',
          whereArgs: [owner.scope, conversationId, ChatSendStatus.sent.name]);
      // Validate/merge BEFORE removing old rows so changes cannot bypass immutability.
      for (final message in messages) {
        await _merge(tx, message);
      }
      final visibleIds = messages.map((m) => m.id).toSet();
      for (final row in rows) {
        if (!visibleIds.contains(row['id'])) {
          await tx.delete('chat_messages',
              where: 'owner_scope=? AND id=?',
              whereArgs: [owner.scope, row['id']]);
        }
      }
    });
    _notify();
  }

  Future<List<OperationalChatMessage>> messages(String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await database.rawQuery('''SELECT m.* FROM chat_messages m
      JOIN chat_conversations c ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE m.owner_scope=? AND m.conversation_id=? AND c.active=1
      ORDER BY coalesce(m.sent_at,m.client_created_at),m.id''',
        [owner.scope, conversationId]);
    return rows.map(_decode).toList();
  }

  Stream<List<OperationalChatMessage>> watchMessages(String conversationId) {
    validateChatUuid(conversationId);
    return _watch(() => messages(conversationId));
  }

  Stream<List<ChatConversation>> watchConversations() => _watch(conversations);

  Stream<T> _watch<T>(Future<T> Function() read) {
    return Stream.multi((controller) {
      var canceled = false;
      Future<void> tail = Future.value();
      void emit() {
        tail = tail.then((_) async {
          if (canceled) return;
          try {
            final result = await read();
            if (!canceled) controller.add(result);
          } catch (_) {
            if (!canceled) {
              controller.addError(StateError('Cannot read local chat.'));
            }
          }
        });
      }

      final subscription = _changes.stream.listen((_) => emit(), onDone: () {
        canceled = true;
        controller.close();
      });
      controller.onCancel = () {
        canceled = true;
        return subscription.cancel();
      };
      emit();
    });
  }

  Future<List<OperationalChatMessage>> due(DateTime now,
      {String? sourceLanguageCode}) async {
    // ponytail: one bounded 100-row drain; C3B scheduler handles further batches.
    final rows = await database.rawQuery('''SELECT m.* FROM chat_messages m
      JOIN chat_conversations c ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE m.owner_scope=? AND c.active=1 AND m.send_status='pending'
      AND (m.next_attempt_at IS NULL OR m.next_attempt_at<=?)
      ${sourceLanguageCode == null ? '' : 'AND m.source_language_code=?'}
      ORDER BY m.client_created_at,m.id LIMIT 100''', [
      owner.scope,
      now.microsecondsSinceEpoch,
      if (sourceLanguageCode != null) sourceLanguageCode
    ]);
    return rows.map(_decode).toList();
  }

  Future<DateTime?> nextPendingAt(DateTime now,
      {required String sourceLanguageCode}) async {
    final rows = await database.rawQuery(
        '''SELECT MIN(coalesce(m.next_attempt_at,?)) AS deadline
      FROM chat_messages m JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE m.owner_scope=? AND c.active=1 AND m.send_status='pending'
      AND m.source_language_code=?''',
        [now.microsecondsSinceEpoch, owner.scope, sourceLanguageCode]);
    return _time(rows.single['deadline']);
  }

  Future<void> fail(OperationalChatMessage message,
      {required bool blocked,
      required DateTime retryAt,
      bool Function()? isCurrent}) async {
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await tx.update(
          'chat_messages',
          {
            'send_status':
                (blocked ? ChatSendStatus.blocked : ChatSendStatus.pending)
                    .name,
            'attempt_count': message.attemptCount + 1,
            'next_attempt_at': blocked ? null : retryAt.microsecondsSinceEpoch,
          },
          where: 'owner_scope=? AND id=? AND send_status=?',
          whereArgs: [owner.scope, message.id, ChatSendStatus.pending.name]);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Map<String, Object?> _row(OperationalChatMessage m) => {
        'owner_scope': owner.scope,
        'id': m.id,
        'conversation_id': m.conversationId,
        'sender_id': m.senderId,
        'raw_text': m.rawText,
        'source_language_code': m.sourceLanguageCode,
        'client_generated_id': m.clientGeneratedId,
        'client_created_at': m.clientCreatedAt.microsecondsSinceEpoch,
        'sent_at': m.sentAt?.microsecondsSinceEpoch,
        'send_status': m.sendStatus.name,
        'attempt_count': m.attemptCount,
        'next_attempt_at': m.nextAttemptAt?.microsecondsSinceEpoch,
      };
  static DateTime? _time(Object? value) => value == null
      ? null
      : DateTime.fromMicrosecondsSinceEpoch(value as int, isUtc: true);
  static OperationalChatMessage _decode(Map<String, Object?> row) =>
      OperationalChatMessage(
        id: row['id'] as String,
        conversationId: row['conversation_id'] as String,
        senderId: row['sender_id'] as String,
        rawText: row['raw_text'] as String,
        sourceLanguageCode: row['source_language_code'] as String,
        clientGeneratedId: row['client_generated_id'] as String,
        clientCreatedAt: _time(row['client_created_at'])!,
        sentAt: _time(row['sent_at']),
        sendStatus: ChatSendStatus.values.byName(row['send_status'] as String),
        attemptCount: row['attempt_count'] as int,
        nextAttemptAt: _time(row['next_attempt_at']),
      );
  void _notify() {
    _revision++;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
