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
        await tx.rawUpdate('''UPDATE chat_corrections
          SET sync_status=CASE
            WHEN sync_status='proposalPending' THEN 'proposalBlocked'
            WHEN sync_status='decisionPending' THEN 'decisionBlocked'
            ELSE sync_status END,next_attempt_at=NULL
          WHERE owner_scope=? AND message_id IN
          (SELECT id FROM chat_messages WHERE owner_scope=? AND conversation_id=?)''',
            [owner.scope, owner.scope, id]);
        await tx.rawUpdate('''UPDATE chat_slang_annotations
          SET sync_status='blocked',next_attempt_at=NULL
          WHERE owner_scope=? AND sync_status='pending' AND message_id IN
          (SELECT id FROM chat_messages WHERE owner_scope=? AND conversation_id=?)''',
            [owner.scope, owner.scope, id]);
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
      await tx.rawUpdate('''UPDATE chat_corrections
        SET sync_status=CASE
          WHEN sync_status='proposalPending' THEN 'proposalBlocked'
          WHEN sync_status='decisionPending' THEN 'decisionBlocked'
          ELSE sync_status END,next_attempt_at=NULL
        WHERE owner_scope=? AND message_id IN
        (SELECT m.id FROM chat_messages m JOIN chat_conversations c
         ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
         WHERE m.owner_scope=? AND c.active=0)''', [owner.scope, owner.scope]);
      await tx.rawUpdate('''UPDATE chat_slang_annotations
        SET sync_status='blocked',next_attempt_at=NULL
        WHERE owner_scope=? AND sync_status='pending' AND message_id IN
        (SELECT m.id FROM chat_messages m JOIN chat_conversations c
         ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
         WHERE m.owner_scope=? AND c.active=0)''', [owner.scope, owner.scope]);
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

  /// Merge-only cache. C4F pulls raw history first, then translations.
  Future<void> mergeTranslations({
    required String conversationId,
    required List<OperationalChatTranslation> translations,
    bool Function()? isCurrent,
  }) async {
    validateChatUuid(conversationId);
    final keys = translations
        .map((row) =>
            '${row.messageId}:${row.targetLanguageCode}:${row.translatorVersion}')
        .toSet();
    if (keys.length != translations.length ||
        translations.any((row) => !operationalChatSupportedTranslatorVersions
            .contains(row.translatorVersion))) {
      throw const FormatException('Invalid translation refresh.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      for (final translation in translations) {
        await _mergeTranslation(tx, conversationId, translation);
      }
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> _mergeTranslation(DatabaseExecutor tx, String conversationId,
      OperationalChatTranslation translation) async {
    final messages = await tx.rawQuery('''SELECT m.source_language_code
      FROM chat_messages m JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE m.owner_scope=? AND m.id=? AND m.conversation_id=?
      AND m.send_status='sent' AND c.active=1''',
        [owner.scope, translation.messageId, conversationId]);
    if (messages.length != 1 ||
        (messages.single['source_language_code'] == 'vi'
            ? translation.targetLanguageCode != 'en'
            : translation.targetLanguageCode != 'vi')) {
      throw const FormatException(
          'Translation is not for an active cached message.');
    }

    final existing = await tx.query('chat_translations',
        where: '''owner_scope=? AND
          (id=? OR (message_id=? AND target_language_code=? AND translator_version=?))''',
        whereArgs: [
          owner.scope,
          translation.id,
          translation.messageId,
          translation.targetLanguageCode,
          translation.translatorVersion,
        ]);
    if (existing.length > 1) {
      throw const FormatException('Conflicting translation identity.');
    }
    if (existing.isEmpty) {
      await tx.insert('chat_translations', _translationRow(translation));
      return;
    }

    final old = _decodeTranslation(existing.single);
    if (old.hasSameRemoteState(translation)) return;
    if (old.id != translation.id ||
        old.messageId != translation.messageId ||
        old.targetLanguageCode != translation.targetLanguageCode ||
        old.translatorVersion != translation.translatorVersion ||
        !old.createdAt.isAtSameMomentAs(translation.createdAt)) {
      throw const FormatException('Immutable translation changed.');
    }
    if (translation.updatedAt.isBefore(old.updatedAt)) return;
    if (old.status == ChatTranslationStatus.succeeded ||
        translation.updatedAt.isAtSameMomentAs(old.updatedAt) ||
        translation.attemptCount < old.attemptCount) {
      throw const FormatException('Conflicting translation state.');
    }
    await tx.update('chat_translations', _translationRow(translation),
        where: 'owner_scope=? AND id=?',
        whereArgs: [owner.scope, translation.id]);
  }

  Future<List<OperationalChatTranslation>> translations(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await database.rawQuery('''SELECT t.*
      FROM chat_translations t JOIN chat_messages m
      ON m.owner_scope=t.owner_scope AND m.id=t.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE t.owner_scope=? AND m.conversation_id=? AND c.active=1
      AND t.translator_version IN (?,?)
      ORDER BY coalesce(m.sent_at,m.client_created_at),m.id,
        CASE t.translator_version WHEN ? THEN 0 ELSE 1 END,t.id''', [
      owner.scope,
      conversationId,
      operationalChatLegacyTranslatorVersion,
      operationalChatTranslatorVersion,
      operationalChatLegacyTranslatorVersion,
    ]);
    final preferred = <String, OperationalChatTranslation>{};
    for (final row in rows.map(_decodeTranslation)) {
      preferred['${row.messageId}:${row.targetLanguageCode}'] = row;
    }
    return preferred.values.toList();
  }

  Stream<List<OperationalChatTranslation>> watchTranslations(
          String conversationId) =>
      _watch(() => translations(conversationId));

  Future<void> enqueueCorrection(OperationalChatCorrection correction,
      {bool Function()? isCurrent}) async {
    if (correction.authorId != owner.userId ||
        correction.status != ChatCorrectionStatus.proposed ||
        correction.syncStatus != ChatCorrectionSyncStatus.proposalPending ||
        correction.attemptCount != 0) {
      throw const FormatException('Invalid local correction proposal.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await _validateCorrectionMember(tx, correction);
      await tx.insert('chat_corrections', _correctionRow(correction));
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> queueCorrectionDecision(
      String correctionId, ChatCorrectionDecision decision, DateTime now,
      {bool Function()? isCurrent}) async {
    validateChatUuid(correctionId);
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      final rows = await tx.rawQuery('''SELECT x.*,m.sender_id,c.active
        FROM chat_corrections x JOIN chat_messages m
        ON m.owner_scope=x.owner_scope AND m.id=x.message_id
        JOIN chat_conversations c
        ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
        WHERE x.owner_scope=? AND x.id=?''', [owner.scope, correctionId]);
      if (rows.length != 1 ||
          rows.single['sender_id'] != owner.userId ||
          rows.single['author_id'] == owner.userId ||
          rows.single['active'] != 1 ||
          rows.single['status'] != ChatCorrectionStatus.proposed.name ||
          rows.single['sync_status'] != ChatCorrectionSyncStatus.synced.name) {
        throw const FormatException('Correction cannot be decided locally.');
      }
      await tx.update(
          'chat_corrections',
          {
            'sync_status': ChatCorrectionSyncStatus.decisionPending.name,
            'pending_decision': decision.name,
            'attempt_count': 0,
            'next_attempt_at': now.toUtc().microsecondsSinceEpoch,
          },
          where: 'owner_scope=? AND id=?',
          whereArgs: [owner.scope, correctionId]);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> mergeCorrections({
    required String conversationId,
    required List<OperationalChatCorrection> corrections,
    bool Function()? isCurrent,
  }) async {
    validateChatUuid(conversationId);
    if (corrections.map((c) => c.id).toSet().length != corrections.length ||
        corrections
            .any((c) => c.syncStatus != ChatCorrectionSyncStatus.synced)) {
      throw const FormatException('Invalid correction refresh.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      for (final correction in corrections) {
        await _mergeCorrection(tx, conversationId, correction);
      }
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> mergeCorrectionAck(OperationalChatCorrection correction,
      {bool Function()? isCurrent}) async {
    if (correction.syncStatus != ChatCorrectionSyncStatus.synced) {
      throw const FormatException('Invalid correction acknowledgement.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      final rows = await tx.query('chat_messages',
          columns: ['conversation_id'],
          where: 'owner_scope=? AND id=?',
          whereArgs: [owner.scope, correction.messageId]);
      if (rows.length != 1) {
        throw const FormatException('Correction message is unavailable.');
      }
      await _mergeCorrection(
          tx, rows.single['conversation_id'] as String, correction);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> _validateCorrectionMember(
      DatabaseExecutor tx, OperationalChatCorrection correction,
      [String? conversationId]) async {
    final rows = await tx.rawQuery('''SELECT m.sender_id,m.source_language_code,
      m.conversation_id,c.peer_id FROM chat_messages m
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE m.owner_scope=? AND m.id=? AND m.send_status='sent' AND c.active=1
      ${conversationId == null ? '' : 'AND m.conversation_id=?'}''', [
      owner.scope,
      correction.messageId,
      if (conversationId != null) conversationId
    ]);
    if (rows.length != 1) {
      throw const FormatException('Correction message is unavailable.');
    }
    final row = rows.single;
    final sender = row['sender_id'];
    final source = row['source_language_code'];
    if (correction.authorId == sender ||
        !{owner.userId, row['peer_id']}.contains(correction.authorId) ||
        (source == 'vi'
            ? correction.targetLanguageCode != 'en'
            : correction.targetLanguageCode != 'vi')) {
      throw const FormatException('Correction is not valid for this message.');
    }
  }

  Future<void> _mergeCorrection(DatabaseExecutor tx, String conversationId,
      OperationalChatCorrection correction) async {
    await _validateCorrectionMember(tx, correction, conversationId);
    final rows = await tx.query('chat_corrections',
        where: 'owner_scope=? AND id=?',
        whereArgs: [owner.scope, correction.id]);
    if (rows.isEmpty) {
      await tx.insert('chat_corrections', _correctionRow(correction));
      return;
    }
    final old = _decodeCorrection(rows.single);
    if (!old.hasSameProposal(correction)) {
      throw const FormatException('Immutable correction changed.');
    }
    if ({
      ChatCorrectionSyncStatus.proposalPending,
      ChatCorrectionSyncStatus.proposalBlocked,
    }.contains(old.syncStatus)) {
      await tx.update('chat_corrections', _correctionRow(correction),
          where: 'owner_scope=? AND id=?',
          whereArgs: [owner.scope, correction.id]);
      return;
    }
    if (!old.createdAt.isAtSameMomentAs(correction.createdAt)) {
      throw const FormatException('Immutable correction timestamp changed.');
    }
    if (old.syncStatus == ChatCorrectionSyncStatus.decisionPending &&
        correction.status == ChatCorrectionStatus.proposed) {
      return;
    }
    if (correction.updatedAt.isBefore(old.updatedAt)) return;
    if (old.syncStatus == ChatCorrectionSyncStatus.synced &&
        old.status != ChatCorrectionStatus.proposed &&
        (old.status != correction.status ||
            !old.updatedAt.isAtSameMomentAs(correction.updatedAt))) {
      throw const FormatException('Final correction changed.');
    }
    if (correction.updatedAt.isAtSameMomentAs(old.updatedAt) &&
        (old.status != correction.status ||
            old.acceptedBy != correction.acceptedBy ||
            old.rejectedBy != correction.rejectedBy)) {
      throw const FormatException('Conflicting correction state.');
    }
    await tx.update('chat_corrections', _correctionRow(correction),
        where: 'owner_scope=? AND id=?',
        whereArgs: [owner.scope, correction.id]);
  }

  Future<List<OperationalChatCorrection>> corrections(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await database.rawQuery('''SELECT x.* FROM chat_corrections x
      JOIN chat_messages m ON m.owner_scope=x.owner_scope AND m.id=x.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE x.owner_scope=? AND m.conversation_id=? AND c.active=1
      ORDER BY coalesce(m.sent_at,m.client_created_at),m.id,x.created_at,x.id''',
        [owner.scope, conversationId]);
    return rows.map(_decodeCorrection).toList();
  }

  Stream<List<OperationalChatCorrection>> watchCorrections(
          String conversationId) =>
      _watch(() => corrections(conversationId));

  Future<List<OperationalChatCorrection>> dueCorrections(DateTime now) async {
    final rows = await database.rawQuery('''SELECT x.* FROM chat_corrections x
      JOIN chat_messages m ON m.owner_scope=x.owner_scope AND m.id=x.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE x.owner_scope=? AND c.active=1
      AND x.sync_status IN ('proposalPending','decisionPending')
      AND x.next_attempt_at<=? ORDER BY x.next_attempt_at,x.created_at,x.id LIMIT 100''',
        [owner.scope, now.toUtc().microsecondsSinceEpoch]);
    return rows.map(_decodeCorrection).toList();
  }

  Future<DateTime?> nextCorrectionPendingAt(DateTime now) async {
    final rows = await database.rawQuery(
        '''SELECT min(x.next_attempt_at) deadline
      FROM chat_corrections x JOIN chat_messages m
      ON m.owner_scope=x.owner_scope AND m.id=x.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE x.owner_scope=? AND c.active=1
      AND x.sync_status IN ('proposalPending','decisionPending')''',
        [owner.scope]);
    return _time(rows.single['deadline']);
  }

  Future<void> failCorrection(OperationalChatCorrection correction,
      {required bool blocked,
      required DateTime retryAt,
      bool Function()? isCurrent}) async {
    final expected = correction.syncStatus;
    if (!{
      ChatCorrectionSyncStatus.proposalPending,
      ChatCorrectionSyncStatus.decisionPending
    }.contains(expected)) {
      throw const FormatException('Correction is not pending.');
    }
    final nextStatus = expected == ChatCorrectionSyncStatus.proposalPending
        ? (blocked
            ? ChatCorrectionSyncStatus.proposalBlocked
            : ChatCorrectionSyncStatus.proposalPending)
        : (blocked
            ? ChatCorrectionSyncStatus.decisionBlocked
            : ChatCorrectionSyncStatus.decisionPending);
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await tx.update(
          'chat_corrections',
          {
            'sync_status': nextStatus.name,
            'attempt_count': correction.attemptCount + 1,
            'next_attempt_at':
                blocked ? null : retryAt.toUtc().microsecondsSinceEpoch,
          },
          where: 'owner_scope=? AND id=? AND sync_status=?',
          whereArgs: [owner.scope, correction.id, expected.name]);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> enqueueAnnotation(OperationalChatAnnotation annotation,
      {bool Function()? isCurrent}) async {
    if (annotation.createdBy != owner.userId ||
        annotation.syncStatus != ChatAnnotationSyncStatus.pending ||
        annotation.attemptCount != 0) {
      throw const FormatException('Invalid local chat annotation.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await _validateAnnotationMember(tx, annotation);
      await tx.insert('chat_slang_annotations', _annotationRow(annotation));
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> mergeAnnotations({
    required String conversationId,
    required List<OperationalChatAnnotation> annotations,
    bool Function()? isCurrent,
  }) async {
    validateChatUuid(conversationId);
    if (annotations.map((row) => row.id).toSet().length != annotations.length ||
        annotations
            .any((row) => row.syncStatus != ChatAnnotationSyncStatus.synced)) {
      throw const FormatException('Invalid annotation refresh.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      for (final annotation in annotations) {
        await _mergeAnnotation(tx, conversationId, annotation);
      }
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> mergeAnnotationAck(OperationalChatAnnotation annotation,
      {bool Function()? isCurrent}) async {
    if (annotation.syncStatus != ChatAnnotationSyncStatus.synced) {
      throw const FormatException('Invalid annotation acknowledgement.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      final rows = await tx.query('chat_messages',
          columns: ['conversation_id'],
          where: 'owner_scope=? AND id=?',
          whereArgs: [owner.scope, annotation.messageId]);
      if (rows.length != 1) {
        throw const FormatException('Annotation message is unavailable.');
      }
      await _mergeAnnotation(
          tx, rows.single['conversation_id'] as String, annotation);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<void> _validateAnnotationMember(
      DatabaseExecutor tx, OperationalChatAnnotation annotation,
      [String? conversationId]) async {
    final rows = await tx.rawQuery('''SELECT m.raw_text,m.sender_id,
      m.conversation_id,x.message_id correction_message,x.status correction_status,
      x.accepted_by,x.sync_status correction_sync,c.active
      FROM chat_messages m JOIN chat_corrections x
      ON x.owner_scope=m.owner_scope AND x.id=?
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE m.owner_scope=? AND m.id=? AND m.send_status='sent'
      ${conversationId == null ? '' : 'AND m.conversation_id=?'}''', [
      annotation.correctionId,
      owner.scope,
      annotation.messageId,
      if (conversationId != null) conversationId,
    ]);
    if (rows.length != 1 ||
        rows.single['active'] != 1 ||
        rows.single['sender_id'] != annotation.createdBy ||
        rows.single['correction_message'] != annotation.messageId ||
        rows.single['correction_status'] !=
            ChatCorrectionStatus.accepted.name ||
        rows.single['accepted_by'] != annotation.createdBy ||
        rows.single['correction_sync'] !=
            ChatCorrectionSyncStatus.synced.name) {
      throw const FormatException(
          'Annotation requires a synced accepted correction.');
    }
    final rawRunes = (rows.single['raw_text'] as String).runes.toList();
    if (annotation.spanEnd > rawRunes.length ||
        String.fromCharCodes(
                rawRunes.sublist(annotation.spanStart, annotation.spanEnd)) !=
            annotation.spanText) {
      throw const FormatException('Annotation Unicode span is invalid.');
    }
  }

  Future<void> _mergeAnnotation(DatabaseExecutor tx, String conversationId,
      OperationalChatAnnotation annotation) async {
    await _validateAnnotationMember(tx, annotation, conversationId);
    final rows = await tx.query('chat_slang_annotations',
        where: 'owner_scope=? AND id=?',
        whereArgs: [owner.scope, annotation.id]);
    if (rows.isEmpty) {
      await tx.insert('chat_slang_annotations', _annotationRow(annotation));
      return;
    }
    final old = _decodeAnnotation(rows.single);
    if (!old.hasSameTag(annotation)) {
      throw const FormatException('Immutable annotation changed.');
    }
    if (old.syncStatus != ChatAnnotationSyncStatus.synced) {
      await tx.update('chat_slang_annotations', _annotationRow(annotation),
          where: 'owner_scope=? AND id=?',
          whereArgs: [owner.scope, annotation.id]);
      return;
    }
    if (!old.createdAt.isAtSameMomentAs(annotation.createdAt)) {
      throw const FormatException('Immutable annotation timestamp changed.');
    }
  }

  Future<List<OperationalChatAnnotation>> annotations(
      String conversationId) async {
    validateChatUuid(conversationId);
    final rows = await database.rawQuery('''SELECT a.*
      FROM chat_slang_annotations a JOIN chat_messages m
      ON m.owner_scope=a.owner_scope AND m.id=a.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE a.owner_scope=? AND m.conversation_id=? AND c.active=1
      ORDER BY coalesce(m.sent_at,m.client_created_at),m.id,a.created_at,a.id''',
        [owner.scope, conversationId]);
    return rows.map(_decodeAnnotation).toList();
  }

  Stream<List<OperationalChatAnnotation>> watchAnnotations(
          String conversationId) =>
      _watch(() => annotations(conversationId));

  Future<List<OperationalChatAnnotation>> dueAnnotations(DateTime now) async {
    final rows = await database.rawQuery('''SELECT a.*
      FROM chat_slang_annotations a JOIN chat_messages m
      ON m.owner_scope=a.owner_scope AND m.id=a.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE a.owner_scope=? AND c.active=1 AND a.sync_status='pending'
      AND a.next_attempt_at<=?
      ORDER BY a.next_attempt_at,a.created_at,a.id LIMIT 100''',
        [owner.scope, now.toUtc().microsecondsSinceEpoch]);
    return rows.map(_decodeAnnotation).toList();
  }

  Future<DateTime?> nextAnnotationPendingAt(DateTime now) async {
    final rows = await database.rawQuery(
        '''SELECT min(a.next_attempt_at) deadline
      FROM chat_slang_annotations a JOIN chat_messages m
      ON m.owner_scope=a.owner_scope AND m.id=a.message_id
      JOIN chat_conversations c
      ON c.owner_scope=m.owner_scope AND c.id=m.conversation_id
      WHERE a.owner_scope=? AND c.active=1 AND a.sync_status='pending' ''',
        [owner.scope]);
    return _time(rows.single['deadline']);
  }

  Future<void> failAnnotation(OperationalChatAnnotation annotation,
      {required bool blocked,
      required DateTime retryAt,
      bool Function()? isCurrent}) async {
    if (annotation.syncStatus != ChatAnnotationSyncStatus.pending) {
      throw const FormatException('Annotation is not pending.');
    }
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      await tx.update(
          'chat_slang_annotations',
          {
            'sync_status': (blocked
                    ? ChatAnnotationSyncStatus.blocked
                    : ChatAnnotationSyncStatus.pending)
                .name,
            'attempt_count': annotation.attemptCount + 1,
            'next_attempt_at':
                blocked ? null : retryAt.toUtc().microsecondsSinceEpoch,
          },
          where: 'owner_scope=? AND id=? AND sync_status=?',
          whereArgs: [owner.scope, annotation.id, annotation.syncStatus.name]);
      _guardCurrent(isCurrent);
    });
    _notify();
  }

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
  Map<String, Object?> _translationRow(OperationalChatTranslation t) => {
        'owner_scope': owner.scope,
        'id': t.id,
        'message_id': t.messageId,
        'target_language_code': t.targetLanguageCode,
        'translated_text': t.translatedText,
        'provider': t.provider,
        'model': t.model,
        'prompt_version': t.promptVersion,
        'translator_version': t.translatorVersion,
        'status': t.status.name,
        'attempt_count': t.attemptCount,
        'next_attempt_at': t.nextAttemptAt?.microsecondsSinceEpoch,
        'error_code': t.errorCode,
        'created_at': t.createdAt.microsecondsSinceEpoch,
        'completed_at': t.completedAt?.microsecondsSinceEpoch,
        'updated_at': t.updatedAt.microsecondsSinceEpoch,
      };
  Map<String, Object?> _correctionRow(OperationalChatCorrection c) => {
        'owner_scope': owner.scope,
        'id': c.id,
        'message_id': c.messageId,
        'author_id': c.authorId,
        'target_language_code': c.targetLanguageCode,
        'proposed_text': c.proposedText,
        'status': c.status.name,
        'accepted_by': c.acceptedBy,
        'accepted_at': c.acceptedAt?.microsecondsSinceEpoch,
        'rejected_by': c.rejectedBy,
        'rejected_at': c.rejectedAt?.microsecondsSinceEpoch,
        'created_at': c.createdAt.microsecondsSinceEpoch,
        'updated_at': c.updatedAt.microsecondsSinceEpoch,
        'sync_status': c.syncStatus.name,
        'pending_decision': c.pendingDecision?.name,
        'attempt_count': c.attemptCount,
        'next_attempt_at': c.nextAttemptAt?.microsecondsSinceEpoch,
      };
  Map<String, Object?> _annotationRow(OperationalChatAnnotation a) => {
        'owner_scope': owner.scope,
        'id': a.id,
        'message_id': a.messageId,
        'correction_id': a.correctionId,
        'created_by': a.createdBy,
        'span_text': a.spanText,
        'span_start': a.spanStart,
        'span_end': a.spanEnd,
        'tag_type': a.tagType.wireValue,
        'normalized_source': a.normalizedSource,
        'annotator_role': 'source_speaker',
        'status': 'active',
        'created_at': a.createdAt.microsecondsSinceEpoch,
        'sync_status': a.syncStatus.name,
        'attempt_count': a.attemptCount,
        'next_attempt_at': a.nextAttemptAt?.microsecondsSinceEpoch,
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
  static OperationalChatTranslation _decodeTranslation(
          Map<String, Object?> row) =>
      OperationalChatTranslation(
        id: row['id'] as String,
        messageId: row['message_id'] as String,
        targetLanguageCode: row['target_language_code'] as String,
        translatedText: row['translated_text'] as String?,
        provider: row['provider'] as String,
        model: row['model'] as String,
        promptVersion: row['prompt_version'] as String,
        translatorVersion: row['translator_version'] as String,
        status: ChatTranslationStatus.values.byName(row['status'] as String),
        attemptCount: row['attempt_count'] as int,
        nextAttemptAt: _time(row['next_attempt_at']),
        errorCode: row['error_code'] as String?,
        createdAt: _time(row['created_at'])!,
        completedAt: _time(row['completed_at']),
        updatedAt: _time(row['updated_at'])!,
      );
  static OperationalChatCorrection _decodeCorrection(
          Map<String, Object?> row) =>
      OperationalChatCorrection(
        id: row['id'] as String,
        messageId: row['message_id'] as String,
        authorId: row['author_id'] as String,
        targetLanguageCode: row['target_language_code'] as String,
        proposedText: row['proposed_text'] as String,
        status: ChatCorrectionStatus.values.byName(row['status'] as String),
        acceptedBy: row['accepted_by'] as String?,
        acceptedAt: _time(row['accepted_at']),
        rejectedBy: row['rejected_by'] as String?,
        rejectedAt: _time(row['rejected_at']),
        createdAt: _time(row['created_at'])!,
        updatedAt: _time(row['updated_at'])!,
        syncStatus: ChatCorrectionSyncStatus.values
            .byName(row['sync_status'] as String),
        pendingDecision: row['pending_decision'] == null
            ? null
            : ChatCorrectionDecision.values
                .byName(row['pending_decision'] as String),
        attemptCount: row['attempt_count'] as int,
        nextAttemptAt: _time(row['next_attempt_at']),
      );
  static OperationalChatAnnotation _decodeAnnotation(
          Map<String, Object?> row) =>
      OperationalChatAnnotation(
        id: row['id'] as String,
        messageId: row['message_id'] as String,
        correctionId: row['correction_id'] as String,
        createdBy: row['created_by'] as String,
        spanText: row['span_text'] as String,
        spanStart: row['span_start'] as int,
        spanEnd: row['span_end'] as int,
        tagType: ChatAnnotationType.fromWire(row['tag_type'] as String),
        normalizedSource: row['normalized_source'] as String,
        createdAt: _time(row['created_at'])!,
        syncStatus: ChatAnnotationSyncStatus.values
            .byName(row['sync_status'] as String),
        attemptCount: row['attempt_count'] as int,
        nextAttemptAt: _time(row['next_attempt_at']),
      );
  void _notify() {
    _revision++;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
