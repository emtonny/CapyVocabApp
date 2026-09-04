import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../vocab_scan/domain/label_connector_geometry.dart';
import '../../../vocab_scan/presentation/label_connector_painter.dart';
import '../label_template_store.dart';
import '../label_visual_style.dart';
import 'emoji_picker_dialog.dart';

class CustomLabelStyleEditor extends StatefulWidget {
  const CustomLabelStyleEditor({
    required this.style,
    required this.onChanged,
    required this.onTemplatesChanged,
    this.templateStore = const LabelTemplateStore(),
    super.key,
  });

  final LabelVisualStyle style;
  final ValueChanged<LabelVisualStyle> onChanged;
  final ValueChanged<List<SavedLabelTemplate>> onTemplatesChanged;
  final LabelTemplateStore templateStore;

  @override
  State<CustomLabelStyleEditor> createState() => _CustomLabelStyleEditorState();
}

class _CustomLabelStyleEditorState extends State<CustomLabelStyleEditor> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final onChanged = widget.onChanged;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EditorHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _ComparisonPreview(style: style),
          ),
          _EditorSection(
            sectionKey: const Key('section-label-frame'),
            title: 'Box label',
            subtitle: 'Nền, hình dáng, viền và chữ',
            icon: Icons.crop_square_rounded,
            accent: const Color(0xFFFDA4AF), // Coral Pink Accent
            background: const Color(0xFFFFF0ED), // Pastel Peach
            initiallyExpanded: false,
            children: [
              _ChoiceControl(
                controlKey: 'corner-style',
                title: 'Hình dạng',
                selected: style.cornerStyle,
                options: const [
                  _ChoiceOption(LabelCornerStyle.square, 'Góc vuông'),
                  _ChoiceOption(LabelCornerStyle.soft, 'Bo nhẹ'),
                  _ChoiceOption(LabelCornerStyle.round, 'Bo tròn'),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(cornerStyle: value)),
              ),
              _OpacityControl(
                sliderKey: const Key('card-opacity-slider'),
                title: 'Độ trong suốt nền',
                value: style.cardOpacity,
                onChanged: (value) =>
                    onChanged(style.copyWith(cardOpacity: value)),
              ),
              _ChoiceControl(
                controlKey: 'border-thickness',
                title: 'Độ dày viền',
                selected: style.borderThickness,
                options: const [
                  _ChoiceOption(LabelBorderThickness.thin, 'Mảnh'),
                  _ChoiceOption(LabelBorderThickness.medium, 'Vừa'),
                  _ChoiceOption(LabelBorderThickness.bold, 'Đậm'),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(borderThickness: value)),
              ),
              _ColorControl(
                controlKey: 'border-color',
                title: 'Màu viền',
                selected: style.borderColor,
                options: _borderColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(borderColor: color)),
              ),
              _ColorControl(
                controlKey: 'card-color',
                title: 'Màu nền label',
                selected: style.cardColor,
                options: _cardColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(cardColor: color)),
              ),
              _ColorControl(
                controlKey: 'text-color',
                title: 'Màu chữ',
                selected: style.textColor,
                options: _textColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(textColor: color)),
              ),
              _ColorControl(
                controlKey: 'meaning-color',
                title: 'Màu nghĩa tiếng Việt',
                selected: style.meaningColor,
                options: _meaningColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(meaningColor: color)),
              ),
            ],
          ),
          _EditorSection(
            sectionKey: const Key('section-badge'),
            title: 'Badge số',
            subtitle: 'Thiết kế riêng, không phụ thuộc box label',
            icon: Icons.looks_one_rounded,
            accent: const Color(0xFFFCD34D), // Yellow Accent
            background: const Color(0xFFFEF3C7), // Pastel Yellow
            children: [
              _ChoiceControl(
                controlKey: 'badge-shape',
                title: 'Hình dạng badge',
                selected: style.badgeShape,
                options: const [
                  _ChoiceOption(LabelBadgeShape.square, 'Góc vuông'),
                  _ChoiceOption(LabelBadgeShape.soft, 'Bo nhẹ'),
                  _ChoiceOption(LabelBadgeShape.pill, 'Viên thuốc'),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(badgeShape: value)),
              ),
              _ChoiceControl(
                controlKey: 'badge-border-thickness',
                title: 'Độ dày viền badge',
                selected: style.badgeBorderThickness,
                options: const [
                  _ChoiceOption(LabelBorderThickness.thin, 'Mảnh'),
                  _ChoiceOption(LabelBorderThickness.medium, 'Vừa'),
                  _ChoiceOption(LabelBorderThickness.bold, 'Đậm'),
                ],
                onSelected: (value) => onChanged(
                  style.copyWith(badgeBorderThickness: value),
                ),
              ),
              _ColorControl(
                controlKey: 'badge-color',
                title: 'Màu nền badge',
                selected: style.badgeColor,
                options: _cardColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(badgeColor: color)),
              ),
              _ColorControl(
                controlKey: 'badge-text-color',
                title: 'Màu chữ số',
                selected: style.badgeTextColor,
                options: _textColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(badgeTextColor: color)),
              ),
              _ColorControl(
                controlKey: 'badge-border-color',
                title: 'Màu viền badge',
                selected: style.badgeBorderColor,
                options: _borderColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(badgeBorderColor: color)),
              ),
            ],
          ),
          _EditorSection(
            sectionKey: const Key('section-connector'),
            title: 'Đường nối & mũi tên',
            subtitle: 'Kiểu nét, độ dày và điểm kết thúc',
            icon: Icons.trending_flat_rounded,
            accent: const Color(0xFF93C5FD), // Blue Accent
            background: const Color(0xFFE0F2FE), // Pastel Blue
            children: [
              _ChoiceControl(
                controlKey: 'connector-line',
                title: 'Kiểu đường nối',
                selected: style.connectorLineStyle,
                options: const [
                  _ChoiceOption(ConnectorLineStyle.solid, 'Nét liền'),
                  _ChoiceOption(ConnectorLineStyle.dashed, 'Nét đứt'),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(connectorLineStyle: value)),
              ),
              _ChoiceControl(
                controlKey: 'connector-thickness',
                title: 'Độ dày',
                selected: style.connectorThickness,
                options: const [
                  _ChoiceOption(ConnectorThickness.thin, 'Mảnh'),
                  _ChoiceOption(ConnectorThickness.medium, 'Vừa'),
                  _ChoiceOption(ConnectorThickness.bold, 'Đậm'),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(connectorThickness: value)),
              ),
              _ChoiceControl(
                controlKey: 'arrow-style',
                title: 'Kiểu đầu mũi tên',
                selected: style.connectorArrowStyle,
                options: const [
                  _ChoiceOption(ConnectorArrowStyle.pointed, 'Nhọn'),
                  _ChoiceOption(ConnectorArrowStyle.rounded, 'Tròn'),
                  _ChoiceOption(ConnectorArrowStyle.dot, 'Chấm tròn'),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(connectorArrowStyle: value)),
              ),
              _ColorControl(
                controlKey: 'connector-color',
                title: 'Màu đường nối',
                selected: style.connectorColor,
                options: _connectorColors,
                onSelected: (color) =>
                    onChanged(style.copyWith(connectorColor: color)),
              ),
              _ToggleControl(
                toggleKey: const Key('toggle-connector-halo'),
                title: 'Viền halo trắng',
                value: style.showConnectorHalo,
                onChanged: (value) =>
                    onChanged(style.copyWith(showConnectorHalo: value)),
              ),
            ],
          ),
          _EditorSection(
            sectionKey: const Key('section-decoration'),
            title: 'Trang trí',
            subtitle: 'Sticker và icon góc label',
            icon: Icons.auto_awesome_rounded,
            accent: const Color(0xFFC4B5FD), // Lavender Accent
            background: const Color(0xFFEDE9FE), // Pastel Lavender
            children: [
              _EmojiPickerControl(
                controlKey: 'sticker',
                title: 'Sticker',
                currentEmoji: style.effectiveStickerEmoji,
                onEmojiSelected: (emoji) {
                  if (emoji.isEmpty) {
                    onChanged(style.copyWith(
                      sticker: LabelSticker.none,
                      clearCustomStickerEmoji: true,
                    ));
                  } else {
                    final matching = LabelSticker.values.firstWhere(
                      (s) => s.emoji == emoji,
                      orElse: () => LabelSticker.capybara,
                    );
                    onChanged(style.copyWith(
                      sticker: matching,
                      customStickerEmoji: emoji,
                    ));
                  }
                },
              ),
              _EmojiPickerControl(
                controlKey: 'corner-icon',
                title: 'Icon góc label',
                currentEmoji: style.effectiveCornerIconEmoji,
                onEmojiSelected: (emoji) {
                  if (emoji.isEmpty) {
                    onChanged(style.copyWith(
                      cornerIcon: LabelCornerIcon.none,
                      clearCustomCornerIconEmoji: true,
                    ));
                  } else {
                    final matching = LabelCornerIcon.values.firstWhere(
                      (c) => c.emoji == emoji,
                      orElse: () => LabelCornerIcon.cookie,
                    );
                    onChanged(style.copyWith(
                      cornerIcon: matching,
                      customCornerIconEmoji: emoji,
                    ));
                  }
                },
              ),
            ],
          ),
          _SaveTemplateButton(
            isSaving: _isSaving,
            onPressed: _isSaving ? null : _saveTemplate,
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    final result = await _showNameDialog();
    if (result == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final templates = await widget.templateStore.save(
        name: result.name,
        style: widget.style,
        iconEmoji: result.iconEmoji,
      );
      if (!mounted) return;
      widget.onTemplatesChanged(templates);
      widget.onChanged(widget.style);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu và áp dụng mẫu “${result.name}”')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu mẫu. Vui lòng thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<_SaveTemplateResult?> _showNameDialog() async {
    var enteredName = '';
    var selectedEmoji = widget.style.showDeerSticker
        ? widget.style.effectiveStickerEmoji
        : '🏷️';
    if (selectedEmoji.isEmpty) selectedEmoji = '🏷️';
    String? errorText;

    return showDialog<_SaveTemplateResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.ink, width: 2.4),
          ),
          backgroundColor: AppColors.softWhite,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.ink, width: 1.6),
                ),
                child: const Icon(
                  Icons.bookmark_add_rounded,
                  color: AppColors.ink,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lưu mẫu thiết kế',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.of(dialogContext).pop(),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child:
                      Icon(Icons.close_rounded, size: 20, color: AppColors.ink),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Box chọn icon cho mẫu
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Icon',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('template-icon-picker-button'),
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                final newEmoji = await EmojiPickerDialog.show(
                                  context,
                                  title: 'Chọn icon mẫu',
                                  currentEmoji: selectedEmoji,
                                  controlKey: 'template-icon',
                                );
                                if (newEmoji != null && newEmoji.isNotEmpty) {
                                  setDialogState(
                                      () => selectedEmoji = newEmoji);
                                }
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.softWhite,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: 1.8,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.ink,
                                      offset: Offset(1, 1),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      selectedEmoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: AppColors.lime,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.ink,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          size: 9,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      // Box đặt tên
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Tên mẫu',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              key: const Key('label-template-name-field'),
                              autofocus: true,
                              maxLength: 30,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ví dụ: Capy bạc hà...',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: Color(0xFF7A7A7A),
                                ),
                                errorText: errorText,
                                filled: true,
                                fillColor: AppColors.softWhite,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                counterStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  color: Color(0xFF4A4A4A),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.ink,
                                    width: 1.8,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.ink,
                                    width: 1.8,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.ink,
                                    width: 2.2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  enteredName = value;
                                  if (value.trim().isNotEmpty) {
                                    errorText = null;
                                  }
                                });
                              },
                              onSubmitted: (value) {
                                final name = value.trim();
                                if (name.isEmpty) {
                                  setDialogState(
                                      () => errorText = 'Hãy nhập tên mẫu');
                                } else {
                                  Navigator.of(dialogContext).pop(
                                    _SaveTemplateResult(
                                      name: name,
                                      iconEmoji: selectedEmoji,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Xem trước thẻ mẫu nhỏ
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.softWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Thẻ xem trước:',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: Color(0xFF4A4A4A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            borderRadius: BorderRadius.circular(5),
                            border:
                                Border.all(color: AppColors.ink, width: 1.2),
                          ),
                          child: Text(
                            selectedEmoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            enteredName.trim().isEmpty
                                ? 'Tên mẫu của bạn'
                                : enteredName.trim(),
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: enteredName.trim().isEmpty
                                  ? const Color(0xFF7A7A7A)
                                  : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Nút hành động
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(
                              color: AppColors.ink,
                              width: 1.8,
                            ),
                          ),
                          child: const Text(
                            'Huỷ',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const Key('confirm-save-label-template'),
                          onPressed: () {
                            final name = enteredName.trim();
                            if (name.isEmpty) {
                              setDialogState(
                                  () => errorText = 'Hãy nhập tên mẫu');
                            } else {
                              Navigator.of(dialogContext).pop(
                                _SaveTemplateResult(
                                  name: name,
                                  iconEmoji: selectedEmoji,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_rounded,
                              size: 16, color: AppColors.ink),
                          label: const Text(
                            'Lưu & áp dụng',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.mint, // Mint
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                  color: AppColors.ink, width: 2.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveTemplateResult {
  const _SaveTemplateResult({
    required this.name,
    required this.iconEmoji,
  });

  final String name;
  final String iconEmoji;
}

class _SaveTemplateButton extends StatelessWidget {
  const _SaveTemplateButton({
    required this.isSaving,
    required this.onPressed,
  });

  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Semantics(
        button: true,
        label: isSaving ? 'Đang lưu mẫu' : 'Lưu mẫu của tôi',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('save-label-template-button'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.mint, // Vibrant Mint
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ink, width: 2.2),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSaving) ...[
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    const Icon(
                      Icons.bookmark_add_rounded,
                      size: 19,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      isSaving ? 'Đang cất mẫu...' : 'Lưu mẫu của tôi',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.yellow, // Vibrant Yellow
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.ink, width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.palette_rounded,
              size: 22,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thiết kế theo sở thích',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 0.1,
                  ),
                ),
                Text(
                  'Tùy chỉnh màu sắc, viền & icon theo phong cách riêng',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.sectionKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.background,
    required this.children,
    this.initiallyExpanded = false,
  });

  final Key sectionKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color background;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.ink, width: 2.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: sectionKey,
              initiallyExpanded: initiallyExpanded,
              maintainState: true,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              expandedAlignment: Alignment.centerLeft,
              tilePadding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
              childrenPadding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                child: Icon(icon, size: 20, color: AppColors.ink),
              ),
              title: Text(
                title,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 0.1,
                ),
              ),
              subtitle: Text(
                subtitle,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A4A4A),
                ),
              ),
              iconColor: AppColors.ink,
              collapsedIconColor: AppColors.ink,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption<T> {
  const _ChoiceOption(
    this.value,
    this.label, [
    this.icon,
    this.emoji,
    this.category,
  ]);

  final T value;
  final String label;
  final IconData? icon;
  final String? emoji;
  final String? category;
}

class _ChoiceControl<T> extends StatelessWidget {
  const _ChoiceControl({
    required this.controlKey,
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String controlKey;
  final String title;
  final T selected;
  final List<_ChoiceOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return _ControlGroup(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          for (final (index, option) in options.indexed)
            ChoiceChip(
              key: Key('$controlKey-$index'),
              selected: option.value == selected,
              showCheckmark: true,
              avatar: option.icon == null ? null : Icon(option.icon, size: 16),
              label: Text(option.label),
              labelStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              selectedColor: AppColors.yellow, // Neo Yellow
              backgroundColor: AppColors.softWhite,
              checkmarkColor: AppColors.ink,
              elevation: 0,
              pressElevation: 0,
              surfaceTintColor: Colors.transparent,
              side: BorderSide(
                color: AppColors.ink,
                width: option.value == selected ? 2.0 : 1.6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onSelected(option.value),
            ),
        ],
      ),
    );
  }
}

class _EmojiPickerControl extends StatelessWidget {
  const _EmojiPickerControl({
    required this.controlKey,
    required this.title,
    required this.currentEmoji,
    required this.onEmojiSelected,
  });

  final String controlKey;
  final String title;
  final String currentEmoji;
  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    final hasEmoji = currentEmoji.isNotEmpty;

    return _ControlGroup(
      title: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('$controlKey-picker-button'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openEmojiDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.ink, width: 1.8),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDD6FE), // Lavender
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.ink, width: 1.5),
                  ),
                  child: hasEmoji
                      ? Text(
                          currentEmoji,
                          style: const TextStyle(fontSize: 20),
                        )
                      : const Icon(
                          Icons.block_rounded,
                          size: 18,
                          color: AppColors.ink,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasEmoji
                            ? 'Biểu tượng: $currentEmoji'
                            : 'Không dùng biểu tượng',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chạm để mở bảng emoji tìm kiếm',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEmojiDialog(BuildContext context) {
    EmojiPickerDialog.show(
      context,
      title: 'Chọn $title',
      currentEmoji: currentEmoji,
      controlKey: controlKey,
    ).then((selected) {
      if (selected != null) {
        onEmojiSelected(selected);
      }
    });
  }
}

class _ControlGroup extends StatelessWidget {
  const _ControlGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.softWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink, width: 1.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.ink, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpacityControl extends StatelessWidget {
  const _OpacityControl({
    required this.sliderKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key sliderKey;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ControlGroup(
      title: title,
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.ink,
                inactiveTrackColor: const Color(0xFFE5DCD3),
                thumbColor: AppColors.yellow,
                overlayColor: const Color(0x22FFD36B),
                valueIndicatorColor: AppColors.ink,
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                  elevation: 2,
                ),
              ),
              child: Slider(
                key: sliderKey,
                value: value,
                divisions: 10,
                label: '${(value * 100).round()}%',
                onChanged: onChanged,
              ),
            ),
          ),
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.softWhite,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.ink, width: 1.8),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(0.75, 0.75),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleControl extends StatelessWidget {
  const _ToggleControl({
    required this.toggleKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key toggleKey;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(1, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: value ? const Color(0xFFFEF3C7) : AppColors.softWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.ink, width: 1.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile.adaptive(
            key: toggleKey,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            secondary: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: value ? AppColors.yellow : AppColors.softWhite,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
              child: Icon(
                value
                    ? Icons.auto_awesome_rounded
                    : Icons.visibility_off_rounded,
                size: 16,
                color: AppColors.ink,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            activeTrackColor: AppColors.lime,
            activeThumbColor: AppColors.ink,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _ColorChoice {
  const _ColorChoice(this.name, this.color);

  final String name;
  final Color color;
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.controlKey,
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String controlKey;
  final String title;
  final Color selected;
  final List<_ColorChoice> options;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final isCustomSelected =
        !options.any((opt) => opt.color.toARGB32() == selected.toARGB32());

    return _ControlGroup(
      title: title,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final (index, option) in options.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  button: true,
                  selected: option.color == selected,
                  label: '$title: ${option.name}',
                  child: Tooltip(
                    message: option.name,
                    child: InkResponse(
                      key: Key('$controlKey-$index'),
                      radius: 24,
                      onTap: () => onSelected(option.color),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: option.color == selected ? 36 : 32,
                            height: option.color == selected ? 36 : 32,
                            decoration: BoxDecoration(
                              color: option.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.ink,
                                width: option.color == selected ? 2.5 : 1.8,
                              ),
                              boxShadow: option.color == selected
                                  ? const [
                                      BoxShadow(
                                        color: AppColors.ink,
                                        offset: Offset(1, 1),
                                        blurRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: option.color == selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color:
                                        option.color.computeLuminance() > 0.45
                                            ? Colors.black
                                            : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Semantics(
              button: true,
              selected: isCustomSelected,
              label: '$title: Tự chọn màu',
              child: Tooltip(
                message: 'Tự chọn màu',
                child: InkResponse(
                  key: Key('$controlKey-custom-picker'),
                  radius: 24,
                  onTap: () => _openCustomPicker(context),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: isCustomSelected ? 36 : 32,
                        height: isCustomSelected ? 36 : 32,
                        decoration: BoxDecoration(
                          color: isCustomSelected ? selected : null,
                          shape: BoxShape.circle,
                          gradient: isCustomSelected
                              ? null
                              : const SweepGradient(
                                  colors: [
                                    Color(0xFFFF0000),
                                    Color(0xFFFFFF00),
                                    Color(0xFF00FF00),
                                    Color(0xFF00FFFF),
                                    Color(0xFF0000FF),
                                    Color(0xFFFF00FF),
                                    Color(0xFFFF0000),
                                  ],
                                ),
                          border: Border.all(
                            color: AppColors.ink,
                            width: isCustomSelected ? 2.5 : 1.8,
                          ),
                          boxShadow: isCustomSelected
                              ? const [
                                  BoxShadow(
                                    color: AppColors.ink,
                                    offset: Offset(1, 1),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: isCustomSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: selected.computeLuminance() > 0.45
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : const Icon(
                                Icons.colorize_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCustomPicker(BuildContext context) {
    showDialog<Color>(
      context: context,
      builder: (dialogContext) => _CustomColorPickerDialog(
        title: title,
        initialColor: selected,
      ),
    ).then((color) {
      if (color != null) onSelected(color);
    });
  }
}

class _CustomColorPickerDialog extends StatefulWidget {
  const _CustomColorPickerDialog({
    required this.title,
    required this.initialColor,
  });

  final String title;
  final Color initialColor;

  @override
  State<_CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value.clamp(0.01, 1.0);
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  static const List<Color> _presetPalette = [
    Color(0xFFE53935), // Đỏ
    Color(0xFFE91E63), // Hồng đậm
    Color(0xFFF48FB1), // Hồng phấn
    Color(0xFF8E24AA), // Tím
    Color(0xFF5C6BC0), // Chàm
    Color(0xFF1E88E5), // Xanh dương
    Color(0xFF00ACC1), // Cyan
    Color(0xFF2E7D32), // Xanh lá đậm
    Color(0xFF81C784), // Xanh lá nhạt
    Color(0xFFFDD835), // Vàng
    Color(0xFFFB8C00), // Cam
    Color(0xFFF4511E), // Đỏ cam
    Color(0xFF8D6E63), // Nâu Capy
    Color(0xFF546E7A), // Xám xanh
    Color(0xFF212121), // Đen
    Color(0xFFFFFFFF), // Trắng
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    final hexString =
        '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    final isDark = currentColor.computeLuminance() < 0.5;

    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.ink, width: 2.4),
      ),
      backgroundColor: AppColors.softWhite,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.ink, width: 1.8),
            ),
            child: const Icon(
              Icons.colorize_rounded,
              color: AppColors.ink,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tự chọn ${widget.title}',
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.ink,
                    width: 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      offset: Offset(1.25, 1.25),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  hexString,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSliderSection(
                title: 'Tông màu (Hue)',
                valueText: '${_hue.round()}°',
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
                slider: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    trackHeight: 12,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                      elevation: 3,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    key: const Key('color-hue-slider'),
                    value: _hue,
                    min: 0.0,
                    max: 360.0,
                    onChanged: (val) => setState(() => _hue = val),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSliderSection(
                title: 'Độ đậm màu (Saturation)',
                valueText: '${(_saturation * 100).round()}%',
                gradient: LinearGradient(
                  colors: [
                    HSVColor.fromAHSV(1.0, _hue, 0.0, _value).toColor(),
                    HSVColor.fromAHSV(1.0, _hue, 1.0, _value).toColor(),
                  ],
                ),
                slider: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    trackHeight: 12,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                      elevation: 3,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    key: const Key('color-saturation-slider'),
                    value: _saturation,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => setState(() => _saturation = val),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSliderSection(
                title: 'Độ sáng (Brightness)',
                valueText: '${(_value * 100).round()}%',
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor(),
                  ],
                ),
                slider: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    trackHeight: 12,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                      elevation: 3,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    key: const Key('color-value-slider'),
                    value: _value,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => setState(() => _value = val),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Màu sắc gợi ý',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final color in _presetPalette)
                    InkWell(
                      onTap: () {
                        final hsv = HSVColor.fromColor(color);
                        setState(() {
                          _hue = hsv.hue;
                          _saturation = hsv.saturation;
                          _value = hsv.value.clamp(0.01, 1.0);
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox.square(
                        dimension: 44,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.ink,
                                width:
                                    color.toARGB32() == currentColor.toARGB32()
                                        ? 2.5
                                        : 1.5,
                              ),
                              boxShadow:
                                  color.toARGB32() == currentColor.toARGB32()
                                      ? const [
                                          BoxShadow(
                                            color: AppColors.ink,
                                            offset: Offset(0.75, 0.75),
                                            blurRadius: 0,
                                          ),
                                        ]
                                      : null,
                            ),
                            child: color.toARGB32() == currentColor.toARGB32()
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: color.computeLuminance() > 0.45
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: const BorderSide(color: AppColors.ink, width: 1.8),
          ),
          child: const Text(
            'Huỷ',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        FilledButton.icon(
          key: const Key('confirm-custom-color-button'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.mint, // Mint
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.ink, width: 2.0),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(currentColor),
          icon: const Icon(Icons.check_rounded, size: 18, color: AppColors.ink),
          label: const Text(
            'Chọn màu này',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSection({
    required String title,
    required String valueText,
    required Gradient gradient,
    required Widget slider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.ink, width: 1.2),
              ),
              child: Text(
                valueText,
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 24,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.ink,
              width: 1.8,
            ),
          ),
          child: slider,
        ),
      ],
    );
  }
}

class _ComparisonPreview extends StatelessWidget {
  const _ComparisonPreview({required this.style});

  final LabelVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('custom-label-preview'),
      label: 'So sánh mẫu mặc định và mẫu đang thiết kế',
      image: true,
      child: Row(
        children: [
          const Expanded(
            child: _PreviewPanel(
              panelKey: Key('before-style-preview'),
              title: 'MẪU GỐC',
              style: LabelVisualStyle.standard,
              isActive: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PreviewPanel(
              panelKey: const Key('after-style-preview'),
              title: 'CỦA BẠN',
              style: style,
              isActive: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.panelKey,
    required this.title,
    required this.style,
    required this.isActive,
  });

  final Key panelKey;
  final String title;
  final LabelVisualStyle style;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: panelKey,
      height: 138,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.ink,
          width: 2.0,
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(1.25, 1.25),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isActive) ...[
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isActive ? AppColors.ink : const Color(0xFF6B6B6B),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                    child: CustomPaint(painter: _PreviewPainter(style))),
                if (style.showDeerSticker)
                  Positioned(
                    right: 5,
                    top: 8,
                    child: Text(
                      style.effectiveStickerEmoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                if (style.showCookieIcon)
                  Positioned(
                    right: 3,
                    bottom: 8,
                    child: Text(
                      style.effectiveCornerIconEmoji,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.style);

  final LabelVisualStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.36,
      size.width * 0.24,
      size.height * 0.27,
    );
    final card = Rect.fromLTWH(
      size.width * 0.46,
      size.height * 0.22,
      size.width * 0.49,
      size.height * 0.58,
    );
    final badge = Rect.fromLTWH(card.left, card.top - 7, 24, 14);

    if (style.showBoundingBox) {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(3)),
          Paint()
            ..color = style.objectFillColor.withValues(
              alpha: style.objectFillOpacity,
            ),
        )
        ..drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(3)),
          Paint()
            ..color = style.objectBorderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
    }

    paintConnector(
      canvas,
      ConnectorPath(from: card.centerLeft, to: box.center),
      color: style.connectorColor,
      strokeWidth: style.connectorThickness.value,
      haloColor: style.connectorHaloColor,
      lineStyle: style.connectorLineStyle == ConnectorLineStyle.adaptive
          ? ConnectorLineStyle.solid
          : style.connectorLineStyle,
      arrowStyle: style.connectorArrowStyle,
      showHalo: style.showConnectorHalo,
    );

    final radius = switch (style.cornerStyle) {
      LabelCornerStyle.square => 0.0,
      LabelCornerStyle.soft => card.height * 0.22,
      LabelCornerStyle.round => card.height / 2,
    };
    final roundedCard = RRect.fromRectAndRadius(card, Radius.circular(radius));
    canvas
      ..drawRRect(
        roundedCard,
        Paint()..color = style.cardColor.withValues(alpha: style.cardOpacity),
      )
      ..drawRRect(
        roundedCard,
        Paint()
          ..color = style.borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.borderThickness.value,
      );

    final badgeRadius = switch (style.badgeShape) {
      LabelBadgeShape.square => 0.0,
      LabelBadgeShape.soft => badge.height * 0.25,
      LabelBadgeShape.pill => badge.height / 2,
    };
    final roundedBadge = RRect.fromRectAndRadius(
      badge,
      Radius.circular(badgeRadius),
    );
    canvas
      ..drawRRect(roundedBadge, Paint()..color = style.badgeColor)
      ..drawRRect(
        roundedBadge.deflate(style.badgeBorderThickness.value / 2),
        Paint()
          ..color = style.badgeBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.badgeBorderThickness.value,
      );
    _paintText(
      canvas,
      '01',
      Offset(badge.left + 6, badge.top + 2),
      7,
      style.badgeTextColor,
    );

    final fontSize = (size.width * 0.065).clamp(6.5, 9.0);
    _paintText(canvas, 'capy', Offset(card.left + 6, card.top + 7), fontSize,
        style.textColor);
    _paintText(
      canvas,
      'capybara',
      Offset(card.left + 6, card.top + 7 + fontSize * 1.35),
      fontSize * 0.85,
      style.meaningColor,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    painter
      ..paint(canvas, offset)
      ..dispose();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) =>
      oldDelegate.style != style;
}

const _textColors = [
  _ColorChoice('Nâu', Color(0xFF8F6E50)),
  _ColorChoice('Đen', Colors.black),
  _ColorChoice('Xanh navy', Color(0xFF24425C)),
  _ColorChoice('Xanh lá', Color(0xFF2E6B4F)),
  _ColorChoice('Tím', Color(0xFF6C4A8B)),
];
const _meaningColors = [
  _ColorChoice('Đỏ', Color(0xFFB00000)),
  _ColorChoice('Đen', Colors.black),
  _ColorChoice('Xanh dương', Color(0xFF1E5A88)),
  _ColorChoice('Xanh lá', Color(0xFF2E6B4F)),
  _ColorChoice('Tím', Color(0xFF6C4A8B)),
];
const _cardColors = [
  _ColorChoice('Kem', Color(0xFFFFFEFA)),
  _ColorChoice('Trắng', Colors.white),
  _ColorChoice('Hồng nhạt', Color(0xFFFFF1F3)),
  _ColorChoice('Xanh bạc hà', Color(0xFFEAF8EE)),
  _ColorChoice('Tím nhạt', Color(0xFFF5EEFF)),
];
const _borderColors = [
  _ColorChoice('Nâu', Color(0xFFD2A374)),
  _ColorChoice('Đen', Colors.black),
  _ColorChoice('Xanh lá', Color(0xFF3E7A45)),
  _ColorChoice('Xanh dương', Color(0xFF3C6E91)),
  _ColorChoice('Tím', Color(0xFF76538D)),
];
const _connectorColors = [
  _ColorChoice('Cam', Color(0xFFD85B24)),
  _ColorChoice('Đen', Colors.black),
  _ColorChoice('Xanh lá', Color(0xFF3E7A45)),
  _ColorChoice('Xanh dương', Color(0xFF3C6E91)),
  _ColorChoice('Tím', Color(0xFF76538D)),
];
