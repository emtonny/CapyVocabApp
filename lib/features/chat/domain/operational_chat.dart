/// Operational text only. Never a Training/export contract.
enum ChatSendStatus { pending, sent, blocked }

const operationalChatTranslatorVersion = 'chat-translate-v2';
const operationalChatPromptVersion = 'chat-translate-p2';
const operationalChatTranslationModel = 'gemini-3.8-flash';
const operationalChatTranslationProvider = 'vilao';
const operationalChatLegacyTranslatorVersion = 'chat-translate-v1';
const operationalChatLegacyPromptVersion = 'chat-translate-p1';
const operationalChatLegacyTranslationModel = 'gemini-3.5-flash-lite';
const operationalChatSupportedTranslatorVersions = <String>[
  operationalChatLegacyTranslatorVersion,
  operationalChatTranslatorVersion,
];

bool isSupportedOperationalChatTranslation({
  required String provider,
  required String model,
  required String promptVersion,
  required String translatorVersion,
}) =>
    (provider == operationalChatTranslationProvider &&
        model == operationalChatTranslationModel &&
        promptVersion == operationalChatPromptVersion &&
        translatorVersion == operationalChatTranslatorVersion) ||
    (provider == 'gemini' &&
        model == operationalChatLegacyTranslationModel &&
        promptVersion == operationalChatLegacyPromptVersion &&
        translatorVersion == operationalChatLegacyTranslatorVersion);

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
      {required this.id,
      required this.peerId,
      this.lastMessageAt,
      this.lastMessageText,
      this.unreadCount = 0}) {
    validateChatUuid(id);
    validateChatUuid(peerId);
    if (unreadCount < 0) {
      throw const FormatException('Invalid unread count.');
    }
  }

  final String id;
  final String peerId;
  final DateTime? lastMessageAt;
  final String? lastMessageText;
  final int unreadCount;
}

final class ChatPeerProfile {
  ChatPeerProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
  }) {
    validateChatUuid(id);
  }

  final String id;
  final String displayName;
  final String username;
  final String avatarUrl;

  String get label {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    final handle = username.trim();
    if (handle.isNotEmpty) return handle;
    return 'Bạn · ${id.substring(id.length - 8)}';
  }

  factory ChatPeerProfile.fromRemote(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String) {
      throw const FormatException('Invalid public chat profile.');
    }
    String field(String key) => row[key] is String ? row[key] as String : '';
    return ChatPeerProfile(
      id: id,
      displayName: field('display_name'),
      username: field('username'),
      avatarUrl: field('avatar_url'),
    );
  }
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

enum ChatTranslationStatus { queued, processing, succeeded, failed }

enum ChatCorrectionStatus { proposed, accepted, rejected }

enum ChatCorrectionSyncStatus {
  synced,
  proposalPending,
  proposalBlocked,
  decisionPending,
  decisionBlocked,
}

enum ChatCorrectionDecision { accepted, rejected }

enum ChatAnnotationType {
  slang('slang'),
  abbreviation('abbreviation'),
  informalAddress('informal_address'),
  idiom('idiom'),
  typoOrPhoneticSpelling('typo_or_phonetic_spelling'),
  other('other');

  const ChatAnnotationType(this.wireValue);
  final String wireValue;

  static ChatAnnotationType fromWire(String value) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    throw const FormatException('Invalid chat annotation type.');
  }
}

enum ChatAnnotationSyncStatus { synced, pending, blocked }

/// A peer-authored correction kept separate from the immutable raw message.
/// It is operational chat data only and is never a Training/export contract.
final class OperationalChatCorrection {
  OperationalChatCorrection({
    required this.id,
    required this.messageId,
    required this.authorId,
    required this.targetLanguageCode,
    required this.proposedText,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedBy,
    this.acceptedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.syncStatus = ChatCorrectionSyncStatus.synced,
    this.pendingDecision,
    this.attemptCount = 0,
    this.nextAttemptAt,
  }) {
    for (final value in [id, messageId, authorId]) {
      validateChatUuid(value);
    }
    if (!{'vi', 'en'}.contains(targetLanguageCode) ||
        proposedText.trim().isEmpty ||
        proposedText.runes.length > 4000 ||
        updatedAt.isBefore(createdAt) ||
        attemptCount < 0 ||
        attemptCount > 4 ||
        !_validDecisionState ||
        !_validSyncState) {
      throw const FormatException('Invalid operational correction.');
    }
  }

