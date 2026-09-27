import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../domain/operational_chat.dart';
import 'operational_chat_provider.dart';

/// C6C correction UI. The raw message above this panel is never replaced.
class OperationalChatCorrectionPanel extends ConsumerStatefulWidget {
  const OperationalChatCorrectionPanel({
    required this.owner,
    required this.conversationId,
    required this.message,
    required this.viewerNativeLanguageCode,
    super.key,
  });

  final ChatOwner owner;
  final String conversationId;
  final OperationalChatMessage message;
  final String? viewerNativeLanguageCode;

  @override
  ConsumerState<OperationalChatCorrectionPanel> createState() =>
      _OperationalChatCorrectionPanelState();
}

class _OperationalChatCorrectionPanelState
    extends ConsumerState<OperationalChatCorrectionPanel> {
  bool _working = false;

  String get _targetLanguageCode =>
      widget.message.sourceLanguageCode == 'vi' ? 'en' : 'vi';

  bool get _canPropose =>
      widget.message.senderId != widget.owner.userId &&
      widget.message.sendStatus == ChatSendStatus.sent &&
      widget.viewerNativeLanguageCode == _targetLanguageCode;

  Future<void> _propose() async {
    if (_working || !_canPropose) return;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _CorrectionProposalDialog(),
    );
    if (text == null || !mounted) return;
    await _perform(() async {
      final coordinator =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (coordinator == null) throw StateError('Chat unavailable.');
      await coordinator.proposeCorrection(
        messageId: widget.message.id,
        proposedText: text,
        targetLanguageCode: _targetLanguageCode,
      );
    }, 'Đã lưu đề xuất trên máy và sẽ tự đồng bộ.');
  }

  Future<void> _decide(
      OperationalChatCorrection correction, ChatCorrectionDecision decision) {
    return _perform(() async {
      final coordinator =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (coordinator == null) throw StateError('Chat unavailable.');
      await coordinator.decideCorrection(correction.id, decision);
    }, 'Đã lưu lựa chọn trên máy và sẽ tự đồng bộ.');
  }

  Future<void> _tag(OperationalChatCorrection correction) async {
    if (_working ||
        widget.message.senderId != widget.owner.userId ||
        correction.status != ChatCorrectionStatus.accepted ||
        correction.acceptedBy != widget.owner.userId ||
        correction.syncStatus != ChatCorrectionSyncStatus.synced) {
      return;
    }
    final draft = await showDialog<_AnnotationDraft>(
      context: context,
      builder: (_) => _AnnotationDialog(rawText: widget.message.rawText),
    );
    if (draft == null || !mounted) return;
    await _perform(() async {
      final coordinator =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      if (coordinator == null) throw StateError('Chat unavailable.');
      await coordinator.proposeAnnotation(
        messageId: widget.message.id,
        correctionId: correction.id,
        spanText: draft.spanText,
        spanStart: draft.spanStart,
        spanEnd: draft.spanEnd,
        tagType: draft.tagType,
        normalizedSource: draft.normalizedSource,
      );
    }, 'Đã lưu nhãn trên máy và sẽ tự đồng bộ.');
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    if (_working || ref.read(operationalChatOwnerProvider) != widget.owner) {
      return;
    }
    setState(() => _working = true);
    try {
      await action();
      if (mounted && ref.read(operationalChatOwnerProvider) == widget.owner) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted && ref.read(operationalChatOwnerProvider) == widget.owner) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa lưu được thao tác correction. Hãy thử lại.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(operationalChatCorrectionsProvider(
        (widget.owner, widget.conversationId)));
    final annotationState = ref.watch(operationalChatAnnotationsProvider(
        (widget.owner, widget.conversationId)));
    final corrections = state.asData?.value
            .where((row) => row.messageId == widget.message.id)
            .toList() ??
        const <OperationalChatCorrection>[];
    final mine = widget.message.senderId == widget.owner.userId;
    final alreadyProposed = corrections.any((row) =>
        row.authorId == widget.owner.userId &&
        row.status == ChatCorrectionStatus.proposed &&
        row.syncStatus != ChatCorrectionSyncStatus.proposalBlocked);
    if (corrections.isEmpty && (mine || !_canPropose)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final correction in corrections)
            _CorrectionCard(
              correction: correction,
              annotations: annotationState.asData?.value
                      .where((row) => row.correctionId == correction.id)
                      .toList() ??
                  const <OperationalChatAnnotation>[],
              canDecide: mine &&
                  correction.status == ChatCorrectionStatus.proposed &&
                  correction.syncStatus == ChatCorrectionSyncStatus.synced &&
                  !_working,
              onDecision: (decision) => _decide(correction, decision),
              canTag: mine &&
                  correction.status == ChatCorrectionStatus.accepted &&
                  correction.acceptedBy == widget.owner.userId &&
                  correction.syncStatus == ChatCorrectionSyncStatus.synced &&
                  !_working,
              onTag: () => _tag(correction),
            ),
          if (_canPropose && !alreadyProposed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('chat-correct-${widget.message.id}'),
                onPressed: _working ? null : _propose,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Sửa giúp bạn'),
              ),
            ),
          if (state.hasError)
            const Text('Không đọc được correction đã lưu.',
                style: TextStyle(fontSize: 12, color: Color(0xFFE94141))),
          if (annotationState.hasError)
            const Text('Không đọc được nhãn đã lưu.',
                style: TextStyle(fontSize: 12, color: Color(0xFFE94141))),
        ],
      ),
    );
  }
}

