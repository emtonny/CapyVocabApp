import 'package:flutter/material.dart';

import '../label_template_store.dart';
import '../label_visual_style.dart';
import 'custom_label_style_editor.dart';

class NoteTemplateSelector extends StatefulWidget {
  const NoteTemplateSelector({
    required this.selectedTemplate,
    required this.customStyle,
    required this.onTemplateChanged,
    required this.onCustomStyleChanged,
    this.templateStore = const LabelTemplateStore(),
    this.isPro = false,
    this.onUpgradeRequested,
    super.key,
  });

  final NoteLabelTemplate selectedTemplate;
  final LabelVisualStyle customStyle;
  final ValueChanged<NoteLabelTemplate> onTemplateChanged;
  final ValueChanged<LabelVisualStyle> onCustomStyleChanged;
  final LabelTemplateStore templateStore;
  final bool isPro;
  final VoidCallback? onUpgradeRequested;

  @override
  State<NoteTemplateSelector> createState() => _NoteTemplateSelectorState();
}

class _NoteTemplateSelectorState extends State<NoteTemplateSelector> {
  List<SavedLabelTemplate> _savedTemplates = const [];
  late bool _isEditorOpen;

  @override
  void initState() {
    super.initState();
    _isEditorOpen = false;
    _loadSavedTemplates();
  }

  @override
  void didUpdateWidget(covariant NoteTemplateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTemplate != NoteLabelTemplate.custom && _isEditorOpen) {
      _isEditorOpen = false;
    }
  }

  Future<void> _loadSavedTemplates() async {
    try {
      final templates = await widget.templateStore.load();
      if (!mounted) return;
      setState(() {
        _savedTemplates = templates;
      });
    } catch (_) {
      // Built-in templates remain usable when local preferences are unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSavedIndex =
        widget.selectedTemplate == NoteLabelTemplate.custom
            ? _savedTemplates.lastIndexWhere(
                (template) => template.style == widget.customStyle,
              )
            : -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Text(
              'CHỌN MẪU NOTE GHIM',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF76675E),
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(width: 5),
            Icon(
              Icons.push_pin_rounded,
              size: 15,
              color: Color(0xFF8F6E50),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _baseTemplateOptions.length + _savedTemplates.length + 1,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 64,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index < _baseTemplateOptions.length) {
              final option = _baseTemplateOptions[index];
              return _TemplateCard(
                cardKey: Key('label-template-${option.template.name}'),
                title: option.title,
                subtitle: option.subtitle,
                icon: option.icon,
                color: option.color,
                isSelected: option.template == widget.selectedTemplate && !_isEditorOpen,
                onTap: () {
                  setState(() => _isEditorOpen = false);
                  widget.onTemplateChanged(option.template);
                },
              );
            }

            final savedStartIndex = _baseTemplateOptions.length;
            final customIndex = savedStartIndex + _savedTemplates.length;
            if (index < customIndex) {
              final savedIndex = index - savedStartIndex;
              final template = _savedTemplates[savedIndex];
              return _TemplateCard(
                cardKey: Key('saved-label-template-$savedIndex'),
                title: template.name,
                subtitle: 'Mẫu đã lưu (Giữ để xoá)',
                icon: Icons.bookmark_rounded,
                emoji: template.effectiveEmoji,
                color: _savedTemplateAccent(template.style),
                isSelected: savedIndex == selectedSavedIndex && !_isEditorOpen,
                onTap: () {
                  setState(() => _isEditorOpen = false);
                  widget.onCustomStyleChanged(template.style);
                  widget.onTemplateChanged(NoteLabelTemplate.custom);
                },
                onLongPress: () => _confirmDeleteTemplate(template),
              );
            }

            const option = _customTemplateOption;
            return _TemplateCard(
              cardKey: Key('label-template-${option.template.name}'),
              title: option.title,
              subtitle: !widget.isPro && _savedTemplates.isNotEmpty
                  ? 'Thêm mẫu với Pro'
                  : option.subtitle,
              icon: !widget.isPro && _savedTemplates.isNotEmpty
                  ? Icons.workspace_premium_rounded
                  : option.icon,
              color: !widget.isPro && _savedTemplates.isNotEmpty
                  ? const Color(0xFFF5A623)
                  : option.color,
              isSelected: widget.selectedTemplate == NoteLabelTemplate.custom &&
                  _isEditorOpen,
              onTap: _openCustomEditor,
            );
          },
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: widget.selectedTemplate == NoteLabelTemplate.custom &&
                  _isEditorOpen
              ? Padding(
                  key: const Key('custom-label-editor'),
                  padding: const EdgeInsets.only(top: 12),
                  child: CustomLabelStyleEditor(
                    style: widget.customStyle,
                    onChanged: widget.onCustomStyleChanged,
                    templateStore: widget.templateStore,
                    onTemplatesChanged: (templates) {
                      setState(() {
                        _savedTemplates = templates;
                        _isEditorOpen = false;
                      });
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _openCustomEditor() {
    if (!widget.isPro && _savedTemplates.isNotEmpty) {
      _showFreeTemplateLimit();
      return;
    }
    setState(() => _isEditorOpen = !_isEditorOpen);
    if (_isEditorOpen) {
      widget.onTemplateChanged(NoteLabelTemplate.custom);
    }
  }

  Future<void> _confirmDeleteTemplate(SavedLabelTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        icon: const Icon(Icons.delete_outline_rounded,
            color: Color(0xFFE53935), size: 28),
        title: const Text('Xoá mẫu đã lưu?'),
        content: Text('Bạn có chắc muốn xoá mẫu “${template.name}” không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updated = await widget.templateStore.delete(template.name);
      if (!mounted) return;
      setState(() => _savedTemplates = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xoá mẫu “${template.name}”')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xoá mẫu. Vui lòng thử lại.')),
        );
      }
    }
  }

  Future<void> _showFreeTemplateLimit() async {
    final wantsUpgrade = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('label-template-pro-limit-dialog'),
        icon: const Icon(Icons.workspace_premium_rounded,
            color: Color(0xFFF5A623)),
        title: const Text('Bạn đã dùng mẫu miễn phí'),
        content: const Text(
          'Gói Free lưu được 1 mẫu tự thiết kế. Nâng cấp Pro để tạo thêm nhiều mẫu phong cách riêng.',
        ),
        actions: [
          if (widget.onUpgradeRequested != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Để sau'),
            ),
          FilledButton.icon(
            key: const Key('upgrade-label-template-pro-button'),
            onPressed: () => Navigator.of(dialogContext)
                .pop(widget.onUpgradeRequested != null),
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(
              widget.onUpgradeRequested == null ? 'Đã hiểu' : 'Nâng cấp Pro',
            ),
          ),
        ],
      ),
    );
    if (wantsUpgrade == true && mounted) widget.onUpgradeRequested?.call();
  }
}

