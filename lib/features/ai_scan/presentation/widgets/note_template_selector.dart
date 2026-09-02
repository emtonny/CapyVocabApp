import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
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
  NoteLabelTemplate? _previousTemplate;

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
        // Section Header with Title and Pin Icon
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'CHỌN MẪU NOTE GHIM',
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.push_pin_rounded,
              size: 16,
              color: Color(0xFF9333EA),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Base 2 cards on top + 1 full-width card below (Exact match with reference image)
        // If saved templates exist: Responsive Grid
        if (_savedTemplates.isEmpty) ...[
          Row(
            children: [
              Expanded(
                child: _TemplateCard(
                  cardKey: const Key('label-template-standard'),
                  title: _standardTemplateOption.title,
                  subtitle: _standardTemplateOption.subtitle,
                  icon: _standardTemplateOption.icon,
                  cardColor: _standardTemplateOption.cardColor,
                  iconBgColor: _standardTemplateOption.iconBgColor,
                  iconColor: _standardTemplateOption.iconColor,
                  isCompact: true,
                  isSelected:
                      widget.selectedTemplate == NoteLabelTemplate.standard &&
                          !_isEditorOpen,
                  onTap: () {
                    setState(() => _isEditorOpen = false);
                    widget.onTemplateChanged(NoteLabelTemplate.standard);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TemplateCard(
                  cardKey: const Key('label-template-minimal'),
                  title: _minimalTemplateOption.title,
                  subtitle: _minimalTemplateOption.subtitle,
                  icon: _minimalTemplateOption.icon,
                  cardColor: _minimalTemplateOption.cardColor,
                  iconBgColor: _minimalTemplateOption.iconBgColor,
                  iconColor: _minimalTemplateOption.iconColor,
                  isCompact: true,
                  isSelected:
                      widget.selectedTemplate == NoteLabelTemplate.minimal &&
                          !_isEditorOpen,
                  onTap: () {
                    setState(() => _isEditorOpen = false);
                    widget.onTemplateChanged(NoteLabelTemplate.minimal);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TemplateCard(
            cardKey: const Key('label-template-custom'),
            title: _customTemplateOption.title,
            subtitle: !widget.isPro && _savedTemplates.isNotEmpty
                ? 'Thêm mẫu với Pro'
                : _customTemplateOption.subtitle,
            icon: !widget.isPro && _savedTemplates.isNotEmpty
                ? Icons.workspace_premium_rounded
                : _customTemplateOption.icon,
            cardColor: _customTemplateOption.cardColor,
            iconBgColor: _customTemplateOption.iconBgColor,
            iconColor: _customTemplateOption.iconColor,
            isCompact: false,
            isSelected: _isEditorOpen,
            onTap: _openCustomEditor,
          ),
        ] else ...[
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _baseTemplateOptions.length + _savedTemplates.length + 1,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              if (index < _baseTemplateOptions.length) {
                final option = _baseTemplateOptions[index];
                return _TemplateCard(
                  cardKey: Key('label-template-${option.template.name}'),
                  title: option.title,
                  subtitle: option.subtitle,
                  icon: option.icon,
                  cardColor: option.cardColor,
                  iconBgColor: option.iconBgColor,
                  iconColor: option.iconColor,
                  isCompact: true,
                  isSelected: option.template == widget.selectedTemplate &&
                      !_isEditorOpen,
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
                final isSelected =
                    savedIndex == selectedSavedIndex && !_isEditorOpen;
                return _TemplateCard(
                  cardKey: Key('saved-label-template-$savedIndex'),
                  title: template.name,
                  subtitle: 'Mẫu đã lưu (Giữ để xoá)',
                  icon: Icons.bookmark_rounded,
                  emoji: template.effectiveEmoji,
                  cardColor: const Color(0xFFFEF3C7),
                  iconBgColor: _savedTemplateAccent(template.style),
                  iconColor: AppColors.ink,
                  isCompact: true,
                  isSelected: isSelected,
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
                cardColor: option.cardColor,
                iconBgColor: option.iconBgColor,
                iconColor: option.iconColor,
                isCompact: true,
                isSelected: _isEditorOpen,
                onTap: _openCustomEditor,
              );
            },
          ),
        ],

        // Expandable Custom Style Editor
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: widget.selectedTemplate == NoteLabelTemplate.custom &&
                  _isEditorOpen
              ? Padding(
                  key: const Key('custom-label-editor'),
                  padding: const EdgeInsets.only(top: 14),
                  child: CustomLabelStyleEditor(
                    style: widget.customStyle,
                    onChanged: widget.onCustomStyleChanged,
                    templateStore: widget.templateStore,
                    onTemplatesChanged: (templates) {
                      setState(() {
                        _savedTemplates = templates;
                        _isEditorOpen = false;
                      });
                      widget.onTemplateChanged(NoteLabelTemplate.custom);
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
    setState(() {
      _isEditorOpen = !_isEditorOpen;
      if (_isEditorOpen) {
        _previousTemplate = widget.selectedTemplate;
        widget.onTemplateChanged(NoteLabelTemplate.custom);
      } else {
        widget.onTemplateChanged(_previousTemplate ?? NoteLabelTemplate.standard);
      }
    });
  }

  Future<void> _confirmDeleteTemplate(SavedLabelTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.softWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.ink, width: 2.8),
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
              foregroundColor: Colors.white,
              minimumSize: const Size(88, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.ink, width: 2.4),
              ),
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
        backgroundColor: AppColors.softWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.ink, width: 2.8),
        ),
        actionsOverflowButtonSpacing: 8,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        icon: const Icon(Icons.workspace_premium_rounded,
            color: Color(0xFFF5A623)),
        title: const Text('Bạn đã dùng mẫu miễn phí'),
        content: const Text(
          'Gói Free lưu được 1 mẫu tự thiết kế. Nâng cấp Pro để tạo thêm nhiều mẫu phong cách riêng.',
        ),
        actions: [
          if (widget.onUpgradeRequested != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Để sau'),
            ),
          FilledButton.icon(
            key: const Key('upgrade-label-template-pro-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.yellow,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(120, 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.ink, width: 2.4),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext)
                .pop(widget.onUpgradeRequested != null),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
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
  const _TemplateOption({
    required this.template,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cardColor,
    required this.iconBgColor,
    required this.iconColor,
  });

  final NoteLabelTemplate template;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  final Color iconBgColor;
  final Color iconColor;
}

const _standardTemplateOption = _TemplateOption(
  template: NoteLabelTemplate.standard,
  title: 'MẶC ĐỊNH',
  subtitle: 'Phong cách Capy hiện ...',
  icon: Icons.push_pin_rounded,
  cardColor: Color(0xFFFFF0ED),
  iconBgColor: Color(0xFFFDA4AF),
  iconColor: Color(0xFF831843),
);

const _minimalTemplateOption = _TemplateOption(
  template: NoteLabelTemplate.minimal,
  title: 'TỐI GIẢN',
  subtitle: 'Đen trắng, thật gọn',
  icon: Icons.reorder_rounded,
  cardColor: Color(0xFFE0F2FE),
  iconBgColor: Color(0xFF93C5FD),
  iconColor: Color(0xFF1E3A8A),
);

const _customTemplateOption = _TemplateOption(
  template: NoteLabelTemplate.custom,
  title: 'TỰ THIẾT KẾ',
  subtitle: 'Tạo và lưu phong cách riêng',
  icon: Icons.palette_rounded,
  cardColor: Color(0xFFDDD6FE),
  iconBgColor: Color(0xFFEDE9FE),
  iconColor: Color(0xFF581C87),
);

const _baseTemplateOptions = [
  _standardTemplateOption,
  _minimalTemplateOption,
];

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.cardKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.cardColor,
    required this.iconBgColor,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
    this.emoji,
    this.onLongPress,
  });

  final Key cardKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color cardColor;
  final Color iconBgColor;
  final Color iconColor;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;
  final String? emoji;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = isCompact ? 28.0 : 36.0;
    final checkmarkSize = isCompact ? 20.0 : 24.0;
    final checkIconSize = isCompact ? 13.0 : 16.0;
    final hPadding = isCompact ? (isSelected ? 4.0 : 6.0) : 10.0;
    final vPadding = isCompact ? 5.0 : 8.0;

    // Inner Card Content
    Widget cardContent = Container(
      constraints: BoxConstraints(minHeight: isCompact ? 56 : 62),
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSelected ? 9 : 12),
        border: Border.all(
          color: AppColors.ink,
          width: isSelected ? 1.6 : 2.0,
        ),
      ),
      child: Row(
        children: [
          // Left Icon Box
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.ink, width: 1.6),
            ),
            child: (emoji != null && emoji!.isNotEmpty)
                ? Text(emoji!, style: TextStyle(fontSize: isCompact ? 14 : 17))
                : (icon == Icons.reorder_rounded)
                    ? _ThreeBarsIcon(
                        color: AppColors.ink,
                        width: isCompact ? 12 : 15,
                      )
                    : Icon(icon, size: isCompact ? 16 : 19, color: iconColor),
          ),
          SizedBox(width: isCompact ? 4 : 8),

          // Title & Subtitle Column
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
                    fontSize: isCompact ? 12.0 : 13.0,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: isCompact ? 9.5 : 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3A3A3A),
                  ),
                ),
              ],
            ),
          ),

          // Right Checkmark Box (When Selected)
          if (isSelected) ...[
            SizedBox(width: isCompact ? 4 : 8),
            Container(
              width: checkmarkSize,
              height: checkmarkSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lime, // Neon Lime Green
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.ink, width: 1.8),
              ),
              child: Icon(
                Icons.check_rounded,
                size: checkIconSize,
                color: AppColors.ink,
                weight: 800,
              ),
            ),
          ],
        ],
      ),
    );

    // If Selected, wrap with the Signature Outer Yellow Neo-Brutalist Frame
    Widget outerWrapper;
    if (isSelected) {
      outerWrapper = Container(
        decoration: BoxDecoration(
          color: AppColors.yellow, // Vibrant Yellow Frame
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.ink, width: 2.4),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: EdgeInsets.all(isCompact ? 2.5 : 3.5),
        child: cardContent,
      );
    } else {
      outerWrapper = Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: cardContent,
      );
    }

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
          borderRadius: BorderRadius.circular(10),
          child: outerWrapper,
        ),
      ),
    );
  }
}

/// Custom 3 Horizontal Bars icon for Minimal template
class _ThreeBarsIcon extends StatelessWidget {
  const _ThreeBarsIcon({
    this.color = AppColors.ink,
    this.width = 16.0,
  });

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: 2.2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2.5),
        Container(
          width: width,
          height: 2.2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2.5),
        Container(
          width: width,
          height: 2.2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

Color _savedTemplateAccent(LabelVisualStyle style) {
  final color = style.borderColor;
  return color.computeLuminance() > 0.78 ? const Color(0xFF8F6E50) : color;
}
