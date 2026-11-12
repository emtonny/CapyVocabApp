import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../library/domain/entities/local_vocabulary_match.dart';

class OperationalChatDictionarySheet extends StatefulWidget {
  const OperationalChatDictionarySheet({
    required this.query,
    required this.lookup,
    super.key,
  });

  final String query;
  final Future<List<LocalVocabularyMatch>> Function() lookup;

  @override
  State<OperationalChatDictionarySheet> createState() =>
      _OperationalChatDictionarySheetState();
}

class _OperationalChatDictionarySheetState
    extends State<OperationalChatDictionarySheet> {
  late Future<List<LocalVocabularyMatch>> _matches;

  @override
  void initState() {
    super.initState();
    _matches = widget.lookup();
  }

  void _retry() {
    final matches = widget.lookup();
    setState(() {
      _matches = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.58,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tra từ trên máy',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    key: const Key('chat-dictionary-close'),
                    tooltip: 'Đóng tra từ',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                '“${widget.query}” · ưu tiên Library local · không dùng mạng',
                key: const Key('chat-dictionary-query'),
                style: const TextStyle(
                  color: Color(0xFF665952),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<LocalVocabularyMatch>>(
                  future: _matches,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          key: Key('chat-dictionary-loading'),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _DictionaryNotice(
                        key: const Key('chat-dictionary-error'),
                        icon: Icons.warning_amber_rounded,
                        text: 'Không đọc được từ vựng trên máy.',
                        actionLabel: 'Thử lại',
                        onAction: _retry,
                      );
                    }
                    final matches = snapshot.data ?? const [];
                    if (matches.isEmpty) {
                      return const _DictionaryNotice(
                        key: Key('chat-dictionary-empty'),
                        icon: Icons.search_off_rounded,
                        text: 'Chưa có từ này trong Library trên máy.',
                      );
                    }
                    return ListView.separated(
                      key: const Key('chat-dictionary-results'),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _VocabularyCard(match: matches[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VocabularyCard extends StatelessWidget {
  const _VocabularyCard({required this.match});

  final LocalVocabularyMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('chat-dictionary-result-${match.word}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.word,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (match.corrected)
                const Tooltip(
                  message: 'Ưu tiên correction mới nhất trong Library',
                  child: Icon(Icons.verified_rounded, size: 22),
                ),
            ],
          ),
          if (match.phonetic != null) Text(match.phonetic!),
          if (match.meaningVi != null)
            Text(
              match.meaningVi!,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          if (match.partOfSpeech != null)
            Text('Từ loại: ${match.partOfSpeech}'),
          if (match.exampleEn != null) Text('Ví dụ: ${match.exampleEn}'),
          if (match.exampleVi != null) Text('Nghĩa ví dụ: ${match.exampleVi}'),
          const SizedBox(height: 6),
          Text(
            'Library trên máy · ${match.occurrenceCount} nguồn đã lưu',
            style: const TextStyle(color: Color(0xFF665952), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DictionaryNotice extends StatelessWidget {
  const _DictionaryNotice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: text,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}
