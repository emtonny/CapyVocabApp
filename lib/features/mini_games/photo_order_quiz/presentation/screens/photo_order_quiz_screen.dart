import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../library/application/library_media_loader.dart';
import '../../../application/lesson_question_builder.dart';
import '../../../domain/lesson_game.dart';
import '../../../presentation/widgets/lesson_photo_view.dart';
import '../widgets/order_number_chip.dart';

class PhotoOrderQuizScreen extends StatefulWidget {
  const PhotoOrderQuizScreen({
    required this.question,
    required this.items,
    required this.mediaLoader,
    required this.onChanged,
    required this.onSubmit,
    this.initialDraftJson,
    this.enabled = true,
    super.key,
  });

  final BuiltPhotoOrderQuestion question;
  final List<LessonMasteryItem> items;
  final LibraryMediaLoader mediaLoader;
  final ValueChanged<String> onChanged;
  final ValueChanged<Map<int, String>> onSubmit;
  final String? initialDraftJson;
  final bool enabled;

  @override
  State<PhotoOrderQuizScreen> createState() => _PhotoOrderQuizScreenState();
}

class _PhotoOrderQuizScreenState extends State<PhotoOrderQuizScreen> {
  final Map<int, String> _placements = {};
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void didUpdateWidget(covariant PhotoOrderQuizScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _placements.clear();
      _selectedItemId = null;
      _restoreDraft();
    }
  }

  void _restoreDraft() {
    final encoded = widget.initialDraftJson;
    if (encoded == null) return;
    try {
      final json = (jsonDecode(encoded) as Map).cast<String, Object?>();
      if (json['question_id'] != widget.question.id) return;
      final placements = (json['placements'] as Map?)?.cast<String, Object?>();
      if (placements == null) return;
      final validIds = widget.question.itemIds.toSet();
      for (final entry in placements.entries) {
        final marker = int.tryParse(entry.key);
        final itemId = entry.value;
        if (marker != null && itemId is String && validIds.contains(itemId)) {
          _placements[marker] = itemId;
        }
      }
      if (_placements.values.toSet().length != _placements.length) {
        _placements.clear();
      }
    } on Object {
      _placements.clear();
    }
  }

  void _place(int marker, String itemId) {
    if (!widget.enabled) return;
    setState(() {
      _placements.removeWhere((_, value) => value == itemId);
      _placements[marker] = itemId;
      _selectedItemId = null;
    });
    widget.onChanged(jsonEncode({
      'question_id': widget.question.id,
      'placements': {
        for (final entry in _placements.entries) '${entry.key}': entry.value,
      },
    }));
  }

  @override
  Widget build(BuildContext context) {
    final itemById = {for (final item in widget.items) item.id: item};
    final targets = widget.question.question.targets;
    final firstItem = itemById[targets.first.itemId]!;
    final complete = _placements.length == targets.length &&
        _placements.values.toSet().length == targets.length;
    final cards = targets.reversed
        .map((target) => itemById[target.itemId]!)
        .toList(growable: false);

    return Column(
      key: Key('photo-order-question-${widget.question.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ghép từ với đồ vật',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kéo thẻ vào ô số, hoặc chạm thẻ rồi chạm ô.',
          style:
              TextStyle(color: AppColors.mutedInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        LessonPhotoView(
          mediaLoader: widget.mediaLoader,
          relativePath: firstItem.imageRelativePath,
          imageWidth: firstItem.imageWidth,
          imageHeight: firstItem.imageHeight,
          markers: [
            for (final target in targets)
              LessonPhotoMarker(
                box: itemById[target.itemId]!.boundingBox,
                number: target.marker,
                semanticLabel: 'Đồ vật số ${target.marker}',
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in cards)
              Semantics(
                key: Key('photo-order-card-${item.id}'),
                button: true,
                selected: _selectedItemId == item.id,
                label: 'Thẻ từ ${item.answer}',
                child: LongPressDraggable<String>(
                  data: item.id,
                  maxSimultaneousDrags: widget.enabled ? 1 : 0,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _WordCard(
                      answer: item.answer,
                      selected: true,
                    ),
                  ),
                  child: _WordCard(
                    answer: item.answer,
                    selected: _selectedItemId == item.id,
                    assigned: _placements.containsValue(item.id),
                    onTap: widget.enabled
                        ? () => setState(() {
                              _selectedItemId = item.id;
                            })
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final target in targets) ...[
          DragTarget<String>(
            onWillAcceptWithDetails: (_) => widget.enabled,
            onAcceptWithDetails: (details) =>
                _place(target.marker, details.data),
            builder: (context, candidates, rejects) {
              final placedId = _placements[target.marker];
              final placed = placedId == null ? null : itemById[placedId];
              return Semantics(
                button: true,
                label: placed == null
                    ? 'Ô số ${target.marker}, chưa có từ'
                    : 'Ô số ${target.marker}, ${placed.answer}',
                child: InkWell(
                  key: Key('photo-order-slot-${target.marker}'),
                  onTap: !widget.enabled
                      ? null
                      : () {
                          final selected = _selectedItemId;
                          if (selected != null) {
                            _place(target.marker, selected);
                          } else if (placedId != null) {
                            setState(() => _placements.remove(target.marker));
                            widget.onChanged(jsonEncode({
                              'question_id': widget.question.id,
                              'placements': {
                                for (final entry in _placements.entries)
                                  '${entry.key}': entry.value,
                              },
                            }));
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: candidates.isEmpty
                          ? AppColors.softWhite
                          : AppColors.yellow.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: Row(
                      children: [
                        OrderNumberChip(number: target.marker),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            placed?.answer ?? 'Chọn một thẻ từ',
                            style: TextStyle(
                              color: placed == null
                                  ? AppColors.mutedInk
                                  : AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        FilledButton(
          key: const Key('photo-order-submit'),
          onPressed: widget.enabled && complete
              ? () => widget.onSubmit(Map.unmodifiable(_placements))
              : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Kiểm tra'),
        ),
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.answer,
    this.selected = false,
    this.assigned = false,
    this.onTap,
  });

  final String answer;
  final bool selected;
  final bool assigned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.yellow
              : assigned
                  ? AppColors.mint.withValues(alpha: .55)
                  : AppColors.softWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink, width: selected ? 3 : 2),
        ),
        child: Text(
          answer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
