import 'package:flutter/material.dart';

import '../../../vocab_scan/domain/label_connector_geometry.dart';
import '../../../vocab_scan/presentation/label_connector_painter.dart';
import '../label_template_store.dart';
import '../label_visual_style.dart';

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
        side: const BorderSide(color: Color(0xFFE8D9C7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EditorHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
            sectionKey: const Key('section-bounding-box'),
            title: 'Khung nhận diện vật thể',
            subtitle: 'Viền và lớp highlight trên ảnh',
            icon: Icons.center_focus_strong_rounded,
            accent: const Color(0xFF77A96A),
            background: const Color(0xFFF0F8EC),
            children: [
              _ToggleControl(
                toggleKey: const Key('toggle-bounding-box'),
                title: 'Hiển thị bounding box',
                value: style.showBoundingBox,
                onChanged: (value) =>
                    onChanged(style.copyWith(showBoundingBox: value)),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: style.showBoundingBox ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !style.showBoundingBox,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ColorControl(
                        controlKey: 'bbox-border-color',
                        title: 'Màu khung',
                        selected: style.objectBorderColor,
                        options: _boundingBorderColors,
                        onSelected: (color) => onChanged(
                          style.copyWith(objectBorderColor: color),
                        ),
                      ),
                      _ColorControl(
                        controlKey: 'bbox-fill-color',
                        title: 'Màu nền highlight',
                        selected: style.objectFillColor,
                        options: _highlightColors,
                        onSelected: (color) => onChanged(
                          style.copyWith(objectFillColor: color),
                        ),
                      ),
                      _OpacityControl(
                        sliderKey: const Key('bbox-opacity-slider'),
                        title: 'Độ trong suốt highlight',
                        value: style.objectFillOpacity,
                        onChanged: (value) => onChanged(
                          style.copyWith(objectFillOpacity: value),
                        ),
                      ),
                    ],
                  ),
                ),
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
              _ChoiceControl(
                controlKey: 'sticker',
                title: 'Sticker',
                selected: style.sticker,
                options: const [
                  _ChoiceOption(LabelSticker.deer, 'Hươu', Icons.pets_rounded),
                  _ChoiceOption(
                    LabelSticker.capybara,
                    'Capybara',
                    Icons.cruelty_free_rounded,
                  ),
                  _ChoiceOption(LabelSticker.star, 'Ngôi sao', Icons.star),
                  _ChoiceOption(
                      LabelSticker.book, 'Quyển sách', Icons.menu_book),
                  _ChoiceOption(LabelSticker.none, 'Không dùng', Icons.block),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(sticker: value)),
              ),
              _ChoiceControl(
                controlKey: 'corner-icon',
                title: 'Icon góc label',
                selected: style.cornerIcon,
                options: const [
                  _ChoiceOption(
                    LabelCornerIcon.cookie,
                    'Bánh quy',
                    Icons.cookie_outlined,
                  ),
                  _ChoiceOption(
                    LabelCornerIcon.pin,
                    'Ghim',
                    Icons.push_pin_rounded,
                  ),
                  _ChoiceOption(
                    LabelCornerIcon.heart,
                    'Trái tim',
                    Icons.favorite_rounded,
                  ),
                  _ChoiceOption(
                      LabelCornerIcon.none, 'Không dùng', Icons.block),
                ],
                onSelected: (value) =>
                    onChanged(style.copyWith(cornerIcon: value)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            child: FilledButton.icon(
              key: const Key('save-label-template-button'),
              onPressed: _isSaving ? null : _saveTemplate,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_rounded),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu mẫu của tôi'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF6F9F43),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    final name = await _showNameDialog();
    if (name == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final templates = await widget.templateStore.save(
        name: name,
        style: widget.style,
      );
      if (!mounted) return;
      widget.onTemplatesChanged(templates);
      widget.onChanged(widget.style);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu và áp dụng mẫu “$name”')),
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

  Future<String?> _showNameDialog() async {
    var enteredName = '';
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.bookmark_rounded, color: Color(0xFF6F9F43)),
          title: const Text('Đặt tên cho mẫu'),
          content: TextField(
            key: const Key('label-template-name-field'),
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Tên mẫu',
              hintText: 'Ví dụ: Capy xanh bạc hà',
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => enteredName = value,
            onSubmitted: (value) {
              final name = value.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = 'Hãy nhập tên mẫu');
              } else {
                Navigator.of(dialogContext).pop(name);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              key: const Key('confirm-save-label-template'),
              onPressed: () {
                final name = enteredName.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorText = 'Hãy nhập tên mẫu');
                } else {
                  Navigator.of(dialogContext).pop(name);
                }
              },
              child: const Text('Lưu & áp dụng'),
            ),
          ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFEAF5DE),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.palette_rounded,
                color: Color(0xFF5F8E36),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Góc sáng tạo của bạn',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3C2A21),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Chạm từng thẻ để chỉnh, preview sẽ đổi ngay.',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF66574E),
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
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withValues(alpha: 0.28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: sectionKey,
            initiallyExpanded: initiallyExpanded,
            maintainState: true,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            expandedAlignment: Alignment.centerLeft,
            tilePadding: const EdgeInsets.fromLTRB(12, 4, 10, 4),
            childrenPadding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            leading: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox.square(
                dimension: 42,
                child: Icon(icon, size: 21, color: accent),
              ),
            ),
            title: Text(
              title,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3C2A21),
              ),
            ),
            subtitle: Text(
              subtitle,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11.5,
                height: 1.25,
                color: Color(0xFF6B5C53),
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
  const _ChoiceOption(this.value, this.label, [this.icon]);

  final T value;
  final String label;
  final IconData? icon;
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: const Color(0xFFEAF6DF),
              side: BorderSide(
                color: option.value == selected
                    ? const Color(0xFF629E2A)
                    : const Color(0xFFD8CABC),
              ),
              onSelected: (_) => onSelected(option.value),
            ),
        ],
      ),
    );
  }
}