  final String id;
  final String messageId;
  final String authorId;
  final String targetLanguageCode;
  final String proposedText;
  final ChatCorrectionStatus status;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ChatCorrectionSyncStatus syncStatus;
  final ChatCorrectionDecision? pendingDecision;
  final int attemptCount;
  final DateTime? nextAttemptAt;

  bool get _validDecisionState {
    if (acceptedBy != null) validateChatUuid(acceptedBy!);
    if (rejectedBy != null) validateChatUuid(rejectedBy!);
    return switch (status) {
      ChatCorrectionStatus.proposed => acceptedBy == null &&
          acceptedAt == null &&
          rejectedBy == null &&
          rejectedAt == null,
      ChatCorrectionStatus.accepted => acceptedBy != null &&
          acceptedAt != null &&
          rejectedBy == null &&
          rejectedAt == null &&
          !acceptedAt!.isBefore(createdAt),
      ChatCorrectionStatus.rejected => rejectedBy != null &&
          rejectedAt != null &&
          acceptedBy == null &&
          acceptedAt == null &&
          !rejectedAt!.isBefore(createdAt),
    };
  }

  bool get _validSyncState {
    final proposal = {
      ChatCorrectionSyncStatus.proposalPending,
      ChatCorrectionSyncStatus.proposalBlocked,
    }.contains(syncStatus);
    final decision = {
      ChatCorrectionSyncStatus.decisionPending,
      ChatCorrectionSyncStatus.decisionBlocked,
    }.contains(syncStatus);
    if (syncStatus == ChatCorrectionSyncStatus.synced) {
      return pendingDecision == null &&
          attemptCount == 0 &&
          nextAttemptAt == null;
    }
    if (proposal) {
      return status == ChatCorrectionStatus.proposed &&
          pendingDecision == null &&
          (nextAttemptAt == null) ==
              (syncStatus == ChatCorrectionSyncStatus.proposalBlocked);
    }
    if (decision) {
      return status == ChatCorrectionStatus.proposed &&
          pendingDecision != null &&
          (nextAttemptAt == null) ==
              (syncStatus == ChatCorrectionSyncStatus.decisionBlocked);
    }
    return false;
  }

  Map<String, Object?> get insertPayload {
    if (syncStatus != ChatCorrectionSyncStatus.proposalPending) {
      throw StateError('Correction is not a pending proposal.');
    }
    return {
      'id': id,
      'message_id': messageId,
      'author_id': authorId,
      'target_language_code': targetLanguageCode,
      'proposed_text': proposedText,
    };
  }

  factory OperationalChatCorrection.fromRemote(Map<String, dynamic> row) {
    String text(String key) {
      final value = row[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid chat correction response.');
      }
      return value;
    }

    String? optionalText(String key) {
      final value = row[key];
      if (value != null && value is! String) {
        throw const FormatException('Invalid chat correction response.');
      }
      return value as String?;
    }

    DateTime time(String key) {
      final raw = text(key);
      final value = DateTime.tryParse(raw);
      if (value == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
        throw const FormatException('Invalid chat correction timestamp.');
      }
      return value.toUtc();
    }

    DateTime? optionalTime(String key) => row[key] == null ? null : time(key);
    ChatCorrectionStatus status;
    try {
      status = ChatCorrectionStatus.values.byName(text('status'));
    } on ArgumentError {
      throw const FormatException('Invalid chat correction status.');
    }
    return OperationalChatCorrection(
      id: text('id'),
      messageId: text('message_id'),
      authorId: text('author_id'),
      targetLanguageCode: text('target_language_code'),
      proposedText: text('proposed_text'),
      status: status,
      acceptedBy: optionalText('accepted_by'),
      acceptedAt: optionalTime('accepted_at'),
      rejectedBy: optionalText('rejected_by'),
      rejectedAt: optionalTime('rejected_at'),
      createdAt: time('created_at'),
      updatedAt: time('updated_at'),
    );
  }

  bool hasSameProposal(OperationalChatCorrection other) =>
      id == other.id &&
      messageId == other.messageId &&
      authorId == other.authorId &&
      targetLanguageCode == other.targetLanguageCode &&
      proposedText == other.proposedText;
}

