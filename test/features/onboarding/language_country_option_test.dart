import 'package:capy_vocab/features/onboarding/domain/entities/language_country_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('danh mục quốc gia có locale duy nhất và cờ hợp lệ', () {
    expect(kLanguageCountries, hasLength(greaterThanOrEqualTo(195)));

    final locales = kLanguageCountries.map((option) => option.locale).toSet();
    expect(locales, hasLength(kLanguageCountries.length));

    for (final option in kLanguageCountries) {
      expect(option.locale, matches(RegExp(r'^[a-z]{2,3}-[A-Z]{2}$')));
      expect(option.flag.runes, hasLength(2));
    }
  });

  test('tra cứu locale trả về đúng quốc gia', () {
    final japan = languageCountryByLocale('ja-JP');

    expect(japan.countryCode, 'JP');
    expect(japan.countryName, 'Nhật Bản');
    expect(japan.languageName, 'Tiếng Nhật');
  });
}
