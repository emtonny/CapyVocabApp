import 'package:flutter/material.dart';

import '../../library/domain/entities/local_vocabulary_match.dart';
import '../domain/operational_chat.dart';

/// Adds C5 bilingual text and C6A speech without replacing the raw message UI.
class OperationalChatMessageBody extends StatelessWidget {
  const OperationalChatMessageBody({
    required this.message,
    required this.viewerNativeLanguageCode,
    this.translation,
    this.translationCacheLoading = false,
    this.translationCacheError = false,
    this.onSpeak,
    this.onLookup,
    this.speakingLineKey,
    this.primaryStyle,
    super.key,
  });

  final OperationalChatMessage message;
  final String? viewerNativeLanguageCode;
  final OperationalChatTranslation? translation;
  final bool translationCacheLoading;
  final bool translationCacheError;
  final Future<void> Function(String text, String languageCode)? onSpeak;
  final Future<void> Function(String text, String languageCode)? onLookup;
  final String? speakingLineKey;
  final TextStyle? primaryStyle;

  @override
  Widget build(BuildContext context) {
    final effectivePrimary = primaryStyle ?? DefaultTextStyle.of(context).style;
    final successful = translation?.status == ChatTranslationStatus.succeeded;
    final translatedText = successful ? translation!.translatedText : null;
    final translationIsPrimary = translatedText != null &&
        viewerNativeLanguageCode == message.sourceLanguageCode &&
        viewerNativeLanguageCode != translation!.targetLanguageCode;

    if (translatedText == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SelectableLanguageLine(
            key: ValueKey('chat-primary-${message.id}'),
            lineKey: 'chat-primary-${message.id}',
            label: 'Tin gốc',
            languageCode: message.sourceLanguageCode,
            text: message.rawText,
            style: effectivePrimary,
            primary: true,
            onSpeak: onSpeak,
            onLookup: onLookup,
            speaking: speakingLineKey ==
                '${message.id}:${message.sourceLanguageCode}',
          ),
          const SizedBox(height: 6),
          _TranslationState(
            key: ValueKey('chat-translation-state-${message.id}'),
            message: message,
            translation: translation,
            cacheLoading: translationCacheLoading,
            cacheError: translationCacheError,
          ),
        ],
      );
    }

    final primaryText = translationIsPrimary ? translatedText : message.rawText;
    final primaryLanguage = translationIsPrimary
        ? translation!.targetLanguageCode
        : message.sourceLanguageCode;
    final primaryLabel = translationIsPrimary ? 'Bản dịch' : 'Tin gốc';
    final secondaryText =
        translationIsPrimary ? message.rawText : translatedText;
    final secondaryLanguage = translationIsPrimary
        ? message.sourceLanguageCode
        : translation!.targetLanguageCode;
    final secondaryLabel = translationIsPrimary ? 'Tin gốc' : 'Bản dịch';
    final secondaryStyle = effectivePrimary.copyWith(
      color: const Color(0xFF665952),
      fontSize: (effectivePrimary.fontSize ?? 14) - 1,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SelectableLanguageLine(
          key: ValueKey('chat-primary-${message.id}'),
          lineKey: 'chat-primary-${message.id}',
          label: primaryLabel,
          languageCode: primaryLanguage,
          text: primaryText,
          style: effectivePrimary,
          primary: true,
          onSpeak: onSpeak,
          onLookup: onLookup,
          speaking: speakingLineKey == '${message.id}:$primaryLanguage',
        ),
        const Divider(height: 13, thickness: 1, color: Color(0x443E322E)),
        _SelectableLanguageLine(
          key: ValueKey('chat-secondary-${message.id}'),
          lineKey: 'chat-secondary-${message.id}',
          label: secondaryLabel,
          languageCode: secondaryLanguage,
          text: secondaryText,
          style: secondaryStyle,
          primary: false,
          onSpeak: onSpeak,
          onLookup: onLookup,
          speaking: speakingLineKey == '${message.id}:$secondaryLanguage',
        ),
      ],
    );
  }
}

class _SelectableLanguageLine extends StatelessWidget {
  const _SelectableLanguageLine({
    required this.label,
    required this.lineKey,
    required this.languageCode,
    required this.text,
    required this.style,
    required this.primary,
    required this.onSpeak,
    required this.onLookup,
    required this.speaking,
    super.key,
  });