/// A source-speaker tag over the immutable raw message. Offsets are zero-based,
/// half-open Unicode code-point indexes, matching Dart runes and PostgreSQL.
/// Operational only: this is not a Training/export contract.
final class OperationalChatAnnotation {
  OperationalChatAnnotation({
    required this.id,
    required this.messageId,
    required this.correctionId,
    required this.createdBy,
    required this.spanText,
    required this.spanStart,
    required this.spanEnd,
    required this.tagType,
    required this.normalizedSource,
    required this.createdAt,
    this.syncStatus = ChatAnnotationSyncStatus.synced,
    this.attemptCount = 0,
    this.nextAttemptAt,
  }) {
    for (final value in [id, messageId, correctionId, createdBy]) {
      validateChatUuid(value);
    }
    if (spanText.trim().isEmpty ||
        spanText.runes.length > 4000 ||
        spanStart < 0 ||
        spanEnd <= spanStart ||
        spanText.runes.length != spanEnd - spanStart ||
        normalizedSource.trim().isEmpty ||
        normalizedSource.runes.length > 4000 ||
        attemptCount < 0 ||
        attemptCount > 4 ||
        !_validSyncState) {
      throw const FormatException('Invalid operational chat annotation.');
    }
  }

  final String id;
  final String messageId;
  final String correctionId;
  final String createdBy;
  final String spanText;
  final int spanStart;
  final int spanEnd;
  final ChatAnnotationType tagType;
  final String normalizedSource;
  final DateTime createdAt;
  final ChatAnnotationSyncStatus syncStatus;
  final int attemptCount;
  final DateTime? nextAttemptAt;

  bool get _validSyncState => switch (syncStatus) {
        ChatAnnotationSyncStatus.synced =>
          attemptCount == 0 && nextAttemptAt == null,
        ChatAnnotationSyncStatus.pending => nextAttemptAt != null,
        ChatAnnotationSyncStatus.blocked => nextAttemptAt == null,
      };

  Map<String, Object?> get insertPayload {
    if (syncStatus != ChatAnnotationSyncStatus.pending) {
      throw StateError('Annotation is not pending.');
    }
    return {
      'id': id,
      'message_id': messageId,
      'correction_id': correctionId,
      'created_by': createdBy,
      'span_text': spanText,
      'span_start': spanStart,
      'span_end': spanEnd,
      'tag_type': tagType.wireValue,
      'normalized_source': normalizedSource,
    };
  }

  factory OperationalChatAnnotation.fromRemote(Map<String, dynamic> row) {
    String text(String key) {
      final value = row[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid chat annotation response.');
      }
      return value;
    }

    int integer(String key) {
      final value = row[key];
      if (value is! int) {
        throw const FormatException('Invalid chat annotation response.');
      }
      return value;
    }

    final rawTime = text('created_at');
    final createdAt = DateTime.tryParse(rawTime);
    if (createdAt == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(rawTime)) {
      throw const FormatException('Invalid chat annotation timestamp.');
    }
    if (row['annotator_role'] != 'source_speaker' ||
        row['status'] != 'active') {
      throw const FormatException('Invalid chat annotation state.');
    }
    return OperationalChatAnnotation(
      id: text('id'),
      messageId: text('message_id'),
      correctionId: text('correction_id'),
      createdBy: text('created_by'),
      spanText: text('span_text'),
      spanStart: integer('span_start'),
      spanEnd: integer('span_end'),
      tagType: ChatAnnotationType.fromWire(text('tag_type')),
      normalizedSource: text('normalized_source'),
      createdAt: createdAt.toUtc(),
    );
  }

  bool hasSameTag(OperationalChatAnnotation other) =>
      id == other.id &&
      messageId == other.messageId &&
      correctionId == other.correctionId &&
      createdBy == other.createdBy &&
      spanText == other.spanText &&
      spanStart == other.spanStart &&
      spanEnd == other.spanEnd &&
      tagType == other.tagType &&
      normalizedSource == other.normalizedSource;
}