class _CorrectionProposalDialog extends StatefulWidget {
  const _CorrectionProposalDialog();

  @override
  State<_CorrectionProposalDialog> createState() =>
      _CorrectionProposalDialogState();
}

class _CorrectionProposalDialogState extends State<_CorrectionProposalDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sửa giúp bạn'),
        content: TextField(
          key: const Key('chat-correction-input'),
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'Nhập câu bạn đề xuất…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('chat-correction-save'),
            onPressed: () {
              final value = _controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Gửi đề xuất'),
          ),
        ],
      );
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    required this.correction,
    required this.annotations,
    required this.canDecide,
    required this.onDecision,
    required this.canTag,
    required this.onTag,
  });

  final OperationalChatCorrection correction;
  final List<OperationalChatAnnotation> annotations;
  final bool canDecide;
  final ValueChanged<ChatCorrectionDecision> onDecision;
  final bool canTag;
  final VoidCallback onTag;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('chat-correction-${correction.id}'),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7DD),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đề xuất · ${_stateLabel(correction)}',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            SelectableText(correction.proposedText),
            for (final annotation in annotations) ...[
              const SizedBox(height: 6),
              Container(
                key: ValueKey('chat-annotation-${annotation.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.ink.withValues(alpha: .3)),
                ),
                child: Text(
                  '“${annotation.spanText}” · ${_tagLabel(annotation.tagType)}'
                  ' → ${annotation.normalizedSource}${_annotationState(annotation)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (canDecide) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('chat-reject-${correction.id}'),
                    onPressed: () =>
                        onDecision(ChatCorrectionDecision.rejected),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('chat-accept-${correction.id}'),
                    onPressed: () =>
                        onDecision(ChatCorrectionDecision.accepted),
                    child: const Text('Chấp nhận'),
                  ),
                ),
              ]),
            ],
            if (canTag) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                key: ValueKey('chat-tag-${correction.id}'),
                onPressed: onTag,
                icon: const Icon(Icons.label_outline_rounded, size: 18),
                label: const Text('Đánh dấu từ lóng/viết tắt'),
              ),
            ],
          ],
        ),
      );
}

final class _AnnotationDraft {
  const _AnnotationDraft({
    required this.spanText,
    required this.spanStart,
    required this.spanEnd,
    required this.tagType,
    required this.normalizedSource,
  });

  final String spanText;
  final int spanStart;
  final int spanEnd;
  final ChatAnnotationType tagType;
  final String normalizedSource;
}

class _AnnotationDialog extends StatefulWidget {
  const _AnnotationDialog({required this.rawText});
  final String rawText;