class _TemplateOption {
  const _TemplateOption(
    this.template,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
  );

  final NoteLabelTemplate template;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _baseTemplateOptions = [
  _TemplateOption(
    NoteLabelTemplate.standard,
    'Mặc định',
    'Phong cách Capy hiện tại',
    Icons.push_pin_rounded,
    Color(0xFFE57373),
  ),
  _TemplateOption(
    NoteLabelTemplate.minimal,
    'Tối giản',
    'Đen trắng, thật gọn',
    Icons.notes_rounded,
    Color(0xFF3C6E91),
  ),
];

const _customTemplateOption = _TemplateOption(
  NoteLabelTemplate.custom,
  'Tự thiết kế',
  'Tạo và lưu phong cách riêng',
  Icons.palette_outlined,
  Color(0xFF8A4F9E),
);

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.cardKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.emoji,
    this.onLongPress,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final String? emoji;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Mẫu $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: cardKey,
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFF9F2)
                  : const Color(0xFFFAF6F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF629E2A)
                    : const Color(0xFFE0D3C3),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x33629E2A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: (emoji != null && emoji!.isNotEmpty)
                      ? Text(emoji!, style: const TextStyle(fontSize: 20))
                      : Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF3C2A21)
                              : const Color(0xFF5F5149),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10.5,
                          color: Color(0xFF74655C),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 19,
                    color: Color(0xFF629E2A),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _savedTemplateAccent(LabelVisualStyle style) {
  final color = style.borderColor;
  return color.computeLuminance() > 0.78 ? const Color(0xFF8F6E50) : color;
}
