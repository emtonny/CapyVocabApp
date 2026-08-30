import 'package:flutter/material.dart';

import '../../../vocab_scan/domain/label_connector_geometry.dart';
import '../../../vocab_scan/presentation/label_connector_painter.dart';
import '../label_template_store.dart';
import '../label_visual_style.dart';
import 'emoji_picker_dialog.dart';

const _ink = Color(0xFF3F3028);
const _mutedInk = Color(0xFF6E5C51);
const _studioGreen = Color(0xFF6D9F3D);
const _studioGreenDark = Color(0xFF3F6820);

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
    return Material(
      color: const Color(0xFFFFFBF5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE8D9C7), width: 1.5),
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
                accent: const Color(0xFFE58A7B),
                background: const Color(0xFFFFF2EE),
                initiallyExpanded: true,
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
                accent: const Color(0xFFE3A23B),
                background: const Color(0xFFFFF6DF),
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
                accent: const Color(0xFF6D9DC5),
                background: const Color(0xFFEEF7FF),
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
                icon: Icons.auto_awesome_outlined,
                accent: const Color(0xFFAE79B9),
                background: const Color(0xFFF8EFFA),
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
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bookmark_add_rounded,
                  color: Color(0xFF4A7227),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lưu mẫu thiết kế',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    Text(
                      'Đặt tên và chọn icon cho mẫu',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11.5,
                        color: _mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: _mutedInk),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(dialogContext).pop(),
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
                  // Hàng chứa Box chọn Icon và Box đặt tên
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
                              fontWeight: FontWeight.w800,
                              color: _mutedInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('template-icon-picker-button'),
                              borderRadius: BorderRadius.circular(16),
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
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFDFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2D4C6),
                                    width: 1.4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
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
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F4DC),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          size: 9,
                                          color: Color(0xFF4A7227),
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
                                fontWeight: FontWeight.w800,
                                color: _mutedInk,
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
                                color: _ink,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ví dụ: Capy bạc hà...',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: Color(0xFF9E8E83),
                                ),
                                errorText: errorText,
                                filled: true,
                                fillColor: const Color(0xFFFFFDFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                counterStyle: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 10,
                                  color: _mutedInk,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2D4C6),
                                    width: 1.2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2D4C6),
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6D9F3D),
                                    width: 2,
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
                      color: const Color(0xFFF9F5F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEFE6DC)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Thẻ xem trước:',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: _mutedInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4DC),
                            borderRadius: BorderRadius.circular(6),
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
                              fontWeight: FontWeight.bold,
                              color: enteredName.trim().isEmpty
                                  ? const Color(0xFF9E8E83)
                                  : _ink,
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(color: Color(0xFFE2D4C6)),
                          ),
                          child: const Text(
                            'Huỷ',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _mutedInk,
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
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text(
                            'Lưu & áp dụng',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7227),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 16),
      child: Semantics(
        button: true,
        label: isSaving ? 'Đang lưu mẫu' : 'Lưu mẫu của tôi',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _studioGreenDark,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: FilledButton.icon(
              key: const Key('save-label-template-button'),
              onPressed: onPressed,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bookmark_add_rounded),
              label: Text(isSaving ? 'Đang cất mẫu...' : 'Lưu mẫu của tôi'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: _studioGreen,
                disabledBackgroundColor: const Color(0xFFA8BE91),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFDDA8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x249B6B43),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SizedBox.square(
                  dimension: 46,
                  child: Icon(
                    Icons.palette_rounded,
                    size: 24,
                    color: Color(0xFF9A5E2E),
                  ),
                ),
              ),
              Positioned(
                right: -3,
                top: -4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFF85A1),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 18,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Thiết kế theo sở thích',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
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
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent.withValues(alpha: 0.34), width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: sectionKey,
            initiallyExpanded: initiallyExpanded,
            maintainState: true,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            expandedAlignment: Alignment.centerLeft,
            tilePadding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
            childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(icon, size: 22, color: accent),
              ),
            ),
            title: Text(
              title,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            subtitle: Text(
              subtitle,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                height: 1.3,
                color: _mutedInk,
              ),
            ),
            iconColor: accent,
            collapsedIconColor: const Color(0xFF75655B),
            children: children,
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
              avatar: option.icon == null ? null : Icon(option.icon, size: 17),
              label: Text(option.label),
              labelStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              selectedColor: const Color(0xFFE8F4DC),
              backgroundColor: const Color(0xFFFFFCF8),
              checkmarkColor: _studioGreenDark,
              elevation: option.value == selected ? 2 : 0,
              pressElevation: 1,
              shadowColor: _studioGreen.withValues(alpha: 0.28),
              surfaceTintColor: Colors.transparent,
              side: BorderSide(
                color: option.value == selected
                    ? _studioGreen
                    : const Color(0xFFD8CABC),
                width: option.value == selected ? 1.8 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openEmojiDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2D4C6), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E7DC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: hasEmoji
                      ? Text(
                          currentEmoji,
                          style: const TextStyle(fontSize: 22),
                        )
                      : const Icon(
                          Icons.block_rounded,
                          size: 20,
                          color: Color(0xFF8A4B2A),
                        ),
                ),
                const SizedBox(width: 12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chạm để mở bảng emoji tìm kiếm',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11.5,
                          color: _mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF8A7365),
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
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE5D8CA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x109B6B43),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: Color(0xFFD66A87),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
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
                activeTrackColor: _studioGreen,
                inactiveTrackColor: const Color(0xFFD9E3CE),
                thumbColor: _studioGreenDark,
                overlayColor: _studioGreen.withValues(alpha: 0.15),
                valueIndicatorColor: _studioGreenDark,
                trackHeight: 5,
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
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCCFC1)),
            ),
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _ink,
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
      child: Material(
        color: value
            ? const Color(0xFFF4FAEE)
            : Colors.white.withValues(alpha: 0.82),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: value ? _studioGreen : const Color(0xFFE5D8CA),
            width: value ? 1.5 : 1,
          ),
        ),
        elevation: value ? 2 : 0,
        shadowColor: _studioGreen.withValues(alpha: 0.22),
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile.adaptive(
          key: toggleKey,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          secondary: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFE4F2D7) : const Color(0xFFF4ECE4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              value ? Icons.auto_awesome_rounded : Icons.visibility_off_rounded,
              size: 18,
              color: value ? _studioGreenDark : _mutedInk,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          activeTrackColor: _studioGreen,
          value: value,
          onChanged: onChanged,
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
                                color: option.color == selected
                                    ? _studioGreenDark
                                    : const Color(0xFFB8AA9D),
                                width: option.color == selected ? 3 : 1,
                              ),
                              boxShadow: option.color == selected
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x306D9F3D),
                                        blurRadius: 7,
                                        offset: Offset(0, 2),
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
                            color: isCustomSelected
                                ? _studioGreenDark
                                : const Color(0xFFB8AA9D),
                            width: isCustomSelected ? 3 : 1.5,
                          ),
                          boxShadow: isCustomSelected
                              ? [
                                  BoxShadow(
                                    color: selected.withValues(alpha: 0.35),
                                    blurRadius: 7,
                                    offset: const Offset(0, 2),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EAE0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.colorize_rounded,
              color: Color(0xFF8F6E50),
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
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C2A21),
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
                height: 56,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD4C5B5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  hexString,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white : Colors.black87,
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
                      elevation: 4,
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
                      elevation: 4,
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
                      elevation: 4,
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
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B5C53),
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
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    color.toARGB32() == currentColor.toARGB32()
                                        ? _studioGreen
                                        : const Color(0xFFD4C5B5),
                                width:
                                    color.toARGB32() == currentColor.toARGB32()
                                        ? 2.5
                                        : 1,
                              ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton.icon(
          key: const Key('confirm-custom-color-button'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6F9F43),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(currentColor),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Chọn màu này'),
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
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A3B32),
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7A6B62),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0x33000000),
                  width: 0.8,
                ),
              ),
            ),
            slider,
          ],
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
      label: 'So sánh mẫu mặc định và mẫu đang thiết kế',
      image: true,
      child: Container(
        key: const Key('custom-label-preview'),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF4EADF), Color(0xFFFFF7ED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4D2C0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 32,
                    child: Icon(
                      Icons.visibility_rounded,
                      size: 17,
                      color: _studioGreenDark,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xem trước trực tiếp',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'Mỗi lựa chọn sẽ hiện ngay ở khung bên phải',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          height: 1.3,
                          color: _mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F4DC),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 9.5,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w900,
                        color: _studioGreenDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: _PreviewPanel(
                    panelKey: Key('before-style-preview'),
                    title: 'Mẫu gốc',
                    style: LabelVisualStyle.standard,
                    isActive: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PreviewPanel(
                    panelKey: const Key('after-style-preview'),
                    title: 'Của bạn',
                    style: style,
                    isActive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? _studioGreen : const Color(0xFFDED4CA),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? const [
                BoxShadow(
                  color: Color(0x246D9F3D),
                  blurRadius: 9,
                  offset: Offset(0, 3),
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
                    color: _studioGreenDark,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: isActive ? _studioGreenDark : _mutedInk,
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