  @override
  State<_AnnotationDialog> createState() => _AnnotationDialogState();
}

class _AnnotationDialogState extends State<_AnnotationDialog> {
  late final TextEditingController _rawController;
  late final List<_AnnotationToken> _tokens;
  final _normalizedController = TextEditingController();
  ChatAnnotationType _type = ChatAnnotationType.slang;
  TextSelection _selection = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    _tokens = _annotationTokens(widget.rawText);
    _rawController = TextEditingController(text: widget.rawText)
      ..addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() {
    final next = _rawController.selection;
    if (next == _selection || !mounted) return;
    setState(() => _selection = next);
  }

  void _selectToken(_AnnotationToken token) {
    HapticFeedback.selectionClick();
    final selection = _selection;
    final start = selection.isValid && !selection.isCollapsed
        ? (selection.start < selection.end ? selection.start : selection.end)
        : token.start;
    final end = selection.isValid && !selection.isCollapsed
        ? (selection.start < selection.end ? selection.end : selection.start)
        : token.end;
    final tokenIsSelected =
        token.start >= start && token.end <= end && start != end;
    _rawController.selection = tokenIsSelected
        ? TextSelection(baseOffset: token.start, extentOffset: token.end)
        : TextSelection(
            baseOffset: token.start < start ? token.start : start,
            extentOffset: token.end > end ? token.end : end,
          );
  }

  void _clearSelection() {
    _rawController.selection = const TextSelection.collapsed(offset: 0);
  }

  bool _isTokenSelected(_AnnotationToken token) {
    final selection = _selection;
    if (!selection.isValid || selection.isCollapsed) return false;
    final start =
        selection.start < selection.end ? selection.start : selection.end;
    final end =
        selection.start < selection.end ? selection.end : selection.start;
    return token.start >= start && token.end <= end;
  }

  String? _selectedText() {
    final selection = _selection;
    if (!selection.isValid || selection.isCollapsed) return null;
    final start =
        selection.start < selection.end ? selection.start : selection.end;
    final end =
        selection.start < selection.end ? selection.end : selection.start;
    return widget.rawText.substring(start, end);
  }

  @override
  void dispose() {
    _rawController
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _normalizedController.dispose();
    super.dispose();
  }