class _ControlGroup extends StatelessWidget {
  const _ControlGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3C2A21),
              ),
            ),
            const SizedBox(height: 6),
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
            child: Slider(
              key: sliderKey,
              value: value,
              divisions: 10,
              label: '${(value * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5F5149),
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
    return SwitchListTile.adaptive(
      key: toggleKey,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3C2A21),
        ),
      ),
      value: value,
      onChanged: onChanged,
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
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, option) in options.indexed)
            Semantics(
              button: true,
              selected: option.color == selected,
              label: '$title: ${option.name}',
              child: InkResponse(
                key: Key('$controlKey-$index'),
                radius: 24,
                onTap: () => onSelected(option.color),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: option.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: option.color == selected
                              ? const Color(0xFF629E2A)
                              : const Color(0xFFB8AA9D),
                          width: option.color == selected ? 3 : 1,
                        ),
                      ),
                      child: option.color == selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: option.color.computeLuminance() > 0.45
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          // Nút tự chọn màu (Lăn màu tự do)
          Semantics(
            button: true,
            selected: isCustomSelected,
            label: '$title: Tự chọn màu',
            child: InkResponse(
              key: Key('$controlKey-custom-picker'),
              radius: 24,
              onTap: () => _openCustomPicker(context),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 28,
                    height: 28,
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
                            ? const Color(0xFF629E2A)
                            : const Color(0xFFB8AA9D),
                        width: isCustomSelected ? 3 : 1.5,
                      ),
                      boxShadow: isCustomSelected
                          ? [
                              BoxShadow(
                                color: selected.withValues(alpha: 0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: isCustomSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: selected.computeLuminance() > 0.45
                                ? Colors.black
                                : Colors.white,
                          )
                        : const Icon(
                            Icons.colorize_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Khung preview màu trực tiếp
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

              // Hue slider (Thanh lăn dải màu cầu vồng)
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

              // Saturation slider (Độ đậm màu)
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

              // Brightness slider (Độ sáng tối)
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

              // Bảng màu gợi ý nhanh
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
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.toARGB32() == currentColor.toARGB32()
                                ? const Color(0xFF629E2A)
                                : const Color(0xFFD4C5B5),
                            width: color.toARGB32() == currentColor.toARGB32()
                                ? 2.5
                                : 1,
                          ),
                        ),
                        child: color.toARGB32() == currentColor.toARGB32()
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: color.computeLuminance() > 0.45
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2ECE5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: _PreviewPanel(
                panelKey: Key('before-style-preview'),
                title: 'Trước',
                style: LabelVisualStyle.standard,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PreviewPanel(
                panelKey: const Key('after-style-preview'),
                title: 'Sau',
                style: style,
              ),
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
  });

  final Key panelKey;
  final String title;
  final LabelVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: panelKey,
      height: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDED4CA)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5F5149),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                    child: CustomPaint(painter: _PreviewPainter(style))),
                if (style.sticker != LabelSticker.none)
                  Positioned(
                    right: 5,
                    top: 10,
                    child: Icon(
                      _stickerIcon(style.sticker),
                      size: 15,
                      color: const Color(0xFF8A4B2A),
                    ),
                  ),
                if (style.cornerIcon != LabelCornerIcon.none)
                  Positioned(
                    right: 2,
                    bottom: 10,
                    child: Icon(
                      _cornerIcon(style.cornerIcon),
                      size: 14,
                      color: const Color(0xFFA85A40),
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

IconData _stickerIcon(LabelSticker sticker) => switch (sticker) {
      LabelSticker.deer => Icons.pets_rounded,
      LabelSticker.capybara => Icons.cruelty_free_rounded,
      LabelSticker.star => Icons.star_rounded,
      LabelSticker.book => Icons.menu_book_rounded,
      LabelSticker.none => Icons.block,
    };

IconData _cornerIcon(LabelCornerIcon icon) => switch (icon) {
      LabelCornerIcon.cookie => Icons.cookie_outlined,
      LabelCornerIcon.pin => Icons.push_pin_rounded,
      LabelCornerIcon.heart => Icons.favorite_rounded,
      LabelCornerIcon.none => Icons.block,
    };

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
const _boundingBorderColors = [
  _ColorChoice('Cam', Colors.deepOrange),
  _ColorChoice('Đen', Colors.black),
  _ColorChoice('Xanh lá', Color(0xFF2E7D32)),
  _ColorChoice('Xanh dương', Color(0xFF1565C0)),
  _ColorChoice('Tím', Color(0xFF6A1B9A)),
];
const _highlightColors = [
  _ColorChoice('Vàng', Colors.amber),
  _ColorChoice('Trắng', Colors.white),
  _ColorChoice('Xanh lá', Color(0xFF81C784)),
  _ColorChoice('Xanh dương', Color(0xFF64B5F6)),
  _ColorChoice('Hồng', Color(0xFFF48FB1)),
];
