class LanguageCountryOption {
  const LanguageCountryOption({
    required this.countryCode,
    required this.countryName,
    required this.languageCode,
    required this.languageName,
  });

  final String countryCode;
  final String countryName;
  final String languageCode;
  final String languageName;

  String get locale => '$languageCode-$countryCode';

  String get flag => String.fromCharCodes(
        countryCode.codeUnits.map((unit) => unit + 127397),
      );
}

LanguageCountryOption languageCountryByLocale(String locale) {
  return kLanguageCountries.firstWhere(
    (option) => option.locale == locale,
    orElse: () => kLanguageCountries.first,
  );
}

const kLanguageCountries = <LanguageCountryOption>[
  LanguageCountryOption(
      countryCode: 'VN',
      countryName: 'Việt Nam',
      languageCode: 'vi',
      languageName: 'Tiếng Việt'),
  LanguageCountryOption(
      countryCode: 'US',
      countryName: 'Hoa Kỳ',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'GB',
      countryName: 'Vương quốc Anh',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'AF',
      countryName: 'Afghanistan',
      languageCode: 'fa',
      languageName: 'Tiếng Dari'),
  LanguageCountryOption(
      countryCode: 'AL',
      countryName: 'Albania',
      languageCode: 'sq',
      languageName: 'Tiếng Albania'),
  LanguageCountryOption(
      countryCode: 'DZ',
      countryName: 'Algeria',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'AD',
      countryName: 'Andorra',
      languageCode: 'ca',
      languageName: 'Tiếng Catalan'),
  LanguageCountryOption(
      countryCode: 'AO',
      countryName: 'Angola',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'AG',
      countryName: 'Antigua và Barbuda',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'AR',
      countryName: 'Argentina',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'AM',
      countryName: 'Armenia',
      languageCode: 'hy',
      languageName: 'Tiếng Armenia'),
  LanguageCountryOption(
      countryCode: 'AU',
      countryName: 'Úc',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'AT',
      countryName: 'Áo',
      languageCode: 'de',
      languageName: 'Tiếng Đức'),
  LanguageCountryOption(
      countryCode: 'AZ',
      countryName: 'Azerbaijan',
      languageCode: 'az',
      languageName: 'Tiếng Azerbaijan'),
  LanguageCountryOption(
      countryCode: 'BS',
      countryName: 'Bahamas',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'BH',
      countryName: 'Bahrain',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'BD',
      countryName: 'Bangladesh',
      languageCode: 'bn',
      languageName: 'Tiếng Bengal'),
  LanguageCountryOption(
      countryCode: 'BB',
      countryName: 'Barbados',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'BY',
      countryName: 'Belarus',
      languageCode: 'be',
      languageName: 'Tiếng Belarus'),
  LanguageCountryOption(
      countryCode: 'BE',
      countryName: 'Bỉ',
      languageCode: 'nl',
      languageName: 'Tiếng Hà Lan'),
  LanguageCountryOption(
      countryCode: 'BZ',
      countryName: 'Belize',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'BJ',
      countryName: 'Benin',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'BT',
      countryName: 'Bhutan',
      languageCode: 'dz',
      languageName: 'Tiếng Dzongkha'),
  LanguageCountryOption(
      countryCode: 'BO',
      countryName: 'Bolivia',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'BA',
      countryName: 'Bosnia và Herzegovina',
      languageCode: 'bs',
      languageName: 'Tiếng Bosnia'),
  LanguageCountryOption(
      countryCode: 'BW',
      countryName: 'Botswana',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'BR',
      countryName: 'Brazil',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'BN',
      countryName: 'Brunei',
      languageCode: 'ms',
      languageName: 'Tiếng Mã Lai'),
  LanguageCountryOption(
      countryCode: 'BG',
      countryName: 'Bulgaria',
      languageCode: 'bg',
      languageName: 'Tiếng Bulgaria'),
  LanguageCountryOption(
      countryCode: 'BF',
      countryName: 'Burkina Faso',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'BI',
      countryName: 'Burundi',
      languageCode: 'rn',
      languageName: 'Tiếng Kirundi'),
  LanguageCountryOption(
      countryCode: 'CV',
      countryName: 'Cabo Verde',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'KH',
      countryName: 'Campuchia',
      languageCode: 'km',
      languageName: 'Tiếng Khmer'),
  LanguageCountryOption(
      countryCode: 'CM',
      countryName: 'Cameroon',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'CA',
      countryName: 'Canada',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'CF',
      countryName: 'Cộng hòa Trung Phi',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'TD',
      countryName: 'Chad',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'CL',
      countryName: 'Chile',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'CN',
      countryName: 'Trung Quốc',
      languageCode: 'zh',
      languageName: 'Tiếng Trung'),
  LanguageCountryOption(
      countryCode: 'CO',
      countryName: 'Colombia',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'KM',
      countryName: 'Comoros',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'CG',
      countryName: 'Cộng hòa Congo',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'CD',
      countryName: 'Cộng hòa Dân chủ Congo',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'CR',
      countryName: 'Costa Rica',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'CI',
      countryName: 'Bờ Biển Ngà',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'HR',
      countryName: 'Croatia',
      languageCode: 'hr',
      languageName: 'Tiếng Croatia'),
  LanguageCountryOption(
      countryCode: 'CU',
      countryName: 'Cuba',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'CY',
      countryName: 'Síp',
      languageCode: 'el',
      languageName: 'Tiếng Hy Lạp'),
  LanguageCountryOption(
      countryCode: 'CZ',
      countryName: 'Séc',
      languageCode: 'cs',
      languageName: 'Tiếng Séc'),
  LanguageCountryOption(
      countryCode: 'DK',
      countryName: 'Đan Mạch',
      languageCode: 'da',
      languageName: 'Tiếng Đan Mạch'),
  LanguageCountryOption(
      countryCode: 'DJ',
      countryName: 'Djibouti',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'DM',
      countryName: 'Dominica',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'DO',
      countryName: 'Cộng hòa Dominica',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'EC',
      countryName: 'Ecuador',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'EG',
      countryName: 'Ai Cập',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'SV',
      countryName: 'El Salvador',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'GQ',
      countryName: 'Guinea Xích Đạo',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'ER',
      countryName: 'Eritrea',
      languageCode: 'ti',
      languageName: 'Tiếng Tigrinya'),
  LanguageCountryOption(
      countryCode: 'EE',
      countryName: 'Estonia',
      languageCode: 'et',
      languageName: 'Tiếng Estonia'),
  LanguageCountryOption(
      countryCode: 'SZ',
      countryName: 'Eswatini',
      languageCode: 'ss',
      languageName: 'Tiếng Swati'),
  LanguageCountryOption(
      countryCode: 'ET',
      countryName: 'Ethiopia',
      languageCode: 'am',
      languageName: 'Tiếng Amhara'),
  LanguageCountryOption(
      countryCode: 'FJ',
      countryName: 'Fiji',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'FI',
      countryName: 'Phần Lan',
      languageCode: 'fi',
      languageName: 'Tiếng Phần Lan'),
  LanguageCountryOption(
      countryCode: 'FR',
      countryName: 'Pháp',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'GA',
      countryName: 'Gabon',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'GM',
      countryName: 'Gambia',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'GE',
      countryName: 'Georgia',
      languageCode: 'ka',
      languageName: 'Tiếng Georgia'),
  LanguageCountryOption(
      countryCode: 'DE',
      countryName: 'Đức',
      languageCode: 'de',
      languageName: 'Tiếng Đức'),
  LanguageCountryOption(
      countryCode: 'GH',
      countryName: 'Ghana',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'GR',
      countryName: 'Hy Lạp',
      languageCode: 'el',
      languageName: 'Tiếng Hy Lạp'),
  LanguageCountryOption(
      countryCode: 'GD',
      countryName: 'Grenada',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'GT',
      countryName: 'Guatemala',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'GN',
      countryName: 'Guinea',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'GW',
      countryName: 'Guinea-Bissau',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'GY',
      countryName: 'Guyana',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'HT',
      countryName: 'Haiti',
      languageCode: 'ht',
      languageName: 'Tiếng Creole Haiti'),
  LanguageCountryOption(
      countryCode: 'HN',
      countryName: 'Honduras',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'HU',
      countryName: 'Hungary',
      languageCode: 'hu',
      languageName: 'Tiếng Hungary'),
  LanguageCountryOption(
      countryCode: 'IS',
      countryName: 'Iceland',
      languageCode: 'is',
      languageName: 'Tiếng Iceland'),
  LanguageCountryOption(
      countryCode: 'IN',
      countryName: 'Ấn Độ',
      languageCode: 'hi',
      languageName: 'Tiếng Hindi'),
  LanguageCountryOption(
      countryCode: 'ID',
      countryName: 'Indonesia',
      languageCode: 'id',
      languageName: 'Tiếng Indonesia'),
  LanguageCountryOption(
      countryCode: 'IR',
      countryName: 'Iran',
      languageCode: 'fa',
      languageName: 'Tiếng Ba Tư'),
  LanguageCountryOption(
      countryCode: 'IQ',
      countryName: 'Iraq',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'IE',
      countryName: 'Ireland',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'IL',
      countryName: 'Israel',
      languageCode: 'he',
      languageName: 'Tiếng Hebrew'),
  LanguageCountryOption(
      countryCode: 'IT',
      countryName: 'Ý',
      languageCode: 'it',
      languageName: 'Tiếng Ý'),
  LanguageCountryOption(
      countryCode: 'JM',
      countryName: 'Jamaica',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'JP',
      countryName: 'Nhật Bản',
      languageCode: 'ja',
      languageName: 'Tiếng Nhật'),
  LanguageCountryOption(
      countryCode: 'JO',
      countryName: 'Jordan',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'KZ',
      countryName: 'Kazakhstan',
      languageCode: 'kk',
      languageName: 'Tiếng Kazakh'),
  LanguageCountryOption(
      countryCode: 'KE',
      countryName: 'Kenya',
      languageCode: 'sw',
      languageName: 'Tiếng Swahili'),
  LanguageCountryOption(
      countryCode: 'KI',
      countryName: 'Kiribati',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'KP',
      countryName: 'Triều Tiên',
      languageCode: 'ko',
      languageName: 'Tiếng Hàn'),
  LanguageCountryOption(
      countryCode: 'KR',
      countryName: 'Hàn Quốc',
      languageCode: 'ko',
      languageName: 'Tiếng Hàn'),
  LanguageCountryOption(
      countryCode: 'KW',
      countryName: 'Kuwait',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'KG',
      countryName: 'Kyrgyzstan',
      languageCode: 'ky',
      languageName: 'Tiếng Kyrgyz'),
  LanguageCountryOption(
      countryCode: 'LA',
      countryName: 'Lào',
      languageCode: 'lo',
      languageName: 'Tiếng Lào'),
  LanguageCountryOption(
      countryCode: 'LV',
      countryName: 'Latvia',
      languageCode: 'lv',
      languageName: 'Tiếng Latvia'),
  LanguageCountryOption(
      countryCode: 'LB',
      countryName: 'Liban',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'LS',
      countryName: 'Lesotho',
      languageCode: 'st',
      languageName: 'Tiếng Sotho'),
  LanguageCountryOption(
      countryCode: 'LR',
      countryName: 'Liberia',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'LY',
      countryName: 'Libya',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'LI',
      countryName: 'Liechtenstein',
      languageCode: 'de',
      languageName: 'Tiếng Đức'),
  LanguageCountryOption(
      countryCode: 'LT',
      countryName: 'Litva',
      languageCode: 'lt',
      languageName: 'Tiếng Litva'),
  LanguageCountryOption(
      countryCode: 'LU',
      countryName: 'Luxembourg',
      languageCode: 'lb',
      languageName: 'Tiếng Luxembourg'),
  LanguageCountryOption(
      countryCode: 'MG',
      countryName: 'Madagascar',
      languageCode: 'mg',
      languageName: 'Tiếng Malagasy'),
  LanguageCountryOption(
      countryCode: 'MW',
      countryName: 'Malawi',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'MY',
      countryName: 'Malaysia',
      languageCode: 'ms',
      languageName: 'Tiếng Mã Lai'),
  LanguageCountryOption(
      countryCode: 'MV',
      countryName: 'Maldives',
      languageCode: 'dv',
      languageName: 'Tiếng Dhivehi'),
  LanguageCountryOption(
      countryCode: 'ML',
      countryName: 'Mali',
      languageCode: 'bm',
      languageName: 'Tiếng Bambara'),
  LanguageCountryOption(
      countryCode: 'MT',
      countryName: 'Malta',
      languageCode: 'mt',
      languageName: 'Tiếng Malta'),
  LanguageCountryOption(
      countryCode: 'MH',
      countryName: 'Quần đảo Marshall',
      languageCode: 'mh',
      languageName: 'Tiếng Marshall'),
  LanguageCountryOption(
      countryCode: 'MR',
      countryName: 'Mauritania',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'MU',
      countryName: 'Mauritius',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'MX',
      countryName: 'Mexico',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'FM',
      countryName: 'Micronesia',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'MD',
      countryName: 'Moldova',
      languageCode: 'ro',
      languageName: 'Tiếng Romania'),
  LanguageCountryOption(
      countryCode: 'MC',
      countryName: 'Monaco',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'MN',
      countryName: 'Mông Cổ',
      languageCode: 'mn',
      languageName: 'Tiếng Mông Cổ'),
  LanguageCountryOption(
      countryCode: 'ME',
      countryName: 'Montenegro',
      languageCode: 'sr',
      languageName: 'Tiếng Montenegro'),
  LanguageCountryOption(
      countryCode: 'MA',
      countryName: 'Maroc',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'MZ',
      countryName: 'Mozambique',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'MM',
      countryName: 'Myanmar',
      languageCode: 'my',
      languageName: 'Tiếng Myanmar'),
  LanguageCountryOption(
      countryCode: 'NA',
      countryName: 'Namibia',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'NR',
      countryName: 'Nauru',
      languageCode: 'na',
      languageName: 'Tiếng Nauru'),
  LanguageCountryOption(
      countryCode: 'NP',
      countryName: 'Nepal',
      languageCode: 'ne',
      languageName: 'Tiếng Nepal'),
  LanguageCountryOption(
      countryCode: 'NL',
      countryName: 'Hà Lan',
      languageCode: 'nl',
      languageName: 'Tiếng Hà Lan'),
  LanguageCountryOption(
      countryCode: 'NZ',
      countryName: 'New Zealand',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'NI',
      countryName: 'Nicaragua',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'NE',
      countryName: 'Niger',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'NG',
      countryName: 'Nigeria',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'MK',
      countryName: 'Bắc Macedonia',
      languageCode: 'mk',
      languageName: 'Tiếng Macedonia'),
  LanguageCountryOption(
      countryCode: 'NO',
      countryName: 'Na Uy',
      languageCode: 'no',
      languageName: 'Tiếng Na Uy'),
  LanguageCountryOption(
      countryCode: 'OM',
      countryName: 'Oman',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'PK',
      countryName: 'Pakistan',
      languageCode: 'ur',
      languageName: 'Tiếng Urdu'),
  LanguageCountryOption(
      countryCode: 'PW',
      countryName: 'Palau',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'PA',
      countryName: 'Panama',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'PG',
      countryName: 'Papua New Guinea',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'PY',
      countryName: 'Paraguay',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'PE',
      countryName: 'Peru',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'PH',
      countryName: 'Philippines',
      languageCode: 'fil',
      languageName: 'Tiếng Filipino'),
  LanguageCountryOption(
      countryCode: 'PL',
      countryName: 'Ba Lan',
      languageCode: 'pl',
      languageName: 'Tiếng Ba Lan'),
  LanguageCountryOption(
      countryCode: 'PT',
      countryName: 'Bồ Đào Nha',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'QA',
      countryName: 'Qatar',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'RO',
      countryName: 'Romania',
      languageCode: 'ro',
      languageName: 'Tiếng Romania'),
  LanguageCountryOption(
      countryCode: 'RU',
      countryName: 'Nga',
      languageCode: 'ru',
      languageName: 'Tiếng Nga'),
  LanguageCountryOption(
      countryCode: 'RW',
      countryName: 'Rwanda',
      languageCode: 'rw',
      languageName: 'Tiếng Kinyarwanda'),
  LanguageCountryOption(
      countryCode: 'KN',
      countryName: 'Saint Kitts và Nevis',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'LC',
      countryName: 'Saint Lucia',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'VC',
      countryName: 'Saint Vincent và Grenadines',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'WS',
      countryName: 'Samoa',
      languageCode: 'sm',
      languageName: 'Tiếng Samoa'),
  LanguageCountryOption(
      countryCode: 'SM',
      countryName: 'San Marino',
      languageCode: 'it',
      languageName: 'Tiếng Ý'),
  LanguageCountryOption(
      countryCode: 'ST',
      countryName: 'São Tomé và Príncipe',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'SA',
      countryName: 'Ả Rập Xê Út',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'SN',
      countryName: 'Senegal',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'RS',
      countryName: 'Serbia',
      languageCode: 'sr',
      languageName: 'Tiếng Serbia'),
  LanguageCountryOption(
      countryCode: 'SC',
      countryName: 'Seychelles',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'SL',
      countryName: 'Sierra Leone',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'SG',
      countryName: 'Singapore',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'SK',
      countryName: 'Slovakia',
      languageCode: 'sk',
      languageName: 'Tiếng Slovakia'),
  LanguageCountryOption(
      countryCode: 'SI',
      countryName: 'Slovenia',
      languageCode: 'sl',
      languageName: 'Tiếng Slovenia'),
  LanguageCountryOption(
      countryCode: 'SB',
      countryName: 'Quần đảo Solomon',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'SO',
      countryName: 'Somalia',
      languageCode: 'so',
      languageName: 'Tiếng Somalia'),
  LanguageCountryOption(
      countryCode: 'ZA',
      countryName: 'Nam Phi',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'SS',
      countryName: 'Nam Sudan',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'ES',
      countryName: 'Tây Ban Nha',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'LK',
      countryName: 'Sri Lanka',
      languageCode: 'si',
      languageName: 'Tiếng Sinhala'),
  LanguageCountryOption(
      countryCode: 'SD',
      countryName: 'Sudan',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'SR',
      countryName: 'Suriname',
      languageCode: 'nl',
      languageName: 'Tiếng Hà Lan'),
  LanguageCountryOption(
      countryCode: 'SE',
      countryName: 'Thụy Điển',
      languageCode: 'sv',
      languageName: 'Tiếng Thụy Điển'),
  LanguageCountryOption(
      countryCode: 'CH',
      countryName: 'Thụy Sĩ',
      languageCode: 'de',
      languageName: 'Tiếng Đức'),
  LanguageCountryOption(
      countryCode: 'SY',
      countryName: 'Syria',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'TW',
      countryName: 'Đài Loan',
      languageCode: 'zh',
      languageName: 'Tiếng Trung'),
  LanguageCountryOption(
      countryCode: 'TJ',
      countryName: 'Tajikistan',
      languageCode: 'tg',
      languageName: 'Tiếng Tajik'),
  LanguageCountryOption(
      countryCode: 'TZ',
      countryName: 'Tanzania',
      languageCode: 'sw',
      languageName: 'Tiếng Swahili'),
  LanguageCountryOption(
      countryCode: 'TH',
      countryName: 'Thái Lan',
      languageCode: 'th',
      languageName: 'Tiếng Thái'),
  LanguageCountryOption(
      countryCode: 'TL',
      countryName: 'Timor-Leste',
      languageCode: 'pt',
      languageName: 'Tiếng Bồ Đào Nha'),
  LanguageCountryOption(
      countryCode: 'TG',
      countryName: 'Togo',
      languageCode: 'fr',
      languageName: 'Tiếng Pháp'),
  LanguageCountryOption(
      countryCode: 'TO',
      countryName: 'Tonga',
      languageCode: 'to',
      languageName: 'Tiếng Tonga'),
  LanguageCountryOption(
      countryCode: 'TT',
      countryName: 'Trinidad và Tobago',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'TN',
      countryName: 'Tunisia',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'TR',
      countryName: 'Thổ Nhĩ Kỳ',
      languageCode: 'tr',
      languageName: 'Tiếng Thổ Nhĩ Kỳ'),
  LanguageCountryOption(
      countryCode: 'TM',
      countryName: 'Turkmenistan',
      languageCode: 'tk',
      languageName: 'Tiếng Turkmen'),
  LanguageCountryOption(
      countryCode: 'TV',
      countryName: 'Tuvalu',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'UG',
      countryName: 'Uganda',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'UA',
      countryName: 'Ukraine',
      languageCode: 'uk',
      languageName: 'Tiếng Ukraine'),
  LanguageCountryOption(
      countryCode: 'AE',
      countryName: 'Các Tiểu vương quốc Ả Rập Thống nhất',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'UY',
      countryName: 'Uruguay',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'UZ',
      countryName: 'Uzbekistan',
      languageCode: 'uz',
      languageName: 'Tiếng Uzbek'),
  LanguageCountryOption(
      countryCode: 'VU',
      countryName: 'Vanuatu',
      languageCode: 'bi',
      languageName: 'Tiếng Bislama'),
  LanguageCountryOption(
      countryCode: 'VA',
      countryName: 'Vatican',
      languageCode: 'it',
      languageName: 'Tiếng Ý'),
  LanguageCountryOption(
      countryCode: 'VE',
      countryName: 'Venezuela',
      languageCode: 'es',
      languageName: 'Tiếng Tây Ban Nha'),
  LanguageCountryOption(
      countryCode: 'YE',
      countryName: 'Yemen',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
  LanguageCountryOption(
      countryCode: 'ZM',
      countryName: 'Zambia',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'ZW',
      countryName: 'Zimbabwe',
      languageCode: 'en',
      languageName: 'Tiếng Anh'),
  LanguageCountryOption(
      countryCode: 'PS',
      countryName: 'Palestine',
      languageCode: 'ar',
      languageName: 'Tiếng Ả Rập'),
];
