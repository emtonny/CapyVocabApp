import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../shared/widgets/sticker_button.dart';
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
    this.sequential = false,
    super.key,
  });

  final BuiltPhotoOrderQuestion question;
  final List<LessonMasteryItem> items;
  final LibraryMediaLoader mediaLoader;
  final ValueChanged<String> onChanged;
  final ValueChanged<Map<int, String>> onSubmit;
  final String? initialDraftJson;
  final bool enabled;
  final bool sequential;

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
        Text(
          widget.sequential ? 'Game 1/2 · Nối từ' : 'Ghép từ với đồ vật',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
                excludeSemantics: true,
                label: 'Thẻ từ ${item.answer}',
                child: Draggable<String>(
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
          Builder(builder: (context) {
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
                  constraints: const BoxConstraints(minHeight: 64),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.ink, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.ink,
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      OrderNumberChip(number: target.marker),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          placed == null ? 'Chọn một thẻ từ' : 'Đã ghép',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            widget.enabled &&
                            widget.question.itemIds.contains(details.data),
                        onAcceptWithDetails: (details) =>
                            _place(target.marker, details.data),
                        builder: (context, candidates, rejects) {
                          final isHovering = candidates.isNotEmpty;
                          return Container(
                            key: Key('photo-order-dropzone-${target.marker}'),
                            width: (MediaQuery.sizeOf(context).width * .31)
                                .clamp(92.0, 142.0),
                            height: 44,
                            padding: const EdgeInsets.only(bottom: 3),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isHovering
                                    ? AppColors.yellow
                                    : placed == null
                                        ? AppColors.softWhite
                                        : AppColors.mint,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isHovering
                                      ? AppColors.darkGreen
                                      : AppColors.ink,
                                  width: isHovering ? 2.5 : 1.8,
                                ),
                              ),
                              child: Text(
                                placed?.answer ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: StickerButton(
            key: const Key('photo-order-submit'),
            text: 'Kiểm tra',
            onPressed: widget.enabled && complete
                ? () => widget.onSubmit(Map.unmodifiable(_placements))
                : null,
            surfaceColor: widget.enabled && complete
                ? AppColors.duoGreen
                : const Color(0xFFD8D7CF),
            textColor:
                widget.enabled && complete ? Colors.white : AppColors.mutedInk,
            edgeColor: widget.enabled && complete
                ? const Color(0xFF3A8F0A)
                : const Color(0xFFB7B5AC),
            fontSize: 16,
            radius: 16,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            minHeight: 52,
            expand: true,
          ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
      child: StickerButton(
        text: answer,
        onPressed: onTap,
        surfaceColor: selected
            ? AppColors.yellow
            : assigned
                ? AppColors.mint
                : AppColors.softWhite,
        edgeColor: selected ? const Color(0xFFE8A900) : null,
        fontSize: 14,
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        minHeight: 48,
      ),
    );
  }
}
