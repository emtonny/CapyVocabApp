import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../library/application/library_media_loader.dart';
import '../../../application/lesson_question_builder.dart';
import '../../../domain/lesson_game.dart';
import '../../../presentation/widgets/lesson_photo_view.dart';
import '../widgets/letter_input_box.dart';

class PhotoLetterFillScreen extends StatefulWidget {
  const PhotoLetterFillScreen({
    required this.question,
    required this.item,
    required this.mediaLoader,
    required this.onChanged,
    required this.onSubmit,
    this.initialDraftJson,
    this.enabled = true,
    super.key,
  });

  final BuiltPhotoLetterFillQuestion question;
  final LessonMasteryItem item;
  final LibraryMediaLoader mediaLoader;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final String? initialDraftJson;
  final bool enabled;

  @override
  State<PhotoLetterFillScreen> createState() => _PhotoLetterFillScreenState();
}

class _PhotoLetterFillScreenState extends State<PhotoLetterFillScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialAnswer());
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  String _initialAnswer() {
    final encoded = widget.initialDraftJson;
    if (encoded == null) return '';
    try {
      final json = (jsonDecode(encoded) as Map).cast<String, Object?>();
      return json['question_id'] == widget.question.id
          ? (json['answer'] as String? ?? '')
          : '';
    } on Object {
      return '';
    }
  }

  void _onTextChanged() {
    widget.onChanged(jsonEncode({
      'question_id': widget.question.id,
      'answer': _controller.text,
    }));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeLessonAnswer(_controller.text);
    final valid = normalized.isNotEmpty && normalized.runes.length <= 80;
    final characters = _controller.text.characters.toList(growable: false);
    return Column(
      key: Key('photo-fill-question-${widget.question.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Điền từ cho đồ vật',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Nhập từ tiếng Anh của vùng đang được tô sáng.',
          style:
              TextStyle(color: AppColors.mutedInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        LessonPhotoView(
          mediaLoader: widget.mediaLoader,
          relativePath: widget.item.imageRelativePath,
          imageWidth: widget.item.imageWidth,
          imageHeight: widget.item.imageHeight,
          markers: [
            LessonPhotoMarker(
              box: widget.item.boundingBox,
              semanticLabel: 'Đồ vật cần điền từ',
              highlighted: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('photo-fill-text-field'),
          controller: _controller,
          enabled: widget.enabled,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Từ tiếng Anh',
            hintText: 'Ví dụ: apple',
            border: OutlineInputBorder(),
          ),
          onSubmitted: valid && widget.enabled ? widget.onSubmit : null,
        ),
        if (characters.isNotEmpty) ...[
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < characters.length; index++)
                  LetterInputBox(
                    character: characters[index],
                    active: index == characters.length - 1,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('photo-fill-submit'),
          onPressed: widget.enabled && valid
              ? () => widget.onSubmit(_controller.text)
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
