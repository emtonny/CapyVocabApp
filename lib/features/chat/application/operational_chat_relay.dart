import '../../../core/utils/random_uuid.dart';
import '../data/operational_chat_store.dart';
import '../domain/operational_chat.dart';

final class ChatRelayResult {
  const ChatRelayResult(
      {this.sent = 0, this.retryScheduled = 0, this.blocked = 0});
  final int sent;
  final int retryScheduled;
  final int blocked;
}

/// No network awaits in enqueue/read. Lifecycle/reconnect calls synchronize in
/// background. C3B will bind the predicates and transport to the auth runtime.
final class OperationalChatRelay {
  OperationalChatRelay(
      {required this.store,
      required this.transport,
      required this.isCurrentOwner,
      required this.canReachNetwork,
      this.cachedSourceLanguageCode,
      DateTime Function()? clock,
      String Function()? idGenerator})
      : _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? createRandomUuidV4;
  final OperationalChatStore store;
  final OperationalChatTransport transport;
  final bool Function() isCurrentOwner;
  final bool Function() canReachNetwork;
  final String? Function()? cachedSourceLanguageCode;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  Future<ChatRelayResult>? _flight;
  bool _closed = false;
  bool get _active => !_closed && isCurrentOwner();

  Future<OperationalChatMessage> enqueue(
      {required String conversationId,
      required String rawText,
      required String sourceLanguageCode}) async {
    if (!_active) throw StateError('No active chat owner.');
    final message = OperationalChatMessage(
        id: _idGenerator(),
        conversationId: conversationId,
        senderId: store.owner.userId,
        rawText: rawText,
        sourceLanguageCode: sourceLanguageCode,
        clientGeneratedId: _idGenerator(),
        clientCreatedAt: _clock().toUtc());
    await store.enqueue(message, isCurrent: () => _active);
    return message;
  }

  Future<ChatRelayResult> synchronize() {
    if (!_active || !canReachNetwork()) {
      return Future.value(const ChatRelayResult());
    }
    return _flight ??= _drain().whenComplete(() => _flight = null);
  }

  Future<ChatRelayResult> _drain() async {
    var sent = 0;
    var retries = 0;
    var blocked = 0;
    final code = cachedSourceLanguageCode?.call();
    if (cachedSourceLanguageCode != null && code == null) {
      return const ChatRelayResult();
    }
    final pending = await store.due(_clock().toUtc(), sourceLanguageCode: code);
    for (final message in pending) {
      if (!_active || !canReachNetwork()) break;
      if (cachedSourceLanguageCode != null &&
          cachedSourceLanguageCode!() != message.sourceLanguageCode) {
        continue;
      }
      try {
        final ack = await transport.send(message);
        if (!_active) break; // A's late response cannot mutate B's UI/store.
        if (!ack.hasSameRawIdentity(message) ||
            ack.sendStatus != ChatSendStatus.sent) {
          throw const FormatException('Invalid chat acknowledgement.');
        }
        await store.mergeRemote(ack, isCurrent: () => _active);
        sent++;
      } catch (error) {
        if (!_active) break;
        final permanent = error is FormatException ||
            (error is ChatRelayException &&
                error.kind == ChatRelayFailureKind.denied) ||
            message.attemptCount >= 7;
        final seconds = (2 << message.attemptCount).clamp(2, 300);
        await store.fail(message,
            isCurrent: () => _active,
            blocked: permanent,
            retryAt: _clock().toUtc().add(Duration(seconds: seconds)));
        if (permanent) {
          blocked++;
        } else {
          retries++;
        }
      }
    }
    return ChatRelayResult(
        sent: sent, retryScheduled: retries, blocked: blocked);
  }

  void dispose() {
    _closed = true;
  }
}
