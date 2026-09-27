final class LocalVocabularyMatch {
  LocalVocabularyMatch({
    required String word,
    required this.occurrenceCount,
    required this.corrected,
    String? phonetic,
    String? meaningVi,
    String? partOfSpeech,
    String? exampleEn,
    String? exampleVi,
  })  : word = _requiredText(word, 'word'),
        phonetic = _optionalText(phonetic),
        meaningVi = _optionalText(meaningVi),
        partOfSpeech = _optionalText(partOfSpeech),
        exampleEn = _optionalText(exampleEn),
        exampleVi = _optionalText(exampleVi) {
    if (occurrenceCount <= 0) {
      throw ArgumentError.value(
        occurrenceCount,
        'occurrenceCount',
        'must be greater than zero',
      );
    }
  }

  final String word;
  final String? phonetic;
  final String? meaningVi;
  final String? partOfSpeech;
  final String? exampleEn;
  final String? exampleVi;
  final int occurrenceCount;
  final bool corrected;
}

String normalizeLocalVocabularyQuery(String value) {
  final collapsed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final withoutBoundaryPunctuation = collapsed.replaceAll(
    RegExp(r'''^[\s.,!?;:'"“”‘’()[\]{}…]+|[\s.,!?;:'"“”‘’()[\]{}…]+$'''),
    '',
  );
  return withoutBoundaryPunctuation.trim().toLowerCase();
}

String _requiredText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, field, 'is empty');
  return normalized;
}

String? _optionalText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
