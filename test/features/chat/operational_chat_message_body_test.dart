import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_message_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _messageId = '30000000-0000-0000-0000-000000000001';
final _created = DateTime.utc(2026, 9, 19, 12);

OperationalChatMessage _message(
        {ChatSendStatus status = ChatSendStatus.sent}) =>
    OperationalChatMessage(
      id: _messageId,
      conversationId: '20000000-0000-0000-0000-000000000001',
      senderId: '10000000-0000-0000-0000-000000000001',
      rawText: 'Tối nay đi quẩy không?',
      sourceLanguageCode: 'vi',
      clientGeneratedId: '40000000-0000-0000-0000-000000000001',
      clientCreatedAt: _created,
      sentAt: status == ChatSendStatus.sent ? _created : null,
      sendStatus: status,
    );

OperationalChatTranslation _translation(
  ChatTranslationStatus status, {
  DateTime? nextAttemptAt,
  String? translatedText,
}) =>
    OperationalChatTranslation(
      id: '50000000-0000-0000-0000-000000000001',
      messageId: _messageId,
      targetLanguageCode: 'en',
      provider: operationalChatTranslationProvider,
      model: operationalChatTranslationModel,
      promptVersion: operationalChatPromptVersion,
      translatorVersion: operationalChatTranslatorVersion,
      status: status,
      attemptCount: status == ChatTranslationStatus.queued ? 0 : 1,
      nextAttemptAt: nextAttemptAt,
      translatedText: translatedText,
      errorCode: status == ChatTranslationStatus.failed
          ? 'PROVIDER_UNAVAILABLE'
          : null,
      createdAt: _created,
      updatedAt: _created,
      completedAt: status == ChatTranslationStatus.succeeded ? _created : null,
    );

Widget _app({
  OperationalChatMessage? message,
  OperationalChatTranslation? translation,
  bool loading = false,
  bool error = false,
  Future<void> Function(String text, String languageCode)? onSpeak,
  Future<void> Function(String text, String languageCode)? onLookup,
  String? speakingLineKey,
}) =>
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            child: OperationalChatMessageBody(
              message: message ?? _message(),
              viewerNativeLanguageCode: 'vi',
              translation: translation,
              translationCacheLoading: loading,
              translationCacheError: error,
              onSpeak: onSpeak,
              onLookup: onLookup,
              speakingLineKey: speakingLineKey,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('raw stays selectable through loading, queue and failure states',
      (tester) async {
    Future<void> verify(Widget app, String state) async {
      await tester.pumpWidget(app);
      expect(find.widgetWithText(SelectableText, _message().rawText),
          findsOneWidget);
      expect(find.text(state), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await verify(_app(loading: true), 'Đang đọc bản dịch đã lưu…');
    await verify(_app(translation: _translation(ChatTranslationStatus.queued)),
        'Đang chờ bản dịch…');
    await verify(
        _app(translation: _translation(ChatTranslationStatus.processing)),
        'Đang dịch…');
    await verify(
      _app(
        translation: _translation(
          ChatTranslationStatus.failed,
          nextAttemptAt: _created.add(const Duration(seconds: 30)),
        ),
      ),
      'Dịch tạm gián đoạn · sẽ tự thử lại',
    );
    await verify(
      _app(translation: _translation(ChatTranslationStatus.failed)),
      'Chưa dịch được · tin gốc vẫn hiển thị',
    );
    await verify(_app(error: true), 'Không đọc được trạng thái dịch');
    await verify(
      _app(message: _message(status: ChatSendStatus.pending)),
      'Chờ gửi tin gốc trước khi dịch',
    );
  });

  testWidgets(
      'speaks each visible language line without replacing selectable text',
      (tester) async {
    final calls = <(String, String)>[];
    final translation = _translation(
      ChatTranslationStatus.succeeded,
      translatedText: 'Are we going out tonight?',
    );
    await tester.pumpWidget(_app(
      translation: translation,
      onSpeak: (text, languageCode) async => calls.add((text, languageCode)),
    ));

    final primaryButton = find.byKey(
      const ValueKey('chat-speak-chat-primary-$_messageId'),
    );
    final secondaryButton = find.byKey(
      const ValueKey('chat-speak-chat-secondary-$_messageId'),
    );
    expect(primaryButton, findsOneWidget);
    expect(secondaryButton, findsOneWidget);
    expect(tester.getSize(primaryButton), const Size(48, 48));
    expect(tester.getSize(secondaryButton), const Size(48, 48));
    expect(find.widgetWithText(SelectableText, 'Are we going out tonight?'),
        findsOneWidget);
    expect(find.widgetWithText(SelectableText, _message().rawText),
        findsOneWidget);

    await tester.tap(primaryButton);
    await tester.pump();
    await tester.tap(secondaryButton);
    await tester.pump();

    expect(calls, [
      ('Are we going out tonight?', 'en'),
      (_message().rawText, 'vi'),
    ]);
  });

  testWidgets('shows progress and disables the active speech line',
      (tester) async {
    await tester.pumpWidget(_app(
      onSpeak: (_, __) async {},
      speakingLineKey: '$_messageId:vi',
    ));

    final button = tester.widget<IconButton>(find.byKey(
      const ValueKey('chat-speak-chat-primary-$_messageId'),
    ));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(SelectableText, _message().rawText),
        findsOneWidget);
  });

  testWidgets('adds local lookup to selected English text and keeps copy menu',
      (tester) async {
    final calls = <(String, String)>[];
    await tester.pumpWidget(_app(
      translation: _translation(
        ChatTranslationStatus.succeeded,
        translatedText: 'Are we going out tonight?',
      ),
      onLookup: (text, languageCode) async => calls.add((text, languageCode)),
    ));

    final textFinder = find.byKey(
      const ValueKey('chat-text-chat-primary-$_messageId'),
    );
    final editableFinder = find.descendant(
      of: textFinder,
      matching: find.byType(EditableText),
    );
    final editable = tester.state<EditableTextState>(editableFinder);
    final renderEditable = editable.renderEditable;
    final firstWordPosition = renderEditable.localToGlobal(
      renderEditable.getLocalRectForCaret(const TextPosition(offset: 1)).center,
    );
    await tester.longPressAt(firstWordPosition);
    await tester.pumpAndSettle();

    expect(find.text('Tra từ'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Tra từ'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.$2, 'en');
    expect(
        'Are we going out tonight?'.toLowerCase(), contains(calls.single.$1));
  });
}
