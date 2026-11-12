import 'package:capy_vocab/features/chat/domain/operational_chat.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_correction_panel.dart';
import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'operational_chat_relay_test.dart' as f;

void main() {
  final owner = ChatOwner(projectRef: f.project, userId: f.a);

  testWidgets('peer message adds correction action without replacing raw UI',
      (tester) async {
    final incoming = f.ack(f.message(1, sender: f.b));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: incoming,
            viewerNativeLanguageCode:
                incoming.sourceLanguageCode == 'vi' ? 'en' : 'vi',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Sửa giúp bạn'), findsOneWidget);
    expect(find.byKey(ValueKey('chat-correct-${incoming.id}')), findsOneWidget);
    expect(find.text(incoming.rawText), findsNothing);
  });

  testWidgets('submitting proposal disposes dialog controller after route exit',
      (tester) async {
    final incoming = f.ack(f.message(1, sender: f.b));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: incoming,
            viewerNativeLanguageCode:
                incoming.sourceLanguageCode == 'vi' ? 'en' : 'vi',
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(ValueKey('chat-correct-${incoming.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('chat-correction-input')), 'A clearer sentence.');
    await tester.tap(find.byKey(const Key('chat-correction-save')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-correction-input')), findsNothing);
  });

  testWidgets(
      'proposal action is hidden when viewer language cannot satisfy RLS',
      (tester) async {
    final incoming = f.ack(f.message(1, sender: f.b));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: incoming,
            viewerNativeLanguageCode: incoming.sourceLanguageCode,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Sửa giúp bạn'), findsNothing);
  });

  testWidgets('raw sender sees separate selectable proposal and decisions',
      (tester) async {
    final own = f.ack(f.message(1));
    final correction = OperationalChatCorrection(
      id: f.uuid(7001),
      messageId: own.id,
      authorId: f.b,
      targetLanguageCode: 'en',
      proposedText: 'Are you going tonight?',
      status: ChatCorrectionStatus.proposed,
      createdAt: f.instant,
      updatedAt: f.instant,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([correction])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: own,
            viewerNativeLanguageCode: 'vi',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Are you going tonight?'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('Chấp nhận'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.text('Sửa giúp bạn'), findsNothing);
  });

  testWidgets('final correction is labelled and has no decision controls',
      (tester) async {
    final own = f.ack(f.message(1));
    final correction = OperationalChatCorrection(
      id: f.uuid(7001),
      messageId: own.id,
      authorId: f.b,
      targetLanguageCode: 'en',
      proposedText: 'Are you going tonight?',
      status: ChatCorrectionStatus.rejected,
      rejectedBy: f.a,
      rejectedAt: f.instant,
      createdAt: f.instant,
      updatedAt: f.instant,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([correction])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: own,
            viewerNativeLanguageCode: 'vi',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Đề xuất · đã từ chối'), findsOneWidget);
    expect(find.text('Chấp nhận'), findsNothing);
    expect(find.text('Từ chối'), findsNothing);
  });

  testWidgets('accepted correction lets raw sender tap words to select a span',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longToken = List.filled(120, 'x').join();
    final own = f.ack(
      f.message(1, text: 'Tối nay đi quẩy k $longToken'),
    );
    final correction = OperationalChatCorrection(
      id: f.uuid(7001),
      messageId: own.id,
      authorId: f.b,
      targetLanguageCode: 'en',
      proposedText: 'Want to hit the club tonight?',
      status: ChatCorrectionStatus.accepted,
      acceptedBy: f.a,
      acceptedAt: f.instant,
      createdAt: f.instant,
      updatedAt: f.instant,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([correction])),
        operationalChatAnnotationsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: own,
            viewerNativeLanguageCode: 'vi',
          ),
        ),
      ),
    ));
    await tester.pump();

    final action = find.byKey(ValueKey('chat-tag-${correction.id}'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('chat-annotation-token-picker')), findsOneWidget);
    expect(find.byKey(const Key('chat-annotation-raw')), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('chat-annotation-token-3')))
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const ValueKey('chat-annotation-token-3')));
    await tester.pump();
    expect(find.text('Đã chọn: “quẩy”'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-annotation-token-2')));
    await tester.pump();
    expect(find.text('Đã chọn: “đi quẩy”'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-annotation-clear-selection')));
    await tester.pump();
    expect(find.byKey(const Key('chat-annotation-selection-preview')),
        findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('chat-annotation-save')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('chat-annotation-token-3')));
    await tester.enterText(
        find.byKey(const Key('chat-annotation-normalized')), 'đi chơi');
    await tester.pump();
    final save = tester
        .widget<FilledButton>(find.byKey(const Key('chat-annotation-save')));
    expect(save.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('chat-annotation-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat-annotation-raw')), findsNothing);
  });

  testWidgets('synced annotation renders without replacing accepted correction',
      (tester) async {
    final own = f.ack(f.message(1));
    final correction = OperationalChatCorrection(
      id: f.uuid(7001),
      messageId: own.id,
      authorId: f.b,
      targetLanguageCode: 'en',
      proposedText: 'Want to hit the club tonight?',
      status: ChatCorrectionStatus.accepted,
      acceptedBy: f.a,
      acceptedAt: f.instant,
      createdAt: f.instant,
      updatedAt: f.instant,
    );
    final annotation = OperationalChatAnnotation(
      id: f.uuid(7101),
      messageId: own.id,
      correctionId: correction.id,
      createdBy: f.a,
      spanText: 'quẩy',
      spanStart: 11,
      spanEnd: 15,
      tagType: ChatAnnotationType.slang,
      normalizedSource: 'đi chơi hoặc đi bar',
      createdAt: f.instant,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        operationalChatOwnerProvider.overrideWithValue(owner),
        operationalChatCorrectionsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([correction])),
        operationalChatAnnotationsProvider((owner, f.conversation))
            .overrideWith((_) => Stream.value([annotation])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OperationalChatCorrectionPanel(
            owner: owner,
            conversationId: f.conversation,
            message: own,
            viewerNativeLanguageCode: 'vi',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byKey(ValueKey('chat-annotation-${annotation.id}')),
        findsOneWidget);
    expect(find.textContaining('“quẩy” · Từ lóng → đi chơi hoặc đi bar'),
        findsOneWidget);
    expect(find.text(correction.proposedText), findsOneWidget);
  });
}