  final String label;
  final String lineKey;
  final String languageCode;
  final String text;
  final TextStyle style;
  final bool primary;
  final Future<void> Function(String text, String languageCode)? onSpeak;
  final Future<void> Function(String text, String languageCode)? onLookup;
  final bool speaking;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!primary || label == 'Bản dịch')
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '$label · ${_languageLabel(languageCode)}',
                style: const TextStyle(
                  color: Color(0xFF7A6B63),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label:
                      '${primary ? 'Dòng chính' : 'Dòng phụ'}, $label, ${_languageLabel(languageCode)}: $text',
                  excludeSemantics: true,
                  child: SelectableText(
                    text,
                    key: ValueKey('chat-text-$lineKey'),
                    style: style,
                    contextMenuBuilder: onLookup == null
                        ? null
                        : (context, editableTextState) =>
                            _buildContextMenu(context, editableTextState),
                  ),
                ),
              ),
              if (onSpeak != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey('chat-speak-$lineKey'),
                  tooltip: 'Nghe $label bằng ${_languageLabel(languageCode)}',
                  visualDensity: VisualDensity.standard,
                  onPressed:
                      speaking ? null : () => onSpeak!(text, languageCode),
                  icon: speaking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.volume_up_rounded),
                ),
              ],
            ],
          ),
        ],
      );

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final value = editableTextState.textEditingValue;
    final selection = value.selection;
    final selected = selection.isValid && !selection.isCollapsed
        ? normalizeLocalVocabularyQuery(selection.textInside(value.text))
        : '';
    final items = List<ContextMenuButtonItem>.of(
      editableTextState.contextMenuButtonItems,
    );
    if (languageCode == 'en' &&
        selected.isNotEmpty &&
        selected.runes.length <= 80) {
      items.insert(
        0,
        ContextMenuButtonItem(
          label: 'Tra từ',
          onPressed: () {
            ContextMenuController.removeAny();
            onLookup!(selected, languageCode);
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }
}

class _TranslationState extends StatelessWidget {
  const _TranslationState({
    required this.message,
    required this.translation,
    required this.cacheLoading,
    required this.cacheError,
    super.key,
  });

  final OperationalChatMessage message;
  final OperationalChatTranslation? translation;
  final bool cacheLoading;
  final bool cacheError;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = _state();
    return Semantics(
      liveRegion: true,
      label: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF7A6B63)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF7A6B63),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String) _state() {
    if (message.sendStatus == ChatSendStatus.pending) {
      return (Icons.schedule_rounded, 'Chờ gửi tin gốc trước khi dịch');
    }
    if (message.sendStatus == ChatSendStatus.blocked) {
      return (Icons.error_outline_rounded, 'Tin chưa gửi nên chưa thể dịch');
    }
    if (cacheError) {
      return (Icons.warning_amber_rounded, 'Không đọc được trạng thái dịch');
    }
    if (translation == null) {
      return cacheLoading
          ? (Icons.translate_rounded, 'Đang đọc bản dịch đã lưu…')
          : (Icons.schedule_rounded, 'Đang chờ bản dịch…');
    }
    return switch (translation!.status) {
      ChatTranslationStatus.queued => (
          Icons.schedule_rounded,
          'Đang chờ bản dịch…'
        ),
      ChatTranslationStatus.processing => (
          Icons.translate_rounded,
          'Đang dịch…'
        ),
      ChatTranslationStatus.failed when translation!.nextAttemptAt != null => (
          Icons.sync_rounded,
          'Dịch tạm gián đoạn · sẽ tự thử lại'
        ),
      ChatTranslationStatus.failed => (
          Icons.error_outline_rounded,
          'Chưa dịch được · tin gốc vẫn hiển thị'
        ),
      ChatTranslationStatus.succeeded => (
          Icons.check_rounded,
          'Bản dịch đã sẵn sàng'
        ),
    };
  }
}

String _languageLabel(String code) => switch (code) {
      'vi' => 'Tiếng Việt',
      'en' => 'Tiếng Anh',
      _ => code.toUpperCase(),
    };