  _AnnotationDraft? _draft() {
    final selection = _selection;
    if (!selection.isValid || selection.isCollapsed) return null;
    final base = selection.start;
    final extent = selection.end;
    final startUnits = base < extent ? base : extent;
    final endUnits = base < extent ? extent : base;
    final start = _runeOffset(widget.rawText, startUnits);
    final end = _runeOffset(widget.rawText, endUnits);
    if (start == null || end == null || end <= start) return null;
    final selected =
        String.fromCharCodes(widget.rawText.runes.toList().sublist(start, end));
    final normalized = _normalizedController.text.trim();
    if (selected.trim().isEmpty || normalized.isEmpty) return null;
    return _AnnotationDraft(
      spanText: selected,
      spanStart: start,
      spanEnd: end,
      tagType: _type,
      normalizedSource: normalized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = _selectedText();
    return AlertDialog(
      title: const Text('Đánh dấu cách nói'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chạm một từ để chọn. Chạm từ khác để mở rộng thành cụm.',
              ),
              const SizedBox(height: 8),
              Container(
                key: const Key('chat-annotation-token-picker'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _tokens.isEmpty
                    ? const Text('Dùng lựa chọn chính xác bên dưới.')
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final availableLabelWidth = constraints.maxWidth > 48
                              ? constraints.maxWidth - 48
                              : constraints.maxWidth;
                          final maxLabelWidth = availableLabelWidth > 320
                              ? 320.0
                              : availableLabelWidth;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var index = 0;
                                  index < _tokens.length;
                                  index++)
                                FilterChip(
                                  key: ValueKey(
                                    'chat-annotation-token-$index',
                                  ),
                                  label: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: maxLabelWidth,
                                    ),
                                    child: Text(
                                      _tokens[index].text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  selected: _isTokenSelected(_tokens[index]),
                                  onSelected: (_) =>
                                      _selectToken(_tokens[index]),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (selectedText != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đã chọn: “$selectedText”',
                        key: const Key('chat-annotation-selection-preview'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      key: const Key('chat-annotation-clear-selection'),
                      onPressed: _clearSelection,
                      child: const Text('Bỏ chọn'),
                    ),
                  ],
                ),
              ],
              ExpansionTile(
                key: const Key('chat-annotation-precise-picker'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Chọn chính xác theo ký tự'),
                subtitle: const Text('Dùng khi từ cần chọn chưa tách đúng.'),
                children: [
                  TextField(
                    key: const Key('chat-annotation-raw'),
                    controller: _rawController,
                    readOnly: true,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      helperText: 'Bôi đen đoạn cần gắn nhãn.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ChatAnnotationType>(
                key: const Key('chat-annotation-type'),
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Loại',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in ChatAnnotationType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(
                        _tagLabel(type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('chat-annotation-normalized'),
                controller: _normalizedController,
                maxLength: 4000,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Dạng chuẩn trong ngôn ngữ câu gốc',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('chat-annotation-save'),
          onPressed:
              _draft() == null ? null : () => Navigator.pop(context, _draft()),
          child: const Text('Lưu nhãn'),
        ),
      ],
    );
  }
}

final class _AnnotationToken {
  const _AnnotationToken({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final int start;
  final int end;
}

final _annotationTokenPattern = RegExp(
  r'[^\s.,!?;:()\[\]{}"“”‘’…]+',
  unicode: true,
);

List<_AnnotationToken> _annotationTokens(String text) => [
      for (final match in _annotationTokenPattern.allMatches(text))
        _AnnotationToken(
          text: match.group(0)!,
          start: match.start,
          end: match.end,
        ),
    ];

int? _runeOffset(String text, int codeUnitOffset) {
  if (codeUnitOffset < 0 || codeUnitOffset > text.length) return null;
  if (codeUnitOffset > 0 && codeUnitOffset < text.length) {
    final before = text.codeUnitAt(codeUnitOffset - 1);
    final after = text.codeUnitAt(codeUnitOffset);
    if (before >= 0xD800 &&
        before <= 0xDBFF &&
        after >= 0xDC00 &&
        after <= 0xDFFF) {
      return null;
    }
  }
  return text.substring(0, codeUnitOffset).runes.length;
}

String _tagLabel(ChatAnnotationType type) => switch (type) {
      ChatAnnotationType.slang => 'Từ lóng',
      ChatAnnotationType.abbreviation => 'Viết tắt',
      ChatAnnotationType.informalAddress => 'Xưng hô thân mật',
      ChatAnnotationType.idiom => 'Thành ngữ',
      ChatAnnotationType.typoOrPhoneticSpelling =>
        'Viết theo âm / lỗi chính tả',
      ChatAnnotationType.other => 'Khác',
    };

String _annotationState(OperationalChatAnnotation annotation) =>
    switch (annotation.syncStatus) {
      ChatAnnotationSyncStatus.synced => '',
      ChatAnnotationSyncStatus.pending => ' · đang gửi',
      ChatAnnotationSyncStatus.blocked => ' · không gửi được',
    };

String _stateLabel(OperationalChatCorrection correction) {
  return switch (correction.syncStatus) {
    ChatCorrectionSyncStatus.proposalPending => 'đang gửi',
    ChatCorrectionSyncStatus.proposalBlocked => 'không gửi được',
    ChatCorrectionSyncStatus.decisionPending => 'đang lưu lựa chọn',
    ChatCorrectionSyncStatus.decisionBlocked => 'chưa lưu được lựa chọn',
    ChatCorrectionSyncStatus.synced => switch (correction.status) {
        ChatCorrectionStatus.proposed => 'đang chờ phản hồi',
        ChatCorrectionStatus.accepted => 'đã chấp nhận',
        ChatCorrectionStatus.rejected => 'đã từ chối',
      },
  };
}
