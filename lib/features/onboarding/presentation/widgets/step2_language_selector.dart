import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/language_country_option.dart';
import '../providers/onboarding_provider.dart';

class Step2LanguageSelector extends ConsumerWidget {
  const Step2LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final interfaceOption = languageCountryByLocale(state.data.interfaceLocale);
    final learningOption = languageCountryByLocale(state.data.learningLocale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Chọn ngôn ngữ của bạn 🌏',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
            fontFamily: 'Fredoka',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Bạn có thể tìm theo tên quốc gia hoặc ngôn ngữ.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.mutedInk,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 18),
        _LanguageSelectorCard(
          controlKey: 'interface-language',
          title: 'Ngôn ngữ giao diện',
          subtitle: 'Ngôn ngữ dùng cho menu và hướng dẫn',
          icon: Icons.translate_rounded,
          badgeColor: const Color(0xFFBAE6FD),
          option: interfaceOption,
          errorText: state.fieldErrors['interfaceLocale'],
          enabled: !state.isBusy,
          onSelected: notifier.updateInterfaceLocale,
        ),
        const SizedBox(height: 14),
        _LanguageSelectorCard(
          controlKey: 'learning-language',
          title: 'Ngôn ngữ muốn học',
          subtitle: 'Ngôn ngữ cho từ vựng và bài luyện tập',
          icon: Icons.school_rounded,
          badgeColor: AppColors.yellow,
          option: learningOption,
          errorText: state.fieldErrors['learningLocale'],
          enabled: !state.isBusy,
          onSelected: notifier.updateLearningLocale,
        ),
      ],
    );
  }
}

class _LanguageSelectorCard extends StatelessWidget {
  const _LanguageSelectorCard({
    required this.controlKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.option,
    required this.errorText,
    required this.enabled,
    required this.onSelected,
  });

  final String controlKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;
  final LanguageCountryOption option;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Semantics(
          button: true,
          label:
              '$title, ${option.languageName}, ${option.countryName}. Mở danh sách tìm kiếm',
          excludeSemantics: true,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: errorText == null ? AppColors.ink : Colors.redAccent,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('onboarding-$controlKey-selector'),
                onTap: enabled ? () => _select(context) : null,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.ink, width: 1.8),
                          ),
                          child: Icon(icon, color: AppColors.ink, size: 23),
                        ),
                        const SizedBox(width: 11),
                        Text(option.flag, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.languageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                '${option.countryName} • $subtitle',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.ink,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (errorText case final error?) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
              fontFamily: 'Nunito',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _select(BuildContext context) async {
    final selected = await LanguageCountryPickerDialog.show(
      context,
      title: title,
      selectedLocale: option.locale,
      controlKey: controlKey,
    );
    if (selected != null) onSelected(selected.locale);
  }
}

class LanguageCountryPickerDialog extends StatefulWidget {
  const LanguageCountryPickerDialog({
    required this.title,
    required this.selectedLocale,
    required this.controlKey,
    super.key,
  });

  final String title;
  final String selectedLocale;
  final String controlKey;

  static Future<LanguageCountryOption?> show(
    BuildContext context, {
    required String title,
    required String selectedLocale,
    required String controlKey,
  }) {
    return showDialog<LanguageCountryOption>(
      context: context,
      builder: (_) => LanguageCountryPickerDialog(
        title: title,
        selectedLocale: selectedLocale,
        controlKey: controlKey,
      ),
    );
  }

  @override
  State<LanguageCountryPickerDialog> createState() =>
      _LanguageCountryPickerDialogState();
}

class _LanguageCountryPickerDialogState
    extends State<LanguageCountryPickerDialog> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<LanguageCountryOption> get _filteredOptions {
    final query = _normalize(_query.trim());
    if (query.isEmpty) return kLanguageCountries;
    return kLanguageCountries.where((option) {
      return _normalize(option.countryName).contains(query) ||
          _normalize(option.languageName).contains(query) ||
          option.countryCode.toLowerCase().contains(query) ||
          option.languageCode.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final options = _filteredOptions;
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      key: Key('onboarding-${widget.controlKey}-dialog'),
      backgroundColor: AppColors.softWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.ink, width: 2.8),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screen.height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: const Icon(Icons.language_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('onboarding-${widget.controlKey}-close'),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    constraints:
                        const BoxConstraints.tightFor(width: 48, height: 48),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: Key('onboarding-${widget.controlKey}-search'),
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Tìm quốc gia hoặc ngôn ngữ...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: options.isEmpty
                    ? const Center(
                        child: Text(
                          'Không tìm thấy quốc gia phù hợp.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          key: Key(
                            'onboarding-${widget.controlKey}-country-list',
                          ),
                          controller: _scrollController,
                          padding: const EdgeInsets.only(right: 10),
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options[index];
                            final selected =
                                option.locale == widget.selectedLocale;
                            return _CountryLanguageTile(
                              option: option,
                              selected: selected,
                              onTap: () => Navigator.of(context).pop(option),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryLanguageTile extends StatelessWidget {
  const _CountryLanguageTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LanguageCountryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.countryName}, ${option.languageName}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? AppColors.yellow : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: Key('language-country-${option.countryCode}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.ink, width: 1.8),
              ),
              child: Row(
                children: [
                  Text(option.flag, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option.countryName,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          option.languageName,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.darkGreen),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _normalize(String value) {
  var result = value.toLowerCase();
  const accented =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const plain =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  for (var index = 0; index < accented.length; index++) {
    result = result.replaceAll(accented[index], plain[index]);
  }
  return result;
}
