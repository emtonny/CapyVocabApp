import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../shared/widgets/sticker_button.dart';
import '../../../../library/application/library_media_loader.dart';
import '../../../application/lesson_question_builder.dart';
import '../../../domain/lesson_game.dart';
import '../../../presentation/widgets/lesson_photo_view.dart';

class PhotoMultiFillScreen extends StatefulWidget {
  const PhotoMultiFillScreen({
    super.key,
    required this.question,
    required this.items,
    required this.mediaLoader,
    required this.onChanged,
    required this.onSubmit,
    this.initialDraftJson,
    this.enabled = true,
    this.loadHints,
  });

  final BuiltPhotoMultiFillQuestion question;
  final List<LessonMasteryItem> items;
  final LibraryMediaLoader mediaLoader;
  final ValueChanged<String> onChanged;
  final ValueChanged<Map<String, String>> onSubmit;
  final String? initialDraftJson;
  final bool enabled;
  final Future<LessonWordHints> Function(LessonMasteryItem)? loadHints;

  @override
  State<PhotoMultiFillScreen> createState() => _PhotoMultiFillScreenState();
}

class _PhotoMultiFillScreenState extends State<PhotoMultiFillScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, int> _hintLevels = {};
  final Map<String, Future<LessonWordHints>> _hintFutures = {};
  static const _hintDuration = Duration(seconds: 5);
  final Set<String> _visibleHints = {};
  final Map<String, Timer> _hintTimers = {};

  @override
  void initState() {
    super.initState();
    Map<String, Object?> draft = {};
    Map<String, Object?> savedHints = {};
    try {
      final json = jsonDecode(widget.initialDraftJson ?? '{}') as Map;
      if (json['question_id'] == widget.question.id) {
        draft = (json['letters'] as Map).cast<String, Object?>();
        if (json['hint_levels'] is Map) {
          savedHints = (json['hint_levels'] as Map).cast<String, Object?>();
        }
      }
    } on Object {
      // A malformed draft must not prevent opening the frozen question.
    }
    for (final item in widget.items) {
      final level = savedHints[item.id];
      _hintLevels[item.id] = level is int ? level.clamp(0, 3) : 0;
      final characters = item.answerNormalized.characters.toList();
      final saved = draft[item.id];
      _controllers[item.id] = TextEditingController(
          text: [
        for (var i = 0; i < characters.length; i++)
          if (characters[i].trim().isNotEmpty)
            saved is List && i < saved.length && saved[i] is String
                ? (saved[i] as String).characters.take(1).toString()
                : ' ',
      ].join().trimRight());
      _focusNodes[item.id] = FocusNode()..addListener(_refresh);
      _controllers[item.id]!.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final timer in _hintTimers.values) {
      timer.cancel();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<String?> _letters(LessonMasteryItem item) {
    final input = _controllers[item.id]!.text.characters.toList();
    var index = 0;
    return [
      for (final character in item.answerNormalized.characters)
        if (character.trim().isEmpty)
          null
        else
          index < input.length ? input[index++] : '',
    ];
  }

  Map<String, String> get _answers => {
        for (final item in widget.items)
          item.id: _letters(item).map((character) => character ?? ' ').join(),
      };

  bool get _complete => widget.items.every((item) => _letters(item)
      .every((character) => character == null || character.trim().isNotEmpty));

  void _changed() {
    widget.onChanged(jsonEncode({
      'question_id': widget.question.id,
      'letters': {
        for (final item in widget.items) item.id: _letters(item),
      },
      'hint_levels': _hintLevels,
    }));
  }

  Future<LessonWordHints> _hintFuture(LessonMasteryItem item) =>
      _hintFutures.putIfAbsent(
          item.id,
          () =>
              widget.loadHints?.call(item) ??
              Future.value(const LessonWordHints()));

  void _showHint(LessonMasteryItem item) {
    _hintTimers.remove(item.id)?.cancel();
    setState(() {
      _hintLevels[item.id] = (_hintLevels[item.id]! + 1).clamp(0, 3);
      _visibleHints.add(item.id);
    });
    _changed();
    // Count five seconds after metadata loads, so slow loading does not consume
    // the time available to read the hint.
    void startTimer() {
      if (!mounted) return;
      _hintTimers.remove(item.id)?.cancel();
      _hintTimers[item.id] = Timer(_hintDuration, () {
        if (!mounted) return;
        setState(() => _visibleHints.remove(item.id));
        _hintTimers.remove(item.id);
      });
    }

    _hintFuture(item).then<void>((_) => startTimer(),
        onError: (Object _, StackTrace __) => startTimer());
  }

  void _focusLetter(String itemId, int index) {
    final controller = _controllers[itemId]!;
    final start = controller.text.characters.take(index).toString().length;
    final offset = start.clamp(0, controller.text.length);
    final end = controller.text.characters.take(index + 1).toString().length;
    controller.selection = TextSelection(
        baseOffset: offset,
        extentOffset: end.clamp(offset, controller.text.length));
    _focusNodes[itemId]!.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final item in widget.items) item.id: item};
    final first = widget.items.first;
    return Column(
      key: Key('photo-multi-fill-question-${widget.question.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Game 2/2 · Điền vào chỗ trống',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text(
            'Nhìn ảnh và nhập từ vào các ô của từng đồ vật được đánh số.',
            style: TextStyle(
                color: AppColors.mutedInk, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        LessonPhotoView(
          mediaLoader: widget.mediaLoader,
          relativePath: first.imageRelativePath,
          imageWidth: first.imageWidth,
          imageHeight: first.imageHeight,
          markers: [
            for (final target in widget.question.question.targets)
              LessonPhotoMarker(
                box: byId[target.itemId]!.boundingBox,
                number: target.marker,
                semanticLabel: 'Đồ vật số ${target.marker}',
              ),
          ],
        ),
        const SizedBox(height: 18),
        for (final target in widget.question.question.targets) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(3, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          'Đồ vật #${target.marker} · ${_letters(byId[target.itemId]!).whereType<String>().length} ký tự',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15))),
                  SizedBox(
                      width: 44,
                      height: 44,
                      child: StickerButton(
                        key: Key('photo-fill-hint-${target.itemId}'),
                        semanticLabel:
                            'Gợi ý đồ vật #${target.marker} (${_hintLevels[target.itemId]}/3)',
                        padding: const EdgeInsets.all(6),
                        surfaceColor: _visibleHints.contains(target.itemId)
                            ? AppColors.yellow
                            : AppColors.softWhite,
                        radius: 14,
                        minHeight: 44,
                        expand: true,
                        onPressed: widget.enabled
                            ? () => _showHint(byId[target.itemId]!)
                            : null,
                        icon: Image.asset(
                            'assets/images/fluent_light_bulb_3d.png',
                            width: 30,
                            height: 30),
                      )),
                ]),
                if (_visibleHints.contains(target.itemId))
                  _hintPanel(byId[target.itemId]!),
                const SizedBox(height: 14),
                _wordInput(byId[target.itemId]!, target.marker),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        StickerButton(
          key: const Key('photo-multi-fill-submit'),
          label: 'Nộp bài',
          surfaceColor: AppColors.duoGreen,
          textColor: Colors.white,
          minHeight: 52,
          radius: 16,
          fontSize: 16,
          expand: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onPressed: widget.enabled && _complete
              ? () => widget.onSubmit(_answers)
              : null,
        ),
      ],
    );
  }

  Widget _wordInput(LessonMasteryItem item, int marker) {
    final letters = _letters(item);
    final controller = _controllers[item.id]!;
    final node = _focusNodes[item.id]!;
    var compactIndex = 0;
    return Stack(
      children: [
        // One input connection per word keeps IME composition and Backspace
        // intact; the cells paint the same value without switching text fields.
        Positioned.fill(
          child: TextField(
            key: Key('photo-multi-fill-input-${item.id}'),
            controller: controller,
            focusNode: node,
            enabled: widget.enabled,
            keyboardType: TextInputType.text,
            maxLines: null,
            expands: true,
            showCursor: false,
            enableInteractiveSelection: false,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              LengthLimitingTextInputFormatter(
                  letters.whereType<String>().length),
            ],
            style: const TextStyle(color: Colors.transparent),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              labelText: 'Nhập từ cho đồ vật số $marker',
              labelStyle: const TextStyle(color: Colors.transparent),
            ),
            onChanged: (_) => _changed(),
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (var i = 0; i < letters.length; i++)
              if (letters[i] == null)
                const SizedBox(width: 18, height: 52)
              else
                _letterCell(item.id, i, compactIndex++, letters[i]!, node),
          ],
        ),
      ],
    );
  }

  Widget _hintPanel(LessonMasteryItem item) {
    final level = _hintLevels[item.id]!;
    final future = _hintFuture(item);
    return FutureBuilder<LessonWordHints>(
      future: future,
      builder: (context, snapshot) => Container(
        key: Key('photo-fill-hint-panel-${item.id}'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10, bottom: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.yellow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(3, 3))
            ]),
        child: DefaultTextStyle.merge(
            style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gợi ý $level/3 · Tự ẩn sau 5 giây',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 6),
                if (snapshot.connectionState != ConnectionState.done)
                  const Text('Đang tải gợi ý…')
                else ...[
                  Text(
                      'Nghĩa: ${snapshot.data?.meaningVi ?? 'Chưa có nghĩa tiếng Việt.'}'),
                  if (level >= 2)
                    Text(
                        'Phiên âm: ${snapshot.data?.phonetic ?? 'Chưa có phiên âm.'}'),
                ],
                if (level >= 3)
                  Text('Từ vựng: ${item.answer}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            )),
      ),
    );
  }

  Widget _letterCell(String itemId, int index, int compactIndex,
      String character, FocusNode node) {
    final controller = _controllers[itemId]!;
    final selectionIndex = controller.text
        .substring(0,
            controller.selection.extentOffset.clamp(0, controller.text.length))
        .characters
        .length;
    final selected = node.hasFocus && selectionIndex == compactIndex;
    return GestureDetector(
      onTap: widget.enabled ? () => _focusLetter(itemId, compactIndex) : null,
      child: Container(
        key: Key('photo-multi-fill-$itemId-$index'),
        width: 44,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.duoGreen : AppColors.ink,
              width: selected ? 3 : 2),
        ),
        child: Text(character,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink)),
      ),
    );
  }
}
