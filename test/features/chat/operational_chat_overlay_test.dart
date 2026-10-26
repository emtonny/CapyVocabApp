import 'package:capy_vocab/features/chat/data/operational_chat_supabase_gateway.dart';
import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_overlay.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_correction_panel.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = '10000000-0000-0000-0000-000000000001';
const _friend = '10000000-0000-0000-0000-000000000002';
const _conversation = '20000000-0000-0000-0000-000000000001';

void main() {
  final owner = ChatOwner(
      projectRef: OperationalChatSupabaseGateway.stagingRef, userId: _user);
  final conversation = ChatConversation(
    id: _conversation,
    peerId: _friend,
    lastMessageAt: DateTime.utc(2026, 9, 17, 12),
    lastMessageText: 'Bạn học tới đâu rồi?',
    unreadCount: 3,
  );
  final profile = ChatPeerProfile(
      id: _friend,
      displayName: 'Capy Mây',
      username: 'capy_may',
      avatarUrl: '');
  final message = OperationalChatMessage(
    id: '30000000-0000-0000-0000-000000000001',
    conversationId: _conversation,
    senderId: _friend,
    clientGeneratedId: '40000000-0000-0000-0000-000000000001',
    sourceLanguageCode: 'vi',
    clientCreatedAt: DateTime.utc(2026, 9, 17, 12),
    sentAt: DateTime.utc(2026, 9, 17, 12, 1),
    rawText: 'Giữ nguyên 📷 [Ảnh: demo.jpg] như nội dung text.',
    sendStatus: ChatSendStatus.sent,
  );
  final translation = OperationalChatTranslation(
    id: '50000000-0000-0000-0000-000000000001',
    messageId: message.id,
    targetLanguageCode: 'en',
    translatedText: 'Keep 📷 [Image: demo.jpg] as plain text.',
    provider: operationalChatTranslationProvider,
    model: operationalChatTranslationModel,
    promptVersion: operationalChatPromptVersion,
    translatorVersion: operationalChatTranslatorVersion,
    status: ChatTranslationStatus.succeeded,
    attemptCount: 1,
    createdAt: DateTime.utc(2026, 9, 17, 12, 1),
    updatedAt: DateTime.utc(2026, 9, 17, 12, 2),
    completedAt: DateTime.utc(2026, 9, 17, 12, 2),
  );

  Widget app({
    ValueChanged<String>? openConversation,
    String viewerNativeLanguageCode = 'vi',
  }) =>
      ProviderScope(
        overrides: [
          operationalChatEnabledProvider.overrideWithValue(true),
          operationalChatOwnerProvider.overrideWithValue(owner),
          operationalChatInboxProvider(owner)
              .overrideWith((_) => Stream.value([conversation])),
          operationalChatFriendsProvider(owner)
              .overrideWith((_) async => [_friend]),
          operationalChatPeerProfilesProvider(owner)
              .overrideWith((_) => Stream.value([profile])),
          operationalChatMessagesProvider((owner, _conversation))
              .overrideWith((_) => Stream.value([message])),
          operationalChatTranslationsProvider((owner, _conversation))
              .overrideWith((_) => Stream.value([translation])),
          operationalChatSourceProvider(owner)
              .overrideWith((_) => Stream.value(viewerNativeLanguageCode)),
          operationalChatStoreProvider(owner).overrideWith((_) async => null),
          operationalChatProfileRefreshProvider(owner)
              .overrideWith((_) async {}),
        ],
        child: MaterialApp(
          home: OperationalChatOverlay(
            openConversation: openConversation,
            child: const Scaffold(body: Text('Trang chủ')),
          ),
        ),
      );

  testWidgets(
      'bubble shows unread, opens mailbox and opens conversation in-box',
      (tester) async {
    String? opened;
    await tester.pumpWidget(app(openConversation: (id) => opened = id));
    await tester.pump();
    final bubble = find.byKey(const Key('operational-chat-bubble'));
    expect(bubble, findsOneWidget);
    expect(tester.widget<Semantics>(bubble).properties.label,
        'Mở hộp thư chat, 3 tin nhắn chưa đọc');
    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.text('Hộp Thư Chat'), findsOneWidget);
    expect(find.text('Capy Mây'), findsOneWidget);
    expect(find.text('Bạn học tới đâu rồi?'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    await tester.enterText(
        find.byKey(const Key('chat-mailbox-search')), 'không có');
    await tester.pump();
    expect(find.text('Capy Mây'), findsNothing);
    expect(find.text('Không tìm thấy bạn bè hoặc cuộc trò chuyện.'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('chat-mailbox-search')), 'capy mây');
    await tester.pump();
    await tester.tap(find.text('Capy Mây'));
    await tester.pumpAndSettle();
    expect(opened, _conversation);

    // In-box conversation view is rendered inside the box chat
    expect(find.byKey(const Key('chat-mailbox-back')), findsOneWidget);
    expect(find.text('Tin gốc luôn được giữ · bản dịch theo hồ sơ'),
        findsOneWidget);
    expect(
      find.text('Giữ nguyên 📷 [Ảnh: demo.jpg] như nội dung text.'),
      findsOneWidget,
    );
    expect(
        find.text('Keep 📷 [Image: demo.jpg] as plain text.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(ValueKey('chat-primary-${message.id}'))).dy,
      lessThan(tester
          .getTopLeft(find.byKey(ValueKey('chat-secondary-${message.id}')))
          .dy),
    );
    expect(find.byKey(const Key('chat-compose')), findsOneWidget);
    expect(find.byKey(const Key('chat-pick-image')), findsNothing);
    expect(find.byKey(const Key('chat-send')), findsOneWidget);

    // Tapping back button returns to the mailbox friend list
    await tester.tap(find.byKey(const Key('chat-mailbox-back')));
    await tester.pumpAndSettle();
    expect(find.text('Hộp Thư Chat'), findsOneWidget);
    expect(find.text('Capy Mây'), findsOneWidget);
  });

  testWidgets(
      'same shared row follows each viewer language without UI overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(app(viewerNativeLanguageCode: 'en'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('operational-chat-bubble')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capy Mây'));
    await tester.pumpAndSettle();

    final primary = find.byKey(ValueKey('chat-primary-${message.id}'));
    final secondary = find.byKey(ValueKey('chat-secondary-${message.id}'));
    expect(primary, findsOneWidget);
    expect(secondary, findsOneWidget);
    expect(find.descendant(of: primary, matching: find.text(message.rawText)),
        findsOneWidget);
    expect(
      find.descendant(
          of: secondary, matching: find.text(translation.translatedText!)),
      findsOneWidget,
    );
    expect(
        find.bySemanticsLabel(RegExp('Dòng chính, Tin gốc')), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('chat-send'))).right,
        lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
      'archived group is listed and opens as read-only without correction',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final semantics = tester.ensureSemantics();
    const groupId = '60000000-0000-0000-0000-000000000001';
    final groupConversation = ChatConversation.group(
      id: '60000000-0000-0000-0000-000000000002',
      groupId: groupId,
      title: 'Lớp Anh văn A',
      memberCount: 4,
      groupArchived: true,
      unreadCount: 1,
    );
    final groupMessage = OperationalChatMessage(
      id: '60000000-0000-0000-0000-000000000003',
      conversationId: groupConversation.id,
      senderId: _friend,
      clientGeneratedId: '60000000-0000-0000-0000-000000000004',
      sourceLanguageCode: 'vi',
      clientCreatedAt: DateTime.utc(2026, 10, 17),
      sentAt: DateTime.utc(2026, 10, 17),
      rawText: 'Chào cả lớp',
      sendStatus: ChatSendStatus.sent,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatEnabledProvider.overrideWithValue(true),
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatInboxProvider(owner)
            .overrideWith((_) => Stream.value([groupConversation])),
        operationalChatFriendsProvider(owner).overrideWith((_) async => []),
        operationalChatPeerProfilesProvider(owner)
            .overrideWith((_) => Stream.value([profile])),
        operationalChatMessagesProvider((owner, groupConversation.id))
            .overrideWith((_) => Stream.value([groupMessage])),
        operationalChatTranslationsProvider((owner, groupConversation.id))
            .overrideWith((_) => Stream.value([])),
        operationalChatSourceProvider(owner)
            .overrideWith((_) => Stream.value('vi')),
        operationalChatStoreProvider(owner).overrideWith((_) async => null),
        operationalChatProfileRefreshProvider(owner).overrideWith((_) async {}),
      ],
      child: const MaterialApp(
        home: OperationalChatOverlay(
          child: Scaffold(body: Text('Trang chủ')),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('operational-chat-bubble')));
    await tester.pumpAndSettle();
    expect(find.text('Lớp Anh văn A'), findsOneWidget);

    await tester.tap(find.text('Lớp Anh văn A'));
    await tester.pumpAndSettle();

    expect(find.text('4 thành viên · bản dịch theo hồ sơ'), findsOneWidget);
    expect(find.text('Capy Mây'), findsOneWidget);
    expect(
        find.byKey(const Key('chat-mailbox-group-read-only')), findsOneWidget);
    expect(find.byType(OperationalChatCorrectionPanel), findsNothing);
    expect(
        tester.widget<TextField>(find.byKey(const Key('chat-compose'))).enabled,
        isFalse);
    expect(find.bySemanticsLabel('Gửi tin nhắn'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('mailbox has no chatbot and idle bubble retreats to edge',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final bubble = find.byKey(const Key('operational-chat-bubble'));
    final before = tester.getCenter(bubble);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getCenter(bubble).dx, greaterThan(before.dx));

    await tester.tapAt(const Offset(797, 450));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-mailbox-search')), findsOneWidget);
    expect(find.byKey(const Key('chat-ai-card')), findsNothing);
    expect(find.byKey(const Key('chatbot-window')), findsNothing);
  });

  testWidgets('bubble can be dragged and docks to the nearest edge',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final bubble = find.byKey(const Key('operational-chat-bubble'));
    final before = tester.getCenter(bubble);
    await tester.drag(bubble, const Offset(-700, -160));
    await tester.pumpAndSettle();
    final docked = tester.getCenter(bubble);
    expect(docked.dx, lessThan(before.dx));
    expect(docked.dx, lessThan(80));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getCenter(bubble).dx, lessThan(docked.dx));
  });

  testWidgets('bubble follows pointer in real time while user holds and drags',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final bubble = find.byKey(const Key('operational-chat-bubble'));
    final initialPos = tester.getCenter(bubble);

    // Start gesture and move past touch slop
    final gesture = await tester.startGesture(initialPos);
    await tester.pump();
    await gesture.moveBy(const Offset(-25, -20));
    await tester.pump();

    // Now actively drag by (-80, -60)
    await gesture.moveBy(const Offset(-80, -60));
    await tester.pump(); // without pumpAndSettle, position updates immediately

    final currentPos = tester.getCenter(bubble);
    expect((currentPos.dx - (initialPos.dx - 80)).abs(), lessThan(5.0));
    expect((currentPos.dy - (initialPos.dy - 60)).abs(), lessThan(5.0));

    // Finish gesture (snaps to edge on release)
    await gesture.up();
    await tester.pumpAndSettle();
    final dockedPos = tester.getCenter(bubble);
    expect(dockedPos.dx, isNot(equals(currentPos.dx)));
  });

  testWidgets('chat mailbox can be dragged across screen by its header',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(app());
    await tester.pump();
    final bubble = find.byKey(const Key('operational-chat-bubble'));
    await tester.tap(bubble);
    await tester.pumpAndSettle();

    final headerTitle = find.text('Hộp Thư Chat');
    expect(headerTitle, findsOneWidget);
    final initialPos = tester.getTopLeft(headerTitle);

    // Drag the header to the left and up
    await tester.drag(headerTitle, const Offset(-120, -50));
    await tester.pump();

    final draggedPos = tester.getTopLeft(headerTitle);
    expect(draggedPos.dx, lessThan(initialPos.dx));
    expect(draggedPos.dy, lessThan(initialPos.dy));

    // Drag down to verify downward movement
    await tester.drag(headerTitle, const Offset(60, 100));
    await tester.pump();
    final draggedDownPos = tester.getTopLeft(headerTitle);
    expect(draggedDownPos.dy, greaterThan(draggedPos.dy));

    // Open conversation directly from the open mailbox to verify dragging in conversation view
    await tester.tap(find.text('Capy Mây'));
    await tester.pumpAndSettle();

    final convHeaderTitle = find.text('Capy Mây');
    expect(convHeaderTitle, findsOneWidget);
    final convInitialPos = tester.getTopLeft(convHeaderTitle);
    await tester.drag(convHeaderTitle, const Offset(-100, -30));
    await tester.pump();
    final convDraggedPos = tester.getTopLeft(convHeaderTitle);
    expect(convDraggedPos.dx, lessThan(convInitialPos.dx));
    expect(convDraggedPos.dy, lessThan(convInitialPos.dy));

    // Close conversation button works
    final convCloseBtn = find.byKey(const Key('chat-mailbox-close-conv'));
    await tester.tap(convCloseBtn);
    await tester.pumpAndSettle();
    expect(find.text('Capy Mây'), findsNothing);
  });
}