/// Operational display cache only. Never a Training/export contract.
final class OperationalChatTranslation {
  OperationalChatTranslation({
    required this.id,
    required this.messageId,
    required this.targetLanguageCode,
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.translatorVersion,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.translatedText,
    this.nextAttemptAt,
    this.errorCode,
    this.completedAt,
  }) {
    validateChatUuid(id);
    validateChatUuid(messageId);
    final validSuccess = status == ChatTranslationStatus.succeeded &&
        translatedText != null &&
        translatedText!.trim().isNotEmpty &&
        translatedText!.runes.length <= 16000 &&
        completedAt != null &&
        errorCode == null &&
        nextAttemptAt == null;
    final validPendingState = status != ChatTranslationStatus.succeeded &&
        translatedText == null &&
        completedAt == null &&
        (status == ChatTranslationStatus.failed) == (errorCode != null);
    if (!{'vi', 'en'}.contains(targetLanguageCode) ||
        !isSupportedOperationalChatTranslation(
          provider: provider,
          model: model,
          promptVersion: promptVersion,
          translatorVersion: translatorVersion,
        ) ||
        attemptCount < 0 ||
        attemptCount > 4 ||
        (status == ChatTranslationStatus.queued && attemptCount != 0) ||
        ({ChatTranslationStatus.processing, ChatTranslationStatus.succeeded}
                .contains(status) &&
            attemptCount == 0) ||
        (status != ChatTranslationStatus.failed && nextAttemptAt != null) ||
        updatedAt.isBefore(createdAt) ||
        (completedAt != null && completedAt!.isBefore(createdAt)) ||
        (errorCode != null &&
            !RegExp(r'^[A-Z0-9_]{1,64}$').hasMatch(errorCode!)) ||
        (!validSuccess && !validPendingState)) {
      throw const FormatException('Invalid operational translation.');
    }
  }

  final String id;
  final String messageId;
  final String targetLanguageCode;
  final String? translatedText;
  final String provider;
  final String model;
  final String promptVersion;
  final String translatorVersion;
  final ChatTranslationStatus status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  factory OperationalChatTranslation.fromRemote(Map<String, dynamic> row) {
    String text(String key) {
      final value = row[key];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Invalid chat translation response.');
      }
      return value;
    }

    String? optionalText(String key) {
      final value = row[key];
      if (value != null && value is! String) {
        throw const FormatException('Invalid chat translation response.');
      }
      return value as String?;
    }

    DateTime time(String key) {
      final raw = text(key);
      final value = DateTime.tryParse(raw);
      if (value == null || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
        throw const FormatException('Invalid chat translation timestamp.');
      }
      return value.toUtc();
    }

    DateTime? optionalTime(String key) => row[key] == null ? null : time(key);

    final rawStatus = text('status');
    final ChatTranslationStatus status;
    try {
      status = ChatTranslationStatus.values.byName(rawStatus);
    } on ArgumentError {
      throw const FormatException('Invalid chat translation status.');
    }
    final attemptCount = row['attempt_count'];
    if (attemptCount is! int) {
      throw const FormatException('Invalid chat translation attempt.');
    }
    return OperationalChatTranslation(
      id: text('id'),
      messageId: text('message_id'),
      targetLanguageCode: text('target_language_code'),
      translatedText: optionalText('translated_text'),
      provider: text('provider'),
      model: text('model'),
      promptVersion: text('prompt_version'),
      translatorVersion: text('translator_version'),
      status: status,
      attemptCount: attemptCount,
      nextAttemptAt: optionalTime('next_attempt_at'),
      errorCode: optionalText('error_code'),
      createdAt: time('created_at'),
      completedAt: optionalTime('completed_at'),
      updatedAt: time('updated_at'),
    );
  }

  bool hasSameRemoteState(OperationalChatTranslation other) =>
      id == other.id &&
      messageId == other.messageId &&
      targetLanguageCode == other.targetLanguageCode &&
      translatedText == other.translatedText &&
      provider == other.provider &&
      model == other.model &&
      promptVersion == other.promptVersion &&
      translatorVersion == other.translatorVersion &&
      status == other.status &&
      attemptCount == other.attemptCount &&
      _sameTime(nextAttemptAt, other.nextAttemptAt) &&
      errorCode == other.errorCode &&
      createdAt.isAtSameMomentAs(other.createdAt) &&
      _sameTime(completedAt, other.completedAt) &&
      updatedAt.isAtSameMomentAs(other.updatedAt);

  static bool _sameTime(DateTime? left, DateTime? right) => left == null
      ? right == null
      : right != null && left.isAtSameMomentAs(right);
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
  Future<List<OperationalChatTranslation>> fetchTranslations(
      String conversationId);
  Future<OperationalChatCorrection> proposeCorrection(
      OperationalChatCorrection correction);
  Future<OperationalChatCorrection> resolveCorrection(
      String correctionId, ChatCorrectionDecision decision);
  Future<List<OperationalChatCorrection>> fetchCorrections(
      String conversationId);
  Future<OperationalChatAnnotation> proposeAnnotation(
      OperationalChatAnnotation annotation);
  Future<List<OperationalChatAnnotation>> fetchAnnotations(
      String conversationId);
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
