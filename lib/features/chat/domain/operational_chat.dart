/// Operational text only. Never a Training/export contract.
enum ChatSendStatus { pending, sent, blocked }

void validateChatUuid(String value) {
  if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
      .hasMatch(value)) {
    throw const FormatException('Invalid chat identity.');
  }
}

final class ChatOwner {
  ChatOwner({required this.projectRef, required this.userId}) {
    if (!RegExp(r'^[a-z]{20}$').hasMatch(projectRef)) {
      throw const FormatException('Invalid chat project.');
    }
    validateChatUuid(userId);
  }

  final String projectRef;
  final String userId;
  String get scope => '$projectRef:$userId';

  @override
  bool operator ==(Object other) => other is ChatOwner && other.scope == scope;
  @override
  int get hashCode => scope.hashCode;
}

final class ChatConversation {
  ChatConversation(
      {required this.id, required this.peerId, this.lastMessageAt}) {
    validateChatUuid(id);
    validateChatUuid(peerId);
  }

  final String id;
  final String peerId;
  final DateTime? lastMessageAt;
}

final class OperationalChatMessage {
  OperationalChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.rawText,
    required this.sourceLanguageCode,
    required this.clientGeneratedId,
    required this.clientCreatedAt,
    this.sentAt,
    this.sendStatus = ChatSendStatus.pending,
    this.attemptCount = 0,
    this.nextAttemptAt,
  }) {
    for (final value in [id, conversationId, senderId, clientGeneratedId]) {
      validateChatUuid(value);
    }
    if (!{'vi', 'en'}.contains(sourceLanguageCode) ||
        rawText.trim().isEmpty ||
        rawText.runes.length > 4000 ||
        attemptCount < 0 ||
        attemptCount > 10 ||
        (sendStatus == ChatSendStatus.sent && sentAt == null)) {
      throw const FormatException('Invalid operational message.');
    }
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String rawText;
  final String sourceLanguageCode;
  final String clientGeneratedId;
  final DateTime clientCreatedAt;
  final DateTime? sentAt;
  final ChatSendStatus sendStatus;
  final int attemptCount;
  final DateTime? nextAttemptAt;

  /// Only columns C2 allows clients to insert; never a timestamp/job override.
  Map<String, Object?> get insertPayload => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'raw_text': rawText,
        'source_language_code': sourceLanguageCode,
        'client_generated_id': clientGeneratedId,
        'client_created_at': clientCreatedAt.toUtc().toIso8601String(),
      };

  factory OperationalChatMessage.fromRemote(Map<String, dynamic> row) {
    String text(String key) {
      final value = row[key];
      if (value is! String) {
        throw const FormatException('Invalid chat response.');
      }
      return value;
    }

    DateTime time(String key) {
      final raw = text(key);
      final value = DateTime.tryParse(raw);
      if (value == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
        throw const FormatException('Invalid chat timestamp.');
      }
      return value.toUtc();
    }

    if (row['deleted_at'] != null || row['moderation_state'] != 'visible') {
      throw const FormatException('Hidden chat response.');
    }
    return OperationalChatMessage(
      id: text('id'),
      conversationId: text('conversation_id'),
      senderId: text('sender_id'),
      rawText: text('raw_text'),
      sourceLanguageCode: text('source_language_code'),
      clientGeneratedId: text('client_generated_id'),
      clientCreatedAt: time('client_created_at'),
      sentAt: time('sent_at'),
      sendStatus: ChatSendStatus.sent,
    );
  }

  bool hasSameRawIdentity(OperationalChatMessage other) =>
      conversationId == other.conversationId &&
      senderId == other.senderId &&
      rawText == other.rawText &&
      sourceLanguageCode == other.sourceLanguageCode &&
      clientGeneratedId == other.clientGeneratedId &&
      clientCreatedAt.isAtSameMomentAs(other.clientCreatedAt);
}

enum ChatRelayFailureKind { retryable, denied }

/// Safe categories only; never carries/logs provider response or chat content.
final class ChatRelayException implements Exception {
  const ChatRelayException(this.kind);
  final ChatRelayFailureKind kind;
}

/// Must be bound to the owner's authenticated session. C3B supplies Supabase.
abstract interface class OperationalChatTransport {
  /// On duplicate sender/client key, read and return the existing server row.
  Future<OperationalChatMessage> send(OperationalChatMessage message);
}

enum ChatRemoteSignal { connected, changed, disconnected }

/// Operational relay only; no Gemini/Training/export access.
abstract interface class OperationalChatGateway
    implements OperationalChatTransport {
  Future<ChatConversation> openDirectChat(String peerId);
  Future<List<ChatConversation>> fetchConversations();
  Future<List<OperationalChatMessage>> fetchHistory(String conversationId);
  Future<Set<String>> visibleCachedIds(String conversationId, Set<String> ids);
  Future<Set<String>> visibleConversationIds(Set<String> ids);
  Stream<ChatRemoteSignal> get signals;
  Future<void> restartRealtime();
  Future<void> dispose();
}

/// Safe cancellation: retry a fresh snapshot, do not treat it as network failure.
final class ChatRefreshSuperseded implements Exception {
  const ChatRefreshSuperseded();
}
